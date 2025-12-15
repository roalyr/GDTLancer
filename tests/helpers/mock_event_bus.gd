# tests/helpers/mock_event_bus.gd
## Mock EventBus for unit testing - forwards emit_signal to actual signal emission.
extends Node

# Define the signals we want to be able to test for.
signal agent_reached_destination(agent_body)
signal agent_damaged(agent_body, damage_amount, source_agent)
signal agent_disabled(agent_body)
signal combat_initiated(player, hostiles)
signal combat_ended(result)
signal world_event_tick_triggered(tu_amount)


## Routes emit_signal calls to actual Godot signal emission for proper test signal tracking.
func emit_signal(signal_name: String, arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
	match signal_name:
		"agent_reached_destination":
			.emit_signal(signal_name, arg1)
		"agent_damaged":
			.emit_signal(signal_name, arg1, arg2, arg3)
		"agent_disabled":
			.emit_signal(signal_name, arg1)
		"combat_initiated":
			.emit_signal(signal_name, arg1, arg2)
		"combat_ended":
			.emit_signal(signal_name, arg1)
		"world_event_tick_triggered":
			.emit_signal(signal_name, arg1)
		_:
			printerr("MockEventBus: Unknown signal '%s'" % signal_name)
