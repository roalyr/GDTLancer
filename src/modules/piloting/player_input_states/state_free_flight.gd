# PROJECT: GDTLancer
# MODULE: state_free_flight.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

# File: src/modules/piloting/player_input_states/state_free_flight.gd
# Handles direct ship orientation and movement input.

extends "res://src/modules/piloting/player_input_states/state_base.gd"


func enter(controller: Node):
	.enter(controller)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if (
		is_instance_valid(_controller._main_camera)
		and _controller._main_camera.has_method("set_rotation_input_active")
	):
		_controller._main_camera.set_rotation_input_active(true)


func exit():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if (
		is_instance_valid(_controller._main_camera)
		and _controller._main_camera.has_method("set_rotation_input_active")
	):
		_controller._main_camera.set_rotation_input_active(false)


func physics_update(_delta: float):
	if is_instance_valid(_controller._main_camera) and is_instance_valid(_controller.agent_script):
		var move_dir = -_controller._main_camera.global_transform.basis.z.normalized()
		_controller.agent_script.command_move_direction(move_dir)
	elif is_instance_valid(_controller.agent_script):
		_controller.agent_script.command_stop()