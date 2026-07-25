# PROJECT: GDTLancer
# MODULE: vessel_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.5
# LOG_REF: 2026-07-26 00:56:00

extends Node

var vessels: Dictionary = {} # vessel_id -> VesselData

func _ready() -> void:
	if EventBus.has_signal("tick_advanced"):
		EventBus.connect("tick_advanced", self, "_on_tick_advanced")

func register_vessel(vessel) -> void:
	if vessel and not vessel.vessel_id.empty():
		vessels[vessel.vessel_id] = vessel

func get_vessel(vessel_id: String):
	return vessels.get(vessel_id, null)

func start_journey(vessel_id: String, destination_node: String, travel_ticks: int, current_tick: int) -> bool:
	var vessel = get_vessel(vessel_id)
	if not vessel or vessel.is_in_transit():
		return false
	vessel.destination_node = destination_node
	vessel.departure_tick = current_tick
	vessel.arrival_tick = current_tick + travel_ticks
	vessel.status = "IN_TRANSIT"
	return true

func _on_tick_advanced(current_tick: int, _delta_ticks: int) -> void:
	for v_id in vessels:
		var vessel = vessels[v_id]
		if vessel.is_in_transit() and current_tick >= vessel.arrival_tick:
			vessel.current_node = vessel.destination_node
			vessel.destination_node = ""
			vessel.status = "DOCKED"
			EventBus.emit_signal("vessel_arrived", vessel.vessel_id, vessel.current_node)

func serialize() -> Dictionary:
	var serialized_vessels: Dictionary = {}
	for v_id in vessels:
		serialized_vessels[v_id] = vessels[v_id].serialize()
	return {
		"vessels": serialized_vessels
	}

func deserialize(data: Dictionary) -> void:
	vessels.clear()
	var raw_vessels = data.get("vessels", {})
	var VesselDataClass = load("res://src/core/simulation/vessel_data.gd")
	for v_id in raw_vessels:
		var v = VesselDataClass.new()
		v.deserialize(raw_vessels[v_id])
		vessels[v_id] = v

func reset() -> void:
	vessels.clear()
