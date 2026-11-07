# Tests for AmbientVisuals: scenery under it is never solid, a target or an obstacle.

extends GutTest

const AmbientVisuals = preload("res://src/scenes/game_world/ambient/ambient_visuals.gd")
const NebulaCloud = preload("res://scenes/prefabs/ambient/nebula_cloud.tscn")


func test_whatever_is_under_it_is_scenery():
	var ambient = Spatial.new()
	ambient.set_script(AmbientVisuals)
	var rock = StaticBody.new()
	rock.collision_layer = 1
	rock.add_to_group("asteroid")
	rock.add_to_group("obstacle")
	ambient.add_child(rock)
	add_child_autofree(ambient)
	assert_eq(rock.collision_layer, 0)
	assert_false(rock.is_in_group("asteroid"), "Not a target")
	assert_false(rock.is_in_group("obstacle"), "Not in the way")
	var late = Area.new()
	late.collision_mask = 3
	ambient.add_child(late)
	late.add_to_group("celestial")
	yield(get_tree(), "idle_frame")
	assert_eq(late.collision_mask, 0, "Added later too")
	assert_false(late.is_in_group("celestial"))


func test_a_nebula_cloud_builds_its_puffs():
	var cloud = NebulaCloud.instance()
	cloud.puffs = 5
	add_child_autofree(cloud)
	assert_eq(cloud.get_child_count(), 5)
	cloud.puffs = 3
	assert_eq(cloud.get_child_count(), 3, "Rebuilt when a field changes")
