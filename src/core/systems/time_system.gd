#
# PROJECT: GDTLancer
# MODULE: time_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 7 (Tick Sequence)
# LOG_REF: 2026-02-13
#

extends Node

## TimeSystem: Pure gameplay clock — tracks real-time accumulation only.
##
## This system is ONLY a timer. It does NOT trigger simulation ticks.
## Simulation ticks are event-driven (dock, undock, sector travel, debug).
## The clock just counts gameplay seconds for UI and game-time tracking.
##
## All upkeep/entropy/cost logic has been moved to BridgeSystems (TASK_6).


func _ready():
	GlobalRefs.set_time_system(self)
	print("TimeSystem Ready (pure clock mode).")


# --- Public API ---

## Advances game time by the given number of seconds.
## Only emits game_time_advanced for UI updates. Does NOT trigger sim ticks.
func advance_game_time(seconds_to_add: int) -> void:
	if seconds_to_add <= 0:
		return

	GameState.game_time_seconds += seconds_to_add

	# Emit signal for UI updates every time time is added
	if EventBus and EventBus.has_signal("game_time_advanced"):
		EventBus.emit_signal("game_time_advanced", seconds_to_add)


## Returns the current game time in seconds.
func get_current_game_time() -> int:
	return GameState.game_time_seconds
