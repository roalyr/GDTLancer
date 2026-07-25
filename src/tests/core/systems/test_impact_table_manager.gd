# PROJECT: GDTLancer
# MODULE: test_impact_table_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 02:05:00

extends "res://addons/gut/test.gd"

const ImpactTableManagerClass = preload("res://src/core/systems/impact_table_manager.gd")
const ImpactCardEntryClass = preload("res://src/core/resources/impact_card_entry.gd")
const ImpactCardPoolClass = preload("res://src/core/resources/impact_card_pool.gd")

var manager: ImpactTableManager

func before_each():
	GameState.reset_state()
	manager = ImpactTableManagerClass.new()

func after_each():
	if manager != null:
		manager.free()
		manager = null

func test_evaluate_context_across_pools():
	var pool1 = ImpactCardPoolClass.new()
	var e1 = ImpactCardEntryClass.new()
	e1.entry_id = "e1"
	e1.type = "COMPLICATION"
	e1.required_tags = ["sector_outer"]
	pool1.entries = [e1]
	
	var pool2 = ImpactCardPoolClass.new()
	var e2 = ImpactCardEntryClass.new()
	e2.entry_id = "e2"
	e2.type = "OPPORTUNITY"
	e2.required_tags = ["sector_outer"]
	pool2.entries = [e2]
	
	manager.register_pool(pool1)
	manager.register_pool(pool2)
	
	var results = manager.evaluate_context(["sector_outer"])
	assert_eq(results.size(), 2)
	
	var comp_results = manager.evaluate_context(["sector_outer"], "COMPLICATION")
	assert_eq(comp_results.size(), 1)
	assert_eq(comp_results[0].entry_id, "e1")

func test_apply_impact_entry_mutates_gamestate():
	GameState.current_sector_id = "sector_test"
	GameState.player_tracks["health"] = 5
	GameState.player_tracks["wealth"] = 5
	
	var entry = ImpactCardEntryClass.new()
	entry.entry_id = "impact_test"
	entry.type = "ADVANTAGE"
	entry.player_track_deltas = {"health": -1, "wealth": 3}
	entry.sector_track_deltas = {"morale": 2}
	entry.applied_tags = ["station_repaired"]
	entry.removed_tags = ["station_damaged"]
	
	GameState.add_sector_tag("sector_test", "station_damaged")
	
	var report = manager.apply_impact_entry(entry, "sector_test")
	
	assert_eq(GameState.get_player_track("health"), 4)
	assert_eq(GameState.get_player_track("wealth"), 8)
	assert_eq(GameState.get_sector_track("sector_test", "morale"), 7)
	assert_true(GameState.has_sector_tag("sector_test", "station_repaired"))
	assert_false(GameState.has_sector_tag("sector_test", "station_damaged"))
	assert_eq(report["entry_id"], "impact_test")
