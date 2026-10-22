# Tests for HullScars: where a hit's scar blob sits and how it is shaped, the per-ship pool of
# scars, and keeping them in the save.

extends GutTest

const HullScars = preload("res://src/core/agents/effects/hull_scars.gd")


func _scars() -> MultiMeshInstance:
	var scars = HullScars.new()
	add_child_autofree(scars)
	return scars


func test_head_on_scar_stands_on_the_normal_and_sinks_in():
	var size := 2.0
	var placed: Transform = HullScars.scar_transform(Vector3(0, 5, 0), Vector3.UP, Vector3.DOWN, size)
	var height: float = size * Constants.HULL_SCAR_FLATNESS
	assert_almost_eq(placed.basis.y.normalized().dot(Vector3.UP), 1.0, 0.001, "Up along the plating's normal")
	assert_almost_eq(placed.basis.y.length(), height, 0.001, "flattened")
	assert_almost_eq(placed.basis.x.length(), size, 0.001, "as wide as asked")
	assert_almost_eq(placed.basis.z.length(), size, 0.001, "and round: head-on hits do not stretch")
	assert_almost_eq(placed.origin, Vector3(0, 5 - height * Constants.HULL_SCAR_SINK, 0), Vector3.ONE * 0.001, "Its centre below the plating.")
	assert_gt(placed.basis.determinant(), 0.0, "Right-handed, so it is not drawn inside out.")


func test_back_face_normal_turns_toward_the_shooter():
	var placed: Transform = HullScars.scar_transform(Vector3.ZERO, Vector3.DOWN, Vector3.DOWN, 1.0)
	assert_almost_eq(placed.basis.y.normalized().dot(Vector3.UP), 1.0, 0.001)


func test_glancing_scar_stretches_along_the_beam():
	var beam: Vector3 = Vector3(1, -0.2, 0).normalized()  # Nearly along the plating
	var placed: Transform = HullScars.scar_transform(Vector3.ZERO, Vector3.UP, beam, 1.0)
	assert_almost_eq(placed.basis.z.normalized().dot(Vector3.RIGHT), 1.0, 0.001, "Along the beam's track on the plating")
	assert_almost_eq(placed.basis.z.length(), 1.0 / Constants.HULL_SCAR_MIN_FACING, 0.001, "stretched up to the cap")
	assert_almost_eq(placed.basis.x.length(), 1.0, 0.001, "but no wider.")
	var steeper: Transform = HullScars.scar_transform(Vector3.ZERO, Vector3.UP, Vector3(1, -1, 0).normalized(), 1.0)
	assert_almost_eq(steeper.basis.z.length(), sqrt(2.0), 0.001, "At 45 degrees: 1 / cos.")


func test_twist_turns_about_the_normal_only():
	var placed: Transform = HullScars.scar_transform(Vector3.ZERO, Vector3.UP, Vector3.DOWN, 1.0, 1.0)
	assert_almost_eq(placed.basis.y.normalized().dot(Vector3.UP), 1.0, 0.001)


func test_size_follows_damage_within_limits():
	assert_almost_eq(HullScars.size_for_damage(6.0), Constants.HULL_SCAR_SIZE_PER_SQRT_DAMAGE * sqrt(6.0), 0.001)
	assert_eq(HullScars.size_for_damage(0.0), Constants.HULL_SCAR_MIN_SIZE)
	assert_eq(HullScars.size_for_damage(10000.0), Constants.HULL_SCAR_MAX_SIZE)


func test_scars_sit_where_hits_landed_on_a_moved_ship():
	var ship = Spatial.new()
	add_child_autofree(ship)
	ship.transform = Transform(Basis(Vector3.UP, 1.0).scaled(Vector3.ONE * 2.0), Vector3(100, 0, 0))
	var scars = HullScars.new()
	ship.add_child(scars)
	scars.add_scar(Vector3(100, 10, 0), Vector3.UP, Vector3.DOWN, 6.0)
	var world: Transform = scars.global_transform * scars.get_scar_transform(0)
	var size: float = HullScars.size_for_damage(6.0)
	var height: float = size * Constants.HULL_SCAR_FLATNESS
	assert_almost_eq(world.origin, Vector3(100, 10 - height * Constants.HULL_SCAR_SINK, 0), Vector3.ONE * 0.01, "At the hit, in world space")
	assert_almost_eq(world.basis.x.length(), size, 0.01, "and its size in metres, whatever the ship's scale.")


func test_pool_keeps_the_newest_scars():
	var scars = _scars()
	for i in range(Constants.HULL_SCAR_MAX_PER_SHIP + 5):
		scars.add_scar(Vector3(i * 10.0, 0, 0), Vector3.UP, Vector3.DOWN, 6.0)
	assert_eq(scars.get_scar_count(), Constants.HULL_SCAR_MAX_PER_SHIP)
	var kept: Array = scars.export_scars()
	assert_almost_eq(float(kept[0][9]), 5 * 10.0, 0.01, "Oldest kept first: the first five gave way")
	assert_almost_eq(float(kept.back()[9]), (Constants.HULL_SCAR_MAX_PER_SHIP + 4) * 10.0, 0.01, "newest last.")


func test_a_hit_on_a_scar_reheats_and_grows_it():
	var scars = _scars()
	scars.add_scar(Vector3.ZERO, Vector3.UP, Vector3.DOWN, 6.0)
	var before: Color = scars.get_scar_data(0)
	scars.add_scar(Vector3(0.1, 0, 0), Vector3.UP, Vector3.DOWN, 6.0)
	assert_eq(scars.get_scar_count(), 1, "No second scar")
	var after: Color = scars.get_scar_data(0)
	assert_almost_eq(after.a, before.a * Constants.HULL_SCAR_REHEAT_GROWTH, 0.001, "it grew")
	assert_true(after.r >= before.r, "and was hit again.")


func test_export_import_round_trip_comes_back_cold():
	var scars = _scars()
	scars.add_scar(Vector3(1, 2, 3), Vector3.UP, Vector3(1, -1, 0).normalized(), 6.0)
	scars.add_scar(Vector3(20, 2, 3), Vector3.RIGHT, Vector3.LEFT, 12.0)
	var saved: Array = scars.export_scars()
	var restored = _scars()
	restored.import_scars(saved)
	assert_eq(restored.get_scar_count(), 2)
	assert_eq_deep(restored.export_scars(), saved)
	var data: Color = restored.get_scar_data(0)
	assert_lt(data.r, HullScars.clock() - Constants.HULL_SCAR_COOL_TIME, "Loaded scars are cold.")
	restored.import_scars([[1, 2, 3], "junk"])
	assert_eq(restored.get_scar_count(), 0, "Malformed entries are skipped.")


func test_clear_removes_every_scar():
	var scars = _scars()
	scars.add_scar(Vector3.ZERO, Vector3.UP, Vector3.DOWN, 6.0)
	scars.clear_scars()
	assert_eq(scars.get_scar_count(), 0)
	assert_eq(scars.export_scars().size(), 0)
