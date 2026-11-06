# Tests for BridgeCommands (tools/devtool/bridge_commands.gd): what the development tool asks of
# Godot. Writes go to copies under user://, never to the project's files.

extends GutTest

const BridgeCommands = preload("res://tools/devtool/bridge_commands.gd")
const FACTION = "res://database/factions/verdant.tres"
const COPY = "user://test_bridge_faction.tres"

var commands = null


func before_each():
	commands = BridgeCommands.new()


func after_each():
	Directory.new().remove(COPY)


func _ok(reply: Dictionary):
	assert_true(reply.ok, str(reply.get("error", "")))
	return reply.get("result")


func test_unknown_commands_are_errors():
	var reply: Dictionary = commands.handle("nope", {})
	assert_false(reply.ok)
	assert_string_contains(reply.error, "nope")


func test_ping():
	assert_string_contains(_ok(commands.handle("ping", {})).godot, "3.6")


func test_schema_lists_fields_with_types_and_comments():
	var schema: Dictionary = _ok(commands.handle("schema", {"path": FACTION}))
	assert_eq(schema["class"], "FactionTemplate")
	var by_name := {}
	for field in schema.fields:
		by_name[field.name] = field
	assert_true(by_name.has("template_id"), "Base script's fields too")
	assert_eq(by_name.color.type, "Color")
	assert_eq(by_name.starting_standing.type, "float")
	assert_string_contains(by_name.color.comment, "HUD", "The comment after the field")
	assert_eq(by_name.hull_material.hint, PROPERTY_HINT_FILE, "File fields say so")
	assert_eq(_ok(commands.handle("schema", {"script": "res://database/definitions/faction_template.gd"})).fields.size(), schema.fields.size(), "By script too")


func test_read_and_write_round_trip():
	assert_eq(ResourceSaver.save(COPY, load(FACTION)), OK)
	var read: Dictionary = _ok(commands.handle("read", {"path": COPY}))
	assert_eq(read.path, COPY)
	assert_eq(read.values.display_name, "Verdant")
	var color: Dictionary = read.values.color
	color.v = [0.1, 0.2, 0.3, 1.0]
	var written: Dictionary = _ok(commands.handle("write", {"path": COPY, "values": {"display_name": "Green", "color": color, "starting_standing": 1, "enemies": ["violet", "raiders"]}}))
	assert_eq(written.problems, [], "No rules for files outside the content folders")
	var again = ResourceLoader.load(COPY, "", true)
	assert_eq(again.display_name, "Green")
	assert_almost_eq(again.color.g, 0.2, 0.001)
	assert_eq(typeof(again.starting_standing), TYPE_REAL, "A JSON 1 lands as the field's float")
	assert_eq(again.enemies, ["violet", "raiders"])
	assert_false(commands.handle("write", {"path": COPY, "values": {"no_such_field": 1}}).ok, "Unknown fields are refused")


func test_create_makes_new_files_only():
	var script := "res://database/definitions/faction_template.gd"
	_ok(commands.handle("create", {"path": COPY, "script": script, "values": {"template_id": "test", "display_name": "Test"}}))
	assert_eq(ResourceLoader.load(COPY, "", true).display_name, "Test")
	assert_false(commands.handle("create", {"path": COPY, "script": script}).ok, "Not over an existing file")


func test_values_survive_encoding():
	for value in [null, true, 3, 2.5, "text", Color(0.1, 0.2, 0.3, 0.4), Vector3(1, 2, 3), [1, "a", Color(1, 0, 0)], {"a": 1, "b": [2]}, {1: "x"}, PoolStringArray(["a", "b"])]:
		var back = BridgeCommands.match_types(BridgeCommands.decode(JSON.parse(BridgeCommands.json(BridgeCommands.encode(value))).result), value)
		assert_eq(var2str(back if not value is PoolStringArray else PoolStringArray(back)), var2str(value), var2str(value))
	var material = load("res://assets/art/materials_generic/mat_hull_glow.tres")
	var encoded: Dictionary = BridgeCommands.encode(material)
	assert_eq(encoded.path, material.resource_path)
	assert_eq(BridgeCommands.decode(encoded), material, "Resources travel by path")


