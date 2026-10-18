# Agent: a physical space vessel (RigidBody, 6DOF thrust flight) driven by a player or AI controller.

extends RigidBody

# --- Core State & Identity ---
var agent_type: String = ""
var template_id: String = ""
var agent_uid = -1
var interaction_radius: float = 150.0
var is_hostile: bool = false  # True if this is a hostile NPC
var ship_template = null  # ShipTemplate this agent flies

# --- Hull & Power ---
var hull: float = 0.0
var hull_max: float = 0.0
var power: float = 0.0
var power_max: float = 0.0
var power_regen: float = 0.0
var is_wreck: bool = false  # Hull reached zero: no thrust or AI; drifts to rest and stays until the sector unloads.

# Bounds of the ship's visual model in body space; used to place hit effects on the hull.
var hull_bounds: AABB = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))

# --- Cargo & Salvage ---
var cargo: Dictionary = {}  # Commodity id -> units in the hold
var cargo_capacity: int = 0  # Units
var salvage: Dictionary = {}  # Wrecks only: commodity id -> units left to strip

const HullScorch = preload("res://src/core/agents/components/hull_scorch.gd")
var _hull_scorch: Node = null

func is_player() -> bool:
	return agent_type == "player"

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
	self.is_hostile = overrides.get("hostile", false)
	var ship_template_id: String = str(overrides.get("ship_template_id", template.ship_template_id))

	movement_system = get_node_or_null("MovementSystem")
	navigation_system = get_node_or_null("NavigationSystem")

	if not is_instance_valid(movement_system) or not is_instance_valid(navigation_system):
		printerr(
			"AgentBody Initialize Error: Failed to get required component nodes for '",
			self.name,
			"'."
		)
		return

	var move_params = _get_movement_params_from_ship(ship_template_id)
	var nav_params = {
		"orbit_kp": overrides.get("orbit_kp", 3.0),
		"orbit_ki": overrides.get("orbit_ki", 0.1),
		"orbit_kd": overrides.get("orbit_kd", 0.5)
	}

	_init_hull_and_power()

	movement_system.initialize_movement_params(move_params)
	_update_mass()  # Movement params set the hull mass; add the cargo back on top.
	navigation_system.initialize_navigation(nav_params, movement_system)
	
	# Instance the ship visual scene if defined in the template
	if is_instance_valid(ship_template):
		if ship_template.ship_scene != null:
			var ship_visual = ship_template.ship_scene.instance()
			var model_node = get_node_or_null("Model")
			if model_node:
				model_node.add_child(ship_visual)
				if ship_visual is Spatial:
					ship_visual.visible = true
				
				# If the ship scene has a CollisionShape, reparent it to the RigidBody
				for child in ship_visual.get_children():
					if child is CollisionShape:
						ship_visual.remove_child(child)
						call_deferred("add_child", child)
				_measure_hull_bounds(ship_visual)
				_hull_scorch = HullScorch.new()
				add_child(_hull_scorch)
				_hull_scorch.setup(ship_visual)
			else:
				printerr("AgentBody Error: 'Model' node not found!")
		else:
			printerr("AgentBody Error: ship_template.ship_scene is null for template_id: ", ship_template.template_id)
	else:
		printerr("AgentBody Error: ship_template is null! Cannot instance ship visual.")

	var ai_controller = get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	if is_instance_valid(ai_controller) and ai_controller.has_method("initialize"):
		ai_controller.initialize({"hostile": is_hostile, "patrol_center": global_transform.origin})

	if Constants.VERBOSE_RUNTIME_LOGS:
		print(
			"AgentBody '",
			self.name,
			"' initialized with ship '",
			ship_template_id,
			"' using template '",
			self.template_id,
			"'."
		)


