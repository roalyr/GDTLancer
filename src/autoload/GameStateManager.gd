# GameStateManager: new game reset and save/load of GameState and the arenas' evolution.
# Saves carry SAVE_FORMAT_VERSION; older ones are deleted at start (they lack the evolution data),
# and a summary for the load prompt (get_save_summary).

extends Node

const SAVE_DIR = "user://savegames/"

var save_dir: String = SAVE_DIR  # Tests point this at their own folder so real saves are never touched
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".sav"
const SAVE_FORMAT_VERSION = 2  # 2: evolution, play time and a summary

var keep_evolution: bool = false  # The next reset keeps the evolution running (a new run in the same world)


func _ready() -> void:
	delete_outdated_saves()


func _process(delta: float) -> void:
	if GameState.current_sector_id != "":
		GameState.play_time += delta / max(Engine.time_scale, 0.001)


# Saves of an older format (or unreadable ones) are of no use any more: removes them.
func delete_outdated_saves() -> void:
	var dir := Directory.new()
	if dir.open(save_dir) != OK:
		return
	var outdated: Array = []
	dir.list_dir_begin(true, true)
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with(SAVE_FILE_PREFIX) and file_name.ends_with(SAVE_FILE_EXT):
			var file := File.new()
			var data = null
			if file.open(save_dir.plus_file(file_name), File.READ) == OK:
				data = file.get_var(true)
				file.close()
			if not (data is Dictionary and _is_save_data_valid(data)):
				outdated.append(file_name)
		file_name = dir.get_next()
	for name in outdated:
		dir.remove(save_dir.plus_file(name))
		print("GameStateManager: removed outdated save ", name)


# --- Public API ---

func delete_save(slot_id: int = 0) -> void:
	var dir := Directory.new()
	var path: String = _get_save_path(slot_id)
	if dir.file_exists(path):
		dir.remove(path)


# Every save slot.
func delete_all_saves() -> void:
	var dir := Directory.new()
	if dir.open(save_dir) != OK:
		return
	dir.list_dir_begin(true, true)
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with(SAVE_FILE_PREFIX) and file_name.ends_with(SAVE_FILE_EXT):
			dir.remove(save_dir.plus_file(file_name))
		file_name = dir.get_next()


# The player's ship is lost (Constants RESPAWN_DELAY): the state they wake up in, docked at home in
# the start's ship. Bank, storage, home and play time stay.
func lose_ship() -> void:
	var game_start = TemplateDatabase.game_starts.get(Constants.DEFAULT_GAME_START_ID)
	GameState.player_ship_template_id = game_start.player_ship_template if game_start != null else Constants.FALLBACK_SHIP_TEMPLATE_ID
	GameState.player_fit = {}  # The hull's default fit
	GameState.player_hull = -1.0
	GameState.player_lance_nails = -1
	GameState.player_tool_ammo = []
	GameState.player_cargo = {Constants.FUEL_COMMODITY: Constants.FUEL_STARTING_UNITS}  # Fuelled for a jump or two
	GameState.player_hull_scars = []
	GameState.player_bounties = {}  # Lapse with the ship (a killer has collected them)
	GameState.player_docked_at = GameState.home_location_id
	GameState.current_sector_id = Constants.INITIAL_SECTOR_ID  # The home port's sector
	GameState.player_position = Vector3.ZERO
	GameState.player_rotation = Vector3.ZERO
	GameState.player_arrived_from_sector = ""
	GameState.player_arrival_direction = Vector3.ZERO


func reset_to_defaults() -> void:
	GameState.reset_state()
	if keep_evolution:
		keep_evolution = false
	else:
		Evolution.new_run()


func save_game(slot_id: int = 0) -> bool:
	_ensure_save_dir_exists()

	# Capture current player position and rotation before serializing
	_capture_player_transform()

	var save_data = _serialize_game_state()

	var file = File.new()
	var path = _get_save_path(slot_id)
	var err = file.open(path, File.WRITE)

	if err == OK:
		file.store_var(save_data, true)
		file.close()
		if Constants.VERBOSE_RUNTIME_LOGS:
			print("Game saved successfully to: ", path)
		return true
	else:
		printerr("Error saving game to path: ", path, " Error code: ", err)
		file.close()
		return false


func load_game(slot_id: int = 0) -> bool:
	var save_data = _read_save_data(slot_id)
	if not save_data is Dictionary or not _is_save_data_valid(save_data):
		printerr("Load Error: No valid save data in slot ", slot_id)
		return false

	_deserialize_and_apply_game_state(save_data)

	EventBus.emit_signal("game_state_loaded")
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("Game state loaded successfully. Emitted game_state_loaded signal.")
	return true


# Treats missing, corrupt or outdated saves as non-existent for UI purposes.
func has_save_file(slot_id: int = 0) -> bool:
	var save_data = _read_save_data(slot_id)
	return save_data is Dictionary and _is_save_data_valid(save_data)


# --- Internals ---

func _get_save_path(slot_id: int) -> String:
	return save_dir + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT


func _read_save_data(slot_id: int):
	var path = _get_save_path(slot_id)
	var file = File.new()
	if not file.file_exists(path):
		return null
	if file.open(path, File.READ) != OK:
		file.close()
		return null
	var save_data = file.get_var(true)
	file.close()
	return save_data


