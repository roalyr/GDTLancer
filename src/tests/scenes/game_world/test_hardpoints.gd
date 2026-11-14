# Tests for nozzles and hardpoints on ship models (ShipModel, EngineExhaustSet): every placeholder
# hull has a nozzle facing each way; the nozzles burn by the way the thrust pushes; fitted parts that
# are not internal show at the hardpoints, internal ones nowhere.

extends GutTest

const ShipModel = preload("res://src/scenes/game_world/models/ship_model.gd")
const ModelCheck = preload("res://src/scenes/game_world/models/model_check.gd")


# Stands in for an Agent: what EngineExhaustSet reads.
class FakeShip:
	extends Spatial
	var thrust := Vector3.ZERO
	var linear_velocity := Vector3.ZERO
	var is_wreck := false

	func get_engine_activity() -> float:
		return thrust.length()

	func get_engine_thrust() -> Vector3:
		return thrust

	func get_top_speed() -> float:
		return 100.0


func _hull(form: String) -> Spatial:
	var hull: Spatial = load("res://scenes/prefabs/ships/placeholders/%s.tscn" % form).instance()
	autofree(hull)
	return hull


func _exhausts(hull: Spatial) -> Array:
	var out: Array = []
	for exhaust in hull.get_node("Engines").get_children():
		out.append(exhaust.transform)
	return out


func test_every_placeholder_has_a_nozzle_facing_each_way():
	for family in Constants.HULL_FORMS:
		for weight in Constants.HULL_FORM_GIRTH:
			assert_eq(ModelCheck.nozzle_problems(_exhausts(_hull("%s_%s" % [family, weight]))), [], "%s %s" % [family, weight])


func test_every_placeholder_has_hardpoints_for_eight_tools():
	for family in Constants.HULL_FORMS:
		var points: Dictionary = ShipModel.hardpoints(_hull(family + "_superheavy"))
		assert_gt(points.tools.size(), 7, family + ": the most tool slots a hull has")
		assert_gt(points.modules.size(), 1, family)


func test_nozzles_burn_the_way_the_thrust_pushes():
	var ship := FakeShip.new()
	add_child_autofree(ship)
	var hull: Spatial = load("res://scenes/prefabs/ships/placeholders/fighter_medium.tscn").instance()
	ship.add_child(hull)
	var engines: Node = hull.get_node("Engines")
	ship.thrust = Vector3.FORWARD
	engines._process(0.0)
	for group in engines.get_groups():
		var burning: bool = group.push.dot(Vector3.FORWARD) > 0.99
		assert_almost_eq(group.thrust, 1.0 if burning else 0.0, 0.001, "Flying ahead burns only the rear nozzles (push %s)" % group.push)
	ship.thrust = Vector3.RIGHT * 0.5
	engines._process(0.0)
	for group in engines.get_groups():
		if group.push.dot(Vector3.RIGHT) > 0.99:
			assert_almost_eq(group.thrust, 0.5, 0.001, "Sliding right burns the left nozzles")
			for exhaust in group.exhausts:
				assert_true(exhaust.get_node("PlumeShapes").visible, "their plumes out")
		else:
			assert_almost_eq(group.thrust, 0.0, 0.001)
	assert_eq(engines.get_groups().size(), 6, "One group a way")
	ship.is_wreck = true
	engines._process(0.0)
	for group in engines.get_groups():
		assert_lt(group.thrust, 0.0, "A wreck's are dead")


func test_outside_parts_take_hardpoints_and_internal_ones_none():
	var hull: Spatial = _hull("fighter_medium")
	var fit := {"tools": ["preset_laser_medium", "", "preset_cannon_medium"], "modules": ["preset_plating_medium", "preset_sensor_medium"]}
	assert_true(load("res://database/presets/parts/preset_plating_medium.tres").internal, "Plating sits inside")
	assert_false(load("res://database/presets/parts/preset_sensor_medium.tres").internal, "a sensor outside")
	assert_eq(ShipModel.mount_parts(hull, fit), 0, "Every outside part has a hardpoint")
	var mounts: Node = hull.get_node(ShipModel.MOUNTS)
	assert_eq(mounts.get_child_count(), 3, "Laser, cannon and sensor; no plating")
	var points: Dictionary = ShipModel.hardpoints(hull)
	assert_eq(mounts.get_child(0).transform.origin, points.tools[0].origin, "The laser at the first weapon hardpoint")
	assert_eq(mounts.get_child(1).transform.origin, points.tools[1].origin, "the cannon at the next free one, the empty slot taking none")
	assert_eq(mounts.get_child(2).transform.origin, points.modules[0].origin, "the sensor at the first module hardpoint")
	var length: float = load("res://src/scenes/game_world/models/model_looks.gd").bounds(hull).size.z
	assert_almost_eq(length, Constants.SHIP_MODEL_LENGTH, Constants.SHIP_MODEL_LENGTH * Constants.SHIP_MODEL_LENGTH_TOLERANCE, "Mounted parts are not the hull's length")


func test_parts_past_the_hardpoints_do_not_show():
	var hull: Spatial = _hull("scavenger_light")
	var tools: Array = []
	for i in range(ShipModel.hardpoints(hull).tools.size() + 2):
		tools.append("preset_laser_light")
	assert_eq(ShipModel.mount_parts(hull, {"tools": tools, "modules": []}), 2, "Two with nowhere to go")
	assert_eq(ShipModel.mount_parts(hull, {"tools": [], "modules": ["preset_power_cell_light"]}), 0, "Refit: rebuilt")
	assert_null(hull.get_node_or_null(ShipModel.MOUNTS), "Only internal parts: nothing shows")
