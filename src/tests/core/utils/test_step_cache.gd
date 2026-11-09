# Tests for StepCache (a group fetched once per physics step in the game world) and the per-step
# caches that go by it (Agent.get_signature, ToolController._hold).

extends GutTest

const StepCache = preload("res://src/core/utils/step_cache.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")


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
