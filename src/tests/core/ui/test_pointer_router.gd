# Tests for PointerRouter: who owns a pointer gesture, and the scene rules that make that reliable.
# Events go through the real viewport (Input.parse_input_event), so GUI routing is exercised as in play.

extends GutTest

const MainHUDScene = preload("res://scenes/ui/hud/main_hud.tscn")
const MainMenuScene = preload("res://scenes/ui/menus/main_menu.tscn")
const ProjectedTargetBracketScene = preload("res://scenes/ui/hud/projected_target_bracket.tscn")

const WORLD_POINT = Vector2(960, 420)

var hud: Control = null
var camera: Node = null
var controller: Node = null


func before_each():
	camera = _make_mock("""extends Camera
var rotating_calls = []
var motion = []
func set_is_rotating(rotating):
	rotating_calls.append(rotating)
func apply_rotation_input(event):
	motion.append(event.relative)
""")
	GlobalRefs.main_camera = camera

	var player = RigidBody.new()
	add_child_autofree(player)
	controller = _make_mock("""extends Node
var clicks = []
var double_clicks = []
var free_flight_calls = []
var blocked = false
func is_pointer_input_blocked():
	return blocked
func handle_world_click(position):
	clicks.append(position)
func handle_world_double_click(position):
	double_clicks.append(position)
func set_free_flight(active):
	free_flight_calls.append(active)
""", false)
	controller.name = Constants.PLAYER_INPUT_HANDLER_NAME
	player.add_child(controller)
	GlobalRefs.player_agent_body = player

	hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")


func after_each():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GlobalRefs.main_hud = null
	GlobalRefs.main_camera = null
	GlobalRefs.player_agent_body = null


func test_click_on_empty_space_reaches_controller():
	yield(_press(WORLD_POINT), "completed")
	yield(_release(WORLD_POINT), "completed")
	assert_eq(controller.clicks, [WORLD_POINT])
	assert_eq(camera.rotating_calls, [], "A click must not rotate the camera.")


func test_double_click_reaches_controller_as_double_click():
	# Frames can run slow under a full test run: a wide window keeps the second click inside it
	# (this tests routing, not timing).
	hud._pointer_router.double_click_ms = 60000
	yield(_press(WORLD_POINT), "completed")
	yield(_release(WORLD_POINT), "completed")
	yield(_press(WORLD_POINT), "completed")
	yield(_release(WORLD_POINT), "completed")
	assert_eq(controller.clicks.size(), 1)
	assert_eq(controller.double_clicks, [WORLD_POINT])


func test_drag_across_hud_button_keeps_rotating_and_does_not_press_it():
	var button: BaseButton = hud.get_node("ScreenControls/BottomCenterZone/ButtonOrbit")
	var button_center: Vector2 = button.get_global_rect().position + button.get_global_rect().size * 0.5
	watch_signals(button)

	yield(_press(WORLD_POINT), "completed")
	yield(_move(WORLD_POINT + Vector2(40, 0), Vector2(40, 0)), "completed")
	yield(_move(button_center, Vector2(5, 5)), "completed")
	yield(_release(button_center), "completed")

	assert_eq(camera.rotating_calls, [true, false], "Drag starts and stops camera rotation exactly once.")
	assert_eq(camera.motion, [Vector2(40, 0), Vector2(5, 5)], "Motion over a HUD button still reaches the camera.")
	assert_signal_not_emitted(button, "pressed", "A world drag released over a button must not press it.")
	assert_eq(controller.clicks, [], "A drag is not a click.")
	assert_false(hud._pointer_router.is_gesture_active())


func test_press_on_hud_button_belongs_to_hud():
	var button: BaseButton = hud.get_node("ScreenControls/BottomCenterZone/ButtonInteract")
	var button_center: Vector2 = button.get_global_rect().position + button.get_global_rect().size * 0.5
	watch_signals(button)

	yield(_press(button_center), "completed")
	assert_false(hud._pointer_router.is_gesture_active(), "The router never sees presses the GUI took.")
	yield(_release(button_center), "completed")

	assert_signal_emitted(button, "pressed")
	assert_eq(controller.clicks, [])
	assert_eq(camera.rotating_calls, [])


func test_click_on_target_bracket_presses_nearest_bracket():
	var near = _add_bracket(WORLD_POINT, 1)
	var far = _add_bracket(WORLD_POINT + Vector2(60, 0), 2)
	watch_signals(near)
	watch_signals(far)

	yield(_press(WORLD_POINT + Vector2(5, 0)), "completed")
	yield(_release(WORLD_POINT + Vector2(5, 0)), "completed")

	assert_signal_emitted(near, "pressed")
	assert_signal_not_emitted(far, "pressed")
	assert_eq(controller.clicks, [], "Clicking a bracket selects it instead of clearing the selection.")


