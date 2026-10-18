# Tests for MeshLod (levels of detail by camera distance; hit marks on LOD0 only) and the
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
	assert_eq(lod1_hull.material_override.get_shader_param("damage_mark_strength"), 0.0, "Lower levels show no marks")
	assert_eq(material.get_shader_param("damage_mark_strength"), 1.0, "and the original material is untouched.")
	var scorch = HullScorch.new()
	add_child_autofree(scorch)
	scorch.setup(root)
	assert_eq(scorch._meshes.size(), 1, "Marks are painted on LOD0 only.")
	assert_eq(scorch._meshes[0].instance, model.get_node("Hull joined"))
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

