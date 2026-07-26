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

func test_sector_travel_succeeds_when_unlocked():
	var res = sector_mgr.travel_to_sector("sector_a", "sector_b", [], 0, 3)
	assert_true(res["success"])

func test_travel_blocked_to_locked_outer_margin_node():
	# Attempt travel without required pass
	var res = sector_mgr.travel_to_sector("sector_a", "node_outer_margin_alpha", [], 0, 1)
	assert_false(res["success"])
	assert_true("Outer Margin Nav-Pass" in res["reason"])
