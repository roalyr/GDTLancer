# PROJECT: GDTLancer
# MODULE: test_vessels.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.5
# LOG_REF: 2026-07-26 00:56:00

extends "res://addons/gut/test.gd"

var VesselDataScript = load("res://src/core/simulation/vessel_data.gd")
var VesselManagerScript = load("res://src/core/simulation/vessel_manager.gd")

var _vessel_manager = null
var _arrived_vessels = []

func before_each():
	_vessel_manager = autoqfree(VesselManagerScript.new())
	_arrived_vessels.clear()
	add_child(_vessel_manager)
	if EventBus.has_signal("vessel_arrived"):
		if EventBus.is_connected("vessel_arrived", self, "_on_vessel_arrived"):
			EventBus.disconnect("vessel_arrived", self, "_on_vessel_arrived")
		EventBus.connect("vessel_arrived", self, "_on_vessel_arrived")

func after_each():
	if EventBus.has_signal("vessel_arrived") and EventBus.is_connected("vessel_arrived", self, "_on_vessel_arrived"):
		EventBus.disconnect("vessel_arrived", self, "_on_vessel_arrived")
	if is_instance_valid(_vessel_manager):
		_vessel_manager.queue_free()

func _on_vessel_arrived(vessel_id: String, arrival_node: String):
	_arrived_vessels.append({"vessel_id": vessel_id, "node": arrival_node})

func test_register_and_retrieve_vessel():
	var v = VesselDataScript.new()
	v.vessel_id = "vessel_01"
	v.display_name = "Starlight Courier"
	v.current_node = "station_alpha"
	
	_vessel_manager.register_vessel(v)
	var retrieved = _vessel_manager.get_vessel("vessel_01")
	assert_not_null(retrieved, "Registered vessel should be retrievable")
	assert_eq(retrieved.display_name, "Starlight Courier", "Display name should match")

func test_vessel_journey_and_arrival():
	var v = VesselDataScript.new()
	v.vessel_id = "vessel_02"
	v.current_node = "station_alpha"
	_vessel_manager.register_vessel(v)

	# Start journey: target station_beta, 3 ticks travel time, started at tick 10
	var success = _vessel_manager.start_journey("vessel_02", "station_beta", 3, 10)
	assert_true(success, "Journey should start successfully")
	assert_true(v.is_in_transit(), "Vessel should be in transit")

	# Tick 11: Not arrived yet
	EventBus.emit_signal("tick_advanced", 11, 1)
	assert_true(v.is_in_transit(), "Vessel should still be in transit at tick 11")
	assert_eq(_arrived_vessels.size(), 0, "No arrival signal yet")

	# Tick 13: Arrived!
	EventBus.emit_signal("tick_advanced", 13, 2)
	assert_false(v.is_in_transit(), "Vessel should no longer be in transit")
	assert_eq(v.current_node, "station_beta", "Current node should be updated to station_beta")
	assert_eq(_arrived_vessels.size(), 1, "Arrival signal should be emitted")
	assert_eq(_arrived_vessels[0]["vessel_id"], "vessel_02", "Arrival signal payload vessel_id should match")
	assert_eq(_arrived_vessels[0]["node"], "station_beta", "Arrival signal payload node should match")

func test_vessel_serialization():
	var v = VesselDataScript.new()
	v.vessel_id = "vessel_03"
	v.display_name = "Wanderer"
	v.current_node = "node_a"
	v.destination_node = "node_b"
	v.status = "IN_TRANSIT"
	v.departure_tick = 5
	v.arrival_tick = 15
	_vessel_manager.register_vessel(v)

	var data = _vessel_manager.serialize()
	var new_manager = VesselManagerScript.new()
	new_manager.deserialize(data)

	var deserialized_vessel = new_manager.get_vessel("vessel_03")
	assert_not_null(deserialized_vessel, "Deserialized manager should contain vessel_03")
	assert_eq(deserialized_vessel.current_node, "node_a", "Current node should match")
	assert_eq(deserialized_vessel.destination_node, "node_b", "Destination node should match")
	assert_eq(deserialized_vessel.arrival_tick, 15, "Arrival tick should match")
	assert_eq(deserialized_vessel.status, "IN_TRANSIT", "Status should match")
	new_manager.free()
