# Navigation command: a pass at a (possibly moving) target with a kinetic lance. Charges at where
# the target will be (a lead point), at full thrust, never braking: an approach that does not slow
# down; it leans a little against its sideways slip relative to the target (NAV_RAM_DRIFT_GAIN). At a
# ship it aims to pass beside it, NAV_RAM_PASS_CLEARANCE m clear of its hull, on the side it already
# slips toward: the lance is thrown at the ship on the way (LanceController, within
# LANCE_RELEASE_RANGE) and the hulls never meet. A wreck or an ore chunk is rammed head-on (a
# shove: lances are not thrown at them). From afar it comes in at a ship NAV_RAM_WEAVE_ANGLE off the
# line, toward its passing side, straightening between NAV_RAM_WEAVE_FULL and NAV_RAM_WEAVE_NONE: a
# ship flying straight at a turret is the easiest thing it can hit. The angle narrows as its closing
# speed falls toward NAV_RAM_WEAVE_MIN_CLOSING (straight in below it): a target backing away or
# circling at range is not lost. A rock: it closes to NAV_RAM_ROCK_STANDOFF off the surface
# and holds there, facing it, to throw from. In the last metres it aims with a stiffer rotation
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

	if not target_node is RigidBody:
		cmd.running_up = false
		_hold_off_rock(target_node, delta)
		return
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
		cmd["side"] = Vector3.ZERO  # The next pass picks its side afresh
	if not cmd.running_up:
		cmd.run_up_time = 0.0
		if not behind:
			cmd.faced = true  # Only a charge that has turned to face the target can pass it

	var heading: Vector3
	if cmd.running_up:
		heading = -direction  # Straight away, as a flee
	else:
		var aim_pos: Vector3 = target_pos
		var side: Vector3 = Vector3.ZERO
		if target_node.get("is_wreck") == false:  # A ship: pass beside it
			side = _pass_side(cmd, direction)
			aim_pos = target_pos + side * (_agent_body.get_apparent_radius() + _nav_sys._get_target_effective_size(target_node) + Constants.NAV_RAM_PASS_CLEARANCE)
		var aim_offset: Vector3 = aim_pos - _agent_body.global_transform.origin
		var aim_direction: Vector3 = aim_offset.normalized() if aim_offset.length() > 0.01 else direction
		var lead_time: float = min(distance / max(closing, Constants.NAV_RAM_MIN_LEAD_SPEED), Constants.NAV_RAM_MAX_LEAD_TIME)
		var lead: Vector3 = (aim_pos + _target_velocity * lead_time - _agent_body.global_transform.origin).normalized()
		var relative: Vector3 = _movement_system.get_velocity() - _target_velocity
		var drift: Vector3 = relative - aim_direction * relative.dot(aim_direction)  # Sideways slip off the pass line: it would miss it by this
		var weave: float = weave_share(distance) if side != Vector3.ZERO else 0.0
		heading = (lead - drift / max(relative.length(), Constants.NAV_RAM_MIN_LEAD_SPEED) * Constants.NAV_RAM_DRIFT_GAIN * (1.0 - weave)).normalized()
		var turn_axis: Vector3 = heading.cross(side)
		if weave > 0.0 and turn_axis.length_squared() > 0.000001:
			var wanted: float = clamp(closing / Constants.NAV_RAM_WEAVE_MIN_CLOSING - 1.0, 0.0, 1.0)  # By how fast it closes now
			cmd["weave"] = lerp(float(cmd.get("weave", 1.0)), wanted, min(1.0, delta * 2.0))  # Eased: no flutter
			heading = heading.rotated(turn_axis.normalized(), deg2rad(Constants.NAV_RAM_WEAVE_ANGLE) * weave * cmd.weave)  # Toward its passing side
	_movement_system.request_rotation_to_pid(heading, delta, 1.0 if cmd.running_up else aim_gain(distance))
	if _movement_system.get_forward().dot(heading) > Constants.NAV_RAM_THRUST_ALIGNMENT:
		_movement_system.request_thrust_forward()