func test_numbers_keep_their_types_through_a_save():
	var like := {"count": 3, "share": 0.5, "list": [1, 2], "floats": [1.0, 2.5]}
	var back = BridgeCommands.match_types({"count": 4.0, "share": 1.0, "list": [5.0, 6.0, 7.0], "floats": [3.0], "new": 2.0}, like)
	assert_eq(typeof(back.count), TYPE_INT)
	assert_eq(typeof(back.share), TYPE_REAL)
	assert_eq(typeof(back.list[2]), TYPE_INT, "A new item like the first")
	assert_eq(typeof(back.floats[0]), TYPE_REAL)


func test_validate_and_models():
	assert_eq(_ok(commands.handle("validate", {"section": "factions"})), [])
	assert_eq(_ok(commands.handle("validate", {"file": FACTION})), [])
	var models: Dictionary = _ok(commands.handle("models", {}))
	assert_true(models.ships.has(Constants.SHIP_DEFAULT_SCENE))
	assert_gt(models.ships[Constants.SHIP_DEFAULT_SCENE].users.size(), 0, "Who flies it")
	assert_eq(models.ships[Constants.SHIP_DEFAULT_SCENE].problems, [])
	assert_true(models.stations.has(Constants.STATION_DEFAULT_MODEL))


# Reading any data file and writing its values back changes nothing in it (against Godot's own save
# of the same file, the text the tool's saves are compared to).
func test_a_read_and_write_back_leaves_every_data_file_as_it_was():
	var paths: Array = []
	for dir_path in ["res://database/factions", "res://database/registry/agents", "res://database/registry/assets/ships",
			"res://database/registry/assets/modules", "res://database/registry/assets/commodities", "res://database/registry/tools",
			"res://database/registry/game_starts", "res://database/registry/locations", "res://database/presets/archetypes", "res://database/sounds"]:
		paths += BridgeCommands.Validator._files_in(dir_path, ".tres")
	assert_gt(paths.size(), 100)
	var baseline := "user://test_bridge_baseline.tres"
	for path in paths:
		ResourceSaver.save(baseline, ResourceLoader.load(path, "", true))
		ResourceSaver.save(COPY, ResourceLoader.load(path, "", true))
		var values: Dictionary = JSON.parse(BridgeCommands.json(_ok(commands.handle("read", {"path": COPY})).values)).result
		_ok(commands.handle("write", {"path": COPY, "values": values}))
		assert_eq(_text(COPY), _text(baseline), path)
	Directory.new().remove(baseline)


func _text(path: String) -> String:
	var file := File.new()
	file.open(path, File.READ)
	var text: String = file.get_as_text()
	file.close()
	return text


# --- Materials ---

func test_materials_show_their_shader_parameters_and_round_trip():
	var library := "res://assets/art/materials_generic/"
	var schema: Dictionary = _ok(commands.handle("schema", {"path": library + "mat_hull_dark_metal.tres"}))
	var names: Array = []
	for field in schema.fields:
		names.append(field.name)
	assert_has(names, "shader")
	assert_has(names, "shader_param/albedo")
	var comments := {}
	for field in schema.fields:
		comments[field.name] = field.comment
	assert_string_contains(comments["shader_param/detail_texture"], "scratches", "The comment after the uniform")
	var copy := "user://test_bridge_material.tres"
	var baseline := "user://test_bridge_material_baseline.tres"
	for path in BridgeCommands.Validator._files_in(library, ".tres"):
		ResourceSaver.save(baseline, ResourceLoader.load(path, "", true))
		ResourceSaver.save(copy, ResourceLoader.load(path, "", true))
		var values: Dictionary = JSON.parse(BridgeCommands.json(_ok(commands.handle("read", {"path": copy})).values)).result
		_ok(commands.handle("write", {"path": copy, "values": values}))
		assert_eq(_text(copy), _text(baseline), path)
	var albedo: Dictionary = _ok(commands.handle("read", {"path": copy})).values["shader_param/albedo"]
	albedo.v = [0.5, 0.25, 0.125, 1.0]
	_ok(commands.handle("write", {"path": copy, "values": {"shader_param/albedo": albedo}}))
	assert_eq(ResourceLoader.load(copy, "", true).get_shader_param("albedo"), Color(0.5, 0.25, 0.125, 1.0))
	Directory.new().remove(copy)
	Directory.new().remove(baseline)


