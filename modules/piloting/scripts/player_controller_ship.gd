# File: modules/piloting/scripts/player_controller_ship.gd
# Version 3.0 - Added Free Flight mode.

extends Node

# --- References ---
var agent_script: Node = null
var agent_body: KinematicBody = null
var _main_camera: Camera = null # Added for convenience

# --- State ---
var _target_under_cursor: Spatial = null
var _selected_target: Spatial = null setget _set_selected_target # ADDED setget
var _is_free_flight_mode: bool = false # ADDED: Free flight state flag

# --- Constants ---
const DEFAULT_ORBIT_DIST = 3000.0
# Distance to project Move To command when double-clicking empty space
const DEFAULT_MOVE_TO_PROJECTION_DIST = 1e6

# --- Initialization ---
func _ready():
	var parent = get_parent()
	if parent is KinematicBody and parent.has_method("command_stop"):
		agent_body = parent
		agent_script = parent
		print("Player Controller ready for: ", agent_script.agent_name)
		# Ensure camera reference is obtained early
		call_deferred("_get_camera_reference")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Start with mouse visible
	else:
		printerr("Player Controller Error: Parent invalid or missing command methods!")
		set_physics_process(false)
		set_process_input(false)
		return

# Renamed from _find_camera_raycast_workaround
func _get_camera_reference():
	yield(get_tree(), "idle_frame") # Wait one frame
	if is_instance_valid(GlobalRefs.main_camera) and GlobalRefs.main_camera is Camera:
		_main_camera = GlobalRefs.main_camera
		print("Player Controller obtained camera reference.")
	else:
		printerr("Player Controller Error: Could not find valid Main Camera in GlobalRefs.")


# --- Physics Update ---
func _physics_process(delta):
	# Update target under cursor only when mouse is visible (not in free flight)
	if not _is_free_flight_mode and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		_update_target_under_cursor()
	else:
		_target_under_cursor = null

	# --- Free Flight Movement --- ADDED Section
	if _is_free_flight_mode:
		if is_instance_valid(_main_camera) and is_instance_valid(agent_script):
			var move_dir = -_main_camera.global_transform.basis.z.normalized()
			# Constantly issue move direction command
			agent_script.command_move_direction(move_dir)
		elif is_instance_valid(agent_script):
			# If camera invalid, stop to prevent errors
			agent_script.command_stop()
			# Optionally: Toggle free flight off automatically?
			# _toggle_free_flight()



func _update_target_under_cursor():
	_target_under_cursor = null
	if not is_instance_valid(agent_body): # Need agent to get world
		return
	var camera = get_viewport().get_camera()
	if not is_instance_valid(camera):
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var ray_length = Constants.TARGETING_RAY_LENGTH
	var ray_end = ray_origin + ray_normal * ray_length

	var space_state = agent_body.get_world().direct_space_state
	var collision_mask = 1 # Layer 1 -> "targetable"
	var exclude_array = [agent_body]

	var result = space_state.intersect_ray(ray_origin, ray_end,
			exclude_array, collision_mask)

	if result:
		if result.collider is Spatial:
			_target_under_cursor = result.collider
			# TODO: Highlight _target_under_cursor

func _set_selected_target(new_target: Spatial):
	if _selected_target == new_target:
		return # No change

	_selected_target = new_target

	if is_instance_valid(_selected_target):
		# Emit signal via EventBus when a valid target is selected
		if EventBus:
			EventBus.emit_signal("player_target_selected", _selected_target)
		print("Player selected target: ", _selected_target.name) # Keep existing print
	else:
		# Emit signal via EventBus when target is deselected (becomes null)
		if EventBus:
			EventBus.emit_signal("player_target_deselected")
		print("Player de-selected target.") # Keep existing print

# --- Input Event Handling ---
func _unhandled_input(event):
	var input_handled = false

	# --- Mouse Button Input (Target Selection) ---
	# Only allow clicking targets when NOT in free flight mode
	if not _is_free_flight_mode and event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			# Check for double-click FIRST
			if event.doubleclick:
				# --- Double Click Handling (Move To Point) ---
				if is_instance_valid(agent_script):
					var camera = get_viewport().get_camera()
					if is_instance_valid(camera):
						var mouse_pos = event.position
						var ray_origin = camera.project_ray_origin(mouse_pos)
						var ray_normal = camera.project_ray_normal(mouse_pos)
						# Calculate point some distance along ray
						var target_point = ray_origin + \
								ray_normal * DEFAULT_MOVE_TO_PROJECTION_DIST
						print("Input: Double-Click Move To ", target_point)
						agent_script.command_move_to(target_point)
						input_handled = true
					else:
						print("Move To Failed: Camera invalid")
				else:
					print("Move To Failed: Agent invalid")
			else:
				# --- Single Click Handling (Target Selection) ---
				if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
					self._selected_target = _target_under_cursor
					input_handled = true # Consume single click

	# --- Keyboard Commands & Mode Toggle ---
	# Allow toggling free flight regardless of other commands
	if Input.is_action_just_pressed("toggle_free_flight"): # MODIFIED Action Name
		_toggle_free_flight()
		input_handled = true # Consume the toggle action

	# Process other commands ONLY if NOT in free flight mode
	elif not _is_free_flight_mode and is_instance_valid(agent_script):
		var command_action_key = ""
		if Input.is_action_just_pressed("command_approach"): command_action_key = "approach"
		elif Input.is_action_just_pressed("command_orbit"): command_action_key = "orbit"
		elif Input.is_action_just_pressed("command_flee"): command_action_key = "flee"
		elif Input.is_action_just_pressed("command_stop"): command_action_key = "stop"
		# Removed "command_move_direction" as it's handled by free flight now
		# Removed "toggle_mouse_capture"

		if command_action_key != "":
			input_handled = true # Assume handled unless check fails

			match command_action_key:
				"approach", "orbit", "flee":
					if is_instance_valid(_selected_target):
						match command_action_key:
							"approach": agent_script.command_approach(_selected_target)
							"orbit": agent_script.command_orbit(_selected_target, DEFAULT_ORBIT_DIST)
							"flee": agent_script.command_flee(_selected_target)
						print("Command Input: ", command_action_key.to_upper()," ", _selected_target.name)
					else:
						print("Command Input: ", command_action_key," failed - no target.")
						input_handled = false
				"stop":
					print("Command Input: STOP"); agent_script.command_stop()
				_:
					input_handled = false # Unhandled action key

	# Consume event if handled
	if input_handled:
		get_viewport().set_input_as_handled()

# --- Free Flight Toggle Logic --- ADDED Function
func _toggle_free_flight():
	_is_free_flight_mode = not _is_free_flight_mode
	print("Free Flight Mode: ", "ON" if _is_free_flight_mode else "OFF")

	if _is_free_flight_mode:
		# --- Entering Free Flight ---
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# Activate camera rotation input externally
		if is_instance_valid(_main_camera) and _main_camera.has_method("set_rotation_input_active"):
			_main_camera.set_rotation_input_active(true)
		# Deselect any current target when entering free flight
		if is_instance_valid(_selected_target):
			self._selected_target = null
		# Movement command is handled in _physics_process
	else:
		# --- Exiting Free Flight ---
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Deactivate camera rotation input (will still work if RMB is held)
		if is_instance_valid(_main_camera) and _main_camera.has_method("set_rotation_input_active"):
			_main_camera.set_rotation_input_active(false)
		# Stop the ship
		if is_instance_valid(agent_script):
			agent_script.command_stop()
