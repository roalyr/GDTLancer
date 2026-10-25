# Navigation command: ram a (possibly moving) target with a kinetic lance. Charges on a collision
# course at full thrust, never braking: it thrusts against its sideways drift relative to the
# target (NAV_RAM_STEER_GAIN), so the line to the target stops turning and the lance meets it
# however the target moves (proportional navigation). From afar it comes in at an angle
# (NAV_RAM_WEAVE: a straight charge is the easiest thing for a laser to track) and turns square in
# for the last NAV_RAM_WEAVE_END m. Once past the target (a strike, a glance or a miss), or when its
# own speed is short of Constants.LAW_LANCE_MIN_SPEED with too little room left to build it, it
# runs up: peels off away and to one side until it has the room to build that speed (plus
# NAV_RAM_TURN_ROOM to turn in), then charges again.

extends Node

var _nav_sys: Node
var _agent_body: RigidBody
var _movement_system: Node

var _prev_target_pos: Vector3 = Vector3.ZERO
var _target_velocity: Vector3 = Vector3.ZERO


func initialize(nav_system):
	_nav_sys = nav_system
	_agent_body = nav_system.agent_body
	_movement_system = nav_system.movement_system


func execute(delta: float):
	if not is_instance_valid(_movement_system) or not is_instance_valid(_agent_body):
		return
	var cmd = _nav_sys._current_command
	var target_node = cmd.target_node
	if not is_instance_valid(target_node):
		_nav_sys.set_command_stopping()
		return
	var target_pos: Vector3 = target_node.global_transform.origin
	if cmd.get("is_new", true):
		_prev_target_pos = target_pos
		_target_velocity = Vector3.ZERO
		cmd["is_new"] = false
		cmd["running_up"] = false
		cmd["side"] = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	elif delta > 0.001:
		_target_velocity = (target_pos - _prev_target_pos) / delta
		_prev_target_pos = target_pos

	var offset: Vector3 = target_pos - _agent_body.global_transform.origin
	var distance: float = offset.length()
	var direction: Vector3 = offset / distance if distance > 0.01 else _movement_system.get_forward()
	var closing: float = (_movement_system.get_velocity() - _target_velocity).dot(direction)
	var own_speed: float = _movement_system.get_velocity().length()
	var room: float = run_up_distance(_agent_body.get_top_speed(), max(0.0, closing), _target_velocity.dot(direction))
	var side: Vector3 = (cmd.side - direction * cmd.side.dot(direction)).normalized()
	if cmd.running_up:
		if distance >= room + Constants.NAV_RAM_TURN_ROOM:
			cmd.running_up = false
			cmd.side = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	elif closing < 0.0 or (own_speed < Constants.LAW_LANCE_MIN_SPEED and distance < room):
		cmd.running_up = true  # Past it, or too slow with too little room

	var heading: Vector3
	if cmd.running_up:
		heading = (-direction + side * Constants.NAV_RAM_RUN_UP_SIDE).normalized()
	else:
		var relative: Vector3 = _movement_system.get_velocity() - _target_velocity
		var drift: Vector3 = relative - direction * relative.dot(direction)
		var weave: float = Constants.NAV_RAM_WEAVE * clamp((distance - Constants.NAV_RAM_WEAVE_END) / Constants.NAV_RAM_WEAVE_END, 0.0, 1.0)
		heading = (direction + side * weave - drift / max(own_speed, Constants.NAV_RAM_MIN_LEAD_SPEED) * Constants.NAV_RAM_STEER_GAIN).normalized()
	_movement_system.request_rotation_to_pid(heading, delta)
	if _movement_system.get_forward().dot(heading) > Constants.NAV_RAM_THRUST_ALIGNMENT:
		_movement_system.request_thrust_forward()


# m a ship of `top_speed` needs to reach LAW_LANCE_MIN_SPEED of closing speed on a target moving
# `target_away` m/s away from it, from `closing` now (thrust against drag: v approaches top speed
# as 1 - e^(-LINEAR_DRAG t)). INF if it never can.
static func run_up_distance(top_speed: float, closing: float, target_away: float) -> float:
	var needed: float = Constants.LAW_LANCE_MIN_SPEED + max(0.0, target_away)
	var own_now: float = closing + max(0.0, target_away)
	if own_now >= needed:
		return 0.0
	if top_speed <= needed:
		return INF
	var k: float = Constants.LINEAR_DRAG
	var t: float = -log((top_speed - needed) / (top_speed - own_now)) / k
	return top_speed * t - (top_speed - own_now) * (1.0 - exp(-k * t)) / k
