# File: tests/core/systems/test_agent_spawner.gd
# GUT Test for the AgentSystem (formerly AgentSpawner).
# Version: 2.1 - Corrected signal payload inspection.

extends GutTest

# --- Test Subjects ---
const AgentSystem = preload("res://src/core/systems/agent_system.gd")
const CharacterTemplate = preload("res://database/definitions/character_template.gd")
const AgentTemplate = preload("res://database/definitions/agent_template.gd")

# --- Helpers ---
const MOCK_AGENT_SCENE = "res://src/tests/helpers/mock_agent.tscn"
const SignalCatcher = preload("res://src/tests/helpers/signal_catcher.gd")

# --- Test State ---
var agent_system_instance = null
var mock_agent_container = null
var signal_catcher = null
const PLAYER_UID = 0


func before_each():
	# 1. Clean and set up the global state
	GameState.characters.clear()
	GameState.player_character_uid = -1

	# 2. Create mock scene nodes required by the AgentSystem
	mock_agent_container = Node.new()
	mock_agent_container.name = "MockAgentContainer"
	add_child_autofree(mock_agent_container)
	GlobalRefs.agent_container = mock_agent_container

	# 3. Create a mock player character in the GameState
	var player_char = CharacterTemplate.new()
	GameState.characters[PLAYER_UID] = player_char
	GameState.player_character_uid = PLAYER_UID

	# 4. Instantiate the system we are testing
	agent_system_instance = AgentSystem.new()
	add_child_autofree(agent_system_instance)

	# 5. Setup signal catcher
	signal_catcher = SignalCatcher.new()
	add_child_autofree(signal_catcher)
	EventBus.connect("agent_spawned", signal_catcher, "_on_signal_received")
	EventBus.connect("player_spawned", signal_catcher, "_on_signal_received")


func after_each():
	# Clean up global state and references
	GameState.characters.clear()
	GameState.player_character_uid = -1
	GlobalRefs.agent_container = null
	
	if EventBus.is_connected("agent_spawned", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("agent_spawned", signal_catcher, "_on_signal_received")
	if EventBus.is_connected("player_spawned", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("player_spawned", signal_catcher, "_on_signal_received")

	agent_system_instance = null


# --- Test Cases ---

func test_spawn_player_on_zone_loaded():
	watch_signals(EventBus) # Watch EventBus to inspect signal history
	
	# Simulate the zone_loaded signal being emitted
	agent_system_instance._on_Zone_Loaded(null, null, mock_agent_container)
	
	# Assert that a player agent was created in the container
	assert_eq(mock_agent_container.get_child_count(), 1, "AgentContainer should have one child after player spawn.")
	
	# Assert that the correct signals were fired
	assert_signal_emitted(EventBus, "agent_spawned")
	assert_signal_emitted(EventBus, "player_spawned")

	# --- FIX: Specifically get the parameters for the agent_spawned signal ---
	var captured_args = get_signal_parameters(EventBus, "agent_spawned")
	assert_not_null(captured_args, "Should have captured parameters for agent_spawned.")
	
	var spawned_body = captured_args[0]
	var init_data = captured_args[1]
	
	assert_true(is_instance_valid(spawned_body), "Signal should contain a valid agent body.")
	assert_eq(init_data["agent_uid"], PLAYER_UID, "Spawned agent should be linked to the player UID.")


func test_spawn_agent_with_overrides():
	var template = AgentTemplate.new()
	var overrides = {"agent_type": "test_npc", "template_id": "npc_fighter"}
	var npc_uid = 123
	
	var agent_body = agent_system_instance.spawn_agent(MOCK_AGENT_SCENE, Vector3.ZERO, template, overrides, npc_uid)

	assert_not_null(agent_body, "Spawner should return a valid KinematicBody instance.")
	assert_eq(agent_body.agent_type, "test_npc", "Agent type override should be applied.")
	assert_eq(agent_body.template_id, "npc_fighter", "Template ID override should be applied.")
	assert_eq(agent_body.agent_uid, npc_uid, "Agent UID should be set correctly.")
