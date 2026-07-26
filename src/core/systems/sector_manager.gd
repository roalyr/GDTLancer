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
	if EventBus != null and EventBus.has_signal("tick_advanced"):
		EventBus.connect("tick_advanced", self, "_on_tick_advanced")

func _on_tick_advanced(current_tick: int, _delta_ticks: int) -> void:
	# Trigger random environmental events as World Clock progresses (every 2 ticks)
	if current_tick > 0 and current_tick % 2 == 0:
		var sec_id = GameState.current_sector_id if GameState.current_sector_id != "" else Constants.INITIAL_SECTOR_ID
		trigger_random_environmental_event(sec_id)

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

	# Evaluate random environmental event on arrival sector
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
	var event = trigger_random_environmental_event(sector_id)
	return [event] if not event.empty() else []

func trigger_random_environmental_event(sector_id: String) -> Dictionary:
	var possible_events = [
		{
			"event_type": "ANOMALOUS_UNREST",
			"severity": "CRITICAL",
			"description": "Outer margin instability causing severe structural distortion.",
			"tag": "anomalous_unrest"
		},
		{
			"event_type": "RESOURCE_COLLAPSE",
			"severity": "HIGH",
			"description": "Critical depletion of life support and mining materials.",
			"tag": "resource_collapse"
		},
		{
			"event_type": "PIRACY_OUTBREAK",
			"severity": "MEDIUM",
			"description": "Lack of security emboldening local raiders.",
			"tag": "piracy_outbreak"
		},
		{
			"event_type": "SOLAR_FLARE",
			"severity": "HIGH",
			"description": "Stellar radiation discharge disrupting long-range sensors.",
			"tag": "solar_flare"
		}
	]

	# Pick a random event from the pool
	var idx = randi() % possible_events.size()
	var selected = possible_events[idx]
	var event_dict = {
		"event_type": selected["event_type"],
		"severity": selected["severity"],
		"description": selected["description"]
	}

	GameState.add_sector_tag(sector_id, selected["tag"])
	emit_signal("environmental_event_triggered", sector_id, selected["event_type"], event_dict)
	if EventBus != null:
		EventBus.emit_signal("environmental_event_triggered", sector_id, selected["event_type"], event_dict)
		EventBus.emit_signal("sector_tags_changed", sector_id, GameState.get_sector_tags(sector_id))
	return event_dict
