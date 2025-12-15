# File: res://core/agents/agent.gd (Attached to AgentBody KinematicBody)
# Version: 3.40 - Ship stats now loaded from ShipTemplate via AssetSystem.

# Agent - this is a physical space vessel that exists in simulation space (ship).

extends KinematicBody

# --- Core State & Identity ---
var agent_type: String = ""
var template_id: String = ""
var agent_uid = -1
var character_uid: int = -1  # Links this agent to a character in GameState
var interaction_radius: float = 15.0
var is_hostile: bool = false  # True if this is a hostile NPC
var ship_template = null  # Cached ship template for combat registration

func is_player() -> bool:
	return character_uid == GameState.player_character_uid and character_uid != -1

# --- Physics State ---
var current_velocity: Vector3 = Vector3.ZERO

# --- Component References ---
var movement_system: Node = null
var navigation_system: Node = null


# --- Initialization ---
# Called externally (e.g., by WorldManager) after instancing and adding to tree
func initialize(template: AgentTemplate, overrides: Dictionary = {}, p_agent_uid: int = -1):
	if not template is AgentTemplate:
		printerr("AgentBody Initialize Error: Invalid template for ", self.name)
		return

	self.template_id = overrides.get("template_id")
	self.agent_type = overrides.get("agent_type")
	self.agent_uid = p_agent_uid
	self.character_uid = overrides.get("character_uid", -1)
	self.is_hostile = overrides.get("hostile", false)
	
	if is_player():
		print("AgentBody initialized as PLAYER. UID: ", self.agent_uid, " CharUID: ", self.character_uid)
	else:
		print("AgentBody initialized as NPC. UID: ", self.agent_uid, " CharUID: ", self.character_uid, " Hostile: ", self.is_hostile)

	movement_system = get_node_or_null("MovementSystem")
	navigation_system = get_node_or_null("NavigationSystem")

	if not is_instance_valid(movement_system) or not is_instance_valid(navigation_system):
		printerr(
			"AgentBody Initialize Error: Failed to get required component nodes for '",
			self.name,
			"'."
		)
		set_physics_process(false)
		return

	# Get movement parameters from the character's active ship
	var move_params = _get_movement_params_from_ship()
	var nav_params = {
		"orbit_kp": overrides.get("orbit_kp", 3.0),
		"orbit_ki": overrides.get("orbit_ki", 0.1),
		"orbit_kd": overrides.get("orbit_kd", 0.5)
	}

	movement_system.initialize_movement_params(move_params)
	navigation_system.initialize_navigation(nav_params, movement_system)
	
	# Register with combat system if we have a ship template
	_register_with_combat_system()

	print(
		"AgentBody '",
		self.name,
		"' initialized with character_uid=",
		self.character_uid,
		" using template '",
		self.template_id,
		"'."
	)


# Retrieves movement parameters from the character's active ship template.
# Falls back to Constants defaults if ship data is unavailable.
# Also caches the ship_template for combat registration.
func _get_movement_params_from_ship() -> Dictionary:
	ship_template = null
	
	# Try to get ship via AssetSystem if character_uid is valid
	if character_uid != -1 and is_instance_valid(GlobalRefs.asset_system):
		ship_template = GlobalRefs.asset_system.get_ship_for_character(character_uid)
	
	# For hostile NPCs without character, load the default hostile ship
	if not is_instance_valid(ship_template) and is_hostile:
		ship_template = load("res://assets/data/assets/ships/ship_hostile_default.tres")
	
	if is_instance_valid(ship_template):
		interaction_radius = ship_template.interaction_radius
		return {
			"max_move_speed": ship_template.max_move_speed,
			"acceleration": ship_template.acceleration,
			"deceleration": ship_template.deceleration,
			"max_turn_speed": ship_template.max_turn_speed,
			"brake_strength": ship_template.deceleration,
			"alignment_threshold_angle_deg": ship_template.alignment_threshold_angle_deg
		}
	else:
		# Fallback to Constants defaults if no ship found (normal for hostile NPCs)
		if character_uid >= 0:
			printerr("AgentBody: No ship found for character_uid=", character_uid, ", using defaults.")
		return {
			"max_move_speed": Constants.DEFAULT_MAX_MOVE_SPEED,
			"acceleration": Constants.DEFAULT_ACCELERATION,
			"deceleration": Constants.DEFAULT_DECELERATION,
			"max_turn_speed": Constants.DEFAULT_MAX_TURN_SPEED,
			"brake_strength": Constants.DEFAULT_DECELERATION,
			"alignment_threshold_angle_deg": Constants.DEFAULT_ALIGNMENT_ANGLE_THRESHOLD
		}


# Registers this agent with the combat system using its ship template.
func _register_with_combat_system() -> void:
	if not is_instance_valid(GlobalRefs.combat_system):
		return
	if agent_uid < 0:
		return
	if not is_instance_valid(ship_template):
		return
	
	GlobalRefs.combat_system.register_combatant(agent_uid, ship_template)
	print("AgentBody '", self.name, "' registered with CombatSystem. Hull: ", ship_template.hull_integrity)


# --- Godot Lifecycle ---
func _ready():
	add_to_group("Agents")
	set_physics_process(true)


func _physics_process(delta: float):
	if not is_instance_valid(navigation_system) or not is_instance_valid(movement_system):
		if delta > 0:
			printerr("AgentBody _physics_process Error: Components invalid for '", self.name, "'!")
		set_physics_process(false)
		return

	if delta <= 0.0001:
		return

	# 1. Update Navigation & Movement Logic
	navigation_system.update_navigation(delta)

	# 2. Smoothly enforce the current speed limit before moving.
	movement_system.enforce_speed_limit(delta)

	# 3. Apply Physics Engine Movement
	current_velocity = move_and_slide(current_velocity, Vector3.UP)

	# 4. Apply Post-Movement Corrections (e.g., PID for orbit)
	navigation_system.apply_orbit_pid_correction(delta)


# --- Public Command API (Delegates to NavigationSystem) ---
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


# MODIFIED: This function now captures the ship's current distance to the target
# as the desired orbit distance, preventing the navigation system from
# immediately trying to correct to a different, pre-calculated minimum.
func command_orbit(target: Spatial):
	if not is_instance_valid(target):
		printerr("AgentBody: command_orbit - Invalid target node provided.")
		if is_instance_valid(navigation_system):
			navigation_system.set_command_stopping()
		return

	if is_instance_valid(navigation_system):
		var vec_to_target_local = to_local(target.global_transform.origin)
		var orbit_clockwise = vec_to_target_local.x > 0.01

		# Always capture the current distance. The NavigationSystem will handle
		# gently pushing the agent out if this distance is too close.
		var captured_orbit_dist = global_transform.origin.distance_to(
			target.global_transform.origin
		)

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
