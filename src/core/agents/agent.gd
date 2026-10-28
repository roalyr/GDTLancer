# Agent: a physical space vessel (RigidBody, 6DOF thrust flight) driven by a player or AI controller.

extends RigidBody

# --- Core State & Identity ---
var agent_type: String = ""
var template_id: String = ""
var agent_uid = -1
var interaction_radius: float = 150.0
var faction: String = ""  # Constants.FACTIONS id; the player's is "player"
var _grudges: Dictionary = {}  # Instance ids of ships that shot this one: enemies whatever their faction
var _hit_by_player: bool = false  # The player has hit it (its faction's standing paid for that once)
var bounties: Dictionary = {}  # Bounty postings on this ship: faction -> WP (the player's are in GameState)
var bounty_paid: float = 0.0  # A wreck: what its killer was paid for it (Bounty.on_kill)
var _last_hit_by = null  # weakref to the ship that hit it last: the killer, when it becomes a wreck
var ship_template = null  # ShipTemplate this agent flies
var evo_uid: String = ""  # Arena NPCs: their life in Evolution
var wallet: float = 0.0  # WP an NPC outside the arenas has (random at spawn; see get_wallet)
var _fit_override: Dictionary = {}  # A fit given at spawn (arena NPCs' genomes); otherwise random

# --- Hull & Power ---
var hull: float = 0.0
var hull_max: float = 0.0
var power: float = 0.0
var power_max: float = 0.0
var power_regen: float = 0.0
var is_docked: bool = false  # Inside a station: out of the world (unseen, no collision, undetected)
var _undocked_collision: Array = []  # [layer, mask] to restore on undocking
var is_wreck: bool = false  # Hull reached zero: no thrust or AI; drifts until stripped and cleared away (Constants WRECK_*).
var wreck_time_ms: int = 0  # When it became a wreck

# Bounds of the ship's visual model in body space; used to place hit effects on the hull.
var hull_bounds: AABB = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))

# --- Cargo & Salvage ---
var cargo: Dictionary = {}  # Commodity id -> units in the hold
var cargo_capacity: int = 0  # Units
var salvage: Dictionary = {}  # Wrecks only: commodity id -> units left to strip

const CollisionHull = preload("res://src/core/agents/components/collision_hull.gd")
const LanceController = preload("res://src/core/agents/components/lance_controller.gd")
const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const ViewDetail = preload("res://src/core/agents/components/view_detail.gd")
const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const Standing = preload("res://src/core/systems/standing.gd")
const Bounty = preload("res://src/core/systems/bounty.gd")

