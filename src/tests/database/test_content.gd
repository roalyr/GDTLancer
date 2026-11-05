# Content checks (CONTENT.md): every faction, sector layout, haven and archetype file is complete and
# points at things that exist, so a content edit that breaks one fails here rather than in play.

extends GutTest

const ModelCheck = preload("res://src/scenes/game_world/models/model_check.gd")


func _exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


func test_factions_are_complete():
	var factions: Dictionary = TemplateDatabase.factions
	assert_gt(factions.size(), 0, "Factions load from %s" % Constants.FACTIONS_DIR)
	for id in factions:
		var faction: Dictionary = factions[id]
		assert_ne(faction.name, "", "%s: a name" % id)
		for enemy in faction.enemies:
			assert_true(factions.has(enemy), "%s: its enemy %s is a faction" % [id, enemy])
		for key in ["hull_material", "station_material"]:
			assert_true(_exists(faction[key]), "%s: %s %s exists" % [id, key, faction[key]])
		if faction.ship_scene != "":
			assert_true(_exists(faction.ship_scene), "%s: its own hull %s exists" % [id, faction.ship_scene])
		for name in faction.roster:
			assert_true(_exists(Constants.ARCHETYPES_DIR.plus_file("agent_archetype_%s.tres" % name)), "%s: roster archetype %s exists" % [id, name])


func test_sector_layouts_and_havens_are_complete():
	var layouts: Dictionary = TemplateDatabase.sector_layouts
	assert_gt(layouts.size(), 0, "Layouts load from %s" % Constants.SECTORS_SCENES_DIR)
	var seen := {}
	for sector_id in layouts:
		var scene_path: String = Constants.SECTORS_SCENES_DIR.plus_file(sector_id).plus_file(sector_id + ".tscn")
		var file := File.new()
		assert_eq(file.open(scene_path, File.READ), OK, "%s: its sector scene" % sector_id)
		if file.is_open():
			assert_string_contains(file.get_as_text(), sector_id + Constants.SECTOR_LAYOUT_SUFFIX, false)  # Its layout is placed in it
			file.close()
		for haven in layouts[sector_id].havens:
			assert_false(seen.has(haven.id), "%s: one haven by that id" % haven.id)
			seen[haven.id] = true
			assert_ne(haven.name, "", "%s: a name" % haven.id)
			assert_true(haven.faction == "" or TemplateDatabase.factions.has(haven.faction), "%s: its owner %s is a faction" % [haven.id, haven.faction])
			for faction in haven.ships:
				assert_true(TemplateDatabase.factions.has(faction), "%s: its ships' faction %s is a faction" % [haven.id, faction])
				assert_false(TemplateDatabase.factions[faction].roster.empty() if TemplateDatabase.factions.has(faction) else true, "%s: %s has a roster to fly" % [haven.id, faction])
			if haven.has("model"):
				assert_true(_exists(haven.model), "%s: its model %s exists" % [haven.id, haven.model])
		for beacon in layouts[sector_id].beacons:
			assert_has(["patrol", "field", "landmark"], beacon.kind, "%s: a known beacon kind" % beacon.name)
			if beacon.kind == "patrol":
				assert_true(TemplateDatabase.factions.has(beacon.get("owner", "")), "%s: its owner is a faction" % beacon.name)


func test_archetypes_are_complete():
	var dir := Directory.new()
	assert_eq(dir.open(Constants.ARCHETYPES_DIR), OK)
	dir.list_dir_begin(true, true)
	var count := 0
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("agent_archetype_"):
			count += 1
			var agent = load(Constants.ARCHETYPES_DIR.plus_file(name))
			var archetype: String = name.trim_prefix("agent_archetype_").trim_suffix(".tres")
			assert_false(agent.genome.empty(), "%s: its genome" % archetype)
			var ship_path: String = Constants.ARCHETYPES_DIR.plus_file(agent.ship_template_id + ".tres")
			assert_true(_exists(ship_path), "%s: its ship %s" % [archetype, ship_path])
			if _exists(ship_path):
				var ship = load(ship_path)
				assert_not_null(ship.ship_scene, "%s: its hull scene" % archetype)
				for part in ship.equipped_tools + ship.equipped_modules:
					assert_true(_exists(Constants.ARCHETYPES_DIR.plus_file(part + ".tres")) or TemplateDatabase.get_template(part) != null or part == Constants.HARPOON_TEMPLATE_ID, "%s: its part %s" % [archetype, part])
			assert_true(_exists(Constants.PLACEHOLDER_HULLS_DIR.plus_file(archetype + ".tscn")), "%s: its placeholder hull" % archetype)
		name = dir.get_next()
	assert_eq(count, 15, "Fifteen archetypes")


# Every ship and station model the game flies or places keeps the model rules (ModelCheck).
func test_every_model_in_use_keeps_the_rules():
	var ships := {}
	for path in _templates_in(Constants.ARCHETYPES_DIR) + _templates_in("res://database/registry/assets/ships"):
		var ship = load(path)
		if "ship_scene" in ship and ship.ship_scene != null:
			ships[ship.ship_scene.resource_path] = true
	for id in TemplateDatabase.factions:
		if TemplateDatabase.factions[id].ship_scene != "":
			ships[TemplateDatabase.factions[id].ship_scene] = true
	ships[Constants.SHIP_DEFAULT_SCENE] = true
	for scene_path in ships:
		assert_eq(ModelCheck.ship_problems(scene_path), [], "Ship model " + scene_path)
	var stations := {Constants.STATION_DEFAULT_MODEL: true}
	for sector_id in TemplateDatabase.sector_layouts:
		for haven in TemplateDatabase.sector_layouts[sector_id].havens:
			if haven.has("model"):
				stations[haven.model] = true
	for scene_path in stations:
		assert_eq(ModelCheck.station_problems(scene_path), [], "Station model " + scene_path)
	assert_gt(ships.size(), 15, "Archetypes' hulls and the xenohive's")


func _templates_in(dir_path: String) -> Array:
	var out: Array = []
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		return out
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".tres") and not name.begins_with("agent_"):
			out.append(dir_path.plus_file(name))
		name = dir.get_next()
	return out
