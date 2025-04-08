# File: scenes/camera/orbit_camera.gd
# Attach to Camera node in orbit_camera.tscn
# Version 1.6 - Removed LMB Detach functionality

extends Camera

# --- Configurable Properties ---
# (distance, zoom_speed, etc. - remain the same)
var distance: float = 50.0
var min_distance: float = 10.0
var max_distance: float = 200.0
var zoom_speed: float = 1.5
var rotation_speed: float = 0.008
var pitch_min: float = -1.45
var pitch_max: float = 1.45
var smoothing_speed: float = 8.0

# --- Internal State ---
var _target: Spatial = null # Target node
var _yaw: float = 0.0
var _pitch: float = 0.4
var _current_distance: float = 50.0
# var _is_detached: bool = true # Removed

# --- Initialization ---
func _ready():
	_current_distance = distance
	set_as_toplevel(true)
	print("OrbitCamera ready.")
	if not is_instance_valid(_target):
		print("OrbitCamera Warning: Target not set during initialization.")

func initialize(config: Dictionary):
	# ... (Initialization logic remains the same) ...
	# ... Sets distance, speeds, angles from config ...
	_current_distance = self.distance # Ensure distance reset on init
	print("OrbitCamera initialized.")

# --- Input Handling ---
func _unhandled_input(event):
	# --- LMB Detach Removed ---
	# if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
	#     if is_instance_valid(_target): ... (Removed this block)

	# --- MMB Cycle Request Signal Emission (if needed later) ---
	# if event is InputEventMouseButton and event.button_index == BUTTON_MIDDLE and event.pressed:
	#     print("OrbitCamera: Target cycle requested.")
	#     emit_signal("target_cycle_requested")
	#     get_viewport().set_input_as_handled()
	#     return

	# --- Standard Orbit/Zoom Controls ---
	# Allow rotation even without target (camera rotates in place)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(BUTTON_RIGHT):
		_yaw -= event.relative.x * rotation_speed
		_pitch += event.relative.y * rotation_speed
		_pitch = clamp(_pitch, pitch_min, pitch_max)
		get_viewport().set_input_as_handled()

	# Only allow zoom if attached to a target
	if is_instance_valid(_target):
		if event is InputEventMouseButton:
			var zoom_factor = 1.0 + (zoom_speed * 0.1)
			if event.button_index == BUTTON_WHEEL_UP and event.pressed:
				_current_distance = max(min_distance, _current_distance / zoom_factor)
				get_viewport().set_input_as_handled()
			elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
				_current_distance = min(max_distance, _current_distance * zoom_factor)
				get_viewport().set_input_as_handled()

# --- Physics Update ---
func _physics_process(delta):
	if is_instance_valid(_target):
		# --- Attached Mode: Orbit Target ---
		var target_pos = _target.global_transform.origin
		var offset = Vector3.FORWARD.rotated(Vector3.UP, _yaw).rotated(Vector3.RIGHT.rotated(Vector3.UP, _yaw), _pitch)
		var desired_position = target_pos + offset * _current_distance
		global_transform.origin = global_transform.origin.linear_interpolate(desired_position, smoothing_speed * delta)
		look_at(target_pos, Vector3.UP)
	else:
		# --- Detached Mode: Rotate in Place (Only if target becomes invalid externally) ---
		var new_basis = Basis()
		new_basis = new_basis.rotated(Vector3.UP, _yaw)
		new_basis = new_basis.rotated(new_basis.x, _pitch)
		global_transform.basis = new_basis.orthonormalized()

# --- Public Functions ---
func set_target_node(new_target: Spatial):
	# Removed _is_detached flag logic
	if is_instance_valid(new_target):
		if _target != new_target:
			_target = new_target
			print("OrbitCamera target set to: ", new_target.name)
			_current_distance = distance # Reset distance
	else:
		if _target != null: print("OrbitCamera target cleared.")
		_target = null

func get_current_target() -> Spatial:
	# Removed _is_detached check
	return _target if is_instance_valid(_target) else null
