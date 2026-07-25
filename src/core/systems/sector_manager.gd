# PROJECT: GDTLancer
# MODULE: sector_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_EXPLORATION-PILLARS.md §4
# LOG_REF: 2026-07-26 02:15:00

extends Node
class_name SectorManager

signal sector_travel_started(source_sector_id, dest_sector_id)
signal sector_travel_completed(dest_sector_id, supplies_cost, tick_cost)
signal environmental_event_triggered(sector_id, event_type, details)

var NodeGateSystemClass = load("res://src/core/systems/node_gate_system.gd")
var gate_system = null

func _ready() -> void:
	gate_system = NodeGateSystemClass.new()

func travel_to_sector(source_sector_id: String, dest_sector_id: String, player_inventory: Array = [], supplies_cost: int = 1, tick_cost: int = 2) -> Dictionary:
	# Check gating rules first
	if gate_system != null and gate_system.is_node_locked(dest_sector_id, player_inventory):
		var reason = gate_system.get_lock_reason(dest_sector_id, player_inventory)
		return {
			"success": false,
			"reason": reason
		}

	var current_supplies: int = GameState.get_player_track("supplies")
	if current_supplies < supplies_cost:
		return {
			"success": false,
			"reason": "Insufficient supplies (" + str(current_supplies) + "/" + str(supplies_cost) + ")"
		}

	emit_signal("sector_travel_started", source_sector_id, dest_sector_id)

	# Deduct supply cost
	GameState.apply_player_track_delta("supplies", -supplies_cost)

	# Advance World Clock
	var world_clock = get_node_or_null("/root/WorldClock")
	if world_clock and world_clock.has_method("advance"):
		world_clock.advance(tick_cost)

	# Evaluate environmental events on arrival sector
	var events = evaluate_sector_thresholds(dest_sector_id)

	emit_signal("sector_travel_completed", dest_sector_id, supplies_cost, tick_cost)

	return {
		"success": true,
		"dest_sector_id": dest_sector_id,
		"supplies_cost": supplies_cost,
		"tick_cost": tick_cost,
		"environmental_events": events
	}

func evaluate_sector_thresholds(sector_id: String) -> Array:
	var triggered_events: Array = []
	var tracks = GameState.get_sector_tracks(sector_id)

	var stability = tracks.get("stability", 5)
	var resources = tracks.get("resources", 5)
	var security = tracks.get("security", 5)

	if stability <= 2:
		var event = {
			"event_type": "ANOMALOUS_UNREST",
			"severity": "CRITICAL",
			"description": "Outer margin instability causing severe structural distortion."
		}
		triggered_events.append(event)
		GameState.add_sector_tag(sector_id, "anomalous_unrest")
		emit_signal("environmental_event_triggered", sector_id, "ANOMALOUS_UNREST", event)

	if resources <= 2:
		var event = {
			"event_type": "RESOURCE_COLLAPSE",
			"severity": "HIGH",
			"description": "Critical depletion of life support and mining materials."
		}
		triggered_events.append(event)
		GameState.add_sector_tag(sector_id, "resource_collapse")
		emit_signal("environmental_event_triggered", sector_id, "RESOURCE_COLLAPSE", event)

	if security <= 2:
		var event = {
			"event_type": "PIRACY_OUTBREAK",
			"severity": "MEDIUM",
			"description": "Lack of security emboldening local raiders."
		}
		triggered_events.append(event)
		GameState.add_sector_tag(sector_id, "piracy_outbreak")
		emit_signal("environmental_event_triggered", sector_id, "PIRACY_OUTBREAK", event)

	return triggered_events
