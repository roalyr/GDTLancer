# Tests for HullScorch: hits mark vertex alpha on the surface facing the shooter, in proportion to damage.

extends GutTest

const HullScorch = preload("res://src/core/agents/components/hull_scorch.gd")

var ship: Spatial = null
var mesh_instance: MeshInstance = null
var scorch: Node = null


func before_each():
	ship = Spatial.new()
	add_child_autofree(ship)
	mesh_instance = MeshInstance.new()
	mesh_instance.mesh = _make_coloured_box(Vector3(20, 4, 20), 24)
	var material = ShaderMaterial.new()
	material.shader = load("res://assets/art/shaders/solid_dither_no_alpha_no_texture_8x8.gdshader")
	mesh_instance.material_override = material
	ship.add_child(mesh_instance)
	scorch = HullScorch.new()
	ship.add_child(scorch)
	scorch.setup(mesh_instance)


# A subdivided box with white vertex colours, like an imported hull.
func _make_coloured_box(size: Vector3, subdivisions: int) -> ArrayMesh:
	var cube = CubeMesh.new()
	cube.size = size
	cube.subdivide_width = subdivisions
	cube.subdivide_height = subdivisions
	cube.subdivide_depth = subdivisions
	var arrays: Array = cube.surface_get_arrays(0)
	var colors := PoolColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	for i in range(colors.size()):
		colors[i] = Color.white
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _mark_of_vertices(predicate: FuncRef) -> float:
	var arrays: Array = scorch._meshes[0].arrays[0]
	var total := 0.0
	var count := 0
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		if predicate.call_func(arrays[Mesh.ARRAY_VERTEX][i]):
			total += 1.0 - arrays[Mesh.ARRAY_COLOR][i].a
			count += 1
	return total / max(count, 1)


func _is_top_face(position: Vector3) -> bool:
	return position.y > 1.99


func _is_bottom_face(position: Vector3) -> bool:
	return position.y < -1.99


func test_hit_from_above_marks_only_the_top_surface():
	var painted: int = scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	assert_gt(painted, 0)
	assert_gt(_mark_of_vertices(funcref(self, "_is_top_face")), 0.0, "Top face, facing the shooter, is marked.")
	assert_eq(_mark_of_vertices(funcref(self, "_is_bottom_face")), 0.0, "Far side stays clean.")


func test_mark_area_grows_with_damage():
	var small: int = scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 1.0)
	before_each()
	var large: int = scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 9.0)
	assert_gt(large, small * 4, "Radius ~ sqrt(damage), so marked area ~ damage (9x here).")


func test_repeated_hits_accumulate_and_saturate():
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	var once: float = scorch.get_average_mark()
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	assert_gt(scorch.get_average_mark(), once, "A second hit on the same spot deepens the mark.")
	for _i in range(60):
		scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	var deepest := 0.0
	var arrays: Array = scorch._meshes[0].arrays[0]
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		deepest = max(deepest, 1.0 - arrays[Mesh.ARRAY_COLOR][i].a)
	assert_true(deepest <= 1.0, "Marks saturate at fully marked.")
	assert_gt(deepest, 0.95)


func test_ship_gets_its_own_material_copy_and_shared_material_is_untouched():
	var shared = ShaderMaterial.new()
	shared.shader = load("res://assets/art/shaders/solid_dither_no_alpha_no_texture_8x8.gdshader")
	mesh_instance.material_override = shared
	scorch.setup(mesh_instance)
	assert_ne(mesh_instance.material_override, shared, "The shared material is never edited.")
	scorch._process(1.0)
	assert_eq(mesh_instance.material_override.get_shader_param("damage_time"), 1.0, "The ship's clock drives its own copy.")
	var shared_time = shared.get_shader_param("damage_time")
	assert_true(shared_time == null or shared_time == 0.0)


func test_meshes_without_vertex_colours_get_a_white_set():
	var plain = MeshInstance.new()
	plain.mesh = CubeMesh.new()
	var material = ShaderMaterial.new()
	material.shader = load("res://assets/art/shaders/simple_solid_NLP.gdshader")
	plain.material_override = material
	ship.add_child(plain)
	scorch.setup(plain)
	assert_true(scorch.is_paintable(), "Any solid-shader mesh can be marked.")
	assert_eq(scorch._meshes[0].arrays[0][Mesh.ARRAY_COLOR][0], Color.white)


func test_meshes_without_a_marking_shader_are_left_alone():
	var plain = MeshInstance.new()
	plain.mesh = CubeMesh.new()
	ship.add_child(plain)
	scorch.setup(plain)
	assert_false(scorch.is_paintable())


func test_rebuild_gives_ship_its_own_mesh_copy():
	var shared_mesh = mesh_instance.mesh
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	scorch.rebuild_meshes()
	assert_ne(mesh_instance.mesh, shared_mesh, "Painting never touches the shared imported mesh.")
	assert_eq(mesh_instance.mesh.get_surface_count(), 1)


func test_hit_heats_the_mark_and_it_cools_over_time():
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	var hottest := 0.0
	var arrays: Array = scorch._meshes[0].arrays[0]
	for value in arrays[Mesh.ARRAY_TEX_UV2]:
		hottest = max(hottest, scorch.get_heat(value))
	assert_between(hottest, HullScorch.HEAT_PER_DAMAGE * 6.0 * 0.8, HullScorch.HEAT_PER_DAMAGE * 6.0, "Heat near the mark centre is proportional to damage.")
	scorch._process(HullScorch.COOL_TIME)
	var cooled := 0.0
	for value in arrays[Mesh.ARRAY_TEX_UV2]:
		cooled = max(cooled, scorch.get_heat(value))
	assert_almost_eq(cooled, hottest * exp(-1.0), 0.01, "One cool time later the heat is down to ~37%.")


func test_reheating_adds_to_remaining_heat_up_to_cap():
	for _i in range(20):
		scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	var hottest := 0.0
	for value in scorch._meshes[0].arrays[0][Mesh.ARRAY_TEX_UV2]:
		hottest = max(hottest, scorch.get_heat(value))
	assert_almost_eq(hottest, HullScorch.MAX_HEAT, 0.001)


func test_hit_point_is_on_the_surface_facing_the_shooter():
	scorch.add_hit(Vector3(0, 200, 0), Vector3(3, 0, -2), 6.0)
	assert_not_null(scorch.last_hit_point)
	assert_almost_eq(scorch.last_hit_point.y, 2.0, 0.01, "Lands on the top face.")
	assert_almost_eq(Vector2(scorch.last_hit_point.x, scorch.last_hit_point.z).distance_to(Vector2(3, -2)), 0.0, 1.5, "Near where the aimed line enters.")


func test_shot_line_that_misses_the_hull_marks_nothing():
	var painted: int = scorch.add_hit(Vector3(0, 200, 0), Vector3(100, 0, 0), 6.0)
	assert_eq(painted, 0)
	assert_null(scorch.last_hit_point)

