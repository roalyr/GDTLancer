# PROJECT: GDTLancer
# MODULE: test_sector_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_EXPLORATION-PILLARS.md §4
# LOG_REF: 2026-07-26 02:15:00

extends "res://addons/gut/test.gd"

const SectorManagerClass = preload("res://src/core/systems/sector_manager.gd")
const AssetCardClass = preload("res://src/core/cards/asset_card.gd")

var sector_mgr: SectorManager

func before_each():
	GameState.reset_state()
	sector_mgr = SectorManagerClass.new()
	sector_mgr._ready()

func after_each():
	if sector_mgr != null:
		sector_mgr.free()
		sector_mgr = null

func test_sector_travel_deducts_supplies_and_advances_clock():
	GameState.player_tracks["supplies"] = 5
	
	var res = sector_mgr.travel_to_sector("sector_a", "sector_b", [], 2, 3)
	assert_true(res["success"])
	assert_eq(GameState.get_player_track("supplies"), 3)

func test_sector_travel_fails_when_supplies_insufficient():
	GameState.player_tracks["supplies"] = 1
	
	var res = sector_mgr.travel_to_sector("sector_a", "sector_b", [], 3, 2)
	assert_false(res["success"])
	assert_eq(GameState.get_player_track("supplies"), 1)

func test_environmental_event_triggered_at_low_stability():
	GameState.set_sector_track("sector_danger", "stability", 1)
	
	var events = sector_mgr.evaluate_sector_thresholds("sector_danger")
	assert_true(events.size() > 0)
	assert_eq(events[0]["event_type"], "ANOMALOUS_UNREST")
	assert_true(GameState.has_sector_tag("sector_danger", "anomalous_unrest"))

func test_travel_blocked_to_locked_outer_margin_node():
	GameState.player_tracks["supplies"] = 10
	
	# Attempt travel without required pass
	var res = sector_mgr.travel_to_sector("sector_a", "node_outer_margin_alpha", [], 1, 1)
	assert_false(res["success"])
	assert_true("Outer Margin Nav-Pass" in res["reason"])
