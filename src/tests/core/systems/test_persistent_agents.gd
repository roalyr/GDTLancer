#
# PROJECT: GDTLancer
# MODULE: src/tests/core/systems/test_persistent_agents.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md Section 1.1 System 6
# LOG_REF: 2026-01-30
#

extends "res://addons/gut/test.gd"

var _agent_system: Node = null

func before_each():
	# Reset GameState
	GameState.persistent_agents = {}
	GameState.characters = {}
	GameState.game_time_seconds = 0
	
	# Mock GlobalRefs
	var zonemock = Node.new()
	zonemock.name = "ZoneMock"
	GlobalRefs.current_zone = zonemock
	add_child(zonemock)
	autoqfree(zonemock)

	# Instance AgentSystem - create a Node and set its script
	var agent_script = load("res://src/core/systems/agent_system.gd")
	_agent_system = Node.new()
	_agent_system.set_script(agent_script)
	add_child(_agent_system) # It registers itself to GlobalRefs in _ready
	autoqfree(_agent_system)

func test_persistent_agents_spawn_on_world_init():
	# Mock location availability (AgentSystem checks if dock position exists)
	# We can't easily mock _get_dock_position_in_zone without dependency injection or mocking the scene tree interaction.
	# However, we can test that the system ATTEMPTS to spawn them or sets up the state correctly.
	
	# Let's focus on the State initialization first, as spawning requires complex scene setup.
	
	var agent_id = "persistent_kai"
	var state = _agent_system.get_persistent_agent_state(agent_id)
	
	assert_eq(state.current_location, "station_alpha", "Should have correct home location")
	assert_eq(state.is_known, false, "Should be unknown by default")
	assert_gt(state.character_uid, -1, "Should have a generated character UID")
	
	var char_data = GameState.characters.get(state.character_uid)
	assert_not_null(char_data, "Character data should be created in GameState")
	assert_eq(char_data.character_name, "Kai", "Character name should match template")

func test_persistent_agent_disable_records_state():
	var agent_id = "persistent_kai"
	var state = _agent_system.get_persistent_agent_state(agent_id)
	
	# Simulate disable
	_agent_system._handle_persistent_agent_disable(agent_id)
	
	assert_true(state.is_disabled, "Agent should be marked disabled")
	assert_eq(state.disabled_at_time, 0.0, "Disabled timestmap should be recorded (game time 0)")

func test_persistent_agent_respawns_after_timeout():
	var agent_id = "persistent_kai"
	var state = _agent_system.get_persistent_agent_state(agent_id)
	
	# Disable at time 0
	_agent_system._handle_persistent_agent_disable(agent_id)
	
	# Advance time (less than timeout)
	GameState.game_time_seconds = 200
	_agent_system._check_persistent_agent_respawns()
	assert_true(state.is_disabled, "Agent should still be disabled after 200s")
	
	# Advance time (past timeout of 300s)
	GameState.game_time_seconds = 301
	_agent_system._check_persistent_agent_respawns()
	assert_false(state.is_disabled, "Agent should be respawned after 300s")
	assert_eq(state.disabled_at_time, 0.0, "Timestamp should reset")

func test_persistent_agent_state_persists_across_save_load():
	# This basically tests GameState structure as that's what is saved
	var agent_id = "persistent_juno"
	var state = _agent_system.get_persistent_agent_state(agent_id)
	state.is_known = true
	state.relationship = 50
	
	# "Save" (Simulated)
	var saved_data = GameState.persistent_agents.duplicate(true)
	
	# "Load" (Clear and Restore)
	GameState.persistent_agents = {}
	GameState.persistent_agents = saved_data
	
	var loaded_state = GameState.persistent_agents[agent_id]
	assert_true(loaded_state.is_known, "is_known should persist")
	assert_eq(loaded_state.relationship, 50, "relationship should persist")

func test_known_vs_unknown_agents_state():
	# Setup known agent
	var known_id = "persistent_kai"
	var unknown_id = "persistent_juno"
	
	var state_k = _agent_system.get_persistent_agent_state(known_id)
	state_k.is_known = true
	
	var state_u = _agent_system.get_persistent_agent_state(unknown_id)
	state_u.is_known = false
	
	# Verify state-level filtering (contacts_panel was deleted in sim rework)
	var known_agents = []
	for agent_id in GameState.persistent_agents:
		var state = GameState.persistent_agents[agent_id]
		if state.is_known:
			known_agents.append(agent_id)
	
	assert_true(known_agents.has(known_id), "Known agent Kai should appear in filtered list.")
	assert_false(known_agents.has(unknown_id), "Unknown agent Juno should NOT appear in filtered list.")

func test_contact_discovered_on_dock():
	var agent_id = "persistent_vera"
	var state = _agent_system.get_persistent_agent_state(agent_id)
	# Vera is at station_beta
	assert_eq(state.is_known, false)
	
	# Simulate docking signal
	watch_signals(EventBus)
	_agent_system._on_player_docked("station_beta")
	
	assert_true(state.is_known, "Should discover agent at home station")
	assert_signal_emitted_with_parameters(EventBus, "contact_met", [agent_id], 0)
