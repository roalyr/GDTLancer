# Navigation command: passes at a (possibly moving) target with a kinetic lance. At a ship, in three
# phases, each held until its event so the ship never dithers between them:
# - Approach: the nose on the lead (where the target will be when it gets there: intercept_time, at
#   its own speed or NAV_CHARGE_MIN_LEAD_SPEED, whichever is more, at most NAV_CHARGE_MAX_LEAD_TIME
#   ahead); within the target's weapon reach (NAV_CHARGE_STRAFE_REACH times it) it thrusts
#   NAV_CHARGE_STRAFE_ANGLE off that line toward its passing side, crossing the target's guns while
#   it closes (a ship flying straight at a turret is the easiest thing it can hit); outside it, straight in.
# - Strike: from strike_range() in (NAV_CHARGE_STRIKE_RANGE times the lance's release range, plus both
#   hulls; the strafe eases out over NAV_CHARGE_STRAFE_EASE m before it) it stops strafing and comes in
#   head-on at the lead, at full thrust, aiming to pass NAV_CHARGE_PASS_CLEARANCE m beside the hull
#   on the side it slips toward; the thrust, not the nose, leans against its sideways slip
#   (NAV_CHARGE_DRIFT_GAIN), so the nose stays on the lead. The lance is thrown on the way
#   (LanceController, within LANCE_RELEASE_RANGE) and the hulls never meet. In the last metres it aims
#   with a stiffer rotation PID (aim_gain).
# - Break-off ("running_up"): once its lance is thrown, or it is past the target (opening within
#   NAV_CHARGE_PASS_DISTANCE: a glance or a miss), or stalled against it, it flies out on a spiral
#   (NAV_CHARGE_BREAK_ANGLE off straight away, toward its passing side), its nose kept on the target,
#   until it has the room to charge again (reengage_range(): to build strike speed from rest plus
#   NAV_CHARGE_TURN_ROOM, at least past the strafe band; at most NAV_CHARGE_MAX_RUN_UP m and
#   NAV_CHARGE_MAX_RUN_UP_TIME s: a target that keeps up with it is charged anyway). A charge starting
#   too close to reach strike speed breaks off first.
# Thrust is the same any way (MovementSystem), so it strafes and backs off with its nose where it
# wants it. A wreck or an ore chunk is charged at head-on, no strafe (a shove: lances are not thrown
# at them). A rock: it closes to NAV_CHARGE_ROCK_STANDOFF off the surface and holds there, facing
# it, to throw from. A target running away is chased, never run from.

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
	var is_ship: bool = target_node.get("is_wreck") == false
	var strike_at: float = strike_range(target_node)
	var nails: int = _agent_body.get_lance_nails() if _agent_body.has_method("get_lance_nails") else 0
	if not cmd.started:  # Once, as the charge starts: from how it moves now, can it charge?
		cmd.started = true
		cmd["nails"] = nails
		cmd.running_up = closing < Constants.LAW_LANCE_MIN_SPEED and distance < reengage_range(target_node) - Constants.NAV_CHARGE_TURN_ROOM - Constants.NAV_CHARGE_STRAFE_EASE
	elif cmd.running_up:
		cmd.run_up_time += delta
		if distance >= reengage_range(target_node) or cmd.run_up_time >= Constants.NAV_CHARGE_MAX_RUN_UP_TIME:
			cmd.running_up = false  # Room for a charge, or a target that keeps up: in again
	else:
		if distance <= strike_at:
			cmd.faced = true  # In its strike: from here a pass or a throw ends it
		var thrown: bool = nails < int(cmd.get("nails", nails))
		var passed: bool = cmd.faced and distance < Constants.NAV_CHARGE_PASS_DISTANCE and closing < 0.0
		var stalled: bool = closing < Constants.LAW_LANCE_MIN_SPEED and distance < Constants.NAV_CHARGE_STALL_DISTANCE
		if thrown or passed or stalled:
			cmd.running_up = true
			cmd.faced = false
	if not cmd.running_up:
		cmd.run_up_time = 0.0
	cmd.nails = nails

	var side: Vector3 = _pass_side(cmd, direction) if is_ship else Vector3.ZERO
	var nose: Vector3
	var thrust: Vector3
	if cmd.running_up:
		# Out on a spiral, watching it: back and across, toward its passing side.
		nose = direction
		var out: Vector3 = -direction
		if side != Vector3.ZERO:
			var angle: float = deg2rad(Constants.NAV_CHARGE_BREAK_ANGLE)
			out = (out * cos(angle) + side * sin(angle)).normalized()
		thrust = out
	else:
		var aim_pos: Vector3 = target_pos
		if is_ship:  # Pass beside it
			aim_pos = target_pos + side * (_agent_body.get_apparent_radius() + _nav_sys._get_target_effective_size(target_node) + Constants.NAV_CHARGE_PASS_CLEARANCE)
		var aim_offset: Vector3 = aim_pos - _agent_body.global_transform.origin
		var aim_direction: Vector3 = aim_offset.normalized() if aim_offset.length() > 0.01 else direction
		var speed: float = max(_movement_system.get_velocity().length(), Constants.NAV_CHARGE_MIN_LEAD_SPEED)
		var lead_time: float = intercept_time(aim_offset, _target_velocity, speed)
		if lead_time < 0.0:
			lead_time = distance / max(closing, Constants.NAV_CHARGE_MIN_LEAD_SPEED)  # It cannot catch it at that speed: lead as it closes
		lead_time = min(lead_time, Constants.NAV_CHARGE_MAX_LEAD_TIME)
		var lead: Vector3 = (aim_pos + _target_velocity * lead_time - _agent_body.global_transform.origin).normalized()
		nose = lead
		var strafe: float = strafe_share(distance, strike_at, _agent_body.weapon_reach_of(target_node)) if is_ship else 0.0
		cmd["strafe"] = strafe
		var across: Vector3 = side - direction * side.dot(direction)
		if strafe > 0.0 and across.length_squared() > 0.0001:  # Approach under its guns: across them
			# Steers its own velocity, not its thrust: top speed, that angle off the line to the target
			# (a thrust off a lead already off the line, at a target circling it, only circles with it).
			var angle: float = deg2rad(Constants.NAV_CHARGE_STRAFE_ANGLE) * strafe
			var wanted: Vector3 = (direction * cos(angle) + across.normalized() * sin(angle)) * _agent_body.get_top_speed()
			thrust = wanted - _movement_system.get_velocity()
			if thrust.length_squared() < 1.0:  # On it: hold it against the drag
				thrust = wanted
		else:  # Head-on: lean against the slip with the thrust
			var relative: Vector3 = _movement_system.get_velocity() - _target_velocity
			var drift: Vector3 = relative - aim_direction * relative.dot(aim_direction)
			var gain: float = Constants.NAV_CHARGE_STRIKE_DRIFT_GAIN if is_ship else Constants.NAV_CHARGE_DRIFT_GAIN
			thrust = (lead - drift / max(relative.length(), Constants.NAV_CHARGE_MIN_LEAD_SPEED) * gain).normalized()
	_movement_system.request_rotation_to_pid(nose, delta, 1.0 if cmd.running_up else aim_gain(distance))
	_movement_system.request_thrust_direction(thrust)



