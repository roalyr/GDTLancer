# PROJECT: GDTLancer
# MODULE: test_node_gate_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_EXPLORATION-PILLARS.md §4
# LOG_REF: 2026-07-26 02:15:00

extends "res://addons/gut/test.gd"

const NodeGateSystemClass = preload("res://src/core/systems/node_gate_system.gd")
const AssetCardClass = preload("res://src/core/cards/asset_card.gd")

var gate_sys: NodeGateSystem

func before_each():
	GameState.reset_state()
	gate_sys = NodeGateSystemClass.new()
	gate_sys._ready()

func after_each():
	if gate_sys != null:
		gate_sys.free()
		gate_sys = null

func test_normal_node_unlocked_by_default():
	assert_false(gate_sys.is_node_locked("node_normal", []))

func test_outer_margin_node_locked_without_key_card():
	assert_true(gate_sys.is_node_locked("node_outer_margin_alpha", []))

func test_outer_margin_node_unlocked_with_key_card():
	var key_card = AssetCardClass.new("Outer Margin Pass", ["outer_margin_pass"], "perm")
	var inventory = [key_card]
	
	assert_false(gate_sys.is_node_locked("node_outer_margin_alpha", inventory))
