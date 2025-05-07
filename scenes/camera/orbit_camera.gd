# File: scenes/camera/orbit_camera.gd
# Version 1.30 - Refactored rotation smoothing to use PIDController.
# Requires tuning of PID gains.

extends Camera

# --- Configuration ---
var distance: float = 55.0
var min_distance_multiplier: float = 2.0
var max_distance_multiplier: float = 15.0
var preferred_distance_multiplier: float = 2.0
const MIN_ABSOLUTE_DISTANCE = 1.0
const MAX_ABSOLUTE_DISTANCE = 500.0
var zoom_speed: float = 1.0

# var rotation_speed: float = 0.004 # REMOVED - Replaced by PID logic
var pitch_min: float = -1.45
var pitch_max: float = 1.45
var position_smoothing_speed: float = 18.0
var rotation_smoothing_speed: float = 18.0  # Now affects how fast camera *looks at* target
var bob_frequency: float = 0.1
var bob_amplitude: float = 0.2

# --- FoV Configuration ---
var _min_fov_deg: float = 40.0
var _max_fov_deg: float = 40.0

# --- Rotation PID Config --- (Tunable - Initial guesses)
# Higher Kp = Faster reaction to input changes
# Higher Ki = Reduces steady-state error (but can cause overshoot/oscillation)
# Higher Kd = Dampens overshoot/oscillation
# --- TUNABLE PARAMETERS START ---
var pid_yaw_kp: float = 10  # Was _rotation_acceleration
var pid_yaw_ki: float = 0.01
var pid_yaw_kd: float = 0.1  # Related to old _rotation_damping conceptually
var pid_pitch_kp: float = 10  # Was _rotation_acceleration
var pid_pitch_ki: float = 0.01
var pid_pitch_kd: float = 0.1  # Related to old _rotation_damping conceptually
var pid_integral_limit: float = 10.0  # Limit integral windup
var pid_output_limit_multiplier: float = 100  # Allow PID to demand slightly > max speed temporarily
# --- TUNABLE PARAMETERS END ---

# --- Rotation Base Config --- (Set via initialize or defaults)
var _rotation_max_speed: float = 15  # Max angular speed (radians/frame? check usage) -> Should be radians/sec
var _rotation_input_curve: float = 1.1  # Power curve for mouse input

# --- Internal State ---
var _target: Spatial = null
var _target_radius: float = 15.0
var _yaw: float = PI
var _pitch: float = 0.25
var _current_distance: float = 55.0
var _rotation_input_active: bool = false  # Free flight flag
var _is_externally_rotating: bool = false  # LMB/Touch drag flag
var _bob_timer: float = 0.0

# --- Rotation PID State ---
var _target_yaw_speed: float = 0.0
var _target_pitch_speed: float = 0.0
var _current_yaw_speed: float = 0.0
var _current_pitch_speed: float = 0.0

# --- PID Controller Instances ---
var _yaw_pid: PIDController = null
var _pitch_pid: PIDController = null
const PIDControllerScript = preload("res://core/utils/pid_controller.gd")


