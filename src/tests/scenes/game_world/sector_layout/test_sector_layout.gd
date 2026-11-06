# Tests for SectorLayout: Elace's havens, beacons and rock fields are built from its
# layout scene (its markers), the same every time, rocks clear of the stations; who docks where.

extends GutTest

const LayoutScript = preload("res://src/scenes/game_world/sector_layout/sector_layout.gd")
const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")


func _layout() -> Node:
	var sector := Spatial.new()
	add_child_autofree(sector)
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
	var spec: Dictionary = TemplateDatabase.sector_layouts.sector_elace
	assert_eq(layout.havens.size(), spec.havens.size(), "Every haven")
	var home = layout.get_haven("station_elace_home").station
	assert_eq(home.get_parent(), layout, "The free port's station is its haven's, built by the layout like every other")
	assert_true(home.has_beacon, "and seen from anywhere: the way home is always on the sensors")
	assert_false(layout.get_haven("verdant_haven").station.has_beacon, "Other havens by their size")
	var marker: Dictionary = {}
	for haven in spec.havens:
		if haven.id == "station_elace_home":
			marker = haven
	assert_almost_eq(layout.get_haven("station_elace_home").station.global_transform.origin, layout.global_transform.xform(marker.at),
		Vector3.ONE * 0.01, "and stands where its marker is")
	assert_eq_deep(layout.get_haven("verdant_haven").factions, {"verdant": 5})
	var entries := 0
	for beacon in spec.beacons:
		if beacon.kind == "entry":
			entries += 1
	assert_eq(entries, 1, "One entry")
	assert_eq(layout.network.beacons.size(), spec.havens.size() + spec.beacons.size() - entries, "A beacon per haven and per listed beacon but the entry")
	for beacon in layout.network.beacons:
		assert_true(beacon.is_in_group("beacon"))


func test_fields_are_the_same_every_time_and_clear_of_stations():
	var first = _layout()
	var second = _layout()
	for spec in TemplateDatabase.sector_layouts.sector_elace.beacons:
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
	assert_true("station_elace_home" in ids and "elace_refinery" in ids, "and the neutral ones")
	assert_false("violet_haven" in ids, "not the enemy's")
	var raider_ids := []
	for station in layout.refuges_for("raiders"):
		raider_ids.append(station.name)
	assert_eq(raider_ids, ["raider_den"], "Raiders have only their den")


func test_only_fields_lone_landmarks_and_paid_pickets_show_to_the_player():
	var layout = _layout()
	for beacon in layout.network.beacons:
		var lone: bool = beacon.beacon_name.find("Pass") >= 0
		var paid: bool = beacon.kind == "patrol" and TemplateDatabase.factions[beacon.faction].patrol_wages  # Where the player earns patrol wages
		assert_eq(beacon.player_visible, beacon.kind == "field" or lone or paid, "%s %s" % [beacon.kind, beacon.beacon_name])
	var projector = load("res://src/core/ui/main_hud/hud_target_projector.gd").new(null)
	for beacon in layout.network.beacons:
		assert_eq(projector.is_world_projectable_target(beacon), beacon.player_visible, "Bracketed only if shown: " + beacon.beacon_name)
		if beacon.player_visible:
			assert_true(projector.is_stellar_target(beacon), "with the celestials")


func test_havens_wear_their_models_and_fit_to_them():
	var layout = _layout()
	for spec in TemplateDatabase.sector_layouts.sector_elace.havens:
		var station: Node = layout.get_haven(spec.id).station
		var model: Node = station.get_node("Model").get_child(0)
		assert_eq(model.filename, spec.model, "%s wears its model" % spec.id)
		var extent: Array = ModelLooks.extent(station.get_node("Model"))
		assert_almost_eq(station.obstacle_radius, extent[0], 0.01, "%s: kept clear by its size (%.0f m)" % [spec.id, station.obstacle_radius])
		assert_gt(extent[0], 50.0, "%s: a station-sized model" % spec.id)
		assert_gt(station.undock_offset.y, extent[1], "%s: ships undock above it" % spec.id)
		assert_true(station.get_node("CollisionShape").shape is ConvexPolygonShape, "%s: its hull collides" % spec.id)


func test_the_entry_is_where_ships_arrive():
	var layout = _layout()
	var entry: Dictionary = LayoutScript.entry_of(layout.get_parent())
	assert_almost_eq(entry.at, Vector3(-20000, 0, 2000), Vector3.ONE * 0.01, "The entry beacon's place")
	assert_eq(entry.radius, 20000.0, "and its radius: how far out ships arrive")


func test_attached_markers_ride_with_their_bodies():
	var sector := Spatial.new()
	add_child_autofree(sector)
	var assets := Spatial.new()
	assets.name = "SceneAssets"
	sector.add_child(assets)
	var star := Spatial.new()
	star.name = "Star Elace"
	star.transform.origin = Vector3(1000, 0, 0)
	assets.add_child(star)
	var planet := Spatial.new()
	planet.name = "Planet Elace B"
	planet.transform.origin = Vector3(30000, 500, 0)
	assets.add_child(planet)
	var layout = LayoutScript.new()
	assets.add_child(layout)
	var hazard: Node = layout.get_node("Hazard_radiation")
	assert_almost_eq(hazard.global_transform.origin, star.global_transform.origin, Vector3.ONE * 0.01, "The radiation round the star, wherever it is")
	var belt: Node = null
	for beacon in layout.network.beacons:
		if beacon.beacon_name == "Elace B Belt":
			belt = beacon
	assert_almost_eq(belt.global_transform.origin, planet.global_transform.origin, Vector3.ONE * 0.01, "The planet's ring of rocks is where the planet is")


func test_a_turned_haven_marker_turns_its_station():
	var marker = load("res://src/scenes/game_world/sector_layout/markers/haven_marker.gd").new()
	marker.haven_id = "turned"
	assert_false(marker.to_spec(Vector3.ZERO).has("turn"), "Unturned: nothing to say")
	marker.rotation_degrees = Vector3(0, 90, 0)
	var spec: Dictionary = marker.to_spec(Vector3(5, 0, 0))
	marker.free()
	var layout = _layout()
	var built: Dictionary = layout._build_haven(spec)
	assert_almost_eq(built.station.rotation_degrees.y, 90.0, 0.01)
	assert_eq(built.station.transform.origin, Vector3(5, 0, 0), "Still where its marker is")


func test_sector_scenes_place_no_editor_only_meshes():
	for sector in ["sector_elace", "sector_cob", "sector_lywin"]:
		var scene: Node = load("res://scenes/levels/sectors/%s/%s.tscn" % [sector, sector]).instance()
		for child in scene.get_children():
			assert_false(child is MeshInstance, "%s: %s is a mesh at the root (the play area is the layout's play_radius)" % [sector, child.name])
		scene.free()


func test_a_beacon_passes_on_only_what_its_kind_reads():
	var marker = load("res://src/scenes/game_world/sector_layout/markers/beacon_marker.gd").new()
	marker.kind = "field"
	marker.owner_faction = "verdant"
	marker.player_visible = true
	marker.rocks = 5
	var spec: Dictionary = marker.to_spec(Vector3.ZERO)
	assert_false(spec.has("owner"), "A field has no owner")
	assert_false(spec.has("player_visible"), "Fields always show")
	assert_eq(spec.rocks, 5)
	marker.kind = "landmark"
	spec = marker.to_spec(Vector3.ZERO)
	assert_false(spec.has("rocks"))
	assert_true(spec.player_visible)
	marker.free()
