# File: tests/core/systems/test_event_system.gd
# Unit tests for EventSystem encounter triggering and hostile management (Sprint 9)
# Test coverage: spawn logic, cooldown management, signal emission, edge cases

extends "res://addons/gut/test.gd"

const EventSystem = preload("res://src/core/systems/event_system.gd")


## Mock spawner that simulates NPC spawning.
class DummySpawner:
	extends Node
	var spawn_count: int = 0

	func spawn_npc_from_template(_template_path: String, position: Vector3, _overrides: Dictionary = {}) -> RigidBody:
		spawn_count += 1
		var npc: RigidBody = RigidBody.new()
		npc.gravity_scale = 0.0
		npc.set("agent_uid", 1000 + spawn_count)
		npc.translation = position
		return npc


## Mock player agent.
class DummyPlayer:
	extends RigidBody
	var agent_uid: int = 1
	
	func _ready():
		gravity_scale = 0.0


var _event_system: Node
var _spawner: DummySpawner
var _player: DummyPlayer


## Setup before each test: initialize event system with mocks.
func before_each() -> void:
	_spawner = DummySpawner.new()
	add_child_autofree(_spawner)
	GlobalRefs.agent_spawner = _spawner

	_player = DummyPlayer.new()
	_player.translation = Vector3.ZERO
	add_child_autofree(_player)
	GlobalRefs.player_agent_body = _player

	_event_system = EventSystem.new()
	add_child_autofree(_event_system)
	_event_system._ready()


## Cleanup after each test: clear global references.
func after_each() -> void:
	GlobalRefs.agent_spawner = null
	GlobalRefs.player_agent_body = null
	_event_system = null
	_spawner = null
	_player = null


# ============ SUCCESS PATH TESTS ============

## Test: Tick decrements cooldown without triggering encounter.
func test_tick_decrements_cooldown_without_triggering() -> void:
	watch_signals(EventBus)
	_event_system._encounter_cooldown_seconds = 5
	_event_system._on_world_event_tick_triggered(2)
	assert_eq(_event_system._encounter_cooldown_seconds, 3, "Cooldown should decrement by tick amount")
	assert_signal_not_emitted(EventBus, "combat_initiated", "Should not trigger with active cooldown")


## Test: Cooldown doesn't go below zero.
func test_cooldown_does_not_go_negative() -> void:
	_event_system._active_hostiles = [Node.new()]
	add_child_autofree(_event_system._active_hostiles[0])
	_event_system._encounter_cooldown_seconds = 2
	_event_system._on_world_event_tick_triggered(10)
	assert_eq(_event_system._encounter_cooldown_seconds, 0, "Cooldown should clamp at zero")


## Test: Force encounter emits combat_initiated signal.
func test_force_encounter_emits_combat_initiated() -> void:
	watch_signals(EventBus)
	_event_system.force_encounter()
	assert_signal_emitted(EventBus, "combat_initiated", "Force encounter should emit combat_initiated")


## Test: Get active hostiles returns a copy, not reference.
func test_get_active_hostiles_returns_copy() -> void:
	var hostile: Node = Node.new()
	add_child_autofree(hostile)
	_event_system._active_hostiles = [hostile]
	var result: Array = _event_system.get_active_hostiles()
	result.clear()
	assert_eq(_event_system._active_hostiles.size(), 1, "Original array should remain unchanged")


# ============ SIGNAL EMISSION TESTS ============

## Test: Emits combat_ended when last hostile is disabled.
func test_emits_combat_ended_when_last_hostile_removed() -> void:
	watch_signals(EventBus)
	var hostile: Node = Node.new()
	add_child_autofree(hostile)
	_event_system._active_hostiles = [hostile]
	_event_system._on_agent_disabled(hostile)
	assert_signal_emitted(EventBus, "combat_ended", "Should emit combat_ended when all hostiles removed")
	assert_eq(_event_system._active_hostiles.size(), 0, "Hostiles should be empty after removal")