# --- Fit ---
var fit: Dictionary = {}  # ShipFit fit: parts per slot. The player's lives in GameState.player_fit.
var fit_stats: Dictionary = {}  # ShipFit.compute_stats(): hull, power, cargo, thrust and mass with the fit
const FuelLeakScene = preload("res://scenes/prefabs/effects/fuel_leak.tscn")
const HullSmoulderScene = preload("res://scenes/prefabs/effects/hull_smoulder.tscn")
const HullScars = preload("res://src/core/agents/effects/hull_scars.gd")
const DamageTrailScene = preload("res://scenes/prefabs/effects/damage_trail.tscn")
const LaserHitEffect = preload("res://src/core/agents/effects/laser_hit_effect.gd")
const WreckExplosionScene = preload("res://scenes/prefabs/effects/wreck_explosion.tscn")
var _damage_toward_leak := 0.0
var _engine_activity := 0.0  # Smoothed engine thrust fraction, 0..1 (signature)
const DecoyScript = preload("res://src/core/agents/components/decoy.gd")
var decoys: int = 0  # Decoy launcher charges left (fit_stats decoy_charges when full)
var afterburner_lit: bool = false  # Afterburner on: extra thrust, power drain, a hot plume
var _decoy_watch := 0.0  # s to the next look for missiles coming in
var _leaks: Array = []
var _smoulders: Array = []  # HullSmoulder spots, oldest first
var _hull_scars = null  # HullScars under the visual root
var _damage_trails: Array = []  # DamageTrail nodes: one per Constants.DAMAGE_TRAIL_HULL_STEP of hull lost
var _last_hit: Array = []  # [world point, outward] of the latest hit: where a new damage trail starts

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
	self.evo_uid = str(overrides.get("evo_uid", ""))
	_fit_override = overrides.get("fit", {})

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
	if not is_player():
		wallet = float(overrides.get("wallet", randf() * Constants.AI_WALLET_MAX_SHARE * get_value()))
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
				model_node.scale = Vector3.ONE * ship_template.model_scale  # Before the collision hull, which takes the scale
				_apply_panel_material(ship_visual, ship_template.panel_material)  # Before MeshLod, whose levels copy it
				model_node.add_child(ship_visual)
				if ship_visual is Spatial:
					ship_visual.visible = true
				
				# If the ship scene has a CollisionShape, reparent it to the RigidBody, shaped as
				# the convex hull of the ship's lowest level of detail (the scene's shape stays if
				# no hull can be built).
				for child in ship_visual.get_children():
					if child is CollisionShape:
						ship_visual.remove_child(child)
						var hull_shape = CollisionHull.shape_for(ship_visual, model_node.transform * ship_visual.transform)
						if hull_shape != null:
							child.shape = hull_shape
							child.transform = Transform.IDENTITY
						call_deferred("add_child", child)
				_measure_hull_bounds(ship_visual)
				MeshLod.attach(ship_visual, ViewDetail.attach(self, get_apparent_radius()))  # One view band for the model, scars and effects
				CollisionHull.add_hit_surface(self, ship_visual)  # Where shots land: the plating, not the hull round it
				_hull_scars = HullScars.new(interaction_radius / Constants.HULL_SCAR_REFERENCE_RADIUS)
				ship_visual.add_child(_hull_scars)
				if is_player():
					_hull_scars.import_scars(GameState.player_hull_scars)
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
			"skill": float(overrides.get("skill", template.skill)),
			"arena": overrides.get("arena", {}),
			"behavior": overrides.get("behavior", template.behavior),
			"docked_at": overrides.get("docked_at", null),
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


# Paints surface 1 (the hull panels) of every Phoenix hull mesh under `visual_root` (ship types).
func _apply_panel_material(visual_root: Node, material_path: String) -> void:
	if material_path == "":
		return
	var material = load(material_path)
	var stack: Array = [visual_root]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if node is MeshInstance and node.name.begins_with("Hull") and node.mesh != null and node.mesh.get_surface_count() > 1:
			node.set_surface_material(1, material)


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
# NPCs fly the fit they spawn with (arena genomes) or a random one (ShipFit.random_fit).
func _init_fit() -> void:
	if not is_instance_valid(ship_template):
		fit = {"tools": [], "modules": []}
		fit_stats = {}
		return
	if is_player() and not GameState.player_fit.empty():
		fit = ShipFit.normalized(ship_template, GameState.player_fit)
	elif is_player():
		fit = ShipFit.default_fit(ship_template)
	elif not _fit_override.empty():
		fit = ShipFit.normalized(ship_template, _fit_override)
	else:
		fit = ShipFit.random_fit(ship_template)
	if is_player():
		GameState.player_fit = fit.duplicate(true)
	fit_stats = ShipFit.compute_stats(ship_template, fit)
	decoys = get_decoy_capacity()
	_refresh_lance()


func _init_hull_and_power() -> void:
	_apply_fit_stats()
	hull = hull_max
	if is_player() and GameState.player_hull >= 0.0:
		hull = min(GameState.player_hull, hull_max)
		call_deferred("_update_damage_trails")  # A hurt hull from a save trails embers again (once the model is in)
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
		movement_system.linear_thrust = fit_stats.linear_thrust + (float(fit_stats.get("afterburner_thrust", 0.0)) if afterburner_lit else 0.0)
		movement_system.angular_thrust = fit_stats.angular_thrust
	_update_mass()


# Refit a live ship: new stats, thrust, mass and tools at once. Hull and power keep their
# current values, capped to the new maximums.
func apply_fit(new_fit: Dictionary) -> void:
	fit = ShipFit.normalized(ship_template, new_fit)
	if is_player():
		GameState.player_fit = fit.duplicate(true)
	fit_stats = ShipFit.compute_stats(ship_template, fit)
	decoys = get_decoy_capacity()  # Refitted at a base: a new launcher comes loaded
	if afterburner_lit and not has_afterburner():
		afterburner_lit = false
	_apply_fit_stats()
	hull = min(hull, hull_max)
	power = min(power, power_max)
	if is_player():
		GameState.player_hull = hull
	_apply_fit_to_movement()
	var tools = get_node_or_null("ToolController")
	if is_instance_valid(tools) and tools.has_method("load_tools_from_ship"):
		tools.load_tools_from_ship()
	_refresh_lance()


