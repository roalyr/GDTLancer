# File: tests/core/systems/test_character_system.gd
# GUT Test Script for CharacterSystem
# Version: 1.0

extends GutTest

# --- Test Subject ---
var CharacterSystem = load("res://core/systems/character_system.gd")
var character_system_instance = null


# --- Test Setup & Teardown ---
func before_each():
	# Create a fresh instance of the system for each test.
	character_system_instance = CharacterSystem.new()
	add_child_autofree(character_system_instance)
	# The system's _ready() function connects to the EventBus.

	assert_not_null(EventBus, "EventBus must be available for this test.")


func after_each():
	character_system_instance = null


# --- Tests ---


func test_initial_state():
	assert_eq(
		character_system_instance.get_all_characters().size(),
		0,
		"Character list should be empty initially."
	)
	assert_null(
		character_system_instance.get_player_character(),
		"Player character should be null initially."
	)


func test_register_character_agent():
	# Create a mock agent node to be "spawned"
	var mock_agent = Node.new()
	add_child_autofree(mock_agent)  # GUT will clean it up
	var agent_id = mock_agent.get_instance_id()

	# Emit the signal that the system listens for.
	EventBus.emit_signal("agent_spawned", mock_agent, {"agent_type": "character"})

	var all_chars = character_system_instance.get_all_characters()
	assert_eq(all_chars.size(), 1, "There should be one character registered.")
	assert_true(
		all_chars.has(agent_id), "The registered character should have the correct instance ID."
	)
	assert_eq(all_chars[agent_id], mock_agent, "The registered node should be the mock agent.")


func test_ignores_non_character_agent():
	var mock_agent = Node.new()
	add_child_autofree(mock_agent)

	# Emit the signal with a different agent_type.
	EventBus.emit_signal("agent_spawned", mock_agent, {"agent_type": "scenery"})

	assert_eq(
		character_system_instance.get_all_characters().size(),
		0,
		"Non-character agents should be ignored."
	)


func test_register_player_character():
	var mock_player = Node.new()
	add_child_autofree(mock_player)

	# Emit the signal with the is_player flag.
	EventBus.emit_signal(
		"agent_spawned", mock_player, {"agent_type": "character", "is_player": true}
	)

	assert_eq(
		character_system_instance.get_player_character(),
		mock_player,
		"The player character should be set correctly."
	)
	assert_eq(
		character_system_instance.get_all_characters().size(),
		1,
		"The player should also be in the main character list."
	)


func test_unregister_on_destroy():
	var mock_agent = Node.new()
	add_child_autofree(mock_agent)
	EventBus.emit_signal("agent_spawned", mock_agent, {"agent_type": "character"})

	# Verify it was registered
	assert_eq(
		character_system_instance.get_all_characters().size(),
		1,
		"Character should be registered initially."
	)

	# Now, "destroy" the node. This will emit the 'tree_exiting' signal the system connects to.
	mock_agent.queue_free()
	# We must wait for the signal to be processed.
	yield(get_tree(), "idle_frame")

	assert_eq(
		character_system_instance.get_all_characters().size(),
		0,
		"Character should be unregistered after being destroyed."
	)


func test_player_character_is_cleared_on_destroy():
	var mock_player = Node.new()
	add_child_autofree(mock_player)
	EventBus.emit_signal(
		"agent_spawned", mock_player, {"agent_type": "character", "is_player": true}
	)

	# Verify it was registered as the player
	assert_eq(
		character_system_instance.get_player_character(),
		mock_player,
		"Player should be set initially."
	)

	# Destroy the player node
	mock_player.queue_free()
	yield(get_tree(), "idle_frame")

	assert_null(
		character_system_instance.get_player_character(),
		"Player character reference should be null after being destroyed."
	)


func test_apply_upkeep_cost_does_not_crash():
	# This function is currently empty. We just call it to ensure it exists and
	# doesn't cause an error, completing the code coverage.
	character_system_instance.apply_upkeep_cost()
	assert_true(true, "apply_upkeep_cost() should run without error.")