## Test: Handles agent despawning signal.
func test_handles_agent_despawning_signal() -> void:
	watch_signals(EventBus)
	var hostile: Node = Node.new()
	add_child_autofree(hostile)
	_event_system._active_hostiles = [hostile]
	_event_system._on_agent_despawning(hostile)
	assert_signal_emitted(EventBus, "combat_ended", "Should emit combat_ended on despawn")


## Test: Multiple hostiles must all be removed before combat_ended.
func test_multiple_hostiles_all_removed_for_combat_end() -> void:
	watch_signals(EventBus)
	var hostile1: Node = Node.new()
	var hostile2: Node = Node.new()
	add_child_autofree(hostile1)
	add_child_autofree(hostile2)
	_event_system._active_hostiles = [hostile1, hostile2]
	_event_system._on_agent_disabled(hostile1)
	assert_signal_not_emitted(EventBus, "combat_ended", "Should not end with hostiles remaining")
	_event_system._on_agent_disabled(hostile2)
	assert_signal_emitted(EventBus, "combat_ended", "Should end when all hostiles removed")


# ============ EDGE CASE TESTS ============

## Edge Case: Negative tick amount ignored.
func test_negative_tick_amount_ignored() -> void:
	var initial_cooldown: int = _event_system._encounter_cooldown_seconds
	_event_system._on_world_event_tick_triggered(-5)
	assert_eq(_event_system._encounter_cooldown_seconds, initial_cooldown, "Negative ticks should be ignored")


## Edge Case: Zero tick amount ignored.
func test_zero_tick_amount_ignored() -> void:
	var initial_cooldown: int = _event_system._encounter_cooldown_seconds
	_event_system._on_world_event_tick_triggered(0)
	assert_eq(_event_system._encounter_cooldown_seconds, initial_cooldown, "Zero ticks should be ignored")


## Edge Case: Pruning removes freed nodes from hostiles.
func test_prune_removes_freed_nodes() -> void:
	var valid_hostile: Node = Node.new()
	var freed_hostile: Node = Node.new()
	add_child_autofree(valid_hostile)
	add_child_autofree(freed_hostile)
	
	_event_system._active_hostiles = [valid_hostile, freed_hostile]
	freed_hostile.queue_free()
	yield(get_tree(), "idle_frame")
	
	_event_system._prune_invalid_hostiles()
	assert_eq(_event_system._active_hostiles.size(), 1, "Freed nodes should be pruned")
	assert_true(_event_system._active_hostiles.has(valid_hostile), "Valid node should remain")


## Edge Case: Remove non-existent hostile doesn't crash.
func test_remove_nonexistent_hostile_safe() -> void:
	var hostile1: Node = Node.new()
	var hostile2: Node = Node.new()
	add_child_autofree(hostile1)
	add_child_autofree(hostile2)
	
	_event_system._active_hostiles = [hostile1]
	_event_system._on_agent_disabled(hostile2)
	assert_eq(_event_system._active_hostiles.size(), 1, "Non-existent hostile removal should be safe")


## Edge Case: Force encounter with no active hostiles spawns immediately.
func test_force_encounter_with_no_hostiles() -> void:
	_event_system._active_hostiles.clear()
	_event_system._encounter_cooldown_seconds = 100
	_event_system.force_encounter()
	assert_eq(_event_system._encounter_cooldown_seconds, 0, "Force should reset cooldown")
	assert_true(_event_system._active_hostiles.size() > 0, "Should spawn hostiles")


## Edge Case: Spawn position calculation within expected bounds.
func test_spawn_position_within_bounds() -> void:
	var player_pos: Vector3 = Vector3.ZERO
	for _i in range(10):
		var spawn_pos: Vector3 = _event_system._calculate_spawn_position(player_pos)
		var distance: float = player_pos.distance_to(spawn_pos)
		assert_true(distance >= EventSystem.SPAWN_DISTANCE_MIN, "Spawn distance too close")
		assert_true(distance <= EventSystem.SPAWN_DISTANCE_MAX, "Spawn distance too far")
