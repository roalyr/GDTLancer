# File: scenes/camera/orbit_camera.gd
# Version 1.20 - Simplified radius calc uses target method, Strict Formatting

extends Camera

# --- Configuration ---
var distance: float = 55.0        # Fallback/preferred distance basis
var min_distance_multiplier: float = 1.8
var max_distance_multiplier: float = 15.0
var preferred_distance_multiplier: float = 2.5
const MIN_ABSOLUTE_DISTANCE = 8.0
const MAX_ABSOLUTE_DISTANCE = 500.0
var zoom_speed: float = 1.5
var rotation_speed: float = 0.008
var pitch_min: float = -1.45
var pitch_max: float = 1.45
var position_smoothing_speed: float = 15.0
var rotation_smoothing_speed: float = 10.0
var bob_frequency: float = 0.6
var bob_amplitude: float = 0.06

# --- Internal State ---
var _target: Spatial = null
var _target_radius: float = 15.0
var _yaw: float = PI
var _pitch: float = 0.25
var _current_distance: float = 55.0
var _is_player_rotating: bool = false
var _bob_timer: float = 0.0

# --- Initialization ---
func _ready():
	_current_distance = distance
	_yaw = PI
	_pitch = 0.25
	set_as_toplevel(true)
	GlobalRefs.main_camera = self

	if EventBus:
		if not EventBus.is_connected("camera_set_target_requested", self,
				"_on_Camera_Set_Target_Requested"):
			var err = EventBus.connect("camera_set_target_requested", self,
					"_on_Camera_Set_Target_Requested")
			if err != OK:
				printerr("Camera Error: Failed connect signal! Code: ", err)
	else:
		printerr("Camera Error: EventBus not available!")

	# Proactive Check for player
	if not is_instance_valid(_target):
		if is_instance_valid(GlobalRefs.player_agent_body):
			set_target_node(GlobalRefs.player_agent_body)

func initialize(config: Dictionary):
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
	if config.has("rotation_speed"):
		self.rotation_speed = config.rotation_speed
	if config.has("pitch_min_deg"):
		self.pitch_min = deg2rad(config.pitch_min_deg)
	if config.has("pitch_max_deg"):
		self.pitch_max = deg2rad(config.pitch_max_deg)
	if config.has("position_smoothing_speed"):
		self.position_smoothing_speed = config.position_smoothing_speed
	if config.has("rotation_smoothing_speed"):
		self.rotation_smoothing_speed = config.rotation_smoothing_speed
	if config.has("bob_frequency"):
		self.bob_frequency = config.bob_frequency
	if config.has("bob_amplitude"):
		self.bob_amplitude = config.bob_amplitude

	self._yaw = deg2rad(config.get("initial_yaw_deg", 180.0))
	self._pitch = clamp(deg2rad(config.get("initial_pitch_deg", 15.0)),
			pitch_min, pitch_max)
	_current_distance = self.distance
	print("OrbitCamera initialized.")


# --- Input Handling ---
func _unhandled_input(event):
	# Track RMB state
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			_is_player_rotating = event.pressed

	# Rotation Input (RMB Drag)
	if event is InputEventMouseMotion:
		if _is_player_rotating:
			_yaw -= event.relative.x * rotation_speed
			_pitch += event.relative.y * rotation_speed
			_pitch = clamp(_pitch, pitch_min, pitch_max)
			get_viewport().set_input_as_handled()

	# Zoom Input (Wheel) - Only works when attached
	if is_instance_valid(_target):
		if event is InputEventMouseButton:
			var dyn_min_dist = max(MIN_ABSOLUTE_DISTANCE,
					_target_radius * min_distance_multiplier)
			var dyn_max_calc = max(dyn_min_dist + 1.0,
					_target_radius * max_distance_multiplier)
			var dyn_max_dist = min(MAX_ABSOLUTE_DISTANCE, dyn_max_calc)

			var zoom_factor = 1.0 + (zoom_speed * 0.1)
			var input_handled = false

			if event.button_index == BUTTON_WHEEL_UP and event.pressed:
				_current_distance = max(dyn_min_dist,
						_current_distance / zoom_factor)
				input_handled = true
			elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
				_current_distance = min(dyn_max_dist,
						_current_distance * zoom_factor)
				input_handled = true

			if input_handled:
				get_viewport().set_input_as_handled()