func test_a_new_material_is_a_copy():
	var copy := "user://test_bridge_new_material.tres"
	Directory.new().remove(copy)
	_ok(commands.handle("create", {"path": copy, "copy_from": "res://assets/art/materials_generic/mat_hull_glow.tres"}))
	var made = ResourceLoader.load(copy, "", true)
	assert_true(made is ShaderMaterial)
	assert_eq(made.shader.resource_path, "res://assets/art/shaders/glow.gdshader")
	Directory.new().remove(copy)


# --- Scenes ---

const LAYOUT = "res://scenes/levels/sectors/sector_elace/sector_elace_layout.tscn"
const LAYOUT_COPY = "user://test_bridge_layout.tscn"


func _layout_copy() -> void:
	var dir := Directory.new()
	dir.copy(LAYOUT, LAYOUT_COPY)


func _node(nodes: Array, path: String) -> Dictionary:
	for node in nodes:
		if node.node == path:
			return node
	return {}


func test_scene_nodes_list_markers_with_fields():
	var nodes: Array = _ok(commands.handle("scene_nodes", {"path": LAYOUT}))
	var root: Dictionary = _node(nodes, ".")
	assert_eq(root.values.sector_id, "sector_elace")
	var haven: Dictionary = _node(nodes, "Havens/VerdantHaven")
	assert_eq(haven.values.haven_id, "verdant_haven")
	assert_eq(haven.values.translation.v, [6000.0, 0.0, 25000.0])
	assert_eq(haven.fields[0].name, "translation", "Its place first")
	for node in nodes:
		assert_false(node.type == "ImmediateGeometry", "Rings drawn by the markers are not the scene's")


func test_a_layout_saved_unchanged_stays_as_it_was():
	_layout_copy()
	var before: String = _text(LAYOUT_COPY)
	var nodes: Array = _ok(commands.handle("scene_nodes", {"path": LAYOUT_COPY}))
	for node in nodes:
		var values: Dictionary = JSON.parse(BridgeCommands.json(node.values)).result
		_ok(commands.handle("scene_write", {"path": LAYOUT_COPY, "node": node.node, "values": values}))
	assert_eq(_text(LAYOUT_COPY), before, "Every node written back as it was")
	Directory.new().remove(LAYOUT_COPY)


func test_a_haven_moves_and_changes():
	_layout_copy()
	var before: String = _text(LAYOUT_COPY)
	_ok(commands.handle("scene_write", {"path": LAYOUT_COPY, "node": "Havens/VerdantHaven",
		"values": {"translation": {"$": "Vector3", "v": [7000, 0, 24000]}, "ships": {"verdant": 6}, "prefer_share": 0.5}}))
	var haven: Dictionary = _node(_ok(commands.handle("scene_nodes", {"path": LAYOUT_COPY})), "Havens/VerdantHaven")
	assert_eq(haven.values.translation.v, [7000.0, 0.0, 24000.0])
	assert_eq_deep(haven.values.ships, {"verdant": 6})
	assert_eq(haven.values.prefer_share, 0.5)
	assert_string_contains(_text(LAYOUT_COPY), '"verdant": 6', "Ship counts stay whole numbers")
	var changed := 0
	var old_lines: PoolStringArray = before.split("\n")
	var new_lines: PoolStringArray = _text(LAYOUT_COPY).split("\n")
	assert_eq(new_lines.size(), old_lines.size(), "No lines added or lost")
	for index in range(min(old_lines.size(), new_lines.size())):
		if old_lines[index] != new_lines[index]:
			changed += 1
	assert_eq(changed, 3, "Only its transform, ships and prefer_share lines changed")
	Directory.new().remove(LAYOUT_COPY)


