# LanceController: the ship's kinetic lance (a "lance" module; ShipLaws.lance_stats, Constants
# LAW_LANCE_*). Hammer and nail: a lance sits in the seat on the ship's axis, its tip past the nose;
# spares wait in a quiver on the hull (salvaging a wreck with a harpoon recovers the lances stuck in
# it that fit this seat: Agent.recoverable_lances_for). Only while armed (the player's LANCE button; an NPC while it
# rams) does the tip strike: each physics step it checks the lance and the tip's path relative to
# each ship near it against that ship's hull box (_sweep), so a fast ship cannot pass through. On a ship, a strike at a closing speed along
# the lance of at least LAW_LANCE_MIN_SPEED goes in with a chance that falls with the angle off
# square-on (ShipLaws.lance_hit_chance: sure square-on, unlikely past LAW_LANCE_GLANCE_ANGLE, where
# only a long lance may slip between parts) and does ShipLaws.lance_damage; otherwise it glances off
# (no damage, the lance stays seated). A strike stops
# the two ships against each other along the lance (an inelastic knock: the target is shoved, the
# rammer stopped) and leaves the lance in the target's hull until it is repaired; the next slides
# into the seat after the reload time. Docking restocks the quiver (restock()). Spent lances are
# gone from the ship's mass (spent_mass()). The module's mass also armours the bow (ShipLaws).
# Child of AgentBody, made by it when the fit has a lance (one per ship: ShipFit).

extends Spatial

signal struck(target, damage)
signal glanced(target, reason)  # reason: "too slow" or "at an angle"
signal nails_changed(nails)

const LANCE_GROUP = "stuck_lance"  # Lances left in a hull (cleared on repair)
const LanceMaterial = preload("res://assets/art/materials_generic/mat_engine_dark_alloy.tres")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")

var lance: Dictionary = {}  # ShipLaws.lance_stats
var module_id: String = ""
var armed: bool = false
var nails: int = 0  # Lances left, the seated one included
var reload_left: float = 0.0  # s until the next lance is seated
var _agent: RigidBody = null
var _nose: float = 0.0  # m from the ship's origin to its nose, along -Z
var _glanced: Dictionary = {}  # Instance id -> s before it can glance off that ship again (one event per pass)
var _charged: Dictionary = {}  # Instance id -> s before the same ship is told again that it is being charged
var _watch_left: float = 0.0  # s until the next look for ships it is charging
var _seat_mesh: MeshInstance = null
var _quiver: Spatial = null


func setup(agent: RigidBody, p_module_id: String, p_lance: Dictionary, p_nails: int = -1) -> void:
	_agent = agent
	module_id = p_module_id
	lance = p_lance
	nails = int(lance.count) if p_nails < 0 else int(min(p_nails, lance.count))
	reload_left = 0.0
	name = "LanceController"
	_nose = _measure_nose()
	_build_visuals()


func is_seated() -> bool:
	return nails > 0 and reload_left <= 0.0


# m from the ship's origin to where the seated lance starts (a little behind the nose).
func _seat() -> float:
	return _nose * (1.0 - Constants.LANCE_SEAT_DEPTH)


# Lance length past the ship's origin to its tip (m).
func get_reach() -> float:
	return _seat() + float(lance.length)


func get_tip() -> Vector3:
	return _agent.global_transform.xform(Vector3(0, 0, -get_reach()))


# Closing speed along the lance on `target` (m/s): what the strike would be at now.
func closing_speed_on(target: Spatial) -> float:
	var target_velocity: Vector3 = target.linear_velocity if target is RigidBody else Vector3.ZERO
	return (_agent.linear_velocity - target_velocity).dot(_axis())


# Damage at `closing_speed` square-on (0 if too slow).
func damage_at(closing_speed: float) -> float:
	return ShipLaws.lance_damage(lance, closing_speed)


# Whether a lance of `nail_mass` kg fits this seat (Constants.LANCE_RECOVER_MASS_TOLERANCE).
func fits(nail_mass: float) -> bool:
	return abs(nail_mass - float(lance.nail_mass)) <= float(lance.nail_mass) * Constants.LANCE_RECOVER_MASS_TOLERANCE


