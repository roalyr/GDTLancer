# PROJECT: GDTLancer
# MODULE: mode_transition_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 01:57:00

extends Node
class_name ModeTransitionManager

signal mode_transition_started(from_mode, to_mode)
signal mode_transition_completed(from_mode, to_mode)
signal mode_changed(new_mode)

enum Mode {
	MODE_A_FLIGHT = 0,
	MODE_B_BOARD = 1
}

var current_mode: int = Mode.MODE_A_FLIGHT
var is_transitioning: bool = false

var mode_a_node: Node = null
var mode_b_node: Node = null

func setup(p_mode_a_node: Node, p_mode_b_node: Node) -> void:
	mode_a_node = p_mode_a_node
	mode_b_node = p_mode_b_node
	_apply_mode_visibility()

func switch_to_mode(target_mode: int) -> bool:
	if is_transitioning or target_mode == current_mode:
		return false
	
	is_transitioning = true
	var previous_mode: int = current_mode
	emit_signal("mode_transition_started", previous_mode, target_mode)
	
	current_mode = target_mode
	_apply_mode_visibility()
	
	emit_signal("mode_changed", current_mode)
	is_transitioning = false
	emit_signal("mode_transition_completed", previous_mode, current_mode)
	return true

func toggle_mode() -> bool:
	var next_mode: int = Mode.MODE_B_BOARD if current_mode == Mode.MODE_A_FLIGHT else Mode.MODE_A_FLIGHT
	return switch_to_mode(next_mode)

func is_mode_a() -> bool:
	return current_mode == Mode.MODE_A_FLIGHT

func is_mode_b() -> bool:
	return current_mode == Mode.MODE_B_BOARD

func _apply_mode_visibility() -> void:
	if mode_a_node != null and mode_a_node.has_method("set_visible"):
		mode_a_node.set_visible(current_mode == Mode.MODE_A_FLIGHT)
	elif mode_a_node != null and "visible" in mode_a_node:
		mode_a_node.visible = (current_mode == Mode.MODE_A_FLIGHT)
		
	if mode_b_node != null and mode_b_node.has_method("set_visible"):
		mode_b_node.set_visible(current_mode == Mode.MODE_B_BOARD)
	elif mode_b_node != null and "visible" in mode_b_node:
		mode_b_node.visible = (current_mode == Mode.MODE_B_BOARD)
