# TscnText: a scene file (.tscn) as text, changed line by line, so an edit touches only the lines it
# means to (a whole re-save by Godot renumbers resources and writes every default). Values are
# written as Godot writes them (var2str; resources as ExtResource( id ), added as needed).
# Sections start with a line beginning "["; a node's properties are "key = value" lines, a value
# going on over the lines after it until the next property (Godot writes dictionaries that way).
# BridgeCommands loads the result again after every change and puts the old text back if it fails.

extends Reference

var header: String = ""
var sections: Array = []  # [{"head": line, "lines": [...]}], in file order (ext_resources, sub_resources, nodes, connections)

var _head_regex := RegEx.new()
var _prop_regex := RegEx.new()


func _init(text: String) -> void:
	_head_regex.compile('(\\w+)="([^"]*)"|(\\w+)=(\\d+)')
	_prop_regex.compile("^([A-Za-z_][\\w/]*) = ")
	var lines: PoolStringArray = text.split("\n")
	var current = null
	for index in range(lines.size()):
		var line: String = lines[index]
		if index == lines.size() - 1 and line == "":
			break  # The file's last newline
		if line.begins_with("["):
			if header == "":
				header = line
				continue
			current = {"head": line, "lines": []}
			sections.append(current)
		elif current != null:
			current.lines.append(line)


# The file's text, spaced the way Godot spaces it: a blank line after every section but between
# ext_resources, between connections, and at the end.
func text() -> String:
	var out: PoolStringArray = [_header_with_load_steps(), ""]
	for index in range(sections.size()):
		var section: Dictionary = sections[index]
		out.append(section.head)
		var lines: Array = section.lines.duplicate()
		while not lines.empty() and lines[-1] == "":
			lines.pop_back()
		for line in lines:
			out.append(line)
		if index + 1 < sections.size():
			var kind: String = _kind(section)
			if not (kind in ["ext_resource", "connection"] and _kind(sections[index + 1]) == kind):
				out.append("")
	return out.join("\n") + "\n"


static func _kind(section: Dictionary) -> String:
	return section.head.substr(1, section.head.find(" ") - 1)


# --- Nodes ---

func head_value(section: Dictionary, key: String) -> String:
	for found in _head_regex.search_all(section.head):
		if found.get_string(1) == key:
			return found.get_string(2)
		if found.get_string(3) == key:
			return found.get_string(4)
	return ""


func is_node(section: Dictionary) -> bool:
	return section.head.begins_with("[node ")


# A node section's path from the scene root ("." for the root).
func node_path(section: Dictionary) -> String:
	var parent: String = head_value(section, "parent")
	if not section.head.find(" parent=") >= 0:
		return "."
	var name: String = head_value(section, "name")
	return name if parent == "." else parent + "/" + name


func find_node(path: String):
	for section in sections:
		if is_node(section) and node_path(section) == path:
			return section
	return null


# The value text of `key` on the node at `path` ("" when the file does not set it).
func get_property(path: String, key: String) -> String:
	var section = find_node(path)
	if section == null:
		return ""
	var span: Array = _span(section, key)
	if span.empty():
		return ""
	var lines: Array = section.lines.slice(span[0], span[1] - 1)
	return PoolStringArray(lines).join("\n").substr(key.length() + 3)


# Sets `key` on the node at `path` to `value_text` (a Godot value's text); "" removes it (the
# script's default then holds).
func set_property(path: String, key: String, value_text: String) -> bool:
	var section = find_node(path)
	if section == null:
		return false
	var span: Array = _span(section, key)
	var new_lines: Array = [] if value_text == "" else (key + " = " + value_text).split("\n")
	if span.empty():
		var at: int = _end_of_properties(section)
		for index in range(new_lines.size()):
			section.lines.insert(at + index, new_lines[index])
	else:
		for _index in range(span[1] - span[0]):
			section.lines.remove(span[0])
		for index in range(new_lines.size()):
			section.lines.insert(span[0] + index, new_lines[index])
	return true


