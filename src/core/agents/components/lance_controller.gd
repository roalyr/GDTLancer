# LanceController: a kinetic lance launcher (a "lance" module; ShipLaws.lance_stats, Constants
# LAW_LANCE_*). A ship may carry several, side by side across its bow (mount_offset: one sits on the
# axis). A lance sits in the seat; spares wait in a quiver on the hull (salvaging a wreck with a harpoon recovers the lances stuck in it that fit this seat:
# Agent.recoverable_lances_for). Only while armed (the player's LANCE button; an NPC while it rams)
# does it fire, and only at the ram's target (NavigationSystem RAM): once within
# Constants.LANCE_RELEASE_RANGE of it, the seat throws the lance at LANCE_LAUNCH_SPEED toward it,
# aimed (within LANCE_AIM_CONE of the nose) so that the lance's flight relative to the target runs
# straight at its middle, cancelling the ship's sideways drift (firing_solution); the ship flies by
# (command_ram passes beside the target). The throw kicks the ship back by the lance's momentum, at
# the launcher's mount: one off the axis also twists the ship, the price of a bank of launchers. In
# flight it is a LanceShot. On a ship, a lance meeting it at a closing speed along the lance of at
# least LAW_LANCE_MIN_SPEED goes in with a chance that falls with the angle off square-on
# (ShipLaws.lance_hit_chance) and does ShipLaws.lance_damage, shoving the ship by its momentum and
# staying in its hull until it is repaired; otherwise it glances off and is lost. A bared rock breaks
# out a chunk (Constants MINING). The next lance is seated after the reload time. Docking restocks
# the quiver (restock()). Spent lances are gone from the ship's mass (spent_mass()). The module's
# mass also armours the bow (ShipLaws).
# Child of AgentBody, one per lance module in its fit (Agent.get_lances).

extends Spatial

signal struck(target, damage)
signal glanced(target, reason)  # reason: "too slow" or "at an angle"
signal nails_changed(nails)
signal launched(target)

const LANCE_GROUP = "stuck_lance"  # Lances left in a hull (cleared on repair)
const LanceMaterial = preload("res://assets/art/materials_generic/mat_engine_dark_alloy.tres")
const ShipLaws = preload("res://src/core/systems/ship_laws.gd")
const LanceShot = preload("res://src/core/agents/components/lance_shot.gd")

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
var mount_offset: float = 0.0  # m off the ship's axis, across (+X), that this launcher sits


# Launcher `index` of `count` on the ship: the launchers spread evenly across the middle half of the
# bow's width (one alone sits on the axis).
func setup(agent: RigidBody, p_module_id: String, p_lance: Dictionary, p_nails: int = -1, index: int = 0, count: int = 1) -> void:
	_agent = agent
	module_id = p_module_id
	lance = p_lance
	nails = int(lance.count) if p_nails < 0 else int(min(p_nails, lance.count))
	reload_left = 0.0
	name = "LanceController" if index == 0 else "LanceController%d" % (index + 1)
	_nose = _measure_nose()
	mount_offset = 0.0
	if count > 1:
		var bounds = _agent.get("hull_bounds")
		var width: float = bounds.size.x if bounds is AABB and bounds.size.x > 0.0 else _nose
		mount_offset = lerp(-0.25, 0.25, float(index) / float(count - 1)) * width
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
	return _agent.global_transform.xform(Vector3(mount_offset, 0, -get_reach()))


# Closing speed along the lance on `target` (m/s): what the strike would be at now.
func closing_speed_on(target: Spatial) -> float:
	var target_velocity: Vector3 = target.linear_velocity if target is RigidBody else Vector3.ZERO
	return (_agent.linear_velocity - target_velocity).dot(_axis())


# The closing speed a lance thrown now would meet `target` at (the ship's own plus the launch).
func strike_speed_on(target: Spatial) -> float:
	return closing_speed_on(target) + Constants.LANCE_LAUNCH_SPEED


