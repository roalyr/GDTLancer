# Handles the low-level execution of agent movement via forces and torques.
# Called by NavigationSystem. Parent must be RigidBody with custom_integrator = true.

extends Node

const Autolevel = preload("res://src/core/agents/components/autolevel.gd")

# --- Movement Capabilities (Set by AgentBody during initialize) ---
var linear_thrust: float = Constants.DEFAULT_LINEAR_THRUST
var angular_thrust: float = Constants.DEFAULT_ANGULAR_THRUST
var alignment_threshold_angle_deg: float = Constants.DEFAULT_ALIGNMENT_ANGLE_THRESHOLD
var _alignment_threshold_rad: float = deg2rad(alignment_threshold_angle_deg)

# --- Throttle Control (0.0 to 1.0) ---
var thrust_throttle: float = 1.0

# --- Accumulated Forces/Torques for Current Frame ---
# These are accumulated by commands and applied in _integrate_forces
var _heading_prev := Vector3.ZERO  # The heading asked for last step (_heading_turn)
var _heading_frame := -1
var _wanted_velocity = null  # The velocity asked for this step (request_velocity), or null; its force is worked out last
var _wanted_response: float = 0.25
var _accumulated_force := Vector3.ZERO
var _accumulated_torque := Vector3.ZERO
var _external_force := Vector3.ZERO  # From tethers, leaks and other bodies; not scaled by throttle
var _external_torque := Vector3.ZERO  # From forces acting off the centre of mass (leaks)
var last_thrust_fraction := 0.0  # Engine thrust used in the last physics step, 0..1 (drives signature)
var last_thrust_vector := Vector3.ZERO  # Its direction too (world space, length last_thrust_fraction): which nozzles burn

# --- Facing (a cannon's aim) ---
# While `facing` is set (NavigationSystem, from ToolController.cannon_facing), the nose turns to it
# and the course commands steer a heading instead: what they ask to face. Their thrust "forward"
# pushes along that heading (thrust is the same in every direction), and they are aligned once they
# ask for it. ZERO: the nose is the commands' again.
var facing := Vector3.ZERO
var _heading := Vector3.ZERO

# Reference to the parent AgentBody RigidBody
var agent_body: RigidBody = null

func _ready():
	agent_body = get_parent()
	if not agent_body is RigidBody:
		printerr("MovementSystem Error: Parent is not a RigidBody!")
		agent_body = null
		return
	
	# Enable custom integrator so we can apply drag and forces manually
	agent_body.custom_integrator = true


func initialize_movement_params(params: Dictionary):
	linear_thrust = params.get("linear_thrust", linear_thrust)
	angular_thrust = params.get("angular_thrust", angular_thrust)
	alignment_threshold_angle_deg = params.get(
		"alignment_threshold_angle_deg", alignment_threshold_angle_deg
	)
	_alignment_threshold_rad = deg2rad(alignment_threshold_angle_deg)
	
	# Set mass on the RigidBody if provided
	var mass = params.get("mass", Constants.DEFAULT_SHIP_MASS)
	if is_instance_valid(agent_body):
		agent_body.mass = mass
	
	# Reset PID states
	reset_pid_states()
	
	if Constants.VERBOSE_RUNTIME_LOGS:
		print(
			(
				"MovementSystem Initialized: LinearThrust=%.1f, AngularThrust=%.1f, Mass=%.1f, Align=%.1f"
				% [
					linear_thrust,
					angular_thrust,
					mass,
					alignment_threshold_angle_deg
				]
			)
		)


func reset_pid_states():
	pass  # The holds keep no state between steps ("How a ship is flown")


# Turns the nose to `facing` (after the command has run); nothing without one.
func apply_facing(delta: float) -> void:
	if facing == Vector3.ZERO:
		_heading = Vector3.ZERO
		return
	_rotate_pid(facing, delta, Constants.NAV_AIM_PID_GAIN)


# The way the course points: its heading while a cannon has the nose, the nose otherwise.
func _course_forward() -> Vector3:
	if facing != Vector3.ZERO and _heading != Vector3.ZERO:
		return _heading
	return -agent_body.global_transform.basis.z.normalized()


