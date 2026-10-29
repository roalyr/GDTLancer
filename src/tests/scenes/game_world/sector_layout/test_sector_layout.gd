# Tests for SectorLayout: Elace's havens, beacons and rock fields are built from Constants
# SECTOR_LAYOUTS, the same every time, rocks clear of the stations; who docks where.

extends GutTest

const LayoutScript = preload("res://src/scenes/game_world/sector_layout/sector_layout.gd")


func _layout() -> Node:
	var sector := Spatial.new()
	add_child_autofree(sector)
	var home := Spatial.new()
	home.name = "ElaceHomeStation"  # The scene's own station, used as it is
	sector.add_child(home)
	var layout = LayoutScript.new()
	sector.add_child(layout)
	return layout


func _rocks(layout: Node, field: String) -> Array:
	var rocks: Array = []
	for child in layout.get_children():
		if child.name.begins_with("Rock_%s_" % field.replace(" ", "_")):
			rocks.append(child)
	return rocks


func test_every_haven_and_beacon_is_built():
	var layout = _layout()
	var spec: Dictionary = Constants.SECTOR_LAYOUTS.sector_elace
	assert_eq(layout.havens.size(), spec.havens.size(), "Every haven")
	assert_eq(layout.get_haven("station_elace_home").station.name, "ElaceHomeStation", "The scene's station is the free port")
	assert_eq_deep(layout.get_haven("verdant_haven").factions, {"verdant": 5})
	assert_eq(layout.network.beacons.size(), spec.havens.size() + spec.beacons.size(), "A beacon per haven and per listed beacon")
	for beacon in layout.network.beacons:
		assert_true(beacon.is_in_group("beacon"))


func test_fields_are_the_same_every_time_and_clear_of_stations():
	var first = _layout()
	var second = _layout()
	for spec in Constants.SECTOR_LAYOUTS.sector_elace.beacons:
		if spec.kind != "field":
			continue
		var a: Array = _rocks(first, spec.name)
		var b: Array = _rocks(second, spec.name)
		assert_true(a.size() >= floor(spec.rocks * 0.8) and a.size() <= spec.rocks, "%s: about %d rocks (%d)" % [spec.name, spec.rocks, a.size()])
		assert_eq(a.size(), b.size())
		for i in range(min(a.size(), b.size())):
			assert_eq(a[i].transform, b[i].transform, "Rock %d where it was" % i)
		for rock in a:
			assert_true(rock.is_in_group("asteroid"), "A rock")
			for haven in first.havens:
				assert_gt(rock.global_transform.origin.distance_to(haven.station.global_transform.origin), Constants.FIELD_ROCK_CLEARANCE, "Clear of %s" % haven.id)


func test_who_is_welcome_where():
	var layout = _layout()
	var ids := []
	for station in layout.refuges_for("verdant"):
		ids.append(station.name)
	assert_true("verdant_haven" in ids and "verdant_post" in ids, "Its own")
	assert_true("ElaceHomeStation" in ids and "elace_refinery" in ids, "and the neutral ones")
	assert_false("violet_haven" in ids, "not the enemy's")
	var raider_ids := []
	for station in layout.refuges_for("raiders"):
		raider_ids.append(station.name)
	assert_eq(raider_ids, ["raider_den"], "Raiders have only their den")


func test_only_fields_and_lone_landmarks_show_to_the_player():
	var layout = _layout()
	for beacon in layout.network.beacons:
		var lone: bool = beacon.beacon_name.find("Pass") >= 0
		assert_eq(beacon.player_visible, beacon.kind == "field" or lone, "%s %s" % [beacon.kind, beacon.beacon_name])
	var projector = load("res://src/core/ui/main_hud/hud_target_projector.gd").new(null)
	for beacon in layout.network.beacons:
		assert_eq(projector.is_world_projectable_target(beacon), beacon.player_visible, "Bracketed only if shown: " + beacon.beacon_name)
		if beacon.player_visible:
			assert_true(projector.is_stellar_target(beacon), "with the celestials")
