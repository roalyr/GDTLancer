# File: modules/piloting/scripts/player_controller_ship.gd
# Version 3.7 - Stop command now also exits free flight mode.

extends Node

# --- References ---
var agent_script: Node = null
var agent_body: KinematicBody = null
var _main_camera: Camera = null

# --- State ---
var _target_under_cursor: Spatial = null  # Updated in _physics_process
var _selected_target: Spatial = null setget _set_selected_target
var _is_free_flight_mode: bool = false

# --- Input Tracking State ---
var _lmb_pressed: bool = false
var _lmb_press_pos: Vector2 = Vector2.ZERO
var _lmb_press_time: int = 0  # Using OS.get_ticks_msec()
var _is_dragging: bool = false
var _last_tap_time: int = 0
# Removed _potential_double_click flag

# --- Constants ---
const DEFAULT_ORBIT_DIST = 3000.0
const DEFAULT_MOVE_TO_PROJECTION_DIST = 1e6
const DRAG_THRESHOLD_PX_SQ = 10 * 10  # Squared distance threshold to start drag
const DOUBLE_CLICK_TIME_MS = 400  # Max milliseconds between taps for double-click


# --- Initialization ---
func _ready():
	# Connect to EventBus signals
	if EventBus:
		# Ensure signal name matches exactly what's emitted
		if not EventBus.is_connected(
			"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
		):
			var err = EventBus.connect(
				"player_free_flight_toggled", self, "_on_Player_Free_Flight_Toggled"
			)
			if err != OK:
				printerr(
					"PlayerController Error: Failed connect player_free_flight_toggled signal! Code: ",
					err
				)

		if not EventBus.is_connected("player_stop_pressed", self, "_on_Player_Stop_Pressed"):
			var err = EventBus.connect("player_stop_pressed", self, "_on_Player_Stop_Pressed")
			if err != OK:
				printerr(
					"PlayerController Error: Failed connect player_stop_pressed signal! Code: ", err
				)

		if not EventBus.is_connected("player_orbit_pressed", self, "_on_Player_Orbit_Pressed"):
			var err = EventBus.connect("player_orbit_pressed", self, "_on_Player_Orbit_Pressed")
			if err != OK:
				printerr(
					"PlayerController Error: Failed connect player_orbit_pressed signal! Code: ",
					err
				)

		if not EventBus.is_connected(
			"player_approach_pressed", self, "_on_Player_Approach_Pressed"
		):
			var err = EventBus.connect(
				"player_approach_pressed", self, "_on_Player_Approach_Pressed"
			)
			if err != OK:
				printerr(
					"PlayerController Error: Failed connect player_orbit_pressed signal! Code: ",
					err
				)  # Typo in original error message fixed

		if not EventBus.is_connected("player_flee_pressed", self, "_on_Player_Flee_Pressed"):
			var err = EventBus.connect("player_flee_pressed", self, "_on_Player_Flee_Pressed")
			if err != OK:
				printerr(  # Typo in original error message fixed
					"PlayerController Error: Failed connect player_flee_pressed signal! Code: ", err
				)

	else:
		printerr("PlayerController Error: EventBus not available!")

	var parent = get_parent()
	if parent is KinematicBody and parent.has_method("command_stop"):
		agent_body = parent
		agent_script = parent
		print("Player Controller ready for: ", agent_script.agent_name)
		call_deferred("_get_camera_reference")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		printerr("Player Controller Error: Parent invalid or missing command methods!")
		set_physics_process(false)
		set_process_input(false)
		return


func _get_camera_reference():
	yield(get_tree(), "idle_frame")
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera is Camera:
		_main_camera = GlobalRefs.main_camera
		print("Player Controller obtained camera reference.")
	else:
		printerr("Player Controller Error: Could not find valid Main Camera in GlobalRefs.")


# --- Physics Update ---
func _physics_process(delta):
	# Always update target under cursor when mouse is visible, might be needed for hover effects later
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		_update_target_under_cursor()
	else:
		_target_under_cursor = null  # Clear if mouse not visible (e.g., free flight)

	# Free Flight Movement (Unchanged)
	if _is_free_flight_mode:
		if is_instance_valid(_main_camera) and is_instance_valid(agent_script):
			var move_dir = -_main_camera.global_transform.basis.z.normalized()
			agent_script.command_move_direction(move_dir)
		elif is_instance_valid(agent_script):
			agent_script.command_stop()  # Existing stop if camera invalid
		# Removed warping logic


