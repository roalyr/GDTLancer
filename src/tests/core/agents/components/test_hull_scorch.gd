# Tests for HullScorch: hits kept as scar and heat slots, pushed to the hull's own material copies,
# and the CPU mirror of what the shader shows (char on surfaces facing the shot, heat in 3D).

extends GutTest

const HullScorch = preload("res://src/core/agents/components/hull_scorch.gd")

var ship: Spatial = null
var mesh_instance: MeshInstance = null
var material: ShaderMaterial = null
var scorch: Node = null


func before_each():
	ship = Spatial.new()
	add_child_autofree(ship)
	mesh_instance = MeshInstance.new()
	mesh_instance.mesh = _make_box(Vector3(20, 4, 20))
	material = ShaderMaterial.new()
	material.shader = load("res://assets/art/shaders/solid_dither_no_alpha_no_texture_8x8.gdshader")
	mesh_instance.material_override = material
	ship.add_child(mesh_instance)
	scorch = HullScorch.new()
	ship.add_child(scorch)
	scorch.setup(mesh_instance)


func _make_box(size: Vector3) -> Mesh:
	var cube = CubeMesh.new()
	cube.size = size
	return cube


func _hit(point: Vector3, damage: float) -> void:
	scorch.add_hit(point + Vector3(0, 200, 0), point, damage)


func test_hit_chars_only_surfaces_facing_the_shot():
	assert_true(scorch.add_hit(Vector3(0, 200, 0), Vector3(0, 2, 0), 6.0))
	assert_gt(scorch.get_char_at(Vector3(0, 2, 0), Vector3.UP), 0.4, "Top face, facing the shooter, is charred.")
	assert_eq(scorch.get_char_at(Vector3(0, -2, 0), Vector3.DOWN), 0.0, "Far side stays clean.")


func test_mark_grows_with_damage():
	_hit(Vector3(0, 2, 0), 1.0)
	assert_eq(scorch.get_char_at(Vector3(1.2, 2, 0), Vector3.UP), 0.0, "A weak hit marks a small spot")
	before_each()
	_hit(Vector3(0, 2, 0), 9.0)
	assert_gt(scorch.get_char_at(Vector3(1.2, 2, 0), Vector3.UP), 0.0, "a strong one a wider one (radius ~ sqrt(damage)).")


func test_char_reaches_other_levels_of_detail_but_not_plates_behind():
	scorch.add_hit(Vector3(0, 200, 0), Vector3(0, 3, 0), 6.0)  # The hit surface's level sits 1 m above this one
	assert_gt(scorch.get_char_at(Vector3(0, 2, 0), Vector3.UP), 0.4, "The shot line carries the char to the level shown")
	assert_gt(scorch.get_char_at(Vector3(0, 4, 0), Vector3.UP), 0.4, "whether it sinks in or bulges out,")
	assert_eq(scorch.get_char_at(Vector3(0, -2, 0), Vector3.UP), 0.0, "but not to a plate further down the line.")


func test_repeated_hits_join_one_scar_and_saturate():
	_hit(Vector3(0, 2, 0), 6.0)
	var once: float = scorch.get_char_at(Vector3(0, 2, 0), Vector3.UP)
	_hit(Vector3(0.3, 2, 0), 6.0)
	assert_eq(scorch.get_scar_count(), 1, "A hit close by from the same side joins the scar")
	assert_gt(scorch.get_char_at(Vector3(0, 2, 0), Vector3.UP), once, "and deepens it.")
	for _i in range(60):
		_hit(Vector3(0, 2, 0), 6.0)
	var deepest: float = scorch.get_char_at(Vector3(0, 2, 0), Vector3.UP)
	assert_true(deepest <= 1.0, "Marks saturate at fully charred.")
	assert_gt(deepest, 0.95)
	assert_eq(scorch.get_scar_count(), 1)


func test_hits_from_another_side_take_their_own_scar():
	_hit(Vector3(0, 2, 0), 6.0)
	scorch.add_hit(Vector3(200, 1, 0), Vector3(10, 1, 0), 6.0)
	assert_eq(scorch.get_scar_count(), 2)


