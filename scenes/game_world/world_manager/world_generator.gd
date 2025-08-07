# File: scenes/game_world/world_manager/world_generator.gd
# Purpose: Uses indexed templates to procedurally generate the initial game state
#          for a new game, populating the GameState autoload.
# Version: 1.0

extends Node

var _next_character_uid: int = 0
var _next_ship_uid: int = 0
var _next_module_uid: int = 0
var _next_commodity_uid: int = 0

# --- Public API ---

# Main entry point. Generates all necessary data for a new game.
func generate_new_world():
	print("WorldGenerator: Generating new world state...")

	# For this initial implementation, we create one instance of each character
	# template found in the TemplateDatabase.
	for template_id in TemplateDatabase.characters:
		var template = TemplateDatabase.characters[template_id]
		_create_character_from_template(template)

	_generate_and_assign_assets()

	print("WorldGenerator: New world state generated.")


# --- Private Logic ---

# Creates a unique instance of a character from a template and registers it
# in the global GameState.
func _create_character_from_template(template: CharacterTemplate):
	var new_character_instance = template.duplicate()
	var uid = _get_new_character_uid()

	# Populate the GameState directly.
	GameState.characters[uid] = new_character_instance

	# Designate the player character based on a property in the template.
	# We assume a boolean `is_player_character` or a specific template_id.
	if template.template_id == "character_default": # This is a placeholder check
		GameState.player_character_uid = uid
		print("... Player character created with UID: ", uid)
	else:
		print("... NPC character created with UID: ", uid)


# Generates a new, unique ID for a character.
func _get_new_character_uid() -> int:
	var id = _next_character_uid
	_next_character_uid += 1
	return id
	
# This should be called from generate_new_world() after characters are created.
func _generate_and_assign_assets():
	print("WorldGenerator: Generating and assigning starting assets...")
	for char_uid in GameState.characters:
		var character = GameState.characters[char_uid]
		# For now, every character gets a default ship.
		# A more complex generator could use faction_id or character_name to decide.
		_create_and_assign_ship(character, "ship_default")
		_create_and_assign_modules(character)
		_create_and_assign_commodities(character)

# Creates a unique instance of a ship and assigns it to a character.
func _create_and_assign_ship(character: CharacterTemplate, ship_template_id: String):
	if not TemplateDatabase.assets_ships.has(ship_template_id):
		printerr("WorldGenerator Error: Cannot find ship template with id: ", ship_template_id)
		return

	var template = TemplateDatabase.assets_ships[ship_template_id]
	var new_ship_instance = template.duplicate()
	var uid = _get_new_ship_uid()

	# Add the unique ship instance to the global state.
	GameState.assets_ships[uid] = new_ship_instance

	# Link the character to their new ship.
	# NOTE: We need to add `active_ship_uid` to character_template.gd
	character.active_ship_uid = uid
	print("... Assigned ship (UID: %d) to character %s" % [uid, character.character_name])


func _get_new_ship_uid() -> int:
	var id = _next_ship_uid
	_next_ship_uid += 1
	return id

func _create_and_assign_modules(character: CharacterTemplate):
	# For now, every character gets one default module.
	var template = TemplateDatabase.assets_modules["module_default"]
	var new_module_instance = template.duplicate()
	var uid = _get_new_module_uid()

	GameState.assets_modules[uid] = new_module_instance
	# NOTE: We need to add `inventory_modules` to character_template.gd
	character.inventory_modules[uid] = new_module_instance # Store the instance directly for now
	print("... Assigned module (UID: %d) to character %s" % [uid, character.character_name])


func _create_and_assign_commodities(character: CharacterTemplate):
	# For now, every character gets 10 units of the default commodity.
	var template = TemplateDatabase.assets_commodities["commodity_default"]
	var new_commodity_instance = template.duplicate()
	var uid = _get_new_commodity_uid()

	GameState.assets_commodities[uid] = new_commodity_instance
	# NOTE: We need to add `inventory_commodities` to character_template.gd
	# We store the quantity against the template_id, as commodities are fungible.
	character.inventory_commodities[template.template_id] = 10
	print("... Assigned 10 units of %s to character %s" % [template.template_id, character.character_name])


func _get_new_module_uid() -> int:
	var id = _next_module_uid
	_next_module_uid += 1
	return id


func _get_new_commodity_uid() -> int:
	var id = _next_commodity_uid
	_next_commodity_uid += 1
	return id

