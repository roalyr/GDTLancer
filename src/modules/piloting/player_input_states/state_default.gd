# File: src/modules/piloting/player_input_states/state_default.gd
# Handles standard flight, targeting, and camera drag input.

extends "res://src/modules/piloting/player_input_states/state_base.gd"

# --- Input Tracking State for this mode ---
var _lmb_pressed: bool = false
var _lmb_press_pos: Vector2 = Vector2.ZERO
var _last_tap_time: int = 0
var _is_dragging: bool = false

const DRAG_THRESHOLD_PX_SQ = 10 * 10
const DOUBLE_CLICK_TIME_MS = 400


func enter(controller: Node):
	.enter(controller)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if (
		is_instance_valid(_controller._main_camera)
		and _controller._main_camera.has_method("set_is_rotating")
	):
		_controller._main_camera.set_is_rotating(false)
	_lmb_pressed = false
	_is_dragging = false


func physics_update(_delta: float):
	_controller._update_target_under_cursor()


func handle_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			_lmb_pressed = true
			_is_dragging = false
			_lmb_press_pos = event.position
		else:  # Released
			if _lmb_pressed:
				if _is_dragging:
					# Stop camera rotation when drag is released
					if (
						is_instance_valid(_controller._main_camera)
						and _controller._main_camera.has_method("set_is_rotating")
					):
						_controller._main_camera.set_is_rotating(false)
				else:  # Tap/Click
					var time_now = OS.get_ticks_msec()
					if time_now - _last_tap_time <= DOUBLE_CLICK_TIME_MS:
						_controller._handle_double_click(event.position)
						_last_tap_time = 0
					else:
						_controller._handle_single_click(event.position)
						_last_tap_time = time_now
				_lmb_pressed = false
				_is_dragging = false
				_controller.get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _lmb_pressed and not _is_dragging:
		if event.position.distance_squared_to(_lmb_press_pos) > DRAG_THRESHOLD_PX_SQ:
			_is_dragging = true
			if (
				is_instance_valid(_controller._main_camera)
				and _controller._main_camera.has_method("set_is_rotating")
			):
				_controller._main_camera.set_is_rotating(true)
			_controller.get_viewport().set_input_as_handled()
