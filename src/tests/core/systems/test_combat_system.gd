# test_combat_system.gd
# Unit tests for CombatSystem - targeting, damage, weapon firing
extends "res://addons/gut/test.gd"

const CombatSystem = preload("res://src/core/systems/combat_system.gd")
const UtilityToolTemplate = preload("res://database/definitions/utility_tool_template.gd")
const MockAgentBody = preload("res://src/tests/helpers/mock_agent_body.gd")

var _combat_system: Node
var _test_weapon: UtilityToolTemplate
var _attacker_uid: int = 0
var _defender_uid: int = 1
var _attacker_body: KinematicBody
var _defender_body: KinematicBody


func before_each():
	# Create dummy AgentBody nodes so CombatSystem can resolve uid -> body for EventBus signals.
	_attacker_body = MockAgentBody.new()
	_attacker_body.agent_uid = _attacker_uid
	_attacker_body.add_to_group("Agents")
	add_child_autofree(_attacker_body)

	_defender_body = MockAgentBody.new()
	_defender_body.agent_uid = _defender_uid
	_defender_body.add_to_group("Agents")
	add_child_autofree(_defender_body)

	_combat_system = CombatSystem.new()
	add_child_autofree(_combat_system)
	
	# Create test weapon
	_test_weapon = UtilityToolTemplate.new()
	_test_weapon.template_id = "test_laser"
	_test_weapon.tool_name = "Test Laser"
	_test_weapon.damage = 10.0
	_test_weapon.range_effective = 50.0
	_test_weapon.range_max = 100.0
	_test_weapon.fire_rate = 2.0
	_test_weapon.accuracy = 1.0  # Always hit for testing
	_test_weapon.hull_damage_multiplier = 1.0
	_test_weapon.armor_damage_multiplier = 1.0
	_test_weapon.cooldown_time = 0.0
	
	# Create mock ship templates
	var attacker_ship = _create_mock_ship(100, 50)
	var defender_ship = _create_mock_ship(100, 50)
	
	_combat_system.register_combatant(_attacker_uid, attacker_ship)
	_combat_system.register_combatant(_defender_uid, defender_ship)


func after_each() -> void:
	_attacker_body = null
	_defender_body = null
	_combat_system = null


func _create_mock_ship(hull: int, armor: int) -> Resource:
	var ship = Resource.new()
	ship.set_meta("hull_integrity", hull)
	ship.set_meta("armor_integrity", armor)
	# Duck-type the properties
	ship.set_script(load("res://src/tests/helpers/mock_ship_template.gd"))
	return ship


# --- Registration Tests ---

func test_register_combatant():
	var state = _combat_system.get_combat_state(_attacker_uid)
	
	assert_false(state.empty(), "Combat state should exist for registered combatant")
	assert_eq(state.current_hull, 100, "Hull should be initialized from ship template")
	assert_eq(state.max_hull, 100, "Max hull should be set")
	assert_eq(state.is_disabled, false, "Should not be disabled initially")


func test_unregister_combatant():
	_combat_system.unregister_combatant(_attacker_uid)
	
	var state = _combat_system.get_combat_state(_attacker_uid)
	assert_true(state.empty(), "Combat state should be empty after unregister")


func test_is_in_combat():
	assert_true(_combat_system.is_in_combat(_attacker_uid), "Registered combatant should be in combat")
	
	_combat_system.unregister_combatant(_attacker_uid)
	assert_false(_combat_system.is_in_combat(_attacker_uid), "Unregistered combatant should not be in combat")


# --- Range Tests ---

func test_is_in_range_within_effective():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)  # 30 units away, within 50 effective
	
	assert_true(_combat_system.is_in_range(shooter_pos, target_pos, _test_weapon), 
		"Target within effective range should be in range")


func test_is_in_range_within_max():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(75, 0, 0)  # 75 units away, within 100 max
	
	assert_true(_combat_system.is_in_range(shooter_pos, target_pos, _test_weapon), 
		"Target within max range should be in range")


func test_is_in_range_out_of_range():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(150, 0, 0)  # 150 units away, beyond 100 max
	
	assert_false(_combat_system.is_in_range(shooter_pos, target_pos, _test_weapon), 
		"Target beyond max range should not be in range")


# --- Damage Calculation Tests ---

func test_calculate_damage_at_effective_range():
	var damage = _combat_system.calculate_damage(_test_weapon, 30.0)
	
	assert_eq(damage.hull_damage, 10.0, "Should deal full damage within effective range")


func test_calculate_damage_at_max_range():
	var damage = _combat_system.calculate_damage(_test_weapon, 100.0)
	
	assert_eq(damage.hull_damage, 0.0, "Should deal zero damage at max range edge")


func test_calculate_damage_falloff():
	var damage = _combat_system.calculate_damage(_test_weapon, 75.0)  # Halfway through falloff
	
	assert_almost_eq(damage.hull_damage, 5.0, 0.1, "Should deal reduced damage in falloff zone")


# --- Fire Weapon Tests ---

func test_fire_weapon_hit():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)
	
	var result = _combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_true(result.success, "Fire should succeed")
	assert_true(result.hit, "Should hit with 100% accuracy")
	assert_eq(result.damage_dealt.hull_damage, 10.0, "Should deal 10 damage")


