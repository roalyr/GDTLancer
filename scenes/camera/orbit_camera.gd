# File: scenes/camera/orbit_camera.gd
# Attach to Camera node in orbit_camera.tscn
# Version 1.8 - Fixed all single-line/lumped if/else blocks, uses Tabs

extends Camera

# --- Configurable Properties ---
var distance: float = 50.0
var min_distance: float = 10.0
var max_distance: float = 200.0
var zoom_speed: float = 1.5
var rotation_speed: float = 0.008
var pitch_min: float = -1.45
var pitch_max: float = 1.45
var smoothing_speed: float = 8.0

# --- Internal State ---
var _target: Spatial = null
var _yaw: float = 0.0
var _pitch: float = 0.4
var _current_distance: float = 50.0
var _is_detached: bool = true # Start detached

# --- Initialization ---
func _ready():
	_current_distance = distance
	set_as_toplevel(true)
	GlobalRefs.main_camera = self # Register self

	# Connect to signal for future target requests
	if EventBus and not EventBus.is_connected("camera_set_target_requested", self, "_on_Camera_Set_Target_Requested"):
		var err = EventBus.connect("camera_set_target_requested", self, "_on_Camera_Set_Target_Requested")
		if err != OK:
			printerr("Camera Error: Failed connect camera_set_target_requested signal! Code: ", err)

	# Proactive Check
	if not is_instance_valid(_target) and is_instance_valid(GlobalRefs.player_agent_body):
		print("OrbitCamera: Found existing player via GlobalRefs on ready, setting target.")
		set_target_node(GlobalRefs.player_agent_body)
	elif not is_instance_valid(_target):
		print("OrbitCamera Ready. No initial target found via GlobalRefs.")
	else:
		print("OrbitCamera Ready (target likely set by initialize).")


func initialize(config: Dictionary):
	# ... (Initialization logic for distance, speed etc.) ...
	if config.has("distance"): self.distance = config.distance
	if config.has("min_distance"): self.min_distance = config.min_distance
	if config.has("max_distance"): self.max_distance = config.max_distance
	if config.has("zoom_speed"): self.zoom_speed = config.zoom_speed
	if config.has("rotation_speed"): self.rotation_speed = config.rotation_speed
	if config.has("pitch_min_deg"): self.pitch_min = deg2rad(config.pitch_min_deg)
	if config.has("pitch_max_deg"): self.pitch_max = deg2rad(config.pitch_max_deg)
	if config.has("smoothing_speed"): self.smoothing_speed = config.smoothing_speed
	if config.has("initial_yaw_deg"): self._yaw = deg2rad(config.initial_yaw_deg)
	if config.has("initial_pitch_deg"): self._pitch = clamp(deg2rad(config.initial_pitch_deg), pitch_min, pitch_max)
	_current_distance = self.distance
	print("OrbitCamera initialized.")


# --- Input Handling ---
func _unhandled_input(event):

	# --- Rotation Input (RMB Drag) - Always works ---
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(BUTTON_RIGHT):
			_yaw -= event.relative.x * rotation_speed
			_pitch += event.relative.y * rotation_speed
			_pitch = clamp(_pitch, pitch_min, pitch_max)
			get_viewport().set_input_as_handled()

	# --- Zoom Input (Wheel) - Only works when attached ---
	if is_instance_valid(_target) and not _is_detached:
		if event is InputEventMouseButton:
			var zoom_factor = 1.0 + (zoom_speed * 0.1)
			# Expanded if/elif block for zoom
			if event.button_index == BUTTON_WHEEL_UP and event.pressed:
				_current_distance = max(min_distance, _current_distance / zoom_factor)
				get_viewport().set_input_as_handled()
			elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
				_current_distance = min(max_distance, _current_distance * zoom_factor)
				get_viewport().set_input_as_handled()


# --- Physics Update ---
func _physics_process(delta):
	if is_instance_valid(_target) and not _is_detached:
		# --- Attached Mode: Orbit Target ---
		var target_pos = _target.global_transform.origin
		var offset = Vector3.FORWARD.rotated(Vector3.UP, _yaw).rotated(Vector3.RIGHT.rotated(Vector3.UP, _yaw), _pitch)
		var desired_position = target_pos + offset * _current_distance
		global_transform.origin = global_transform.origin.linear_interpolate(desired_position, smoothing_speed * delta)
		look_at(target_pos, Vector3.UP)
	else:
		# --- Detached Mode: Rotate in Place ---
		var new_basis = Basis()
		new_basis = new_basis.rotated(Vector3.UP, _yaw)
		new_basis = new_basis.rotated(new_basis.x, _pitch)
		global_transform.basis = new_basis.orthonormalized()


# --- Signal Handler ---
func _on_Camera_Set_Target_Requested(target_node):
	print(">>> Camera received set_target_requested signal for: ", target_node.name if is_instance_valid(target_node) else "null")
	set_target_node(target_node) # Call internal setter


# --- Public Functions ---
func set_target_node(new_target: Spatial):
	print(">>> Camera set_target_node called with: ", new_target.name if is_instance_valid(new_target) else "null")
	if is_instance_valid(new_target):
		# Expanded if
		if _target != new_target:
			_target = new_target
			_is_detached = false # Re-attach
			print("OrbitCamera target set to: ", new_target.name)
			_current_distance = distance # Reset distance
	else:
		# Expanded if
		if _target != null:
			print("OrbitCamera target cleared.")
		_target = null
		_is_detached = true


# Allows other scripts to safely ask what the camera is currently targeting
func get_current_target() -> Spatial:
	# Expanded ternary operator
	if not _is_detached and is_instance_valid(_target):
		return _target
	else:
		return null

# --- Cleanup ---
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# Expanded disconnect check
		if EventBus and EventBus.is_connected("camera_set_target_requested", self, "_on_Camera_Set_Target_Requested"):
			EventBus.disconnect("camera_set_target_requested", self, "_on_Camera_Set_Target_Requested")
		# Expanded global ref check
		if GlobalRefs and GlobalRefs.main_camera == self:
			GlobalRefs.main_camera = null
