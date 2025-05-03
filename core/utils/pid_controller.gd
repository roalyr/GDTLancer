# File: core/utils/pid_controller.gd
# Version: 1.0
# Purpose: A reusable PID controller class.

extends Node  # Or use 'extends Reference' if node features aren't needed
class_name PIDController

# --- Gains ---
var kp: float = 1.0 setget set_kp
var ki: float = 0.0 setget set_ki
var kd: float = 0.0 setget set_kd

# --- Limits ---
var integral_limit: float = 1000.0 setget set_integral_limit
var output_limit: float = 50.0 setget set_output_limit

# --- State ---
var integral: float = 0.0
var previous_error: float = 0.0


# --- Initialization ---
func initialize(
	p_gain: float, i_gain: float, d_gain: float, i_limit: float = 1000.0, o_limit: float = 50.0
):
	kp = p_gain
	ki = i_gain
	kd = d_gain
	integral_limit = abs(i_limit)  # Ensure positive limit
	output_limit = abs(o_limit)  # Ensure positive limit
	reset()  # Start with a clean state


# --- Update ---
# Calculates the PID output based on the current error and delta time.
# Returns the clamped PID output value.
func update(error: float, delta: float) -> float:
	if delta <= 0.0001:
		# Avoid division by zero or instability with tiny delta
		return 0.0

	# --- Proportional Term ---
	var p_term = kp * error

	# --- Integral Term ---
	integral += error * delta
	# Clamp integral to prevent windup
	integral = clamp(integral, -integral_limit, integral_limit)
	var i_term = ki * integral

	# --- Derivative Term ---
	var derivative = (error - previous_error) / delta
	var d_term = kd * derivative

	# --- Update State for Next Iteration ---
	previous_error = error

	# --- Calculate & Clamp Output ---
	var output = p_term + i_term + d_term
	output = clamp(output, -output_limit, output_limit)

	return output


# --- Reset ---
# Resets the integral and previous error state.
func reset():
	integral = 0.0
	previous_error = 0.0


# --- Setters (Optional, for runtime tweaking if needed) ---
func set_kp(value: float):
	kp = value


func set_ki(value: float):
	ki = value


func set_kd(value: float):
	kd = value


func set_integral_limit(value: float):
	integral_limit = abs(value)


func set_output_limit(value: float):
	output_limit = abs(value)