# --- Kinetic lance (LanceController) ---

# Each lance module in the fit gets a LanceController, side by side across the bow (the player's
# keep their lances left across sectors and saves: GameState.player_lance_nails, their total, filled
# in launcher order); no lance, none. Spent lances lighten the ship.
func _refresh_lance() -> void:
	var wanted: Array = []  # [module_id, stats]
	for module_id in fit.get("modules", []):
		var module = TemplateDatabase.get_template(str(module_id)) if str(module_id) != "" else null
		if module is ModuleTemplate and not module.lance.empty():
			wanted.append([str(module_id), module.lance])
	var current: Array = get_lances()
	var same: bool = current.size() == wanted.size()
	for i in range(min(current.size(), wanted.size())):
		same = same and current[i].module_id == wanted[i][0]
	if same:
		return
	var spawned: bool = current.empty()
	for controller in current:
		remove_child(controller)
		controller.queue_free()
	if wanted.empty():
		_update_mass()
		if is_player():
			GameState.player_lance_nails = -1
		return
	var left: int = -1
	if is_player():
		if spawned:
			left = GameState.player_lance_nails  # Spawned with them: as they were left
		else:
			GameState.player_lance_nails = -1  # New lances come full
	for i in range(wanted.size()):
		var controller = LanceController.new()
		add_child(controller)
		var nails: int = -1
		if left >= 0:
			nails = int(min(left, int(wanted[i][1].count)))
			left -= nails
		controller.setup(self, wanted[i][0], wanted[i][1], nails, i, wanted.size())
		controller.connect("nails_changed", self, "_on_lance_nails_changed")
		if is_player():  # A glance leaves no mark: say what the tip met
			controller.connect("struck", self, "_on_player_lance_struck")
			controller.connect("glanced", self, "_on_player_lance_glanced")
	_update_mass()


# Charged at with a lance: the charger is an enemy now, as if it had fired (the AI reacts in its own
# controller); the player is told.
func _on_agent_charged(agent_body, charger) -> void:
	if agent_body != self or is_wreck or not is_instance_valid(charger):
		return
	_hold_grudge(charger)
	if is_player():
		var who: String = charger.get_faction_name() if charger.has_method("get_faction_name") else ""
		EventBus.emit_signal("announcement", "%s ship charging you with a lance!" % (who if who != "" else "A"), "danger")


func _on_player_lance_struck(target, damage) -> void:
	if is_instance_valid(target) and target.is_in_group("ore_chunk"):
		EventBus.emit_signal("attack_action_feedback", true, "Broke out a chunk: %d units, the lance in it (harpoon it)" % target.get_salvage_units())
		return
	EventBus.emit_signal("attack_action_feedback", true, "Lance in: %d damage" % int(damage))


func _on_player_lance_glanced(_target, reason) -> void:
	EventBus.emit_signal("attack_action_feedback", false, "Lance glanced off: %s" % reason)


func _on_tool_ammo_changed(_index: int, _ammo: int) -> void:
	_update_mass()


func _on_lance_nails_changed(_nails: int) -> void:
	if is_player():
		GameState.player_lance_nails = get_lance_nails()
	_update_mass()


# `target` is running from this ship too fast to be lanced: this ship cannot gain LANCE_CATCH_SPEED
# on it, so it never gets within release range (LANCE_RELEASE_RANGE). NPCs do not ram such a runner;
# the player's RAM button says so.
func outruns_ram(target) -> bool:
	if not (is_instance_valid(target) and target is RigidBody and target.has_method("get_top_speed")):
		return false
	var away: Vector3 = target.global_transform.origin - global_transform.origin
	if away.length() < 0.001:
		return false
	var running: bool = target.linear_velocity.dot(away.normalized()) > Constants.AI_RUNNER_SPEED_SHARE * max(target.get_top_speed(), 1.0)
	return running and get_burst_top_speed() - target.get_top_speed() < Constants.LANCE_CATCH_SPEED  # An afterburner counts


