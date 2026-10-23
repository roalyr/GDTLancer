# Tests for MeshLod (levels of detail by the host's view band).

extends GutTest

const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const ViewDetail = preload("res://src/core/agents/components/view_detail.gd")
const PHOENIX = "res://assets/models/ships/Phoenix_light.glb"


func test_levels_follow_the_view_band():
	assert_eq(MeshLod.level_for_band(Constants.VIEW_CLOSE, 4), 0, "Close: full detail")
	assert_eq(MeshLod.level_for_band(Constants.VIEW_DOT, 4), 3, "a dot: the last level,")
	assert_eq(MeshLod.level_for_band(Constants.VIEW_DOT, 2), 1, "never past the levels there are.")
	for band in range(Constants.VIEW_DOT):
		assert_true(MeshLod.level_for_band(band + 1, 4) >= MeshLod.level_for_band(band, 4), "Smaller on screen never means more detail.")


func test_levels_change_with_the_hosts_band():
	var host = Spatial.new()
	add_child_autofree(host)
	var detail = ViewDetail.attach(host, 12.0)
	var root = Spatial.new()
	host.add_child(root)
	root.add_child(load(PHOENIX).instance())
	var lod = MeshLod.attach(root, detail)[0]
	assert_eq(lod.level, 0, "Shown in full until judged")
	detail.band = Constants.VIEW_FAR
	detail.emit_signal("band_changed", detail.band)
	assert_eq(lod.level, MeshLod.level_for_band(Constants.VIEW_FAR, 4))
	assert_true(lod.levels[lod.level].visible)


func test_finds_generated_lod_files_and_never_for_nebulas():
	var paths: Array = MeshLod.lod_paths_for(PHOENIX)
	assert_eq(paths.size(), 3)
	assert_eq(paths[0], "res://assets/models/ships/lod/Phoenix_light_LOD1.glb")
	assert_eq(MeshLod.lod_paths_for("res://assets/models/nebulas/nebula_1.glb"), [])


func test_attached_levels_show_one_at_a_time():
	var root = Spatial.new()
	add_child_autofree(root)
	var model: Spatial = load(PHOENIX).instance()
	root.add_child(model)
	var material: ShaderMaterial = load("res://assets/art/materials_generic/mat_engine_dark_alloy.tres")
	model.get_node("Hull joined").material_override = material
	var lods: Array = MeshLod.attach(root, null)
	assert_eq(lods.size(), 1)
	var lod = lods[0]
	assert_eq(lod.levels.size(), 4, "LOD0 plus three.")
	var lod1_hull: MeshInstance = lod.levels[1].get_node("Hull joined")
	assert_true(lod1_hull.is_in_group("lod_mesh"))
	assert_eq(lod1_hull.material_override, material, "Lower levels take the original's material.")
	lod.show_level(2)
	assert_false(lod.levels[0].visible)
	assert_true(lod.levels[2].visible)
	assert_false(lod.levels[1].visible or lod.levels[3].visible, "One level at a time.")


func test_dense_meshes_never_keep_more_detail_than_low_poly_ones():
	for band in range(Constants.VIEW_DOT + 1):
		var dense: int = MeshLod.level_for_band(band, 4, Constants.LOD_LEVEL_BY_BAND_DENSE)
		var low_poly: int = MeshLod.level_for_band(band, 4)
		assert_true(dense >= low_poly, "Band %d: dense LOD%d, low-poly LOD%d" % [band, dense, low_poly])


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
	var lod = MeshLod.attach(root, null)[0]
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
