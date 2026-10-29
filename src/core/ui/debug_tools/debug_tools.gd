# DebugTools: the debug overlay's quick tools, one panel with a page per tool, all by touch.
# - JUMP: every sector; pick one to be there at once (no fuel, from anywhere, docked or not).
# - GO TO: the current sector's places (stations, beacons, jump points, bodies, megastructures), or
#   typed coordinates in km; the ship is put a standoff away, stopped (undocked first if need be).
# - TO TARGET: straight to the selected target, TARGET_STANDOFF off its edge, at its speed.
# - REFIT: every tool slot and module slot of the ship; pick one, then any part that fits it (or
#   none). Free and at once, without docking or storage.

extends Control

const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const Fitting = preload("res://src/core/systems/fitting.gd")
const MainTheme = preload("res://assets/themes/main_theme.tres")
const BUTTON_HEIGHT = 64
const STANDOFF_MIN = 1500.0  # m off a place's edge the ship is put
const TARGET_STANDOFF = 300.0  # m off the selected target's edge
const PLACE_GROUPS = [["dockable_station", "STATION"], ["beacon", "BEACON"], ["jump_point", "JUMP POINT"], ["celestial", "BODY"], ["megastructure", "MEGASTRUCTURE"]]

var _title: Label = null
var _status: Label = null
var _list: VBoxContainer = null
var _coords: HBoxContainer = null
var _coord_edits: Array = []  # LineEdits: x, y, z in km
var _target: WeakRef = weakref(null)  # The player's selected target


func _ready() -> void:
	EventBus.connect("player_target_selected", self, "_on_target_selected")
	EventBus.connect("player_target_deselected", self, "_on_target_selected", [null])
	theme = MainTheme
	visible = false
	anchor_right = 1.0
	anchor_bottom = 1.0
	pause_mode = PAUSE_MODE_PROCESS
	var panel := Panel.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.margin_left = 20
	panel.margin_top = 20
	panel.margin_right = -20
	panel.margin_bottom = -20
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.anchor_right = 1.0
	layout.anchor_bottom = 1.0
	layout.margin_left = 16
	layout.margin_top = 16
	layout.margin_right = -16
	layout.margin_bottom = -16
	layout.add_constant_override("separation", 12)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	header.add_constant_override("separation", 8)
	layout.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_title.valign = Label.VALIGN_CENTER
	header.add_child(_title)
	header.add_child(_button("CLOSE", self, "close", [], 160))
	_status = Label.new()
	_status.autowrap = true
	layout.add_child(_status)
	_coords = HBoxContainer.new()
	_coords.add_constant_override("separation", 8)
	layout.add_child(_coords)
	for axis in ["X", "Y", "Z"]:
		var label := Label.new()
		label.text = axis + " KM"
		label.valign = Label.VALIGN_CENTER
		_coords.add_child(label)
		var edit := LineEdit.new()
		edit.rect_min_size = Vector2(160, BUTTON_HEIGHT)
		edit.text = "0"
		_coords.add_child(edit)
		_coord_edits.append(edit)
	_coords.add_child(_button("HERE", self, "_fill_coords_here", [], 140))
	_coords.add_child(_button("GO", self, "_go_to_typed", [], 140))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.scroll_horizontal_enabled = false
	layout.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_constant_override("separation", 8)
	scroll.add_child(_list)


func close() -> void:
	visible = false


func _button(text: String, target: Object, method: String, binds: Array = [], width: int = 0) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = FOCUS_NONE
	button.rect_min_size = Vector2(width, BUTTON_HEIGHT)
	button.clip_text = true
	button.connect("pressed", target, method, binds)
	return button


func _clear_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


func _show(title: String, with_coords: bool) -> void:
	_title.text = title
	_status.text = ""
	_coords.visible = with_coords
	_clear_list()
	visible = true


# --- JUMP ---

func open_jump() -> void:
	_show("JUMP", false)
	var ids: Array = []
	for id in TemplateDatabase.locations:
		if TemplateDatabase.locations[id].get("connections") != null:
			ids.append(id)
	ids.sort()
	for id in ids:
		var location = TemplateDatabase.locations[id]
		var name: String = str(location.get("location_name")) if location.get("location_name") != null else id
		var here: String = "  (HERE)" if id == GameState.current_sector_id else ""
		_list.add_child(_button((name + here).to_upper(), self, "jump_to", [id]))


func jump_to(sector_id: String) -> void:
	if sector_id == GameState.current_sector_id or not is_instance_valid(GlobalRefs.world_manager):
		return
	close()
	if GameState.player_docked_at != "":
		EventBus.emit_signal("player_undocked")
		yield(get_tree(), "idle_frame")
	GlobalRefs.world_manager._travel_to_sector_immediate(sector_id)


# --- GO TO ---

func open_go_to() -> void:
	_show("GO TO", true)
	_fill_coords_here()
	for place in places():
		_list.add_child(_button("%s  %s  (%.0f KM)" % [place.kind, place.name.to_upper(), place.distance / 1000.0], self, "go_to_place", [place.node]))


# The sector's places, nearest first: [{"node", "name", "kind", "distance"}].
func places() -> Array:
	var found: Array = []
	var from: Vector3 = _ship_position()
	for group in PLACE_GROUPS:
		for node in get_tree().get_nodes_in_group(group[0]):
			if not (node is Spatial) or not is_instance_valid(node) or not node.is_inside_tree():
				continue
			var name = node.get("station_name")
			if name == null or str(name) == "":
				name = node.get("display_name") if node.get("display_name") != null else node.name
			found.append({"node": node, "name": str(name), "kind": group[1], "distance": from.distance_to(node.global_transform.origin)})
	found.sort_custom(self, "_nearer")
	return found


