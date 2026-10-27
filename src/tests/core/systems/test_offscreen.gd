# Tests for Offscreen: far ships leave the physics and are resolved by rule, near ones fly again;
# docked ships are out of the physics.

extends GutTest

const Offscreen = preload("res://src/core/systems/offscreen.gd")


class Ship extends "res://src/core/agents/agent.gd":
	func get_top_speed() -> float:
		return 100.0
	func get_damage_per_second() -> float:
		return 20.0


class StubAI extends Node:
	var _arena: Dictionary = {}
	var _home_position: Vector3 = Vector3.ZERO
	var _home_point: Vector3 = Vector3.ZERO
	var retreat: bool = false
	func is_leaving() -> bool:
		return false
	func _due_home() -> bool:
		return false
	func _should_retreat() -> bool:
		return retreat
	func can_mine() -> bool:
		return false


var offscreen: Node = null


func before_each():
	GameState.reset_state()
	offscreen = Offscreen.new()
	offscreen.enabled = false  # Driven by hand
	add_child_autofree(offscreen)


func after_each():
	GlobalRefs.player_agent_body = null
	GameState.reset_state()


func _ship(faction: String, at: Vector3, agent_type: String = "npc") -> RigidBody:
	var body = Ship.new()
	body.agent_type = agent_type
	body.faction = faction
	body.hull = 100.0
	body.hull_max = 100.0
	body.cargo_capacity = 10
	body.translation = at
	var ai := StubAI.new()
	ai.name = Constants.AI_CONTROLLER_NODE_NAME
	body.add_child(ai)
	add_child_autofree(body)
	return body


func test_far_ships_leave_the_physics_and_near_ones_fly_again_at_their_speed():
	var player = _ship("player", Vector3.ZERO, "player")
	GlobalRefs.player_agent_body = player
	var far = _ship("verdant", Vector3(Constants.OFFSCREEN_RADIUS + 1000.0, 0, 0))
	var near = _ship("verdant", Vector3(1000, 0, 0))
	far.linear_velocity = Vector3(0, 0, 40)
	offscreen.check()
	assert_true(offscreen.is_offscreen(far))
	assert_false(offscreen.is_offscreen(near))
	assert_eq(far.mode, RigidBody.MODE_STATIC)
	assert_false(far.get_node(Constants.AI_CONTROLLER_NODE_NAME).is_physics_processing(), "Its AI rests")
	assert_eq(offscreen.count(), 1)
	far.translation = Vector3(Constants.OFFSCREEN_FULL_RADIUS - 100.0, 0, 0)
	offscreen.check()
	assert_false(offscreen.is_offscreen(far))
	assert_eq(far.mode, RigidBody.MODE_RIGID)
	assert_eq(far.linear_velocity, Vector3(0, 0, 40), "At the speed it had")


func test_an_off_screen_ship_closes_on_an_enemy_it_detects_and_damages_it_by_rule():
	var player = _ship("player", Vector3.ZERO, "player")
	GlobalRefs.player_agent_body = player
	var hunter = _ship("verdant", Vector3(50000, 0, 0))
	var prey = _ship("violet", Vector3(50000, 0, 1400))  # Within a bare hull's 1500 m signature
	offscreen.check()
	assert_true(offscreen.is_offscreen(hunter))
	offscreen.resolve(1.0)
	assert_almost_eq(prey.hull, 100.0 - 20.0 * Constants.OFFSCREEN_HIT_SHARE, 0.01, "Within engage range: it deals its damage share")


func test_an_off_screen_ship_moves_toward_its_patrol_and_faces_its_way():
	var player = _ship("player", Vector3.ZERO, "player")
	GlobalRefs.player_agent_body = player
	var ship = _ship("verdant", Vector3(50000, 0, 0))
	ship.get_node(Constants.AI_CONTROLLER_NODE_NAME)._home_position = Vector3(60000, 0, 0)
	offscreen.check()
	var entry: Dictionary = offscreen._entries[ship.get_instance_id()]
	offscreen._move(ship, entry, Vector3(60000, 0, 0), 1.0, 0.0)
	assert_almost_eq(ship.global_transform.origin.x, 50000.0 + 100.0 * Constants.OFFSCREEN_SPEED_SHARE, 0.01, "At its share of top speed")
	assert_almost_eq(entry.velocity.normalized().x, 1.0, 0.001)
	assert_almost_eq((-ship.global_transform.basis.z).x, 1.0, 0.001, "Nose along its way")


func test_docked_ships_are_out_of_the_physics_and_back_in_on_undocking():
	var ship = _ship("verdant", Vector3.ZERO)
	ship.dock_at(null)
	assert_eq(ship.mode, RigidBody.MODE_STATIC)
	ship.undock()
	assert_eq(ship.mode, RigidBody.MODE_RIGID)
