# PROJECT: GDTLancer
# MODULE: test_impact_resources.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 02:05:00

extends "res://addons/gut/test.gd"

const ImpactCardEntryClass = preload("res://src/core/resources/impact_card_entry.gd")
const ImpactCardPoolClass = preload("res://src/core/resources/impact_card_pool.gd")

func test_impact_card_entry_creation():
	var entry = ImpactCardEntryClass.new()
	entry.entry_id = "test_adv_01"
	entry.type = "ADVANTAGE"
	entry.required_tags = ["sector_core", "npc_friendly"]
	entry.prohibited_tags = ["sector_hazard"]
	entry.player_track_deltas = {"wealth": 2, "morale": 1}
	
	assert_eq(entry.entry_id, "test_adv_01")
	assert_eq(entry.type, "ADVANTAGE")
	assert_true(entry.matches_context(["sector_core", "npc_friendly"]))
	assert_false(entry.matches_context(["sector_core"]))
	assert_false(entry.matches_context(["sector_core", "npc_friendly", "sector_hazard"]))

func test_impact_card_pool_filtering():
	var pool = ImpactCardPoolClass.new()
	pool.pool_id = "test_pool"
	
	var entry1 = ImpactCardEntryClass.new()
	entry1.entry_id = "e1"
	entry1.type = "ADVANTAGE"
	entry1.required_tags = ["tag_a"]
	
	var entry2 = ImpactCardEntryClass.new()
	entry2.entry_id = "e2"
	entry2.type = "DISADVANTAGE"
	entry2.required_tags = ["tag_a"]
	
	var entry3 = ImpactCardEntryClass.new()
	entry3.entry_id = "e3"
	entry3.type = "ADVANTAGE"
	entry3.required_tags = ["tag_b"]
	
	pool.entries = [entry1, entry2, entry3]
	
	var matches_all = pool.get_matching_entries(["tag_a"])
	assert_eq(matches_all.size(), 2)
	assert_true(entry1 in matches_all)
	assert_true(entry2 in matches_all)
	
	var matches_adv = pool.get_matching_entries(["tag_a"], "ADVANTAGE")
	assert_eq(matches_adv.size(), 1)
	assert_eq(matches_adv[0], entry1)