func _nearer(a: Dictionary, b: Dictionary) -> bool:
	return a.distance < b.distance


func go_to_place(node: Spatial, standoff: float = STANDOFF_MIN, velocity: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(node):
		return
	var target: Vector3 = node.global_transform.origin
	var away: Vector3 = (_ship_position() - target).normalized()
	if away.length_squared() < 0.5:
		away = Vector3.BACK
	put_ship_at(target + away * (_size_of(node) + standoff), velocity)


# --- TO TARGET ---

func _on_target_selected(target) -> void:
	_target = weakref(target)


# Next to the selected target, moving with it. Returns false without one.
func go_to_target() -> bool:
	var target = _target.get_ref()
	var ship = GlobalRefs.player_agent_body
	if not (target is Spatial and is_instance_valid(target) and target.is_inside_tree()) or target == ship:
		return false
	var velocity = target.get("linear_velocity")
	go_to_place(target, TARGET_STANDOFF, velocity if velocity is Vector3 else Vector3.ZERO)
	return true


func _go_to_typed() -> void:
	var values: Array = []
	for edit in _coord_edits:
		if not edit.text.strip_edges().is_valid_float():
			_status.text = "Coordinates are numbers, in km"
			return
		values.append(float(edit.text) * 1000.0)
	put_ship_at(Vector3(values[0], values[1], values[2]))


func _fill_coords_here() -> void:
	var at: Vector3 = _ship_position()
	for index in range(3):
		_coord_edits[index].text = "%.1f" % (at[index] / 1000.0)


# Puts the player's ship at `position`, moving at `velocity` (undocked first if docked).
func put_ship_at(position: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	var ship = GlobalRefs.player_agent_body
	if not is_instance_valid(ship):
		return
	close()
	if GameState.player_docked_at != "":
		EventBus.emit_signal("player_undocked")
		yield(get_tree(), "idle_frame")
	ship.global_transform.origin = position
	ship.linear_velocity = velocity
	ship.angular_velocity = Vector3.ZERO
	if velocity == Vector3.ZERO and ship.has_method("command_stop"):
		ship.command_stop()


func _ship_position() -> Vector3:
	var ship = GlobalRefs.player_agent_body
	return ship.global_transform.origin if is_instance_valid(ship) else Vector3.ZERO


# Half the widest extent of a place's meshes, m.
static func _size_of(node: Spatial) -> float:
	for property in ["obstacle_radius", "radius"]:
		var value = node.get(property)
		if value != null and float(value) > 0.0:
			return float(value)
	var bounds := AABB()
	var found := false
	var stack: Array = [node]
	while not stack.empty():
		var item = stack.pop_back()
		stack += item.get_children()
		if item is MeshInstance and item.mesh != null:
			var box: AABB = item.global_transform.xform(item.get_aabb())
			bounds = box if not found else bounds.merge(box)
			found = true
	if not found:
		return 0.0
	return max(bounds.size.x, max(bounds.size.y, bounds.size.z)) * 0.5


# --- REFIT ---

func open_refit() -> void:
	_show("REFIT", false)
	var ship = GlobalRefs.player_agent_body
	if not is_instance_valid(ship):
		_status.text = "No ship"
		return
	var sizes: Array = ShipFit.tool_slot_sizes(ship.ship_template)
	for index in range(ship.fit.tools.size()):
		var size: String = sizes[index] if index < sizes.size() else "?"
		_list.add_child(_button("TOOL %d (%s): %s" % [index + 1, size.to_upper(), _part_label(ship.fit.tools[index])], self, "_pick_part", ["tools", index]))
	for index in range(ship.fit.modules.size()):
		_list.add_child(_button("MODULE %d: %s" % [index + 1, _part_label(ship.fit.modules[index])], self, "_pick_part", ["modules", index]))


func _pick_part(kind: String, slot: int) -> void:
	var ship = GlobalRefs.player_agent_body
	if not is_instance_valid(ship):
		return
	_show("REFIT: %s %d" % ["TOOL" if kind == "tools" else "MODULE", slot + 1], false)
	_list.add_child(_button("< BACK", self, "open_refit"))
	_list.add_child(_button("EMPTY", self, "refit", [kind, slot, ""]))
	for part_id in parts_for(ship, kind, slot):
		_list.add_child(_button(_part_label(part_id), self, "refit", [kind, slot, part_id]))


# Every part that can go in the slot: tools that fit its size, any module.
static func parts_for(ship: Node, kind: String, slot: int) -> Array:
	var ids: Array = []
	if kind == "tools":
		var sizes: Array = ShipFit.tool_slot_sizes(ship.ship_template)
		for tool_id in TemplateDatabase.utility_tools:
			if slot < sizes.size() and ShipFit.tool_fits_slot(TemplateDatabase.utility_tools[tool_id], sizes[slot]):
				ids.append(tool_id)
	else:
		for module_id in TemplateDatabase.assets_modules:
			ids.append(module_id)
	ids.sort()
	return ids


func refit(kind: String, slot: int, part_id: String) -> void:
	var ship = GlobalRefs.player_agent_body
	if not is_instance_valid(ship):
		return
	var fit: Dictionary = ship.fit.duplicate(true)
	fit[kind][slot] = part_id
	ship.apply_fit(fit)
	open_refit()
	_status.text = "Fitted %s" % _part_label(part_id)


static func _part_label(part_id: String) -> String:
	return "-" if part_id == "" else Fitting.part_name(part_id).to_upper()
