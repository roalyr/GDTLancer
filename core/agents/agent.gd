# File: res://core/agents/agent.gd (Attached to AgentBody KinematicBody)
# Version: 3.33 - Fetched component nodes inside initialize() due to execution order.
extends KinematicBody

# --- Core State & Identity ---
var agent_name: String = "Default Agent"
var faction_id: String = "Neutral"
var template_id: String = "default"
var interaction_radius: float = 15.0

# --- Physics State ---
var current_velocity: Vector3 = Vector3.ZERO

# --- Component References ---
# Declare vars, assign them in initialize() now
var movement_system: Node = null
var navigation_system: Node = null


# --- Initialization ---
# Called externally (e.g., by WorldManager) after instancing and adding to tree
func initialize(template: AgentTemplate, overrides: Dictionary = {}):
	# 1. Basic AgentBody Initialization
	if not template is AgentTemplate:
		printerr("AgentBody Initialize Error: Invalid template for ", self.name)
		return

	self.template_id = template.template_id
	var default_name = template.default_agent_name + "_" + str(get_instance_id())
	self.agent_name = overrides.get("name", default_name)
	self.faction_id = overrides.get("faction", template.default_faction_id)
	self.name = self.agent_name  # Set Node name
	self.interaction_radius = overrides.get("interaction_radius", template.interaction_radius)

	# *** Fetch Component Nodes HERE inside initialize ***
	movement_system = get_node_or_null("MovementSystem")
	navigation_system = get_node_or_null("NavigationSystem")

	# *** Check if references were successfully obtained NOW ***
	if not is_instance_valid(movement_system) or not is_instance_valid(navigation_system):
		printerr(
			"AgentBody Initialize Error: Failed to get required component nodes (MovementSystem or NavigationSystem) for '",
			self.name,
			"'. Check node names and scene structure."
		)
		set_physics_process(false)  # Disable physics if components are missing
		return  # Stop initialization

	# If we got here, components were found successfully.

	# 2. Prepare Params for Components
	var move_params = {
		"max_move_speed": overrides.get("max_move_speed", template.max_move_speed),
		"acceleration": overrides.get("acceleration", template.acceleration),
		"deceleration": overrides.get("deceleration", template.deceleration),
		"max_turn_speed": overrides.get("max_turn_speed", template.max_turn_speed),
		"brake_strength": overrides.get("brake_strength", template.deceleration * 1.5),
		"alignment_threshold_angle_deg":
		overrides.get("alignment_threshold_angle_deg", template.alignment_threshold_angle_deg)
	}
	var nav_params = {
		"orbit_kp": overrides.get("orbit_kp", 3.0),
		"orbit_ki": overrides.get("orbit_ki", 0.1),
		"orbit_kd": overrides.get("orbit_kd", 0.5)
	}

	# 3. Initialize Components
	movement_system.initialize_movement_params(move_params)
	navigation_system.initialize_navigation(nav_params, movement_system)  # Pass ref to movement_system

	print(
		"AgentBody '",
		self.name,
		"' initialized WITH COMPONENTS successfully using template '",
		self.template_id,
		"'."
	)


# --- Godot Lifecycle ---
func _ready():
	add_to_group("Agents")
	# No need to fetch nodes here anymore, moved to initialize()
	set_physics_process(true)  # Enable physics processing


func _physics_process(delta: float):
	# Check components validity just in case something weird happens after init
	if not is_instance_valid(navigation_system) or not is_instance_valid(movement_system):
		# If components somehow became invalid after successful init, stop processing.
		if delta > 0:  # Avoid printing flood if physics is disabled
			printerr("AgentBody _physics_process Error: Components invalid for '", self.name, "'!")
		set_physics_process(false)
		return

	if delta <= 0.0001:
		return

	# 1. Update Navigation & Movement Logic
	navigation_system.update_navigation(delta)

	# 2. Apply Physics Engine Movement
	current_velocity = move_and_slide(current_velocity, Vector3.UP)

	# 3. Apply Post-Movement Corrections (e.g., PID)
	navigation_system.apply_orbit_pid_correction(delta)

	# 4. Final Velocity Clamping
	var max_speed = movement_system.max_move_speed
	if current_velocity.length_squared() > max_speed * max_speed:
		current_velocity = current_velocity.normalized() * max_speed


# --- Public Command API (Delegates to NavigationSystem) ---
# (Command functions remain the same as v3.32)
# ...
func command_stop():
	if is_instance_valid(navigation_system):
		navigation_system.set_command_stopping()
	else:
		printerr("AgentBody: Cannot command_stop - NavigationSystem invalid.")


func command_move_to(position: Vector3):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_move_to(position)
	else:
		printerr("AgentBody: Cannot command_move_to - NavigationSystem invalid.")


func command_move_direction(direction: Vector3):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_move_direction(direction)
	else:
		printerr("AgentBody: Cannot command_move_direction - NavigationSystem invalid.")


func command_approach(target: Spatial):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_approach(target)
	else:
		printerr("AgentBody: Cannot command_approach - NavigationSystem invalid.")


func command_orbit(target: Spatial):
	if not is_instance_valid(target):
		printerr("AgentBody: command_orbit - Invalid target node provided.")
		if is_instance_valid(navigation_system):
			navigation_system.set_command_stopping()
		return

	if is_instance_valid(navigation_system):
		var vec_to_target_local = to_local(target.global_transform.origin)
		var orbit_clockwise = vec_to_target_local.x > 0.01
		var target_size = navigation_system._get_target_effective_size(target)
		var current_dist = global_transform.origin.distance_to(target.global_transform.origin)
		var min_orbit_dist = target_size * 1.2 + 10.0
		var captured_orbit_dist = max(current_dist, min_orbit_dist)
		navigation_system.set_command_orbit(target, captured_orbit_dist, orbit_clockwise)
	else:
		printerr("AgentBody: Cannot command_orbit - NavigationSystem invalid.")


func command_flee(target: Spatial):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_flee(target)
	else:
		printerr("AgentBody: Cannot command_flee - NavigationSystem invalid.")


func command_align_to(direction: Vector3):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_align_to(direction)
	else:
		printerr("AgentBody: Cannot command_align_to - NavigationSystem invalid.")


# --- Public Getters ---
func get_interaction_radius() -> float:
	return interaction_radius


# --- Despawn ---
func despawn():
	print("AgentBody '", self.name, "' despawning...")
	EventBus.emit_signal("agent_despawning", self)
	set_physics_process(false)
	call_deferred("queue_free")
# ...
