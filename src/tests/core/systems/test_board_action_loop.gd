# PROJECT: GDTLancer
# MODULE: test_board_action_loop.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2; TRUTH_EXPLORATION-PILLARS.md §3
# LOG_REF: 2026-07-26 00:57:00

extends "res://addons/gut/test.gd"

var AssetCardScript = load("res://src/core/cards/asset_card.gd")
var ImpactCardScript = load("res://src/core/cards/impact_card.gd")
var ActionCheckEngineScript = load("res://src/core/systems/action_check_engine.gd")
var BoardActionLoopScript = load("res://src/core/systems/board_action_loop.gd")
var WorldClockScript = load("res://src/core/simulation/world_clock.gd")

var _board_loop = null
var _world_clock = null

func before_each():
	_board_loop = autoqfree(BoardActionLoopScript.new())
	add_child(_board_loop)
	_world_clock = autoqfree(WorldClockScript.new())
	_world_clock.name = "WorldClock"
	get_tree().root.add_child(_world_clock)
	GameState.player_tracks = {"health": 5, "wealth": 5, "morale": 5, "supplies": 5}
	GameState.sector_tracks.clear()

func after_each():
	if is_instance_valid(_world_clock):
		get_tree().root.remove_child(_world_clock)

func test_player_track_tiers():
	GameState.player_tracks["health"] = 1
	assert_eq(GameState.get_player_track_tier("health"), "CRITICAL", "Health 1 should be CRITICAL tier")

	GameState.player_tracks["wealth"] = 4
	assert_eq(GameState.get_player_track_tier("wealth"), "LOW", "Wealth 4 should be LOW tier")

	GameState.player_tracks["morale"] = 6
	assert_eq(GameState.get_player_track_tier("morale"), "STABLE", "Morale 6 should be STABLE tier")

	GameState.player_tracks["supplies"] = 9
	assert_eq(GameState.get_player_track_tier("supplies"), "PROSPEROUS", "Supplies 9 should be PROSPEROUS tier")

func test_asset_card_schema():
	var card = AssetCardScript.new()
	card.card_id = "magnetic_anchor"
	card.display_name = "Magnetic Anchor"
	card.tags = ["Anchor", "Utility"]
	card.unlocked_verbs = ["ATTACH", "STABILIZE"]
	card.trade_offs = {"check_modifier": 1}

	assert_true(card.has_tag("anchor"), "has_tag should be case-insensitive")
	assert_true(card.has_tag("Utility"), "has_tag should match exact tag")
	assert_false(card.has_tag("weapon"), "Non-existent tag should return false")

func test_action_check_engine_3d6():
	var engine = ActionCheckEngineScript.new()
	var card = AssetCardScript.new()
	card.tags = ["Tool", "Scannable"]

	# Seeded dice: 3 + 4 + 5 = 12 base total
	# Card adds 2 modifier
	# Track state: all STABLE (no modifier)
	var res = engine.resolve_check(12, [card], GameState.player_tracks, [3, 4, 5])
	assert_eq(res["base_total"], 12, "Base total should be 12")
	assert_eq(res["modifier"], 2, "Modifier should be 2 from card tags")
	assert_eq(res["final_total"], 14, "Final total should be 14")
	assert_true(res["success"], "Check should succeed (14 >= 12)")
	assert_eq(res["margin"], 2, "Margin should be +2")

func test_board_action_loop_full_sequence():
	var mock_node = Node.new()
	autoqfree(mock_node)

	# 1. Target
	_board_loop.select_target(mock_node)
	assert_eq(_board_loop.current_target_node, mock_node, "Target node should be selected")

	# 2. Assemble
	var card = AssetCardScript.new()
	card.card_id = "salvage_rig"
	card.tags = ["Salvage"]
	_board_loop.assemble_action([card])
	assert_eq(_board_loop.selected_asset_cards.size(), 1, "One card should be assembled")

	# 3. Check (Seeded 4,4,4 = 12 base + 1 card mod = 13 total vs difficulty 12 -> Success)
	var check_res = _board_loop.execute_check(12, [4, 4, 4])
	assert_true(check_res["success"], "Check should be successful")

	# 4. Mutate
	var impact = ImpactCardScript.new()
	impact.display_name = "Major Salvage Yield"
	impact.player_track_deltas = {"wealth": 2, "supplies": 1}
	impact.sector_track_deltas = {"morale": 1}

	var initial_tick = _world_clock.current_tick
	var mutated = _board_loop.apply_mutation(impact, "sector_alpha")

	assert_true(mutated, "Mutation should apply successfully")
	assert_eq(GameState.get_player_track("wealth"), 7, "Player wealth should increase from 5 to 7")
	assert_eq(GameState.get_player_track("supplies"), 6, "Player supplies should increase from 5 to 6")
	assert_eq(GameState.get_sector_track("sector_alpha", "morale"), 6, "Sector morale should increase from 5 to 6")
	assert_eq(_world_clock.current_tick, initial_tick + 1, "WorldClock should advance by 1 tick upon board mutation")
