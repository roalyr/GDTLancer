# File: core/systems/time_system.gd
# Purpose: Manages the passage of abstract game time (TU) and triggers world events.
# Version: 1.1 - Removed has_method check for better testability.

extends Node

# --- Configuration ---
const TIME_CLOCK_MAX_TU = 100

# --- State ---
var _current_tu: int = 0 setget , get_current_tu

# --- System References ---
var _character_system: Node = null


func _ready():
	GlobalRefs.set_time_system(self)
	print("TimeSystem Ready.")


# --- Public API ---
func add_time_units(tu_to_add: int):
	if tu_to_add <= 0:
		return

	_current_tu += tu_to_add

	while _current_tu >= TIME_CLOCK_MAX_TU:
		_trigger_world_event_tick()


func get_current_tu() -> int:
	return _current_tu


# --- Private Logic ---
func _trigger_world_event_tick():
	# 1. Decrement the clock by the max amount for one tick.
	_current_tu -= TIME_CLOCK_MAX_TU

	print("--- WORLD EVENT TICK TRIGGERED ---")

	# 2. Emit the global signal with the amount of TU that this tick represents.
	if EventBus:
		EventBus.emit_signal("world_event_tick_triggered", TIME_CLOCK_MAX_TU)  #MODIFIED

	# 3. Call the Character System to apply the WP Upkeep cost.
	if is_instance_valid(_character_system):
		_character_system.apply_upkeep_cost()
	else:
		print("TimeSystem: Placeholder - Would call CharacterSystem to apply WP upkeep cost.")
