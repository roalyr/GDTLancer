# GameStateManager: new game reset and save/load of GameState.

extends Node

const SAVE_DIR = "user://savegames/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".sav"


# --- Public API ---

func reset_to_defaults() -> void:
	GameState.reset_state()


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
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT


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
		str(save_data.get("player_ship_template_id", "")) != ""
		and str(save_data.get("current_sector_id", "")) != ""
	)


func _ensure_save_dir_exists() -> void:
	var dir = Directory.new()
	if not dir.dir_exists(SAVE_DIR):
		var err = dir.make_dir_recursive(SAVE_DIR)
		if err != OK:
			printerr("GameStateManager Error: Could not create save dir: ", SAVE_DIR, " (", err, ")")


func _capture_player_transform() -> void:
	var player_body = GlobalRefs.player_agent_body
	if is_instance_valid(player_body):
		GameState.player_position = player_body.global_transform.origin
		GameState.player_rotation = player_body.rotation_degrees


func _serialize_game_state() -> Dictionary:
	return {
		"player_ship_template_id": GameState.player_ship_template_id,
		"current_sector_id": GameState.current_sector_id,
		"player_docked_at": GameState.player_docked_at,
		"player_position": _serialize_vector3(GameState.player_position),
		"player_rotation": _serialize_vector3(GameState.player_rotation),
		"player_arrived_from_sector": GameState.player_arrived_from_sector,
		"player_arrival_direction": _serialize_vector3(GameState.player_arrival_direction),
	}


func _deserialize_and_apply_game_state(save_data: Dictionary) -> void:
	reset_to_defaults()
	GameState.player_ship_template_id = str(save_data.get("player_ship_template_id", ""))
	GameState.current_sector_id = str(save_data.get("current_sector_id", ""))
	GameState.player_docked_at = str(save_data.get("player_docked_at", ""))
	GameState.player_position = _deserialize_vector3(save_data.get("player_position", {}))
	GameState.player_rotation = _deserialize_vector3(save_data.get("player_rotation", {}))
	GameState.player_arrived_from_sector = str(save_data.get("player_arrived_from_sector", ""))
	GameState.player_arrival_direction = _deserialize_vector3(save_data.get("player_arrival_direction", {}))


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
