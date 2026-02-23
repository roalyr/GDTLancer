#
# PROJECT: GDTLancer
# MODULE: GameStateManager.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 8 (Simulation Architecture)
# LOG_REF: 2026-02-13
#

extends Node

## GameStateManager: Handles save/load operations for the four-layer GameState.
## Serializes and deserializes all simulation and scene data to/from savegame files.

const SAVE_DIR = "user://savegames/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".sav"

# Preload the script to safely access its enums without relying on a live node.
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")


# --- Public API ---

func reset_to_defaults() -> void:
	# --- Simulation Meta ---
	GameState.world_seed = ""
	GameState.game_time_seconds = 0
	GameState.sim_tick_count = 0
	GameState.player_character_uid = ""

	# --- Scene State ---
	GameState.player_docked_at = ""
	GameState.player_position = Vector3.ZERO
	GameState.player_rotation = Vector3.ZERO

	# --- Layer 1: World ---
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.world_tags = []
	GameState.sector_tags.clear()

	# --- Layer 2: Grid ---
	GameState.grid_dominion.clear()
	GameState.colony_levels.clear()
	GameState.colony_upgrade_progress.clear()
	GameState.colony_downgrade_progress.clear()
	GameState.security_upgrade_progress.clear()
	GameState.security_downgrade_progress.clear()
	GameState.security_change_threshold.clear()
	GameState.economy_upgrade_progress.clear()
	GameState.economy_downgrade_progress.clear()
	GameState.economy_change_threshold.clear()
	GameState.hostile_infestation_progress.clear()

	# --- Layer 3: Agents ---
	GameState.characters.clear()
	GameState.agents.clear()
	GameState.agent_tags.clear()
	GameState.assets_ships.clear()
	GameState.inventories.clear()

	# --- Layer 4: Chronicle ---
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []

	# --- Legacy (kept for compatibility) ---
	GameState.locations.clear()
	GameState.factions.clear()
	GameState.assets_commodities.clear()
	GameState.persistent_agents.clear()

func save_game(slot_id: int = 0) -> bool:
	_ensure_save_dir_exists()
	
	# Capture current player position and rotation before serializing
	_capture_player_transform()
	
	var save_data = _serialize_game_state()
	if save_data.empty():
		printerr("GameStateManager Error: Failed to serialize game state.")
		return false

	var file = File.new()
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT
	var err = file.open(path, File.WRITE)

	if err == OK:
		file.store_var(save_data, true)
		file.close()
		print("Game saved successfully to: ", path)
		return true
	else:
		printerr("Error saving game to path: ", path, " Error code: ", err)
		file.close()
		return false


func _capture_player_transform() -> void:
	var player_body = GlobalRefs.player_agent_body
	if is_instance_valid(player_body):
		GameState.player_position = player_body.global_transform.origin
		GameState.player_rotation = player_body.rotation_degrees


func load_game(slot_id: int = 0) -> bool:
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT
	var file = File.new()

	if not file.file_exists(path):
		printerr("Load Error: Save file not found at path: ", path)
		return false

	var err = file.open(path, File.READ)
	if err != OK:
		printerr("Load Error: Failed to open file! Error code: ", err)
		return false

	var save_data = file.get_var(true)
	file.close()

	if not save_data is Dictionary:
		printerr("Load Error: Save data is not a Dictionary.")
		return false
	
	_deserialize_and_apply_game_state(save_data)
	
	EventBus.emit_signal("game_state_loaded")
	print("Game state loaded successfully. Emitted game_state_loaded signal.")
	return true


func has_save_file(slot_id: int = 0) -> bool:
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot_id) + SAVE_FILE_EXT
	var file = File.new()
	if not file.file_exists(path):
		return false

	# Treat corrupt/empty saves as non-existent for UI purposes.
	var err = file.open(path, File.READ)
	if err != OK:
		file.close()
		return false
	var save_data = file.get_var(true)
	file.close()
	if not (save_data is Dictionary):
		return false
	return _is_save_data_valid(save_data)