# The first lance launcher (the one on the axis if it has only one), or null.
func get_lance() -> Node:
	return get_node_or_null("LanceController")


# Every lance launcher, in mount order.
func get_lances() -> Array:
	var found: Array = []
	for child in get_children():
		if child is LanceController and not child.is_queued_for_deletion():
			found.append(child)
	return found


# Lances left in all its launchers.
func get_lance_nails() -> int:
	var total := 0
	for lance in get_lances():
		total += lance.nails
	return total


# Arms or makes safe all its launchers.
func set_lances_armed(on: bool) -> void:
	for lance in get_lances():
		lance.armed = on


func get_fitted_tool_ids() -> Array:
	return ShipFit.fitted_tool_ids(fit) if not fit.empty() else (ship_template.equipped_tools if is_instance_valid(ship_template) else [])


# --- Docking ---

# Held at the station's dock point until undock(); `station` may be null (stays where it is).
# A docked ship is inside the station: hidden, without collision and undetectable (see detects),
# so nothing can see, hit or target it until it undocks.
func dock_at(station: Spatial) -> void:
	if not is_docked:
		_undocked_collision = [collision_layer, collision_mask]
	is_docked = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if is_instance_valid(station) and station.has_method("get_undock_position"):
		global_transform.origin = station.get_undock_position()
	mode = MODE_STATIC  # Out of the physics while docked: no integration, no _integrate_forces


func undock() -> void:
	if is_docked and _undocked_collision.size() == 2:
		collision_layer = _undocked_collision[0]
		collision_mask = _undocked_collision[1]
	if is_docked:
		mode = MODE_RIGID
		sleeping = false
	is_docked = false
	visible = true


# --- Factions ---

# Whether this ship treats `other` as an enemy: its faction is at war with other's (with the player:
# its standing is hostile), other shot it, other carries a bounty worth hunting (Bounty), or other is
# in its faction's territory (in_territory). One-sided: a ship that hits another by accident does
# not start hating it.
func is_enemy_of(other) -> bool:
	if not (is_instance_valid(other) and other != self and other.get("faction") != null):
		return false
	if _grudges.has(other.get_instance_id()):
		return true
	if Bounty.is_worth_hunting(self, other) or in_territory(other):
		return true
	if other.faction == "player":
		return Standing.is_hostile(faction)
	return other.faction in Constants.FACTIONS.get(faction, {}).get("enemies", [])


# A territorial faction's ship (Constants FACTIONS "territory": the xenohive) takes any other ship
# within that many m of one of its stations (its hive) for an enemy.
func in_territory(other) -> bool:
	var territory: float = float(Constants.FACTIONS.get(faction, {}).get("territory", 0.0))
	if territory <= 0.0 or other.get("faction") == faction or not is_inside_tree():
		return false
	for station in get_tree().get_nodes_in_group("arena_station"):
		if station.get("faction") == faction and other.global_transform.origin.distance_to(station.global_transform.origin) <= territory:
			return true
	return false


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
	_update_damage_trails()
	_hold_grudge(source)
	if is_instance_valid(source) and source != self:
		_last_hit_by = weakref(source)
		if not _hit_by_player and source.has_method("is_player") and source.is_player():
			_hit_by_player = true
			Standing.on_player_attacked(faction)
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
	var killer = _last_hit_by.get_ref() if _last_hit_by != null else null
	if is_instance_valid(killer) and killer.has_method("is_player") and killer.is_player():
		Standing.on_player_killed(faction)
	bounty_paid = Bounty.on_kill(killer, self) if is_instance_valid(killer) else 0.0
	for spot in _smoulders:
		if is_instance_valid(spot):
			spot.duration_factor = Constants.SMOULDER_WRECK_FACTOR  # Wrecks smoulder on
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


