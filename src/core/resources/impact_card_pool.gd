# PROJECT: GDTLancer
# MODULE: impact_card_pool.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 02:05:00

extends Resource
class_name ImpactCardPool

export(String) var pool_id: String = ""
export(String) var display_name: String = ""
export(Array, Resource) var entries: Array = []

func get_matching_entries(active_tags: Array, filter_type: String = "") -> Array:
	var matching: Array = []
	for entry in entries:
		if entry == null:
			continue
		if filter_type != "" and entry.type != filter_type:
			continue
		if entry.has_method("matches_context"):
			if entry.matches_context(active_tags):
				matching.append(entry)
	return matching