# --- Called by AgentBody in _integrate_forces ---
func integrate_forces(state: PhysicsDirectBodyState):
	if not is_instance_valid(agent_body):
		return
	
	# Apply global linear drag
	var linear_drag_force = -state.linear_velocity * Constants.LINEAR_DRAG * agent_body.mass
	state.add_central_force(linear_drag_force)
	
	# Apply global angular drag
	var angular_drag_torque = -state.angular_velocity * Constants.ANGULAR_DRAG * agent_body.mass
	state.add_torque(angular_drag_torque)
	
	# The velocity asked for (steered by the autopilot's avoidance since): its force, now
	if _wanted_velocity != null:
		_accumulated_force += _velocity_force(_wanted_velocity, _wanted_response, state.linear_velocity, state.step)
		_wanted_velocity = null
	# Apply accumulated forces from navigation commands (scaled by throttle)
	var engines: Vector3 = _accumulated_force * thrust_throttle
	state.add_central_force(engines + _external_force)
	state.add_torque(_accumulated_torque + _external_torque + _autolevel_torque())
	
	last_thrust_fraction = clamp(_accumulated_force.length() * thrust_throttle / max(thrust(), 0.001), 0.0, 1.0)
	last_thrust_vector = _accumulated_force.normalized() * last_thrust_fraction if last_thrust_fraction > 0.0 else Vector3.ZERO

	# Clear accumulated forces for next frame
	_accumulated_force = Vector3.ZERO
	_accumulated_torque = Vector3.ZERO
	_external_force = Vector3.ZERO
	_external_torque = Vector3.ZERO


# The player's autolevel (Settings "autolevel"): Autolevel.torque, a small roll towards level.
func _autolevel_torque() -> Vector3:
	if not (agent_body.has_method("is_player") and agent_body.is_player() and Settings.get_option("autolevel")):
		return Vector3.ZERO
	return Autolevel.torque(agent_body.global_transform.basis, agent_body.mass, angular_thrust)


# Force from outside the ship's own engines (e.g. a tether), applied on the next physics step.
func add_external_force(force: Vector3) -> void:
	_external_force += force


# A force acting at a world point: pushes the centre of mass and turns the ship about it.
func add_external_force_at(force: Vector3, world_point: Vector3) -> void:
	_external_force += force
	_external_torque += (world_point - agent_body.global_transform.origin).cross(force)


# --- Public Methods Called by NavigationSystem Commands ---


# Request thrust in a specific world direction (autopilot decides direction)
# The thrust asked for so far this step (commands add theirs before the autopilot's avoidance).
func get_requested_force() -> Vector3:
	if _wanted_velocity == null or not is_instance_valid(agent_body):
		return _accumulated_force
	return _accumulated_force + _velocity_force(_wanted_velocity, _wanted_response, agent_body.linear_velocity, _step())


func request_thrust_direction(direction: Vector3, magnitude_scale: float = 1.0):
	if not is_instance_valid(agent_body):
		return
	if direction.length_squared() < 0.001:
		return
	_accumulated_force += direction.normalized() * thrust() * clamp(magnitude_scale, 0.0, 1.0)


# Drops the part of the thrust asked for so far this step that points along `direction` (a planet
# the ship is up against: NavigationSystem), so it slides off rather than pressing on.
func cancel_thrust_toward(direction: Vector3) -> void:
	var into: float = _accumulated_force.dot(direction)
	if into > 0.0:
		_accumulated_force -= direction * into
	if _wanted_velocity != null and _wanted_velocity.dot(direction) > 0.0:  # Nor a velocity into it
		_wanted_velocity -= direction * _wanted_velocity.dot(direction)


# Request thrust along the ship's forward axis
func request_thrust_forward(magnitude_scale: float = 1.0):
	if not is_instance_valid(agent_body):
		return
	_accumulated_force += _course_forward() * thrust() * clamp(magnitude_scale, 0.0, 1.0)


# Request thrust along the ship's backward axis (rear thrusters)
func request_thrust_backward(magnitude_scale: float = 1.0):
	if not is_instance_valid(agent_body):
		return
	var backward = -_course_forward()
	_accumulated_force += backward * thrust() * clamp(magnitude_scale, 0.0, 1.0)