# Damage at `closing_speed` square-on (0 if too slow).
func damage_at(closing_speed: float) -> float:
	return ShipLaws.lance_damage(lance, closing_speed)


# The throw's kick on the ship (`impulse`: the lance's momentum, N s), at the launcher's mount: it
# slows the ship and, off the axis, twists it (inertia as a solid ball of the ship's size).
func _recoil(impulse: Vector3) -> void:
	var mass: float = max(_agent.mass, 1.0)
	_agent.linear_velocity -= impulse / mass
	if mount_offset != 0.0:
		var radius: float = _agent.get_apparent_radius() if _agent.has_method("get_apparent_radius") else 10.0
		var arm: Vector3 = _agent.global_transform.basis.xform(Vector3(mount_offset, 0, -_seat()))
		_agent.angular_velocity += arm.cross(-impulse) / (0.4 * mass * radius * radius)


# Lances stuck in `hull` (a wreck or a chunk) that `salvager`'s launchers take and have room for.
static func recoverable_from(hull: Node, salvager) -> int:
	if not (is_instance_valid(salvager) and salvager.has_method("get_lances")):
		return 0
	var stuck: Array = _stuck_in(hull)
	var total := 0
	for lance in salvager.get_lances():
		var room: int = int(lance.lance.count) - lance.nails
		var fitting := 0
		for child in stuck:
			if lance.fits(float(child.get_meta("nail_mass", 0.0))):
				fitting += 1
		var taken: int = int(min(room, fitting))
		total += taken
		for i in range(taken):  # Each stuck lance goes to one launcher
			for child in stuck:
				if lance.fits(float(child.get_meta("nail_mass", 0.0))):
					stuck.erase(child)
					break
	return total


# Pulls one lance out of `hull` into the first of `salvager`'s launchers it fits with room; true if
# it did.
static func recover_from(hull: Node, salvager) -> bool:
	if recoverable_from(hull, salvager) <= 0:
		return false
	for lance in salvager.get_lances():
		if lance.nails >= int(lance.lance.count):
			continue
		for child in _stuck_in(hull):
			if lance.fits(float(child.get_meta("nail_mass", 0.0))):
				hull.remove_child(child)
				child.queue_free()
				lance.restock(1)
				return true
	return false


static func _stuck_in(hull: Node) -> Array:
	var found: Array = []
	for child in hull.get_children():
		if child.is_in_group(LANCE_GROUP) and not child.is_queued_for_deletion():
			found.append(child)
	return found


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
	if armed and is_seated() and is_instance_valid(_agent) and not _agent.is_wreck and not _agent.is_docked and _agent.is_inside_tree():
		var target = get_aim_target()
		if target != null:
			var solution: Dictionary = firing_solution(target)
			if not solution.empty():
				fire(target, solution)
		_watch_left -= delta
		if _watch_left <= 0.0:
			_watch_left = Constants.CHARGE_WATCH_INTERVAL
			_announce_charges()


# What it fires at: the target of the ship's ram (NavigationSystem RAM), or null.
func get_aim_target() -> Spatial:
	var nav = _agent.get("navigation_system")
	if not is_instance_valid(nav) or nav.get_current_command_type() != nav.CommandType.RAM:
		return null
	var target = nav._current_command.get("target_node")
	if not (target is Spatial and is_instance_valid(target) and target.is_inside_tree()):
		return null
	if target is RigidBody:
		return target if target.get("is_wreck") == false else null  # Wrecks and chunks are rammed, not lanced
	return target if target.is_in_group("mineable") else null


