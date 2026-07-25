# PROJECT: GDTLancer
# MODULE: impact_card_entry.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 02:05:00

extends Resource
class_name ImpactCardEntry

export(String) var entry_id: String = ""
export(String) var display_name: String = ""
export(String) var type: String = "ADVANTAGE" # ADVANTAGE, DISADVANTAGE, COMPLICATION, OPPORTUNITY
export(String) var description: String = ""

# Context Tag Filtering
export(Array, String) var required_tags: Array = []
export(Array, String) var prohibited_tags: Array = []
export(int) var weight: int = 10

# Board Mutations
export(Dictionary) var player_track_deltas: Dictionary = {}
export(Dictionary) var sector_track_deltas: Dictionary = {}
export(Array, String) var applied_tags: Array = []
export(Array, String) var removed_tags: Array = []

func matches_context(active_tags: Array) -> bool:
	for tag in required_tags:
		if not tag in active_tags:
			return false
	for tag in prohibited_tags:
		if tag in active_tags:
			return false
	return true
