# Projectile: a round in flight (a missile, a cannon shell), moved by hand rather than by the
# physics. It meets a ship when its path this step, relative to that ship, passes within
# Constants.PROJECTILE_FUSE_MARGIN of the ship's hull box (as a lance tip does: closing speeds of
# hundreds of m/s cover metres a step, more than a thin hull is deep); a rock in the way (a ray along
# the path) stops it. Either way it bursts; past its flight time it burns out harmlessly.
# Subclasses steer (_steer) and choose the burst (_burst_effect). Added to the agent container.

extends Spatial

const LanceController = preload("res://src/core/agents/components/lance_controller.gd")

signal hit(projectile, body, damage)  # body: the ship or rock it met
signal expired(projectile)

var shooter: Spatial = null
var target: Spatial = null
var damage: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var flight_time: float = 5.0  # s it flies before it burns out
var age: float = 0.0
var done: bool = false


func launch(p_shooter: Spatial, p_target: Spatial, position: Vector3, p_velocity: Vector3, p_damage: float, p_flight_time: float) -> void:
	shooter = p_shooter
	target = p_target
	velocity = p_velocity
	damage = p_damage
	flight_time = p_flight_time
	var holder: Node = GlobalRefs.agent_container if is_instance_valid(GlobalRefs.agent_container) else p_shooter.get_parent()
	holder.add_child(self)
	global_transform = Transform(_basis_along(velocity if velocity.length_squared() > 0.01 else -p_shooter.global_transform.basis.z), position)


func _physics_process(delta: float) -> void:
	if done:
		return
	age += delta
	if age >= flight_time:
		_finish(null)
		emit_signal("expired", self)
		return
	_steer(delta)
	if done:
		return  # Steering ended it (a missile bursting on a decoy)
	var from: Vector3 = global_transform.origin
	var to: Vector3 = from + velocity * delta
	var met: Dictionary = _first_ship_on(from, to, delta)
	var rock: Dictionary = _first_rock_on(from, to)
	if not rock.empty() and (met.empty() or from.distance_to(rock.position) < from.distance_to(met.point)):
		global_transform.origin = rock.position
		_finish(rock.collider)
		emit_signal("hit", self, rock.collider, 0.0)
		return
	if not met.empty():
		global_transform.origin = met.point
		_strike(met.body, met.point)
		return
	global_transform = Transform(_basis_along(velocity) if velocity.length_squared() > 0.01 else global_transform.basis, to)


# How it flies: a shell keeps its velocity; a missile turns and burns.
func _steer(_delta: float) -> void:
	pass


# The first live ship (not its shooter) whose hull box its path this step, relative to that ship,
# meets: {"body", "point"} (world), or {}.
func _first_ship_on(from: Vector3, to: Vector3, delta: float) -> Dictionary:
	var best: Dictionary = {}
	var best_t: float = INF
	var step: float = from.distance_to(to)
	for body in get_tree().get_nodes_in_group("agent_body"):
		if body == shooter or not body is RigidBody or body.get("is_wreck") != false or body.get("is_docked"):
			continue
		var radius: float = body.get_apparent_radius() if body.has_method("get_apparent_radius") else 10.0
		if from.distance_to(body.global_transform.origin) > radius + step + body.linear_velocity.length() * delta + Constants.PROJECTILE_FUSE_MARGIN:
			continue
		var to_local: Transform = body.global_transform.affine_inverse()
		var shift: Vector3 = body.linear_velocity * delta  # Its own motion this step: the path relative to it
		var entry: Dictionary = LanceController._segment_into_box(to_local.xform(from), to_local.xform(to - shift), body.hull_bounds.grow(Constants.PROJECTILE_FUSE_MARGIN))
		if entry.empty():
			continue
		var point: Vector3 = body.global_transform.xform(entry.point)
		var t: float = from.distance_squared_to(point)
		if t < best_t:
			best_t = t
			best = {"body": body, "point": point}
	return best


func _first_rock_on(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree() or from.distance_squared_to(to) < 0.0001:
		return {}
	var hit: Dictionary = get_world().direct_space_state.intersect_ray(from, to, [], Constants.SHOT_BLOCK_MASK)
	if hit.empty() or not (hit.collider is Node and hit.collider.is_in_group("asteroid")):
		return {}
	return hit


func _strike(body: Spatial, point: Vector3) -> void:
	var from: Vector3 = point - velocity.normalized() * 5.0
	if body.has_method("register_hit"):
		body.register_hit(from, damage, point)
	if body.has_method("apply_damage"):
		body.apply_damage(damage, shooter if is_instance_valid(shooter) else null)
	_finish(body)
	emit_signal("hit", self, body, damage)


func _finish(body) -> void:
	done = true
	_burst_effect(body)
	queue_free()


func _burst_effect(_body) -> void:
	pass


static func _basis_along(direction: Vector3) -> Basis:
	var forward: Vector3 = direction.normalized()
	var up: Vector3 = Vector3.UP if abs(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return Transform().looking_at(forward, up).basis
