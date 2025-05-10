# File: modules/piloting/scripts/player_controller_ship.gd
# Version 3.8 - Speed control refactored for keyboard and slider synchronization.
extends Node

# --- References ---
var agent_script: Node = null  # Parent AgentBody (KinematicBody with agent.gd)
var agent_body: KinematicBody = null  # Same as agent_script in this context
var movement_system: Node = null  # Agent's MovementSystem component
var _main_camera: Camera = null
var _speed_slider: Slider = null

# --- Speed Control Values ---
var template_min_speed_actual: float = 0.0  # Ship's absolute minimum speed capability
var template_max_speed_actual: float = 300.0  # Ship's absolute maximum speed capability (from template)
var current_target_speed_normalized: float = 1.0  # Player's desired speed percentage (0.0 to 1.0)
const KEY_SPEED_INCREMENT_NORMALIZED: float = 0.05  # 5% change per key press

# --- State ---
var _target_under_cursor: Spatial = null
var _selected_target: Spatial = null setget _set_selected_target
var _is_free_flight_mode: bool = false
var _is_programmatically_setting_slider: bool = false

# --- Input Tracking State ---
var _lmb_pressed: bool = false
var _lmb_press_pos: Vector2 = Vector2.ZERO
var _lmb_press_time: int = 0
var _is_dragging: bool = false
var _last_tap_time: int = 0

# --- Constants ---
const DEFAULT_MOVE_TO_PROJECTION_DIST = 1e6
const DRAG_THRESHOLD_PX_SQ = 10 * 10
const DOUBLE_CLICK_TIME_MS = 400


func _ready():
	var parent = get_parent()
	if parent is KinematicBody and parent.has_method("command_stop"):
		agent_body = parent
		agent_script = parent  # agent.gd is on AgentBody

		# Attempt to get MovementSystem. Agent.gd should make this accessible.
		if agent_script.has_node("MovementSystem"):
			movement_system = agent_script.get_node("MovementSystem")

		if (
			not is_instance_valid(movement_system)
			or not movement_system.has_method("initialize_movement_params")
		):
			printerr(
				"PlayerController Error: Valid MovementSystem not found on agent: ",
				agent_script.name
			)
			set_physics_process(false)
			set_process_input(false)
			return

		print("Player Controller ready for: ", agent_script.agent_name)
		call_deferred("_deferred_ready_setup")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		printerr("Player Controller Error: Parent invalid or missing command methods!")
		set_physics_process(false)
		set_process_input(false)
		return


func _deferred_ready_setup():
	# Ensure GlobalRefs and HUD are ready
	if not is_instance_valid(GlobalRefs.main_hud):
		yield(GlobalRefs, "main_hud_ready")  # Assuming GlobalRefs could emit such a signal if needed
		if not is_instance_valid(GlobalRefs.main_hud):  # Check again
			printerr("PlayerController Error: Main HUD not available in GlobalRefs after wait.")
			return

	_speed_slider = GlobalRefs.main_hud.get_node_or_null(
		"ScreenControls/CenterRightZone/SliderControlRight"
	)
	if not is_instance_valid(_speed_slider):
		printerr("PlayerController Error: Speed slider not found in MainHUD.")
		# Potentially disable speed control features or log error further

	# Initialize speed capabilities from the agent's movement system
	# This assumes movement_system.max_move_speed holds the ship's template max speed at this point.
	template_max_speed_actual = movement_system.max_move_speed
	template_min_speed_actual = 0.0  # Or a game-defined minimum if ships don't fully stop

	current_target_speed_normalized = 1.0  # Start at 100% speed
	_update_agent_speed_cap_and_slider_visuals()

	# Connect to EventBus signals
	if EventBus:
		if not EventBus.is_connected(
			"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
		):
			EventBus.connect("player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled")
		if not EventBus.is_connected("player_stop_pressed", self, "_on_Player_Stop_Pressed"):
			EventBus.connect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
		if not EventBus.is_connected("player_orbit_pressed", self, "_on_Player_Orbit_Pressed"):
			EventBus.connect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
		if not EventBus.is_connected(
			"player_approach_pressed", self, "_on_Player_Approach_Pressed"
		):
			EventBus.connect("player_approach_pressed", self, "_on_Player_Approach_Pressed")
		if not EventBus.is_connected("player_flee_pressed", self, "_on_Player_Flee_Pressed"):
			EventBus.connect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
		# This connection is for when the SLIDER's value is changed by the user via main_hud.gd
		if not EventBus.is_connected(
			"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
		):
			EventBus.connect(
				"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
			)
	else:
		printerr("PlayerController Error: EventBus not available for signal connections.")

	call_deferred("_get_camera_reference")


