# File: scenes/camera/orbit_camera.gd
# Version 1.26 - Added rotation acceleration based on mouse input intensity. Rotation speed adjusted, pitch reversed.

extends Camera

# --- Configuration ---
var distance: float = 55.0
var min_distance_multiplier: float = 2.0
var max_distance_multiplier: float = 15.0
var preferred_distance_multiplier: float = 2.0
const MIN_ABSOLUTE_DISTANCE = 1.0
const MAX_ABSOLUTE_DISTANCE = 500.0
var zoom_speed: float = 1.0

# var rotation_speed: float = 0.004 # REMOVED - Replaced by acceleration logic
var pitch_min: float = -1.55
var pitch_max: float = 1.55
var position_smoothing_speed: float = 17.0
var rotation_smoothing_speed: float = 22.0  # Now affects how fast camera *looks at* target
var bob_frequency: float = 0.06
var bob_amplitude: float = 0.06

# --- FoV Configuration ---
var _min_fov_deg: float = 40.0
var _max_fov_deg: float = 100.0

# --- Rotation Acceleration Config --- (Internal, set via initialize)
var _rotation_max_speed: float = 0.10  # Max angular speed (radians/sec) from full mouse motion
var _rotation_acceleration: float = 15.0  # How quickly speed changes towards target
var _rotation_damping: float = 10.0  # How quickly speed decays when no input (higher = faster stop)
var _rotation_input_curve: float = 1.5  # Power curve for mouse input (1 = linear, >1 = faster ramp-up)

# --- Internal State ---
var _target: Spatial = null
var _target_radius: float = 15.0
var _yaw: float = PI
var _pitch: float = 0.25
var _current_distance: float = 55.0
var _rotation_input_active: bool = false  # Free flight flag
var _is_externally_rotating: bool = false  # LMB/Touch drag flag
var _bob_timer: float = 0.0

# --- Rotation Acceleration State ---
var _target_yaw_speed: float = 0.0
var _target_pitch_speed: float = 0.0
var _current_yaw_speed: float = 0.0
var _current_pitch_speed: float = 0.0


# --- Initialization ---
func _ready():
	_current_distance = distance
	_yaw = PI
	_pitch = 0.25
	set_as_toplevel(true)
	GlobalRefs.main_camera = self

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
	# ... other standard params ...
	if config.has("bob_amplitude"):
		self.bob_amplitude = config.bob_amplitude

	# Initialize FoV limits... (same as before)
	if config.has("min_fov_deg"):
		self._min_fov_deg = config.min_fov_deg
	if config.has("max_fov_deg"):
		self._max_fov_deg = config.max_fov_deg

	# --- ADDED: Initialize Rotation Acceleration limits from config ---
	if config.has("rotation_max_speed"):
		self._rotation_max_speed = config.rotation_max_speed
	if config.has("rotation_acceleration"):
		self._rotation_acceleration = config.rotation_acceleration
	if config.has("rotation_damping"):
		self._rotation_damping = config.rotation_damping
	if config.has("rotation_input_curve"):
		self._rotation_input_curve = config.rotation_input_curve
	# --- End Added ---

	self._yaw = deg2rad(config.get("initial_yaw_deg", 180.0))
	self._pitch = clamp(deg2rad(config.get("initial_pitch_deg", 15.0)), pitch_min, pitch_max)
	_current_distance = self.distance

	print("OrbitCamera initialized.")


