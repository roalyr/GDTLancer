# PROJECT: GDTLancer
# MODULE: character_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Agent Parity Principle
# LOG_REF: 2026-06-11 00:55:00

extends Node


## CharacterSystem: Stateless API for character data management.
## Provides credits, FP, and skill operations on CharacterTemplate instances in GameState.


func _ready():
	GlobalRefs.set_character_system(self)
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("CharacterSystem Ready.")


# --- Public API ---


# Retrieves a character instance from the GameState.
func get_character(character_uid) -> CharacterTemplate:
	return GameState.characters.get(character_uid)


# Convenience function to get the player's character instance.
func get_player_character() -> CharacterTemplate:
	if GameState.player_character_uid != "":
		var uid = GameState.player_character_uid
		if GameState.characters.has(uid):
			return GameState.characters.get(uid)
		# Fallback: characters dict may use int keys from WorldGenerator
		var int_uid = int(uid)
		if GameState.characters.has(int_uid):
			return GameState.characters.get(int_uid)
	return null


# Convenience function to get the player's UID.
func get_player_character_uid() -> String:
	return GameState.player_character_uid


# Creates a new character based on a template, assigns a unique UID, and stores it in GameState.
func create_character(template_id: String) -> int:
	if not TemplateDatabase.characters.has(template_id):
		printerr("CharacterSystem Error: Character template not found in TemplateDatabase: ", template_id)
		return -1

	var template: CharacterTemplate = TemplateDatabase.characters[template_id]
	var new_character = template.duplicate()

	# Generate a new unique UID (1000 + incremental)
	var max_uid = 1000
	if not GameState.characters.empty():
		for k in GameState.characters.keys():
			var k_int = int(str(k))
			if k_int >= max_uid:
				max_uid = k_int + 1
	var char_uid = max_uid

	# Populate initial credits and focus points based on the template
	new_character.credits = template.credits
	new_character.focus_points = template.focus_points

	# Store in GameState
	GameState.characters[char_uid] = new_character

	return char_uid


# --- Stat Modification API (Operates on GameState) ---


func add_credits(character_uid, amount: int):
	if GameState.characters.has(character_uid):
		GameState.characters[character_uid].credits += amount
		# If this change was for the player, announce it.
		if str(character_uid) == str(GameState.player_character_uid):
			EventBus.emit_signal("player_credits_changed", GameState.characters[character_uid].credits)


func subtract_credits(character_uid, amount: int):
	if GameState.characters.has(character_uid):
		var new_credits = GameState.characters[character_uid].credits - amount
		GameState.characters[character_uid].credits = max(0, new_credits)
		# If this change was for the player, announce it.
		if str(character_uid) == str(GameState.player_character_uid):
			EventBus.emit_signal("player_credits_changed", GameState.characters[character_uid].credits)


func get_credits(character_uid) -> int:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].credits
	return 0


func add_fp(character_uid, amount: int):
	if GameState.characters.has(character_uid):
		var character = GameState.characters[character_uid]
		character.focus_points += amount
		character.focus_points = clamp(character.focus_points, 0, Constants.FOCUS_MAX_DEFAULT)
		# If this change was for the player, announce it.
		if str(character_uid) == str(GameState.player_character_uid):
			EventBus.emit_signal("player_fp_changed", character.focus_points)


func subtract_fp(character_uid, amount: int):
	if GameState.characters.has(character_uid):
		var character = GameState.characters[character_uid]
		character.focus_points -= amount
		character.focus_points = clamp(character.focus_points, 0, Constants.FOCUS_MAX_DEFAULT)
		# If this change was for the player, announce it.
		if str(character_uid) == str(GameState.player_character_uid):
			EventBus.emit_signal("player_fp_changed", character.focus_points)


func get_fp(character_uid) -> int:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].focus_points
	return 0


func get_skill_level(character_uid, skill_name: String) -> int:
	if GameState.characters.has(character_uid):
		if GameState.characters[character_uid].skills.has(skill_name):
			return GameState.characters[character_uid].skills[skill_name]
	return 0


func apply_upkeep_cost(character_uid, cost: int):
	subtract_credits(character_uid, cost)

# NOTE: The get_player_save_data() and load_player_save_data() functions have been removed.
# This responsibility is now handled by the GameStateManager, which will serialize and
# deserialize the entire GameState.characters dictionary directly.
