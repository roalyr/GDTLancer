# tests/helpers/mock_event_bus.gd
extends Node

# Define the signals we want to be able to test for.
signal agent_reached_destination(agent_body)

# We can add more signals here as needed for other tests.

# This method exists so the test doesn't crash, but it won't do anything.
# We will check if the signal was emitted instead.
func emit_signal(signal_name, arg1=null, arg2=null, arg3=null, arg4=null, arg5=null):
	# We can add logging here for debugging if needed, e.g.:
	# print("MockEventBus received emit_signal: ", signal_name)
	pass