# A shot from `from_global` lands on the hull: leaves a scar and a smoulder spot, may open a fuel
# leak, and returns the world point it hit. The shot line meets the hit surface (the plating;
# CollisionHull.ray_onto), aimed at `aim_at` if given, random points (a line can pass between wings), then the centre;
# failing that the convex collision hull at the centre, then the hull point facing the shooter.
# Only hits on the plating scar it.
func register_hit(from_global: Vector3, damage: float, aim_at = null) -> Vector3:
	var point = null
	var normal = null
	var centre: Vector3 = to_global(hull_bounds.position + hull_bounds.size * 0.5)
	for attempt in range(4):
		var aim: Vector3 = get_random_aim_point() if attempt < 2 else centre
		if attempt == 0 and aim_at is Vector3:
			aim = aim_at  # A known point (a lance's tip): try it first
		var hit: Dictionary = CollisionHull.ray_onto(self, from_global, aim, get_apparent_radius() * 2.0, attempt < 3)
		if not hit.empty():
			point = hit.position
			normal = hit.normal
			if hit.collider != self and is_instance_valid(_hull_scars) and damage > 0.0:  # On the plating
				_hull_scars.add_scar(point, normal, aim - from_global, damage, hit.collider)
				if is_player():
					GameState.player_hull_scars = _hull_scars.export_scars()
			break
	if point == null:
		point = get_hull_point_facing(from_global)
	_last_hit = [point, normal if normal != null else (point - centre).normalized()]
	_add_smoulder(point, normal, damage)
	_accumulate_leak_damage(point, normal, damage)
	return point


# Every hit leaves a smouldering spot (HullSmoulder), or reheats one close by, in from the hit
# point (_ember_point()).
func _add_smoulder(point: Vector3, normal, damage: float) -> void:
	var heat: float = LaserHitEffect.intensity_for_damage(damage)
	if heat <= 0.0 or not is_inside_tree():
		return
	var size_scale: float = clamp(get_apparent_radius() / Constants.SMOULDER_REFERENCE_RADIUS, 0.5, 5.0)
	var centre: Vector3 = to_global(hull_bounds.position + hull_bounds.size * 0.5)
	var spot_point: Vector3 = _ember_point(point)
	var live: Array = []
	for spot in _smoulders:
		if is_instance_valid(spot) and not spot.is_queued_for_deletion():
			live.append(spot)
	_smoulders = live
	for spot in _smoulders:
		if spot.global_transform.origin.distance_to(spot_point) <= Constants.SMOULDER_MERGE_DISTANCE * size_scale:
			spot.reheat(heat)
			return
	if _smoulders.size() >= Constants.SMOULDER_MAX_PER_SHIP:
		_smoulders.pop_front().queue_free()
	var spot = HullSmoulderScene.instance()
	spot.outward = normal if normal != null else (point - centre).normalized()
	spot.heat = min(heat, Constants.SMOULDER_MAX_HEAT)
	spot.size_scale = size_scale
	spot.duration_factor = Constants.SMOULDER_WRECK_FACTOR if is_wreck else 1.0
	add_child(spot)
	spot.global_transform.origin = spot_point
	_smoulders.append(spot)


# Lasting ember trails, one per Constants.DAMAGE_TRAIL_HULL_STEP of hull lost: the first new one
# starts where the latest hit landed, any others at random points of the hull (both in toward the
# centre, _ember_point()). Brighter the more hull is lost; repairs remove them.
func _update_damage_trails() -> void:
	if not is_inside_tree() or hull_max <= 0.0:
		return
	var lost: float = clamp(1.0 - hull / hull_max, 0.0, 1.0)
	var wanted: int = int(min(floor(lost / Constants.DAMAGE_TRAIL_HULL_STEP + 0.0001), Constants.DAMAGE_TRAIL_MAX))
	var live: Array = []
	for trail in _damage_trails:
		if is_instance_valid(trail) and not trail.is_queued_for_deletion():
			live.append(trail)
	_damage_trails = live
	while _damage_trails.size() > wanted:
		_damage_trails.pop_back().queue_free()
	var centre: Vector3 = to_global(hull_bounds.position + hull_bounds.size * 0.5)
	var at_last_hit: bool = not _last_hit.empty()
	while _damage_trails.size() < wanted:
		var point: Vector3
		var outward: Vector3
		if at_last_hit:
			point = _last_hit[0]
			outward = _last_hit[1]
			at_last_hit = false
		else:
			outward = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			point = get_hull_point_facing(centre + outward * get_apparent_radius() * 10.0)
		point = _ember_point(point)
		var trail = DamageTrailScene.instance()
		trail.outward = outward
		trail.size_scale = clamp(get_apparent_radius() / Constants.SMOULDER_REFERENCE_RADIUS, 0.5, 5.0)
		add_child(trail)
		trail.global_transform.origin = point
		_damage_trails.append(trail)
	for trail in _damage_trails:
		trail.strength = lost
	if is_instance_valid(_hull_scars):
		_hull_scars.set_slag_count(int(floor(lost * _hull_scars.get_slag_capacity() + 0.0001)))


