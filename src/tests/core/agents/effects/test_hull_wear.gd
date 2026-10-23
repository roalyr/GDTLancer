# Tests for HullWear: soot on a ship's paint follows the hull lost, on that ship only.

extends GutTest

const HullWear = preload("res://src/core/agents/effects/hull_wear.gd")
const PHOENIX = "res://scenes/prefabs/ships/phoenix_light_verdant.tscn"


func _ship() -> Spatial:
	var ship: Spatial = load(PHOENIX).instance()
	add_child_autofree(ship)
	return ship


func _wearing_materials(root: Node) -> Array:
	var found: Array = []
	var stack: Array = [root]
	while not stack.empty():
		var node = stack.pop_back()
		stack += node.get_children()
		if node is MeshInstance:
			for surface in range(node.get_surface_material_count()):
				var material = node.get_surface_material(surface)
				if HullWear._wears(material):
					found.append(material)
	return found


func test_the_hull_materials_take_damage():
	var shared: Array = _wearing_materials(_ship())
	assert_gt(shared.size(), 0, "The Phoenix's hull uses the wear shader")
	for material in shared:
		assert_not_null(material.get_shader_param("damage_texture"), "with a soot texture")
		assert_not_null(material.get_shader_param("damage_noise"), "and a noise to spread it.")


func test_an_undamaged_ship_keeps_the_shared_materials():
	var ship := _ship()
	var before: Array = _wearing_materials(ship)
	var wear = HullWear.new(ship)
	wear.set_damage(0.0)
	assert_eq(wear.get_materials().size(), 0)
	assert_eq(_wearing_materials(ship), before)


func test_damage_shows_on_that_ship_only():
	var ship := _ship()
	var other := _ship()
	var shared: Array = _wearing_materials(other)
	var wear = HullWear.new(ship)
	wear.set_damage(0.5)
	assert_gt(wear.get_materials().size(), 0, "A damaged ship gets its own materials")
	for material in _wearing_materials(ship):
		assert_false(material in shared, "for every surface")
		assert_almost_eq(material.get_shader_param("damage"), 0.5, 0.0001, "showing its damage,")
	for material in shared:
		assert_almost_eq(float(material.get_shader_param("damage")), 0.0, 0.0001, "while other ships stay clean.")
	wear.set_damage(0.0)
	for material in wear.get_materials():
		assert_almost_eq(material.get_shader_param("damage"), 0.0, 0.0001, "Repaired, it is clean again.")