func _get_camera_reference():
	yield(get_tree(), "idle_frame")  # Wait for scene tree to be fully ready
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera is Camera:
		_main_camera = GlobalRefs.main_camera
		print("Player Controller obtained camera reference.")
	else:
		printerr("Player Controller Error: Could not find valid Main Camera in GlobalRefs.")


func _physics_process(delta):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		_update_target_under_cursor()
	else:
		_target_under_cursor = null

	if _is_free_flight_mode:
		if is_instance_valid(_main_camera) and is_instance_valid(agent_script):
			var move_dir = -_main_camera.global_transform.basis.z.normalized()
			agent_script.command_move_direction(move_dir)
		elif is_instance_valid(agent_script):
			agent_script.command_stop()


func _update_target_under_cursor():
	_target_under_cursor = null
	if not is_instance_valid(agent_body):
		return
	var camera = get_viewport().get_camera()
	if not is_instance_valid(camera):
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_normal * Constants.TARGETING_RAY_LENGTH

	var space_state = agent_body.get_world().direct_space_state
	var result = space_state.intersect_ray(ray_origin, ray_end, [agent_body], 1)

	if result and result.collider is Spatial:
		_target_under_cursor = result.collider


func _set_selected_target(new_target: Spatial):
	if _selected_target == new_target:
		return

	_selected_target = new_target
	if EventBus:
		if is_instance_valid(_selected_target):
			EventBus.emit_signal("player_target_selected", _selected_target)
			print("Player selected target: ", _selected_target.name)
		else:
			EventBus.emit_signal("player_target_deselected")
			print("Player de-selected target.")


func deselect_current_target():
	if is_instance_valid(_selected_target):
		self._selected_target = null


func _unhandled_input(event):
	var input_handled = false

	if Input.is_action_just_pressed("toggle_free_flight"):
		_toggle_free_flight_mode()
		input_handled = true

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			_lmb_pressed = true
			_is_dragging = false
			_lmb_press_pos = event.position
			_lmb_press_time = OS.get_ticks_msec()
		else:  # Released
			if _lmb_pressed:
				_lmb_pressed = false
				var time_now = OS.get_ticks_msec()
				if _is_dragging:
					if (
						is_instance_valid(_main_camera)
						and _main_camera.has_method("set_is_rotating")
					):
						_main_camera.set_is_rotating(false)
					input_handled = true
				else:  # Tap/Click
					if time_now - _last_tap_time <= DOUBLE_CLICK_TIME_MS:
						_handle_double_click(event.position)
						_last_tap_time = 0  # Reset double click timer
					else:
						_handle_single_click(event.position)
						_last_tap_time = time_now
					input_handled = true
				_is_dragging = false

	elif event is InputEventMouseMotion and _lmb_pressed and not _is_dragging:
		if event.position.distance_squared_to(_lmb_press_pos) > DRAG_THRESHOLD_PX_SQ:
			_is_dragging = true
			_last_tap_time = 0  # Cancel potential double click
			if not _is_free_flight_mode:
				if is_instance_valid(_main_camera) and _main_camera.has_method("set_is_rotating"):
					_main_camera.set_is_rotating(true)

	# Keyboard commands (not consumed by mouse/touch release)
	if not input_handled:
		if not _is_free_flight_mode and is_instance_valid(agent_script):
			var command_action_key = ""
			if Input.is_action_just_pressed("command_approach"):
				command_action_key = "approach"
			elif Input.is_action_just_pressed("command_orbit"):
				command_action_key = "orbit"
			elif Input.is_action_just_pressed("command_flee"):
				command_action_key = "flee"

			if command_action_key != "":
				input_handled = true
				if is_instance_valid(_selected_target):
					match command_action_key:
						"approach":
							agent_script.command_approach(_selected_target)
						"orbit":
							agent_script.command_orbit(_selected_target)
						"flee":
							agent_script.command_flee(_selected_target)
					print(
						"Command Input: ", command_action_key.to_upper(), " ", _selected_target.name
					)
				else:
					print("Command Input: ", command_action_key, " failed - no target.")
					input_handled = false  # Don't consume if command failed

		# Speed adjustment keys (work in both modes)
		if Input.is_action_pressed("command_speed_up"):  # Use is_action_pressed for holding down
			current_target_speed_normalized = clamp(
				(
					current_target_speed_normalized
					+ KEY_SPEED_INCREMENT_NORMALIZED * event.get_action_strength("command_speed_up")
				),
				0.0,
				1.0
			)
			_update_agent_speed_cap_and_slider_visuals()
			input_handled = true
		elif Input.is_action_pressed("command_speed_down"):
			current_target_speed_normalized = clamp(
				(
					current_target_speed_normalized
					- (
						KEY_SPEED_INCREMENT_NORMALIZED
						* event.get_action_strength("command_speed_down")
					)
				),
				0.0,
				1.0
			)
			_update_agent_speed_cap_and_slider_visuals()
			input_handled = true

		if Input.is_action_just_pressed("command_stop"):
			_issue_stop_command()
			input_handled = true

	if input_handled:
		get_viewport().set_input_as_handled()