# --- Target Raycast ---
func _update_target_under_cursor():
	# Reset first
	_target_under_cursor = null
	if not is_instance_valid(agent_body):
		return
	var camera = get_viewport().get_camera()  # Use viewport camera for UI interaction
	if not is_instance_valid(camera):
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_normal * Constants.TARGETING_RAY_LENGTH

	var space_state = agent_body.get_world().direct_space_state
	var result = space_state.intersect_ray(ray_origin, ray_end, [agent_body], 1)  # Mask 1

	if result and result.collider is Spatial:
		_target_under_cursor = result.collider
		# TODO: Highlight _target_under_cursor (visual feedback)


# --- Target Selection Setter ---
func _set_selected_target(new_target: Spatial):
	if _selected_target == new_target:
		return

	_selected_target = new_target

	if is_instance_valid(_selected_target):
		if EventBus:
			EventBus.emit_signal("player_target_selected", _selected_target)
		print("Player selected target: ", _selected_target.name)
	else:
		# Handle deselection explicitly via signal
		if EventBus:
			EventBus.emit_signal("player_target_deselected")
		print("Player de-selected target.")


# --- Public Deselect Function --- (For UI Button)
func deselect_current_target():
	if is_instance_valid(_selected_target):
		self._selected_target = null  # Will trigger deselection signal via setter


# --- Input Event Handling ---
func _unhandled_input(event):
	var input_handled = false

	# --- Free Flight Toggle (Keyboard - Direct Check Re-added) ---
	if Input.is_action_just_pressed("toggle_free_flight"):
		_toggle_free_flight()
		input_handled = true  # CONSUME the input event

	# --- LMB / Touch Input Handling ---
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			_lmb_pressed = true
			_is_dragging = false
			_lmb_press_pos = event.position
			_lmb_press_time = OS.get_ticks_msec()
			# Don't handle yet
		else:  # Released
			if _lmb_pressed:
				_lmb_pressed = false
				var time_now = OS.get_ticks_msec()
				if _is_dragging:
					# End of Drag
					if (
						is_instance_valid(_main_camera)
						and _main_camera.has_method("set_is_rotating")
					):
						_main_camera.set_is_rotating(false)
					input_handled = true  # CONSUME event
				else:
					# End of Tap/Click
					if time_now - _last_tap_time <= DOUBLE_CLICK_TIME_MS:
						_handle_double_click(event.position)
						_last_tap_time = 0
					else:
						_handle_single_click(event.position)
						_last_tap_time = time_now
					input_handled = true  # CONSUME event
				_is_dragging = false

	# --- Mouse Motion / Touch Drag ---
	elif event is InputEventMouseMotion and _lmb_pressed and not _is_dragging:
		if event.position.distance_squared_to(_lmb_press_pos) > DRAG_THRESHOLD_PX_SQ:
			# Start Drag
			_is_dragging = true
			_last_tap_time = 0
			if not _is_free_flight_mode:
				if is_instance_valid(_main_camera) and _main_camera.has_method("set_is_rotating"):
					_main_camera.set_is_rotating(true)
			# Let camera consume motion event if it uses it

	# --- Other Keyboard Commands (Only if not in free flight *unless* it's stop) --- # MODIFIED CONDITION
	# Stop command check is now handled separately inside the helper.
	elif not _is_free_flight_mode and is_instance_valid(agent_script):  # Original condition kept for other commands
		# Check only if event wasn't handled by LMB/Touch release
		if not input_handled:
			var command_action_key = ""
			if Input.is_action_just_pressed("command_approach"):
				command_action_key = "approach"
			elif Input.is_action_just_pressed("command_orbit"):
				command_action_key = "orbit"
			elif Input.is_action_just_pressed("command_flee"):
				command_action_key = "flee"
			# Stop key check moved below

			if command_action_key != "":
				input_handled = true  # CONSUME event if handled
				match command_action_key:
					"approach", "orbit", "flee":
						if is_instance_valid(_selected_target):
							match command_action_key:
								"approach":
									agent_script.command_approach(_selected_target)
								"orbit":
									agent_script.command_orbit(_selected_target)  # Assuming default distance/direction is ok here
								"flee":
									agent_script.command_flee(_selected_target)
							print(
								"Command Input: ",
								command_action_key.to_upper(),
								" ",
								_selected_target.name
							)
						else:
							print("Command Input: ", command_action_key, " failed - no target.")
							input_handled = false  # Don't consume if failed
					_:
						input_handled = false  # Don't consume unknown actions

	# --- Stop Command (Keyboard) - Checked Regardless of Free Flight Mode --- # NEW CHECK POSITION
	# Moved outside the !_is_free_flight_mode block
	if not input_handled and Input.is_action_just_pressed("command_stop"):
		_issue_stop_command()  # Call helper
		input_handled = true  # CONSUME event

	# --- Consume Input ---
	if input_handled:
		get_viewport().set_input_as_handled()


