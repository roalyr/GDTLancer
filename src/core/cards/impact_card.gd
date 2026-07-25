# PROJECT: GDTLancer
# MODULE: impact_card.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 00:57:00

extends Resource
class_name ImpactCard

export(String) var card_id: String = ""
export(String) var display_name: String = ""
export(String) var type: String = "ADVANTAGE"
export(Dictionary) var player_track_deltas: Dictionary = {}
export(Dictionary) var sector_track_deltas: Dictionary = {}
export(Array, String) var applied_tags: Array = []
export(Array, String) var removed_tags: Array = []
