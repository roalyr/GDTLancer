#
# PROJECT: GDTLancer
# MODULE: character_system.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-28-QA-Intern
#

extends Node

## CharacterSystem: Stateless API for character data management.
## Provides credits, FP, and skill operations on CharacterTemplate instances in GameState.


func _ready():
	GlobalRefs.set_character_system(self)
	print("CharacterSystem Ready.")


# --- Public API ---


# Retrieves a character instance from the GameState.
func get_character(character_uid: int) -> CharacterTemplate:
	return GameState.characters.get(character_uid)


# Convenience function to get the player's character instance.
func get_player_character() -> CharacterTemplate:
	if GameState.player_character_uid != -1:
		return GameState.characters.get(GameState.player_character_uid)
	return null


# Convenience function to get the player's UID.
func get_player_character_uid() -> int:
	return GameState.player_character_uid


# --- Stat Modification API (Operates on GameState) ---


func add_credits(character_uid: int, amount: int):
	if GameState.characters.has(character_uid):
		GameState.characters[character_uid].credits += amount
		# If this change was for the player, announce it.
		if character_uid == GameState.player_character_uid:
			EventBus.emit_signal("player_credits_changed", GameState.characters[character_uid].credits)


func subtract_credits(character_uid: int, amount: int):
	if GameState.characters.has(character_uid):
		GameState.characters[character_uid].credits -= amount
		# If this change was for the player, announce it.
		if character_uid == GameState.player_character_uid:
			EventBus.emit_signal("player_credits_changed", GameState.characters[character_uid].credits)


func get_credits(character_uid: int) -> int:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].credits
	return 0


func add_fp(character_uid: int, amount: int):
	if GameState.characters.has(character_uid):
		var character = GameState.characters[character_uid]
		character.focus_points += amount
		character.focus_points = clamp(character.focus_points, 0, Constants.FOCUS_MAX_DEFAULT)
		# If this change was for the player, announce it.
		if character_uid == GameState.player_character_uid:
			EventBus.emit_signal("player_fp_changed", character.focus_points)


func subtract_fp(character_uid: int, amount: int):
	if GameState.characters.has(character_uid):
		var character = GameState.characters[character_uid]
		character.focus_points -= amount
		character.focus_points = clamp(character.focus_points, 0, Constants.FOCUS_MAX_DEFAULT)
		# If this change was for the player, announce it.
		if character_uid == GameState.player_character_uid:
			EventBus.emit_signal("player_fp_changed", character.focus_points)


func get_fp(character_uid: int) -> int:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].focus_points
	return 0


func get_skill_level(character_uid: int, skill_name: String) -> int:
	if GameState.characters.has(character_uid):
		if GameState.characters[character_uid].skills.has(skill_name):
			return GameState.characters[character_uid].skills[skill_name]
	return 0


func apply_upkeep_cost(character_uid: int, cost: int):
	subtract_credits(character_uid, cost)

# NOTE: The get_player_save_data() and load_player_save_data() functions have been removed.
# This responsibility is now handled by the GameStateManager, which will serialize and
# deserialize the entire GameState.characters dictionary directly.
