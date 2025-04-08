# File: modules/piloting/scripts/ship_controller_ai.gd
# Attach to a Node child of the Agent KinematicBody in npc_agent.tscn
# Version 1.3 - Despawns upon reaching target

extends Node

# --- Configuration ---
var target_position: Vector3 = Vector3.ZERO
var stopping_distance: float = 1.0 # Increased further for easier trigger

# --- State ---
var is_active: bool = false

# --- References ---
var agent_body: KinematicBody = null
var movement_comp: Node = null

func _ready():
	var parent = get_parent()
	if parent is KinematicBody:
		agent_body = parent
		movement_comp = agent_body.get_node_or_null("MovementComponent")
		if not movement_comp or not movement_comp.has_method("move"):
			printerr("ShipControllerAI Error: Invalid MovementComponent found for ", agent_body.name if agent_body else "UNKNOWN")
			is_active = false
		elif not agent_body.has_method("set_movement_input"):
			printerr("ShipControllerAI Error: Parent agent node is missing expected methods!")
			is_active = false
	else:
		printerr("ShipControllerAI Error: Parent node is not a KinematicBody!")
		is_active = false
	# No randomize needed here anymore

func initialize(config: Dictionary):
	if config.has("stopping_distance"):
		self.stopping_distance = config.stopping_distance
	# Start active only if an initial target is provided
	if config.has("initial_target"):
		set_target(config.initial_target)
	else:
		is_active = false # Don't start wandering if no target given
		print("ShipControllerAI Warning: No initial target provided for ", agent_body.name if agent_body else "UNKNOWN")

	print("ShipControllerAI initialized for: ", agent_body.name if agent_body else "UNKNOWN")

func _physics_process(delta):
	if not is_active or not agent_body or not movement_comp:
		_signal_movement_intent(Vector3.ZERO)
		return

	var current_pos = agent_body.global_transform.origin
	var distance_to_target = current_pos.distance_to(target_position)

	if distance_to_target > stopping_distance:
		var direction_to_target = movement_comp.get_direction_to(target_position)
		if direction_to_target != Vector3.ZERO:
			movement_comp.rotate_towards(delta, direction_to_target)
			_signal_movement_intent(-agent_body.global_transform.basis.z)
			movement_comp.move(delta, -agent_body.global_transform.basis.z)
		else:
			_signal_movement_intent(Vector3.ZERO)
			movement_comp.move(delta, Vector3.ZERO)
			_handle_target_reached() # Reached
	else:
		# Reached target
		_signal_movement_intent(Vector3.ZERO)
		movement_comp.move(delta, Vector3.ZERO)
		_handle_target_reached()

# --- Target Management ---
func _handle_target_reached():
	if not is_instance_valid(agent_body): return

	print(agent_body.name, " reached target: ", target_position, ". Despawning.")
	is_active = false # Stop AI processing immediately
	# Call the agent's despawn method - this emits signal THEN queues free
	if agent_body.has_method("despawn"):
		agent_body.despawn()
	else:
		# Fallback if method is somehow missing
		agent_body.queue_free()

# Public function to set a specific target
func set_target(new_target: Vector3):
	target_position = new_target
	is_active = true
	if agent_body:
		print(agent_body.name, " AI target set to: ", new_target)

# --- Helper for Agent/Movement Component ---
func _signal_movement_intent(direction: Vector3):
	if is_instance_valid(agent_body) and agent_body.has_method("set_movement_input"):
		agent_body.set_movement_input(direction)