# Where an ember emitter for a hit at `point` sits: part of the way in toward the hull centre, since
# hits land on the collision hull, which can sit well outside the plating.
func _ember_point(point: Vector3) -> Vector3:
	return point.linear_interpolate(to_global(hull_bounds.position + hull_bounds.size * 0.5), Constants.EMBER_INSET_SHARE)


func get_damage_trail_count() -> int:
	var count := 0
	for trail in _damage_trails:
		if is_instance_valid(trail) and not trail.is_queued_for_deletion():
			count += 1
	return count


func get_smoulder_count() -> int:
	var count := 0
	for spot in _smoulders:
		if is_instance_valid(spot) and not spot.is_queued_for_deletion():
			count += 1
	return count


func get_hull_scar_count() -> int:
	return _hull_scars.get_scar_count() if is_instance_valid(_hull_scars) else 0


func _clear_smoulders() -> void:
	for spot in _smoulders:
		if is_instance_valid(spot):
			spot.queue_free()
	_smoulders.clear()


# `normal` is the hull's surface normal at the hit (null when the shot missed the hull shape): the leak vents
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


# Speed the engines hold against drag at full thrust (m/s).
func get_top_speed() -> float:
	if not is_instance_valid(movement_system):
		return 0.0
	return movement_system.linear_thrust / max(mass * Constants.LINEAR_DRAG, 0.001)


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
	if afterburner_lit:
		signature += Constants.SIG_AFTERBURNER * _engine_activity
	signature *= 1.0 - float(fit_stats.get("signature_damping", 0.0))  # A damper hides a share of it all
	return max(Constants.SIG_MIN, signature)


# --- Afterburner and decoys (modules; Constants LAW_AFTERBURNER_*, LAW_DECOY_*, DECOY_*) ---

func has_afterburner() -> bool:
	return float(fit_stats.get("afterburner_thrust", 0.0)) > 0.0


# Lights the afterburner (true if it is lit now) or puts it out. It takes power to light.
func set_afterburner(on: bool) -> bool:
	if on and (not has_afterburner() or is_wreck or is_docked or power <= 0.0):
		on = false
	if on != afterburner_lit:
		afterburner_lit = on
		_apply_fit_to_movement()
	return afterburner_lit


# Top speed with the afterburner lit (as it is without one).
func get_burst_top_speed() -> float:
	if not has_afterburner() or not is_instance_valid(movement_system):
		return get_top_speed()
	return (float(fit_stats.get("linear_thrust", 0.0)) + float(fit_stats.afterburner_thrust)) / max(mass * Constants.LINEAR_DRAG, 0.001)


func get_decoy_capacity() -> int:
	return int(fit_stats.get("decoy_charges", 0))


# Refills the launcher (at a base); the charges added.
func restock_decoys() -> int:
	var added: int = get_decoy_capacity() - decoys
	decoys = get_decoy_capacity()
	return int(max(0, added))


# A missile coming at this ship within DECOY_TRIGGER_TIME of impact draws a decoy (each missile one);
# DECOY_SEDUCE_CHANCE of them turn after the flare.
func _launch_decoys() -> void:
	for missile in get_tree().get_nodes_in_group("missile"):
		if decoys <= 0:
			return
		if missile.done or missile.target != self or missile.has_meta("decoy_drawn"):
			continue
		var offset: Vector3 = global_transform.origin - missile.global_transform.origin
		var distance: float = offset.length()
		var closing: float = (missile.velocity - linear_velocity).dot(offset / max(distance, 0.001))
		if closing <= 0.0 or distance / closing > Constants.DECOY_TRIGGER_TIME:
			continue
		missile.set_meta("decoy_drawn", true)
		decoys -= 1
		var side: Vector3 = offset.cross(Vector3.UP)
		side = (side.normalized() if side.length_squared() > 0.01 else Vector3.RIGHT) * (1.0 if randf() < 0.5 else -1.0)
		var decoy = DecoyScript.new()
		decoy.launch(get_parent(), global_transform.origin + side * get_apparent_radius(), linear_velocity + side * Constants.DECOY_EJECT_SPEED)
		var taken: bool = randf() < Constants.DECOY_SEDUCE_CHANCE
		if taken:
			missile.target = decoy
		if is_player():
			EventBus.emit_signal("announcement", "Decoy out (%d left): %s" % [decoys, "the missile took it" if taken else "the missile kept on"], "info" if taken else "danger")
		elif evo_uid != "":
			Evolution.note(evo_uid, "decoyed" if taken else "decoy_failed")


