# PROJECT: GDTLancer
# MODULE: character_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
# LOG_REF: 2026-06-14 02:11:58

extends Node


## CharacterSystem: Stateless API for character data management.
## Provides wealth_tier, wealth_progress, and skill operations on CharacterTemplate instances in GameState.



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

	# Populate initial wealth properties
	new_character.wealth_tier = template.wealth_tier
	new_character.wealth_progress = template.wealth_progress

	# Store in GameState
	GameState.characters[char_uid] = new_character

	return char_uid


# --- Stat Modification API (Operates on GameState) ---


func add_wealth_progress(character_uid, amount: int):
	if GameState.characters.has(character_uid):
		var char_data = GameState.characters[character_uid]
		char_data.wealth_progress += amount
		
		# Wrap promotion
		while char_data.wealth_progress >= Constants.WEALTH_TRACK_MAX:
			if char_data.wealth_tier == "BROKE":
				char_data.wealth_tier = "COMFORTABLE"
				char_data.wealth_progress -= Constants.WEALTH_TRACK_MAX
			elif char_data.wealth_tier == "COMFORTABLE":
				char_data.wealth_tier = "WEALTHY"
				char_data.wealth_progress -= Constants.WEALTH_TRACK_MAX
			elif char_data.wealth_tier == "WEALTHY":
				char_data.wealth_progress = Constants.WEALTH_TRACK_MAX
				break
		
		# If this change was for the player, announce it.
		if str(character_uid) == str(GameState.player_character_uid):
			EventBus.emit_signal("player_wealth_changed", char_data.wealth_tier, char_data.wealth_progress)
			EventBus.emit_signal("player_credits_changed", char_data.wealth_progress)


func subtract_wealth_progress(character_uid, amount: int):
	if GameState.characters.has(character_uid):
		var char_data = GameState.characters[character_uid]
		char_data.wealth_progress -= amount
		
		# Wrap demotion
		while char_data.wealth_progress < 0:
			if char_data.wealth_tier == "WEALTHY":
				char_data.wealth_tier = "COMFORTABLE"
				char_data.wealth_progress = Constants.WEALTH_TRACK_MAX + char_data.wealth_progress + 1
			elif char_data.wealth_tier == "COMFORTABLE":
				char_data.wealth_tier = "BROKE"
				char_data.wealth_progress = Constants.WEALTH_TRACK_MAX + char_data.wealth_progress + 1
			elif char_data.wealth_tier == "BROKE":
				char_data.wealth_progress = 0
				break
				
		# If this change was for the player, announce it.
		if str(character_uid) == str(GameState.player_character_uid):
			EventBus.emit_signal("player_wealth_changed", char_data.wealth_tier, char_data.wealth_progress)
			EventBus.emit_signal("player_credits_changed", char_data.wealth_progress)


func get_wealth_tier(character_uid) -> String:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].wealth_tier
	return "BROKE"


func get_wealth_modifier(character_uid) -> int:
	if not GameState.characters.has(character_uid):
		return 0
	var tier: String = get_wealth_tier(character_uid)
	return Constants.WEALTH_MODIFIERS.get(tier, 0)


func get_wealth_progress(character_uid) -> int:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].wealth_progress
	return 0


# --- Legacy Compatibility Shims (Deprecated) ---

func add_credits(character_uid, amount: int):
	add_wealth_progress(character_uid, amount)


func subtract_credits(character_uid, amount: int):
	subtract_wealth_progress(character_uid, amount)


func get_credits(character_uid) -> int:
	return get_wealth_progress(character_uid)


func get_skill_level(character_uid, skill_name: String) -> int:
	if GameState.characters.has(character_uid):
		if GameState.characters[character_uid].skills.has(skill_name):
			return GameState.characters[character_uid].skills[skill_name]
	return 0


func apply_upkeep_cost(character_uid, cost: int):
	subtract_wealth_progress(character_uid, cost)

# NOTE: The get_player_save_data() and load_player_save_data() functions have been removed.
# This responsibility is now handled by the GameStateManager, which will serialize and
# deserialize the entire GameState.characters dictionary directly.
