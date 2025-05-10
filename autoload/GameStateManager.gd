# File: autoload/GameStateManager.gd
# Autoload Singleton: GameStateManager
# Purpose: Handles saving and loading game state.
# Version: 1.1 - Corrected ProjectSettings.get_setting for Godot 3

extends Node

const SAVE_DIR = "user://savegames/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".sav"  # Godot's variant storage format


func _ready():
	print("GameStateManager Ready.")
	# Ensure save directory exists on startup
	var dir = Directory.new()
	if not dir.dir_exists(SAVE_DIR):
		var err = dir.make_dir_recursive(SAVE_DIR)
		if err != OK:
			printerr(
				"GameStateManager Error: Could not create save directory: ",
				SAVE_DIR,
				" Error: ",
				err
			)


# --- Save Game ---
# Returns true on success, false on failure
func save_game(slot_id: int) -> bool:
	print("Attempting to save game to slot ", slot_id)
	var save_data = {}  # Dictionary to hold all save data

	# --- (Gathering Data) ---
	# 1. Player Data
	if is_instance_valid(GlobalRefs.player_agent_body):
		var player_data = {}
		player_data["scene_path"] = Constants.PLAYER_AGENT_SCENE_PATH
		player_data["position_x"] = GlobalRefs.player_agent_body.global_transform.origin.x
		player_data["position_y"] = GlobalRefs.player_agent_body.global_transform.origin.y
		player_data["position_z"] = GlobalRefs.player_agent_body.global_transform.origin.z
		player_data["rotation_basis_cols"] = [
			GlobalRefs.player_agent_body.global_transform.basis.x,
			GlobalRefs.player_agent_body.global_transform.basis.y,
			GlobalRefs.player_agent_body.global_transform.basis.z
		]
		player_data["position_z"] = GlobalRefs.player_agent_body.global_transform.origin.z
		save_data["player_state"] = player_data
	else:
		printerr("Save Error: Player agent body not valid!")
		return false

	# 2. Character System Data (FP, WP, Skills, etc.) - Assumed Placeholder
	if (
		is_instance_valid(GlobalRefs.character_system)
		and GlobalRefs.character_system.has_method("get_player_save_data")
	):
		save_data["character_state"] = GlobalRefs.character_system.get_player_save_data()
	else:
		print("Save Warning: CharacterSystem missing or no save method. FP/WP/Skills NOT saved.")

	# 3. World State
	var world_data = {}
	if is_instance_valid(GlobalRefs.current_zone):
		world_data["current_zone_path"] = GlobalRefs.current_zone.filename
	else:
		printerr("Save Error: Current zone reference invalid!")
		return false
	# TODO: Add Time Clock Value - Requires Time System/Manager reference
	# world_data["time_clock_tu"] = GlobalRefs.time_manager.get_current_tu()
	save_data["world_state"] = world_data

	# 4. Goal System State - Assumed Placeholder
	# if is_instance_valid(GlobalRefs.goal_system) and GlobalRefs.goal_system.has_method("get_save_data"):
	#     save_data["goal_system_state"] = GlobalRefs.goal_system.get_save_data()

	# 5. Add Metadata
	# *** CORRECTED for Godot 3 ***
	var game_version_setting = ProjectSettings.get_setting("application/config/version")
	var game_version = "0.0.1"  # Default version
	if game_version_setting != null:
		game_version = str(game_version_setting)  # Ensure it's a string if found
	# *** END CORRECTION ***

	save_data["metadata"] = {"save_time": OS.get_unix_time(), "game_version": game_version}

	# --- Writing File ---
	var file = File.new()
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT
	var err = file.open(path, File.WRITE)

	if err == OK:
		# Use true for share/compression - valid in Godot 3
		file.store_var(save_data, true)
		file.close()
		print("Game saved successfully to: ", path)
		return true
	else:
		printerr("Error saving game to path: ", path, " Error code: ", err)
		file.close()  # Ensure file is closed even on error
		return false


