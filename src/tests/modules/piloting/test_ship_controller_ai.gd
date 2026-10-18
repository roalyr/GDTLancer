# Tests for ShipControllerAI: target selection and combat transitions.

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const AIScript = preload("res://src/modules/piloting/ship_controller_ai.gd")

var hostile: RigidBody = null
var ai: Node = null


func before_each():
	hostile = _make_body(Vector3.ZERO, true)
	ai = AIScript.new()
	hostile.add_child(ai)


func _make_body(position: Vector3, is_hostile: bool) -> RigidBody:
	var body = AgentScript.new()
	add_child_autofree(body)
	body.global_transform.origin = position
	body.is_hostile = is_hostile
	body.hull_max = 50.0
	body.hull = 50.0
	return body


func test_scan_picks_nearest_live_non_hostile_in_range():
	var far = _make_body(Vector3(0, 0, -2500), false)
	var near = _make_body(Vector3(0, 0, -1000), false)
	_make_body(Vector3(0, 0, -100), true)  # Fellow hostile: ignored
	var wreck = _make_body(Vector3(0, 0, -50), false)
	wreck.become_wreck()
	_make_body(Vector3(0, 0, -(Constants.AI_DETECTION_RANGE + 100)), false)  # Out of range
	assert_eq(ai.scan_for_target(), near)
	near.become_wreck()
	assert_eq(ai.scan_for_target(), far)


func test_scan_finds_nothing_when_alone():
	assert_null(ai.scan_for_target())


func test_hostile_starts_patrolling_and_wreck_disables():
	ai.initialize({"hostile": true, "patrol_center": Vector3.ZERO})
	assert_eq(ai.get_state(), AIScript.AIState.PATROL)
	hostile.become_wreck()
	assert_eq(ai.get_state(), AIScript.AIState.DISABLED)


func test_shot_from_beyond_detection_range_makes_it_chase_the_attacker():
	ai.initialize({"hostile": true, "patrol_center": Vector3.ZERO})
	var sniper = _make_body(Vector3(0, 0, -(Constants.AI_DETECTION_RANGE * 3.0)), false)
	assert_null(ai.scan_for_target(), "Too far to be noticed on its own.")
	hostile.apply_damage(1.0, sniper)
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT)
	assert_eq(ai._target_agent, sniper)
	ai._process_combat()
	assert_eq(ai.get_state(), AIScript.AIState.COMBAT, "Stays on the attacker beyond detection range.")


func test_damage_from_nothing_alive_does_not_provoke():
	ai.initialize({"hostile": true, "patrol_center": Vector3.ZERO})
	hostile.apply_damage(1.0, null)
	assert_eq(ai.get_state(), AIScript.AIState.PATROL)

