# Agent: a physical space vessel (RigidBody, 6DOF thrust flight) driven by a player or AI controller.

extends RigidBody

# --- Core State & Identity ---
var agent_type: String = ""
var template_id: String = ""
var agent_uid = -1
var interaction_radius: float = 150.0
var faction: String = ""  # Constants.FACTIONS id; the player's is "player"
var _grudges: Dictionary = {}  # Instance ids of ships that shot this one: enemies whatever their faction
var ship_template = null  # ShipTemplate this agent flies

# --- Hull & Power ---
var hull: float = 0.0
var hull_max: float = 0.0
var power: float = 0.0
var power_max: float = 0.0
var power_regen: float = 0.0
var is_docked: bool = false  # Held at a station: no motion, no leak thrust
var is_wreck: bool = false  # Hull reached zero: no thrust or AI; drifts until stripped and cleared away (Constants WRECK_*).
var wreck_time_ms: int = 0  # When it became a wreck

# Bounds of the ship's visual model in body space; used to place hit effects on the hull.
var hull_bounds: AABB = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))

# --- Cargo & Salvage ---
var cargo: Dictionary = {}  # Commodity id -> units in the hold
var cargo_capacity: int = 0  # Units
var salvage: Dictionary = {}  # Wrecks only: commodity id -> units left to strip

const HullScorch = preload("res://src/core/agents/components/hull_scorch.gd")
const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const ShipFit = preload("res://src/core/systems/ship_fit.gd")

# --- Fit ---
var fit: Dictionary = {}  # ShipFit fit: parts per slot. The player's lives in GameState.player_fit.
var fit_stats: Dictionary = {}  # ShipFit.compute_stats(): hull, power, cargo, thrust and mass with the fit
const FuelLeakScene = preload("res://scenes/prefabs/effects/fuel_leak.tscn")
const WreckExplosionScene = preload("res://scenes/prefabs/effects/wreck_explosion.tscn")
var _hull_scorch: Node = null
var _damage_toward_leak := 0.0
var _engine_activity := 0.0  # Smoothed engine thrust fraction, 0..1 (signature)
var _leaks: Array = []

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
	self.faction = "player" if is_player() else str(overrides.get("faction", template.faction))
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

	_init_fit()
	_init_hull_and_power()

	movement_system.initialize_movement_params(move_params)
	_apply_fit_to_movement()  # Movement params set the bare hull's thrust and mass; use the fitted ones.
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
				MeshLod.attach(ship_visual, get_apparent_radius())  # Before the marks: they stay on LOD0
				_hull_scorch = HullScorch.new()
				add_child(_hull_scorch)
				_hull_scorch.setup(ship_visual)
				if is_player():
					_hull_scorch.import_marks(GameState.player_hull_marks)
			else:
				printerr("AgentBody Error: 'Model' node not found!")
		else:
			printerr("AgentBody Error: ship_template.ship_scene is null for template_id: ", ship_template.template_id)
	else:
		printerr("AgentBody Error: ship_template is null! Cannot instance ship visual.")

	var ai_controller = get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	if is_instance_valid(ai_controller) and ai_controller.has_method("initialize"):
		ai_controller.initialize({
			"patrol_center": overrides.get("patrol_center", global_transform.origin),
			"home_point": overrides.get("home_point", global_transform.origin),
			"skill": template.skill,
		})

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
# The solid core of the hull, in body space: cable anchors sit on it and slack cable is kept out of it.
func get_hull_core_box() -> AABB:
	var center: Vector3 = hull_bounds.position + hull_bounds.size * 0.5
	return AABB(center - hull_bounds.size * 0.35, hull_bounds.size * 0.7)


func get_hull_point_facing(from_global: Vector3) -> Vector3:
	var inner: AABB = get_hull_core_box()
	var center: Vector3 = inner.position + inner.size * 0.5
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


# The player keeps their fit in GameState (new runs start from the hull's default fit);
# everyone else flies the hull's default fit.
func _init_fit() -> void:
	if not is_instance_valid(ship_template):
		fit = {"tools": [], "modules": []}
		fit_stats = {}
		return
	if is_player() and not GameState.player_fit.empty():
		fit = ShipFit.normalized(ship_template, GameState.player_fit)
	else:
		fit = ShipFit.default_fit(ship_template)
	if is_player():
		GameState.player_fit = fit.duplicate(true)
	fit_stats = ShipFit.compute_stats(ship_template, fit)


