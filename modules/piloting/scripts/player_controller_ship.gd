# File: modules/piloting/scripts/player_controller_ship.gd
# Version 2.4 - Strict formatting, updated command calls

extends Node

# --- References ---
var agent_script: Node = null
var agent_body: KinematicBody = null
var _camera_raycast: RayCast = null

# --- State ---
var _target_under_cursor: CollisionObject = null
var _selected_target: Spatial = null

# --- Default Command Distances ---
# Approach distance is dynamic now
const DEFAULT_ORBIT_DIST = 3000.0
# Keep Range is now Flee (no distance needed)

# --- Initialization ---
func _ready():
	var parent = get_parent()
	if parent is KinematicBody and parent.has_method("command_stop"):
		agent_body = parent
		agent_script = parent
		print("Player Controller ready for: ", agent_script.agent_name)
		call_deferred("_find_camera_raycast")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		printerr("Player Controller Error: Parent invalid or missing command methods!")
		set_physics_process(false)
		set_process_input(false)
		return

func _find_camera_raycast():
	if is_instance_valid(GlobalRefs.main_camera):
		_camera_raycast = GlobalRefs.main_camera.get_node_or_null("TargetRayCast")
		if not is_instance_valid(_camera_raycast):
			printerr("Player Controller Error: Could not find 'TargetRayCast' on Main Camera!")
		# else: print("Player Controller: Found camera RayCast.")
	else:
		printerr("Player Controller Error: Could not find Main Camera in GlobalRefs.")


# --- Physics Update ---
func _physics_process(delta):
	_update_target_under_cursor()


func _update_target_under_cursor():
	_target_under_cursor = null
	if not is_instance_valid(_camera_raycast):
		return

	_camera_raycast.force_raycast_update()
	if _camera_raycast.is_colliding():
		var collider = _camera_raycast.get_collider()
		if collider is CollisionObject and collider != agent_body:
			if collider is Spatial:
				_target_under_cursor = collider
				# TODO: Add visual indicator


# --- Input Event Handling ---
func _unhandled_input(event):
	# Target Selection (LMB - Action: "select_target")
	if Input.is_action_just_pressed("select_target"):
		if is_instance_valid(_target_under_cursor):
			if _selected_target != _target_under_cursor:
				_selected_target = _target_under_cursor
				print("Player selected target: ", _selected_target.name)
		# Optional Deselect
		# elif not is_instance_valid(_target_under_cursor):
		#	 if is_instance_valid(_selected_target):
		#		 print("Player de-selected target.")
		#		 _selected_target = null
		get_viewport().set_input_as_handled()
		return # Consume select target action

	if not is_instance_valid(agent_script):
		return # Agent script must be valid

	# --- Keyboard Commands & Mouse Toggle ---
	var command_issued = false
	var command_action_key = ""

	# Check actions (ensure Input Map reflects these, e.g., command_flee instead of keep_range)
	if Input.is_action_just_pressed("command_approach"): command_action_key = "approach"
	elif Input.is_action_just_pressed("command_orbit"): command_action_key = "orbit"
	elif Input.is_action_just_pressed("command_flee"): command_action_key = "flee"
	elif Input.is_action_just_pressed("command_stop"): command_action_key = "stop"
	elif Input.is_action_just_pressed("command_move_direction"): command_action_key = "move_direction"
	elif Input.is_action_just_pressed("toggle_mouse_capture"): command_action_key = "toggle_mouse"


	# --- Handle Actions ---
	if command_action_key != "":
		command_issued = true # Assume handled unless check fails

		# Handle target-based commands first
		if command_action_key in ["approach", "orbit", "flee"]:
			if is_instance_valid(_selected_target):
				match command_action_key:
					"approach":
						print("Command Input: APPROACH ", _selected_target.name)
						agent_script.command_approach(_selected_target) # No distance
					"orbit":
						print("Command Input: ORBIT ", _selected_target.name)
						agent_script.command_orbit(_selected_target, DEFAULT_ORBIT_DIST)
					"flee":
						print("Command Input: FLEE from ", _selected_target.name)
						agent_script.command_flee(_selected_target) # No distance
			else:
				print("Command Input: ", command_action_key, " failed - no target selected.")
				command_issued = false # Failed, don't consume? Or maybe still consume? Consume.

		# Handle non-target commands
		elif command_action_key == "stop":
			print("Command Input: STOP")
			agent_script.command_stop()
		elif command_action_key == "move_direction":
			if is_instance_valid(GlobalRefs.main_camera):
				var move_dir = -GlobalRefs.main_camera.global_transform.basis.z.normalized()
				print("Command Input: MOVE_DIRECTION ", move_dir)
				agent_script.command_move_direction(move_dir)
			else:
				print("Command Input: MoveDirection failed - camera ref invalid.")
				command_issued = false
		elif command_action_key == "toggle_mouse":
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			command_issued = false # Should not be reached

		# Consume input if a relevant action was processed
		if command_issued:
			get_viewport().set_input_as_handled()