func test_a_haven_takes_another_model_and_gives_it_back():
	_layout_copy()
	var refinery := {"$": "Resource", "path": "res://scenes/prefabs/station/placeholders/refinery.tscn"}
	_ok(commands.handle("scene_write", {"path": LAYOUT_COPY, "node": "Havens/ElaceFreePort", "values": {"model": refinery}}))
	assert_string_contains(_text(LAYOUT_COPY), "model = ExtResource( 8 )", "A scene the file has already")
	var other := {"$": "Resource", "path": "res://scenes/prefabs/station/faction_station.tscn"}
	_ok(commands.handle("scene_write", {"path": LAYOUT_COPY, "node": "Havens/ElaceFreePort", "values": {"model": other}}))
	assert_string_contains(_text(LAYOUT_COPY), '[ext_resource path="res://scenes/prefabs/station/faction_station.tscn" type="PackedScene" id=10]')
	assert_string_contains(_text(LAYOUT_COPY), "load_steps=11", "Counted")
	_ok(commands.handle("scene_write", {"path": LAYOUT_COPY, "node": "Havens/ElaceFreePort", "values": {"model": null}}))
	assert_eq(_text(LAYOUT_COPY), _text(LAYOUT), "Back to none: the line and the unused resource go")
	Directory.new().remove(LAYOUT_COPY)


func test_markers_are_added_and_removed():
	_layout_copy()
	var added: Dictionary = _ok(commands.handle("scene_add", {"path": LAYOUT_COPY, "parent": "Beacons", "name": "TestBeacon",
		"script": "res://src/scenes/game_world/sector_layout/markers/beacon_marker.gd",
		"values": {"translation": {"$": "Vector3", "v": [100, 0, 200]}, "kind": "field", "rocks": 12}}))
	assert_eq(added.node, "Beacons/TestBeacon")
	var beacon: Dictionary = _node(_ok(commands.handle("scene_nodes", {"path": LAYOUT_COPY})), "Beacons/TestBeacon")
	assert_eq(beacon.values.kind, "field")
	assert_eq(beacon.values.rocks, 12)
	var twin: Dictionary = _ok(commands.handle("scene_add", {"path": LAYOUT_COPY, "parent": "Beacons", "name": "TestBeacon",
		"script": "res://src/scenes/game_world/sector_layout/markers/beacon_marker.gd"}))
	assert_ne(twin.node, "Beacons/TestBeacon", "A taken name gets a number")
	_ok(commands.handle("scene_remove", {"path": LAYOUT_COPY, "node": "Beacons/TestBeacon"}))
	_ok(commands.handle("scene_remove", {"path": LAYOUT_COPY, "node": twin.node}))
	assert_eq(_text(LAYOUT_COPY), _text(LAYOUT), "Back as it was")
	assert_false(commands.handle("scene_remove", {"path": LAYOUT_COPY, "node": "."}).ok, "Never the root")
	Directory.new().remove(LAYOUT_COPY)


func test_the_sector_map_has_bodies_and_markers():
	var items: Array = _ok(commands.handle("sector_map", {"sector": "sector_elace"}))
	var kinds := {}
	for item in items:
		kinds[item.kind] = true
	for kind in ["star", "planet", "haven_marker", "beacon_marker", "hazard_marker"]:
		assert_true(kinds.has(kind), kind)


# --- Checks ---

func test_sound_slots_and_script_checks():
	var slots: Array = _ok(commands.handle("sound_slots", {}))
	assert_eq(slots.size(), BridgeCommands.SoundBank.SLOTS.size())
	assert_eq(slots[0].keys().size(), 4)
	assert_true(_ok(commands.handle("check_script", {"source": "extends Node\nconst A = 1\n"})).ok)
	assert_false(_ok(commands.handle("check_script", {"source": "extends Node\nconst A = (\n"})).ok)


