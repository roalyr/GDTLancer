# Default piloting state: commands and targeting. Pointer gestures (selection, camera drag)
# are handled by PointerRouter, not here.

extends "res://src/modules/piloting/player_input_states/state_base.gd"


func enter(controller: Node):
	.enter(controller)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if (
		is_instance_valid(_controller._main_camera)
		and _controller._main_camera.has_method("set_is_rotating")
	):
		_controller._main_camera.set_is_rotating(false)
