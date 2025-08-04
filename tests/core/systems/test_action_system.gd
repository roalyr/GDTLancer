# File: tests/core/systems/test_action_system.gd
# Version: 2.3 - Validates action check integration.

extends GutTest

var ActionSystem = load("res://core/systems/action_system.gd")
var action_system_instance = null
var mock_action_resource = load("res://tests/data/test_action.tres")
const TICK_TU_VALUE = 100


func before_each():
	action_system_instance = ActionSystem.new()
	add_child_autofree(action_system_instance)
	assert_not_null(mock_action_resource)
	assert_not_null(EventBus)


func after_each():
	action_system_instance = null


func test_request_action_requires_approach():
	var mock_character = Node.new()
	add_child_autofree(mock_character)

	var result = action_system_instance.request_action(
		mock_character, mock_action_resource, Constants.ActionApproach.CAUTIOUS
	)
	assert_true(result)
	assert_eq(action_system_instance._active_actions.size(), 1)

	var action_data = action_system_instance._active_actions.values()[0]
	assert_eq(action_data.action_approach, Constants.ActionApproach.CAUTIOUS)


func test_action_completion_emits_signal_with_payload():
	var mock_character = Node.new()
	add_child_autofree(mock_character)

	# Watch the ActionSystem instance itself for the new signal.
	watch_signals(action_system_instance)

	action_system_instance.request_action(
		mock_character, mock_action_resource, Constants.ActionApproach.RISKY
	)

	# Simulate a world tick to complete the action.
	EventBus.emit_signal("world_event_tick_triggered", TICK_TU_VALUE)

	assert_signal_emitted(action_system_instance, "action_completed")

	# Check the payload of the emitted signal.
	var payload = get_signal_parameters(action_system_instance, "action_completed")[2]
	assert_not_null(payload)
	assert_has(payload, "result_tier")
	assert_has(payload, "roll_total")