# m from the target's centre where the strafe stops and the head-on strike begins:
# NAV_CHARGE_STRIKE_RANGE times the lance's release range, plus both hulls.
func strike_range(target) -> float:
	return Constants.NAV_CHARGE_STRIKE_RANGE * Constants.LANCE_RELEASE_RANGE + _agent_body.get_apparent_radius() + _nav_sys._get_target_effective_size(target)


# m out a break-off goes before it charges again: the room to build strike speed from rest plus the
# turn, at least past the strafe band, at most NAV_CHARGE_MAX_RUN_UP.
func reengage_range(target) -> float:
	var run_up: float = run_up_distance(_agent_body.get_top_speed(), 0.0, 0.0) + Constants.NAV_CHARGE_TURN_ROOM
	return min(max(run_up, strike_range(target) + Constants.NAV_CHARGE_STRAFE_EASE + Constants.NAV_CHARGE_TURN_ROOM), Constants.NAV_CHARGE_MAX_RUN_UP)


# Share of NAV_CHARGE_STRAFE_ANGLE an approach at `distance` m strafes at: none within `strike_at`,
# full from NAV_CHARGE_STRAFE_EASE m past it (smoothstep), and none outside the target's weapon
# `reach` times NAV_CHARGE_STRAFE_REACH (nothing to dodge: straight in).
static func strafe_share(distance: float, strike_at: float, reach: float) -> float:
	if reach <= 0.0 or distance > reach * Constants.NAV_CHARGE_STRAFE_REACH:
		return 0.0
	var share: float = clamp((distance - strike_at) / Constants.NAV_CHARGE_STRAFE_EASE, 0.0, 1.0)
	return share * share * (3.0 - 2.0 * share)