# --- Views ---

func test_the_archetypes_view_has_every_design_with_its_numbers():
	var view: Dictionary = _ok(commands.handle("archetypes", {}))
	var names: Array = []
	for design in view.archetypes:
		names.append(design.name)
		assert_false(design.has("error"), design.name)
		assert_gt(design.top_speed, 0.0, design.name)
		assert_true(design.burst_speed >= design.top_speed, design.name)
		assert_gt(design.mass, 0.0, design.name)
	assert_eq(names, BridgeCommands.Validator.archetype_names())
	assert_true(view.ranges.has("engage"))
	var light: Dictionary = {}
	for design in view.archetypes:
		if design.name == "fighter_light":
			light = design
	assert_has(light.flown_by, "verdant", "Verdant's roster has it")
	assert_almost_eq(light.length, 0.83931 * Constants.SHIP_MODEL_LENGTH, 0.001)
	assert_eq(light.parts[0].name, "Rail Cannon II")
	assert_gt(light.gun_dps, 0.0)
	var lance_light: Dictionary = {}
	for design in view.archetypes:
		if design.name == "lance_light":
			lance_light = design
	assert_gt(lance_light.burst_speed, lance_light.top_speed, "Its afterburner")


func test_the_factions_view_has_wars_both_ways_and_havens():
	var view: Dictionary = _ok(commands.handle("factions", {}))
	var by_id := {}
	for faction in view.factions:
		by_id[faction.id] = faction
	assert_has(by_id.verdant.at_war, "violet")
	assert_has(by_id.violet.at_war, "verdant")
	for faction in view.factions:
		for other in faction.at_war:
			assert_has(by_id[other].at_war, faction.id, "War goes both ways")
	assert_gt(by_id.verdant.havens.size(), 0)
	assert_eq(by_id.verdant.havens[0].sector, "sector_elace")
	assert_true(by_id.verdant.paint is Dictionary and by_id.verdant.paint.has("v"))
	assert_eq(view.archetypes, BridgeCommands.Validator.archetype_names())


func test_the_parts_view_has_every_part_and_who_uses_it():
	var view: Dictionary = _ok(commands.handle("parts", {}))
	var by_id := {}
	for kind in ["weapons", "modules", "commodities"]:
		assert_gt(view[kind].size(), 0, kind)
		for item in view[kind]:
			by_id[item.id] = item
	assert_eq(by_id.tool_ablative_laser.dps, 6.0)
	assert_has(by_id.tool_ablative_laser.used_by, "start start_default")
	assert_has(by_id.preset_cannon_2_308_52_60.used_by, "fighter_light", "Fitted to an archetype")
	assert_eq(by_id.preset_cannon_2_308_52_60.origin, "archetype")
	assert_eq(view.starts[0].id, "start_default")


func test_the_look_view_and_the_music_stream():
	var view: Dictionary = _ok(commands.handle("look", {}))
	var by_path := {}
	for shader in view.shaders:
		by_path[shader.path] = shader
	assert_gt(by_path["res://assets/art/shaders/solid.gdshader"].materials.size(), 10)
	assert_gt(by_path["res://assets/art/shaders/star_surface.gdshader"].scenes.size(), 0, "Named in a star scene")
	assert_eq(view.paints.size(), BridgeCommands.Validator.faction_files().size() * 2)
	assert_string_ends_with(view.music.stream, ".mp3")
	var copy := "user://test_bridge_main.tscn"
	Directory.new().copy(BridgeCommands.MAIN_SCENE, copy)
	var before: String = _text(copy)
	_ok(commands.handle("scene_write", {"path": copy, "node": "AmbientMusic", "values": {"stream": view.music.values.stream}}))
	assert_eq(_text(copy), before, "The same stream: unchanged")
	Directory.new().remove(copy)