# --- How a ship is flown ---
# One physical model for every command, the player's and NPCs' alike. The engines push the same in
# every direction, up to linear_thrust (thrust_throttle scales it), and turn the ship about its centre
# of mass up to angular_thrust; drag (LINEAR_DRAG, ANGULAR_DRAG) slows both. A command asks for one of
# two things, and the force or torque that gets it is worked out from the body's own mass and inertia,
# so no hull flies differently for its shape:
# - a velocity (request_velocity): the force that takes the difference off over VELOCITY_RESPONSE
#   (never more than all of it in a step: no overshoot), plus what holds that velocity against drag;
# - a heading (request_rotation_to_pid): a spin toward it, as fast as the turn can still be braked
#   to rest on it (POINT_BRAKE_SHARE of the angular thrust), slower as it nears (POINT_GAIN), and the
#   torque that gets that spin over POINT_RESPONSE; a roll is let go of, as a stop's spin is.
# The autopilot steers the wanted velocity round obstacles (steer_velocity) before its force is
# worked out, so the hold flies round them instead of undoing the swerve. Stopping the spin (request_rotation_damping_pid)
#   asks for none, over SPIN_DAMP_TIME: the ship's inertia is felt.
# Braking needs no flip: a ship slows in place, its nose where it was.
const VELOCITY_RESPONSE = 0.25  # s over which a velocity's difference is taken off (full thrust until near)
const POINT_GAIN = 3.0  # 1/s: spin toward a heading per radian off it, near it
const POINT_BRAKE_SHARE = 0.2  # Of the angular thrust a turn counts on to stop on its heading: lower, slower and softer turns (about the old PID's)
const POINT_RESPONSE = 0.05  # s over which a wanted spin is reached (within the torque there is)
const HEADING_JUMP = 0.05  # rad: a heading moving more than this in a step jumped (a new aim), not turned
const SPIN_DAMP_TIME = 0.8  # s over which a stop takes the spin off (lower: a harder stop, less inertia felt)


const ARRIVAL_BRAKE_SHARE = 0.6  # Of the thrust an arrival counts on to brake (the drag helps): the margin
const ARRIVAL_SETTLE_GAIN = 1.0  # 1/s: the last metres of an arrival at this times the distance left


# m/s to close on a point `distance` m off (negative: past it, back): top speed until the distance
# left is what `brake_share` of its thrust (`acceleration` m/s²) stops it in, then down to it, the
# last of it at ARRIVAL_SETTLE_GAIN times the distance. Every arrival flies it (move-to, approach,
# a charge at a rock).
func arrival_speed(distance: float, top_speed: float, acceleration: float, brake_share: float = ARRIVAL_BRAKE_SHARE) -> float:
	var braking: float = sqrt(2.0 * acceleration * brake_share * abs(distance))
	return sign(distance) * min(top_speed, min(braking, abs(distance) * ARRIVAL_SETTLE_GAIN))


# N the engines give: linear_thrust, times Constants.DEV_SPEED_FACTOR for the player with the DEV
# cheat MAXIMUM SPEED X5. Every command flies by it (top_speed, acceleration, the velocity force),
# so the cheat raises the speeds they ask for; scaling the force after them did nothing, as the
# velocity they hold was still the plain top speed. NPCs read the ship's own (Agent.get_top_speed).
func thrust() -> float:
	if not GameState.dev_cheats.empty() and GameState.cheat("speed_x5") and is_instance_valid(agent_body) and agent_body.has_method("is_player") and agent_body.is_player():
		return linear_thrust * Constants.DEV_SPEED_FACTOR
	return linear_thrust


# m/s the engines hold against the drag: thrust / (mass * LINEAR_DRAG).
func top_speed() -> float:
	return thrust() / max(agent_body.mass * Constants.LINEAR_DRAG, 0.001) if is_instance_valid(agent_body) else 0.0


# m/s² full thrust gives.
func acceleration() -> float:
	return thrust() / max(agent_body.mass, 0.001) if is_instance_valid(agent_body) else 0.0


# Brakes: holds still (request_velocity, zero), thrusting straight against the motion.
func request_thrust_brake():
	request_velocity(Vector3.ZERO)