# Resolves and caches the ship template, returning its movement parameters.
# Falls back to Constants defaults if the ship template is unavailable.
func _get_movement_params_from_ship(ship_template_id: String) -> Dictionary:
	ship_template = null
	if is_instance_valid(GlobalRefs.asset_system):
		ship_template = GlobalRefs.asset_system.get_ship_template(ship_template_id)

	if is_instance_valid(ship_template):
		interaction_radius = ship_template.interaction_radius
		return {
			"mass": ship_template.mass,
			"linear_thrust": ship_template.linear_thrust,
			"angular_thrust": ship_template.angular_thrust,
			"alignment_threshold_angle_deg": ship_template.alignment_threshold_angle_deg
		}
	else:
		if Constants.VERBOSE_RUNTIME_LOGS:
			print("AgentBody: No ship template '", ship_template_id, "', using defaults.")
		return {
			"mass": Constants.DEFAULT_SHIP_MASS,
			"linear_thrust": Constants.DEFAULT_LINEAR_THRUST,
			"angular_thrust": Constants.DEFAULT_ANGULAR_THRUST,
			"alignment_threshold_angle_deg": Constants.DEFAULT_ALIGNMENT_ANGLE_THRESHOLD
		}


func _measure_hull_bounds(visual_root: Node) -> void:
	var to_body: Transform = global_transform.affine_inverse()
	var found := false
	var stack: Array = [visual_root]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if node is GeometryInstance and node.is_visible_in_tree():
			var box: AABB = (to_body * node.global_transform).xform(node.get_aabb())
			hull_bounds = box if not found else hull_bounds.merge(box)
			found = true


# Size the camera frames this ship by, from its ShipTemplate.
func get_apparent_radius() -> float:
	return ship_template.apparent_radius if is_instance_valid(ship_template) else get_hull_radius()


func get_hull_radius() -> float:
	return hull_bounds.size.length() * 0.5


# Point on the hull facing `from_global`: where the line to the hull centre enters the
# model's bounds, pulled in toward the centre so it sits on the hull rather than the box corner.
func get_hull_point_facing(from_global: Vector3) -> Vector3:
	var center: Vector3 = hull_bounds.position + hull_bounds.size * 0.5
	var inner := AABB(center - hull_bounds.size * 0.35, hull_bounds.size * 0.7)
	var from_local: Vector3 = to_local(from_global)
	if inner.has_point(from_local):
		return to_global(center)
	# Slab method: latest entry across the three axis-aligned slab pairs.
	var direction: Vector3 = center - from_local
	var t_enter := 0.0
	for axis in range(3):
		if abs(direction[axis]) > 0.000001:
			var t1: float = (inner.position[axis] - from_local[axis]) / direction[axis]
			var t2: float = (inner.end[axis] - from_local[axis]) / direction[axis]
			t_enter = max(t_enter, min(t1, t2))
	return to_global(from_local + direction * t_enter)


func _init_hull_and_power() -> void:
	if is_instance_valid(ship_template):
		hull_max = float(ship_template.hull_integrity)
		power_max = float(ship_template.power_capacity)
		power_regen = float(ship_template.power_regen)
	else:
		hull_max = 100.0
		power_max = 100.0
		power_regen = 10.0
	hull = hull_max
	if is_player() and GameState.player_hull >= 0.0:
		hull = min(GameState.player_hull, hull_max)
	power = power_max
	cargo_capacity = int(ship_template.cargo_capacity) if is_instance_valid(ship_template) else 0
	cargo = GameState.player_cargo.duplicate() if is_player() else {}
	_update_mass()


# --- Hull & Power API ---
func apply_damage(amount: float, source: Node = null) -> void:
	if is_wreck or amount <= 0.0:
		return
	hull = max(0.0, hull - amount)
	if is_player():
		GameState.player_hull = hull
	if is_instance_valid(_hull_scorch) and source is Spatial:
		_hull_scorch.add_hit(source.global_transform.origin, amount)
	EventBus.emit_signal("agent_damaged", self, amount, source)
	if hull <= 0.0:
		become_wreck()


func become_wreck() -> void:
	if is_wreck:
		return
	is_wreck = true
	hull = 0.0
	power = 0.0
	# What can be stripped from the wreck: the hull's own salvage plus whatever was in its hold.
	salvage = ship_template.salvage_yield.duplicate() if is_instance_valid(ship_template) else {}
	for commodity_id in cargo:
		salvage[commodity_id] = int(salvage.get(commodity_id, 0)) + int(cargo[commodity_id])
	cargo.clear()
	_update_mass()
	add_to_group("wreck")
	EventBus.emit_signal("agent_disabled", self)


