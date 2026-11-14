# Tests for StepCache (a group fetched once per physics step in the game world) and the per-step
# caches that go by it (Agent.get_signature, ToolController._hold).

extends GutTest

const StepCache = preload("res://src/core/utils/step_cache.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const ProjectileScript = preload("res://src/core/agents/components/projectile.gd")


class Hull extends RigidBody:
	var is_wreck := false
	var is_docked := false
	var hull_bounds := AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	func _ready() -> void:
		add_to_group("agent_body")
	func get_apparent_radius() -> float:
		return 17.0


func after_each():
	StepCache.set_active(false)


func _member() -> Node:
	var node = Node.new()
	add_child_autofree(node)
	node.add_to_group("step_cache_test")
	return node


func test_outside_the_game_world_a_group_is_fetched_fresh():
	_member()
	yield(get_tree(), "physics_frame")
	assert_eq(StepCache.group(get_tree(), "step_cache_test").size(), 1)
	_member()
	assert_eq(StepCache.group(get_tree(), "step_cache_test").size(), 2, "Not cached")


func test_in_the_game_world_once_per_physics_step():
	StepCache.set_active(true)
	_member()
	yield(get_tree(), "physics_frame")
	assert_true(StepCache.active(), "Within a physics step")
	assert_eq(StepCache.group(get_tree(), "step_cache_test").size(), 1)
	_member()
	assert_eq(StepCache.group(get_tree(), "step_cache_test").size(), 1, "The same list all step")
	yield(get_tree(), "physics_frame")
	assert_eq(StepCache.group(get_tree(), "step_cache_test").size(), 2, "Fetched again the next step")


func test_a_held_weapon_looks_again_after_the_recheck_only_in_the_game_world():
	var tools = autofree(ToolControllerScript.new())  # Out of the tree: only its hold is looked at
	yield(get_tree(), "physics_frame")
	tools._hold(0)
	assert_false(tools._held.has(0), "In a test: every look counts")
	StepCache.set_active(true)
	tools._hold(0)
	assert_eq(tools._held.get(0), Constants.SHOT_HOLD_RECHECK, "In the game: it waits")


func test_rounds_share_one_list_of_ships_a_step_and_miss_one_wrecked_during_it():
	var ship = Hull.new()
	ship.mode = RigidBody.MODE_STATIC
	add_child_autofree(ship)
	ship.global_transform.origin = Vector3(0, 0, -100)
	var round_ = autofree(ProjectileScript.new())
	add_child(round_)
	StepCache.set_active(true)
	yield(get_tree(), "physics_frame")
	var listed: Array = ProjectileScript.hittable_ships(get_tree())
	assert_eq(listed.size(), 1)
	listed.append(listed[0])
	assert_eq(ProjectileScript.hittable_ships(get_tree()).size(), 2, "The same list all step")
	listed.pop_back()
	assert_eq(round_._first_ship_on(Vector3(0, 0, -50), Vector3(0, 0, -150), 1.0 / 30.0).get("body"), ship, "In its path")
	ship.is_wreck = true
	assert_true(round_._first_ship_on(Vector3(0, 0, -50), Vector3(0, 0, -150), 1.0 / 30.0).empty(), "Wrecked this step: not met again")
	yield(get_tree(), "physics_frame")
	assert_eq(ProjectileScript.hittable_ships(get_tree()).size(), 0, "Gone from the next step's list")