func _handle_single_click(click_pos: Vector2):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		var target = _raycast_for_target(click_pos)
		self._selected_target = target


# --- Helper Raycast Function ---
func _raycast_for_target(screen_pos: Vector2) -> Spatial:
	if not is_instance_valid(agent_body):
		return null
	var camera = get_viewport().get_camera()
	if not is_instance_valid(camera):
		return null
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_normal = camera.project_ray_normal(screen_pos)
	var ray_end = ray_origin + ray_normal * Constants.TARGETING_RAY_LENGTH
	var space_state = agent_body.get_world().direct_space_state
	var result = space_state.intersect_ray(ray_origin, ray_end, [agent_body], 1)
	if result and result.collider is Spatial:
		return result.collider
	else:
		return null


func _handle_double_click(click_pos: Vector2):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		if is_instance_valid(agent_script) and is_instance_valid(_main_camera):
			var ray_origin = _main_camera.project_ray_origin(click_pos)
			var ray_normal = _main_camera.project_ray_normal(click_pos)
			var target_point = ray_origin + ray_normal * DEFAULT_MOVE_TO_PROJECTION_DIST
			print("Input: Double-Click Move To ", target_point)
			agent_script.command_move_to(target_point)


# --- Signal Handlers for UI Button Presses via EventBus ---
func _on_Player_Free_Flight_Toggled():
	_toggle_free_flight_mode()


func _on_Player_Stop_Pressed():
	_issue_stop_command()


func _on_Player_Orbit_Pressed():
	if is_instance_valid(_selected_target) and is_instance_valid(agent_script):
		agent_script.command_orbit(_selected_target)
	else:
		print("PlayerController: Cannot Orbit - invalid target or agent.")


func _on_Player_Approach_Pressed():
	if is_instance_valid(_selected_target) and is_instance_valid(agent_script):
		agent_script.command_approach(_selected_target)
	else:
		print("PlayerController: Cannot Approach - invalid target or agent.")


func _on_Player_Flee_Pressed():
	if is_instance_valid(_selected_target) and is_instance_valid(agent_script):
		agent_script.command_flee(_selected_target)
	else:
		print("PlayerController: Cannot Flee - invalid target or agent.")


