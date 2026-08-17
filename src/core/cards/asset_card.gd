# PROJECT: GDTLancer
# MODULE: asset_card.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md § 2; TRUTH_EXPLORATION-PILLARS.md §3, §9
# LOG_REF: 2026-08-17 03:59:00

extends Resource
class_name AssetCard

enum CardType {
	MODULE,      # Ship-only, slotted, never enters board play
	FIELD,       # Used on contextual boards
	POSSESSION,  # Gifts, personal items, crafting materials
	CONSUMABLE   # Single-use items expended on boards or ship events
}

export(String) var card_id: String = ""
export(String) var display_name: String = ""
export(String) var description: String = ""
export(CardType) var card_type: int = CardType.FIELD
export(bool) var is_junk: bool = false
export(Array, String) var tags: Array = []
export(Array, String) var unlocked_verbs: Array = []
export(Dictionary) var trade_offs: Dictionary = {}
export(Dictionary) var quantitative_modifiers: Dictionary = {} # e.g. {"modifier_name": 1}

func _init(p_id: String = "", p_name: String = "", p_tags: Array = [], p_verbs: Array = [], p_trade_offs: Dictionary = {}, p_desc: String = "", p_type: int = CardType.FIELD, p_junk: bool = false, p_modifiers: Dictionary = {}) -> void:
	if not p_id.empty():
		card_id = p_id
		display_name = p_name if not p_name.empty() else p_id
		tags = p_tags
		unlocked_verbs = p_verbs
		trade_offs = p_trade_offs
		description = p_desc
		card_type = p_type
		is_junk = p_junk
		quantitative_modifiers = p_modifiers

func has_tag(tag: String) -> bool:
	for t in tags:
		if String(t).to_lower() == tag.to_lower():
			return true
	return false

func is_modification_card() -> bool:
	return has_tag("modification") or has_tag("transhuman") or not trade_offs.empty()

func validate_trade_offs() -> bool:
	if is_modification_card():
		if trade_offs.empty():
			return false
		# Pillar 9: Must explicitly define what is gained and what is surrendered
		var has_gain = trade_offs.has("gained") and not String(trade_offs["gained"]).empty()
		var has_surrender = trade_offs.has("surrendered") and not String(trade_offs["surrendered"]).empty()
		return has_gain and has_surrender
	return true