# A new node section under `parent`, after the parent's last descendant; returns its path.
func add_node(parent: String, name: String, type: String, script_id: int) -> String:
	var taken := {}
	for section in sections:
		if is_node(section) and _parent_path(section) == parent:
			taken[head_value(section, "name")] = true
	var unique: String = name
	var number := 2
	while taken.has(unique):
		unique = "%s%d" % [name, number]
		number += 1
	var at: int = sections.size()
	for index in range(sections.size()):
		var section: Dictionary = sections[index]
		if is_node(section):
			var path: String = node_path(section)
			if path == parent or parent == "." or path.begins_with(parent + "/"):
				at = index + 1
		elif section.head.begins_with("[connection") and at > index:
			at = index
	var head: String = '[node name="%s" type="%s" parent="%s"]' % [unique, type, parent]
	var lines: Array = []
	if script_id >= 0:
		lines.append("script = ExtResource( %d )" % script_id)
	sections.insert(at, {"head": head, "lines": lines})
	return unique if parent == "." else parent + "/" + unique


# Removes the node at `path` and every node under it.
func remove_node(path: String) -> bool:
	var removed := false
	for index in range(sections.size() - 1, -1, -1):
		var section: Dictionary = sections[index]
		if is_node(section):
			var own: String = node_path(section)
			if own == path or own.begins_with(path + "/"):
				sections.remove(index)
				removed = true
	return removed


# --- Resources ---

# The id of the ext_resource for `path` of `type`, added if the file has none.
func ext_id(path: String, type: String) -> int:
	var highest := 0
	var last_ext := -1
	for index in range(sections.size()):
		var section: Dictionary = sections[index]
		if section.head.begins_with("[ext_resource "):
			last_ext = index
			var id: int = int(head_value(section, "id"))
			highest = max(highest, id)
			if head_value(section, "path") == path:
				return id
	var id: int = highest + 1
	sections.insert(last_ext + 1, {"head": '[ext_resource path="%s" type="%s" id=%d]' % [path, type, id], "lines": []})
	return id


# Drops ext_resources nothing refers to any more (after a node that used one is gone).
func drop_unused_resources() -> void:
	var body: String = ""
	for section in sections:
		if not section.head.begins_with("[ext_resource "):
			body += section.head + "\n" + PoolStringArray(section.lines).join("\n") + "\n"
	for index in range(sections.size() - 1, -1, -1):
		var section: Dictionary = sections[index]
		if section.head.begins_with("[ext_resource "):
			var id: String = head_value(section, "id")
			if body.find("ExtResource( %s )" % id) < 0:
				sections.remove(index)


# --- Helpers ---

func _parent_path(section: Dictionary) -> String:
	return head_value(section, "parent") if section.head.find(" parent=") >= 0 else ""


# [first line, line after the last] of property `key` in `section`, or [].
func _span(section: Dictionary, key: String) -> Array:
	var lines: Array = section.lines
	for index in range(lines.size()):
		if lines[index].begins_with(key + " = "):
			var end: int = index + 1
			while end < lines.size() and lines[end] != "" and _prop_regex.search(lines[end]) == null:
				end += 1
			return [index, end]
	return []


func _end_of_properties(section: Dictionary) -> int:
	var at: int = section.lines.size()
	while at > 0 and section.lines[at - 1] == "":
		at -= 1
	return at


# The header with load_steps counting the resources (Godot writes one more than there are).
func _header_with_load_steps() -> String:
	var resources := 0
	for section in sections:
		if section.head.begins_with("[ext_resource ") or section.head.begins_with("[sub_resource "):
			resources += 1
	var regex := RegEx.new()
	regex.compile("load_steps=\\d+ ")
	if resources == 0:
		return regex.sub(header, "")
	if regex.search(header) != null:
		return regex.sub(header, "load_steps=%d " % (resources + 1))
	return header.replace("[gd_scene ", "[gd_scene load_steps=%d " % (resources + 1))
