# PROJECT: GDTLancer
# MODULE: test_m29_playable_board_game_mvp.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: STRATEGICAL-TODO.md §M29; TRUTH_EXPLORATION-PILLARS.md §4, §5
# LOG_REF: 2026-07-26 03:45:00

extends "res://addons/gut/test.gd"

const AssetSystemClass = preload("res://src/core/systems/asset_system.gd")
const SectorManagerClass = preload("res://src/core/systems/sector_manager.gd")
const NodeGateSystemClass = preload("res://src/core/systems/node_gate_system.gd")
const BoardUIScene = preload("res://scenes/ui/board/board_ui.tscn")

var asset_sys: Node
var sector_mgr: Node
var gate_sys: Reference
var board_ui: Control

func before_each():
	GameState.reset_state()
	asset_sys = AssetSystemClass.new()
	asset_sys._ready()
	
	sector_mgr = SectorManagerClass.new()
	sector_mgr._ready()
	
	gate_sys = NodeGateSystemClass.new()
	
	board_ui = autoqfree(BoardUIScene.instance())
	add_child(board_ui)

func after_each():
	if asset_sys != null:
		asset_sys.free()
		asset_sys = null
	if sector_mgr != null:
		sector_mgr.free()
		sector_mgr = null

func test_system_integration_wiring():
	assert_not_null(GlobalRefs.asset_system, "AssetSystem should register itself in GlobalRefs")
	assert_true(asset_sys.registered_cards.size() >= 10, "Card corpus should be fully loaded")
	assert_not_null(gate_sys, "NodeGateSystem should initialize")

func test_mode_b_board_ui_population_and_action_loop():
	assert_not_null(board_ui.card_area, "CardArea should be bound in BoardUI")
	assert_not_null(board_ui.action_btn, "ExecuteActionButton should be bound in BoardUI")
	
	board_ui._populate_board()
	assert_true(board_ui.card_area.cards.size() > 0, "BoardUI should populate with cards from AssetSystem")
	
	# Initial track values
	GameState.set_player_track("wealth", 5)
	GameState.set_player_track("health", 5)
	
	# Execute an action check
	board_ui.card_area.selected_cards = [board_ui.card_area.cards[0]]
	board_ui._on_execute_action_pressed()
	
	assert_ne(board_ui.dice_feedback.outcome_label.text, "Awaiting Roll...", "Outcome feedback should update")
	assert_true(GameState.get_player_track("wealth") != 5 or GameState.get_player_track("health") != 5, "Action check should mutate player tracks")

func test_outer_margin_node_dangling_carrot_locking():
	# NodeOuterMarginAlpha requires "outer_margin_pass" tag
	var empty_inv = []
	assert_true(gate_sys.is_node_locked("node_outer_margin_alpha", empty_inv), "Outer margin teaser node should be locked without required card")
	
	var reason = gate_sys.get_lock_reason("node_outer_margin_alpha", empty_inv)
	assert_true("Nav-Pass" in reason or "Locked" in reason, "Lock reason should inform player of missing requirement")
	
	# Unlocking with Asset Card
	var nav_card = asset_sys.get_card("nav_pass_outer_margin")
	assert_not_null(nav_card, "Outer margin nav pass card should exist in corpus")
	var inv_with_card = [nav_card]
	assert_false(gate_sys.is_node_locked("node_outer_margin_alpha", inv_with_card), "Outer margin teaser node should unlock with Nav-Pass card")

func test_sector_travel_resource_drain_and_thresholds():
	GameState.set_player_track("supplies", 5)
	
	# Travel from sector_core_industrial to sector_epsilon
	var result = sector_mgr.travel_to_sector("sector_core_industrial", "sector_epsilon", [], 2, 1)
	assert_true(result.get("success", false), "Travel should succeed with sufficient supplies")
	assert_eq(GameState.get_player_track("supplies"), 3, "Travel should deduct 2 supplies")
	
	# Environmental threshold test
	GameState.set_sector_track("sector_epsilon", "stability", 1)
	var events = sector_mgr.evaluate_sector_thresholds("sector_epsilon")
	assert_true(events.size() > 0, "Low sector stability should trigger environmental event")
	assert_eq(events[0].event_type, "ANOMALOUS_UNREST")