# --- Input Handling ---
func _unhandled_input(event):
	# Rotation Input (Mouse Motion) - Now sets TARGET speed
	if event is InputEventMouseMotion:
		if _rotation_input_active or _is_externally_rotating:
			# Calculate input strength (normalize relative motion magnitude, maybe clamp)
			# Note: event.relative can be large, might need scaling factor if uncapped
			var input_strength_x = abs(event.relative.x)  # Normalize roughly? Or use fixed divisor?
			var input_strength_y = abs(event.relative.y)

			# Apply power curve for non-linear response
			input_strength_x = pow(input_strength_x, _rotation_input_curve)
			input_strength_y = pow(input_strength_y, _rotation_input_curve)

			# Set target speed based on direction and scaled strength
			_target_yaw_speed = -sign(event.relative.x) * input_strength_x * _rotation_max_speed
			_target_pitch_speed = -sign(event.relative.y) * input_strength_y * _rotation_max_speed  # Note: Pitch might feel inverted, adjust sign if needed

			# Consume the event so other UI elements don't process drag motion
			get_viewport().set_input_as_handled()

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

	# --- Update Rotation based on Speed --- ADDED ---
	var rot_active = _rotation_input_active or _is_externally_rotating
	# If rotation isn't active, force target speed to 0 to ensure damping works
	if not rot_active:
		_target_yaw_speed = 0.0
		_target_pitch_speed = 0.0

	# Interpolate current speed towards target speed (Acceleration)
	_current_yaw_speed = lerp(_current_yaw_speed, _target_yaw_speed, _rotation_acceleration * delta)
	_current_pitch_speed = lerp(
		_current_pitch_speed, _target_pitch_speed, _rotation_acceleration * delta
	)

	# Apply damping (always active, brings speed back to 0)
	var damp_factor = 1.0 - (_rotation_damping * delta)  # Needs delta adjustment for frame independence
	# Clamp damp_factor to prevent reversal if delta is large or damping is high
	damp_factor = max(0.0, damp_factor)
	_current_yaw_speed *= damp_factor
	_current_pitch_speed *= damp_factor

	# Apply calculated rotation speeds to angles
	_yaw += _current_yaw_speed * delta
	_pitch -= _current_pitch_speed * delta
	_pitch = clamp(_pitch, pitch_min, pitch_max)  # Keep pitch within limits

	# Reset target speed for next frame (input will overwrite if motion occurs)
	# This ensures damping takes over if input stops suddenly
	_target_yaw_speed = 0.0
	_target_pitch_speed = 0.0
	# --- End Rotation Update ---

	# --- Update Position and LookAt ---
	if not is_instance_valid(_target):
		# Detached Mode (Apply only rotation)
		var new_basis = Basis().rotated(Vector3.UP, _yaw).rotated(
			Basis().rotated(Vector3.UP, _yaw).x, _pitch
		)
		global_transform.basis = global_transform.basis.slerp(
			new_basis.orthonormalized(), rotation_smoothing_speed * delta
		)
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

	# Interpolate Look At (still smoothly look at target even while manually rotating)
	var target_look_transform = global_transform.looking_at(target_pos, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(
		target_look_transform.basis.orthonormalized(), rotation_smoothing_speed * delta
	)


# --- Dynamic FoV Update Logic --- (Unchanged from v1.24)
func _update_fov():
	var dyn_min_dist = _get_dynamic_min_distance()
	var dyn_max_dist = _get_dynamic_max_distance()
	if is_equal_approx(dyn_max_dist, dyn_min_dist):
		self.fov = _max_fov_deg
		return
	var t = clamp((_current_distance - dyn_min_dist) / (dyn_max_dist - dyn_min_dist), 0.0, 1.0)
	self.fov = lerp(_min_fov_deg, _max_fov_deg, t)


# --- Helper functions for dynamic distances --- (Unchanged from v1.24)
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


func set_is_rotating(rotating: bool):
	if not _rotation_input_active:
		_is_externally_rotating = rotating


# --- set_target_node, _get_target_effective_radius, get_current_target, _notification ---
# (Unchanged from v1.24)
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
	else:
		if _target != null:
			print("OrbitCamera target cleared.")
			target_changed = true
		_target = null
		_target_radius = 10.0
	if target_changed:
		_update_fov()


func _get_target_effective_radius(target_node: Spatial) -> float:
	var default_radius = 10.0
	if not is_instance_valid(target_node):
		return default_radius
	if target_node.has_method("get_interaction_radius"):
		var radius = target_node.get_interaction_radius()
		if (radius is float or radius is int) and radius > 0.0:
			return max(radius, 1.0)
	return default_radius


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
