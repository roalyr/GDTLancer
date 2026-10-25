# Missile: a guided Projectile. It leaves its launcher toward the target and burns at full thrust
# (accel m/s^2 up to top_speed), steering for where the target will be when it gets there (lead
# pursuit) but turning at most turn_rate rad/s: a ship crossing fast enough, near enough, makes it
# overshoot, and it has to come round again before its fuel (flight_time) runs out. The warhead
# bursts as a small explosion. The plume is the ships' own engine exhaust (EngineExhaustSet).

extends "res://src/core/agents/components/projectile.gd"

const EngineExhaustScene = preload("res://scenes/prefabs/effects/engine_exhaust.tscn")
const EngineExhaustSet = preload("res://src/core/agents/effects/engine_exhaust_set.gd")
const WreckExplosionScene = preload("res://scenes/prefabs/effects/wreck_explosion.tscn")

var top_speed: float = 300.0  # m/s (relative to where it was launched from)
var accel: float = 150.0  # m/s^2
var turn_rate: float = 1.5  # rad/s
var size: float = 1.0  # Model scale: 1 for a missile of Constants.LAW_MISSILE_REF_MASS
var linear_velocity: Vector3 = Vector3.ZERO  # What the exhaust reads (it draws ships' engines)
var is_wreck: bool = false
var _launch_velocity: Vector3 = Vector3.ZERO  # The launcher's: speeds count from it


func setup(stats: Dictionary) -> void:
	top_speed = float(stats.get("projectile_speed", top_speed))
	accel = float(stats.get("projectile_accel", accel))
	turn_rate = float(stats.get("turn_rate", turn_rate))
	size = pow(float(stats.get("round_mass", Constants.LAW_MISSILE_REF_MASS)) / Constants.LAW_MISSILE_REF_MASS, 1.0 / 3.0)


func _ready() -> void:
	_launch_velocity = shooter.linear_velocity if is_instance_valid(shooter) and shooter is RigidBody else Vector3.ZERO
	linear_velocity = velocity
	var body := MeshInstance.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = Constants.MISSILE_MODEL_RADIUS * 0.6
	mesh.bottom_radius = Constants.MISSILE_MODEL_RADIUS
	mesh.height = Constants.MISSILE_MODEL_LENGTH
	mesh.radial_segments = 8
	mesh.rings = 1
	var material := SpatialMaterial.new()
	material.albedo_color = Constants.MISSILE_MODEL_COLOR
	mesh.material = material
	body.mesh = mesh
	body.rotation_degrees = Vector3(-90, 0, 0)  # Cylinder along -Z, the top (narrow) forward
	body.scale = Vector3.ONE * size
	add_child(body)
	var engines := Spatial.new()
	engines.name = "Engines"
	engines.set_script(EngineExhaustSet)
	engines.transform.origin = Vector3(0, 0, Constants.MISSILE_MODEL_LENGTH * 0.5 * size)
	engines.scale = Vector3.ONE * size * Constants.MISSILE_EXHAUST_SCALE
	engines.add_child(EngineExhaustScene.instance())
	add_child(engines)


func get_engine_activity() -> float:
	return 1.0


func get_top_speed() -> float:
	return top_speed


func _steer(delta: float) -> void:
	var own: Vector3 = velocity - _launch_velocity
	var speed: float = min(top_speed, own.length() + accel * delta)
	var heading: Vector3 = own.normalized() if own.length_squared() > 0.01 else -global_transform.basis.z
	if is_instance_valid(target) and target.get("is_wreck") == false:
		var aim: Vector3 = intercept_direction(global_transform.origin, _launch_velocity, target.global_transform.origin, target.linear_velocity, max(speed, 1.0))
		var angle: float = heading.angle_to(aim)
		if angle > 0.0001:
			var axis: Vector3 = heading.cross(aim)
			if axis.length_squared() < 0.000001:
				axis = heading.cross(Vector3.UP if abs(heading.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
			heading = heading.rotated(axis.normalized(), min(angle, turn_rate * delta))
	velocity = _launch_velocity + heading * speed
	linear_velocity = velocity


# Direction to fly at `speed` (on top of `own_velocity`, the frame its speed counts from) to meet a point moving at
# `target_velocity`: where it will be when it gets there (falls back to straight at it).
static func intercept_direction(from: Vector3, own_velocity: Vector3, target_pos: Vector3, target_velocity: Vector3, speed: float) -> Vector3:
	var offset: Vector3 = target_pos - from
	var relative: Vector3 = target_velocity - own_velocity
	var a: float = relative.length_squared() - speed * speed
	var b: float = 2.0 * offset.dot(relative)
	var c: float = offset.length_squared()
	var t: float = -1.0
	if abs(a) < 0.0001:
		t = -c / b if abs(b) > 0.0001 else -1.0
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var root: float = sqrt(disc)
			var t1: float = (-b - root) / (2.0 * a)
			var t2: float = (-b + root) / (2.0 * a)
			t = min(t1, t2) if min(t1, t2) > 0.0 else max(t1, t2)
	var point: Vector3 = target_pos + relative * t if t > 0.0 else target_pos
	var direction: Vector3 = point - from
	return direction.normalized() if direction.length_squared() > 0.0001 else offset.normalized()


func _burst_effect(body) -> void:
	if body == null or not is_inside_tree():
		return  # Burnt out: it just goes dark
	var explosion = WreckExplosionScene.instance()
	explosion.radius = Constants.MISSILE_BLAST_RADIUS * size
	explosion.velocity = body.linear_velocity if body is RigidBody else Vector3.ZERO
	get_parent().add_child(explosion)
	explosion.global_transform.origin = global_transform.origin
