#
# PROJECT: GDTLancer
# MODULE: test_time_system.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 7 (Tick Sequence)
# LOG_REF: 2026-02-13
#

extends GutTest

## Unit tests for TimeSystem: game time advancement and world tick triggering.
## TimeSystem is now a PURE CLOCK — it only tracks time and emits tick signals.
## Upkeep costs are handled by BridgeSystems (TASK_6 rework).

# --- Test Subjects ---
const TimeSystem = preload("res://src/core/systems/time_system.gd")

# --- Test State ---
var time_system_instance = null

func before_each():
	# 1. Clean and set up the global state for the test
	GameState.game_time_seconds = 0
	GameState.player_character_uid = 0

	# 2. Instantiate the system we are testing
	time_system_instance = TimeSystem.new()
	add_child_autofree(time_system_instance)

func after_each():
	# Clean up global state to ensure test isolation
	GameState.game_time_seconds = 0
	GameState.player_character_uid = -1
	time_system_instance = null

# --- Test Cases ---

func test_initialization():
	assert_eq(time_system_instance.get_current_game_time(), 0, "Initial game time should be 0.")

func test_advance_game_time_below_threshold():
	watch_signals(EventBus)
	time_system_instance.advance_game_time(5)
	assert_eq(GameState.game_time_seconds, 5, "GameState.game_time_seconds should be 5.")
	assert_signal_not_emitted(EventBus, "world_event_tick_triggered")

func test_advance_game_time_exactly_at_threshold():
	watch_signals(EventBus)
	time_system_instance.advance_game_time(Constants.WORLD_TICK_INTERVAL_SECONDS)
	assert_eq(GameState.game_time_seconds, Constants.WORLD_TICK_INTERVAL_SECONDS, "Game time should be equal to tick interval.")
	assert_signal_emitted(EventBus, "world_event_tick_triggered")

func test_advance_game_time_above_threshold():
	watch_signals(EventBus)
	time_system_instance.advance_game_time(Constants.WORLD_TICK_INTERVAL_SECONDS + 5)
	assert_eq(GameState.game_time_seconds, Constants.WORLD_TICK_INTERVAL_SECONDS + 5, "Game time should include overflow.")
	assert_signal_emitted(EventBus, "world_event_tick_triggered")

func test_advance_game_time_triggers_multiple_ticks():
	watch_signals(EventBus)
	time_system_instance.advance_game_time((Constants.WORLD_TICK_INTERVAL_SECONDS * 2) + 5)
	assert_eq(GameState.game_time_seconds, (Constants.WORLD_TICK_INTERVAL_SECONDS * 2) + 5, "Game time should accumulate.")
	assert_signal_emit_count(EventBus, "world_event_tick_triggered", 2)