func _init_hull_and_power() -> void:
	_apply_fit_stats()
	hull = hull_max
	if is_player() and GameState.player_hull >= 0.0:
		hull = min(GameState.player_hull, hull_max)
	power = power_max
	cargo = GameState.player_cargo.duplicate() if is_player() else {}
	_update_mass()


func _apply_fit_stats() -> void:
	hull_max = float(fit_stats.get("hull", 100.0))
	power_max = float(fit_stats.get("power_capacity", 100.0))
	power_regen = float(fit_stats.get("power_regen", 10.0))
	cargo_capacity = int(fit_stats.get("cargo_capacity", 0))


func _apply_fit_to_movement() -> void:
	if is_instance_valid(movement_system) and not fit_stats.empty():
		movement_system.linear_thrust = fit_stats.linear_thrust
		movement_system.angular_thrust = fit_stats.angular_thrust
	_update_mass()


# Refit a live ship: new stats, thrust, mass and tools at once. Hull and power keep their
# current values, capped to the new maximums.
func apply_fit(new_fit: Dictionary) -> void:
	fit = ShipFit.normalized(ship_template, new_fit)
	if is_player():
		GameState.player_fit = fit.duplicate(true)
	fit_stats = ShipFit.compute_stats(ship_template, fit)
	_apply_fit_stats()
	hull = min(hull, hull_max)
	power = min(power, power_max)
	if is_player():
		GameState.player_hull = hull
	_apply_fit_to_movement()
	var tools = get_node_or_null("ToolController")
	if is_instance_valid(tools) and tools.has_method("load_tools_from_ship"):
		tools.load_tools_from_ship()


func get_fitted_tool_ids() -> Array:
	return ShipFit.fitted_tool_ids(fit) if not fit.empty() else (ship_template.equipped_tools if is_instance_valid(ship_template) else [])


# --- Docking ---

# Held at the station's dock point until undock(); `station` may be null (stays where it is).
func dock_at(station: Spatial) -> void:
	is_docked = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if is_instance_valid(station) and station.has_method("get_undock_position"):
		global_transform.origin = station.get_undock_position()


func undock() -> void:
	is_docked = false


# --- Factions ---

# Whether this ship treats `other` as an enemy: its faction is at war with other's, or other shot it.
# One-sided: a ship that hits another by accident does not start hating it.
func is_enemy_of(other) -> bool:
	if not (is_instance_valid(other) and other != self and other.get("faction") != null):
		return false
	if _grudges.has(other.get_instance_id()):
		return true
	return other.faction in Constants.FACTIONS.get(faction, {}).get("enemies", [])


func get_faction_color() -> Color:
	return Constants.FACTIONS.get(faction, {}).get("color", Constants.COLOR_UI_TARGET_NEUTRAL)


func get_faction_name() -> String:
	return Constants.FACTIONS.get(faction, {}).get("name", "")


# Shot by another ship: it is now an enemy. Stray fire from its own side is forgiven.
func _hold_grudge(source) -> void:
	if not (is_instance_valid(source) and source != self and source.get("faction") != null):
		return
	if source.faction != "" and source.faction == faction:
		return
	_grudges[source.get_instance_id()] = true


# --- Hull & Power API ---
func apply_damage(amount: float, source: Node = null) -> void:
	if is_wreck or amount <= 0.0:
		return
	hull = max(0.0, hull - amount)
	_hold_grudge(source)
	if is_player():
		GameState.player_hull = hull
	EventBus.emit_signal("agent_damaged", self, amount, source)
	if hull <= 0.0:
		become_wreck()


func become_wreck() -> void:
	if is_wreck:
		return
	is_wreck = true
	wreck_time_ms = OS.get_ticks_msec()
	hull = 0.0
	power = 0.0
	# What can be stripped from the wreck: the hull's own salvage plus whatever was in its hold.
	salvage = ship_template.salvage_yield.duplicate() if is_instance_valid(ship_template) else {}
	for commodity_id in cargo:
		salvage[commodity_id] = int(salvage.get(commodity_id, 0)) + int(cargo[commodity_id])
	cargo.clear()
	_update_mass()
	_spawn_explosion()
	add_to_group("wreck")
	EventBus.emit_signal("agent_disabled", self)


