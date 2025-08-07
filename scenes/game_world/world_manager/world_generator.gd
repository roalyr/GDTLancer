# File: scenes/game_world/world_manager/world_generator.gd
# Purpose: Uses indexed templates to procedurally generate the initial game state
#          for a new game, populating the GameState autoload.
# Version: 1.0

extends Node

var _next_character_uid: int = 0

# --- Public API ---

# Main entry point. Generates all necessary data for a new game.
func generate_new_world():
	print("WorldGenerator: Generating new world state...")

	# For this initial implementation, we create one instance of each character
	# template found in the TemplateDatabase.
	for template_id in TemplateDatabase.characters:
		var template = TemplateDatabase.characters[template_id]
		_create_character_from_template(template)

	# TODO: This is where we would generate starting assets, inventories,
	# faction standings, etc., and populate the GameState object.
	# For example:
	# _generate_starting_assets()
	# _assign_assets_to_characters()

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