func test_beyond_the_slots_the_weakest_scar_turns_into_wear():
	var spots: Array = [Vector2(-8, -8), Vector2(-8, 0), Vector2(-8, 8), Vector2(0, -8), Vector2(0, 0), Vector2(0, 8), Vector2(8, -8)]
	for spot in spots:
		_hit(Vector3(spot.x, 2, spot.y), 6.0)
	assert_eq(scorch.get_scar_count(), Constants.SCORCH_MAX_SCARS, "Slots are bounded")
	assert_gt(scorch.get_wear(), 0.0, "and the scar that gave way still counts as wear")
	assert_true(scorch.get_wear() <= Constants.SCORCH_MAX_WEAR)


func test_a_clean_hull_keeps_the_shared_material():
	assert_eq(mesh_instance.material_override, material, "Never hit: nothing to draw, nothing copied.")


func test_first_hit_gives_the_hull_its_own_material_copy():
	_hit(Vector3(0, 2, 0), 6.0)
	var copy: ShaderMaterial = mesh_instance.material_override
	assert_ne(copy, material, "The shared material is never edited.")
	assert_eq(copy.get_shader_param("damage_active"), 1.0)
	var shared_active = material.get_shader_param("damage_active")
	assert_true(shared_active == null or shared_active == 0.0)
	var scar: Plane = copy.get_shader_param("damage_scar_0")
	assert_almost_eq(scar.normal, Vector3(0, 2, 0), Vector3.ONE * 0.001, "The scar's point, in the mesh's space")
	assert_almost_eq(scar.d, Constants.SCORCH_RADIUS_PER_SQRT_DAMAGE * sqrt(6.0), 0.001, "and its radius.")
	scorch._process(1.0)
	assert_eq(copy.get_shader_param("damage_time"), 1.0, "The hull's clock drives its own copy while hot.")


func test_meshes_without_a_marking_shader_are_left_alone():
	var plain = MeshInstance.new()
	plain.mesh = CubeMesh.new()
	ship.add_child(plain)
	scorch.setup(plain)
	assert_false(scorch.is_paintable())
	assert_false(scorch.add_hit(Vector3(0, 200, 0), Vector3.ZERO, 6.0))


func test_meshes_placed_apart_get_slots_in_their_own_space():
	var other = MeshInstance.new()
	other.mesh = _make_box(Vector3(4, 4, 4))
	other.material_override = material
	other.translation = Vector3(30, 0, 0)
	ship.add_child(other)
	scorch.setup(ship)
	scorch.add_hit(Vector3(30, 200, 0), Vector3(30, 2, 0), 6.0)
	var scar: Plane = other.material_override.get_shader_param("damage_scar_0")
	assert_almost_eq(scar.normal, Vector3(0, 2, 0), Vector3.ONE * 0.001, "The hit, as seen from the moved mesh")
	assert_ne(other.material_override, mesh_instance.material_override, "with its own copy.")


func test_hit_heats_the_spot_and_it_cools_over_time():
	_hit(Vector3(0, 2, 0), 6.0)
	var hottest: float = scorch.get_heat_at(Vector3(0, 2, 0))
	assert_almost_eq(hottest, Constants.SCORCH_HEAT_PER_DAMAGE * 6.0, 0.001, "Heat at the centre is proportional to damage.")
	scorch._process(Constants.SCORCH_COOL_TIME)
	assert_almost_eq(scorch.get_heat_at(Vector3(0, 2, 0)), hottest * exp(-1.0), 0.01, "One cool time later the heat is down to ~37%.")


func test_reheating_adds_to_remaining_heat_up_to_cap():
	for _i in range(20):
		_hit(Vector3(0, 2, 0), 6.0)
	assert_almost_eq(scorch.get_heat_at(Vector3(0, 2, 0)), Constants.SCORCH_MAX_HEAT, 0.001)


func test_stronger_beam_heats_a_wider_area():
	_hit(Vector3(0, 2, 0), 3.0)
	assert_eq(scorch.get_heat_at(Vector3(2.5, 2, 0)), 0.0, "A weak beam's heat stays close")
	before_each()
	_hit(Vector3(0, 2, 0), 12.0)
	assert_gt(scorch.get_heat_at(Vector3(2.5, 2, 0)), 0.0, "a strong one spreads further.")


