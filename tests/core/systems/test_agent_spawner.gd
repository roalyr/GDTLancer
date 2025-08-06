# tests/core/systems/test_agent_spawner.gd
extends GutTest

const AgentSpawnerScript = preload("res://core/systems/agent_system.gd")
const AgentTemplate = preload("res://core/resource/agent_template.gd")
const MOCK_AGENT_SCENE = "res://tests/helpers/mock_agent.tscn"
const SignalCatcher = preload("res://tests/helpers/signal_catcher.gd")
const TestAgentBodyScript = preload("res://tests/helpers/test_agent_body.gd")

var spawner
var mock_agent_container
var mock_current_zone
var signal_catcher


func before_each():
	spawner = AgentSpawnerScript.new()
	add_child(spawner)

	mock_agent_container = Node.new()
	mock_agent_container.name = "MockAgentContainer"
	add_child(mock_agent_container)
	GlobalRefs.agent_container = mock_agent_container

	mock_current_zone = Spatial.new()
	mock_current_zone.name = "MockCurrentZone"
	add_child(mock_current_zone)
	GlobalRefs.current_zone = mock_current_zone

	signal_catcher = SignalCatcher.new()
	EventBus.connect("agent_spawned", signal_catcher, "_on_signal_received")
	EventBus.connect("player_spawned", signal_catcher, "_on_signal_received")


func after_each():
	GlobalRefs.agent_container = null
	GlobalRefs.current_zone = null

	if EventBus.is_connected("agent_spawned", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("agent_spawned", signal_catcher, "_on_signal_received")
	if EventBus.is_connected("player_spawned", signal_catcher, "_on_signal_received"):
		EventBus.disconnect("player_spawned", signal_catcher, "_on_signal_received")

	if is_instance_valid(spawner):
		spawner.free()
	if is_instance_valid(mock_agent_container):
		mock_agent_container.free()
	if is_instance_valid(mock_current_zone):
		mock_current_zone.free()
	if is_instance_valid(signal_catcher):
		signal_catcher.free()


func test_spawn_agent_successfully():
	signal_catcher.reset()
	var template = AgentTemplate.new()
	var agent_body = spawner.spawn_agent(MOCK_AGENT_SCENE, Vector3.ZERO, template)

	assert_not_null(agent_body, "Spawner should return a valid KinematicBody instance.")
	assert_eq(mock_agent_container.get_child_count(), 1, "AgentContainer should have one child.")
	assert_not_null(
		agent_body.init_data, "The agent's `initialize` method should have been called."
	)
	assert_eq(
		agent_body.init_data.template, template, "Agent was initialized with the correct template."
	)

	var captured_args = signal_catcher.get_last_args()
	assert_not_null(captured_args, "The 'agent_spawned' signal should have been emitted.")
	assert_eq(
		captured_args[0],
		agent_body,
		"Signal should include the spawned agent body as the first argument."
	)


func test_spawn_agent_fails_with_bad_path():
	var template = AgentTemplate.new()
	var agent_body = spawner.spawn_agent("res://bad/path.tscn", Vector3.ZERO, template)
	assert_null(agent_body, "Spawner should return null for a non-existent scene path.")
	assert_eq(mock_agent_container.get_child_count(), 0, "No children should be added on failure.")


func test_spawn_player_finds_entry_point():
	signal_catcher.reset()
	var mock_entry_point = Position3D.new()
	mock_entry_point.name = Constants.ENTRY_POINT_NAMES[0]
	mock_entry_point.global_transform.origin = Vector3(100, 100, 100)
	mock_current_zone.add_child(mock_entry_point)

	spawner.spawn_player()

	var captured_args = signal_catcher.get_last_args()
	assert_not_null(captured_args, "The 'player_spawned' signal should have been emitted.")
	var player_body = captured_args[0]

	var expected_pos = Vector3(100, 105, 115)
	# CORRECTED: Assert each component of the Vector3 individually.
	assert_almost_eq(
		player_body.global_transform.origin.x,
		expected_pos.x,
		0.001,
		"Player spawn X position should be correct."
	)
	assert_almost_eq(
		player_body.global_transform.origin.y,
		expected_pos.y,
		0.001,
		"Player spawn Y position should be correct."
	)
	assert_almost_eq(
		player_body.global_transform.origin.z,
		expected_pos.z,
		0.001,
		"Player spawn Z position should be correct."
	)
