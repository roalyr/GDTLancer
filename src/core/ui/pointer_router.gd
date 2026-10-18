# PointerRouter: the single owner of pointer (mouse / touch) input between the HUD and the 3D view.
#
# Rules. UI work must follow them so pointer ownership never has to be re-solved:
# 1. HUD controls that act on a press (buttons, sliders) use MOUSE_FILTER_STOP. Every other HUD
#    control (zones, panels, labels, readouts, target brackets) uses MOUSE_FILTER_IGNORE, and so do
#    children of buttons. Modal windows may block as a whole while visible. Nothing changes
#    mouse_filter at runtime. test_pointer_router.gd enforces this on the HUD scenes.
# 2. A press the GUI takes belongs to the HUD for its whole gesture; the router never sees it.
# 3. A press the GUI leaves reaches _unhandled_input and starts a world gesture. Until its release
#    the router takes every motion and the release in _input, ahead of the GUI, so controls the
#    pointer crosses cannot steal or end the gesture.
# 4. A world gesture that moves past DRAG_THRESHOLD_PX rotates the camera. Otherwise it is a click:
#    the target bracket nearest the pointer is selected, or the selection is cleared;
#    a double click flies toward the point.
# 5. Free flight captures the mouse: all motion steers the camera, and a click leaves free flight
#    so mouse-only and touch players are never stuck in it.
# 6. Pause, focus loss or a release that never arrives (mouse mode change) cancels the gesture.

extends Node

const DRAG_THRESHOLD_PX = 10.0
const DOUBLE_CLICK_MS = 400

var _hud: Control = null
var _gesture_active: bool = false
var _is_dragging: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _last_click_ms: int = -DOUBLE_CLICK_MS


func _init(hud: Control = null) -> void:
	_hud = hud
	name = "PointerRouter"
	pause_mode = Node.PAUSE_MODE_STOP  # Menus own the pointer while the game is paused.


func is_gesture_active() -> bool:
	return _gesture_active


func cancel_gesture() -> void:
	if _is_dragging:
		_set_camera_rotating(false)
	_gesture_active = false
	_is_dragging = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		cancel_gesture()


# Rule 3 and 5: runs before the GUI.
func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_captured_input(event)
		return
	if not _gesture_active:
		return
	if event is InputEventMouseMotion:
		if not _is_dragging and event.position.distance_to(_press_position) > DRAG_THRESHOLD_PX:
			_is_dragging = true
			_set_camera_rotating(true)
		if _is_dragging:
			_forward_camera_motion(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		var was_click: bool = not _is_dragging
		cancel_gesture()
		if was_click:
			_handle_world_click(event.position)


# Rule 2 and 3: only presses no HUD control took get here.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed):
		return
	if _is_world_input_blocked():
		return
	get_viewport().set_input_as_handled()
	_gesture_active = true
	_is_dragging = false
	_press_position = event.position


func _handle_captured_input(event: InputEvent) -> void:
	cancel_gesture()
	if event is InputEventMouseMotion:
		_forward_camera_motion(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		var controller = _get_player_controller()
		if is_instance_valid(controller) and controller.has_method("set_free_flight"):
			controller.set_free_flight(false)


func _handle_world_click(position: Vector2) -> void:
	var bracket = _hud.find_target_bracket_at(position) if is_instance_valid(_hud) else null
	if is_instance_valid(bracket):
		_last_click_ms = -DOUBLE_CLICK_MS
		bracket.emit_signal("pressed")
		return
	var controller = _get_player_controller()
	if not is_instance_valid(controller):
		return
	var now: int = OS.get_ticks_msec()
	if now - _last_click_ms <= DOUBLE_CLICK_MS:
		_last_click_ms = -DOUBLE_CLICK_MS
		controller.handle_world_double_click(position)
	else:
		_last_click_ms = now
		controller.handle_world_click(position)


func _is_world_input_blocked() -> bool:
	var controller = _get_player_controller()
	return is_instance_valid(controller) and controller.has_method("is_pointer_input_blocked") and controller.is_pointer_input_blocked()


func _get_player_controller() -> Node:
	var player = GlobalRefs.player_agent_body
	if not is_instance_valid(player):
		return null
	return player.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)


func _set_camera_rotating(rotating: bool) -> void:
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and camera.has_method("set_is_rotating"):
		camera.set_is_rotating(rotating)


func _forward_camera_motion(event: InputEventMouseMotion) -> void:
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and camera.has_method("apply_rotation_input"):
		camera.apply_rotation_input(event)
