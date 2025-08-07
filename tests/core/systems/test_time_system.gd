# File: tests/core/systems/test_time_system.gd
# Version: 2.1 - Corrected GUT assertion syntax.

extends GutTest

# --- Test Subjects ---
const TimeSystem = preload("res://core/systems/time_system.gd")
const CharacterSystem = preload("res://core/systems/character_system.gd") # For mocking

# --- Test State ---
var time_system_instance = null
var mock_character_system = null
const PLAYER_UID = 0

func before_each():
	# 1. Clean and set up the global state for the test
	GameState.current_tu = 0
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
	GameState.current_tu = 0
	GameState.player_character_uid = -1
	GlobalRefs.character_system = null
	time_system_instance = null

# --- Test Cases ---

func test_initialization():
	assert_eq(time_system_instance.get_current_tu(), 0, "Initial TU should be 0 from GameState.")

func test_add_time_units_below_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(5)
	assert_eq(GameState.current_tu, 5, "GameState.current_tu should be 5.")
	assert_signal_not_emitted(EventBus, "world_event_tick_triggered")
	assert_not_called(mock_character_system, "apply_upkeep_cost")

func test_add_time_units_exactly_at_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(Constants.TIME_CLOCK_MAX_TU)
	assert_eq(GameState.current_tu, 0, "TU should reset to 0 after a tick.")
	assert_signal_emitted(EventBus, "world_event_tick_triggered")
	assert_called(mock_character_system, "apply_upkeep_cost", [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])

func test_add_time_units_above_threshold():
	watch_signals(EventBus)
	time_system_instance.add_time_units(Constants.TIME_CLOCK_MAX_TU + 5)
	assert_eq(GameState.current_tu, 5, "TU should be 5 after one tick.")
	assert_signal_emitted(EventBus, "world_event_tick_triggered")
	assert_call_count(mock_character_system, "apply_upkeep_cost", 1, [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])

func test_add_time_units_triggers_multiple_ticks():
	watch_signals(EventBus)
	time_system_instance.add_time_units((Constants.TIME_CLOCK_MAX_TU * 2) + 5)
	assert_eq(GameState.current_tu, 5, "TU should be 5 after two ticks.")
	assert_signal_emit_count(EventBus, "world_event_tick_triggered", 2)
	assert_call_count(mock_character_system, "apply_upkeep_cost", 2, [PLAYER_UID, Constants.DEFAULT_UPKEEP_COST])
