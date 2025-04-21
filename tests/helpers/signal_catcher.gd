# File: tests/helpers/signal_catcher.gd
# Helper script for catching signals in GUT tests
# Version 1.2 - Reliably captures first few args, including nulls

extends Node

var _last_signal_args = null # Store arguments from the last signal received

# Generic handler function. Connect signals expecting up to 5 args here.
# It captures the arguments as passed by Godot's signal system.
func _on_signal_received(p1=null, p2=null, p3=null, p4=null, p5=null):
	# Store the arguments directly in an array.
	# The test script is responsible for knowing how many args were
	# actually emitted by a specific signal and checking only those.
	_last_signal_args = [p1, p2, p3, p4, p5]
	# print("Signal Catcher raw args captured: ", _last_signal_args) # For debugging

# Call this in test to get the captured arguments
func get_last_args():
	# Returns the array [p1, p2, p3, p4, p5] as captured
	return _last_signal_args

# Call this in test setup (e.g., before_each) to clear state
func reset():
	_last_signal_args = null