# Asks for `target_velocity` this step ("How a ship is flown"); the last ask stands. Its force is
# worked out at the end of the step, after the autopilot's avoidance has steered it (steer_velocity).
func request_velocity(target_velocity: Vector3, response: float = VELOCITY_RESPONSE) -> void:
	_wanted_velocity = target_velocity
	_wanted_response = response


# This step's wanted velocity (request_velocity), or null if none was asked for.
func get_wanted_velocity():
	return _wanted_velocity


# Bends this step's wanted velocity by `change` (the autopilot round an obstacle); false if none
# was asked for (the thrust is the command's own: the caller pushes instead).
func steer_velocity(change: Vector3) -> bool:
	if _wanted_velocity == null:
		return false
	_wanted_velocity += change
	return true


# The force that takes `velocity` to `target` over `response` s (never past it in a `step`) and
# holds it against the drag; at most linear_thrust.
func _velocity_force(target: Vector3, response: float, velocity: Vector3, step: float) -> Vector3:
	var force: Vector3 = agent_body.mass * ((target - velocity) / max(response, step) + target * Constants.LINEAR_DRAG)
	var most: float = thrust()
	return force.normalized() * most if force.length() > most else force


# Kept for its callers: request_velocity.
func request_velocity_pid(target_velocity: Vector3, _delta: float = 0.0):
	request_velocity(target_velocity)