# --- Load Game ---
# Returns true on success, false on failure
func load_game(slot_id: int) -> bool:
	print("Load attempt for slot ", slot_id)
	var path = get_save_slot_path(slot_id)
	print("Load path: ", path)

	var file = File.new()
	if not file.file_exists(path):
		printerr("Load Error: Save file not found at path!")
		return false

	print("Load Debug: File exists. Attempting to open...")
	var err = file.open(path, File.READ)
	if err != OK:
		printerr("Load Error: Failed to open file for reading! Error code: ", err)
		return false

	print("Load Debug: File opened. Attempting to get var...")
	# Use true if store_var used true
	var save_data = file.get_var(true)
	var file_err = file.get_error()  # Check error *after* operation
	file.close()  # Close file immediately

	if file_err != OK:
		printerr("Load Error: Error reading var from file! File Error code: ", file_err)
		return false

	print("Load Debug: Got var. Checking type...")
	if not save_data is Dictionary:
		printerr("Load Error: Save file data is not a Dictionary! Type is: ", typeof(save_data))
		return false

	print("Save file loaded successfully. Applying state...")
	# ... (Placeholder apply logic) ...
	EventBus.emit_signal("game_loaded", save_data)
	return true

	# --- Apply Loaded State ---
	# This section requires careful coordination with scene loading and initialization.
	# It might need to emit signals or use call_deferred extensively.
	# Placeholder logic - assumes this is called from a state where loading is safe (e.g., main menu)

	# 1. Request Zone Load (WorldManager listens for this?) - NEEDS A ROBUST WORKFLOW
	if save_data.has("world_state") and save_data.world_state.has("current_zone_path"):
		var zone_path = save_data.world_state.current_zone_path
		if (
			is_instance_valid(GlobalRefs.world_manager)
			and GlobalRefs.world_manager.has_method("load_zone")
		):
			# Ideally, loading should happen via scene transition, not direct call here.
			# For now, just logging. Actual loading needs proper handling.
			print("Load Request: Need to load zone: ", zone_path)
			# GlobalRefs.world_manager.load_zone(zone_path) # Direct call here is usually problematic
			# Need a system to handle scene transition THEN player spawn/restore
			# Emit signal instead? EventBus.emit_signal("load_zone_requested", zone_path, save_data)
		else:
			printerr("Load Error: Cannot request zone load, WorldManager invalid/missing method.")
			return false
	else:
		printerr("Load Error: Save data missing world state or zone path.")
		return false

	# 2. Restore Player State (Should happen AFTER zone is loaded)
	# This logic needs to be triggered *after* the scene transition and player spawn.
	# Placeholder - This should be handled by CharacterSystem reacting to load event or player spawn
	if save_data.has("player_state"):
		var p_state = save_data.player_state
		var p_pos = Vector3(
			p_state.get("position_x", 0), p_state.get("position_y", 0), p_state.get("position_z", 0)
		)
		var p_basis_cols = p_state.get(
			"rotation_basis_cols", [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
		var p_basis = Basis(p_basis_cols[0], p_basis_cols[1], p_basis_cols[2])
		# Need to apply pos/rot AFTER player is spawned in the new zone.
		print("Load Request: Player should spawn at ", p_pos, " with rotation")

	if save_data.has("character_state"):
		# CharacterSystem should listen for game_loaded or player_spawned signal
		# and apply this data to the player agent
		print("Load Request: Character state needs restore: ", save_data.character_state)
		# GlobalRefs.character_system.load_save_data(save_data.character_state)

	# 3. Restore Time Clock
	# print("Load Request: Time clock needs restore")
	# GlobalRefs.time_manager.load_save_data(...)

	# 4. Restore Goal System State
	# print("Load Request: Goals need restore")
	# GlobalRefs.goal_system.load_save_data(...)

	# 5. Restore Persistent NPCs (Later Phase)

	# 6. Emit signal that load data is ready (systems should listen and apply)
	print("Load Process: Emitting game_loaded signal...")
	EventBus.emit_signal("game_loaded", save_data)  # Pass full data

	# IMPORTANT: Returning true here only means the file was read.
	# Actual game state restoration is asynchronous and depends on listeners.
	return true


# --- Helper Functions ---
func get_save_slot_path(slot_id: int) -> String:
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT


func save_exists(slot_id: int) -> bool:
	var file = File.new()
	return file.file_exists(get_save_slot_path(slot_id))


# Gets only the metadata part of a save file, if possible
func get_save_metadata(slot_id: int) -> Dictionary:
	var path = get_save_slot_path(slot_id)
	var file = File.new()
	if not file.file_exists(path):
		return {}
	var err = file.open(path, File.READ)
	if err != OK:
		return {}
	# Use false here if we ONLY want the top-level dict, not full object parsing
	# Depends if metadata is stored simply at top level
	var data = file.get_var(true)
	file.close()
	if data is Dictionary and data.has("metadata"):
		return data.metadata
	# Try parsing non-shared if metadata is simple? Might fail on complex saves.
	# var file2 = File.new(); file2.open(path, File.READ); var data2 = file2.get_var(false); file2.close()
	# if data2 is Dictionary and data2.has("metadata"): return data2.metadata
	print("Warning: Could not read metadata from save slot ", slot_id)
	return {}
