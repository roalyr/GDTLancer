# File: res://scenes/camera/camera_particles_controller.gd
# Purpose: Controls the space dust (CPUParticles) effect attached to the camera,
#          adjusting emission, velocity, and emitter position based on
#          the CAMERA's movement speed. (GLES2 Compatible)
extends CPUParticles  # Use CPUParticles for GLES2

# --- Tunable Parameters ---
# Camera speed threshold below which particles stop emitting strongly
export var min_camera_speed_threshold: float = 0.5
# Camera speed at which the effect reaches maximum intensity
export var max_camera_speed_for_effect: float = 50.0
# --- NEW: How much to shift emitter opposite to velocity vector ---
export var velocity_offset_scale: float = -250.0

# --- Node References ---
var _camera: Camera = null

# --- State ---
var _previous_camera_pos: Vector3 = Vector3.ZERO
var _initialized: bool = false


func _ready():
	# Get camera reference (assuming this node is a direct child of the camera)
	_camera = get_parent() as Camera
	if not _camera:
		printerr("CameraParticlesController Error: Parent node is not a Camera!")
		set_process(false)
		return

	# Set initial state directly on the node
	self.emitting = false
	self.gravity = Vector3.ZERO
	self.transform.origin = Vector3.ZERO  # Ensure offset starts at zero

	# Defer setting previous position until the first process frame
	# to ensure the camera has its initial position set.
	call_deferred("_initialize_position")


func _initialize_position():
	if is_instance_valid(_camera):
		_previous_camera_pos = _camera.global_transform.origin
		_initialized = true
		#print("CameraParticlesController Initialized.")
	else:
		printerr("CameraParticlesController Error: Camera invalid during deferred init.")
		set_process(false)


func _process(delta: float):
	# Ensure camera is valid and initialized
	if not _initialized or not is_instance_valid(_camera):
		# Keep particles off if camera isn't ready
		if self.emitting:
			self.emitting = false
		if self.gravity != Vector3.ZERO:
			self.gravity = Vector3.ZERO
		# Reset offset if camera becomes invalid
		if self.transform.origin != Vector3.ZERO:
			self.transform.origin = Vector3.ZERO
		return

	# --- Calculate Camera Movement ---
	var current_pos: Vector3 = _camera.global_transform.origin
	# Vector representing the camera's displacement over the last frame in global space
	var position_delta_global: Vector3 = current_pos - _previous_camera_pos
	var camera_speed: float = 0.0

	if delta > 0.0001:  # Avoid division by zero or large spikes on first frame/lag
		camera_speed = position_delta_global.length() / delta

	# Store current position for the next frame's calculation
	_previous_camera_pos = current_pos

	# --- Apply Velocity Offset ---
	# Calculate the desired offset in the opposite direction of the global movement.
	# Since this script/node is a child of the camera, we need to transform the global
	# offset direction into the camera's local space before applying it.
	var global_offset_vector = -position_delta_global * velocity_offset_scale
	# Transform the global offset vector into the camera's local coordinate system
	var local_offset_vector = _camera.global_transform.basis.xform_inv(global_offset_vector)

	# Set the local position offset of this CPUParticles node
	self.transform.origin = local_offset_vector

	# --- Control Emission (based on speed) ---
	if camera_speed > min_camera_speed_threshold:
		if not self.emitting:
			self.emitting = true
	else:
		if self.emitting:
			self.emitting = false