func get_sensor_strength() -> float:
	return float(fit_stats.get("sensor_strength", ship_template.sensor_strength if is_instance_valid(ship_template) else 1.0))


# Whether this ship's sensors see `other`: ships, wrecks, celestials and stations all have a
# signature. Anything without one is always known.
func detects(other) -> bool:
	if not is_instance_valid(other) or other == self or not other.has_method("get_signature"):
		return true
	if other.get("is_docked"):
		return false
	return global_transform.origin.distance_to(other.global_transform.origin) <= other.get_signature() * get_sensor_strength()


# --- Wealth (desperation; Constants AI block) ---

# WP the pilot has: the player's bank, an arena pilot's stake and takings (Evolution), or `wallet`.
func get_wallet() -> float:
	if is_player():
		return float(GameState.player_bank)
	if evo_uid != "":
		return Evolution.wallet_of(evo_uid)
	return wallet


# What the ship and its fitted parts are worth (WP).
func get_value() -> float:
	var value: float = float(ship_template.base_value) if is_instance_valid(ship_template) else 0.0
	for part_id in fit.get("tools", []) + fit.get("modules", []):
		var part = TemplateDatabase.get_template(str(part_id)) if str(part_id) != "" else null
		if part != null and part.get("base_value") != null:
			value += float(part.base_value)
	return value


# 0 comfortable .. 1 broke: how recklessly it flies (ShipControllerAI).
func get_desperation() -> float:
	var comfort: float = max(1.0, get_value() * Constants.AI_DESPERATION_COMFORT)
	return clamp(1.0 - get_wallet() / comfort, 0.0, 1.0)


# Weapons' damage per second (ToolController: lasers, missiles, cannons), plus a lance with lances left at this ship's top speed, over
# Constants AI_RAM_PASS_TIME between strikes (or its reload, if longer).
func get_damage_per_second() -> float:
	var tools = get_node_or_null("ToolController")
	var dps: float = tools.get_damage_per_second() if is_instance_valid(tools) and tools.has_method("get_damage_per_second") else 0.0
	for lance in get_lances():
		if lance.nails > 0:
			dps += lance.damage_at(get_top_speed() + Constants.LANCE_LAUNCH_SPEED) / max(float(lance.lance.reload), Constants.AI_RAM_PASS_TIME)
	return dps


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


# Takes up to `units` of a commodity out of the hold; returns how many came out.
func remove_cargo(commodity_id: String, units: int) -> int:
	var removed: int = int(min(units, int(cargo.get(commodity_id, 0))))
	if removed <= 0:
		return 0
	cargo[commodity_id] = int(cargo[commodity_id]) - removed
	if cargo[commodity_id] <= 0:
		cargo.erase(commodity_id)
	if is_player():
		GameState.player_cargo = cargo.duplicate()
	_update_mass()
	return removed


func clear_cargo() -> void:
	cargo.clear()
	if is_player():
		GameState.player_cargo = {}
	_update_mass()


# Restores the hull, puts out smoulder spots and clears scars; returns hull points restored.
func repair_hull() -> float:
	var restored: float = hull_max - hull
	hull = hull_max
	_clear_smoulders()
	if is_instance_valid(_hull_scars):
		_hull_scars.clear_scars()
	for child in get_children():
		if child.is_in_group(LanceController.LANCE_GROUP):
			child.queue_free()  # Lances stuck in the hull come out
	_update_damage_trails()
	if is_player():
		GameState.player_hull = hull
		GameState.player_hull_scars = []
	return restored


