#
# PROJECT: GDTLancer
# MODULE: time_system.gd
# STATUS: Level 2 - Implementation
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-27-Senior-Dev
#

extends Node

var _accumulated_seconds: float = 0.0

func _ready():
	GlobalRefs.set_time_system(self)
	print("TimeSystem Ready.")


# --- Public API ---
func advance_game_time(seconds_to_add: int):
	if seconds_to_add <= 0:
		return

	GameState.game_time_seconds += seconds_to_add
	
	# Update session stats
	if GameState.session_stats:
		GameState.session_stats.time_played_seconds += seconds_to_add

	# Emit signal for UI updates every time time is added
	if EventBus and EventBus.has_signal("game_time_advanced"):
		EventBus.emit_signal("game_time_advanced", seconds_to_add)

	# Handle world ticks
	_accumulated_seconds += float(seconds_to_add)
	while _accumulated_seconds >= Constants.WORLD_TICK_INTERVAL_SECONDS:
		_accumulated_seconds -= Constants.WORLD_TICK_INTERVAL_SECONDS
		_trigger_world_event_tick()


func get_current_game_time() -> int:
	return GameState.game_time_seconds


# --- Private Logic ---
func _trigger_world_event_tick():
	#print("--- WORLD EVENT TICK TRIGGERED ---")

	# Emit the global signal with the amount of time that this tick represents.
	if EventBus:
		EventBus.emit_signal("world_event_tick_triggered", Constants.WORLD_TICK_INTERVAL_SECONDS)

	# Call the Character System to apply the Credits Upkeep cost for the player character.
	if is_instance_valid(GlobalRefs.character_system):
		var player_uid = GlobalRefs.character_system.get_player_character_uid()
		if player_uid != -1:
			GlobalRefs.character_system.apply_upkeep_cost(player_uid, Constants.DEFAULT_UPKEEP_COST)
