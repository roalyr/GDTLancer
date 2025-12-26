# File: tests/modules/piloting/test_ship_controller_ai.gd
# Unit tests for ShipControllerAI (Sprint 9)

extends "res://addons/gut/test.gd"

const ShipControllerAI = preload("res://src/modules/piloting/ship_controller_ai.gd")

class DummyAgentBody:
	extends RigidBody
	var agent_uid: int = 1
	var last_command: Dictionary = {}

	func command_stop():
		last_command = {"name": "stop"}

	func command_move_to(pos: Vector3):
		last_command = {"name": "move_to", "pos": pos}

	func command_approach(target: Spatial):
		last_command = {"name": "approach", "target": target}

	func command_flee(target: Spatial):
		last_command = {"name": "flee", "target": target}

	func despawn():
		last_command = {"name": "despawn"}


class DummyCombatSystem:
	extends Node
	var hull_percent_by_uid := {}
	var in_combat_by_uid := {}

	func is_in_combat(uid: int) -> bool:
		return bool(in_combat_by_uid.get(uid, false))

	func get_hull_percent(uid: int) -> float:
		return float(hull_percent_by_uid.get(uid, 1.0))


var _agent: DummyAgentBody
var _player: DummyAgentBody
var _ai: Node
var _combat: DummyCombatSystem


func before_each():
	_agent = DummyAgentBody.new()
	_agent.translation = Vector3.ZERO
	add_child_autofree(_agent)

	_ai = ShipControllerAI.new()
	_agent.add_child(_ai)
	_ai._ready()  # ensure parent references are cached

	_player = DummyAgentBody.new()
	_player.agent_uid = 999
	_player.translation = Vector3(10, 0, 0)
	add_child_autofree(_player)
	GlobalRefs.player_agent_body = _player

	_combat = DummyCombatSystem.new()
	add_child_autofree(_combat)
	GlobalRefs.combat_system = _combat


func after_each():
	GlobalRefs.player_agent_body = null
	GlobalRefs.combat_system = null
	_agent = null
	_player = null
	_ai = null
	_combat = null


func test_initial_state_is_idle():
	assert_eq(_ai._current_state, ShipControllerAI.AIState.IDLE)


func test_initialize_hostile_transitions_to_patrol():
	_ai.initialize({"hostile": true})
	assert_eq(_ai._current_state, ShipControllerAI.AIState.PATROL)


func test_scan_for_target_returns_player_when_in_range():
	_ai.is_hostile = true
	_ai.aggro_range = 50.0
	var found = _ai._scan_for_target()
	assert_true(is_instance_valid(found))
	assert_eq(found, _player)


func test_combat_transitions_to_flee_when_hull_critical():
	_ai.is_hostile = true
	_ai._target_agent = _player
	_ai._current_state = ShipControllerAI.AIState.COMBAT

	_combat.in_combat_by_uid[_agent.agent_uid] = true
	_combat.hull_percent_by_uid[_agent.agent_uid] = 0.1

	_ai._process_combat(0.1)
	assert_eq(_ai._current_state, ShipControllerAI.AIState.FLEE)
	assert_eq(_agent.last_command.get("name"), "flee")