# kg of lances spent (left in targets) since the quiver was full.
func spent_mass() -> float:
	return float(lance.nail_mass) * max(0, int(lance.count) - nails) if not lance.empty() else 0.0


# Fills the quiver, with at most `limit` lances if given; returns how many it took.
func restock(limit: int = -1) -> int:
	var taken: int = int(lance.count) - nails
	if limit >= 0:
		taken = int(min(taken, limit))
	nails += taken
	reload_left = 0.0
	_update_visuals()
	emit_signal("nails_changed", nails)
	return taken


func _physics_process(delta: float) -> void:
	if reload_left > 0.0:
		reload_left = max(0.0, reload_left - delta)
		if reload_left <= 0.0:
			_update_visuals()
	for id in _glanced.keys():
		_glanced[id] -= delta
		if _glanced[id] <= 0.0:
			_glanced.erase(id)
	for id in _charged.keys():
		_charged[id] -= delta
		if _charged[id] <= 0.0:
			_charged.erase(id)
	if armed and is_seated() and is_instance_valid(_agent) and not _agent.is_wreck and not _agent.is_docked:
		_sweep(delta)
		_watch_left -= delta
		if _watch_left <= 0.0:
			_watch_left = Constants.CHARGE_WATCH_INTERVAL
			_announce_charges()


# Tells each ship it is charging (EventBus agent_charged), once a pass: it sees the lance coming.
func _announce_charges() -> void:
	if not _agent.is_inside_tree():
		return
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body != _agent and not _charged.has(body.get_instance_id()) and is_charging(body):
			_charged[body.get_instance_id()] = Constants.CHARGE_ALERT_COOLDOWN
			EventBus.emit_signal("agent_charged", body, _agent)


# Charging `target`: armed and seated, nose toward it, within CHARGE_ALERT_DISTANCE, closing at
# strike speed on a line that meets it (its sideways drift would miss by less than CHARGE_ALERT_MISS
# past its size). Seen the same way by whoever is charged, NPC or player.
func is_charging(target) -> bool:
	if not (armed and is_seated() and is_instance_valid(target) and target is RigidBody) or target.get("is_wreck") != false or target.get("is_docked"):
		return false
	var offset: Vector3 = target.global_transform.origin - _agent.global_transform.origin
	var distance: float = offset.length()
	if distance < 1.0 or distance > Constants.CHARGE_ALERT_DISTANCE:
		return false
	var direction: Vector3 = offset / distance
	var relative: Vector3 = _agent.linear_velocity - target.linear_velocity
	var closing: float = relative.dot(direction)
	if closing < Constants.LAW_LANCE_MIN_SPEED or _axis().dot(direction) < Constants.CHARGE_ALERT_ALIGNMENT:
		return false
	var radius: float = target.get_apparent_radius() if target.has_method("get_apparent_radius") else 10.0
	var miss: float = (relative - direction * closing).length() * distance / closing  # Sideways by the time it gets there
	return miss < radius + Constants.CHARGE_ALERT_MISS


# The tip meets a ship when it comes within LANCE_TIP_MARGIN of the ship's hull box (its model's
# bounds), checked by proximity rather than the physics' collision: along the lance from the seat to
# the tip, and along the tip's path this step relative to that ship (closing speeds of a few hundred
# m/s cover metres per step, more than a thin hull is deep).
func _sweep(delta: float) -> void:
	if not _agent.is_inside_tree():
		return
	var tip: Vector3 = get_tip()
	var seat: Vector3 = _agent.global_transform.xform(Vector3(0, 0, -_seat()))
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == _agent or not body is RigidBody or body.get("is_wreck") != false or _glanced.has(body.get_instance_id()):
			continue  # Wrecks are not worth a lance
		var relative: Vector3 = (_agent.linear_velocity - body.linear_velocity) * delta
		var radius: float = body.get_apparent_radius() if body.has_method("get_apparent_radius") else 10.0
		if tip.distance_to(body.global_transform.origin) > radius + relative.length() + float(lance.length) + Constants.LANCE_TIP_MARGIN:
			continue
		var bounds: AABB = body.hull_bounds.grow(Constants.LANCE_TIP_MARGIN)
		var to_local: Transform = body.global_transform.affine_inverse()
		var hit: Dictionary = _segment_into_box(to_local.xform(seat), to_local.xform(tip), bounds)
		if hit.empty():
			hit = _segment_into_box(to_local.xform(tip - relative), to_local.xform(tip), bounds)
		if not hit.empty():
			strike(body, body.global_transform.xform(hit.point), body.global_transform.basis.xform(hit.normal).normalized())
			return