func _is_save_data_valid(save_data: Dictionary) -> bool:
	# Minimal validity checks so we don't offer "Load" when it can't restore a playable state.
	var player_uid := int(save_data.get("player_character_uid", -1))
	if player_uid < 0:
		return false
	var characters = save_data.get("characters", null)
	if not (characters is Dictionary) or characters.empty():
		return false
	var locations = save_data.get("locations", null)
	if not (locations is Dictionary) or locations.empty():
		return false
	return true


func _ensure_save_dir_exists() -> void:
	var dir = Directory.new()
	if not dir.dir_exists(SAVE_DIR):
		var err = dir.make_dir_recursive(SAVE_DIR)
		if err != OK:
			printerr("GameStateManager Error: Could not create save dir: ", SAVE_DIR, " (", err, ")")

# --- Serialization (Live State -> Dictionary) ---

func _serialize_game_state() -> Dictionary:
	var state_dict = {}

	# --- Simulation Meta ---
	state_dict["player_character_uid"] = GameState.player_character_uid
	state_dict["game_time_seconds"] = GameState.game_time_seconds
	state_dict["sim_tick_count"] = GameState.sim_tick_count
	state_dict["world_seed"] = GameState.world_seed
	state_dict["player_docked_at"] = GameState.player_docked_at
	state_dict["player_position"] = _serialize_vector3(GameState.player_position)
	state_dict["player_rotation"] = _serialize_vector3(GameState.player_rotation)

	# --- Layer 1: World (static, but saved for deterministic restore) ---
	state_dict["world_topology"] = GameState.world_topology.duplicate(true)
	state_dict["world_hazards"] = GameState.world_hazards.duplicate(true)
	state_dict["world_tags"] = GameState.world_tags.duplicate()
	state_dict["sector_tags"] = GameState.sector_tags.duplicate(true)

	# --- Layer 2: Grid ---
	state_dict["grid_dominion"] = GameState.grid_dominion.duplicate(true)
	state_dict["colony_levels"] = GameState.colony_levels.duplicate(true)
	state_dict["colony_upgrade_progress"] = GameState.colony_upgrade_progress.duplicate(true)
	state_dict["colony_downgrade_progress"] = GameState.colony_downgrade_progress.duplicate(true)
	state_dict["security_upgrade_progress"] = GameState.security_upgrade_progress.duplicate(true)
	state_dict["security_downgrade_progress"] = GameState.security_downgrade_progress.duplicate(true)
	state_dict["security_change_threshold"] = GameState.security_change_threshold.duplicate(true)
	state_dict["economy_upgrade_progress"] = GameState.economy_upgrade_progress.duplicate(true)
	state_dict["economy_downgrade_progress"] = GameState.economy_downgrade_progress.duplicate(true)
	state_dict["economy_change_threshold"] = GameState.economy_change_threshold.duplicate(true)
	state_dict["hostile_infestation_progress"] = GameState.hostile_infestation_progress.duplicate(true)

	# --- Layer 3: Agents ---
	state_dict["characters"] = _serialize_resource_dict(GameState.characters)
	state_dict["agents"] = GameState.agents.duplicate(true)
	state_dict["agent_tags"] = GameState.agent_tags.duplicate(true)
	state_dict["assets_ships"] = _serialize_resource_dict(GameState.assets_ships)
	state_dict["inventories"] = _serialize_inventories(GameState.inventories)

	# --- Layer 4: Chronicle ---
	state_dict["chronicle_events"] = GameState.chronicle_events.duplicate(true)
	state_dict["chronicle_rumors"] = GameState.chronicle_rumors.duplicate(true)

	# --- Legacy ---
	state_dict["locations"] = _serialize_resource_dict_by_string_key(GameState.locations)
	state_dict["factions"] = _serialize_resource_dict_by_string_key(GameState.factions)

	return state_dict

func _serialize_resource(res: Resource) -> Dictionary:
	var dict = {}
	if not is_instance_valid(res):
		return dict
		
	dict["template_id"] = res.template_id
	
	for prop in res.get_script().get_script_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE:
			dict[prop.name] = res.get(prop.name)
			
	return dict

func _serialize_resource_dict(res_dict: Dictionary) -> Dictionary:
	var serialized_dict = {}
	for uid in res_dict:
		serialized_dict[uid] = _serialize_resource(res_dict[uid])
	return serialized_dict

