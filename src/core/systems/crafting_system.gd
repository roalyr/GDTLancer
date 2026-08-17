# PROJECT: GDTLancer
# MODULE: crafting_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-08-17 04:00:00

extends Node

var AssetCardClass = load("res://src/core/cards/asset_card.gd")

## Tag-pairing crafting logic. Attempts to combine two cards.
## Returns a Dictionary with "success": bool, and "result": AssetCard (either the new item or Junk).
func craft(card_a: Resource, card_b: Resource) -> Dictionary:
	if not card_a or not card_b:
		return _produce_junk("Missing inputs")
		
	# Junk can sometimes be used as universal fuel, but for standard pairing, we check tags
	var tags_a = []
	var tags_b = []
	
	if "tags" in card_a: tags_a = card_a.tags
	if "tags" in card_b: tags_b = card_b.tags
	
	# Example tag pairing logic:
	# If one card has "salvage" and the other has "repair", produce a basic fix-it consumable
	var a_is_salvage = "salvage" in tags_a or card_a.get("is_junk") == true
	var b_is_repair = "repair" in tags_b
	var b_is_salvage = "salvage" in tags_b or card_b.get("is_junk") == true
	var a_is_repair = "repair" in tags_a
	
	if (a_is_salvage and b_is_repair) or (b_is_salvage and a_is_repair):
		return _produce_item("consumable_repair_kit", "Basic Repair Kit", AssetCardClass.CardType.CONSUMABLE, ["repair", "consumable"])
		
	# If combinations fail, produce junk
	return _produce_junk("Incompatible tags")

func _produce_junk(reason: String) -> Dictionary:
	var junk_card = AssetCardClass.new()
	junk_card.card_id = "item_junk"
	junk_card.display_name = "Scrap/Junk"
	junk_card.card_type = AssetCardClass.CardType.POSSESSION
	junk_card.is_junk = true
	junk_card.description = "Produced via failed crafting: " + reason
	return {
		"success": false,
		"result": junk_card,
		"message": "Crafting failed: " + reason
	}

func _produce_item(id: String, name: String, type: int, tags: Array) -> Dictionary:
	var new_card = AssetCardClass.new()
	new_card.card_id = id
	new_card.display_name = name
	new_card.card_type = type
	new_card.tags = tags
	new_card.is_junk = false
	return {
		"success": true,
		"result": new_card,
		"message": "Crafting successful!"
	}
