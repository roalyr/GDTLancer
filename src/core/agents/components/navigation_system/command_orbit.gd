# Navigation command: orbit a (possibly moving) target at the distance the command was given at
# (cmd.distance; at least Constants.NAV_CLOSE_ORBIT_DISTANCE_FACTOR times the target's size), for
# as long as the command stands. The ship keeps pace with the target and circles it in a fixed
# plane (set by its motion when the command starts), steering back toward the orbit radius when
# pushed off it, whichever way the target goes. Orbit speed is a share of top speed, less on tight
# orbits, where the turn would take more thrust than the ship has.

extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return
	if delta <= 0.0:
		return

	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	if not is_instance_valid(target_node):
		_nav_sys.set_command_stopping()
		return

	var radial: Vector3 = _agent_body.global_transform.origin - target_node.global_transform.origin
	var current_radius: float = max(radial.length(), 0.01)
	var radial_dir: Vector3 = radial / current_radius
	var target_velocity = target_node.get("linear_velocity")
	if not target_velocity is Vector3:
		target_velocity = Vector3.ZERO  # Stations, rocks
	var relative_velocity: Vector3 = _movement_system.get_velocity() - target_velocity

	var radius: float = get_orbit_radius(cmd, current_radius, _nav_sys._get_target_effective_size(target_node))
	var normal: Vector3 = cmd.get("normal", Vector3.ZERO)
	if normal == Vector3.ZERO or abs(normal.dot(radial_dir)) > 0.95:
		normal = pick_orbit_normal(radial_dir, relative_velocity, cmd.get("clockwise", false))
		cmd["normal"] = normal
	var tangent_dir: Vector3 = normal.cross(radial_dir).normalized()

	var mass: float = max(_agent_body.mass, 0.001)
	var top_speed: float = _movement_system.linear_thrust / (mass * Constants.LINEAR_DRAG)
	var desired: Vector3 = get_orbit_velocity(radial_dir, tangent_dir, current_radius, radius, top_speed, _movement_system.linear_thrust / mass)
	_movement_system.request_rotation_to_pid(desired.normalized(), delta)
	_movement_system.request_velocity_pid(target_velocity + desired, delta)


# The radius to hold: the distance at the command, never closer than the target's safe distance.
static func get_orbit_radius(cmd: Dictionary, current_radius: float, target_size: float) -> float:
	return max(float(cmd.get("distance", current_radius)), target_size * Constants.NAV_CLOSE_ORBIT_DISTANCE_FACTOR)


# Velocity relative to the target: along the orbit, plus back toward the orbit radius if off it.
# Circling at speed v takes v^2 / r of acceleration; at most half of what the ship has goes to that.
static func get_orbit_velocity(radial_dir: Vector3, tangent_dir: Vector3, current_radius: float, radius: float, top_speed: float, acceleration: float) -> Vector3:
	var orbit_speed: float = min(top_speed * Constants.NAV_ORBIT_SPEED_SHARE, sqrt(acceleration * 0.5 * radius))
	var max_radial: float = top_speed * Constants.NAV_ORBIT_MAX_RADIAL_SHARE
	var radial_speed: float = clamp((radius - current_radius) * Constants.NAV_ORBIT_RADIAL_GAIN, -max_radial, max_radial)
	return tangent_dir * orbit_speed + radial_dir * radial_speed


# The plane to circle in: the one the ship already moves in around the target, else sideways
# (clockwise or not, seen from above).
static func pick_orbit_normal(radial_dir: Vector3, relative_velocity: Vector3, clockwise: bool) -> Vector3:
	var sideways: Vector3 = relative_velocity - radial_dir * relative_velocity.dot(radial_dir)
	if sideways.length() < 1.0:
		sideways = radial_dir.cross(Vector3.UP) if clockwise else Vector3.UP.cross(radial_dir)
		if sideways.length_squared() < 0.01:
			sideways = radial_dir.cross(Vector3.FORWARD)
	return radial_dir.cross(sideways).normalized()