# --- Initialization ---
func _ready():
	_current_distance = distance
	_yaw = PI
	_pitch = 0.25
	set_as_toplevel(true)
	GlobalRefs.main_camera = self

	# --- Instantiate and Initialize PID Controllers ---
	if PIDControllerScript:
		_yaw_pid = PIDControllerScript.new()
		_pitch_pid = PIDControllerScript.new()

		# Calculate output limit based on max speed
		# PID output represents acceleration, limit it reasonably
		var output_limit = _rotation_max_speed * pid_output_limit_multiplier  # Allow some overshoot potential if needed

		if is_instance_valid(_yaw_pid):
			_yaw_pid.initialize(
				pid_yaw_kp, pid_yaw_ki, pid_yaw_kd, pid_integral_limit, output_limit
			)
			print(
				(
					"Camera Yaw PID Initialized (Kp=%.2f, Ki=%.2f, Kd=%.2f, OLimit=%.2f)"
					% [pid_yaw_kp, pid_yaw_ki, pid_yaw_kd, output_limit]
				)
			)
		else:
			printerr("Camera Error: Failed to instance Yaw PIDController.")

		if is_instance_valid(_pitch_pid):
			_pitch_pid.initialize(
				pid_pitch_kp, pid_pitch_ki, pid_pitch_kd, pid_integral_limit, output_limit
			)
			print(
				(
					"Camera Pitch PID Initialized (Kp=%.2f, Ki=%.2f, Kd=%.2f, OLimit=%.2f)"
					% [pid_pitch_kp, pid_pitch_ki, pid_pitch_kd, output_limit]
				)
			)
		else:
			printerr("Camera Error: Failed to instance Pitch PIDController.")
	else:
		printerr(
			"Camera Error: Failed to preload PIDController script! Rotation smoothing disabled."
		)
		set_physics_process(false)  # Disable if PIDs can't be created

	# Connect signals... (same as before)
	if EventBus:
		if not EventBus.is_connected(
			"camera_set_target_requested", self, "_on_Camera_Set_Target_Requested"
		):
			var err = EventBus.connect(
				"camera_set_target_requested", self, "_on_Camera_Set_Target_Requested"
			)
			if err != OK:
				printerr("Camera Error: Failed connect signal! Code: ", err)
	else:
		printerr("Camera Error: EventBus not available!")

	# Proactive player check... (same as before)
	if not is_instance_valid(_target):
		if is_instance_valid(GlobalRefs.player_agent_body):
			set_target_node(GlobalRefs.player_agent_body)
	_update_fov()


func initialize(config: Dictionary):
	# Initialize standard config... (same as before)
	if config.has("distance"):
		self.distance = config.distance
	if config.has("min_distance_multiplier"):
		self.min_distance_multiplier = config.min_distance_multiplier
	if config.has("max_distance_multiplier"):
		self.max_distance_multiplier = config.max_distance_multiplier
	if config.has("preferred_distance_multiplier"):
		self.preferred_distance_multiplier = config.preferred_distance_multiplier
	if config.has("zoom_speed"):
		self.zoom_speed = config.zoom_speed
	if config.has("pitch_min"):
		self.pitch_min = config.pitch_min
	if config.has("pitch_max"):
		self.pitch_max = config.pitch_max
	if config.has("position_smoothing_speed"):
		self.position_smoothing_speed = config.position_smoothing_speed
	if config.has("rotation_smoothing_speed"):
		self.rotation_smoothing_speed = config.rotation_smoothing_speed
	if config.has("bob_frequency"):
		self.bob_frequency = config.bob_frequency
	if config.has("bob_amplitude"):
		self.bob_amplitude = config.bob_amplitude

	# Initialize FoV limits... (same as before)
	if config.has("min_fov_deg"):
		self._min_fov_deg = config.min_fov_deg
	if config.has("max_fov_deg"):
		self._max_fov_deg = config.max_fov_deg

	# --- Initialize Rotation Base Config from config ---
	if config.has("rotation_max_speed"):
		self._rotation_max_speed = config.rotation_max_speed
	if config.has("rotation_input_curve"):
		self._rotation_input_curve = config.rotation_input_curve

	# --- Initialize PID Tunables from config ---
	if config.has("pid_yaw_kp"):
		self.pid_yaw_kp = config.pid_yaw_kp
	if config.has("pid_yaw_ki"):
		self.pid_yaw_ki = config.pid_yaw_ki
	if config.has("pid_yaw_kd"):
		self.pid_yaw_kd = config.pid_yaw_kd
	if config.has("pid_pitch_kp"):
		self.pid_pitch_kp = config.pid_pitch_kp
	if config.has("pid_pitch_ki"):
		self.pid_pitch_ki = config.pid_pitch_ki
	if config.has("pid_pitch_kd"):
		self.pid_pitch_kd = config.pid_pitch_kd
	if config.has("pid_integral_limit"):
		self.pid_integral_limit = config.pid_integral_limit
	if config.has("pid_output_limit_multiplier"):
		self.pid_output_limit_multiplier = config.pid_output_limit_multiplier

	# --- Re-Initialize PIDs if they exist and params changed ---
	if is_instance_valid(_yaw_pid) and is_instance_valid(_pitch_pid):
		var output_limit = _rotation_max_speed * pid_output_limit_multiplier
		_yaw_pid.initialize(pid_yaw_kp, pid_yaw_ki, pid_yaw_kd, pid_integral_limit, output_limit)
		_pitch_pid.initialize(
			pid_pitch_kp, pid_pitch_ki, pid_pitch_kd, pid_integral_limit, output_limit
		)
		print("Camera PIDs Re-initialized from config.")

	self._yaw = deg2rad(config.get("initial_yaw_deg", 180.0))
	self._pitch = clamp(deg2rad(config.get("initial_pitch_deg", 15.0)), pitch_min, pitch_max)
	_current_distance = self.distance

	print("OrbitCamera initialized via config.")