# How to throw a lance at `target` now, or {} if not now: within LANCE_RELEASE_RANGE of its hull
# (a ship) or surface (a rock), the launch (LANCE_LAUNCH_SPEED, within LANCE_AIM_CONE of the nose)
# that sends the lance straight at its middle relative to it, at strike speed. {"direction" (the
# throw), "velocity" (the lance's), "closing"}.
func firing_solution(target: Spatial) -> Dictionary:
	var tip: Vector3 = get_tip()
	var target_velocity: Vector3 = target.linear_velocity if target is RigidBody else Vector3.ZERO
	var radius: float = target.get_apparent_radius() if target.has_method("get_apparent_radius") else 10.0
	var aim: Vector3 = target.global_transform.origin
	var bounds = target.get("hull_bounds")
	if target is RigidBody and bounds is AABB:
		aim = target.to_global(bounds.position + bounds.size * 0.5)
	var offset: Vector3 = aim - tip
	var distance: float = offset.length()
	if distance < 0.01 or distance - radius > Constants.LANCE_RELEASE_RANGE:
		return {}
	var line: Vector3 = offset / distance
	var relative: Vector3 = _agent.linear_velocity - target_velocity
	var along: float = relative.dot(line)
	var drift: Vector3 = relative - line * along
	var launch_speed: float = Constants.LANCE_LAUNCH_SPEED
	if drift.length() >= launch_speed:
		return {}  # Slipping by too fast to throw it straight at the target
	var forward: float = sqrt(launch_speed * launch_speed - drift.length_squared())
	var direction: Vector3 = (line * forward - drift) / launch_speed
	if direction.dot(_axis()) < cos(deg2rad(Constants.LANCE_AIM_CONE)):
		return {}
	var closing: float = along + forward
	if closing < Constants.LAW_LANCE_MIN_SPEED:
		return {}
	return {"direction": direction, "velocity": _agent.linear_velocity + direction * launch_speed, "closing": closing}


# Throws the seated lance (a LanceShot) at `target`; the ship is kicked back by its momentum.
func fire(target: Spatial, solution: Dictionary) -> void:
	var direction: Vector3 = solution.direction
	var velocity: Vector3 = solution.velocity
	_recoil(direction * Constants.LANCE_LAUNCH_SPEED * float(lance.nail_mass))
	var shot = LanceShot.new()
	var world = _agent.get_parent()
	world.add_child(shot)
	shot.launch(self, target, get_tip(), velocity, (velocity - (target.linear_velocity if target is RigidBody else Vector3.ZERO)).normalized(), _lance_mesh(float(lance.length)))
	nails -= 1
	reload_left = float(lance.reload) if nails > 0 else 0.0
	_update_visuals()
	emit_signal("nails_changed", nails)
	emit_signal("launched", target)


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
	if closing < max(1.0, Constants.LAW_LANCE_MIN_SPEED - Constants.LANCE_LAUNCH_SPEED) or _axis().dot(direction) < Constants.CHARGE_ALERT_ALIGNMENT:
		return false
	var radius: float = target.get_apparent_radius() if target.has_method("get_apparent_radius") else 10.0
	var miss: float = (relative - direction * closing).length() * distance / closing  # Sideways by the time it gets there
	return miss < radius + Constants.CHARGE_ALERT_MISS


# A lance (along `direction`, at `velocity`; the seated one's if not given) meets a rock at `point`
# (surface `normal`). Struck at strike speed square enough, it breaks chunks off (Asteroid.break_chunks)
# with the lance stuck in the biggest; otherwise the lance glances off. Returns the damage. `roll` as
# for strike().
func strike_rock(rock: Spatial, point: Vector3, normal: Vector3, roll: float = -1.0, direction: Vector3 = Vector3.ZERO, velocity = null) -> float:
	var axis: Vector3 = direction.normalized() if direction != Vector3.ZERO else _axis()
	var motion: Vector3 = velocity if velocity is Vector3 else _agent.linear_velocity
	var closing: float = motion.dot(axis)
	var angle: float = rad2deg(acos(clamp(abs(normal.normalized().dot(axis)), 0.0, 1.0)))
	var damage: float = ShipLaws.lance_damage(lance, closing)
	if roll < 0.0:
		roll = randf()
	var reason: String = ""
	if rock.get_deposit() <= 0:
		reason = "the rock is worked out"
	elif damage <= 0.0:
		reason = "too slow, %d of %d m/s" % [int(closing), int(Constants.LAW_LANCE_MIN_SPEED)]
	elif roll >= ShipLaws.lance_hit_chance(lance, angle):
		reason = "at %d degrees" % int(angle)
	if reason != "":
		_glanced[rock.get_instance_id()] = 1.0
		emit_signal("glanced", rock, reason)
		return 0.0
	var chunks: Array = rock.break_chunks(point, axis, damage)
	if chunks.empty():
		return 0.0
	var chunk = chunks[0]
	_leave_lance(chunk, chunk.get_hull_point_facing(point - axis * 10.0), axis)
	emit_signal("struck", chunk, damage)
	return damage


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


