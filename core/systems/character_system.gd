# File: core/systems/character_system.gd
# Purpose: Manages the gloabl dictionary of characters (both player and NPCs).
# Version: 2.0 - Reworked to match new templates.

extends Node

# TODO: instantiate CharacterTemplate resource directly and put instances into this dictionary?
# Global dictionary of _character_data instances.
var _characters: Dictionary = {}

# Derive dictionary fields from CharacterTemplate class for consistency!
# TODO: Link fields from character_template.gd
var _character_data: Dictionary = {} # Or CharacterTemplate instance?

func _ready():
	GlobalRefs.set_character_system(self)
	print("CharacterSystem Ready.")

# --- Public API ---

# func get_character() -> Dictionary:
	# Return a copy to prevent direct modification of the internal state.
	

func add_wp(amount: int):
	# Iterate over all characters
	for i in _characters.size():
		_characters[i].wealth_points += amount

func subtract_wp(amount: int):
	# Iterate over all characters
	for i in _characters.size():
		_characters[i].wealth_points -= amount

func get_wp(character: String) -> int:
	return _characters[character].wealth_points

func add_fp(character: String, amount: int):
	_characters[character].focus_points += amount
	_characters[character].focus_points = clamp(_characters[character].focus_points, 0, Constants.FOCUS_MAX_DEFAULT)

func subtract_fp(character: String, amount: int):
	_characters[character].focus_points -= amount
	_characters[character].focus_points = clamp(_characters[character].focus_points, 0, Constants.FOCUS_MAX_DEFAULT)

func get_fp(character: String) -> int:
	return _characters[character].focus_points

func get_skill_level(character: String, skill_name: String) -> int:
	if _characters[character].skills.has(skill_name):
		return _characters[character].skills[skill_name]
	return 0

func apply_upkeep_cost(cost: int):
	subtract_wp(cost)

func get_player_save_data() -> Dictionary: # Return proper type
	# Placeholder. Should be in _characters dictionary
	_characters["player"] = {}
	return _characters["player"].duplicate(true)

func load_player_save_data(data: Dictionary): # Return proper type
	_characters["player"] = data
