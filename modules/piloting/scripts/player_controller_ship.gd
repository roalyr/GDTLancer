# File: modules/piloting/scripts/player_controller_ship.gd
# Version 2.8 - Added Double-Click Move To command

extends Node

# --- References ---
var agent_script: Node = null
var agent_body: KinematicBody = null

# --- State ---
var _target_under_cursor: Spatial = null
var _selected_target: Spatial = null

# --- Constants ---
const DEFAULT_ORBIT_DIST = 3000.0
# Distance to project Move To command when double-clicking empty space
const DEFAULT_MOVE_TO_PROJECTION_DIST = 5000.0

# --- Initialization ---
func _ready():
	var parent = get_parent()
	if parent is KinematicBody and parent.has_method("command_stop"):
		agent_body = parent
		agent_script = parent
		print("Player Controller ready for: ", agent_script.agent_name)
		call_deferred("_find_camera_raycast_workaround") # Using workaround name
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		printerr("Player Controller Error: Parent invalid or missing command methods!")
		set_physics_process(false)
		set_process_input(false)
		return

# Workaround: Camera might not have RayCast immediately in _ready via GlobalRefs
# This waits a frame, then tries to get it. A signal-based approach might be better later.
func _find_camera_raycast_workaround():
	yield(get_tree(), "idle_frame") # Wait one frame
	if is_instance_valid(GlobalRefs.main_camera):
		# We removed the RayCast node dependency, this function is no longer needed
		# _camera_raycast = GlobalRefs.main_camera.get_node_or_null("TargetRayCast")
		# if not is_instance_valid(_camera_raycast):
		#	 printerr("Player Controller Error: Could not find 'TargetRayCast' on Main Camera!")
		pass # No RayCast node needed now
	else:
		printerr("Player Controller Error: Could not find Main Camera in GlobalRefs.")


# --- Physics Update ---
func _physics_process(delta):
	# Only update target under cursor if mouse is visible (for selection/clicks)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		_update_target_under_cursor()
	else:
		_target_under_cursor = null


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


# --- Input Event Handling ---
func _unhandled_input(event):
	var input_handled = false

	# --- Mouse Button Input ---
	if event is InputEventMouseButton:
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
				# Only process if mouse is visible
				if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
					if is_instance_valid(_target_under_cursor):
						if _selected_target != _target_under_cursor:
							_selected_target = _target_under_cursor
							print("Player selected target: ", _selected_target.name)
					elif not is_instance_valid(_target_under_cursor): # Clicked empty space
						if is_instance_valid(_selected_target):
							print("Player de-selected target.")
							_selected_target = null
					input_handled = true # Consume single click as well

	# --- Keyboard Commands & Mouse Toggle ---
	if not input_handled and is_instance_valid(agent_script): # Process only if mouse didn't handle it
		var command_action_key = ""
		if Input.is_action_just_pressed("command_approach"): command_action_key = "approach"
		elif Input.is_action_just_pressed("command_orbit"): command_action_key = "orbit"
		elif Input.is_action_just_pressed("command_flee"): command_action_key = "flee"
		elif Input.is_action_just_pressed("command_stop"): command_action_key = "stop"
		elif Input.is_action_just_pressed("command_move_direction"): command_action_key = "move_direction"
		elif Input.is_action_just_pressed("toggle_mouse_capture"): command_action_key = "toggle_mouse"

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
				"move_direction":
					if is_instance_valid(GlobalRefs.main_camera):
						var move_dir = -GlobalRefs.main_camera.global_transform.basis.z.normalized()
						print("Command Input: MOVE_DIRECTION ", move_dir); agent_script.command_move_direction(move_dir)
					else: print("Command Input: MoveDirection fail - camera invalid."); input_handled = false
				"toggle_mouse":
					if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					else: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_:
					input_handled = false # Unhandled action key

	# Consume event if handled
	if input_handled:
		get_viewport().set_input_as_handled()
