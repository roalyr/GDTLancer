# Strings: every piece of text the player reads, in every language the game has (LANGUAGES), from
# one file, database/strings/strings.json: {key: {"en": text, "uk": text}}. Edit it with the
# development tool (tools/dev.py, Strings), not by hand. Settings "language" picks the language;
# on a phone or a computer whose system language is one of these, the first run starts in it.
#   - Code reads text by key: Strings.t("options.title"), Strings.t("fit.sell_for", [price])
#     (`args` fill the text's %s / %d, as GDScript's %). A key not in the file reads as itself, so
#     a missing string shows, not a blank (the strings test fails on it).
#   - A scene's Label, Button or HudBar (its caption) with the meta STR (a key) takes that key's text as it enters the
#     tree and again when the language changes; the scene keeps its English text for the editor.
#   - Text code made itself is redone on "changed": a window or the HUD redraws its words then (or
#     on its next refresh, as most do on open).
# Not Godot's translation server: that needs the UI rebuilt to switch; here a switch is one signal.

extends Node

signal changed(language)

const PATH = "res://database/strings/strings.json"
const LANGUAGES = ["en", "uk"]  # The first is the fallback: every key has it
const LANGUAGE_NAMES = {"en": "ENGLISH", "uk": "УКРАЇНСЬКА"}  # Each in itself (the option shows them so)
const STR = "str"  # Meta: the key whose text a Label or Button shows
const GROUP = "strings_keyed"

var language: String = "en"
var _table: Dictionary = {}
var _missing: Dictionary = {}  # Keys asked for and not found (warned once each)


func _ready() -> void:
	load_table()
	get_tree().connect("node_added", self, "_on_node_added")
	_take_present(get_tree().root)  # As UiScale: a main scene is in the tree before autoloads ready
	Settings.connect("changed", self, "_on_settings_changed")
	Settings.connect("loaded", self, "_on_settings_loaded")
	set_language(str(Settings.get_option("language")))


func load_table() -> void:
	_table = {}
	var file := File.new()
	if file.open(PATH, File.READ) != OK:
		push_error("Strings: cannot read " + PATH)
		return
	var parsed := JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
		push_error("Strings: %s line %d: %s" % [PATH, parsed.error_line, parsed.error_string])
		return
	_table = parsed.result


# The text of `key` in the current language (else in English, else the key itself).
func t(key: String, args = null) -> String:
	var entry = _table.get(key)
	var text: String = key
	if typeof(entry) == TYPE_DICTIONARY:
		text = str(entry.get(language, "")) if str(entry.get(language, "")) != "" else str(entry.get(LANGUAGES[0], key))
	elif not _missing.has(key):
		_missing[key] = true
		push_warning("Strings: no '%s' in %s" % [key, PATH])
	if args == null:
		return text
	return text % (args if typeof(args) == TYPE_ARRAY else [args])


# A name from the game's data (a part's, a hull's, a cargo's: "Laser Mk I-light") in the current
# language: the key is the English name made a key ("name.laser_mk_i_light"), so every copy of a
# design (evolved hulls) shares it. A name with no key reads as it is (a station's, a pilot's).
func name_of(english: String) -> String:
	var key: String = name_key(english)
	return t(key) if _table.has(key) else english


# A word the game keeps in English as state (an AI's activity "PATROLLING", a side "hostile", a
# pilot level "VETERAN") as the player reads it: key "word." and it made a key, upper case kept
# as the English had it. A word with no key reads as it is.
func word(english: String) -> String:
	var key: String = "word." + name_key(english).trim_prefix("name.")
	if not _table.has(key):
		return english
	var text: String = t(key)
	return text.to_upper() if english == english.to_upper() else text


static func name_key(english: String) -> String:
	var slug := ""
	for character in english.to_lower():
		slug += character if character.is_valid_identifier() or character.is_valid_integer() else "_"
	while slug.find("__") >= 0:
		slug = slug.replace("__", "_")
	return "name." + slug.strip_edges().trim_prefix("_").trim_suffix("_")


func has(key: String) -> bool:
	return _table.has(key)


func keys() -> Array:
	return _table.keys()


func entry(key: String) -> Dictionary:
	return _table.get(key, {})


func set_language(code: String) -> void:
	if not code in LANGUAGES:
		code = LANGUAGES[0]
	language = code
	for node in get_tree().get_nodes_in_group(GROUP):
		_apply(node)
	emit_signal("changed", language)


# A first run (no language saved) starts in the system's language when the game has it.
func _on_settings_loaded() -> void:
	if not Settings.is_saved("language"):
		var system: String = OS.get_locale().substr(0, 2).to_lower()
		if system in LANGUAGES and system != Settings.get_option("language"):
			Settings.set_option("language", system)
			return
	set_language(str(Settings.get_option("language")))


func _on_settings_changed(key: String, value) -> void:
	if key == "language":
		set_language(str(value))


func _take_present(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_take_present(child)


func _on_node_added(node: Node) -> void:
	if node.has_meta(STR):
		node.add_to_group(GROUP)
		_apply(node)


func _apply(node: Node) -> void:
	if is_instance_valid(node) and node.has_meta(STR):
		var property: String = "caption" if node.get("text") == null and node.get("caption") != null else "text"  # HudBar's caption
		node.set(property, t(str(node.get_meta(STR))))
