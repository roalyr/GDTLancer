# Content checks (CONTENT.md): every faction, sector layout, haven and archetype file is complete and
# points at things that exist, so a content edit that breaks one fails here rather than in play.

extends GutTest


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
		for key in ["hull_material", "station_material", "ship_scene"]:
			assert_true(_exists(faction[key]), "%s: %s %s exists" % [id, key, faction[key]])
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
			if haven.has("form"):
				assert_true(Constants.STATION_FORMS.has(haven.form), "%s: its form %s exists" % [haven.id, haven.form])
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
