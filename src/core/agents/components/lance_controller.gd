# LanceController: the ship's kinetic lance (a "lance" module; ShipLaws.lance_stats, Constants
# LAW_LANCE_*). Hammer and nail: a lance sits in the seat on the ship's axis, its tip past the nose;
# spares wait in a quiver on the hull. Only while armed (the player's LANCE button; an NPC while it
# rams) does the tip strike: each physics step a ray runs from the seat to the tip and on by the
# step's travel, so a fast ship cannot pass through. On a ship, a strike at a closing speed along
# the lance of at least LAW_LANCE_MIN_SPEED, within LAW_LANCE_GLANCE_ANGLE of square-on, does
# ShipLaws.lance_damage; otherwise it glances off (no damage, the lance stays seated). A strike stops
# the two ships against each other along the lance (an inelastic knock: the target is shoved, the
# rammer stopped) and leaves the lance in the target's hull until it is repaired; the next slides
# into the seat after the reload time. Docking restocks the quiver (restock()). Spent lances are
# gone from the ship's mass (spent_mass()). The module's mass also armours the bow (ShipLaws).
# Child of AgentBody, made by it when the fit has a lance (one per ship: ShipFit).

extends Spatial

signal struck(target, damage)
signal glanced(target)
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
var _excluded: Array = []  # Own body and hit surface: the ray ignores them
var _glanced: Dictionary = {}  # Instance id -> s before it can glance off that ship again (one event per pass)
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


# Lance length past the ship's origin to its tip (m).
func get_reach() -> float:
	return _nose + float(lance.length)


func get_tip() -> Vector3:
	return _agent.global_transform.xform(Vector3(0, 0, -get_reach()))


# Closing speed along the lance on `target` (m/s): what the strike would be at now.
func closing_speed_on(target: Spatial) -> float:
	var target_velocity: Vector3 = target.linear_velocity if target is RigidBody else Vector3.ZERO
	return (_agent.linear_velocity - target_velocity).dot(_axis())


# Damage at `closing_speed` square-on (0 if too slow).
func damage_at(closing_speed: float) -> float:
	return ShipLaws.lance_damage(lance, closing_speed, 0.0)


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
	if armed and is_seated() and is_instance_valid(_agent) and not _agent.is_wreck and not _agent.is_docked:
		_sweep(delta)


func _sweep(delta: float) -> void:
	if not _agent.is_inside_tree():
		return
	var axis: Vector3 = _axis()
	var travel: float = max(0.0, _agent.linear_velocity.dot(axis)) * delta
	var from: Vector3 = _agent.global_transform.xform(Vector3(0, 0, -_nose * 0.5))
	var to: Vector3 = get_tip() + axis * travel
	var hit: Dictionary = _agent.get_world().direct_space_state.intersect_ray(from, to, _excluded, Constants.SHOT_BLOCK_MASK)
	if hit.empty():
		return
	var target = _agent_of(hit.collider)
	if target == null or target == _agent or target.is_wreck or _glanced.has(target.get_instance_id()):
		return  # Wrecks are not worth a lance
	strike(target, hit.position, hit.normal)


# The tip meets `target` at `point` (surface `normal`): strikes or glances off. Returns the damage.
func strike(target: RigidBody, point: Vector3, normal: Vector3) -> float:
	var axis: Vector3 = _axis()
	var closing: float = closing_speed_on(target)
	var angle: float = rad2deg(acos(clamp(abs(normal.normalized().dot(axis)), 0.0, 1.0)))
	var damage: float = ShipLaws.lance_damage(lance, closing, angle)
	if damage <= 0.0:
		_glanced[target.get_instance_id()] = 1.0
		emit_signal("glanced", target)
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


# The struck lance stays in the hull, a third of it in (Constants LANCE_STUCK_MAX per ship).
func _leave_lance(target: Spatial, point: Vector3, axis: Vector3) -> void:
	if not target.is_inside_tree():
		return
	var stuck: Array = []
	for child in target.get_children():
		if child.is_in_group(LANCE_GROUP):
			stuck.append(child)
	if stuck.size() >= Constants.LANCE_STUCK_MAX:
		stuck[0].queue_free()
	var length: float = float(lance.length)
	var mesh := _lance_mesh(length)
	mesh.add_to_group(LANCE_GROUP)
	target.add_child(mesh)
	var centre: Vector3 = point - axis * length * (0.5 - Constants.LANCE_STUCK_DEPTH)
	mesh.global_transform = Transform(_basis_along(axis), centre)


func _axis() -> Vector3:
	return -_agent.global_transform.basis.z.normalized()


static func _agent_of(collider: Object):
	var node = collider
	while node != null and node is Node:
		if node is RigidBody and node.has_method("apply_damage") and node.get("is_wreck") != null:
			return node
		node = node.get_parent()
	return null


# --- Looks: the seated lance on the axis, the spares round the stern ---

func _measure_nose() -> float:
	var bounds = _agent.get("hull_bounds")
	if bounds is AABB and bounds.size != Vector3.ZERO:
		return max(0.0, -bounds.position.z)
	return float(_agent.get_apparent_radius()) if _agent.has_method("get_apparent_radius") else 10.0


func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()
	_excluded = [_agent]
	var surface = _agent.find_node("HitSurface", true, false)
	if surface != null:
		_excluded.append(surface)
	var length: float = float(lance.length)
	_seat_mesh = _lance_mesh(length)
	add_child(_seat_mesh)
	_seat_mesh.transform = Transform(_basis_along(Vector3.FORWARD), Vector3(0, 0, -(_nose + length * 0.5)))
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
	cylinder.top_radius = radius * 0.3  # The tip (the mesh's +Y)
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
