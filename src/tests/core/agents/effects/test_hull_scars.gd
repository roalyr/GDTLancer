# Tests for HullScars: where a hit's scar blob sits and how it is shaped, the per-ship pool of
# scars, slag on them, and keeping them in the save.

extends GutTest

const HullScars = preload("res://src/core/agents/effects/hull_scars.gd")
const ViewDetail = preload("res://src/core/agents/components/view_detail.gd")


func _scars() -> Spatial:
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


func test_a_hit_on_a_scar_adds_a_new_one_and_never_grows_the_old():
	var scars = _scars()
	scars.add_scar(Vector3.ZERO, Vector3.UP, Vector3.DOWN, 6.0)
	var before: Color = scars.get_scar_data(0)
	scars.add_scar(Vector3(0.1, 0, 0), Vector3.UP, Vector3.DOWN, 6.0)
	assert_eq(scars.get_scar_count(), 2, "A second scar")
	assert_eq(scars.get_scar_data(0), before, "and the first is as it was.")


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


func test_slag_sits_on_the_newest_scars_fewest_first():
	var scars = _scars()
	scars.set_slag_count(3)
	assert_eq(scars.get_slag_count(), 0, "No scars, no slag")
	for i in range(3):
		scars.add_scar(Vector3(i * 10.0, 0, 0), Vector3.UP, Vector3.DOWN, 6.0)
	scars.set_slag_count(Constants.HULL_SLAG_MAX)
	assert_eq(scars.get_slag_count(), int(min(3 * Constants.HULL_SLAG_PER_SCAR, scars.get_slag_capacity())), "at most HULL_SLAG_PER_SCAR on a scar")
	assert_eq(scars.get_slag_scar(0), 2, "the first on the newest scar,")
	assert_eq(scars.get_slag_scar(1), 1, "then one on each older scar")
	assert_eq(scars.get_slag_scar(3), 2, "before any scar gets a second.")
	var slag: Transform = scars.get_slag_transform(0)
	var newest: Transform = scars.get_scar_transform(2)
	assert_lt(slag.origin.distance_to(newest.origin), newest.basis.x.length(), "On its scar")
	assert_almost_eq(slag.basis.x.length(), min(newest.basis.x.length() * Constants.HULL_SLAG_SIZE_SHARE, Constants.HULL_SLAG_MAX_SIZE), 0.001, "and smaller,")
	scars.set_slag_count(0)
	scars.add_scar(Vector3(100, 0, 0), Vector3.UP, Vector3.DOWN, 10000.0)
	scars.set_slag_count(1)
	assert_eq(scars.get_slag_scar(0), 3)
	assert_almost_eq(scars.get_slag_transform(0).basis.x.length(), Constants.HULL_SLAG_MAX_SIZE, 0.001, "never larger than the cap.")
	scars.clear_scars()
	assert_eq(scars.get_slag_count(), 0, "A repair clears it.")


func test_slag_moves_with_its_scar_when_the_scar_gives_way():
	var scars = _scars()
	for i in range(scars.get_scar_capacity()):
		scars.add_scar(Vector3(i * 10.0, 0, 0), Vector3.UP, Vector3.DOWN, 6.0)
	scars.set_slag_count(scars.get_slag_capacity())
	var oldest_slot := 0
	var slag_on_oldest := -1
	for k in range(scars.get_slag_count()):
		if scars.get_slag_scar(k) == oldest_slot:
			slag_on_oldest = k
	if slag_on_oldest < 0:
		pending("No slag on the oldest scar at this capacity")
		return
	scars.add_scar(Vector3(0, 0, 500), Vector3.UP, Vector3.DOWN, 6.0)  # Takes the oldest scar's slot
	var moved: Transform = scars.get_slag_transform(slag_on_oldest)
	assert_lt(moved.origin.distance_to(scars.get_scar_transform(oldest_slot).origin), 2.0, "The slag sits on the new scar, not on bare plating.")


