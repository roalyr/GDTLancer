# MapWindow: the MAP button's window, two tabs. SECTOR: the current sector from above, what the
# HUD's brackets would show (MapItems.sector) and its geography. GLOBAL: the sectors and their
# routes (MapItems.global). The side bar's filters show or hide each kind of thing (kept while the
# game runs), its buttons zoom, fit and centre on the ship; a tap on the map picks a thing and the
# side bar describes it, TARGET makes a picked thing the HUD's target. Open, it pauses the game,
# as the other windows do; docking closes it.

extends Control

const MapItems = preload("res://src/core/ui/map_window/map_items.gd")
const MapView = preload("res://src/core/ui/map_window/map_view.gd")
const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")

const SECTOR = "sector"
const GLOBAL = "global"
const FILTERS = {  # Per tab, the side bar's switches: [filter key (MapItems'), its name]
	SECTOR: [["stars", "STARS"], ["planets", "PLANETS"], ["moons", "MOONS"], ["belts", "BELTS"], ["rocks", "ROCKS"],
		["stations", "STATIONS"], ["ships", "SHIPS"], ["wrecks", "WRECKS"], ["beacons", "BEACONS"], ["pickups", "PICKUPS"],
		["hazards", "HAZARDS"], ["area", "PLAY AREA"], ["labels", "NAMES"]],
	GLOBAL: [["routes", "ROUTES"], ["labels", "NAMES"]],
}
const TARGETABLE = ["ship", "station", "beacon", "distress", "wreck", "pickup", "rock", "star", "planet", "moon"]
const KIND_NAMES = {"ship": "SHIP", "station": "STATION", "beacon": "BEACON", "distress": "MAYDAY", "wreck": "WRECK",
	"pickup": "PICKUP", "rock": "ROCK", "star": "STAR", "planet": "PLANET", "moon": "MOON", "belt": "BELT", "hazard": "HAZARD"}
const FILTER_HEIGHT = 48.0

var tab: String = SECTOR
var _was_paused: bool = false
var _shown: Dictionary = {SECTOR: {}, GLOBAL: {}}  # Filter key -> on, per tab
var _fit_pending: bool = false  # Fit the view once it has its size (laid out)

onready var _view: Control = $Panel/Layout/Body/View
onready var _title: Label = $Panel/Layout/Header/Title
onready var _filters: VBoxContainer = $Panel/Layout/Body/Side/Filters/List
onready var _info: Label = $Panel/Layout/Body/Side/Info
onready var _target: Button = $Panel/Layout/Body/Side/ButtonTarget
onready var _centre: Button = $Panel/Layout/Body/Side/ButtonCentre


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	var header = $Panel/Layout/Header
	header.get_node("ButtonClose").connect("pressed", self, "close")
	header.get_node("TabSector").connect("pressed", self, "show_tab", [SECTOR])
	header.get_node("TabGlobal").connect("pressed", self, "show_tab", [GLOBAL])
	var side = $Panel/Layout/Body/Side
	side.get_node("Zoom/ButtonZoomIn").connect("pressed", _view, "zoom", [MapView.ZOOM_STEP])
	side.get_node("Zoom/ButtonZoomOut").connect("pressed", _view, "zoom", [1.0 / MapView.ZOOM_STEP])
	side.get_node("Zoom/ButtonFit").connect("pressed", _view, "fit")
	_centre.connect("pressed", self, "centre_on_ship")
	_target.connect("pressed", self, "target_picked")
	_view.connect("picked", self, "_on_picked")
	_view.connect("resized", self, "_on_view_resized")
	EventBus.connect("player_docked", self, "_on_player_docked")


func open() -> void:
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
	show_tab(tab)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _on_player_docked(_location_id) -> void:
	close()


# Shows `which` tab: its things read afresh, its filters, the view fitted to them (the sector
# map: centred on the ship).
func show_tab(which: String) -> void:
	tab = which
	var header = $Panel/Layout/Header
	header.get_node("TabSector").text = "[SECTOR]" if tab == SECTOR else "SECTOR"
	header.get_node("TabGlobal").text = "[GLOBAL]" if tab == GLOBAL else "GLOBAL"
	_view.selected = {}
	refresh()
	_build_filters()
	_on_picked({})
	_fit_pending = true
	if _view.rect_size.x >= 1.0 and _view.rect_size.y >= 1.0:
		_fit_view()


# The view fitted to this tab's things; the sector map centred on the ship.
func _fit_view() -> void:
	_fit_pending = false
	_view.fit()
	if tab == SECTOR:
		centre_on_ship()


func _on_view_resized() -> void:
	if _fit_pending and _view.rect_size.x >= 1.0 and _view.rect_size.y >= 1.0:
		_fit_view()