func test_weak_hit_stays_below_the_glow_threshold():
	_hit(Vector3(0, 2, 0), 1.0)
	var weak: float = scorch.get_heat_at(Vector3(0, 2, 0))
	assert_gt(weak, 0.0, "It still warms the surface")
	assert_lt(weak, Constants.SCORCH_GLOW_THRESHOLD, "but not enough to glow.")
	before_each()
	_hit(Vector3(0, 2, 0), 12.0)
	assert_gt(scorch.get_heat_at(Vector3(0, 2, 0)), Constants.SCORCH_GLOW_THRESHOLD, "A powerful beam glows at once.")


func test_a_cold_hull_stops_its_clock():
	_hit(Vector3(0, 2, 0), 6.0)
	assert_true(scorch.is_processing())
	for _i in range(10):
		scorch._process(Constants.SCORCH_COOL_TIME)
	assert_false(scorch.is_processing(), "Nothing hot: no more per-frame updates")
	assert_eq(scorch.get_heat_at(Vector3(0, 2, 0)), 0.0)
	assert_gt(scorch.get_char_at(Vector3(0, 2, 0), Vector3.UP), 0.0, "and the char stays.")


func test_thin_plate_heats_through_but_chars_only_the_lit_side():
	mesh_instance.mesh = _make_box(Vector3(20, 0.3, 20))
	scorch.setup(mesh_instance)
	_hit(Vector3(0, 0.15, 0), 6.0)
	assert_gt(scorch.get_char_at(Vector3(0, 0.15, 0), Vector3.UP), 0.0, "The lit face is burned.")
	assert_gt(scorch.get_heat_at(Vector3(0, -0.15, 0)), 0.0, "Heat conducts through the plate to the underside.")
	assert_eq(scorch.get_char_at(Vector3(0, -0.15, 0), Vector3.DOWN), 0.0, "The beam cannot burn the face it cannot see.")


func test_heat_wraps_round_an_edge_without_charring_the_side():
	_hit(Vector3(9.5, 2, 0), 6.0)
	assert_gt(scorch.get_heat_at(Vector3(10, 1.5, 0)), 0.0, "The side face next to the hit heats up.")
	assert_eq(scorch.get_char_at(Vector3(10, 1.5, 0), Vector3.RIGHT), 0.0, "The side face is edge-on to the beam, so it is not burned.")


func test_marks_export_and_import_onto_a_fresh_hull():
	_hit(Vector3(0, 2, 0), 6.0)
	scorch.add_hit(Vector3(200, 1, 0), Vector3(10, 1, 0), 6.0)
	var marks: Dictionary = scorch.export_marks()
	assert_eq(marks.scars.size(), 2)
	var level: float = scorch.get_mark_level()
	var charred: float = scorch.get_char_at(Vector3(0, 2, 0), Vector3.UP)
	before_each()
	assert_eq(scorch.get_mark_level(), 0.0)
	scorch.import_marks(marks)
	assert_almost_eq(scorch.get_mark_level(), level, 0.0001, "A respawned hull shows the same marks")
	assert_almost_eq(scorch.get_char_at(Vector3(0, 2, 0), Vector3.UP), charred, 0.0001, "in the same places")
	assert_ne(mesh_instance.material_override, material, "on its own material copy")
	assert_eq(scorch.get_heat_at(Vector3(0, 2, 0)), 0.0, "and cooled.")
	scorch.clear_marks()
	assert_eq(scorch.get_mark_level(), 0.0, "Repair restores a clean hull")
	assert_eq(mesh_instance.material_override, material, "and the shared material.")


func test_a_clean_hull_exports_nothing():
	assert_true(scorch.export_marks().empty())


func test_old_vertex_marks_are_ignored():
	scorch.import_marks({"0:0": PoolRealArray([0.5, 0.5])})
	assert_eq(scorch.get_mark_level(), 0.0)
	assert_eq(mesh_instance.material_override, material)


func test_the_agent_marks_where_the_hull_faces_the_shooter_when_no_ray_lands():
	var AgentScript = load("res://src/core/agents/agent.gd")
	var body = AgentScript.new()
	add_child_autofree(body)
	body._hull_scorch = scorch
	var point: Vector3 = body.register_hit(Vector3(0, 50, 0), 6.0)
	assert_true(point.is_equal_approx(body.get_hull_point_facing(Vector3(0, 50, 0))), "No collision shape: the facing hull point")
	assert_eq(scorch.get_scar_count(), 1, "still marked there.")