# Same as above but for dictionaries with String keys (like locations)
func _serialize_resource_dict_by_string_key(res_dict: Dictionary) -> Dictionary:
	var serialized_dict = {}
	for key in res_dict:
		var res = res_dict[key]
		if res is Resource:
			serialized_dict[key] = _serialize_resource(res)
		else:
			# Already a plain dict
			serialized_dict[key] = res.duplicate(true) if res is Dictionary else res
	return serialized_dict

func _serialize_inventories(inv_dict: Dictionary) -> Dictionary:
	var serialized_inventories = {}
	for char_uid in inv_dict:
		var original_inv = inv_dict[char_uid]
		# Keys may be int (from live state) or String (from a loaded save).
		# Try both forms to handle load→save round-trips safely.
		var ship_key = InventorySystem.InventoryType.SHIP      # 0
		var module_key = InventorySystem.InventoryType.MODULE   # 1
		var commodity_key = InventorySystem.InventoryType.COMMODITY # 2
		var ships = original_inv.get(ship_key, original_inv.get(str(ship_key), {}))
		var modules = original_inv.get(module_key, original_inv.get(str(module_key), {}))
		var commodities = original_inv.get(commodity_key, original_inv.get(str(commodity_key), {}))
		serialized_inventories[char_uid] = {
			ship_key: _serialize_resource_dict(ships),
			module_key: _serialize_resource_dict(modules),
			commodity_key: commodities.duplicate(true) if commodities is Dictionary else commodities
		}
	return serialized_inventories

# --- Deserialization (Dictionary -> Live State) ---

func _deserialize_and_apply_game_state(save_data: Dictionary):
	# Clear current state
	reset_to_defaults()

	# --- Simulation Meta ---
	GameState.player_character_uid = save_data.get("player_character_uid", "")
	GameState.game_time_seconds = save_data.get("game_time_seconds", save_data.get("current_tu", 0))
	GameState.sim_tick_count = save_data.get("sim_tick_count", 0)
	GameState.world_seed = save_data.get("world_seed", "")
	GameState.player_docked_at = save_data.get("player_docked_at", "")
	GameState.player_position = _deserialize_vector3(save_data.get("player_position", {}))
	GameState.player_rotation = _deserialize_vector3(save_data.get("player_rotation", {}))

	# --- Layer 1: World ---
	GameState.world_topology = save_data.get("world_topology", {}).duplicate(true) if save_data.has("world_topology") else {}
	GameState.world_hazards = save_data.get("world_hazards", {}).duplicate(true) if save_data.has("world_hazards") else {}
	GameState.world_tags = save_data.get("world_tags", []).duplicate() if save_data.has("world_tags") else []
	GameState.sector_tags = save_data.get("sector_tags", {}).duplicate(true) if save_data.has("sector_tags") else {}

	# --- Layer 2: Grid ---
	GameState.grid_dominion = save_data.get("grid_dominion", {}).duplicate(true) if save_data.has("grid_dominion") else {}
	GameState.colony_levels = save_data.get("colony_levels", {}).duplicate(true) if save_data.has("colony_levels") else {}
	GameState.colony_upgrade_progress = save_data.get("colony_upgrade_progress", {}).duplicate(true) if save_data.has("colony_upgrade_progress") else {}
	GameState.colony_downgrade_progress = save_data.get("colony_downgrade_progress", {}).duplicate(true) if save_data.has("colony_downgrade_progress") else {}
	GameState.security_upgrade_progress = save_data.get("security_upgrade_progress", {}).duplicate(true) if save_data.has("security_upgrade_progress") else {}
	GameState.security_downgrade_progress = save_data.get("security_downgrade_progress", {}).duplicate(true) if save_data.has("security_downgrade_progress") else {}
	GameState.security_change_threshold = save_data.get("security_change_threshold", {}).duplicate(true) if save_data.has("security_change_threshold") else {}
	GameState.economy_upgrade_progress = save_data.get("economy_upgrade_progress", {}).duplicate(true) if save_data.has("economy_upgrade_progress") else {}
	GameState.economy_downgrade_progress = save_data.get("economy_downgrade_progress", {}).duplicate(true) if save_data.has("economy_downgrade_progress") else {}
	GameState.economy_change_threshold = save_data.get("economy_change_threshold", {}).duplicate(true) if save_data.has("economy_change_threshold") else {}
	GameState.hostile_infestation_progress = save_data.get("hostile_infestation_progress", {}).duplicate(true) if save_data.has("hostile_infestation_progress") else {}

	# --- Layer 3: Agents ---
	GameState.assets_ships = _deserialize_resource_dict(save_data.get("assets_ships", {}))
	GameState.characters = _deserialize_resource_dict(save_data.get("characters", {}))
	GameState.agents = save_data.get("agents", {}).duplicate(true) if save_data.has("agents") else {}
	GameState.agent_tags = save_data.get("agent_tags", {}).duplicate(true) if save_data.has("agent_tags") else {}
	GameState.inventories = _deserialize_inventories(save_data.get("inventories", {}))

	# --- Layer 4: Chronicle ---
	GameState.chronicle_events = save_data.get("chronicle_events", []).duplicate(true) if save_data.has("chronicle_events") else []
	GameState.chronicle_rumors = save_data.get("chronicle_rumors", []).duplicate(true) if save_data.has("chronicle_rumors") else []

	# --- Legacy ---
	GameState.locations = _deserialize_resource_dict_by_string_key(save_data.get("locations", {}))
	GameState.factions = _deserialize_resource_dict_by_string_key(save_data.get("factions", {}))