func refresh() -> void:
	_view.shown = _shown[tab]
	_view.labels = _shown[tab].get("labels", true)
	_view.units = tab == GLOBAL
	if tab == SECTOR:
		var hud: Node = get_parent()
		var projector = hud.get("_target_projector") if hud != null else null
		var targets: Array = projector.collect_world_projected_targets() if projector != null else []
		var layout: Dictionary = TemplateDatabase.sector_layouts.get(GameState.current_sector_id, {})
		var namer: Object = hud if hud != null and hud.has_method("_resolve_target_display_name") else null
		_view.set_items(MapItems.sector(GlobalRefs.current_zone, targets, GlobalRefs.player_agent_body, namer, float(layout.get("play_radius", INF))))
		var location = TemplateDatabase.locations.get(GameState.current_sector_id)
		_title.text = "MAP  ·  %s" % (str(location.location_name).to_upper() if location != null else GameState.current_sector_id.to_upper())
	else:
		var known: Dictionary = MapItems.global(TemplateDatabase.locations, GameState.current_sector_id)
		_view.set_items(known.sectors, known.routes)
		_title.text = "MAP  ·  %d SECTORS" % known.sectors.size()
	_centre.visible = tab == SECTOR


func centre_on_ship() -> void:
	for item in _view.items:
		if item.kind == "player":
			_view.centre_on(item.at)
			return


# Flips one filter of this tab.
func toggle_filter(key: String) -> void:
	_shown[tab][key] = not _shown[tab].get(key, true)
	_view.shown = _shown[tab]
	_view.labels = _shown[tab].get("labels", true)
	_build_filters()
	_view.update()
	if not _view.selected.empty() and not _view.is_shown(_view.selected):
		_view.selected = {}
		_on_picked({})


func _build_filters() -> void:
	for child in _filters.get_children():
		_filters.remove_child(child)
		child.queue_free()
	for spec in FILTERS[tab]:
		var on: bool = _shown[tab].get(spec[0], true)
		var button := Button.new()
		button.name = "Filter_" + spec[0]
		button.text = "%s: %s" % [spec[1], "ON" if on else "OFF"]
		button.rect_min_size = Vector2(0, FILTER_HEIGHT)
		button.focus_mode = Control.FOCUS_NONE
		button.modulate = Color(1, 1, 1, 1.0 if on else 0.55)
		button.connect("pressed", self, "toggle_filter", [spec[0]])
		_filters.add_child(button)


# Makes the picked thing the HUD's target (as tapping its bracket does).
func target_picked() -> void:
	var item: Dictionary = _view.selected
	if item.empty() or not is_instance_valid(item.get("ref")) or not item.kind in TARGETABLE:
		return
	EventBus.emit_signal("player_target_selection_requested", item.ref)
	_info.text = describe(item) + "\nTARGET SET."


func _on_picked(item: Dictionary) -> void:
	_info.text = describe(item) if not item.empty() else ("TAP A THING TO SEE IT." if tab == SECTOR else "TAP A SECTOR TO SEE IT.")
	_target.visible = tab == SECTOR and not item.empty() and item.kind in TARGETABLE and is_instance_valid(item.get("ref"))


# The side bar's lines on a picked item: its name, what it is, how far.
func describe(item: Dictionary) -> String:
	var lines: Array = []
	if item.kind == "sector":
		lines.append(item.label.to_upper() + ("  (HERE)" if item.here else ""))
		lines.append("%s, %d ROUTE%s" % [str(item.type).to_upper(), item.routes, "" if item.routes == 1 else "S"])
		var here = TemplateDatabase.locations.get(GameState.current_sector_id)
		if here != null and not item.here:
			var from: Vector2 = Vector2(here.global_position.x, here.global_position.z)
			lines.append(MapView.units_text(from.distance_to(item.at)) + " AWAY")
		return PoolStringArray(lines).join("\n")
	var name: String = item.label if item.label != "" else item.get("field", "")
	lines.append(name.to_upper() if name != "" else KIND_NAMES.get(item.kind, item.kind.to_upper()))
	var what: String = KIND_NAMES.get(item.kind, item.kind.to_upper())
	if item.kind == "ship":
		what = "%s SHIP" % TargetKinds.side_of(item.ref, GlobalRefs.player_agent_body).to_upper() if is_instance_valid(item.ref) else what
	elif item.kind == "belt":
		what = "ROCK FIELD" if item.has("field") else "BELT, %d ROCKS SEEN" % item.get("rocks", 0)
	if item.radius > 0.0:
		what += ", %s ACROSS" % MapView.distance_text(item.radius * 2.0)
	lines.append(what)
	for other in _view.items:
		if other.kind == "player":
			lines.append(MapView.distance_text(max(0.0, other.at.distance_to(item.at) - (item.radius if item.kind in ["star", "planet", "moon"] else 0.0))) + " AWAY")
	return PoolStringArray(lines).join("\n")
