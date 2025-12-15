# test_weapon_controller.gd
# Unit tests for WeaponController - weapon firing, cooldowns, signal emissions
extends "res://addons/gut/test.gd"

const WeaponController = preload("res://core/agents/components/weapon_controller.gd")
const CombatSystem = preload("res://core/systems/combat_system.gd")
const UtilityToolTemplate = preload("res://core/resource/utility_tool_template.gd")

var _weapon_controller: Node
var _mock_agent_body: KinematicBody
var _mock_combat_system: Node
var _test_weapon: UtilityToolTemplate

const SHOOTER_UID: int = 100
const TARGET_UID: int = 200


# --- Test Agent Body with required properties ---
class TestAgentBody:
	extends KinematicBody
	var agent_uid: int = 100
	var character_uid: int = 1


func before_each():
	# Create mock agent body
	_mock_agent_body = TestAgentBody.new()
	_mock_agent_body.name = "TestAgentBody"
	_mock_agent_body.agent_uid = SHOOTER_UID
	_mock_agent_body.character_uid = 1
	add_child(_mock_agent_body)
	
	# Create and register mock combat system
	_mock_combat_system = CombatSystem.new()
	add_child(_mock_combat_system)
	GlobalRefs.combat_system = _mock_combat_system
	
	# Create test weapon
	_test_weapon = UtilityToolTemplate.new()
	_test_weapon.template_id = "test_laser"
	_test_weapon.tool_name = "Test Laser"
	_test_weapon.tool_type = "weapon"
	_test_weapon.damage = 10.0
	_test_weapon.range_effective = 50.0
	_test_weapon.range_max = 100.0
	_test_weapon.fire_rate = 2.0  # 2 shots per second = 0.5s base cooldown
	_test_weapon.accuracy = 1.0
	_test_weapon.hull_damage_multiplier = 1.0
	_test_weapon.armor_damage_multiplier = 1.0
	_test_weapon.cooldown_time = 0.5  # Additional cooldown
	
	# Create weapon controller and add as child of agent body
	_weapon_controller = WeaponController.new()
	_weapon_controller.name = "WeaponController"
	_mock_agent_body.add_child(_weapon_controller)
	
	# Manually inject a weapon (bypassing asset system loading)
	_weapon_controller._weapons = [_test_weapon]
	_weapon_controller._cooldowns = {0: 0.0}
	
	# Register combatants for fire tests
	var shooter_ship = _create_mock_ship(100, 50)
	var target_ship = _create_mock_ship(100, 50)
	_mock_combat_system.register_combatant(SHOOTER_UID, shooter_ship)
	_mock_combat_system.register_combatant(TARGET_UID, target_ship)


func after_each():
	GlobalRefs.combat_system = null
	if is_instance_valid(_mock_agent_body):
		_mock_agent_body.queue_free()
	if is_instance_valid(_mock_combat_system):
		_mock_combat_system.queue_free()


func _create_mock_ship(hull: int, armor: int) -> Resource:
	var ship = Resource.new()
	ship.set_script(load("res://tests/helpers/mock_ship_template.gd"))
	ship.hull_integrity = hull
	ship.armor_integrity = armor
	return ship


# --- Weapon Loading Tests ---

func test_get_weapon_count():
	assert_eq(_weapon_controller.get_weapon_count(), 1, "Should have 1 weapon loaded")


func test_get_weapon_valid_index():
	var weapon = _weapon_controller.get_weapon(0)
	assert_not_null(weapon, "Weapon at index 0 should exist")
	assert_eq(weapon.template_id, "test_laser", "Should return correct weapon")


func test_get_weapon_invalid_index():
	var weapon = _weapon_controller.get_weapon(99)
	assert_null(weapon, "Invalid index should return null")
	
	weapon = _weapon_controller.get_weapon(-1)
	assert_null(weapon, "Negative index should return null")


# --- Weapon Ready State Tests ---

func test_is_weapon_ready_initially():
	assert_true(_weapon_controller.is_weapon_ready(0), "Weapon should be ready initially")


func test_is_weapon_ready_after_fire():
	var target_pos = Vector3(10, 0, 0)
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_false(_weapon_controller.is_weapon_ready(0), "Weapon should not be ready after firing")


func test_get_cooldown_remaining_initially():
	var cooldown = _weapon_controller.get_cooldown_remaining(0)
	assert_eq(cooldown, 0.0, "Initial cooldown should be 0")


# --- Fire Weapon Tests ---