# --- Speed Control Logic ---
# Called when the MainHUD's speed slider is changed by the USER.
func _on_Player_Ship_Speed_Slider_Changed_By_HUD(slider_ui_value: float):
	if _is_programmatically_setting_slider:
		return  # Avoid loop if we set the slider from code

	# Slider value is 0-100, 0=max speed, 100=min speed (inverted UI)
	current_target_speed_normalized = (100.0 - slider_ui_value) / 100.0
	current_target_speed_normalized = clamp(current_target_speed_normalized, 0.0, 1.0)
	_update_agent_speed_cap_and_slider_visuals()  # Update agent and ensure slider reflects clamped value


# Central function to update agent's speed cap and the UI slider's visual state
func _update_agent_speed_cap_and_slider_visuals():
	if not is_instance_valid(movement_system):
		printerr("PlayerController: MovementSystem invalid, cannot update speed.")
		return

	# 1. Calculate the new actual speed cap for the movement system
	var new_actual_speed_cap = lerp(
		template_min_speed_actual, template_max_speed_actual, current_target_speed_normalized
	)
	movement_system.max_move_speed = new_actual_speed_cap
	# print("Player Speed Cap set to: ", movement_system.max_move_speed, " (Normalized: ", current_target_speed_normalized, ")")

	# 2. Update the UI Slider's visual position
	if is_instance_valid(_speed_slider):
		_is_programmatically_setting_slider = true
		var slider_display_value = current_target_speed_normalized * 100.0
		# The slider is inverted (0 means full speed, 100 means min speed)
		_speed_slider.value = 100.0 - clamp(slider_display_value, 0.0, 100.0)
		_is_programmatically_setting_slider = false
	# else:
	# print("PlayerController: Speed slider instance is not valid for UI update.")


func _issue_stop_command():
	if not is_instance_valid(agent_script):
		printerr("PlayerController Error: AgentScript invalid, cannot issue stop command.")
		return

	print("Command Input: STOP")
	agent_script.command_stop()

	if _is_free_flight_mode:
		_exit_free_flight_mode_common()  # Common exit logic


func _toggle_free_flight_mode():
	_is_free_flight_mode = not _is_free_flight_mode
	print("Toggling Free Flight Mode to: ", "ON" if _is_free_flight_mode else "OFF")

	if _is_free_flight_mode:  # Entering Free Flight
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if is_instance_valid(_main_camera) and _main_camera.has_method("set_rotation_input_active"):
			_main_camera.set_rotation_input_active(true)
		_is_dragging = false
		if is_instance_valid(_main_camera) and _main_camera.has_method("set_is_rotating"):
			_main_camera.set_is_rotating(false)  # Ensure external drag rotation is off
	else:  # Exiting Free Flight (not via stop command, but by toggle)
		_exit_free_flight_mode_common()
		if is_instance_valid(agent_script):  # Issue stop if exiting via toggle
			agent_script.command_stop()


func _exit_free_flight_mode_common():
	_is_free_flight_mode = false  # Ensure state is OFF
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if is_instance_valid(_main_camera):
		if _main_camera.has_method("set_rotation_input_active"):
			_main_camera.set_rotation_input_active(false)
		if _main_camera.has_method("set_is_rotating"):
			_main_camera.set_is_rotating(false)
	_lmb_pressed = false
	_is_dragging = false


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus:
			if EventBus.is_connected(
				"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
			):
				EventBus.disconnect(
					"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
				)
			if EventBus.is_connected("player_stop_pressed", self, "_on_Player_Stop_Pressed"):
				EventBus.disconnect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
			if EventBus.is_connected("player_orbit_pressed", self, "_on_Player_Orbit_Pressed"):
				EventBus.disconnect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
			if EventBus.is_connected(
				"player_approach_pressed", self, "_on_Player_Approach_Pressed"
			):
				EventBus.disconnect("player_approach_pressed", self, "_on_Player_Approach_Pressed")
			if EventBus.is_connected("player_flee_pressed", self, "_on_Player_Flee_Pressed"):
				EventBus.disconnect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
			if EventBus.is_connected(
				"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
			):
				EventBus.disconnect(
					"player_ship_speed_changed", self, "_on_Player_Ship_Speed_Slider_Changed_By_HUD"
				)
