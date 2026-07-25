# PROJECT: GDTLancer
# MODULE: world_clock.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §1
# LOG_REF: 2026-07-26 00:56:00

extends Node

var current_tick: int = 0

func advance(ticks: int = 1) -> void:
	if ticks <= 0:
		return
	current_tick += ticks
	EventBus.emit_signal("tick_advanced", current_tick, ticks)

func serialize() -> Dictionary:
	return {
		"current_tick": current_tick
	}

func deserialize(data: Dictionary) -> void:
	if data.has("current_tick"):
		current_tick = int(data["current_tick"])

func reset() -> void:
	current_tick = 0
