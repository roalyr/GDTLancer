extends GutTest

var NavigationSystem = load("res://src/core/agents/components/navigation_system.gd")
var MovementSystem = load("res://src/core/agents/components/movement_system.gd")
const SignalCatcher = preload("res://src/tests/helpers/signal_catcher.gd")
const TestAgentBodyScript = preload("res://src/tests/helpers/test_agent_body.gd")

var agent_body
var nav_system
var mock_movement_system
var signal_catcher


func before_each():
	signal_catcher = SignalCatcher.new()
	EventBus.connect("agent_reached_destination", signal_catcher, "_on_signal_received")

	agent_body = partial_double(TestAgentBodyScript).new()
	agent_body.name = "TestAgent"

	mock_movement_system = double(MovementSystem).new()
	# CORRECTED: Stub methods to silence GUT warnings and provide default return values.
	stub(mock_movement_system, "_ready").to_return(null)
	stub(mock_movement_system, "apply_deceleration").to_return(null)
	stub(mock_movement_system, "apply_braking").to_return(false)
	stub(mock_movement_system, "apply_rotation").to_return(null)
	stub(mock_movement_system, "apply_acceleration").to_return(null)
	stub(mock_movement_system, "max_move_speed").to_return(100.0)

	nav_system = NavigationSystem.new()
	nav_system.name = "NavigationSystem"

	agent_body.add_child(mock_movement_system)
	agent_body.add_child(nav_system)

	get_tree().get_root().add_child(agent_body)

	nav_system._ready()
	nav_system.initialize_navigation({}, mock_movement_system)


func after_each():
	if EventBus.is_connected("agent_reached_destination", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("agent_reached_destination", signal_catcher, "_on_signal_received")

	if is_instance_valid(agent_body):
		agent_body.queue_free()
	if is_instance_valid(signal_catcher):
		signal_catcher.free()


func test_initial_state_is_idle():
	signal_catcher.reset()
	assert_eq(
		nav_system._current_command.type,
		nav_system.CommandType.IDLE,
		"Default command should be IDLE."
	)
	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_deceleration", [0.1])


func test_set_command_stopping():
	signal_catcher.reset()
	nav_system.set_command_stopping()
	assert_eq(nav_system._current_command.type, nav_system.CommandType.STOPPING)
	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_braking", [0.1])


func test_stop_command_emits_reached_destination_signal():
	signal_catcher.reset()
	# This time we need apply_braking to return true to trigger the signal
	stub(mock_movement_system, "apply_braking").to_return(true)

	nav_system.set_command_stopping()
	nav_system.update_navigation(0.1)

	var captured_args = signal_catcher.get_last_args()
	assert_not_null(captured_args, "A signal should have been captured.")
	assert_eq(
		captured_args[0], agent_body, "The first argument of the signal should be the agent_body."
	)


func test_set_command_move_to():
	signal_catcher.reset()
	var target_pos = Vector3(100, 200, 300)
	nav_system.set_command_move_to(target_pos)

	assert_eq(nav_system._current_command.type, nav_system.CommandType.MOVE_TO)
	assert_eq(nav_system._current_command.target_pos, target_pos)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_rotation")


func test_set_command_approach():
	signal_catcher.reset()
	var target_node = TestAgentBodyScript.new()
	agent_body.add_child(target_node)
	# CORRECTED: Move the target so the distance isn't zero.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_approach(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.APPROACH)
	assert_eq(nav_system._current_command.target_node, target_node)

	nav_system.update_navigation(0.1)
	# This assertion will now pass because the distance is > arrival threshold.
	assert_called(mock_movement_system, "apply_rotation")


func test_set_command_orbit():
	signal_catcher.reset()
	var target_node = TestAgentBodyScript.new()
	agent_body.add_child(target_node)
	# Move the target so the distance isn't zero.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_orbit(target_node, 500.0, true)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.ORBIT)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_rotation")


func test_set_command_flee():
	signal_catcher.reset()
	var target_node = TestAgentBodyScript.new()
	agent_body.add_child(target_node)
	# Move the target so there is a direction to flee from.
	target_node.global_transform.origin = Vector3(0, 0, -1000)

	nav_system.set_command_flee(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.FLEE)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_rotation")
	assert_called(mock_movement_system, "apply_acceleration")


func test_set_command_align_to():
	signal_catcher.reset()
	var direction = Vector3.BACK.normalized()
	nav_system.set_command_align_to(direction)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.ALIGN_TO)

	nav_system.update_navigation(0.1)
	assert_called(mock_movement_system, "apply_rotation")
	assert_called(mock_movement_system, "apply_deceleration")


func test_invalid_target_in_update_switches_to_stopping():
	signal_catcher.reset()
	var target_node = TestAgentBodyScript.new()

	nav_system.set_command_approach(target_node)
	assert_eq(nav_system._current_command.type, nav_system.CommandType.APPROACH)

	target_node.free()
	yield(get_tree(), "idle_frame")

	nav_system.update_navigation(0.1)

	assert_eq(nav_system._current_command.type, nav_system.CommandType.STOPPING)
	assert_called(mock_movement_system, "apply_braking")
