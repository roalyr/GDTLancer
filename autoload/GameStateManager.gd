# File: autoload/GameStateManager.gd
# Autoload Singleton: GameStateManager
# Version: 2.4 - Fixed location serialization (Resources not plain dicts).

extends Node

const SAVE_DIR = "user://savegames/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".sav"

# Preload the script to safely access its enums without relying on a live node.
const InventorySystem = preload("res://core/systems/inventory_system.gd")


# --- Public API ---

func reset_to_defaults() -> void:
	GameState.world_seed = ""
	GameState.current_tu = 0
	GameState.player_character_uid = -1
	GameState.player_docked_at = ""

	GameState.characters.clear()
	GameState.active_actions.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.assets_commodities.clear()
	GameState.inventories.clear()
	GameState.locations.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()

	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}

func save_game(slot_id: int = 0) -> bool:
	_ensure_save_dir_exists()
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
	return file.file_exists(path)


func _ensure_save_dir_exists() -> void:
	var dir = Directory.new()
	if not dir.dir_exists(SAVE_DIR):
		var err = dir.make_dir_recursive(SAVE_DIR)
		if err != OK:
			printerr("GameStateManager Error: Could not create save dir: ", SAVE_DIR, " (", err, ")")

# --- Serialization (Live State -> Dictionary) ---

func _serialize_game_state() -> Dictionary:
	var state_dict = {}
	
	state_dict["player_character_uid"] = GameState.player_character_uid
	state_dict["current_tu"] = GameState.current_tu
	state_dict["player_docked_at"] = GameState.player_docked_at
	
	state_dict["characters"] = _serialize_resource_dict(GameState.characters)
	state_dict["assets_ships"] = _serialize_resource_dict(GameState.assets_ships)
	state_dict["assets_modules"] = _serialize_resource_dict(GameState.assets_modules)
	state_dict["inventories"] = _serialize_inventories(GameState.inventories)
	
	# Phase 1 additions - locations are Resources, need proper serialization
	state_dict["locations"] = _serialize_resource_dict_by_string_key(GameState.locations)
	state_dict["contracts"] = _serialize_resource_dict_by_string_key(GameState.contracts)
	state_dict["active_contracts"] = _serialize_resource_dict_by_string_key(GameState.active_contracts)
	state_dict["narrative_state"] = GameState.narrative_state.duplicate(true)
	state_dict["session_stats"] = GameState.session_stats.duplicate(true)
	
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
		serialized_inventories[char_uid] = {
			InventorySystem.InventoryType.SHIP: _serialize_resource_dict(original_inv[InventorySystem.InventoryType.SHIP]),
			InventorySystem.InventoryType.MODULE: _serialize_resource_dict(original_inv[InventorySystem.InventoryType.MODULE]),
			InventorySystem.InventoryType.COMMODITY: original_inv[InventorySystem.InventoryType.COMMODITY].duplicate(true)
		}
	return serialized_inventories

# --- Deserialization (Dictionary -> Live State) ---

func _deserialize_and_apply_game_state(save_data: Dictionary):
	# Clear current state
	GameState.characters.clear()
	GameState.assets_ships.clear()
	GameState.assets_modules.clear()
	GameState.inventories.clear()
	GameState.locations.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()
	
	GameState.player_character_uid = save_data.get("player_character_uid", -1)
	GameState.current_tu = save_data.get("current_tu", 0)
	GameState.player_docked_at = save_data.get("player_docked_at", "")

	GameState.assets_ships = _deserialize_resource_dict(save_data.get("assets_ships", {}))
	GameState.assets_modules = _deserialize_resource_dict(save_data.get("assets_modules", {}))
	GameState.characters = _deserialize_resource_dict(save_data.get("characters", {}))
	GameState.inventories = _deserialize_inventories(save_data.get("inventories", {}))
	
	# Phase 1 additions - locations need to be deserialized back to Resources
	GameState.locations = _deserialize_resource_dict_by_string_key(save_data.get("locations", {}))
	GameState.contracts = _deserialize_resource_dict_by_string_key(save_data.get("contracts", {}))
	GameState.active_contracts = _deserialize_resource_dict_by_string_key(save_data.get("active_contracts", {}))
	
	# Restore narrative state with defaults if not present
	var default_narrative = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"chronicle_entries": []
	}
	var saved_narrative = save_data.get("narrative_state", {})
	for key in default_narrative:
		GameState.narrative_state[key] = saved_narrative.get(key, default_narrative[key])
	
	# Restore session stats with defaults if not present
	var default_stats = {
		"contracts_completed": 0,
		"total_wp_earned": 0,
		"total_wp_spent": 0,
		"enemies_disabled": 0,
		"time_played_tu": 0
	}
	var saved_stats = save_data.get("session_stats", {})
	for key in default_stats:
		GameState.session_stats[key] = saved_stats.get(key, default_stats[key])

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
		
		# --- FIX: Use integer enum values directly as keys for lookup ---
		var ship_key = InventorySystem.InventoryType.SHIP
		var module_key = InventorySystem.InventoryType.MODULE
		var commodity_key = InventorySystem.InventoryType.COMMODITY
		
		inv_dict[char_uid] = {
			InventorySystem.InventoryType.SHIP: _deserialize_resource_dict(original_inv.get(ship_key, {})),
			InventorySystem.InventoryType.MODULE: _deserialize_resource_dict(original_inv.get(module_key, {})),
			InventorySystem.InventoryType.COMMODITY: original_inv.get(commodity_key, {}).duplicate(true)
		}
		# --- END FIX ---
	return inv_dict

# Helper to find a template by its ID across all categories in the database.
func _find_template_in_database(template_id: String) -> Resource:
	if TemplateDatabase.characters.has(template_id):
		return TemplateDatabase.characters[template_id]
	if TemplateDatabase.assets_ships.has(template_id):
		return TemplateDatabase.assets_ships[template_id]
	if TemplateDatabase.assets_modules.has(template_id):
		return TemplateDatabase.assets_modules[template_id]
	if TemplateDatabase.locations.has(template_id):
		return TemplateDatabase.locations[template_id]
	if TemplateDatabase.contracts.has(template_id):
		return TemplateDatabase.contracts[template_id]
	# Add other template types here as needed...
	return null
