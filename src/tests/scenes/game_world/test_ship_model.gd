# Tests for the model contract (ShipModel, StationModel, ModelLooks, ModelCheck) on a model made in
# Blender the way CONTENT.md says (src/tests/fixtures/models/test_hull: nose to +Y in Blender,
# materials "Paint", "Hull Dark Metal" and "Glow", two empties named Engine).

extends GutTest

const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")
const ModelCheck = preload("res://src/scenes/game_world/models/model_check.gd")
const CollisionHull = preload("res://src/core/agents/components/collision_hull.gd")
const TEST_HULL_SCENE = "res://src/tests/fixtures/models/test_hull/test_hull.tscn"


func _hull() -> Spatial:
	var hull: Spatial = load(TEST_HULL_SCENE).instance()
	autofree(hull)
	return hull


func _surface_by_tag(root: Node, tag: String) -> Array:
	for node in ModelLooks._mesh_instances(root):
		for surface in range(node.mesh.get_surface_count()):
			if ModelLooks.tag_of(node.mesh.surface_get_material(surface)) == tag:
				return [node, surface]
	return []


func test_a_blender_model_passes_the_check():
	assert_eq(ModelCheck.ship_problems(TEST_HULL_SCENE), [])


func test_it_comes_in_nose_forward_at_its_length():
	var box: AABB = ModelLooks.bounds(_hull())
	assert_almost_eq(box.size.z, Constants.SHIP_MODEL_LENGTH, 0.1, "17 m nose to tail")
	assert_lt(box.position.z, -8.0, "The nose (+Y in Blender) faces -Z")
	assert_gt(box.size.y, 1.0, "and its top +Y.")


func test_engine_empties_get_exhausts_aft():
	var engines: Node = _hull().get_node("Engines")
	assert_not_null(engines, "Exhausts as it instances")
	assert_eq(engines.get_child_count(), 2, "One per Engine empty")
	for exhaust in engines.get_children():
		assert_gt(exhaust.transform.origin.z, 7.0, "at the stern")
		assert_almost_eq(exhaust.transform.basis.get_scale().x, 0.8, 0.01, "sized by the empty's scale")


func test_materials_come_from_the_library_by_name():
	var hull: Spatial = _hull()
	var metal: Array = _surface_by_tag(hull, "hull_dark_metal")
	assert_false(metal.empty(), "\"Hull Dark Metal\" reads as hull_dark_metal")
	assert_eq(metal[0].get_surface_material(metal[1]), load(ModelLooks.LIBRARY_DIR + "mat_hull_dark_metal.tres"))
	var glow: Array = _surface_by_tag(hull, "glow")
	assert_eq(glow[0].get_surface_material(glow[1]), load(ModelLooks.LIBRARY_DIR + "mat_hull_glow.tres"), "an alias")
	assert_eq(ModelLooks.unknown_tags(hull), [])


func test_paint_reaches_only_the_paint_surfaces():
	var hull: Spatial = _hull()
	var paint := SpatialMaterial.new()
	hull.paint(paint)
	var painted: Array = _surface_by_tag(hull, "paint")
	assert_eq(painted[0].get_surface_material(painted[1]), paint)
	var metal: Array = _surface_by_tag(hull, "hull_dark_metal")
	assert_ne(metal[0].get_surface_material(metal[1]), paint)
	assert_true(ModelLooks.has_paint(hull))


func test_an_unknown_material_is_a_problem():
	var hull: Spatial = _hull()
	var stray := SpatialMaterial.new()
	stray.resource_name = "Material.003"
	var paint: Array = _surface_by_tag(hull, "paint")
	paint[0].mesh = paint[0].mesh.duplicate()
	paint[0].mesh.surface_set_material(paint[1], stray)
	assert_eq(ModelLooks.unknown_tags(hull), ["material"], "Blender's default name, suffix dropped")


func test_its_model_gets_a_hit_surface_wherever_it_lives():
	var body := StaticBody.new()
	add_child_autofree(body)
	var hull: Spatial = _hull()
	body.add_child(hull)
	assert_not_null(CollisionHull.add_hit_surface(body, hull), "Not only models under assets/models/ships/")


func test_a_station_fits_itself_to_its_model():
	var station: StaticBody = load("res://scenes/prefabs/station/faction_station.tscn").instance()
	station.faction = "verdant"
	station.get_node("Model").add_child(load("res://scenes/prefabs/station/placeholders/refinery.tscn").instance())
	add_child_autofree(station)
	var extent: Array = ModelLooks.extent(station.get_node("Model"))
	assert_almost_eq(station.obstacle_radius, extent[0], 0.01, "Kept clear of its far corner")
	assert_gt(station.undock_offset.y, extent[1], "ships undock above it")
	assert_true(station.get_node("CollisionShape").shape is ConvexPolygonShape, "and it collides by its hull.")
	var paint: Material = load(TemplateDatabase.factions.verdant.station_material)
	var painted := 0
	for node in ModelLooks._mesh_instances(station.get_node("Model")):
		if node.name.begins_with(ModelLooks.PAINT_PREFIX):
			assert_eq(node.material_override, paint)
			painted += 1
	assert_gt(painted, 0, "In its owner's paint")
