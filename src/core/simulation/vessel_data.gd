# PROJECT: GDTLancer
# MODULE: vessel_data.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.5
# LOG_REF: 2026-07-26 00:56:00

extends Reference
class_name VesselData

var vessel_id: String = ""
var display_name: String = ""
var current_node: String = ""
var destination_node: String = ""
var departure_tick: int = 0
var arrival_tick: int = 0
var assigned_npc_ids: Array = []
var status: String = "DOCKED" # DOCKED, IN_TRANSIT, DISABLED

func is_in_transit() -> bool:
	return status == "IN_TRANSIT"

func serialize() -> Dictionary:
	return {
		"vessel_id": vessel_id,
		"display_name": display_name,
		"current_node": current_node,
		"destination_node": destination_node,
		"departure_tick": departure_tick,
		"arrival_tick": arrival_tick,
		"assigned_npc_ids": assigned_npc_ids.duplicate(),
		"status": status
	}

func deserialize(data: Dictionary) -> void:
	vessel_id = String(data.get("vessel_id", ""))
	display_name = String(data.get("display_name", ""))
	current_node = String(data.get("current_node", ""))
	destination_node = String(data.get("destination_node", ""))
	departure_tick = int(data.get("departure_tick", 0))
	arrival_tick = int(data.get("arrival_tick", 0))
	assigned_npc_ids = data.get("assigned_npc_ids", []).duplicate()
	status = String(data.get("status", "DOCKED"))