func test_blobs_merge_into_chunks_one_draw_call_each():
	var scars = _scars()
	for i in range(5):
		scars.add_scar(Vector3(i * 10.0, 0, 0), Vector3.UP, Vector3.DOWN, 6.0)
	scars.set_slag_count(3)
	scars.flush()
	assert_eq(scars.get_draw_count(), 2, "A few scars and slag: one chunk each")
	var template: int = HullScars.ScarMesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX].size()
	var slag_template: int = HullScars.SlagMesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX].size()
	assert_lt(slag_template, template, "Slag uses the lighter template")
	assert_eq(scars.get_vertex_count(), 5 * template + 3 * slag_template)
	for i in range(5, Constants.HULL_SCAR_CHUNK_BLOBS + 1):
		scars.add_scar(Vector3(i * 10.0, 0, 0), Vector3.UP, Vector3.DOWN, 6.0)
	scars.flush()
	assert_eq(scars.get_draw_count(), 3, "One more scar than a chunk holds: a second scar chunk")
	scars.clear_scars()
	assert_eq(scars.get_draw_count(), 0, "Nothing left to draw after a repair.")


func test_a_new_scar_rebuilds_only_its_chunk():
	var scars = _scars()
	for i in range(Constants.HULL_SCAR_CHUNK_BLOBS + 1):
		scars.add_scar(Vector3(i * 10.0, 0, 0), Vector3.UP, Vector3.DOWN, 6.0)
	scars.flush()
	var before: Array = scars._blobs[0]
	scars.add_scar(Vector3(0, 0, 500), Vector3.UP, Vector3.DOWN, 6.0)  # Slot 17: the second chunk
	assert_eq(scars._dirty.keys(), [1], "Only the newest chunk is marked")
	scars.flush()
	assert_eq(scars._blobs[0], before, "and the first chunk's blobs were not worked out again.")


func test_hidden_ships_only_keep_placements():
	var scars = _scars()
	scars.show_band(Constants.VIEW_DOT)  # As if too small on screen
	assert_false(scars.visible)
	scars.add_scar(Vector3.ZERO, Vector3.UP, Vector3.DOWN, 6.0)
	scars._process(1.0)
	assert_null(scars._blobs[0], "No vertices worked out for a ship nobody sees")
	assert_eq(scars.get_scar_count(), 1, "but the scar is kept")
	scars.flush()
	assert_not_null(scars._blobs[0], "and built once asked for.")


func test_scars_and_slag_follow_the_ships_view_band():
	var ship = Spatial.new()
	add_child_autofree(ship)
	var detail = ViewDetail.attach(ship, 15.0)
	var scars = HullScars.new()
	ship.add_child(scars)
	assert_true(scars.visible, "A new ship shows everything until judged")
	detail.band = Constants.HULL_SLAG_MAX_BAND + 1
	detail.emit_signal("band_changed", detail.band)
	assert_eq(scars.visible, Constants.HULL_SLAG_MAX_BAND + 1 <= Constants.HULL_SCAR_MAX_BAND, "Past the slag's band: scars as their band says")
	assert_false(scars.get_node("Slag").visible, "and no slag.")
	detail.emit_signal("band_changed", Constants.VIEW_DOT)
	assert_false(scars.visible, "A dot shows no scars.")


func test_blob_vertices_carry_hit_time_seed_and_facing():
	var data := Color(123.5, 0.25, 0.75, 2.0)
	var blob: Array = HullScars._blob_arrays(HullScars.ScarMesh, Transform(Basis().scaled(Vector3(2, 0.7, 2)), Vector3(0, 5, 0)), data, 0.0)
	assert_eq(blob[0].size(), blob[2].size())
	for k in range(blob[0].size()):
		assert_eq(blob[2][k], Vector2(123.5, 0.25))
		assert_almost_eq(blob[3][k].r, 0.75, 0.0001)
		assert_lt(abs(blob[0][k].y - 5.0), 0.36, "Placed: squashed to 0.7 high, at y 5")
		assert_almost_eq(blob[1][k].length(), 1.0, 0.001, "with unit normals.")