# --- Click Handling Logic ---
func _handle_single_click(click_pos: Vector2):
	# Process click only when mouse is visible
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		var target = _raycast_for_target(click_pos)
		self._selected_target = target


func _handle_double_click(click_pos: Vector2):
	# Process double click only when mouse is visible
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		if is_instance_valid(agent_script) and is_instance_valid(_main_camera):
			var ray_origin = _main_camera.project_ray_origin(click_pos)
			var ray_normal = _main_camera.project_ray_normal(click_pos)
			var target_point = ray_origin + ray_normal * DEFAULT_MOVE_TO_PROJECTION_DIST
			print("Input: Double-Click Move To ", target_point)
			agent_script.command_move_to(target_point)
		# else: print("Move To Failed")


# --- Signal Handling ---


# ---- From GUI ----
func _on_Player_Free_Flight_Toggled():
	_toggle_free_flight()


func _on_Player_Stop_Pressed():
	# agent_script.command_stop() # Replaced by helper call
	_issue_stop_command()  # Call helper


func _on_Player_Orbit_Pressed():
	# Check target validity before issuing command
	if is_instance_valid(_selected_target) and is_instance_valid(agent_script):
		agent_script.command_orbit(_selected_target)  # Assuming default distance/direction is okay
	else:
		print("PlayerController: Cannot Orbit - invalid target or agent.")


func _on_Player_Approach_Pressed():
	# Check target validity before issuing command
	if is_instance_valid(_selected_target) and is_instance_valid(agent_script):
		agent_script.command_approach(_selected_target)
	else:
		print("PlayerController: Cannot Approach - invalid target or agent.")


func _on_Player_Flee_Pressed():
	# Check target validity before issuing command
	if is_instance_valid(_selected_target) and is_instance_valid(agent_script):
		agent_script.command_flee(_selected_target)
	else:
		print("PlayerController: Cannot Flee - invalid target or agent.")


# --- Command Issuance Helpers --- # NEW SECTION
func _issue_stop_command():
	if not is_instance_valid(agent_script):
		printerr("PlayerController Error: AgentScript invalid, cannot issue stop command.")
		return

	print("Command Input: STOP")
	agent_script.command_stop()

	# Check if in free flight mode and disable it if necessary
	if _is_free_flight_mode:
		# Directly call the parts of _toggle_free_flight needed to exit the mode,
		# without toggling the state variable again.
		print("Stop command issued while in Free Flight. Exiting Free Flight...")
		_is_free_flight_mode = false  # Set state directly
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if is_instance_valid(_main_camera):
			if _main_camera.has_method("set_rotation_input_active"):
				_main_camera.set_rotation_input_active(false)
			if _main_camera.has_method("set_is_rotating"):
				_main_camera.set_is_rotating(false)
		# The stop command was already issued above, so agent_script.command_stop() from the original
		# _toggle_free_flight's exit logic is not needed here.
		_lmb_pressed = false
		_is_dragging = false


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


# --- Free Flight Toggle Logic ---
# Uses CAPTURED mode
func _toggle_free_flight():
	# We now only handle *entering* free flight here, or toggling when
	# triggered by its dedicated key/button. Exiting via Stop is handled separately.
	var intended_state = not _is_free_flight_mode

	print("Toggling Free Flight Mode. Intended State: ", "ON" if intended_state else "OFF")

	if intended_state == true:  # Entering Free Flight
		_is_free_flight_mode = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # Using CAPTURED
		if is_instance_valid(_main_camera) and _main_camera.has_method("set_rotation_input_active"):
			_main_camera.set_rotation_input_active(true)
		_is_dragging = false  # Clear drag state
		if is_instance_valid(_main_camera) and _main_camera.has_method("set_is_rotating"):
			_main_camera.set_is_rotating(false)
	elif _is_free_flight_mode == true:  # Explicitly toggling OFF (not via stop command)
		_is_free_flight_mode = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if is_instance_valid(_main_camera):
			if _main_camera.has_method("set_rotation_input_active"):
				_main_camera.set_rotation_input_active(false)
			if _main_camera.has_method("set_is_rotating"):
				_main_camera.set_is_rotating(false)
		# If toggling off normally, issue a stop command as well.
		if is_instance_valid(agent_script):
			# Call the helper to ensure consistency, though it won't toggle free flight again
			_issue_stop_command()
		_lmb_pressed = false
		_is_dragging = false
