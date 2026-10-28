# LanceShot: a lance in flight, fired by a LanceController at its target from within
# Constants.LANCE_RELEASE_RANGE. It flies straight at its launch velocity (the ship's plus
# LANCE_LAUNCH_SPEED toward the target) and checks only that target, by proximity rather than the
# physics' collision: a ship's hull box (along its path this step relative to the ship, as a fast
# lance would otherwise pass through) or, for a rock, a ray along its path. Meeting it, the lance
# strikes or glances (LanceController.strike / strike_rock); anything else in the way, the target
# gone or LANCE_SHOT_LIFE s up, it misses. A lance that glances or misses drifts on as a LooseLance
# (LanceController.drop_lance) for a harpoon to recover. A child of the world, not of the ship: a
# lance outlives a pass; if its ship is gone before it lands, it is lost.

extends Spatial

var velocity: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD  # Its axis: the line it was launched along
var _target: WeakRef = weakref(null)
var _launcher: WeakRef = weakref(null)  # The LanceController that fired it
var _shooter: WeakRef = weakref(null)  # Its ship, left out of the ray
var _life: float = 0.0


func launch(launcher: Node, target: Spatial, tip: Vector3, p_velocity: Vector3, p_direction: Vector3, mesh: Spatial) -> void:
	_launcher = weakref(launcher)
	_shooter = weakref(launcher.get_parent())
	_target = weakref(target)
	velocity = p_velocity
	direction = p_direction.normalized()
	_life = Constants.LANCE_SHOT_LIFE
	name = "LanceShot"
	add_child(mesh)
	global_transform = Transform(launcher._basis_along(direction), tip)  # The mesh hangs back from the tip
	mesh.transform = Transform(Basis(), Vector3(0, -float(launcher.lance.length) * 0.5, 0))


func _physics_process(delta: float) -> void:
	_life -= delta
	var target = _target.get_ref()
	var launcher = _launcher.get_ref()
	if not (is_instance_valid(target) and target.is_inside_tree() and is_instance_valid(launcher)) or _life <= 0.0:
		_lost(launcher, target)
		return
	var tip: Vector3 = global_transform.origin
	var next: Vector3 = tip + velocity * delta
	if target is RigidBody:
		var relative: Vector3 = (velocity - target.linear_velocity) * delta
		var bounds: AABB = target.hull_bounds.grow(Constants.LANCE_TIP_MARGIN) if target.get("hull_bounds") is AABB else AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
		var to_local: Transform = target.global_transform.affine_inverse()
		var hit: Dictionary = launcher._segment_into_box(to_local.xform(next - relative), to_local.xform(next), bounds)
		if not hit.empty():
			launcher.strike(target, target.global_transform.xform(hit.point), target.global_transform.basis.xform(hit.normal).normalized(), -1.0, direction, velocity)
			queue_free()
			return
	else:
		var exclude: Array = [_shooter.get_ref()] if is_instance_valid(_shooter.get_ref()) else []
		var ray: Dictionary = get_world().direct_space_state.intersect_ray(tip, next, exclude, Constants.SHOT_BLOCK_MASK)
		if not ray.empty():
			if ray.collider == target:
				launcher.strike_rock(target, ray.position, ray.normal, -1.0, direction, velocity)
			else:
				var surface: Vector3 = ray.collider.linear_velocity if ray.collider is RigidBody else Vector3.ZERO
				launcher.drop_lance(ray.position, velocity, ray.normal, surface)
				launcher.emit_signal("glanced", target, "missed")
			queue_free()
			return
	global_transform.origin = next


func _lost(launcher, target) -> void:
	if is_instance_valid(launcher):
		launcher.drop_lance(global_transform.origin, velocity)
		launcher.emit_signal("glanced", target, "missed")
	queue_free()