func test_fire_weapon_success():
	var target_pos = Vector3(10, 0, 0)  # Within range
	
	var result = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_true(result.get("success", false), "Fire should succeed")


func test_fire_weapon_emits_weapon_fired_signal():
	watch_signals(_weapon_controller)
	var target_pos = Vector3(10, 0, 0)
	
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_signal_emitted(_weapon_controller, "weapon_fired", "weapon_fired signal should emit")


func test_fire_weapon_emits_cooldown_started_signal():
	watch_signals(_weapon_controller)
	var target_pos = Vector3(10, 0, 0)
	
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_signal_emitted(_weapon_controller, "weapon_cooldown_started", 
		"weapon_cooldown_started signal should emit")


func test_fire_weapon_starts_cooldown():
	var target_pos = Vector3(10, 0, 0)
	
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	var cooldown = _weapon_controller.get_cooldown_remaining(0)
	assert_gt(cooldown, 0.0, "Cooldown should be > 0 after firing")


func test_fire_weapon_invalid_index():
	var target_pos = Vector3(10, 0, 0)
	
	var result = _weapon_controller.fire_at_target(99, TARGET_UID, target_pos)
	
	assert_false(result.get("success", true), "Fire with invalid index should fail")
	assert_eq(result.get("reason"), "Invalid weapon index", "Should return correct error reason")


func test_fire_weapon_during_cooldown_fails():
	var target_pos = Vector3(10, 0, 0)
	
	# First fire should succeed
	var result1 = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	assert_true(result1.get("success", false), "First fire should succeed")
	
	# Second immediate fire should fail
	var result2 = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	assert_false(result2.get("success", true), "Second fire should fail due to cooldown")
	assert_eq(result2.get("reason"), "Weapon on cooldown", "Should report cooldown as reason")


# --- Cooldown Timer Tests ---

func test_cooldown_decrements_over_time():
	var target_pos = Vector3(10, 0, 0)
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	var initial_cooldown = _weapon_controller.get_cooldown_remaining(0)
	
	# Simulate physics frame
	_weapon_controller._physics_process(0.25)
	
	var new_cooldown = _weapon_controller.get_cooldown_remaining(0)
	assert_lt(new_cooldown, initial_cooldown, "Cooldown should decrease after physics process")


func test_cooldown_reaches_zero():
	var target_pos = Vector3(10, 0, 0)
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	# Simulate enough time to complete cooldown (fire_rate=2 -> 0.5s + cooldown_time=0.5s = 1.0s)
	_weapon_controller._physics_process(2.0)
	
	var final_cooldown = _weapon_controller.get_cooldown_remaining(0)
	assert_eq(final_cooldown, 0.0, "Cooldown should reach 0")
	assert_true(_weapon_controller.is_weapon_ready(0), "Weapon should be ready after cooldown")


func test_weapon_ready_signal_emitted_after_cooldown():
	watch_signals(_weapon_controller)
	var target_pos = Vector3(10, 0, 0)
	
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	# Simulate time to complete cooldown
	_weapon_controller._physics_process(2.0)
	
	assert_signal_emitted(_weapon_controller, "weapon_ready", 
		"weapon_ready signal should emit when cooldown ends")


# --- Edge Case Tests ---

func test_fire_without_combat_system():
	GlobalRefs.combat_system = null
	var target_pos = Vector3(10, 0, 0)
	
	var result = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	assert_false(result.get("success", true), "Fire should fail without combat system")
	assert_eq(result.get("reason"), "CombatSystem unavailable", "Should report system unavailable")


func test_multiple_physics_frames_decrement_cooldown():
	var target_pos = Vector3(10, 0, 0)
	_weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	
	var cooldowns = []
	cooldowns.append(_weapon_controller.get_cooldown_remaining(0))
	
	for _i in range(4):
		_weapon_controller._physics_process(0.1)
		cooldowns.append(_weapon_controller.get_cooldown_remaining(0))
	
	# Verify strictly decreasing
	for i in range(1, cooldowns.size()):
		assert_lt(cooldowns[i], cooldowns[i-1], 
			"Cooldown should decrease each frame (frame %d)" % i)


func test_can_fire_again_after_cooldown_complete():
	var target_pos = Vector3(10, 0, 0)
	
	# First fire
	var result1 = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	assert_true(result1.get("success", false), "First fire should succeed")
	
	# Wait for cooldown
	_weapon_controller._physics_process(2.0)
	
	# Second fire after cooldown
	var result2 = _weapon_controller.fire_at_target(0, TARGET_UID, target_pos)
	assert_true(result2.get("success", false), "Fire after cooldown should succeed")