func test_fire_weapon_out_of_range():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(150, 0, 0)  # Beyond max range
	
	var result = _combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_false(result.success, "Fire should fail")
	assert_eq(result.reason, "Target out of range", "Should report out of range")


func test_fire_weapon_cooldown():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)
	
	# Fire first shot
	_combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	# Try to fire again immediately
	var result = _combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_false(result.success, "Second shot should fail due to cooldown")
	assert_eq(result.reason, "Weapon on cooldown", "Should report cooldown")


func test_cooldown_update():
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)
	
	# Fire first shot
	_combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	# Update cooldowns past the fire_rate period (0.5s for 2 shots/sec)
	_combat_system.update_cooldowns(1.0)
	
	# Should be able to fire again
	var result = _combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_true(result.success, "Should be able to fire after cooldown")


# --- Damage Application Tests ---

func test_apply_damage_reduces_hull():
	_combat_system.apply_damage(_defender_uid, 25.0)
	
	var state = _combat_system.get_combat_state(_defender_uid)
	assert_eq(state.current_hull, 75, "Hull should be reduced by damage")


func test_apply_damage_disables_at_zero():
	_combat_system.apply_damage(_defender_uid, 100.0)
	
	var state = _combat_system.get_combat_state(_defender_uid)
	assert_eq(state.current_hull, 0, "Hull should be zero")
	assert_true(state.is_disabled, "Ship should be disabled")


func test_apply_damage_clamps_to_zero():
	_combat_system.apply_damage(_defender_uid, 150.0)  # More than hull
	
	var state = _combat_system.get_combat_state(_defender_uid)
	assert_eq(state.current_hull, 0, "Hull should clamp to zero")


func test_get_hull_percent():
	_combat_system.apply_damage(_defender_uid, 30.0)
	
	var percent = _combat_system.get_hull_percent(_defender_uid)
	assert_almost_eq(percent, 0.7, 0.01, "Hull percent should be 70%")


# --- Combat Victory Tests ---

func test_check_victory_player_wins():
	# Disable the defender (enemy)
	_combat_system.apply_damage(_defender_uid, 100.0)
	
	var result = _combat_system.check_combat_victory(_attacker_uid)
	assert_true(result.victory, "Player should win when all enemies disabled")


func test_check_victory_enemies_remain():
	var result = _combat_system.check_combat_victory(_attacker_uid)
	
	assert_false(result.victory, "Victory should be false while enemies remain")
	assert_eq(result.reason, "enemies_remain", "Reason should indicate enemies remain")


func test_check_victory_player_disabled():
	_combat_system.apply_damage(_attacker_uid, 100.0)
	
	var result = _combat_system.check_combat_victory(_attacker_uid)
	
	assert_false(result.victory, "Victory should be false if player disabled")
	assert_eq(result.reason, "player_disabled", "Reason should indicate player disabled")


# --- Signal Tests ---

func test_damage_dealt_signal():
	watch_signals(_combat_system)
	
	_combat_system.apply_damage(_defender_uid, 25.0)
	
	assert_signal_emitted(_combat_system, "damage_dealt", "damage_dealt signal should emit")


func test_ship_disabled_signal():
	watch_signals(_combat_system)
	
	_combat_system.apply_damage(_defender_uid, 100.0)
	
	assert_signal_emitted(_combat_system, "ship_disabled", "ship_disabled signal should emit")


func test_eventbus_agent_damaged_emits_for_damage():
	watch_signals(EventBus)
	_combat_system.apply_damage(_defender_uid, 10.0, 0.0, _attacker_uid)
	assert_signal_emitted(EventBus, "agent_damaged")


func test_eventbus_agent_disabled_emits_on_disable():
	watch_signals(EventBus)
	_combat_system.apply_damage(_defender_uid, 100.0, 0.0, _attacker_uid)
	assert_signal_emitted(EventBus, "agent_disabled")


func test_weapon_fired_signal():
	watch_signals(_combat_system)
	
	var shooter_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, 0)
	_combat_system.fire_weapon(_attacker_uid, _defender_uid, _test_weapon, shooter_pos, target_pos)
	
	assert_signal_emitted(_combat_system, "weapon_fired", "weapon_fired signal should emit")


# --- Combat Start/End Tests ---

func test_start_combat():
	# Clear existing combatants
	_combat_system.end_combat()
	
	watch_signals(_combat_system)
	
	var ship1 = _create_mock_ship(100, 50)
	var ship2 = _create_mock_ship(80, 30)
	
	_combat_system.start_combat([
		{"uid": 10, "ship_template": ship1},
		{"uid": 11, "ship_template": ship2}
	])
	
	assert_signal_emitted(_combat_system, "combat_started", "combat_started signal should emit")
	assert_true(_combat_system.is_in_combat(10), "First participant should be in combat")
	assert_true(_combat_system.is_in_combat(11), "Second participant should be in combat")


func test_end_combat():
	watch_signals(_combat_system)
	
	_combat_system.end_combat("victory")
	
	assert_signal_emitted(_combat_system, "combat_ended", "combat_ended signal should emit")
	assert_false(_combat_system.is_in_combat(_attacker_uid), "Combatants should be cleared")
