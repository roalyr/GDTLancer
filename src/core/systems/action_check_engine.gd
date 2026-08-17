# PROJECT: GDTLancer
# MODULE: action_check_engine.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-08-17 04:00:00

extends Reference
class_name ActionCheckEngine

var AssetCardClass = load("res://src/core/cards/asset_card.gd")

## Resolves a card-based action check against target difficulty and required tags.
## applied_asset_cards: Array of AssetCard instances
func resolve_check(target_difficulty: int = 1, applied_asset_cards: Array = [], required_tags: Array = []) -> Dictionary:
	var total_power: int = 0
	var matched_tags: int = 0

	for card in applied_asset_cards:
		total_power += 1 # Base value of playing a card
		
		# Add quantitative modifiers if they exist
		var mods = card.get("quantitative_modifiers")
		if mods != null and typeof(mods) == TYPE_DICTIONARY:
			for mod_val in mods.values():
				total_power += int(mod_val)
				
		# Count matched tags
		for r_tag in required_tags:
			if card.has_method("has_tag") and card.has_tag(r_tag):
				matched_tags += 1
				
	# Success if power meets difficulty OR if all required tags are met
	var is_success = false
	if required_tags.size() > 0:
		is_success = matched_tags >= required_tags.size()
	else:
		is_success = total_power >= target_difficulty

	return {
		"applied_cards_count": applied_asset_cards.size(),
		"total_power": total_power,
		"matched_tags": matched_tags,
		"target_difficulty": target_difficulty,
		"success": is_success
	}
