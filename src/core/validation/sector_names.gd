# SectorNames: how a sector's folder, files and nodes are named (CONTENT.md, Sectors). One set of
# rules: ContentValidator checks every sector against them, and the development tool names what it
# makes by them (tools/devtool/bridge_commands.gd), so what the tool makes always keeps them.
#   scenes/levels/sectors/<sector id>/            sector_<word>, the location's template_id
#       <sector id>.tscn                          the sector scene, its root "Sector <Word>"
#       <sector id>_layout.tscn                   its layout
#       <body>/<body>.tscn                        one folder a body; other files there are its parts,
#       <body>/<body>_<part>.tscn                 named after it (a star's sprite)
# A body is <kind>_<word>[_<suffix>], <word> the sector's (sector_elace: elace):
#   star_elace, star_elace_b ...     the main star, then more by letter
#   planet_elace_a, planet_elace_b   planets by letter
#   moon_elace_b1, moon_elace_b2     a planet's moons: its letter and a number
#   belt_elace_deep                  a belt: a word of its own
# Every file and folder is lower_snake_case. A body's root node, and its instance in the sector
# scene, are its title: "Planet Elace B", "Moon Elace B1" (title()). A sector places its own bodies,
# each once, and the shared celestial prefabs (scenes/prefabs/celestial/), as often as it likes.

extends Reference

const SECTOR_PREFIX = "sector_"
const KINDS = ["star", "planet", "moon", "belt"]
const PREFABS_DIR = "res://scenes/prefabs/celestial/"
const LETTERS = "abcdefghijklmnopqrstuvwxyz"


static func is_snake(name: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
	return regex.search(name) != null


# The sector's own word: sector_elace -> elace.
static func word_of(sector_id: String) -> String:
	return sector_id.trim_prefix(SECTOR_PREFIX)


# "" if `sector_id` is a sector folder's name, else what is wrong.
static func sector_problem(sector_id: String) -> String:
	if not is_snake(sector_id):
		return "'%s' is not lower_snake_case" % sector_id
	if not sector_id.begins_with(SECTOR_PREFIX) or word_of(sector_id) == "":
		return "'%s' does not start with %s" % [sector_id, SECTOR_PREFIX]
	return ""


# A node name from a file's name: "planet_elace_b" -> "Planet Elace B", "moon_elace_b1" -> "Moon Elace B1".
static func title(stem: String) -> String:
	var words: Array = []
	for word in stem.get_file().get_basename().split("_"):
		if word != "":
			words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return PoolStringArray(words).join(" ")


# A body folder's parts: {"kind", "suffix"} ("" suffix: the main star), or {"problem": text}.
static func body_parts(sector_id: String, stem: String) -> Dictionary:
	var word: String = word_of(sector_id)
	if not is_snake(stem):
		return {"problem": "'%s' is not lower_snake_case" % stem}
	for kind in KINDS:
		var head: String = "%s_%s" % [kind, word]
		if stem == head or stem.begins_with(head + "_"):
			var suffix: String = stem.substr(head.length() + 1) if stem != head else ""
			var problem: String = _suffix_problem(kind, suffix)
			return {"problem": "'%s': %s" % [stem, problem]} if problem != "" else {"kind": kind, "suffix": suffix}
	return {"problem": "'%s' is not <%s>_%s_<suffix>" % [stem, PoolStringArray(KINDS).join("|"), word]}


static func _suffix_problem(kind: String, suffix: String) -> String:
	var regex := RegEx.new()
	match kind:
		"star":
			regex.compile("^([b-z])?$")
			return "" if regex.search(suffix) != null else "a star is the sector's (no suffix), then b, c, ..."
		"planet":
			regex.compile("^[a-z]$")
			return "" if regex.search(suffix) != null else "a planet's suffix is one letter"
		"moon":
			regex.compile("^[a-z][0-9]+$")
			return "" if regex.search(suffix) != null else "a moon's suffix is its planet's letter and a number (b1)"
		"belt":
			return "" if suffix != "" else "a belt's suffix is a word of its own (deep)"
	return "no kind"


# The next free name of `kind` in `sector_id`, not in `taken` (stems): a star, planet or moon by
# letter or number (a moon of planet `of`: its letter), a belt from `word`. "" if none can be had.
static func next_name(sector_id: String, kind: String, taken: Array, of: String = "", word: String = "") -> String:
	var head: String = "%s_%s" % [kind, word_of(sector_id)]
	match kind:
		"star":
			if not head in taken:
				return head
			for letter in LETTERS.substr(1):
				if not "%s_%s" % [head, letter] in taken:
					return "%s_%s" % [head, letter]
		"planet":
			for letter in LETTERS:
				if not "%s_%s" % [head, letter] in taken:
					return "%s_%s" % [head, letter]
		"moon":
			if of.length() != 1:
				return ""
			for number in range(1, 100):
				if not "%s_%s%d" % [head, of, number] in taken:
					return "%s_%s%d" % [head, of, number]
		"belt":
			var name: String = "%s_%s" % [head, word]
			return name if word != "" and is_snake(word) and not name in taken else ""
	return ""


# A sector scene's ext_resources: id -> path.
static func ext_resources(scene_text: String) -> Dictionary:
	var out := {}
	var regex := RegEx.new()
	regex.compile('\\[ext_resource path="([^"]+)" type="[^"]+" id=([0-9]+)\\]')
	for found in regex.search_all(scene_text):
		out[int(found.get_string(2))] = found.get_string(1)
	return out


# The instances a scene places under `parent`: [{name, scene}], in order.
static func instances_under(scene_text: String, parent: String) -> Array:
	var resources: Dictionary = ext_resources(scene_text)
	var out: Array = []
	var regex := RegEx.new()
	regex.compile('\\[node name="([^"]+)" parent="%s" instance=ExtResource\\( ([0-9]+) \\)\\]' % parent)
	for found in regex.search_all(scene_text):
		out.append({"name": found.get_string(1), "scene": resources.get(int(found.get_string(2)), "")})
	return out


# The name of a scene's root node, from its text ("" none).
static func root_name(scene_text: String) -> String:
	var regex := RegEx.new()
	regex.compile('\\[node name="([^"]+)" type="[^"]+"\\]')
	var found = regex.search(scene_text)
	return found.get_string(1) if found != null else ""
