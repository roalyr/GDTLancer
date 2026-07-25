# PROJECT: GDTLancer
# MODULE: test_world_clock.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §1
# LOG_REF: 2026-07-26 00:56:00

extends "res://addons/gut/test.gd"

var WorldClockScript = load("res://src/core/simulation/world_clock.gd")
var _clock = null
var _emitted_signals = []

func before_each():
	_clock = WorldClockScript.new()
	_emitted_signals.clear()
	if EventBus.has_signal("tick_advanced"):
		if EventBus.is_connected("tick_advanced", self, "_on_tick_advanced"):
			EventBus.disconnect("tick_advanced", self, "_on_tick_advanced")
		EventBus.connect("tick_advanced", self, "_on_tick_advanced")

func after_each():
	if is_instance_valid(_clock):
		_clock.free()
	if EventBus.has_signal("tick_advanced") and EventBus.is_connected("tick_advanced", self, "_on_tick_advanced"):
		EventBus.disconnect("tick_advanced", self, "_on_tick_advanced")

func _on_tick_advanced(current_tick: int, delta_ticks: int):
	_emitted_signals.append({"tick": current_tick, "delta": delta_ticks})

func test_initial_state():
	assert_eq(_clock.current_tick, 0, "Initial tick should be 0")

func test_advance_ticks():
	_clock.advance(1)
	assert_eq(_clock.current_tick, 1, "Tick should advance to 1")
	assert_eq(_emitted_signals.size(), 1, "One signal should be emitted")
	assert_eq(_emitted_signals[0]["tick"], 1, "Signal payload tick should be 1")
	assert_eq(_emitted_signals[0]["delta"], 1, "Signal payload delta should be 1")

	_clock.advance(5)
	assert_eq(_clock.current_tick, 6, "Tick should advance to 6")
	assert_eq(_emitted_signals.size(), 2, "Two signals should be emitted")
	assert_eq(_emitted_signals[1]["tick"], 6, "Signal payload tick should be 6")
	assert_eq(_emitted_signals[1]["delta"], 5, "Signal payload delta should be 5")

func test_advance_invalid_ticks():
	_clock.advance(0)
	assert_eq(_clock.current_tick, 0, "Tick should not advance on 0")
	assert_eq(_emitted_signals.size(), 0, "No signal on 0 ticks")

	_clock.advance(-3)
	assert_eq(_clock.current_tick, 0, "Tick should not advance on negative ticks")
	assert_eq(_emitted_signals.size(), 0, "No signal on negative ticks")

func test_serialization():
	_clock.advance(10)
	var data = _clock.serialize()
	assert_eq(data["current_tick"], 10, "Serialized data should contain current tick")

	var new_clock = WorldClockScript.new()
	new_clock.deserialize(data)
	assert_eq(new_clock.current_tick, 10, "Deserialized clock should have tick 10")
	new_clock.free()
