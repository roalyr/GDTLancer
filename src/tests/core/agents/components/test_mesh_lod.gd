# Tests for MeshLod (levels of detail by camera distance; marks painted on every level) and the
# hit-flash light limits.

extends GutTest

const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const HullScorch = preload("res://src/core/agents/components/hull_scorch.gd")
const PHOENIX = "res://assets/models/ships/Phoenix_light.glb"


func test_levels_follow_distance_in_object_radii_with_hysteresis():
	var radius := 10.0
	var first: float = Constants.LOD_DISTANCE_RADII[0] * radius
	assert_eq(MeshLod.level_for(first * 0.5, radius, 0, 4), 0, "Close: full detail.")
	assert_eq(MeshLod.level_for(first * 1.05, radius, 0, 4), 0, "Just past the threshold: holds until clearly past")
	assert_eq(MeshLod.level_for(first * 1.2, radius, 0, 4), 1, "then drops a level.")
	assert_eq(MeshLod.level_for(first * 0.95, radius, 1, 4), 1, "Coming back: holds until clearly inside")
	assert_eq(MeshLod.level_for(first * 0.8, radius, 1, 4), 0, "then returns to full detail.")
	assert_eq(MeshLod.level_for(1.0e9, radius, 0, 4), 3, "Far: the last level")
	assert_eq(MeshLod.level_for(1.0e9, radius, 0, 2), 1, "never past the levels there are.")
	assert_gt(MeshLod.level_for(first * 1.2, radius * 10.0, 0, 4), -1)
	assert_eq(MeshLod.level_for(first * 1.2, radius * 10.0, 0, 4), 0, "A bigger object keeps its detail further out.")


func test_finds_generated_lod_files_and_never_for_nebulas():
	var paths: Array = MeshLod.lod_paths_for(PHOENIX)
	assert_eq(paths.size(), 3)
	assert_eq(paths[0], "res://assets/models/ships/lod/Phoenix_light_LOD1.glb")
	assert_eq(MeshLod.lod_paths_for("res://assets/models/nebulas/nebula_1.glb"), [])


func test_attached_levels_show_one_at_a_time_and_only_lod0_takes_marks():
	var root = Spatial.new()
	add_child_autofree(root)
	var model: Spatial = load(PHOENIX).instance()
	root.add_child(model)
	var material: ShaderMaterial = load("res://assets/art/materials_generic/mat_engine_dark_alloy.tres")
	model.get_node("Hull joined").material_override = material
	var lods: Array = MeshLod.attach(root, 12.0)
	assert_eq(lods.size(), 1)
	var lod = lods[0]
	assert_eq(lod.levels.size(), 4, "LOD0 plus three.")
	var lod1_hull: MeshInstance = lod.levels[1].get_node("Hull joined")
	assert_true(lod1_hull.is_in_group("lod_mesh"))
	assert_eq(lod1_hull.material_override, material, "Lower levels take the original's material.")
	var scorch = HullScorch.new()
	add_child_autofree(scorch)
	scorch.setup(root)
	assert_eq(scorch._meshes.size(), 1, "The beam lands on full detail")
	assert_eq(scorch._meshes[0].instance, model.get_node("Hull joined"))
	assert_eq(scorch._lod_meshes.size(), 3, "and every lower level gets painted too.")
	assert_ne(lod1_hull.material_override, material, "Each level gets the ship's own material copy (its clock).")
	lod.show_level(2)
	assert_false(lod.levels[0].visible)
	assert_true(lod.levels[2].visible)
	assert_false(lod.levels[1].visible or lod.levels[3].visible, "One level at a time.")


func test_hit_flash_lights_only_near_the_camera_and_only_a_few_at_once():
	var camera = Camera.new()
	add_child_autofree(camera)
	camera.current = true
	var effect = load("res://scenes/prefabs/effects/laser_hit.tscn").instance()
	effect.damage = 6.0
	add_child_autofree(effect)
	assert_true(effect.should_light(Vector3(0, 0, -100)), "Near: lit")
	assert_false(effect.should_light(Vector3(0, 0, -Constants.HIT_FX_LIGHT_DISTANCE - 1.0)), "far: glow only.")
	var lights: Array = []
	for _i in range(Constants.HIT_FX_MAX_LIGHTS):
		var light = OmniLight.new()
		light.add_to_group("hit_fx_light")
		add_child_autofree(light)
		lights.append(light)
	assert_false(effect.should_light(Vector3(0, 0, -100)), "Enough flashes lit already.")


func test_dense_meshes_never_keep_more_detail_than_low_poly_ones():
	for radii in range(1, 300, 3):
		var distance: float = radii * 100.0
		var dense: int = MeshLod.level_for(distance, 100.0, 0, 4, Constants.LOD_DISTANCE_RADII_DENSE)
		var low_poly: int = MeshLod.level_for(distance, 100.0, 0, 4)
		assert_true(dense >= low_poly, "At %d radii: dense LOD%d, low-poly LOD%d" % [radii, dense, low_poly])


