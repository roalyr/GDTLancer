# Tests for Strings: every key has every language, every key the code and scenes ask for is in the
# file, scenes' keyed labels follow the language, and a missing key reads as itself.

extends GutTest

const KEY_CALL = "Strings\\.t\\(\"([a-z0-9_.]+)\""  # Strings.t("a.key" ...)
const KEY_META = "\"str\": \"([a-z0-9_.]+)\""  # A scene node's meta


func after_each():
	Settings.reset_to_defaults()
	Strings.set_language("en")


func test_every_key_has_every_language():
	var empty := []
	for key in Strings.keys():
		for language in Strings.LANGUAGES:
			if str(Strings.entry(key).get(language, "")).strip_edges() == "":
				empty.append("%s (%s)" % [key, language])
	assert_eq(empty, [], "Strings with no text in a language")


func test_every_key_asked_for_is_in_the_file():
	var missing := {}
	var key_call := RegEx.new()
	key_call.compile(KEY_CALL)
	var key_meta := RegEx.new()
	key_meta.compile(KEY_META)
	for path in _files("res://src", ".gd") + _files("res://scenes", ".tscn"):
		if path.begins_with("res://src/tests") or path.ends_with("/Strings.gd"):  # Its header's examples
			continue
		var file := File.new()
		file.open(path, File.READ)
		var text := file.get_as_text()
		file.close()
		for regex in [key_call, key_meta]:
			for found in regex.search_all(text):
				var key: String = found.get_string(1)
				if not key.ends_with(".") and not Strings.has(key):
					missing[key] = path
	assert_eq(missing.keys(), [], "Keys the code or scenes name that strings.json lacks")


func test_a_keyed_label_follows_the_language():
	var label := Label.new()
	label.set_meta(Strings.STR, "common.close")
	add_child_autofree(label)
	assert_eq(label.text, "CLOSE")
	Strings.set_language("uk")
	assert_eq(label.text, "ЗАКРИТИ")


func test_a_missing_key_reads_as_itself_and_args_fill_in():
	assert_eq(Strings.t("no.such.key.for.test"), "no.such.key.for.test")
	assert_eq(Strings.t("options.values", ["A · B"]), "Values: A · B")


static func _files(dir: String, ending: String) -> Array:
	var out := []
	var walk := Directory.new()
	if walk.open(dir) != OK:
		return out
	walk.list_dir_begin(true, true)
	var name := walk.get_next()
	while name != "":
		var path: String = dir + "/" + name
		if walk.current_is_dir():
			out += _files(path, ending)
		elif name.ends_with(ending):
			out.append(path)
		name = walk.get_next()
	return out
