#
# PROJECT: GDTLancer
# MODULE: test_time_system.gd
# STATUS: Level 2 - Implementation
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-27-Senior-Dev
#

extends GutTest

# --- Test Subjects ---
const TimeSystem = preload("res://src/core/systems/time_system.gd")
const CharacterSystem = preload("res://src/core/systems/character_system.gd") # For mocking

# --- Test State ---
var time_system_instance = null
var mock_character_system = null
const PLAYER_UID = 0

func before_each():
	# 1. Clean and set up the global state for the test
	GameState.game_time_seconds = 0
	GameState.player_character_uid = PLAYER_UID

	# 2. Create a mock CharacterSystem and set it in GlobalRefs
	mock_character_system = double(CharacterSystem).new()
	add_child_autofree(mock_character_system)
	GlobalRefs.character_system = mock_character_system

	# 3. Stub the methods that TimeSystem will call
	stub(mock_character_system, "get_player_character_uid").to_return(PLAYER_UID)
	stub(mock_character_system, "apply_upkeep_cost").to_do_nothing()

	# 4. Instantiate the system we are testing
	time_system_instance = TimeSystem.new()
	add_child_autofree(time_system_instance)

func after_each():
	# Clean up global state to ensure test isolation
	GameState.game_time_seconds = 0
	GameState.player_character_uid = -1
	GlobalRefs.character_system = null
	time_system_instance = null

# --- Test Cases ---

func test_initialization():
	assert_eq(time_system_instance.get_current_game_time(), 0, "Initial game time should be 0.")

func test_advance_game_time_below_threshold():
	watch_signals(EventBus)
	time_system_instance.advance_game_time(5)
	assert_eq(GameState.game_time_seconds, 5, "GameState.game_time_seconds should be 5.")
	assert_signal_not_emitted(EventBus, "world_event_tick_triggered")
	assert_not_called(mock_character_system, "apply_upkeep_cost")

func test_advance_game_time_exactly_at_threshold():
	watch_signals(EventBus)
	time_system_instance.advance_game_time(Constants.WORLD_TICK_INTERVAL_SECONDS)
	assert_eq(GameState.game_time_seconds, Constants.WORLD_TICK_INTERVAL_SECONDS, "Game time should be equal to tick interval.")
	assert_signal_emitted(EventBus, "world_event_tick_triggered")
	assert_called(mock_character_system, "apply_upkeep_cost", [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])

func test_advance_game_time_above_threshold():
	watch_signals(EventBus)
	time_system_instance.advance_game_time(Constants.WORLD_TICK_INTERVAL_SECONDS + 5)
	assert_eq(GameState.game_time_seconds, Constants.WORLD_TICK_INTERVAL_SECONDS + 5, "Game time should include overflow.")
	assert_signal_emitted(EventBus, "world_event_tick_triggered")
	assert_call_count(mock_character_system, "apply_upkeep_cost", 1, [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])

func test_advance_game_time_triggers_multiple_ticks():
	watch_signals(EventBus)
	time_system_instance.advance_game_time((Constants.WORLD_TICK_INTERVAL_SECONDS * 2) + 5)
	assert_eq(GameState.game_time_seconds, (Constants.WORLD_TICK_INTERVAL_SECONDS * 2) + 5, "Game time should accumulate.")
	assert_signal_emit_count(EventBus, "world_event_tick_triggered", 2)
	assert_call_count(mock_character_system, "apply_upkeep_cost", 2, [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])
