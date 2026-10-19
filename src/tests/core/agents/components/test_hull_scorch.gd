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
	assert_between(hottest, Constants.SCORCH_HEAT_PER_DAMAGE * 6.0 * 0.8, Constants.SCORCH_HEAT_PER_DAMAGE * 6.0 + 0.001, "Heat near the mark centre is proportional to damage.")
	scorch._process(Constants.SCORCH_COOL_TIME)
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
	assert_almost_eq(hottest, Constants.SCORCH_MAX_HEAT, 0.001)


func test_hit_point_is_on_the_surface_facing_the_shooter():
	scorch.add_hit(Vector3(0, 200, 0), Vector3(3, 0, -2), 6.0)
	assert_not_null(scorch.last_hit_point)
	assert_almost_eq(scorch.last_hit_point.y, 2.0, 0.01, "Lands on the top face.")
	assert_almost_eq(scorch.last_hit_normal.dot(Vector3.UP), 1.0, 0.001, "Reports the surface normal there.")
	assert_almost_eq(Vector2(scorch.last_hit_point.x, scorch.last_hit_point.z).distance_to(Vector2(3, -2)), 0.0, 1.5, "Near where the aimed line enters.")


func test_shot_line_that_misses_the_hull_marks_nothing():
	var painted: int = scorch.add_hit(Vector3(0, 200, 0), Vector3(100, 0, 0), 6.0)
	assert_eq(painted, 0)
	assert_null(scorch.last_hit_point)


func test_marks_export_and_import_onto_a_fresh_hull():
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	var marks: Dictionary = scorch.export_marks()
	assert_eq(marks.size(), 1, "Only marked surfaces are exported.")
	var marked: float = scorch.get_average_mark()
	before_each()
	assert_eq(scorch.get_average_mark(), 0.0)
	scorch.import_marks(marks)
	assert_almost_eq(scorch.get_average_mark(), marked, 0.0001, "A respawned hull shows the same marks.")
	scorch.clear_marks()
	assert_eq(scorch.get_average_mark(), 0.0, "Repair restores a clean hull.")


func test_marks_for_a_different_mesh_are_ignored():
	scorch.import_marks({"0:0": PoolRealArray([0.5, 0.5])})
	assert_eq(scorch.get_average_mark(), 0.0)


func test_thin_details_in_front_of_the_hull_are_passed():
	var antenna = MeshInstance.new()
	var pole = CubeMesh.new()
	pole.size = Vector3(0.2, 10, 0.2)
	antenna.mesh = pole
	antenna.material_override = mesh_instance.material_override
	antenna.translation = Vector3(0, 7, 0)
	ship.add_child(antenna)
	scorch.setup(ship)
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	assert_almost_eq(scorch.last_hit_point.y, 2.0, 0.01, "The shot lands on the hull, not the antenna tip at y=12.")


func _heated(threshold: float) -> int:
	var count := 0
	for value in scorch._meshes[0].arrays[0][Mesh.ARRAY_TEX_UV2]:
		if scorch.get_heat(value) > threshold:
			count += 1
	return count


func test_stronger_beam_heats_a_wider_area():
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 3.0)
	var weak: int = _heated(0.0)
	before_each()
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 12.0)
	assert_gt(_heated(0.0), weak * 2, "Heat radius grows with beam power.")


func test_weak_hit_stays_below_the_glow_threshold():
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 1.0)
	assert_gt(_heated(0.0), 0, "It still warms the surface")
	assert_eq(_heated(Constants.SCORCH_GLOW_THRESHOLD), 0, "but not enough to glow.")
	before_each()
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 12.0)
	assert_gt(_heated(Constants.SCORCH_GLOW_THRESHOLD), 0, "A powerful beam glows at once.")



func _setup_box(size: Vector3) -> void:
	mesh_instance.mesh = _make_coloured_box(size, 24)
	scorch.setup(mesh_instance)


