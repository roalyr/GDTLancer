#
# PROJECT: GDTLancer
# MODULE: camera_particles_controller.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §6.1, §6.3, §7; TRUTH_DOCS_Particle shaders_Godot_3.6.md note plus §Render modes; TRUTH_SIMULATION-GRAPH.md §1
# LOG_REF: 2026-05-16 23:40:29
#

# Controls the space dust CPUParticles attached to the gameplay camera,
# adjusting emission, velocity, and emitter position from camera movement.
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
var _effect_active: bool = true


func _ready():
	# Resolve the owning camera even when emitters are grouped under a container.
	_camera = _resolve_camera_ancestor()
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


func set_effect_active(is_active: bool, clear_existing: bool = false) -> void:
	_effect_active = is_active
	visible = is_active
	_apply_idle_state(true)
	if clear_existing and has_method("restart"):
		restart()
		emitting = false


func _process(delta: float):
	# Ensure camera is valid and initialized
	if not _initialized or not is_instance_valid(_camera):
		_apply_idle_state(false)
		return

	if not _effect_active:
		_apply_idle_state(true)
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


func _apply_idle_state(reset_previous_position: bool) -> void:
	if reset_previous_position and is_instance_valid(_camera):
		_previous_camera_pos = _camera.global_transform.origin
	if self.emitting:
		self.emitting = false
	if self.gravity != Vector3.ZERO:
		self.gravity = Vector3.ZERO
	if self.transform.origin != Vector3.ZERO:
		self.transform.origin = Vector3.ZERO


func _resolve_camera_ancestor() -> Camera:
	var current_node = get_parent()
	while is_instance_valid(current_node):
		if current_node is Camera:
			return current_node
		current_node = current_node.get_parent()
	return null