# --- Physics Update ---
func _physics_process(delta):
	_bob_timer += delta

	if not is_instance_valid(_target):
		# Detached Mode: Rotate in Place
		var new_basis = Basis()
		new_basis = new_basis.rotated(Vector3.UP, _yaw)
		new_basis = new_basis.rotated(new_basis.x, _pitch)
		global_transform.basis = new_basis.orthonormalized()
		return

	# --- Attached Mode ---
	var target_pos = _target.global_transform.origin

	# Calculate Bobbing Offset
	var bob_offset = global_transform.basis.y * \
			sin(_bob_timer * bob_frequency * TAU) * bob_amplitude

	# Calculate Desired Camera Position
	var camera_basis = Basis()
	camera_basis = camera_basis.rotated(Vector3.UP, _yaw)
	camera_basis = camera_basis.rotated(camera_basis.x, _pitch)
	var position_offset = -camera_basis.z * _current_distance
	var desired_position = target_pos + position_offset + bob_offset

	# Smoothly Interpolate Camera Position
	global_transform.origin = global_transform.origin.linear_interpolate(
			desired_position, position_smoothing_speed * delta)

	# Smoothly Interpolate Look At
	var target_look_transform = global_transform.looking_at(target_pos, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(
			target_look_transform.basis, rotation_smoothing_speed * delta)


# --- Signal Handler & Public Functions ---
func _on_Camera_Set_Target_Requested(target_node):
	set_target_node(target_node)

func set_target_node(new_target: Spatial):
	if is_instance_valid(new_target):
		if _target != new_target:
			_target = new_target
			# Update target radius using target's own method or default
			_target_radius = _get_target_effective_radius(_target)
			print("OrbitCamera target set to: ", new_target.name,
					" | Eff Radius: ", _target_radius)
			# Reset/Clamp distance based on new target size
			var dyn_min_dist = max(MIN_ABSOLUTE_DISTANCE,
					_target_radius * min_distance_multiplier)
			var dyn_max_calc = max(dyn_min_dist + 1.0,
					_target_radius * max_distance_multiplier)
			var dyn_max_dist = min(MAX_ABSOLUTE_DISTANCE, dyn_max_calc)
			var preferred_dist = max(dyn_min_dist,
					_target_radius * preferred_distance_multiplier)
			_current_distance = clamp(preferred_dist, dyn_min_dist, dyn_max_dist)
			print("  Reset distance to: ", _current_distance)
	else:
		# Target is being cleared
		if _target != null:
			print("OrbitCamera target cleared.")
		_target = null
		_target_radius = 10.0 # Reset to default radius


# --- Target Size Helper ---
# Simplified to primarily rely on the target having get_interaction_radius()
func _get_target_effective_radius(target_node: Spatial) -> float:
	var default_radius = 10.0 # Fallback if method missing or invalid

	if not is_instance_valid(target_node):
		return default_radius

	# Prioritize specific method if target implements it
	if target_node.has_method("get_interaction_radius"):
		var radius = target_node.get_interaction_radius()
		# Validate the returned value
		if radius is float or radius is int:
			if radius > 0.0:
				# Return custom radius, ensuring minimum 1.0
				return max(radius, 1.0)
			else:
				print("Warning: get_interaction_radius returned non-positive value for ",
						target_node.name)
		else:
			print("Warning: get_interaction_radius returned non-numeric value for ",
					target_node.name)
	# else:
	#	 print("Warning: Target ", target_node.name,
	#			 " missing get_interaction_radius(), using default.") # Optional

	# Fallback if method doesn't exist or returns invalid value
	return default_radius


func get_current_target() -> Spatial:
	if is_instance_valid(_target):
		return _target
	else:
		return null

# --- Cleanup ---
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus:
			if EventBus.is_connected("camera_set_target_requested", self,
					"_on_Camera_Set_Target_Requested"):
				EventBus.disconnect("camera_set_target_requested", self,
						"_on_Camera_Set_Target_Requested")
		if GlobalRefs:
			if GlobalRefs.main_camera == self:
				GlobalRefs.main_camera = null
