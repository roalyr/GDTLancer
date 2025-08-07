# File: scenes/game_world/world_manager/world_generator.gd
# Purpose: Uses indexed templates to procedurally generate the initial game state
#          for a new game, populating the GameState autoload.
# Version: 2.0 - Updated to use the unified InventorySystem.

extends Node

var _next_character_uid: int = 0
var _next_ship_uid: int = 0
var _next_module_uid: int = 0
# Commodity UIDs are no longer needed as they are not unique instances.

# --- Public API ---

# Main entry point. Generates all necessary data for a new game.
func generate_new_world():
	print("WorldGenerator: Generating new world state...")

	# Create characters first.
	for template_id in TemplateDatabase.characters:
		var template = TemplateDatabase.characters[template_id]
		_create_character_from_template(template)

	# Then, generate and assign their starting assets and inventories.
	_generate_and_assign_assets()

	print("WorldGenerator: New world state generated.")


# --- Private Logic ---

# Creates a unique instance of a character from a template and registers it
# in the global GameState. It also creates their inventory.
func _create_character_from_template(template: CharacterTemplate):
	var new_character_instance = template.duplicate()
	var uid = _get_new_character_uid()

	# Populate the GameState with the new character.
	GameState.characters[uid] = new_character_instance

	# --- NEW: Create an inventory record for this character ---
	if is_instance_valid(GlobalRefs.inventory_system):
		GlobalRefs.inventory_system.create_inventory_for_character(uid)
	# --- END NEW ---

	# Designate the player character.
	if template.template_id == "character_default":
		GameState.player_character_uid = uid
		print("... Player character created with UID: ", uid)
	else:
		print("... NPC character created with UID: ", uid)


# Generates starting assets and assigns them to characters using the InventorySystem.
func _generate_and_assign_assets():
	print("WorldGenerator: Generating and assigning starting assets...")
	for char_uid in GameState.characters:
		var character = GameState.characters[char_uid]
		
		# Create and assign a starting ship.
		var ship_uid = _create_ship_instance("ship_default")
		if ship_uid != -1:
			# Add the ship to the character's inventory.
			GlobalRefs.inventory_system.add_asset(char_uid, GlobalRefs.inventory_system.InventoryType.SHIP, ship_uid)
			# Set this ship as the character's active vessel.
			character.active_ship_uid = ship_uid
			print("... Assigned ship (UID: %d) to character %s" % [ship_uid, character.character_name])

		# Create and assign a starting module.
		var module_uid = _create_module_instance("module_default")
		if module_uid != -1:
			GlobalRefs.inventory_system.add_asset(char_uid, GlobalRefs.inventory_system.InventoryType.MODULE, module_uid)
			print("... Assigned module (UID: %d) to character %s" % [module_uid, character.character_name])
			
		# Assign starting commodities.
		GlobalRefs.inventory_system.add_asset(char_uid, GlobalRefs.inventory_system.InventoryType.COMMODITY, "commodity_default", 10)
		print("... Assigned 10 units of commodity_default to character %s" % character.character_name)


# Creates a unique instance of a ship and returns its UID.
func _create_ship_instance(ship_template_id: String) -> int:
	if not TemplateDatabase.assets_ships.has(ship_template_id):
		printerr("WorldGenerator Error: Cannot find ship template with id: ", ship_template_id)
		return -1

	var template = TemplateDatabase.assets_ships[ship_template_id]
	var new_ship_instance = template.duplicate()
	var uid = _get_new_ship_uid()
	GameState.assets_ships[uid] = new_ship_instance
	return uid


# Creates a unique instance of a module and returns its UID.
func _create_module_instance(module_template_id: String) -> int:
	if not TemplateDatabase.assets_modules.has(module_template_id):
		printerr("WorldGenerator Error: Cannot find module template with id: ", module_template_id)
		return -1
		
	var template = TemplateDatabase.assets_modules[module_template_id]
	var new_module_instance = template.duplicate()
	var uid = _get_new_module_uid()
	GameState.assets_modules[uid] = new_module_instance
	return uid


# --- UID Generation ---
func _get_new_character_uid() -> int:
	var id = _next_character_uid
	_next_character_uid += 1
	return id

func _get_new_ship_uid() -> int:
	var id = _next_ship_uid
	_next_ship_uid += 1
	return id

func _get_new_module_uid() -> int:
	var id = _next_module_uid
	_next_module_uid += 1
	return id
