# PROJECT: GDTLancer
# MODULE: action_check_engine.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 00:57:00

extends Reference
class_name ActionCheckEngine

var AssetCardClass = load("res://src/core/cards/asset_card.gd")

## Resolves a 3d6 action check against target difficulty.
## applied_asset_cards: Array of AssetCard instances
## player_track_states: Dictionary of player track values or tiers
func resolve_check(target_difficulty: int, applied_asset_cards: Array = [], player_track_states: Dictionary = {}, seeded_dice: Array = [], bond_modifier: int = 0) -> Dictionary:
	var dice_rolls: Array = []
	if seeded_dice.size() >= 3:
		dice_rolls = [int(seeded_dice[0]), int(seeded_dice[1]), int(seeded_dice[2])]
	else:
		randomize()
		dice_rolls = [randi() % 6 + 1, randi() % 6 + 1, randi() % 6 + 1]

	var base_total: int = dice_rolls[0] + dice_rolls[1] + dice_rolls[2]
	var modifier: int = bond_modifier

	# Calculate Asset Card bonuses
	for card in applied_asset_cards:
		if card != null and (card is AssetCardClass or card.has_method("has_tag")):
			modifier += card.tags.size()
			if card.trade_offs.has("check_modifier"):
				modifier += int(card.trade_offs["check_modifier"])

	# Calculate Track State modifiers
	for track in player_track_states:
		var val = int(player_track_states[track])
		if val <= 2:
			modifier -= 2
		elif val <= 4:
			modifier -= 1
		elif val >= 8:
			modifier += 1

	var final_total: int = base_total + modifier
	var success: bool = final_total >= target_difficulty
	var margin: int = final_total - target_difficulty

	return {
		"dice_rolls": dice_rolls,
		"base_total": base_total,
		"modifier": modifier,
		"final_total": final_total,
		"target_difficulty": target_difficulty,
		"success": success,
		"margin": margin
	}
