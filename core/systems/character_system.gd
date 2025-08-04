# File: core/systems/character_system.gd
# Purpose: Manages the player's core stats, skills, and narrative data.
# Version: 1.1

extends Node

# --- Data Structures ---
var _player_character_data: Dictionary = {
	"wealth_points": 0,
	"focus_points": 0,
	"skills": {
		"piloting": 1,
		"tactics": 1,
		"trading": 1
	},
	"reputation": 0,
	"faction_standings": {} # e.g., {"pirates": -10, "corp": 5}
}

func _ready():
	GlobalRefs.set_character_system(self)
	print("CharacterSystem Ready.")

# --- Public API ---

func get_player_character() -> Dictionary:
	# Return a copy to prevent direct modification of the internal state.
	return _player_character_data.duplicate(true)

func add_wp(amount: int):
	_player_character_data.wealth_points += amount

func subtract_wp(amount: int):
	_player_character_data.wealth_points -= amount

func get_wp() -> int:
	return _player_character_data.wealth_points

func add_fp(amount: int):
	_player_character_data.focus_points += amount
	_player_character_data.focus_points = clamp(_player_character_data.focus_points, 0, Constants.FOCUS_MAX_DEFAULT)

func subtract_fp(amount: int):
	_player_character_data.focus_points -= amount
	_player_character_data.focus_points = clamp(_player_character_data.focus_points, 0, Constants.FOCUS_MAX_DEFAULT)

func get_fp() -> int:
	return _player_character_data.focus_points

func get_skill_level(skill_name: String) -> int:
	if _player_character_data.skills.has(skill_name):
		return _player_character_data.skills[skill_name]
	return 0

func apply_upkeep_cost(cost: int):
	subtract_wp(cost)

func get_player_save_data() -> Dictionary:
	return _player_character_data.duplicate(true)

func load_player_save_data(data: Dictionary):
	_player_character_data = data