func try_spend_power(amount: float) -> bool:
	if is_wreck or power < amount:
		return false
	power -= amount
	return true


func get_hull_fraction() -> float:
	return hull / hull_max if hull_max > 0.0 else 0.0


# --- Hits & Damage Effects (placed from the hull itself; no hardpoints) ---

# Random point inside the central part of the hull bounds, in world space.
func get_random_aim_point() -> Vector3:
	var centre: Vector3 = hull_bounds.position + hull_bounds.size * 0.5
	var offset := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * hull_bounds.size * Constants.HIT_AIM_SPREAD
	return to_global(centre + offset)


# A shot from `from_global` lands on the hull: marks it, may open a fuel leak, and returns the
# world point it hit. Aims at random points (a line can pass between wings), then the centre.
func register_hit(from_global: Vector3, damage: float) -> Vector3:
	var point = null
	var normal = null
	if is_instance_valid(_hull_scorch) and _hull_scorch.is_paintable() and damage > 0.0:
		for attempt in range(3):
			var aim: Vector3 = get_random_aim_point() if attempt < 2 else to_global(hull_bounds.position + hull_bounds.size * 0.5)
			_hull_scorch.add_hit(from_global, aim, damage)
			point = _hull_scorch.last_hit_point
			normal = _hull_scorch.last_hit_normal
			if point != null or _hull_scorch.last_hit_deferred:
				break  # Marked, or recorded for when someone can see the hull
		if is_player():
			GameState.player_hull_marks = _hull_scorch.export_marks()
	if point == null:
		point = get_hull_point_facing(from_global)
	_accumulate_leak_damage(point, normal, damage)
	return point


# `normal` is the hull's surface normal at the hit (null without a marked mesh): the leak vents
# along it. On a long hull that is mostly sideways, so off-centre leaks turn the ship.
func _accumulate_leak_damage(point: Vector3, normal, damage: float) -> void:
	if is_wreck or damage <= 0.0 or not is_inside_tree():
		return
	_damage_toward_leak += damage
	if _damage_toward_leak < Constants.FUEL_LEAK_EVERY_DAMAGE:
		return
	_damage_toward_leak -= Constants.FUEL_LEAK_EVERY_DAMAGE
	var live: Array = []
	for leak in _leaks:
		if is_instance_valid(leak):
			live.append(leak)
	_leaks = live
	if _leaks.size() >= Constants.FUEL_LEAK_MAX_PER_SHIP:
		_leaks.pop_front().queue_free()
	var leak = FuelLeakScene.instance()
	leak.outward = normal if normal != null else (point - to_global(hull_bounds.position + hull_bounds.size * 0.5)).normalized()
	leak.outward_local = global_transform.basis.xform_inv(leak.outward).normalized()
	leak.size_scale = clamp(get_apparent_radius() / 12.0, 0.5, 5.0)
	add_child(leak)
	leak.global_transform.origin = point
	_leaks.append(leak)


func get_leak_count() -> int:
	var count := 0
	for leak in _leaks:
		if is_instance_valid(leak):
			count += 1
	return count


func _spawn_explosion() -> void:
	if not is_inside_tree():
		return
	var holder: Node = GlobalRefs.agent_container if is_instance_valid(GlobalRefs.agent_container) else get_parent()
	var explosion = WreckExplosionScene.instance()
	explosion.velocity = linear_velocity
	explosion.radius = get_apparent_radius()
	holder.add_child(explosion)
	explosion.global_transform.origin = global_transform.origin


# --- Signature & Detection (one rule for everyone; see Constants SIGNATURE block) ---

# How far away this ship can be detected (m): its hull's base plus engines, firing and leaks.
# Smoothed engine thrust, 0 idle .. 1 full burn (engine exhaust looks, signature).
func get_engine_activity() -> float:
	return _engine_activity


