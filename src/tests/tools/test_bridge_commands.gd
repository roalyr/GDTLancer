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