# The torque toward spin `target_spin` (rad/s, world) over `response` s, from the body's inertia,
# holding it against the angular drag; at most angular_thrust. With `roll_axis`, the spin about it
# is taken to its target over SPIN_DAMP_TIME instead (a heading's hold: its roll let go of softly).
func request_spin(target_spin: Vector3, response: float, roll_axis: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(agent_body):
		return
	var step: float = _step()
	var difference: Vector3 = target_spin - agent_body.angular_velocity
	var change: Vector3 = difference / max(response, step)
	if roll_axis != Vector3.ZERO:
		var roll: Vector3 = roll_axis * difference.dot(roll_axis)
		change = (difference - roll) / max(response, step) + roll / max(SPIN_DAMP_TIME, step)
	var torque: Vector3 = _inertia_times(change) + target_spin * Constants.ANGULAR_DRAG * agent_body.mass
	if torque.length() > angular_thrust:
		torque = torque.normalized() * angular_thrust
	_accumulated_torque += torque


# Inertia (the body's, about its centre of mass) times a world vector: the torque for that change
# of spin a second. Godot 3 gives the inertia along the body's own axes.
func _inertia_times(world: Vector3) -> Vector3:
	var inverse_inertia: Vector3 = _inverse_inertia()
	var basis: Basis = agent_body.global_transform.basis.orthonormalized()
	var local: Vector3 = basis.xform_inv(world)
	for axis in range(3):
		local[axis] = local[axis] / inverse_inertia[axis] if inverse_inertia[axis] > 1e-12 else 0.0
	return basis.xform(local)


# Angular acceleration (rad/s²) full angular thrust gives about world `axis`.
func _turn_acceleration(axis: Vector3) -> float:
	var inverse_inertia: Vector3 = _inverse_inertia()
	var local: Vector3 = agent_body.global_transform.basis.orthonormalized().xform_inv(axis.normalized())
	return angular_thrust * (local.x * local.x * inverse_inertia.x + local.y * local.y * inverse_inertia.y + local.z * local.z * inverse_inertia.z)


# s a physics step lasts (time_scale included: evolution's runs go faster).
func _step() -> float:
	return max(agent_body.get_physics_process_delta_time(), 0.0001)


func _inverse_inertia() -> Vector3:
	var state = PhysicsServer.body_get_direct_state(agent_body.get_rid())
	return state.inverse_inertia if state != null else Vector3.ZERO


# Turns the nose to `target_direction` ("How a ship is flown"). `gain` scales POINT_GAIN: above 1, a
# quicker settle on it (a charge's aim).
func request_rotation_to_pid(target_direction: Vector3, delta: float, gain: float = 1.0):
	if _steer_heading(target_direction):
		return
	_rotate_pid(target_direction, delta, gain)


# The same, for callers without a step.
func request_rotation_to(target_direction: Vector3):
	request_rotation_to_pid(target_direction, 0.0)


# A cannon has the nose: the requested direction becomes the course's heading. True if so.
func _steer_heading(target_direction: Vector3) -> bool:
	if facing == Vector3.ZERO:
		return false
	if target_direction.length_squared() >= 0.001:
		_heading = target_direction.normalized()
	return true


# The heading's spin: about the axis to it, as fast as it can be braked to rest there, slower as it
# nears. A roll the ship has is left to it (the player's autolevel).
func _rotate_pid(target_direction: Vector3, _delta: float, gain: float) -> void:
	if not is_instance_valid(agent_body) or target_direction.length_squared() < 0.001:
		return
	var target_dir: Vector3 = target_direction.normalized()
	var forward: Vector3 = -agent_body.global_transform.basis.z.normalized()
	var angle: float = forward.angle_to(target_dir)
	var axis: Vector3 = forward.cross(target_dir)
	if axis.length_squared() > 1e-12:
		axis = axis.normalized()
	else:
		axis = Vector3.ZERO if angle < 0.1 else agent_body.global_transform.basis.y.normalized()  # On it, or right behind it
	var rate: float = angle * POINT_GAIN * gain
	if axis != Vector3.ZERO:
		var acceleration: float = _turn_acceleration(axis)
		if acceleration > 0.0:
			rate = min(rate, sqrt(2.0 * acceleration * POINT_BRAKE_SHARE * angle))
	var turn: Vector3 = axis * rate + _heading_turn(target_dir)
	request_spin(turn - forward * turn.dot(forward), POINT_RESPONSE, forward)  # No roll: let go of over SPIN_DAMP_TIME


# How fast the heading asked for turns (rad/s, world): a heading on a moving target, or one a
# circling ship watches, is led by its own turn, not chased behind it.
func _heading_turn(target_dir: Vector3) -> Vector3:
	var frame: int = Engine.get_physics_frames()
	var turn := Vector3.ZERO
	if _heading_frame == frame - 1 and _heading_prev != Vector3.ZERO:
		var cross: Vector3 = _heading_prev.cross(target_dir)
		var angle: float = _heading_prev.angle_to(target_dir)
		if cross.length_squared() > 1e-14 and angle < HEADING_JUMP:  # A jump (a new aim) is no turn
			turn = cross.normalized() * angle / _step()
	if _heading_frame != frame:  # The step's first heading: one a step (a facing after the command's)
		_heading_prev = target_dir
		_heading_frame = frame
	return turn


# Stops the ship's spin (stop, align): a spin of none over SPIN_DAMP_TIME.
func request_rotation_damping_pid(_delta: float = 0.0):
	if facing != Vector3.ZERO or not is_instance_valid(agent_body):
		return
	request_spin(Vector3.ZERO, SPIN_DAMP_TIME)


func request_rotation_damping():
	request_rotation_damping_pid()


# Check if ship is approximately aligned with target direction
func is_aligned_to(target_direction: Vector3) -> bool:
	if not is_instance_valid(agent_body):
		return false
	if target_direction.length_squared() < 0.001:
		return true
	
	var target_dir = target_direction.normalized()
	var current_forward = _course_forward()
	var angle = current_forward.angle_to(target_dir)
	return angle <= _alignment_threshold_rad


# Check if ship has (approximately) stopped moving
func is_stopped() -> bool:
	if not is_instance_valid(agent_body):
		return true
	return agent_body.linear_velocity.length_squared() < 1.0


# Check if ship has (approximately) stopped rotating
func is_rotation_stopped() -> bool:
	if not is_instance_valid(agent_body):
		return true
	return agent_body.angular_velocity.length_squared() < 0.01


# Get current speed (magnitude of linear velocity)
func get_current_speed() -> float:
	if not is_instance_valid(agent_body):
		return 0.0
	return agent_body.linear_velocity.length()


# Get current velocity vector
func get_velocity() -> Vector3:
	if not is_instance_valid(agent_body):
		return Vector3.ZERO
	return agent_body.linear_velocity


# Get ship's forward direction
func get_forward() -> Vector3:
	if not is_instance_valid(agent_body):
		return -Vector3.FORWARD
	return _course_forward()