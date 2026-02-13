#
# PROJECT: GDTLancer
# MODULE: time_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 7 (Tick Sequence)
# LOG_REF: 2026-02-13
#

extends Node

## TimeSystem: Pure clock — tracks real-time accumulation and emits tick signals.
##
## This system is ONLY a timer. It does NOT call any other systems directly.
## When WORLD_TICK_INTERVAL_SECONDS elapses, it emits world_event_tick_triggered
## on EventBus. SimulationEngine listens to that signal and orchestrates the
## full tick sequence (Grid → Bridge → Agent → Chronicle).
##
## All upkeep/entropy/cost logic has been moved to BridgeSystems (TASK_6).

var _accumulated_seconds: float = 0.0

func _ready():
	GlobalRefs.set_time_system(self)
	print("TimeSystem Ready (pure clock mode).")


# --- Public API ---

## Advances game time by the given number of seconds.
## Triggers world event ticks whenever the accumulator crosses the interval threshold.
func advance_game_time(seconds_to_add: int) -> void:
	if seconds_to_add <= 0:
		return

	GameState.game_time_seconds += seconds_to_add

	# Emit signal for UI updates every time time is added
	if EventBus and EventBus.has_signal("game_time_advanced"):
		EventBus.emit_signal("game_time_advanced", seconds_to_add)

	# Accumulate and fire world ticks as needed
	_accumulated_seconds += float(seconds_to_add)
	while _accumulated_seconds >= Constants.WORLD_TICK_INTERVAL_SECONDS:
		_accumulated_seconds -= Constants.WORLD_TICK_INTERVAL_SECONDS
		_emit_world_tick()


## Returns the current game time in seconds.
func get_current_game_time() -> int:
	return GameState.game_time_seconds


# --- Private ---

## Emits the world tick signal. SimulationEngine handles everything else.
func _emit_world_tick() -> void:
	if EventBus:
		EventBus.emit_signal("world_event_tick_triggered", Constants.WORLD_TICK_INTERVAL_SECONDS)
