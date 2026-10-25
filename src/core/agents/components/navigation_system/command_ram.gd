# Navigation command: ram a (possibly moving) target with a kinetic lance. Charges straight at where
# the target will be (a lead point), at full thrust, never braking: an approach that does not slow
# down; it leans a little against its sideways slip relative to the target (NAV_RAM_DRIFT_GAIN), so
# it does not pass beside a target that moves. Closing in, it aims with a stiffer rotation PID
# (aim_gain): a near miss is a few degrees, where the usual autopilot eases in; from afar the usual
# one, so it settles onto its course without overshooting. A ram picks up from how the ship moves now, from any distance; only when it is too close to
# reach Constants.LAW_LANCE_MIN_SPEED of closing speed before it gets there (just past the target
# after a strike, a glance or a miss, or slow and near) does it run up: straight away, as a flee,
# until it has that room plus NAV_RAM_TURN_ROOM to turn in, then charges again.

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
	elif delta > 0.001:
		_target_velocity = (target_pos - _prev_target_pos) / delta
		_prev_target_pos = target_pos

	var offset: Vector3 = target_pos - _agent_body.global_transform.origin
	var distance: float = offset.length()
	var direction: Vector3 = offset / distance if distance > 0.01 else _movement_system.get_forward()
	var closing: float = (_movement_system.get_velocity() - _target_velocity).dot(direction)
	var room: float = run_up_distance(_agent_body.get_top_speed(), max(0.0, closing), _target_velocity.dot(direction))
	if cmd.running_up:
		if distance >= room + Constants.NAV_RAM_TURN_ROOM:
			cmd.running_up = false
	elif closing < Constants.LAW_LANCE_MIN_SPEED and distance < room + Constants.NAV_RAM_TURN_ROOM * 0.5:
		cmd.running_up = true  # Too close to build strike speed (just past it, or slow): out first

	var heading: Vector3
	if cmd.running_up:
		heading = -direction  # Straight away, as a flee
	else:
		var lead_time: float = min(distance / max(closing, Constants.NAV_RAM_MIN_LEAD_SPEED), Constants.NAV_RAM_MAX_LEAD_TIME)
		var lead: Vector3 = (target_pos + _target_velocity * lead_time - _agent_body.global_transform.origin).normalized()
		var relative: Vector3 = _movement_system.get_velocity() - _target_velocity
		var drift: Vector3 = relative - direction * relative.dot(direction)  # Sideways slip relative to the target: it would miss by this
		heading = (lead - drift / max(relative.length(), Constants.NAV_RAM_MIN_LEAD_SPEED) * Constants.NAV_RAM_DRIFT_GAIN).normalized()
	_movement_system.request_rotation_to_pid(heading, delta, 1.0 if cmd.running_up else aim_gain(distance))
	if _movement_system.get_forward().dot(heading) > Constants.NAV_RAM_THRUST_ALIGNMENT:
		_movement_system.request_thrust_forward()


# Rotation PID gain at `distance` m from the target: 1 from NAV_RAM_PID_GAIN_RANGE out, rising
# toward NAV_RAM_PID_GAIN as it closes, most of it in the last stretch (NAV_RAM_PID_GAIN_EXP).
static func aim_gain(distance: float) -> float:
	var near: float = 1.0 - clamp(distance / Constants.NAV_RAM_PID_GAIN_RANGE, 0.0, 1.0)
	return 1.0 + (Constants.NAV_RAM_PID_GAIN - 1.0) * pow(near, Constants.NAV_RAM_PID_GAIN_EXP)


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
