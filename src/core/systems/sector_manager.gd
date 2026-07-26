# PROJECT: GDTLancer
# MODULE: sector_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_EXPLORATION-PILLARS.md §4
# LOG_REF: 2026-07-26 08:31:00

extends Node
class_name SectorManager

signal sector_travel_started(source_sector_id, dest_sector_id)
signal sector_travel_completed(dest_sector_id, supplies_cost, tick_cost)

var NodeGateSystemClass = load("res://src/core/systems/node_gate_system.gd")
var gate_system = null

func _ready() -> void:
	gate_system = NodeGateSystemClass.new()

func travel_to_sector(source_sector_id: String, dest_sector_id: String, player_inventory: Array = [], supplies_cost: int = 0, tick_cost: int = 1) -> Dictionary:
	# Check gating rules first
	if gate_system != null and gate_system.is_node_locked(dest_sector_id, player_inventory):
		var reason = gate_system.get_lock_reason(dest_sector_id, player_inventory)
		return {
			"success": false,
			"reason": reason
		}

	emit_signal("sector_travel_started", source_sector_id, dest_sector_id)

	# Advance World Clock on Sector Travel (Mode A)
	var world_clock = get_node_or_null("/root/WorldClock")
	if not is_instance_valid(world_clock):
		world_clock = get_node_or_null("/root/MainGameScene/WorldManager/WorldClock")
	if is_instance_valid(world_clock) and world_clock.has_method("advance"):
		world_clock.advance(tick_cost)

	emit_signal("sector_travel_completed", dest_sector_id, supplies_cost, tick_cost)
	if EventBus != null and EventBus.has_signal("sector_travel_completed"):
		EventBus.emit_signal("sector_travel_completed", dest_sector_id, supplies_cost, tick_cost)

	return {
		"success": true,
		"dest_sector_id": dest_sector_id,
		"supplies_cost": supplies_cost,
		"tick_cost": tick_cost
	}
