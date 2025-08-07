# File: tests/core/systems/test_action_system.gd
# GUT Test for the stateless ActionSystem.
# Version: 3.0 - Rewritten for GameState architecture.

extends GutTest

# --- Test Subjects ---
const ActionSystem = preload("res://core/systems/action_system.gd")
const CharacterTemplate = preload("res://core/resource/character_template.gd")
const ActionTemplate = preload("res://core/resource/action_template.gd")

# --- Test State ---
var action_system_instance = null
var mock_character: CharacterTemplate = null
var mock_action: ActionTemplate = null
const PLAYER_UID = 0


func before_each():
	# 1. Clean the global state
	GameState.characters.clear()
	GameState.active_actions.clear()
	GameState.player_character_uid = -1

	# 2. Create mock character and action data
	mock_character = CharacterTemplate.new()
	mock_character.character_name = "Test Character"
	GameState.characters[PLAYER_UID] = mock_character
	GameState.player_character_uid = PLAYER_UID

	mock_action = ActionTemplate.new()
	mock_action.action_name = "Test Action"
	mock_action.tu_cost = 5

	# 3. Instantiate the system we are testing
	action_system_instance = ActionSystem.new()
	add_child_autofree(action_system_instance)
	# Manually call _ready to connect signals for the test
	action_system_instance._ready()


func after_each():
	GameState.characters.clear()
	GameState.active_actions.clear()
	GameState.player_character_uid = -1
	action_system_instance = null


# --- Test Cases ---

func test_request_action_populates_game_state():
	assert_eq(GameState.active_actions.size(), 0, "Active actions should be empty initially.")

	var result = action_system_instance.request_action(
		mock_character, mock_action, Constants.ActionApproach.CAUTIOUS
	)

	assert_true(result, "request_action should return true on success.")
	assert_eq(GameState.active_actions.size(), 1, "There should be one active action in GameState.")

	var action_data = GameState.active_actions.values()[0]
	assert_eq(action_data.character_instance, mock_character, "Action data should store the correct character.")
	assert_eq(action_data.action_template, mock_action, "Action data should store the correct action template.")


func test_action_progresses_on_world_tick():
	action_system_instance.request_action(
		mock_character, mock_action, Constants.ActionApproach.CAUTIOUS
	)
	var action_id = GameState.active_actions.keys()[0]

	# Simulate a world tick that does NOT complete the action
	EventBus.emit_signal("world_event_tick_triggered", 2) # 2 TU passed

	assert_eq(GameState.active_actions[action_id].tu_progress, 2, "Action progress should be 2 TU.")


func test_action_completes_and_emits_signal():
	watch_signals(action_system_instance)
	action_system_instance.request_action(
		mock_character, mock_action, Constants.ActionApproach.RISKY
	)
	assert_eq(GameState.active_actions.size(), 1, "Pre-check: Action should be queued.")

	# Simulate a world tick that completes the action (action costs 5 TU)
	EventBus.emit_signal("world_event_tick_triggered", 10)

	assert_signal_emitted(action_system_instance, "action_completed", "action_completed signal should be emitted.")
	assert_eq(GameState.active_actions.size(), 0, "Action should be removed from GameState after completion.")

	# Verify the signal payload
	var params = get_signal_parameters(action_system_instance, "action_completed")
	assert_eq(params[0], mock_character, "Payload should contain the correct character.")
	assert_eq(params[1], mock_action, "Payload should contain the correct action template.")
	assert_has(params[2], "result_tier", "Payload should contain the result dictionary.")
