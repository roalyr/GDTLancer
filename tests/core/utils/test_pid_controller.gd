# tests/core/utils/test_pid_controller.gd
extends GutTest

var PIDController = load("res://core/utils/pid_controller.gd")
var pid


func before_each():
	pid = PIDController.new()


func after_each():
	if is_instance_valid(pid):
		pid.free()


func test_initialization():
	pid.initialize(1.5, 0.5, 0.75, 50.0, 100.0)
	assert_eq(pid.kp, 1.5, "P gain should be set correctly.")
	assert_eq(pid.ki, 0.5, "I gain should be set correctly.")
	assert_eq(pid.kd, 0.75, "D gain should be set correctly.")
	assert_eq(pid.integral_limit, 50.0, "Integral limit should be set correctly.")
	assert_eq(pid.output_limit, 100.0, "Output limit should be set correctly.")
	assert_eq(pid.integral, 0.0, "Integral should be reset to 0 on initialization.")
	assert_eq(pid.previous_error, 0.0, "Previous error should be reset to 0 on initialization.")


func test_proportional_term():
	pid.initialize(2.0, 0.0, 0.0, 100.0, 100.0)
	var output = pid.update(10.0, 1.0)
	assert_almost_eq(output, 20.0, 0.001, "Output should be kp * error.")


func test_integral_term():
	pid.initialize(0.0, 3.0, 0.0, 100.0, 100.0)
	var output1 = pid.update(5.0, 1.0)  # integral = 5
	assert_almost_eq(output1, 15.0, 0.001, "Output should be ki * integral (1st step).")
	var output2 = pid.update(5.0, 1.0)  # integral = 10
	assert_almost_eq(output2, 30.0, 0.001, "Output should be ki * integral (2nd step).")


func test_integral_limit_clamping():
	pid.initialize(0.0, 1.0, 0.0, 10.0, 100.0)
	pid.update(12.0, 1.0)  # integral would be 12, but clamped to 10
	assert_almost_eq(pid.integral, 10.0, 0.001, "Integral should be clamped to its positive limit.")
	assert_almost_eq(
		pid.update(1.0, 1.0), 10.0, 0.001, "Output should use the clamped integral value."
	)
	pid.reset()
	pid.update(-15.0, 1.0)  # integral would be -15, but clamped to -10
	assert_almost_eq(
		pid.integral, -10.0, 0.001, "Integral should be clamped to its negative limit."
	)


func test_derivative_term():
	pid.initialize(0.0, 0.0, 4.0, 100.0, 100.0)
	pid.update(5.0, 1.0)  # previous_error is now 5
	var output = pid.update(7.0, 1.0)  # derivative = (7 - 5) / 1 = 2
	assert_almost_eq(output, 8.0, 0.001, "Output should be kd * derivative.")


func test_output_limit_clamping():
	pid.initialize(10.0, 0.0, 0.0, 100.0, 50.0)
	var output = pid.update(10.0, 1.0)  # P term would be 100
	assert_almost_eq(output, 50.0, 0.001, "Output should be clamped to positive output_limit.")

	pid.initialize(-10.0, 0.0, 0.0, 100.0, 50.0)
	output = pid.update(10.0, 1.0)  # P term would be -100
	assert_almost_eq(output, -50.0, 0.001, "Output should be clamped to negative output_limit.")


func test_reset_function():
	pid.initialize(1.0, 1.0, 1.0, 100.0, 100.0)
	pid.update(10.0, 1.0)
	assert_ne(pid.integral, 0.0, "Integral should not be zero after an update.")
	assert_ne(pid.previous_error, 0.0, "Previous error should not be zero after an update.")

	pid.reset()
	assert_eq(pid.integral, 0.0, "Integral should be zero after reset.")
	assert_eq(pid.previous_error, 0.0, "Previous error should be zero after reset.")


func test_zero_delta_returns_zero():
	pid.initialize(1.0, 1.0, 1.0, 100.0, 100.0)
	var output = pid.update(10.0, 0.0)
	assert_eq(output, 0.0, "Update with delta <= 0 should return 0 to prevent division by zero.")
