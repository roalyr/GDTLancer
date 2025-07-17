# File: scenes/camera/components/camera_rotation_controller.gd
# Purpose: Manages camera rotation, including PID-based smoothing and mouse input.
# This is a component of the main OrbitCamera.

extends Node
class_name CameraRotationController

# --- References ---
var _camera: Camera = null
var _yaw_pid: PIDController = null
var _pitch_pid: PIDController = null
const PIDControllerScript = preload("res://core/utils/pid_controller.gd")

# --- Configuration (Copied from OrbitCamera) ---
var pitch_min: float = -1.45
var pitch_max: float = 1.45
var pid_yaw_kp: float = 10.0
var pid_yaw_ki: float = 0.01
var pid_yaw_kd: float = 0.1
var pid_pitch_kp: float = 10.0
var pid_pitch_ki: float = 0.01
var pid_pitch_kd: float = 0.1
var pid_integral_limit: float = 10.0
var pid_output_limit_multiplier: float = 100.0
var _rotation_max_speed: float = 15.0
var _rotation_input_curve: float = 1.1

# --- State ---
var yaw: float = PI
var pitch: float = 0.25
var _rotation_input_active: bool = false
var _is_externally_rotating: bool = false
var _target_yaw_speed: float = 0.0
var _target_pitch_speed: float = 0.0
var _current_yaw_speed: float = 0.0
var _current_pitch_speed: float = 0.0


# --- Initialization ---
func initialize(camera_node: Camera, config: Dictionary):
	_camera = camera_node
	
	# Set configuration from the main camera script
	pitch_min = config.get("pitch_min", pitch_min)
	pitch_max = config.get("pitch_max", pitch_max)
	pid_yaw_kp = config.get("pid_yaw_kp", pid_yaw_kp)
	pid_yaw_ki = config.get("pid_yaw_ki", pid_yaw_ki)
	pid_yaw_kd = config.get("pid_yaw_kd", pid_yaw_kd)
	pid_pitch_kp = config.get("pid_pitch_kp", pid_pitch_kp)
	pid_pitch_ki = config.get("pid_pitch_ki", pid_pitch_ki)
	pid_pitch_kd = config.get("pid_pitch_kd", pid_pitch_kd)
	pid_integral_limit = config.get("pid_integral_limit", pid_integral_limit)
	pid_output_limit_multiplier = config.get("pid_output_limit_multiplier", pid_output_limit_multiplier)
	_rotation_max_speed = config.get("_rotation_max_speed", _rotation_max_speed)
	_rotation_input_curve = config.get("_rotation_input_curve", _rotation_input_curve)
	
	yaw = config.get("initial_yaw", PI)
	pitch = config.get("initial_pitch", 0.25)

	# Instantiate and Initialize PID Controllers
	if PIDControllerScript:
		_yaw_pid = PIDControllerScript.new()
		_pitch_pid = PIDControllerScript.new()
		add_child(_yaw_pid) # Ensure it's freed with the node
		add_child(_pitch_pid)

		var output_limit = _rotation_max_speed * pid_output_limit_multiplier
		_yaw_pid.initialize(pid_yaw_kp, pid_yaw_ki, pid_yaw_kd, pid_integral_limit, output_limit)
		_pitch_pid.initialize(pid_pitch_kp, pid_pitch_ki, pid_pitch_kd, pid_integral_limit, output_limit)
	else:
		printerr("CameraRotationController Error: Failed to preload PIDController script!")


# --- Public Methods ---
func handle_input(event: InputEvent):
	if event is InputEventMouseMotion:
		if _rotation_input_active or _is_externally_rotating:
			var input_x = event.relative.x
			var input_y = event.relative.y

			var strength_x = pow(abs(input_x), _rotation_input_curve) * sign(input_x)
			var strength_y = pow(abs(input_y), _rotation_input_curve) * sign(input_y)

			var input_scale_factor = 0.01
			_target_yaw_speed = -strength_x * input_scale_factor * _rotation_max_speed
			_target_pitch_speed = -strength_y * input_scale_factor * _rotation_max_speed

			_target_yaw_speed = clamp(_target_yaw_speed, -_rotation_max_speed, _rotation_max_speed)
			_target_pitch_speed = clamp(_target_pitch_speed, -_rotation_max_speed, _rotation_max_speed)

			get_viewport().set_input_as_handled()

func physics_update(delta: float):
	if not is_instance_valid(_yaw_pid) or not is_instance_valid(_pitch_pid):
		return

	var rot_active = _rotation_input_active or _is_externally_rotating
	if not rot_active:
		_target_yaw_speed = 0.0
		_target_pitch_speed = 0.0

	var error_yaw = _target_yaw_speed - _current_yaw_speed
	var error_pitch = _target_pitch_speed - _current_pitch_speed

	var yaw_accel = _yaw_pid.update(error_yaw, delta)
	var pitch_accel = _pitch_pid.update(error_pitch, delta)

	_current_yaw_speed += yaw_accel * delta
	_current_pitch_speed += pitch_accel * delta

	yaw += _current_yaw_speed * delta
	pitch -= _current_pitch_speed * delta
	pitch = clamp(pitch, pitch_min, pitch_max)

	_target_yaw_speed = 0.0
	_target_pitch_speed = 0.0

func set_rotation_input_active(is_active: bool):
	_rotation_input_active = is_active
	if is_active:
		_is_externally_rotating = false
	reset_pids()

func set_is_rotating(rotating: bool):
	if not _rotation_input_active:
		_is_externally_rotating = rotating
	reset_pids()

func reset_pids():
	if is_instance_valid(_yaw_pid): _yaw_pid.reset()
	if is_instance_valid(_pitch_pid): _pitch_pid.reset()
	_current_yaw_speed = 0.0
	_current_pitch_speed = 0.0
