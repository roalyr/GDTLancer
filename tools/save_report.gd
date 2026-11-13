# Save report: what a save holds, in words: where the player is, the ship, its fit and hold, the
# bank, home storage, standings and bounties, the world's time and markups, and the travellers.
# Reads the file only; nothing is changed.
#     godot --no-window -s tools/save_report.gd -- [save=<path to a .sav>]
# Without save=: the newest save of the game and of test starts (GameStateManager PLAY_SAVE_DIR,
# TEST_SAVE_DIR).
extends SceneTree

const DIRS = ["user://savegames/", "user://test_start_saves/"]


func _initialize():
	var path := ""
	for arg in OS.get_cmdline_args():
		if arg.begins_with("save="):
			path = arg.trim_prefix("save=")
	if path == "":
		path = newest_save()
	if path == "":
		print("SAVE none in ", DIRS)
		quit(1)
		return
	var file := File.new()
	if file.open(path, File.READ) != OK:
		print("SAVE cannot read ", path)
		quit(1)
		return
	var data = file.get_var(true)
	file.close()
	if not data is Dictionary:
		print("SAVE not a save: ", path)
		quit(1)
		return
	for line in report(data, path):
		print(line)
	quit()


static func newest_save() -> String:
	var best := ""
	var best_time := -1
	var file := File.new()
	for dir_path in DIRS:
		var dir := Directory.new()
		if dir.open(dir_path) != OK:
			continue
		dir.list_dir_begin(true, true)
		var name: String = dir.get_next()
		while name != "":
			if name.ends_with(".sav"):
				var time: int = file.get_modified_time(dir_path.plus_file(name))
				if time > best_time:
					best_time = time
					best = dir_path.plus_file(name)
			name = dir.get_next()
	return best


# The save as lines of text.
static func report(data: Dictionary, path: String) -> Array:
	var summary: Dictionary = data.get("summary", {})
	var lines: Array = ["SAVE %s (%s mode, format %s, saved %s)" % [path, data.get("mode", "?"), data.get("format_version", "?"), summary.get("saved_at", "?")]]
	var docked: String = str(data.get("player_docked_at", ""))
	lines.append("Where: %s, %s; home %s" % [data.get("current_sector_id", "?"), "docked at " + docked if docked != "" else "in flight at " + str(data.get("player_position", "?")), data.get("home_location_id", "?")])
	lines.append("Time: played %s, world %s" % [_hours(data.get("play_time", 0.0)), _hours(data.get("world_time", 0.0))])
	var hull = data.get("player_hull", -1.0)
	lines.append("Ship: %s, hull %s, weapons %s" % [data.get("player_ship_template_id", "?"), "full" if float(hull) < 0.0 else "%.0f" % float(hull), "safe" if data.get("weapons_safe", true) else "armed"])
	var fit: Dictionary = data.get("player_fit", {})
	lines.append("Fit: %s" % ("the hull's own" if fit.empty() else "tools %s, modules %s" % [fit.get("tools", []), fit.get("modules", [])]))
	lines.append("Hold: %s" % _pairs(data.get("player_cargo", {})))
	lines.append("Bank: %s WP" % data.get("player_bank", 0))
	lines.append("Storage: %s" % _pairs(data.get("player_storage", {})))
	lines.append("Standing: %s" % _pairs(data.get("player_standing", {}), "%+.2f"))
	lines.append("Bounties: %s" % _pairs(data.get("player_bounties", {})))
	lines.append("Markups: %s" % _pairs(data.get("station_markups", {}), "%.2f"))
	var travelers: Array = data.get("travelers", [])
	lines.append("Travellers (%d):" % travelers.size())
	for record in travelers:
		lines.append("  %s %s %s in %s (%s), bank %s, hull %.0f%%, hold %s" % [record.get("id", "?"), record.get("faction", "?"), record.get("role", "") if record.get("role", "") != "" else "any",
			record.get("sector", "?"), record.get("status", "?"), record.get("bank", 0), 100.0 * float(record.get("hull", 1.0)), _pairs(record.get("cargo", {}))])
	var evolution = data.get("evolution", {})
	if evolution is Dictionary and not evolution.empty():
		lines.append("Evolution: %s" % ", ".join(PoolStringArray(evolution.keys())))
	return lines


static func _pairs(pairs, number: String = "%s") -> String:
	if not pairs is Dictionary or pairs.empty():
		return "none"
	var keys: Array = pairs.keys()
	keys.sort()
	var out: Array = []
	for key in keys:
		out.append(("%s " + number) % [key, pairs[key]])
	return ", ".join(PoolStringArray(out))


static func _hours(seconds) -> String:
	return "%.1f h" % (float(seconds) / 3600.0)