func get_salvage_units() -> int:
	return count_units(salvage)


# Lances stuck in this hull (LanceController strikes; repairs take them out) that `salvager`'s
# launchers take and their quivers have room for.
func recoverable_lances_for(salvager) -> int:
	return LanceController.recoverable_from(self, salvager)


# Pulls one lance that fits one of `salvager`'s launchers out of this hull into its quiver; true if
# it did.
func recover_lance_into(salvager) -> bool:
	return LanceController.recover_from(self, salvager)


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


# Hull and parts (the fit, less lances spent) plus cargo; drag scales with mass, so a loaded ship is
# slower and heavier to turn.
func _update_mass() -> void:
	var base_mass: float = float(fit_stats.get("mass", ship_template.mass if is_instance_valid(ship_template) else Constants.DEFAULT_SHIP_MASS))
	for lance in get_lances():
		base_mass -= lance.spent_mass()
	var tools = get_node_or_null("ToolController")
	if tools != null and tools.has_method("spent_ammo_mass"):
		base_mass -= tools.spent_ammo_mass()
	mass = max(1.0, base_mass + get_cargo_mass())


# --- Godot Lifecycle ---
func _ready():
	add_to_group("Agents")
	add_to_group("agent_body")
	EventBus.connect("agent_charged", self, "_on_agent_charged")
	# RigidBody settings for 6DOF space flight
	mode = RigidBody.MODE_RIGID
	gravity_scale = 0.0  # No gravity in space
	can_sleep = false  # Always active


func _physics_process(delta: float) -> void:
	if not is_wreck and power < power_max:
		power = min(power_max, power + power_regen * delta)
	if afterburner_lit:
		var used = movement_system.get("last_thrust_fraction") if is_instance_valid(movement_system) else 0.0
		var drain: float = float(fit_stats.get("afterburner_thrust", 0.0)) / 1000.0 * Constants.LAW_AFTERBURNER_POWER_PER_KN * float(used if used != null else 0.0) * delta
		if is_wreck or is_docked or not try_spend_power(drain):
			set_afterburner(false)  # Out of power: it goes out
	if decoys > 0 and not is_wreck and not is_docked:
		_decoy_watch -= delta
		if _decoy_watch <= 0.0:
			_decoy_watch = 0.1
			_launch_decoys()
	_apply_leak_thrust()
	var thrust_used = movement_system.get("last_thrust_fraction") if is_instance_valid(movement_system) else null
	var thrust: float = float(thrust_used) if thrust_used != null and not is_wreck and not is_docked else 0.0
	_engine_activity = lerp(_engine_activity, thrust, 1.0 - exp(-delta / Constants.SIG_ENGINE_SMOOTHING))


# Venting gas pushes back on the hull where it leaks; off-centre leaks turn the ship. Not on wrecks:
# they would drift and tumble on for minutes.
func _apply_leak_thrust() -> void:
	if _leaks.empty() or is_docked or is_wreck or not is_instance_valid(movement_system):
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
	# Wrecks have no thrust but obey the same drag as everything else, so they come to rest. Their
	# spin is damped directly at Constants.ANGULAR_DRAG per second: MovementSystem's drag torque
	# scales with mass, not the moment of inertia, so on a ship's hull it barely slows a spin.
	if is_wreck:
		movement_system.integrate_forces(state)
		state.angular_velocity *= exp(-Constants.ANGULAR_DRAG * state.step)
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


# Nose on `target`, easing off to a drift (an NPC making up its mind about it).
func command_watch(target: Spatial):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_watch(target)
	else:
		printerr("AgentBody: Cannot command_watch - NavigationSystem invalid.")


# Charge `target` at full speed, nose first (a kinetic lance; command_ram), running up as needed.
func command_ram(target: Spatial):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_ram(target)
	else:
		printerr("AgentBody: Cannot command_ram - NavigationSystem invalid.")


# Point the nose where a cannon round will meet `target`, holding `keep_range` from it (command_aim).
func command_aim(target: Spatial, keep_range: float):
	if is_instance_valid(navigation_system):
		navigation_system.set_command_aim(target, keep_range)
	else:
		printerr("AgentBody: Cannot command_aim - NavigationSystem invalid.")


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