# --- Input Handling ---
func _unhandled_input(event):
	# Rotation Input (Mouse Motion) - Sets TARGET speed
	if event is InputEventMouseMotion:
		if _rotation_input_active or _is_externally_rotating:
			# Calculate input strength (normalize relative motion magnitude if needed)
			# Using event.relative directly, scaled by max_speed later.
			var input_x = event.relative.x
			var input_y = event.relative.y

			# Apply power curve for non-linear response
			# Sign must be preserved
			var strength_x = pow(abs(input_x), _rotation_input_curve) * sign(input_x)
			var strength_y = pow(abs(input_y), _rotation_input_curve) * sign(input_y)

			# Set target speed based on direction and scaled strength
			# Normalize/Scale the input strength. How much mouse movement corresponds to max speed?
			# Let's assume a certain pixel movement (e.g., 50px?) corresponds to reaching max speed.
			var input_scale_factor = 0.01  # TUNABLE: Adjust this based on feel. Lower = more sensitive.
			_target_yaw_speed = -strength_x * input_scale_factor * _rotation_max_speed
			_target_pitch_speed = -strength_y * input_scale_factor * _rotation_max_speed

			# Clamp target speed to max speed (important!)
			_target_yaw_speed = clamp(_target_yaw_speed, -_rotation_max_speed, _rotation_max_speed)
			_target_pitch_speed = clamp(
				_target_pitch_speed, -_rotation_max_speed, _rotation_max_speed
			)

			# Consume the event
			get_viewport().set_input_as_handled()
		#else: # Reset target speed if mouse moves but rotation is not active? Or let physics handle damping?
		#	_target_yaw_speed = 0.0
		#	_target_pitch_speed = 0.0
		# Let physics handle damping back to 0 if input stops or mode changes.

	# Zoom Input (Wheel) - Unchanged
	elif event is InputEventMouseButton and is_instance_valid(_target):
		var dyn_min_dist = _get_dynamic_min_distance()
		var dyn_max_dist = _get_dynamic_max_distance()
		var zoom_factor = 1.0 + (zoom_speed * 0.1)
		var input_handled = false
		if event.button_index == BUTTON_WHEEL_UP and event.pressed:
			_current_distance = max(dyn_min_dist, _current_distance / zoom_factor)
			input_handled = true
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			_current_distance = min(dyn_max_dist, _current_distance * zoom_factor)
			input_handled = true
		if input_handled:
			get_viewport().set_input_as_handled()


