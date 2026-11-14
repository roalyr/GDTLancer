# InfoWindow: a read-only window over the HUD (ShipWindow, PilotWindow): a title, CLOSE, a summary
# line and a scrolled list built of the fitting window's pieces (scenes/ui/menus/fitting/: heading,
# row, note). Open, it pauses the game, as the options and interaction windows do; closing puts the
# pause back as it was. A window fills the list in fill(); open() and refresh() rebuild it.

extends Control

const HeadingScene = preload("res://scenes/ui/menus/fitting/fitting_heading.tscn")
const RowScene = preload("res://scenes/ui/menus/fitting/fitting_row.tscn")
const NoteScene = preload("res://scenes/ui/menus/fitting/fitting_note.tscn")

var _was_paused: bool = false

onready var _title: Label = $Panel/Layout/Header/Title
onready var _summary: Label = $Panel/Layout/Summary
onready var _list: VBoxContainer = $Panel/Layout/Scroll/List


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	$Panel/Layout/Header/ButtonClose.connect("pressed", self, "close")
	EventBus.connect("player_docked", self, "_on_player_docked")


func open() -> void:
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
	refresh()
	$Panel/Layout/Scroll.scroll_vertical = 0


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


# Docking covers the screen with the fitting window: nothing of this stays open under it.
func _on_player_docked(_location_id) -> void:
	close()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	fill()


func fill() -> void:
	pass


func add_heading(text: String) -> void:
	if _list.get_child_count() > 0:
		var gap := Control.new()
		gap.rect_min_size = Vector2(0, 10)
		_list.add_child(gap)
	var heading: Label = HeadingScene.instance()
	heading.text = text.to_upper()
	_list.add_child(heading)


# A row: `title` over `detail` (dimmer, wrapping), every other one shaded; returns it, so a window
# may colour its name or add to it.
func add_row(title: String, detail: String) -> Control:
	var panel: PanelContainer = RowScene.instance()
	var rows: int = 0
	for child in _list.get_children():
		rows = rows + 1 if child is PanelContainer else 0  # Shading starts over under each heading
	if rows % 2 != 0:
		panel.self_modulate = Color(1, 1, 1, 0)
	_list.add_child(panel)
	panel.get_node("Row/Text/Name").text = title.to_upper()
	var detail_label: Label = panel.get_node("Row/Text/Detail")
	detail_label.text = detail
	detail_label.visible = detail != ""
	return panel


func add_note(text: String) -> void:
	var note: Label = NoteScene.instance()
	note.text = text
	_list.add_child(note)


# A station's name by its location id (the dockable stations in the world), else the id.
func station_name(location_id: String) -> String:
	for station in get_tree().get_nodes_in_group("dockable_station"):
		if station.get("location_id") == location_id:
			return str(station.station_name)
	return location_id


static func duration_text(seconds: float) -> String:
	var minutes: int = int(seconds / 60.0)
	return "%d h %02d min" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d min" % minutes
