# EvolutionRunner: evolution mode as a process of its own (tools/evolution_sim.gd, headless), started
# and stopped from the debug overlay, so its data and the game's never meet: it reads and writes
# only Constants EVOLUTION_DIR, the game only its own saves. Desktop with the project's files only
# (available): an exported game has no tools.
# The run reports through EVOLUTION_STATUS_FILE; STOP asks it to save and end (EVOLUTION_STOP_FILE)
# and, should it not within EVOLUTION_STOP_WAIT, kills it (its saves are atomic: the last one holds).

extends Reference


static func available() -> bool:
	return OS.has_feature("editor") and OS.get_name() != "Android" and ResourceLoader.exists(Constants.EVOLUTION_SIM_SCRIPT)


# Starts a run that goes on until stopped; returns its process id (-1: it did not start).
static func start() -> int:
	Directory.new().remove(Constants.EVOLUTION_STOP_FILE)
	var args: Array = [
		"--no-window", "--path", ProjectSettings.globalize_path("res://"), "-s", Constants.EVOLUTION_SIM_SCRIPT,
		"--", "--hours=0", "--speed=%s" % Constants.EVOLUTION_SIM_SPEED,
	]
	return OS.execute(OS.get_executable_path(), args, false)


# Asks the run to save and end.
static func request_stop() -> void:
	var dir := Directory.new()
	dir.make_dir_recursive(Constants.EVOLUTION_DIR)
	var file := File.new()
	if file.open(Constants.EVOLUTION_STOP_FILE, File.WRITE) == OK:
		file.store_string(str(OS.get_unix_time()))
		file.close()


static func kill(pid: int) -> void:
	if pid > 0:
		OS.kill(pid)


# The run's last report ({} if there is none): pid, state ("running", "done"), updated and saved
# (unix times), game_time, lives, births, genomes, run_id, pace.
static func status() -> Dictionary:
	var file := File.new()
	if file.open(Constants.EVOLUTION_STATUS_FILE, File.READ) != OK:
		return {}
	var parsed = parse_json(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


# The status in a few lines, for the overlay.
static func describe(status: Dictionary, now: int) -> String:
	if status.empty():
		return "STARTING: THE SECTOR IS LOADING"
	var lines: PoolStringArray = []
	lines.append("%s  RUN %s" % [str(status.get("state", "?")).to_upper(), status.get("run_id", "?")])
	lines.append("EVOLUTION TIME %.2f H  AT x%.1f" % [float(status.get("game_time", 0.0)) / 3600.0, float(status.get("pace", 0.0))])
	lines.append("%d LIVES ENDED, %d BORN, %d GENOMES" % [int(status.get("lives", 0)), int(status.get("births", 0)), int(status.get("genomes", 0))])
	var saved: int = int(status.get("saved", 0))
	lines.append("LAST SAVED %s" % ("NOT YET" if saved <= 0 else "%d S AGO" % (now - saved)))
	lines.append("REPORTED %d S AGO" % (now - int(status.get("updated", now))))
	lines.append("DATA: %s" % ProjectSettings.globalize_path(Constants.EVOLUTION_DIR))
	return lines.join("\n")