func try_spend_power(amount: float) -> bool:
	if is_wreck or power < amount:
		return false
	power -= amount
	return true


func get_hull_fraction() -> float:
	return hull / hull_max if hull_max > 0.0 else 0.0


# --- Cargo & Salvage API ---
static func count_units(stock: Dictionary) -> int:
	var total := 0
	for units in stock.values():
		total += int(units)
	return total


func get_cargo_units() -> int:
	return count_units(cargo)


func get_free_cargo() -> int:
	return int(max(0, cargo_capacity - get_cargo_units()))


# Adds up to `units` of a commodity, limited by free hold space; returns how many fit.
func add_cargo(commodity_id: String, units: int) -> int:
	var added: int = int(min(units, get_free_cargo()))
	if added <= 0:
		return 0
	cargo[commodity_id] = int(cargo.get(commodity_id, 0)) + added
	if is_player():
		GameState.player_cargo = cargo.duplicate()
	_update_mass()
	return added


func get_salvage_units() -> int:
	return count_units(salvage)


# Removes up to `units` from the wreck, taking commodities in name order; returns {id: units}.
func take_salvage(units: int) -> Dictionary:
	var taken := {}
	var ids: Array = salvage.keys()
	ids.sort()
	for commodity_id in ids:
		if units <= 0:
			break
		var amount: int = int(min(units, int(salvage[commodity_id])))
		if amount <= 0:
			continue
		taken[commodity_id] = amount
		units -= amount
		salvage[commodity_id] = int(salvage[commodity_id]) - amount
		if salvage[commodity_id] <= 0:
			salvage.erase(commodity_id)
	return taken


func get_cargo_mass() -> float:
	var total := 0.0
	for commodity_id in cargo:
		var commodity = TemplateDatabase.get_template(commodity_id)
		var unit_mass: float = commodity.unit_mass if commodity is CommodityTemplate else 0.0
		total += unit_mass * int(cargo[commodity_id])
	return total


# Hull mass plus cargo; drag scales with mass, so a loaded ship is slower and heavier to turn.
func _update_mass() -> void:
	var base_mass: float = ship_template.mass if is_instance_valid(ship_template) else Constants.DEFAULT_SHIP_MASS
	mass = base_mass + get_cargo_mass()


# --- Godot Lifecycle ---
func _ready():
	add_to_group("Agents")
	add_to_group("agent_body")
	# RigidBody settings for 6DOF space flight
	mode = RigidBody.MODE_RIGID
	gravity_scale = 0.0  # No gravity in space
	can_sleep = false  # Always active


func _physics_process(delta: float) -> void:
	if not is_wreck and power < power_max:
		power = min(power_max, power + power_regen * delta)


# --- RigidBody Physics Integration ---
func _integrate_forces(state: PhysicsDirectBodyState):
	if not is_instance_valid(navigation_system) or not is_instance_valid(movement_system):
		return
	# Wrecks have no thrust but obey the same drag as everything else, so they come to rest.
	if is_wreck:
		movement_system.integrate_forces(state)
		return

	# Update navigation logic (determines what forces/torques to apply)
	navigation_system.update_navigation(state.step)
	
	# Apply forces and drag via movement system
	movement_system.integrate_forces(state)


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


func command_idle():
	if is_instance_valid(navigation_system):
		navigation_system.set_command_idle()
	else:
		printerr("AgentBody: Cannot command_idle - NavigationSystem invalid.")


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


func command_align_to(
	direction: Vector3,
	apply_forward_thrust: bool = false,
	forward_thrust_scale: float = 1.0,
	persist_until_cleared: bool = false
):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_align_to(
			direction,
			apply_forward_thrust,
			forward_thrust_scale,
			persist_until_cleared
		)
	else:
		printerr("AgentBody: Cannot command_align_to - NavigationSystem invalid.")


# --- Public Getters ---
func get_interaction_radius() -> float:
	return interaction_radius


# --- Despawn ---
func despawn():
	print("AgentBody '", self.name, "' despawning...")
	EventBus.emit_signal("agent_despawning", self)
	call_deferred("queue_free")