# A lance (along `direction`, at `velocity`; the seated one's if not given) meets `target` at `point`
# (surface `normal`): strikes or glances off. Returns the damage. `roll` (0-1) decides an angled
# strike; random if not given.
func strike(target: RigidBody, point: Vector3, normal: Vector3, roll: float = -1.0, direction: Vector3 = Vector3.ZERO, velocity = null) -> float:
	var axis: Vector3 = direction.normalized() if direction != Vector3.ZERO else _axis()
	var lance_velocity: Vector3 = velocity if velocity is Vector3 else _agent.linear_velocity
	var closing: float = (lance_velocity - target.linear_velocity).dot(axis)
	var angle: float = rad2deg(acos(clamp(abs(normal.normalized().dot(axis)), 0.0, 1.0)))  # Off the face it meets
	var bounds = target.get("hull_bounds")
	if bounds is AABB:  # A lance driving at the hull's middle goes in, whichever face of its box it meets first
		var inward: Vector3 = target.to_global(bounds.position + bounds.size * 0.5) - point
		if inward.length_squared() > 0.01:
			angle = min(angle, rad2deg(acos(clamp(inward.normalized().dot(axis), -1.0, 1.0))))
	var motion: Vector3 = lance_velocity - target.linear_velocity
	if motion.length_squared() > 1.0:  # But only motion along the lance drives it in: a sideswipe glances
		angle = max(angle, rad2deg(acos(clamp(motion.normalized().dot(axis), -1.0, 1.0))))
	var damage: float = ShipLaws.lance_damage(lance, closing)
	if roll < 0.0:
		roll = randf()
	if damage <= 0.0 or roll >= ShipLaws.lance_hit_chance(lance, angle):
		_glanced[target.get_instance_id()] = 1.0
		emit_signal("glanced", target, "too slow, %d of %d m/s" % [int(closing), int(Constants.LAW_LANCE_MIN_SPEED)] if damage <= 0.0 else "at %d degrees" % int(angle))
		return 0.0
	target.linear_velocity += axis * closing * float(lance.nail_mass) / max(target.mass, 1.0)  # Shoved by the lance's momentum
	if target.has_method("register_hit"):
		target.register_hit(point - axis * float(lance.length), damage, point)
	_leave_lance(target, point, axis)
	emit_signal("struck", target, damage)
	if target.has_method("apply_damage"):
		target.apply_damage(damage, _agent)
	return damage


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
	_seat_mesh.transform = Transform(_basis_along(Vector3.FORWARD), Vector3(mount_offset, 0, -(_seat() + length * 0.5)))
	_quiver = Spatial.new()
	_quiver.name = "Quiver"
	add_child(_quiver)
	var spares: int = int(lance.count) - 1
	var ring: float = max(1.0, _nose * Constants.LANCE_QUIVER_RING)
	for i in range(spares):
		var spare := _lance_mesh(length * Constants.LANCE_QUIVER_SCALE)
		var angle: float = TAU * i / max(1, spares)
		spare.transform = Transform(_basis_along(Vector3.FORWARD), Vector3(mount_offset + cos(angle) * ring, sin(angle) * ring, _nose * 0.3))
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
