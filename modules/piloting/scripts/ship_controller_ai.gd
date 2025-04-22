# File: modules/piloting/scripts/ship_controller_ai.gd
# Attach to a Node child of the AgentBody KinematicBody in npc_agent.tscn
# Version 2.0 - Works with agent.gd v2.0 (merged movement)

extends Node

# --- Configuration (Set via initialize) ---
var target_position: Vector3 = Vector3.ZERO
var stopping_distance: float = 10.0

# --- State ---
var is_active: bool = false # Determines if AI tries to move

# --- References ---
var agent_script: Node = null # Reference to the parent agent.gd script instance
var agent_body: KinematicBody = null # Reference to the parent KinematicBody

# --- Initialization ---
func _ready():
	# Get references to parent agent node and script
	var parent = get_parent()
	if parent is KinematicBody and parent.has_method("set_thrust_input") and parent.has_method("set_look_input"):
		agent_body = parent
		agent_script = parent # The script is directly on the KinematicBody parent
		# Optional Debug: print("AI Controller ready for: ", agent_script.agent_name)
	else:
		printerr("AI Controller Error: Parent node is not an Agent KinematicBody with required methods!")
		is_active = false
		set_physics_process(false) # Disable processing if setup is wrong

# Called by WorldManager's spawn_agent function (via initialize dictionary)
func initialize(config: Dictionary):
	if config.has("stopping_distance"):
		self.stopping_distance = config.stopping_distance
	# Only become active if given a valid initial target
	if config.has("initial_target") and config.initial_target is Vector3:
		set_target(config.initial_target)
	else:
		is_active = false
		if is_instance_valid(agent_body): print("AI Controller Warning: No initial target provided for ", agent_body.name)

# --- Physics Update (Decision Making) ---
func _physics_process(delta):
	# Don't run if inactive or references are bad
	if not is_active or not is_instance_valid(agent_body) or not is_instance_valid(agent_script):
		# Ensure we signal stop if inactive
		if is_instance_valid(agent_script):
			agent_script.set_thrust_input(Vector3.ZERO)
		return

	var current_pos = agent_body.global_transform.origin
	var distance_to_target = current_pos.distance_to(target_position)

	if distance_to_target > stopping_distance:
		# --- Still moving towards target ---
		var direction_to_target = (target_position - current_pos)
		if direction_to_target.length_squared() > 0.001: # Check direction is valid
			direction_to_target = direction_to_target.normalized()
			# Command the agent to look towards the target direction
			agent_script.set_look_input(direction_to_target)
			# Command the agent to apply thrust in its forward direction
			agent_script.set_thrust_input(-agent_body.global_transform.basis.z)
		else:
			# Edge case: Already at target but distance check somehow failed? Stop thrust.
			agent_script.set_thrust_input(Vector3.ZERO)
			_handle_target_reached() # Treat as reached
	else:
		# --- Target Reached ---
		agent_script.set_thrust_input(Vector3.ZERO) # Command stop
		_handle_target_reached()


# --- Event Handling ---
func _handle_target_reached():
	if not is_instance_valid(agent_body): return # Safety check

	print(agent_body.name, " reached target: ", target_position, ". Emitting signal.")
	is_active = false # Stop this AI controller instance from processing further
	# Emit global signal via EventBus - WorldManager listens for this
	EventBus.emit_signal("agent_reached_destination", agent_body)


# --- Public Functions ---
# Sets a new target and reactivates the AI
func set_target(new_target: Vector3):
	target_position = new_target
	is_active = true # Activate when given a target
	# Optional Debug:
	# if is_instance_valid(agent_body): print(agent_body.name, " AI target set to: ", new_target)