func test_lod_surfaces_take_the_material_of_the_same_name():
	var root = Spatial.new()
	add_child_autofree(root)
	var model: Spatial = load(PHOENIX).instance()
	root.add_child(model)
	var hull: MeshInstance = model.get_node("Hull joined")
	var assigned := {}
	for surface in range(hull.mesh.get_surface_count()):
		var material := SpatialMaterial.new()
		hull.set_surface_material(surface, material)
		assigned[MeshLod.material_key(hull.mesh.surface_get_material(surface))] = material
	var lod = MeshLod.attach(root, 12.0)[0]
	var lod2_hull: MeshInstance = lod.levels[2].get_node("Hull joined")
	assert_lt(lod2_hull.mesh.get_surface_count(), hull.mesh.get_surface_count(), "This level lost a material (the small glow strips)")
	for surface in range(lod2_hull.mesh.get_surface_count()):
		var key: String = MeshLod.material_key(lod2_hull.mesh.surface_get_material(surface))
		assert_eq(lod2_hull.get_surface_material(surface), assigned[key], "but each surface still gets its own material: " + key)


func test_material_key_drops_blender_duplicate_suffixes():
	var material := SpatialMaterial.new()
	material.resource_name = "paint 1 main color.001"
	assert_eq(MeshLod.material_key(material), "paint 1 main color")
	material.resource_name = "v1.5 alloy"
	assert_eq(MeshLod.material_key(material), "v1.5 alloy", "Only a numeric suffix is dropped.")


func test_a_hit_marks_and_heats_every_level_at_the_same_spot():
	var root = Spatial.new()
	add_child_autofree(root)
	var model: Spatial = load(PHOENIX).instance()
	root.add_child(model)
	model.get_node("Hull joined").material_override = load("res://assets/art/materials_generic/mat_engine_dark_alloy.tres")
	MeshLod.attach(root, 12.0)
	var scorch = HullScorch.new()
	add_child_autofree(scorch)
	scorch.setup(root)
	var clock_at_hit: float = scorch._clock
	assert_gt(scorch.add_hit(Vector3(0, 60, 0), Vector3.ZERO, 30.0), 0, "Hit from above.")
	var hit: Vector3 = scorch.last_hit_point
	for entry in scorch._lod_meshes:
		assert_eq(entry.pending.size(), 1, "Hidden levels wait")
	scorch._clock += 2.0  # Time passes before the levels show
	for entry in scorch._lod_meshes:
		entry.instance.get_parent().visible = true
	for _i in range(20):
		scorch._replay_pending()
	for entry in scorch._lod_meshes:
		assert_true(entry.pending.empty(), "and are painted once shown")
		assert_eq(entry.arrays[entry.paintable[0]][Mesh.ARRAY_TEX_UV2].size() > 0, true)
		var hottest := 0.0
		var hottest_at := Vector3.ZERO
		var marked := 0
		for surface in entry.paintable:
			var arrays: Array = entry.arrays[surface]
			for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var heat: float = scorch.get_heat(arrays[Mesh.ARRAY_TEX_UV2][i])
				if heat > hottest:
					hottest = heat
					hottest_at = arrays[Mesh.ARRAY_VERTEX][i]
				if arrays[Mesh.ARRAY_COLOR][i].a < 1.0:
					marked += 1
		assert_gt(hottest, 0.5, "Every level glows")
		var stamped := false
		for surface in entry.paintable:
			for stored in entry.arrays[surface][Mesh.ARRAY_TEX_UV2]:
				if stored.y > 0.0:
					stamped = stamped or is_equal_approx(stored.x, clock_at_hit)
		assert_true(stamped, "with heat stamped at the hit's own time, so it has cooled as on the full-detail hull")
		assert_true(hottest_at.distance_to(hit) < Constants.SCORCH_RADIUS_PER_SQRT_DAMAGE * sqrt(30.0) * Constants.SCORCH_HEAT_SPREAD, "where the beam landed")
		assert_gt(marked, 0, "and is charred there.")
		assert_true(entry.dirty, "Uploaded once shown.")


func test_vertex_grid_finds_the_vertices_near_a_point():
	var VertexGrid = load("res://src/core/agents/components/vertex_grid.gd")
	var positions := PoolVector3Array()
	for i in range(1000):
		positions.append(Vector3(i % 10, (i / 10) % 10, i / 100))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	var grid: Dictionary = VertexGrid.build([arrays, arrays], [1])
	var found: Array = VertexGrid.query(grid, Vector3(5, 5, 5), 1.0)
	assert_true(found.has(1 * VertexGrid.STRIDE + 555), "The vertex at the point, tagged with its surface")
	for i in range(positions.size()):
		if positions[i].distance_to(Vector3(5, 5, 5)) <= 1.0:
			assert_true(found.has(VertexGrid.STRIDE + i), "and every vertex within reach.")
	assert_lt(found.size(), 300, "Not the whole mesh.")
	assert_eq(VertexGrid.query(grid, Vector3(5, 5, 5), 50.0).size(), 1000, "A reach past the mesh finds all of it.")