func _is_save_data_valid(save_data: Dictionary) -> bool:
	return (
		int(save_data.get("format_version", 0)) == SAVE_FORMAT_VERSION
		and str(save_data.get("player_ship_template_id", "")) != ""
		and str(save_data.get("current_sector_id", "")) != ""
	)


func _ensure_save_dir_exists() -> void:
	var dir = Directory.new()
	if not dir.dir_exists(save_dir):
		var err = dir.make_dir_recursive(save_dir)
		if err != OK:
			printerr("GameStateManager Error: Could not create save dir: ", save_dir, " (", err, ")")


func _capture_player_transform() -> void:
	var player_body = GlobalRefs.player_agent_body
	if is_instance_valid(player_body):
		GameState.player_position = player_body.global_transform.origin
		GameState.player_rotation = player_body.rotation_degrees


func _serialize_game_state() -> Dictionary:
	return {
		"player_ship_template_id": GameState.player_ship_template_id,
		"player_hull": GameState.player_hull,
		"player_lance_nails": GameState.player_lance_nails,
		"player_tool_ammo": GameState.player_tool_ammo,
		"player_cargo": GameState.player_cargo.duplicate(),
		"home_location_id": GameState.home_location_id,
		"player_bank": GameState.player_bank,
		"player_fit": GameState.player_fit.duplicate(true),
		"player_storage": GameState.player_storage.duplicate(),
		"player_standing": GameState.player_standing.duplicate(),
		"player_bounties": GameState.player_bounties.duplicate(),
		"station_markups": GameState.station_markups.duplicate(),
		"player_hull_scars": GameState.player_hull_scars.duplicate(true),
		"current_sector_id": GameState.current_sector_id,
		"player_docked_at": GameState.player_docked_at,
		"player_position": _serialize_vector3(GameState.player_position),
		"player_rotation": _serialize_vector3(GameState.player_rotation),
		"player_arrived_from_sector": GameState.player_arrived_from_sector,
		"player_arrival_direction": _serialize_vector3(GameState.player_arrival_direction),
		"play_time": GameState.play_time,
		"format_version": SAVE_FORMAT_VERSION,
		"evolution": Evolution.serialize(),
		"summary": _make_summary(),
	}


func _make_summary() -> Dictionary:
	var summary: Dictionary = Evolution.summary()
	var now: Dictionary = OS.get_datetime()
	summary["saved_at"] = "%04d-%02d-%02d %02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute]
	summary["play_time"] = GameState.play_time
	summary["bank"] = GameState.player_bank
	summary["sector"] = GameState.current_sector_id
	return summary


# The saved game's summary (see _make_summary), or {} if there is no valid save.
func get_save_summary(slot_id: int = 0) -> Dictionary:
	var save_data = _read_save_data(slot_id)
	if not (save_data is Dictionary and _is_save_data_valid(save_data)):
		return {}
	return save_data.get("summary", {})


func _deserialize_and_apply_game_state(save_data: Dictionary) -> void:
	reset_to_defaults()
	GameState.player_ship_template_id = str(save_data.get("player_ship_template_id", ""))
	GameState.player_hull = float(save_data.get("player_hull", -1.0))
	GameState.player_lance_nails = int(save_data.get("player_lance_nails", -1))
	GameState.player_tool_ammo = save_data.get("player_tool_ammo", [])
	GameState.home_location_id = str(save_data.get("home_location_id", ""))
	GameState.player_bank = int(save_data.get("player_bank", 0))
	var saved_fit = save_data.get("player_fit", {})
	GameState.player_fit = saved_fit if saved_fit is Dictionary else {}
	var saved_storage = save_data.get("player_storage", {})
	GameState.player_storage = saved_storage if saved_storage is Dictionary else {}
	for key in ["player_standing", "player_bounties", "station_markups"]:
		var saved = save_data.get(key, {})
		var values: Dictionary = {}
		if saved is Dictionary:
			for id in saved:
				values[str(id)] = float(saved[id])
		GameState.set(key, values)
	var saved_scars = save_data.get("player_hull_scars", [])
	GameState.player_hull_scars = saved_scars if saved_scars is Array else []
	var saved_cargo = save_data.get("player_cargo", {})
	GameState.player_cargo = {}
	if saved_cargo is Dictionary:
		for commodity_id in saved_cargo:
			GameState.player_cargo[str(commodity_id)] = int(saved_cargo[commodity_id])
	GameState.current_sector_id = str(save_data.get("current_sector_id", ""))
	GameState.player_docked_at = str(save_data.get("player_docked_at", ""))
	GameState.player_position = _deserialize_vector3(save_data.get("player_position", {}))
	GameState.player_rotation = _deserialize_vector3(save_data.get("player_rotation", {}))
	GameState.player_arrived_from_sector = str(save_data.get("player_arrived_from_sector", ""))
	GameState.player_arrival_direction = _deserialize_vector3(save_data.get("player_arrival_direction", {}))
	GameState.play_time = float(save_data.get("play_time", 0.0))
	var evolution = save_data.get("evolution", {})
	if evolution is Dictionary:
		Evolution.deserialize(evolution)


# --- Vector3 Serialization Helpers ---
func _serialize_vector3(vec: Vector3) -> Dictionary:
	return {"x": vec.x, "y": vec.y, "z": vec.z}


func _deserialize_vector3(data) -> Vector3:
	if data is Dictionary:
		return Vector3(
			float(data.get("x", 0.0)),
			float(data.get("y", 0.0)),
			float(data.get("z", 0.0))
		)
	return Vector3.ZERO