func _deserialize_resource(res_data: Dictionary) -> Resource:
	if not res_data.has("template_id"):
		return null
	
	var template_id = res_data["template_id"]
	var template = _find_template_in_database(template_id)
	
	if not is_instance_valid(template):
		printerr("Deserialize Error: Could not find template with id '", template_id, "' in TemplateDatabase.")
		return null
		
	var instance = template.duplicate()
	for key in res_data:
		if key != "template_id":
			instance.set(key, res_data[key])
			
	return instance

func _deserialize_resource_dict(serialized_dict: Dictionary) -> Dictionary:
	var res_dict = {}
	for uid_str in serialized_dict:
		var uid = int(uid_str)
		res_dict[uid] = _deserialize_resource(serialized_dict[uid_str])
	return res_dict

# Same but for string-keyed dicts (like locations)
func _deserialize_resource_dict_by_string_key(serialized_dict: Dictionary) -> Dictionary:
	var res_dict = {}
	for key in serialized_dict:
		var data = serialized_dict[key]
		if data is Dictionary and data.has("template_id"):
			res_dict[key] = _deserialize_resource(data)
		else:
			# Plain dict, just duplicate
			res_dict[key] = data.duplicate(true) if data is Dictionary else data
	return res_dict

func _deserialize_inventories(serialized_inv: Dictionary) -> Dictionary:
	var inv_dict = {}
	for char_uid_str in serialized_inv:
		var char_uid = int(char_uid_str)
		var original_inv = serialized_inv[char_uid_str]
		
		# Keys may be int (from enum) or String (from JSON round-trip).
		# Try both forms to handle either case safely.
		var ship_key = InventorySystem.InventoryType.SHIP        # 0
		var module_key = InventorySystem.InventoryType.MODULE     # 1
		var commodity_key = InventorySystem.InventoryType.COMMODITY # 2
		var ships = original_inv.get(ship_key, original_inv.get(str(ship_key), {}))
		var modules = original_inv.get(module_key, original_inv.get(str(module_key), {}))
		var commodities = original_inv.get(commodity_key, original_inv.get(str(commodity_key), {}))
		
		inv_dict[char_uid] = {
			ship_key: _deserialize_resource_dict(ships),
			module_key: _deserialize_resource_dict(modules),
			commodity_key: commodities.duplicate(true) if commodities is Dictionary else commodities
		}
	return inv_dict

# Helper to find a template by its ID across all categories in the database.
func _find_template_in_database(template_id: String) -> Resource:
	if TemplateDatabase.characters.has(template_id):
		return TemplateDatabase.characters[template_id]
	if TemplateDatabase.assets_ships.has(template_id):
		return TemplateDatabase.assets_ships[template_id]
	if TemplateDatabase.locations.has(template_id):
		return TemplateDatabase.locations[template_id]
	if TemplateDatabase.factions.has(template_id):
		return TemplateDatabase.factions[template_id]
	# NOTE: assets_modules and contracts lookups removed — pruned in sim rework.
	return null


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