func test_drag_starting_on_target_bracket_rotates_camera():
	var bracket = _add_bracket(WORLD_POINT, 1)
	watch_signals(bracket)
	yield(_press(WORLD_POINT), "completed")
	yield(_move(WORLD_POINT + Vector2(0, 30), Vector2(0, 30)), "completed")
	yield(_release(WORLD_POINT + Vector2(0, 30)), "completed")
	assert_eq(camera.rotating_calls, [true, false])
	assert_signal_not_emitted(bracket, "pressed")


func test_blocked_controller_ignores_world_gestures():
	controller.blocked = true
	yield(_press(WORLD_POINT), "completed")
	yield(_release(WORLD_POINT), "completed")
	assert_eq(controller.clicks, [])


func test_pause_cancels_drag_and_stops_rotation():
	yield(_press(WORLD_POINT), "completed")
	yield(_move(WORLD_POINT + Vector2(40, 0), Vector2(40, 0)), "completed")
	hud._pointer_router.notification(Node.NOTIFICATION_PAUSED)
	assert_false(hud._pointer_router.is_gesture_active())
	assert_eq(camera.rotating_calls, [true, false])


func test_click_in_free_flight_leaves_free_flight():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	yield(_move(WORLD_POINT, Vector2(3, 0)), "completed")
	yield(_press(WORLD_POINT), "completed")
	assert_eq(camera.motion, [Vector2(3, 0)], "Captured motion steers the camera.")
	assert_eq(controller.free_flight_calls, [false])


# --- Scene rules (see pointer_router.gd header) ---

func test_hud_scene_follows_pointer_rules():
	var violations: Array = []
	_collect_violations(hud.get_node("ScreenControls"), violations)
	_collect_violations(hud.get_node("ProjectedTargetOverlay"), violations)
	assert_eq(violations, [], "Only buttons and sliders may take the mouse in the in-flight HUD.")


func test_target_bracket_never_takes_the_mouse():
	var bracket = ProjectedTargetBracketScene.instance()
	add_child_autofree(bracket)
	var violations: Array = []
	_collect_violations(bracket, violations, true)
	assert_eq(violations, [])


func test_button_children_never_take_the_mouse():
	var menu = MainMenuScene.instance()
	add_child_autofree(menu)
	var violations: Array = []
	for scene_root in [hud, menu]:
		for node in _all_nodes(scene_root):
			if node is BaseButton:
				for child in _all_nodes(node):
					if child != node and child is Control and child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
						violations.append(str(scene_root.get_path_to(child)))
	assert_eq(violations, [], "Controls inside buttons swallow the button's own clicks.")


func _collect_violations(root: Node, violations: Array, all_must_ignore: bool = false) -> void:
	for node in _all_nodes(root):
		if not node is Control or node.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if all_must_ignore or not (node is BaseButton or node is Range):
			violations.append(str(root.get_path_to(node)))


func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for child in root.get_children():
		out += _all_nodes(child)
	return out


# --- Helpers ---

func _add_bracket(center: Vector2, key: int) -> Control:
	hud.set_process(false)  # Keep the per-frame projector from moving or hiding hand-placed brackets.
	var bracket = ProjectedTargetBracketScene.instance()
	hud.projected_target_overlay.add_child(bracket)
	bracket.rect_size = Vector2(150, 150)
	bracket.rect_global_position = center - bracket.rect_size * 0.5
	hud._world_target_buttons[key] = bracket
	return bracket


func _make_mock(source: String, add_to_tree: bool = true) -> Node:
	var script = GDScript.new()
	script.source_code = source
	script.reload()
	var node = Camera.new() if source.begins_with("extends Camera") else Node.new()
	node.set_script(script)
	if add_to_tree:
		add_child_autofree(node)
	return node


func _press(position: Vector2):
	yield(_button(position, true), "completed")


func _release(position: Vector2):
	yield(_button(position, false), "completed")


func _button(position: Vector2, pressed: bool):
	var event = InputEventMouseButton.new()
	event.button_index = BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")


func _move(position: Vector2, relative: Vector2):
	var event = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	if pressed_left():
		event.button_mask = BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")


func pressed_left() -> bool:
	return is_instance_valid(hud) and hud._pointer_router.is_gesture_active()
