# Tests for CollisionHull: convex shapes from a model's lowest level of detail, and shot rays that
# find a body's surface through whatever else is in the way.

extends GutTest

const CollisionHull = preload("res://src/core/agents/components/collision_hull.gd")
const PHOENIX = "res://assets/models/ships/Phoenix_light.glb"


func _box_instance(size: Vector3) -> MeshInstance:
	var instance = MeshInstance.new()
	var cube = CubeMesh.new()
	cube.size = size
	cube.subdivide_width = 8
	cube.subdivide_height = 8
	cube.subdivide_depth = 8
	instance.mesh = cube
	return instance


func test_reduce_keeps_few_points_all_on_the_hull():
	var points := PoolVector3Array()
	for i in range(2000):
		points.append(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized() * 5.0)
	var kept: PoolVector3Array = CollisionHull.reduce(points, 32)
	assert_true(kept.size() <= 32, "At most the asked count")
	assert_gt(kept.size(), 16, "spread round the shape")
	for point in kept:
		assert_almost_eq(point.length(), 5.0, 0.001, "and every one an original hull point.")


func test_plain_meshes_give_a_hull_placed_in_the_body():
	var root = Spatial.new()
	add_child_autofree(root)
	root.add_child(_box_instance(Vector3(20, 4, 20)))
	var shape = CollisionHull.shape_for(root, Transform(Basis(), Vector3(0, 10, 0)))
	assert_true(shape is ConvexPolygonShape)
	assert_true(shape.points.size() <= Constants.COLLISION_HULL_MAX_POINTS)
	var bounds := AABB(shape.points[0], Vector3.ZERO)
	for point in shape.points:
		bounds = bounds.expand(point)
	assert_almost_eq(bounds.position, Vector3(-10, 8, -10), Vector3.ONE * 0.5, "The box's outline, moved into the body")
	assert_almost_eq(bounds.end, Vector3(10, 12, 10), Vector3.ONE * 0.5)


func test_models_use_their_lowest_level_of_detail_and_skip_effects():
	var root = Spatial.new()
	add_child_autofree(root)
	var model: Spatial = load(PHOENIX).instance()
	root.add_child(model)
	var plume = _box_instance(Vector3(1, 1, 200))  # An engine plume: not a model file, so not hull
	root.add_child(plume)
	var shape = CollisionHull.shape_for(root, Transform.IDENTITY)
	assert_not_null(shape)
	assert_true(shape.points.size() <= Constants.COLLISION_HULL_MAX_POINTS)
	var model_bounds := AABB()
	var found := false
	var stack: Array = [model]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if node is MeshInstance:
			var box: AABB = node.global_transform.xform(node.get_aabb())
			model_bounds = box if not found else model_bounds.merge(box)
			found = true
	for point in shape.points:
		assert_true(model_bounds.grow(1.0).has_point(point), "Hull points stay on the ship, not the plume: %s" % point)


func test_a_shot_ray_finds_its_target_through_other_bodies():
	var target = StaticBody.new()
	var target_shape = CollisionShape.new()
	target.add_child(target_shape)
	add_child_autofree(target)
	var root = Spatial.new()
	target.add_child(root)
	root.add_child(_box_instance(Vector3(20, 4, 20)))
	target_shape.shape = CollisionHull.shape_for(root, Transform.IDENTITY)
	var debris = StaticBody.new()
	var debris_shape = CollisionShape.new()
	debris_shape.shape = SphereShape.new()
	debris.add_child(debris_shape)
	debris.translation = Vector3(0, 100, 0)
	add_child_autofree(debris)
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	var hit: Dictionary = CollisionHull.ray_onto(target, Vector3(0, 200, 0), Vector3(3, 0, -2), 20.0)
	assert_false(hit.empty(), "Past the debris")
	assert_eq(hit.collider, target)
	assert_almost_eq(hit.position.y, 2.0, 0.15, "onto the target's top face")
	assert_almost_eq(hit.normal.dot(Vector3.UP), 1.0, 0.05, "with its normal.")
	assert_true(CollisionHull.ray_onto(target, Vector3(0, 200, 0), Vector3(100, 0, 0), 20.0).empty(), "A line past it misses.")


func test_asteroids_collide_as_their_outline():
	var rock = load("res://scenes/prefabs/celestial/asteroid.tscn").instance()
	add_child_autofree(rock)
	var shape = rock.get_node("CollisionShape").shape
	assert_true(shape is ConvexPolygonShape, "A convex hull, not the sphere inside the rock")
	var reach := 0.0
	for point in shape.points:
		reach = max(reach, point.length())
	assert_gt(reach, rock.get_apparent_radius() * 0.7, "reaching out to the rock's surface.")


func test_shots_land_on_the_plating_inside_the_hull():
	var target = StaticBody.new()
	add_child_autofree(target)
	var visual = Spatial.new()
	target.add_child(visual)
	visual.add_child(load(PHOENIX).instance())
	var hull = CollisionShape.new()
	hull.shape = CollisionHull.shape_for(visual, Transform.IDENTITY)
	target.add_child(hull)
	var surface: StaticBody = CollisionHull.add_hit_surface(target, visual)
	assert_not_null(surface)
	assert_eq(surface.collision_layer, Constants.HIT_SURFACE_LAYER, "Its own layer")
	assert_eq(surface.collision_mask, 0, "and it collides with nothing.")
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	var space: PhysicsDirectSpaceState = target.get_world().direct_space_state
	var on_plating := 0
	var through_gaps := 0
	seed(11)
	for _i in range(60):
		var aim := Vector3(rand_range(-9, 9), 0, rand_range(-6, 6))
		var from: Vector3 = aim + Vector3(rand_range(-0.3, 0.3), 1, rand_range(-0.3, 0.3)).normalized() * 200.0
		var outline: Dictionary = space.intersect_ray(from, aim, [], 1)
		var hit: Dictionary = CollisionHull.ray_onto(target, from, aim, 20.0)
		if outline.empty():
			continue
		if hit.empty():
			through_gaps += 1
			continue
		on_plating += 1
		assert_eq(hit.collider, surface)
		assert_true(from.distance_to(hit.position) >= from.distance_to(outline.position) - 0.01, "The plating is never outside the hull.")
	assert_gt(on_plating, 20, "Most shots land on the plating")
	assert_gt(through_gaps, 0, "and some pass between the wings, where the hull is only air.")