# Share of NAV_RAM_WEAVE_ANGLE a charge at `distance` m comes in at: 1 from NAV_RAM_WEAVE_FULL out,
# 0 from NAV_RAM_WEAVE_NONE in (smoothstep between).
static func weave_share(distance: float) -> float:
	var far: float = clamp((distance - Constants.NAV_RAM_WEAVE_NONE) / (Constants.NAV_RAM_WEAVE_FULL - Constants.NAV_RAM_WEAVE_NONE), 0.0, 1.0)
	return far * far * (3.0 - 2.0 * far)


# The side it passes a ship on (unit, across the line to it): the way it already slips relative to
# the target, kept for the pass.
func _pass_side(cmd: Dictionary, direction: Vector3) -> Vector3:
	var side: Vector3 = cmd.get("side", Vector3.ZERO)
	side -= direction * side.dot(direction)
	if side.length_squared() < 0.01:
		var relative: Vector3 = _movement_system.get_velocity() - _target_velocity
		side = relative - direction * relative.dot(direction)
		if side.length_squared() < 1.0:
			var right: Vector3 = _agent_body.global_transform.basis.x
			side = right - direction * right.dot(direction)
	side = side.normalized()
	cmd["side"] = side
	return side


# A rock: closes until the lance's tip is NAV_RAM_ROCK_STANDOFF off its surface and holds there,
# nose on (the lance is thrown from there; the throw alone is past strike speed).
func _hold_off_rock(rock: Spatial, delta: float) -> void:
	var offset: Vector3 = rock.global_transform.origin - _agent_body.global_transform.origin
	var distance: float = offset.length()
	if distance < 0.01:
		return
	var direction: Vector3 = offset / distance
	var radius: float = rock.get_apparent_radius() if rock.has_method("get_apparent_radius") else 100.0
	var lance = _agent_body.get_lance() if _agent_body.has_method("get_lance") else null
	var reach: float = lance.get_reach() if lance != null else 0.0  # The lance is thrown from its tip
	var gap: float = distance - radius - Constants.NAV_RAM_ROCK_STANDOFF - reach
	var speed: float = clamp(gap * Constants.NAV_RAM_ROCK_SPEED_GAIN, -Constants.NAV_RAM_ROCK_MAX_SPEED, Constants.NAV_RAM_ROCK_MAX_SPEED)
	_movement_system.request_rotation_to_pid(direction, delta)
	_movement_system.request_velocity_pid(direction * speed, delta)


# Rotation PID gain at `distance` m from the target: 1 from NAV_RAM_PID_GAIN_FROM out, easing up to
# NAV_RAM_PID_GAIN at NAV_RAM_PID_GAIN_FULL (turn-arounds at 200-500 m keep the usual, calm aim).
static func aim_gain(distance: float) -> float:
	var near: float = clamp((Constants.NAV_RAM_PID_GAIN_FROM - distance) / (Constants.NAV_RAM_PID_GAIN_FROM - Constants.NAV_RAM_PID_GAIN_FULL), 0.0, 1.0)
	return 1.0 + (Constants.NAV_RAM_PID_GAIN - 1.0) * near * near * (3.0 - 2.0 * near)  # Smoothstep


# m a ship of `top_speed` needs to reach strike speed (LAW_LANCE_MIN_SPEED less the throw,
# LANCE_LAUNCH_SPEED) of closing speed on a target moving `target_away` m/s away from it, from
# `closing` now (thrust against drag: v approaches top speed as 1 - e^(-LINEAR_DRAG t)). INF if it
# never can.
static func run_up_distance(top_speed: float, closing: float, target_away: float) -> float:
	var needed: float = max(0.0, Constants.LAW_LANCE_MIN_SPEED - Constants.LANCE_LAUNCH_SPEED) + max(0.0, target_away)
	var own_now: float = closing + max(0.0, target_away)
	if own_now >= needed:
		return 0.0
	if top_speed <= needed:
		return INF
	var k: float = Constants.LINEAR_DRAG
	var t: float = -log((top_speed - needed) / (top_speed - own_now)) / k
	return top_speed * t - (top_speed - own_now) * (1.0 - exp(-k * t)) / k