func get_signature() -> float:
	var base: float = float(fit_stats.get("signature", ship_template.signature if is_instance_valid(ship_template) else 1500.0))
	if is_wreck:
		return max(Constants.SIG_MIN, base * Constants.SIG_WRECK_FACTOR)
	var signature: float = base + Constants.SIG_ENGINE_FULL * _engine_activity
	var tools = get_node_or_null("ToolController")
	if is_instance_valid(tools) and tools.has_method("get_firing_activity"):
		signature += Constants.SIG_TOOL_FIRING * tools.get_firing_activity()
	for leak in _leaks:
		if is_instance_valid(leak):
			signature += Constants.SIG_PER_LEAK * leak.get_pressure()
	return max(Constants.SIG_MIN, signature)


func get_sensor_strength() -> float:
	return float(fit_stats.get("sensor_strength", ship_template.sensor_strength if is_instance_valid(ship_template) else 1.0))


# Whether this ship's sensors see `other`. Things without a signature (stations, rocks, stars)
# are always known.
func detects(other) -> bool:
	if not is_instance_valid(other) or other == self or not other.has_method("get_signature"):
		return true
	return global_transform.origin.distance_to(other.global_transform.origin) <= other.get_signature() * get_sensor_strength()


func get_damage_per_second() -> float:
	var tools = get_node_or_null("ToolController")
	return tools.get_damage_per_second() if is_instance_valid(tools) and tools.has_method("get_damage_per_second") else 0.0


# What this ship's wreck would be worth to a salvager: its hull's salvage plus its cargo.
func get_salvage_value() -> int:
	var stock: Dictionary = (ship_template.salvage_yield if is_instance_valid(ship_template) else {}).duplicate()
	for commodity_id in cargo:
		stock[commodity_id] = int(stock.get(commodity_id, 0)) + int(cargo[commodity_id])
	var value := 0
	for commodity_id in stock:
		var commodity = TemplateDatabase.get_template(commodity_id)
		if commodity is CommodityTemplate:
			value += int(stock[commodity_id]) * commodity.base_value
	return value


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


func clear_cargo() -> void:
	cargo.clear()
	if is_player():
		GameState.player_cargo = {}
	_update_mass()


# Restores the hull and clears its damage marks; returns hull points restored.
func repair_hull() -> float:
	var restored: float = hull_max - hull
	hull = hull_max
	if is_instance_valid(_hull_scorch):
		_hull_scorch.clear_marks()
	if is_player():
		GameState.player_hull = hull
		GameState.player_hull_marks = {}
	return restored


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
# Hull and parts (the fit) plus cargo; drag scales with mass, so a loaded ship is slower and heavier to turn.
func _update_mass() -> void:
	var base_mass: float = float(fit_stats.get("mass", ship_template.mass if is_instance_valid(ship_template) else Constants.DEFAULT_SHIP_MASS))
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
	_apply_leak_thrust()
	var thrust_used = movement_system.get("last_thrust_fraction") if is_instance_valid(movement_system) else null
	var thrust: float = float(thrust_used) if thrust_used != null and not is_wreck and not is_docked else 0.0
	_engine_activity = lerp(_engine_activity, thrust, 1.0 - exp(-delta / Constants.SIG_ENGINE_SMOOTHING))


# Venting gas pushes back on the hull where it leaks; off-centre leaks turn the ship (wrecks too).
func _apply_leak_thrust() -> void:
	if _leaks.empty() or is_docked or not is_instance_valid(movement_system):
		return
	for leak in _leaks:
		if not is_instance_valid(leak) or not leak.is_inside_tree():
			continue
		var pressure: float = leak.get_pressure()
		if pressure <= 0.0:
			continue
		var jet_direction: Vector3 = global_transform.basis.xform(leak.outward_local).normalized()
		movement_system.add_external_force_at(-jet_direction * Constants.FUEL_LEAK_THRUST * pressure, leak.global_transform.origin)


# --- RigidBody Physics Integration ---
func _integrate_forces(state: PhysicsDirectBodyState):
	if is_docked:
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return
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
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("AgentBody '", self.name, "' despawning...")
	EventBus.emit_signal("agent_despawning", self)
	# Spawned agents sit under their scene's root in the agent container: free that root too.
	var root: Node = get_parent()
	var owner_root: Node = root if is_instance_valid(root) and root.get_parent() == GlobalRefs.agent_container else self
	owner_root.call_deferred("queue_free")
