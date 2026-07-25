# PROJECT: GDTLancer
# MODULE: test_mode_transition_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 01:57:00

extends "res://addons/gut/test.gd"

var ModeTransitionManagerScript = load("res://src/core/systems/mode_transition_manager.gd")

var _manager = null
var _node_a = null
var _node_b = null

func before_each():
	_manager = autoqfree(ModeTransitionManagerScript.new())
	add_child(_manager)
	_node_a = autoqfree(Control.new())
	_node_b = autoqfree(Control.new())
	add_child(_node_a)
	add_child(_node_b)

func test_initial_state():
	assert_eq(_manager.current_mode, ModeTransitionManagerScript.Mode.MODE_A_FLIGHT, "Default mode should be MODE_A_FLIGHT")
	assert_true(_manager.is_mode_a(), "is_mode_a should return true initially")
	assert_false(_manager.is_mode_b(), "is_mode_b should return false initially")

func test_setup_and_visibility():
	_manager.setup(_node_a, _node_b)
	assert_true(_node_a.visible, "Mode A node should be visible in MODE_A_FLIGHT")
	assert_false(_node_b.visible, "Mode B node should be hidden in MODE_A_FLIGHT")

func test_switch_mode():
	_manager.setup(_node_a, _node_b)
	watch_signals(_manager)
	
	var success = _manager.switch_to_mode(ModeTransitionManagerScript.Mode.MODE_B_BOARD)
	assert_true(success, "Switch to Mode B should return true")
	assert_true(_manager.is_mode_b(), "Manager should now be in MODE_B_BOARD")
	assert_false(_node_a.visible, "Mode A node should now be hidden")
	assert_true(_node_b.visible, "Mode B node should now be visible")
	assert_signal_emitted(_manager, "mode_changed", "mode_changed signal should be emitted")

func test_toggle_mode():
	_manager.setup(_node_a, _node_b)
	_manager.toggle_mode()
	assert_true(_manager.is_mode_b(), "Toggling from Mode A should switch to Mode B")
	_manager.toggle_mode()
	assert_true(_manager.is_mode_a(), "Toggling from Mode B should switch back to Mode A")