# --- Physics Update ---
func _physics_process(delta):
	_bob_timer += delta

	# --- Update FoV --- (Unchanged)
	if is_instance_valid(_target):
		_update_fov()

	# --- PID Rotation Update ---
	# Check if PIDs are valid
	if not is_instance_valid(_yaw_pid) or not is_instance_valid(_pitch_pid):
		# Fallback or error state if PIDs failed
		if delta > 0:
			printerr("Camera physics update skipped: PIDs invalid.")
		# Could implement simple non-PID rotation here as fallback if desired
	else:
		var rot_active = _rotation_input_active or _is_externally_rotating

		# If rotation isn't active, force target speed to 0
		if not rot_active:
			_target_yaw_speed = 0.0
			_target_pitch_speed = 0.0

		# Calculate Error (Setpoint - Process Variable)
		var error_yaw = _target_yaw_speed - _current_yaw_speed
		var error_pitch = _target_pitch_speed - _current_pitch_speed

		# Update PIDs to get acceleration adjustment
		var yaw_accel = _yaw_pid.update(error_yaw, delta)
		var pitch_accel = _pitch_pid.update(error_pitch, delta)

		# Apply acceleration to current speed
		_current_yaw_speed += yaw_accel * delta
		_current_pitch_speed += pitch_accel * delta

		# --- Sanity check/clamp speed if PID overshoots significantly (optional) ---
		# _current_yaw_speed = clamp(_current_yaw_speed, -_rotation_max_speed * 1.1, _rotation_max_speed * 1.1)
		# _current_pitch_speed = clamp(_current_pitch_speed, -_rotation_max_speed * 1.1, _rotation_max_speed * 1.1)

		# Apply calculated rotation speeds to angles
		_yaw += _current_yaw_speed * delta
		_pitch -= _current_pitch_speed * delta  # MAINTAIN SIGN CONVENTION
		_pitch = clamp(_pitch, pitch_min, pitch_max)  # Keep pitch within limits

		# Reset target speed derived from momentary input for next frame
		# PID system naturally damps if input stops setting a target speed.
		_target_yaw_speed = 0.0
		_target_pitch_speed = 0.0
	# --- End PID Rotation Update ---

	# --- Update Position and LookAt --- (Unchanged from previous logic)
	if not is_instance_valid(_target):
		# Detached Mode (Apply only orientation calculated above)
		# Ensure _yaw and _pitch updates are still applied
		var new_basis = Basis().rotated(Vector3.UP, _yaw).rotated(
			Basis().rotated(Vector3.UP, _yaw).x, _pitch
		)
		# We don't slerp the basis anymore, we directly set it based on PID-controlled angles
		global_transform.basis = new_basis.orthonormalized()
		return

	# --- Attached Mode --- (Position + LookAt)
	var target_pos = _target.global_transform.origin
	var bob_offset = (
		global_transform.basis.y
		* sin(_bob_timer * bob_frequency * TAU)
		* bob_amplitude
	)

	# Calculate desired orientation first based on yaw/pitch
	var desired_basis = Basis().rotated(Vector3.UP, _yaw).rotated(
		Basis().rotated(Vector3.UP, _yaw).x, _pitch
	)

	# Calculate desired position based on orientation and distance
	var position_offset = -desired_basis.z * _current_distance
	var desired_position = target_pos + position_offset + bob_offset

	# Interpolate Position
	global_transform.origin = global_transform.origin.linear_interpolate(
		desired_position, position_smoothing_speed * delta
	)

	# Interpolate Look At (still smoothly look *at* the target even while manually rotating orientation)
	var target_look_transform = global_transform.looking_at(target_pos, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(
		target_look_transform.basis.orthonormalized(), rotation_smoothing_speed * delta
	)


# --- Dynamic FoV Update Logic --- (Unchanged)
func _update_fov():
	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_dist = _get_dynamic_max_distance()
	if is_equal_approx(dyn_max_dist, dyn_min_dist):
		self.fov = _max_fov_deg
		return
	var t = clamp((_current_distance - dyn_min_dist) / (dyn_max_dist - dyn_min_dist), 0.0, 1.0)
	self.fov = lerp(_min_fov_deg, _max_fov_deg, t)


# --- Helper functions for dynamic distances --- (Unchanged)
func _get_dynamic_min_distance() -> float:
	if not is_instance_valid(_target):
		return MIN_ABSOLUTE_DISTANCE
	_target_radius = _get_target_effective_radius(_target)
	return max(MIN_ABSOLUTE_DISTANCE, _target_radius * min_distance_multiplier)


func _get_dynamic_max_distance() -> float:
	if not is_instance_valid(_target):
		return MAX_ABSOLUTE_DISTANCE
	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_calc = max(dyn_min_dist + 1.0, _target_radius * max_distance_multiplier)
	return min(MAX_ABSOLUTE_DISTANCE, dyn_max_calc)


# --- Signal Handler & Public Functions --- (External control functions unchanged)
func _on_Camera_Set_Target_Requested(target_node):
	set_target_node(target_node)


func set_rotation_input_active(is_active: bool):
	_rotation_input_active = is_active
	if is_active:
		_is_externally_rotating = false
	# Reset PID controllers when state changes? Optional, depends on desired feel.
	# if is_instance_valid(_yaw_pid): _yaw_pid.reset()
	# if is_instance_valid(_pitch_pid): _pitch_pid.reset()


func set_is_rotating(rotating: bool):
	# Only allow external rotation if free flight rotation is not active
	if not _rotation_input_active:
		_is_externally_rotating = rotating
	# Reset PIDs when starting/stopping drag?
	# if is_instance_valid(_yaw_pid): _yaw_pid.reset()
	# if is_instance_valid(_pitch_pid): _pitch_pid.reset()


# --- set_target_node, _get_target_effective_radius, get_current_target, _notification ---
# (Unchanged from v1.26/previous version)
func set_target_node(new_target: Spatial):
	var target_changed = false
	if is_instance_valid(new_target):
		if _target != new_target:
			_target = new_target
			_target_radius = _get_target_effective_radius(_target)
			print("OrbitCamera target set to: ", new_target.name, " | Eff Radius: ", _target_radius)
			var dyn_min_dist = _get_dynamic_min_distance()
			var dyn_max_dist = _get_dynamic_max_distance()
			var preferred_dist = max(dyn_min_dist, _target_radius * preferred_distance_multiplier)
			_current_distance = clamp(preferred_dist, dyn_min_dist, dyn_max_dist)
			print("  Reset distance to: ", _current_distance)
			target_changed = true
			# Reset PIDs on target change for stability
			if is_instance_valid(_yaw_pid):
				_yaw_pid.reset()
			if is_instance_valid(_pitch_pid):
				_pitch_pid.reset()
			_current_yaw_speed = 0.0
			_current_pitch_speed = 0.0
	else:
		if _target != null:
			print("OrbitCamera target cleared.")
			target_changed = true
		_target = null
		_target_radius = 10.0
		# Optionally reset PIDs when target is cleared too
		# if is_instance_valid(_yaw_pid): _yaw_pid.reset()
		# if is_instance_valid(_pitch_pid): _pitch_pid.reset()
		# _current_yaw_speed = 0.0
		# _current_pitch_speed = 0.0
	if target_changed:
		_update_fov()


func _get_target_effective_radius(target_node: Spatial) -> float:
	var default_radius = 10.0
	if not is_instance_valid(target_node):
		return default_radius
	# Use the agent's method if available (consistent with NavigationSystem)
	if target_node.has_method("get_interaction_radius"):
		var radius = target_node.get_interaction_radius()
		if (radius is float or radius is int) and radius > 0.0:
			return max(float(radius), 1.0)  # Ensure float and minimum size
	# Fallback (keep simple for camera, agent has more complex logic)
	var node_scale = target_node.global_transform.basis.get_scale()
	var max_scale = max(node_scale.x, max(node_scale.y, node_scale.z))
	return max(max_scale / 2.0, default_radius)  # Rough radius from scale, or default


func get_current_target() -> Spatial:
	if is_instance_valid(_target):
		return _target
	else:
		return null


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if (
			EventBus
			and EventBus.is_connected(
				"camera_set_target_requested", self, "_on_Camera_Set_Target_Requested"
			)
		):
			EventBus.disconnect(
				"camera_set_target_requested", self, "_on_Camera_Set_Target_Requested"
			)
		if GlobalRefs and GlobalRefs.main_camera == self:
			GlobalRefs.main_camera = null