func _surface_state(predicate: FuncRef) -> Dictionary:
	var arrays: Array = scorch._meshes[0].arrays[0]
	var state := {"heated": 0, "charred": 0}
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		if predicate.call_func(arrays[Mesh.ARRAY_VERTEX][i], arrays[Mesh.ARRAY_NORMAL][i]):
			if scorch.get_heat(arrays[Mesh.ARRAY_TEX_UV2][i]) > 0.0:
				state.heated += 1
			if arrays[Mesh.ARRAY_COLOR][i].a < 1.0:
				state.charred += 1
	return state


func _underside(_position: Vector3, normal: Vector3) -> bool:
	return normal.y < -0.9


func _upper_side(_position: Vector3, normal: Vector3) -> bool:
	return normal.y > 0.9


func _right_side(_position: Vector3, normal: Vector3) -> bool:
	return normal.x > 0.9


func test_thin_plate_heats_through_but_chars_only_the_lit_side():
	_setup_box(Vector3(20, 0.3, 20))
	scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0)
	var top: Dictionary = _surface_state(funcref(self, "_upper_side"))
	var bottom: Dictionary = _surface_state(funcref(self, "_underside"))
	assert_gt(top.charred, 0, "The lit face is burned.")
	assert_gt(bottom.heated, 0, "Heat conducts through the plate to the underside.")
	assert_eq(bottom.charred, 0, "The beam cannot burn the face it cannot see.")


func test_heat_wraps_round_an_edge_without_charring_the_side():
	_setup_box(Vector3(20, 4, 20))
	scorch.add_hit(Vector3(9.5, 200, 0), Vector3(9.5, 0, 0), 6.0)
	var side: Dictionary = _surface_state(funcref(self, "_right_side"))
	assert_gt(side.heated, 0, "The side face next to the hit heats up.")
	assert_eq(side.charred, 0, "The side face is edge-on to the beam, so it is not burned.")


# --- No one watching ---

func test_a_hull_no_one_can_see_records_hits_and_paints_them_once_seen():
	var camera = Camera.new()
	add_child_autofree(camera)
	camera.current = true
	camera.far = 10000.0
	camera.translation = Vector3(0, 0, 200)
	camera.look_at(Vector3(0, 0, 400), Vector3.UP)  # Looking away from the hull
	assert_false(scorch.is_watched())
	var clock_at_hit: float = scorch._clock
	assert_eq(scorch.add_hit(Vector3(0, 50, 0), Vector3.ZERO, 6.0), 0, "Out of sight: nothing painted now")
	assert_true(scorch.last_hit_deferred, "the shot is only recorded")
	assert_eq(_mark_of_vertices(funcref(self, "_is_top_face")), 0.0)
	scorch._clock += 3.0
	camera.look_at(Vector3.ZERO, Vector3.UP)
	assert_true(scorch.is_watched())
	scorch._replay_pending()
	assert_gt(_mark_of_vertices(funcref(self, "_is_top_face")), 0.0, "In view: painted")
	var stamped := false
	for stored in scorch._meshes[0].arrays[0][Mesh.ARRAY_TEX_UV2]:
		stamped = stamped or (stored.y > 0.0 and is_equal_approx(stored.x, clock_at_hit))
	assert_true(stamped, "at its own hit time, so its heat has cooled as if painted then.")


func test_the_agent_does_not_retry_a_recorded_hit():
	var AgentScript = load("res://src/core/agents/agent.gd")
	var body = AgentScript.new()
	add_child_autofree(body)
	body._hull_scorch = scorch
	var camera = Camera.new()
	add_child_autofree(camera)
	camera.current = true
	camera.far = 10000.0
	camera.translation = Vector3(0, 0, 200)
	camera.look_at(Vector3(0, 0, 400), Vector3.UP)
	var point: Vector3 = body.register_hit(Vector3(0, 50, 0), 6.0)
	assert_eq(scorch._pending_hits.size(), 1, "One shot, recorded once")
	assert_true(point.is_equal_approx(body.get_hull_point_facing(Vector3(0, 50, 0))), "and the hit effect still gets a spot on the hull.")

