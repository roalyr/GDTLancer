# Navigation command: ram a (possibly moving) target with a kinetic lance. Charges straight at where
# the target will be (a lead point), at full thrust, never braking: an approach that does not slow
# down; it leans a little against its sideways slip relative to the target (NAV_RAM_DRIFT_GAIN), so
# it does not pass beside a target that moves. In the last metres it aims with a stiffer rotation
# PID (aim_gain): a near miss is a few degrees, where the usual autopilot eases in.
# A ram picks up from how the ship moves now, from any distance: it runs up first only if it starts
# too close to reach Constants.LAW_LANCE_MIN_SPEED of closing speed. Charging, it runs up only once
# past the target (a strike, a glance or a miss: behind it and opening within NAV_RAM_PASS_DISTANCE)
# or stalled against it; running up (straight away, as a flee) it goes until it has the room to
# build that speed from rest on a still target plus NAV_RAM_TURN_ROOM (at most NAV_RAM_MAX_RUN_UP m,
# NAV_RAM_MAX_RUN_UP_TIME s: a target that follows it is charged anyway), then charges again. A target
# running away is chased, never run from. Each phase holds until its event, so
# the ship does not dither between them.

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
		cmd["started"] = false
		cmd["run_up_time"] = 0.0
		cmd["faced"] = false
	elif delta > 0.001:
		_target_velocity = (target_pos - _prev_target_pos) / delta
		_prev_target_pos = target_pos

	var offset: Vector3 = target_pos - _agent_body.global_transform.origin
	var distance: float = offset.length()
	var direction: Vector3 = offset / distance if distance > 0.01 else _movement_system.get_forward()
	var closing: float = (_movement_system.get_velocity() - _target_velocity).dot(direction)
	# Run-up length: the room to build strike speed from rest on a still target, plus the turn, at
	# most NAV_RAM_MAX_RUN_UP (a target running away is chased, never run from).
	var run_up: float = min(run_up_distance(_agent_body.get_top_speed(), 0.0, 0.0) + Constants.NAV_RAM_TURN_ROOM, Constants.NAV_RAM_MAX_RUN_UP)
	var behind: bool = _movement_system.get_forward().dot(direction) < 0.0
	# Hysteresis: each phase holds until a clear event, so the ship never dithers between the two.
	if not cmd.started:  # Once, as the ram starts: from how it moves now, can it charge?
		cmd.started = true
		cmd.running_up = closing < Constants.LAW_LANCE_MIN_SPEED and distance < run_up - Constants.NAV_RAM_TURN_ROOM
	elif cmd.running_up:
		cmd.run_up_time += delta
		if distance >= run_up or cmd.run_up_time >= Constants.NAV_RAM_MAX_RUN_UP_TIME:
			cmd.running_up = false  # Room for a charge, or a target that keeps up: turn and charge anyway
	elif cmd.faced and distance < Constants.NAV_RAM_PASS_DISTANCE and ((closing < 0.0 and behind) or (closing < Constants.LAW_LANCE_MIN_SPEED and distance < Constants.NAV_RAM_STALL_DISTANCE)):
		cmd.running_up = true  # Just past it (behind and opening: a strike, a glance or a miss), or stalled against it
		cmd.faced = false
	if not cmd.running_up:
		cmd.run_up_time = 0.0
		if not behind:
			cmd.faced = true  # Only a charge that has turned to face the target can pass it

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


# Rotation PID gain at `distance` m from the target: 1 from NAV_RAM_PID_GAIN_FROM out, easing up to
# NAV_RAM_PID_GAIN at NAV_RAM_PID_GAIN_FULL (turn-arounds at 100-500 m keep the usual, calm aim).
static func aim_gain(distance: float) -> float:
	var near: float = clamp((Constants.NAV_RAM_PID_GAIN_FROM - distance) / (Constants.NAV_RAM_PID_GAIN_FROM - Constants.NAV_RAM_PID_GAIN_FULL), 0.0, 1.0)
	return 1.0 + (Constants.NAV_RAM_PID_GAIN - 1.0) * near * near * (3.0 - 2.0 * near)  # Smoothstep


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