# Where the segment `from` -> `to` first enters `box` (slab method): {"point", "normal"} (the face's
# outward normal; a start inside counts as a square hit), or {} if it misses.
static func _segment_into_box(from: Vector3, to: Vector3, box: AABB) -> Dictionary:
	var direction: Vector3 = to - from
	var t_enter := 0.0
	var t_exit := 1.0
	var normal := Vector3.ZERO
	for axis in range(3):
		var low: float = box.position[axis]
		var high: float = box.end[axis]
		if abs(direction[axis]) < 0.000001:
			if from[axis] < low or from[axis] > high:
				return {}
			continue
		var t1: float = (low - from[axis]) / direction[axis]
		var t2: float = (high - from[axis]) / direction[axis]
		var face := Vector3.ZERO
		face[axis] = -1.0 if t1 < t2 else 1.0
		if t1 > t2:
			var swap: float = t1
			t1 = t2
			t2 = swap
		if t1 > t_enter:
			t_enter = t1
			normal = face
		t_exit = min(t_exit, t2)
		if t_enter > t_exit:
			return {}
	if normal == Vector3.ZERO:
		normal = -direction.normalized() if direction.length_squared() > 0.0 else Vector3.BACK
	return {"point": from + direction * t_enter, "normal": normal}


# The tip meets `target` at `point` (surface `normal`): strikes or glances off. Returns the damage.
# `roll` (0-1) decides an angled strike; random if not given.
func strike(target: RigidBody, point: Vector3, normal: Vector3, roll: float = -1.0) -> float:
	var axis: Vector3 = _axis()
	var closing: float = closing_speed_on(target)
	var angle: float = rad2deg(acos(clamp(abs(normal.normalized().dot(axis)), 0.0, 1.0)))  # Off the face it meets
	var bounds = target.get("hull_bounds")
	if bounds is AABB:  # A lance driving at the hull's middle goes in, whichever face of its box it meets first
		var inward: Vector3 = target.to_global(bounds.position + bounds.size * 0.5) - point
		if inward.length_squared() > 0.01:
			angle = min(angle, rad2deg(acos(clamp(inward.normalized().dot(axis), -1.0, 1.0))))
	var motion: Vector3 = _agent.linear_velocity - target.linear_velocity
	if motion.length_squared() > 1.0:  # But only motion along the lance drives it in: a sideswipe glances
		angle = max(angle, rad2deg(acos(clamp(motion.normalized().dot(axis), -1.0, 1.0))))
	var damage: float = ShipLaws.lance_damage(lance, closing)
	if roll < 0.0:
		roll = randf()
	if damage <= 0.0 or roll >= ShipLaws.lance_hit_chance(lance, angle):
		_glanced[target.get_instance_id()] = 1.0
		emit_signal("glanced", target, "too slow, %d of %d m/s" % [int(closing), int(Constants.LAW_LANCE_MIN_SPEED)] if damage <= 0.0 else "at %d degrees" % int(angle))
		return 0.0
	_knock(target, axis)
	if target.has_method("register_hit"):
		target.register_hit(point - axis * float(lance.length), damage, point)
	_leave_lance(target, point, axis)
	nails -= 1
	reload_left = float(lance.reload) if nails > 0 else 0.0
	_update_visuals()
	emit_signal("nails_changed", nails)
	emit_signal("struck", target, damage)
	if target.has_method("apply_damage"):
		target.apply_damage(damage, _agent)
	return damage


# Both ships end up moving alike along the lance (momentum kept): the target is shoved, the rammer stopped.
func _knock(target: RigidBody, axis: Vector3) -> void:
	var own_mass: float = max(_agent.mass, 1.0)
	var target_mass: float = max(target.mass, 1.0)
	var own_along: float = _agent.linear_velocity.dot(axis)
	var target_along: float = target.linear_velocity.dot(axis)
	var common: float = (own_mass * own_along + target_mass * target_along) / (own_mass + target_mass)
	_agent.linear_velocity += axis * (common - own_along)  # At once: the hulls must not meet at ramming speed
	target.linear_velocity += axis * (common - target_along)


