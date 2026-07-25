# PROJECT: GDTLancer
# MODULE: asset_card.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_EXPLORATION-PILLARS.md §3, §9
# LOG_REF: 2026-07-26 00:57:00

extends Resource
class_name AssetCard

export(String) var card_id: String = ""
export(String) var display_name: String = ""
export(String) var description: String = ""
export(Array, String) var tags: Array = []
export(Array, String) var unlocked_verbs: Array = []
export(Dictionary) var trade_offs: Dictionary = {}

func has_tag(tag: String) -> bool:
	for t in tags:
		if String(t).to_lower() == tag.to_lower():
			return true
	return false
