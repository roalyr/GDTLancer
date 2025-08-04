# File: tests/core/systems/test_time_system.gd
# Version: 5.1 - Corrected assert_not_null syntax.

extends GutTest

var TimeSystem = load("res://core/systems/time_system.gd")
var time_system_instance = null
var mock_character_system = null


func before_each():
	time_system_instance = TimeSystem.new()
	add_child_autofree(time_system_instance)

	mock_character_system = double("res://core/systems/character_system.gd").new()
	stub(mock_character_system, "apply_upkeep_cost").to_do_nothing()
	add_child_autofree(mock_character_system)

	time_system_instance._character_system = mock_character_system
	# Corrected assertion for this version of GUT
	assert_not_null(EventBus, "EventBus autoload must be present.")


func after_each():
	time_system_instance = null
	mock_character_system = null


func test_initialization():
	assert_eq(time_system_instance.get_current_tu(), 0)


func test_add_time_units_below_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(50)
	assert_eq(time_system_instance.get_current_tu(), 50)
	assert_signal_not_emitted(EventBus, "world_event_tick_triggered")
	assert_call_count(mock_character_system, "apply_upkeep_cost", 0, [])


func test_add_time_units_exactly_at_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(100)
	assert_eq(time_system_instance.get_current_tu(), 0)
	assert_signal_emitted(EventBus, "world_event_tick_triggered")
	assert_call_count(mock_character_system, "apply_upkeep_cost", 1, [])


func test_add_time_units_above_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(120)
	assert_eq(time_system_instance.get_current_tu(), 20)
	assert_signal_emitted(EventBus, "world_event_tick_triggered")
	assert_call_count(mock_character_system, "apply_upkeep_cost", 1, [])


func test_add_time_units_triggers_multiple_ticks():
	watch_signals(EventBus)
	time_system_instance.add_time_units(250)
	assert_eq(time_system_instance.get_current_tu(), 50)
	assert_signal_emit_count(EventBus, "world_event_tick_triggered", 2)
	assert_call_count(mock_character_system, "apply_upkeep_cost", 2, [])


func test_add_zero_or_negative_time_units():
	watch_signals(EventBus)
	time_system_instance.add_time_units(0)
	time_system_instance.add_time_units(-10)
	assert_eq(time_system_instance.get_current_tu(), 0)
	assert_signal_not_emitted(EventBus, "world_event_tick_triggered")
	assert_call_count(mock_character_system, "apply_upkeep_cost", 0, [])