# The struck lance stays in the hull, a third of it in (Constants LANCE_STUCK_MAX per ship), turned
# LANCE_STUCK_CENTERING of the way from the lance's line toward the target's centre.
func _leave_lance(target: Spatial, point: Vector3, axis: Vector3) -> void:
	if not target.is_inside_tree():
		return
	var bounds = target.get("hull_bounds")
	if bounds is AABB:  # In toward the target's centre, not left standing off a glancing face
		var inward: Vector3 = (target.to_global(bounds.position + bounds.size * 0.5) - point).normalized()
		axis = axis.linear_interpolate(inward, Constants.LANCE_STUCK_CENTERING).normalized()
	var stuck: Array = []
	for child in target.get_children():
		if child.is_in_group(LANCE_GROUP):
			stuck.append(child)
	if stuck.size() >= Constants.LANCE_STUCK_MAX:
		stuck[0].queue_free()
	var length: float = float(lance.length)
	var mesh := _lance_mesh(length)
	mesh.add_to_group(LANCE_GROUP)
	mesh.set_meta("nail_mass", float(lance.nail_mass))  # Salvage can recover it into a seat it fits
	target.add_child(mesh)
	var centre: Vector3 = point - axis * length * (0.5 - Constants.LANCE_STUCK_DEPTH)
	mesh.global_transform = Transform(_basis_along(axis), centre)


func _axis() -> Vector3:
	return -_agent.global_transform.basis.z.normalized()


# --- Looks: the seated lance on the axis, the spares round the stern ---

func _measure_nose() -> float:
	var bounds = _agent.get("hull_bounds")
	if bounds is AABB and bounds.size != Vector3.ZERO:
		return max(0.0, -bounds.position.z)
	return float(_agent.get_apparent_radius()) if _agent.has_method("get_apparent_radius") else 10.0


func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()
	var length: float = float(lance.length)
	_seat_mesh = _lance_mesh(length)
	add_child(_seat_mesh)
	_seat_mesh.transform = Transform(_basis_along(Vector3.FORWARD), Vector3(0, 0, -(_seat() + length * 0.5)))
	_quiver = Spatial.new()
	_quiver.name = "Quiver"
	add_child(_quiver)
	var spares: int = int(lance.count) - 1
	var ring: float = max(1.0, _nose * Constants.LANCE_QUIVER_RING)
	for i in range(spares):
		var spare := _lance_mesh(length * Constants.LANCE_QUIVER_SCALE)
		var angle: float = TAU * i / max(1, spares)
		spare.transform = Transform(_basis_along(Vector3.FORWARD), Vector3(cos(angle) * ring, sin(angle) * ring, _nose * 0.3))
		_quiver.add_child(spare)
	_update_visuals()


func _update_visuals() -> void:
	if is_instance_valid(_seat_mesh):
		_seat_mesh.visible = is_seated()
	if is_instance_valid(_quiver):
		var spares: int = nails - (1 if is_seated() else 0)
		for i in range(_quiver.get_child_count()):
			_quiver.get_child(i).visible = i < spares


func _lance_mesh(length: float) -> MeshInstance:
	var cylinder := CylinderMesh.new()
	var radius: float = Constants.LANCE_RADIUS * pow(float(lance.nail_mass) / Constants.LAW_LANCE_DAMAGE[0], 1.0 / 3.0)
	cylinder.top_radius = radius * Constants.LANCE_TIP_SHARE  # The tip (the mesh's +Y)
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 8
	cylinder.rings = 1
	var mesh := MeshInstance.new()
	mesh.mesh = cylinder
	mesh.material_override = LanceMaterial
	mesh.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	return mesh


# A basis whose +Y (the cylinder's axis, tip end) points along `direction`.
static func _basis_along(direction: Vector3) -> Basis:
	var y: Vector3 = direction.normalized()
	var x: Vector3 = y.cross(Vector3.UP if abs(y.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))
