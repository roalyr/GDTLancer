# File: core/systems/time_system.gd
# Purpose: Manages the passage of abstract game time (TU) and triggers world events.
# Version: 2.0 - Refactored to be stateless and correctly apply player upkeep.

extends Node

func _ready():
	GlobalRefs.set_time_system(self)
	print("TimeSystem Ready.")


# --- Public API ---
func add_time_units(tu_to_add: int):
	if tu_to_add <= 0:
		return

	GameState.current_tu += tu_to_add

	while GameState.current_tu >= Constants.TIME_CLOCK_MAX_TU:
		_trigger_world_event_tick()


func get_current_tu() -> int:
	return GameState.current_tu


# --- Private Logic ---
func _trigger_world_event_tick():
	# 1. Decrement the clock by the max amount for one tick.
	GameState.current_tu -= Constants.TIME_CLOCK_MAX_TU

	#print("--- WORLD EVENT TICK TRIGGERED ---")

	# 2. Emit the global signal with the amount of TU that this tick represents.
	if EventBus:
		EventBus.emit_signal("world_event_tick_triggered", Constants.TIME_CLOCK_MAX_TU)

	# 3. Call the Character System to apply the WP Upkeep cost for the player character.
	if is_instance_valid(GlobalRefs.character_system):
		var player_uid = GlobalRefs.character_system.get_player_character_uid()
		if player_uid != -1:
			GlobalRefs.character_system.apply_upkeep_cost(player_uid, Constants.DEFAULT_UPKEEP_COST)
