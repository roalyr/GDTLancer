# File: tests/autoload/test_event_bus.gd
# GUT Test Script for EventBus.gd Autoload
# Version 1.3 - Adjusted for revised signal_catcher logic

extends GutTest

const SignalCatcher = preload("res://tests/helpers/signal_catcher.gd")
var listener = null

func before_each():
	listener = Node.new()
	listener.set_script(SignalCatcher)
	add_child_autofree(listener)
	listener.reset()

func after_each():
	# Disconnect signals manually if needed
	if EventBus.is_connected("agent_spawned", listener, "_on_signal_received"):
		EventBus.disconnect("agent_spawned", listener, "_on_signal_received")
	if EventBus.is_connected("camera_set_target_requested", listener, "_on_signal_received"):
		EventBus.disconnect("camera_set_target_requested", listener, "_on_signal_received")
	if EventBus.is_connected("agent_reached_destination", listener, "_on_signal_received"):
		EventBus.disconnect("agent_reached_destination", listener, "_on_signal_received")

# --- Test Methods ---

func test_agent_spawned_signal_emission_and_parameters():
	var connect_error = EventBus.connect("agent_spawned", listener, "_on_signal_received")
	assert_eq(connect_error, OK, "Connect agent_spawned.")
	watch_signals(EventBus)
	var dummy_agent_body = Node.new(); add_child_autofree(dummy_agent_body)
	var dummy_init_data = {"name": "TestDummy", "speed": 100}

	EventBus.emit_signal("agent_spawned", dummy_agent_body, dummy_init_data)

	assert_signal_emitted(EventBus, "agent_spawned", "agent_spawned emitted.")
	var received_args_raw = listener.get_last_args()
	assert_true(received_args_raw != null, "Listener received signal.")

	if received_args_raw != null:
		# agent_spawned emits 2 args. Our catcher stores [arg1, arg2, null, null, null]
		# We only care about the first 2 elements.
		assert_true(received_args_raw.size() >= 2, "Listener should capture at least 2 potential args.")
		# Check the actual arguments passed
		assert_eq(received_args_raw[0], dummy_agent_body, "Listener arg 1 check.")
		assert_eq(received_args_raw[1], dummy_init_data, "Listener arg 2 check.")

	prints("Tested EventBus: agent_spawned signal")


func test_camera_set_target_requested_with_null():
	var connect_error = EventBus.connect("camera_set_target_requested", listener, "_on_signal_received")
	assert_eq(connect_error, OK, "Connect camera_set_target_requested.")
	watch_signals(EventBus)

	EventBus.emit_signal("camera_set_target_requested", null) # Emit ONE argument: null

	assert_signal_emitted(EventBus, "camera_set_target_requested", "Signal should emit.")
	var received_args_raw = listener.get_last_args()
	assert_true(received_args_raw != null, "Listener received signal (null target).")

	if received_args_raw != null:
		# camera_set_target_requested emits 1 arg. Catcher stores [null, null, null, null, null]
		assert_true(received_args_raw.size() >= 1, "Listener should capture at least 1 potential arg.")
		# Check the actual first argument passed
		assert_eq(received_args_raw[0], null, "Listener arg 1 should be null.")

	prints("Tested EventBus: camera_set_target_requested (null)")

# ... (test_signal_not_emitted and test_signal_emit_count remain the same) ...

func test_signal_not_emitted_when_not_called():
	 watch_signals(EventBus)
	 assert_signal_not_emitted(EventBus, "zone_loaded", "zone_loaded should not have been emitted yet.")
	 var received_args = listener.get_last_args()
	 assert_true(received_args == null, "Listener should NOT have received signal data.")
	 prints("Tested EventBus: assert_signal_not_emitted")

func test_signal_emit_count():
	var connect_error = EventBus.connect("agent_reached_destination", listener, "_on_signal_received")
	assert_eq(connect_error, OK, "Connect agent_reached_destination.")
	watch_signals(EventBus)
	var dummy_agent = Node.new(); add_child_autofree(dummy_agent)
	var dummy_agent2 = Node.new(); add_child_autofree(dummy_agent2)

	EventBus.emit_signal("agent_reached_destination", dummy_agent)
	EventBus.emit_signal("agent_reached_destination", dummy_agent2)
	EventBus.emit_signal("agent_reached_destination", dummy_agent)

	assert_signal_emit_count(EventBus, "agent_reached_destination", 3, "Signal should have emitted 3 times total.")
	prints("Tested EventBus: assert_signal_emit_count")