# s until a ship flying straight at `speed` meets a point `offset` away moving at `velocity` (the
# first time |offset + velocity t| = speed t); -1 if it never can.
static func intercept_time(offset: Vector3, velocity: Vector3, speed: float) -> float:
	var a: float = velocity.length_squared() - speed * speed
	var b: float = 2.0 * offset.dot(velocity)
	var c: float = offset.length_squared()
	if abs(a) < 0.0001:
		return -c / b if b < 0.0 else -1.0
	var disc: float = b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var root: float = sqrt(disc)
	var t1: float = (-b - root) / (2.0 * a)
	var t2: float = (-b + root) / (2.0 * a)
	var best: float = INF
	for t in [t1, t2]:
		if t > 0.0:
			best = min(best, t)
	return best if best < INF else -1.0


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


# A rock: closes until the lance's tip is NAV_CHARGE_ROCK_STANDOFF off its surface and holds there,
# nose on (the lance is thrown from there; the throw alone is past strike speed).
func _hold_off_rock(rock: Spatial, delta: float) -> void:
	var offset: Vector3 = rock.global_transform.origin - _agent_body.global_transform.origin
	var distance: float = offset.length()
	if distance < 0.01:
		return
	var direction: Vector3 = offset / distance
	var radius: float = rock.get_apparent_radius() if rock.has_method("get_apparent_radius") else 100.0
	var reach := 0.0  # The lance is thrown from its tip
	for lance in (_agent_body.get_lances() if _agent_body.has_method("get_lances") else []):
		reach = max(reach, lance.get_reach())
	var gap: float = distance - radius - Constants.NAV_CHARGE_ROCK_STANDOFF - reach
	var speed: float = clamp(gap * Constants.NAV_CHARGE_ROCK_SPEED_GAIN, -Constants.NAV_CHARGE_ROCK_MAX_SPEED, Constants.NAV_CHARGE_ROCK_MAX_SPEED)
	_movement_system.request_rotation_to_pid(direction, delta)
	_movement_system.request_velocity_pid(direction * speed, delta)


# Rotation PID gain at `distance` m from the target: 1 from NAV_CHARGE_PID_GAIN_FROM out, easing up to
# NAV_CHARGE_PID_GAIN at NAV_CHARGE_PID_GAIN_FULL (turn-arounds at 200-500 m keep the usual, calm aim).
static func aim_gain(distance: float) -> float:
	var near: float = clamp((Constants.NAV_CHARGE_PID_GAIN_FROM - distance) / (Constants.NAV_CHARGE_PID_GAIN_FROM - Constants.NAV_CHARGE_PID_GAIN_FULL), 0.0, 1.0)
	return 1.0 + (Constants.NAV_CHARGE_PID_GAIN - 1.0) * near * near * (3.0 - 2.0 * near)  # Smoothstep


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
