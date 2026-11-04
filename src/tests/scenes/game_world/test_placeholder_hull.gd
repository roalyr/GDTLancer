# Tests for the placeholder hulls (PlaceholderHull, PrimitiveForm): every archetype's scene builds
# a model, engines and a collision shape as it instances; weight classes differ; paint reaches only
# the painted parts.

extends GutTest

const PrimitiveForm = preload("res://src/scenes/game_world/primitive_form.gd")
const ARCHETYPES = "res://database/presets/archetypes/"


func _hull(family: String, weight: String) -> Spatial:
	var hull: Spatial = load("res://scenes/prefabs/ships/placeholders/%s_%s.tscn" % [family, weight]).instance()
	autofree(hull)
	return hull


func test_every_archetype_flies_its_placeholder_hull():
	for family in Constants.HULL_FORMS:
		for weight in Constants.HULL_FORM_GIRTH:
			var ship = load(ARCHETYPES + "preset_ship_archetype_%s_%s.tres" % [family, weight])
			assert_not_null(ship, "%s %s archetype" % [family, weight])
			if ship == null:
				continue
			assert_eq(ship.ship_scene.resource_path, "res://scenes/prefabs/ships/placeholders/%s_%s.tscn" % [family, weight])
			var hull: Spatial = ship.ship_scene.instance()
			autofree(hull)
			assert_gt(hull.get_node("Model/PrimitiveForm").get_child_count(), 4, "%s %s: a model as it instances" % [family, weight])
			assert_gt(hull.get_node("Engines").get_child_count(), 0, "Engines")
			assert_not_null(hull.get_node_or_null("CollisionShape"), "A collision shape for the ship to take")
			var radius: float = PrimitiveForm.extent(hull.get_node("Model/PrimitiveForm"))[0]
			assert_true(radius > 6.0 and radius < 13.0, "About a 17 m hull (%.1f m to its far corner)" % radius)


func test_heavier_hulls_are_wider_and_carry_more():
	for family in Constants.HULL_FORMS:
		var light: Node = _hull(family, "light").get_node("Model/PrimitiveForm")
		var heavy: Node = _hull(family, "heavy").get_node("Model/PrimitiveForm")
		assert_gt(heavy.get_child_count(), light.get_child_count(), "%s: heavy adds parts" % family)


func test_paint_reaches_only_painted_parts():
	var hull: Spatial = _hull("fighter", "medium")
	var material := SpatialMaterial.new()
	hull.paint(material)
	var painted := 0
	for piece in hull.get_node("Model/PrimitiveForm").get_children():
		if piece.name.begins_with(PrimitiveForm.PAINT_PREFIX):
			assert_eq(piece.material_override, material)
			painted += 1
		else:
			assert_ne(piece.material_override, material, "%s keeps its own" % piece.name)
	assert_gt(painted, 0)


func test_mirrored_parts_sit_either_side():
	var form: Spatial = PrimitiveForm.build([{"shape": "box", "size": Vector3(0.1, 0.1, 0.1), "at": Vector3(0.3, 0, 0), "turn": Vector3(0, 20, 0), "mirror": true}], 10.0)
	autofree(form)
	assert_eq(form.get_child_count(), 2)
	assert_almost_eq(form.get_child(0).transform.origin.x, 3.0, 0.001)
	assert_almost_eq(form.get_child(1).transform.origin.x, -3.0, 0.001)
	assert_almost_eq(form.get_child(1).transform.basis.get_euler().y, deg2rad(-20.0), 0.001, "Turned the other way")
