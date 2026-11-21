# MapView: the map window's drawing area, all 2D shapes: a grid in round kilometres, then the
# items (MapItems) top-down, the picked one in a bracket. Drag (mouse or finger) moves it, the wheel
# zooms about the pointer (the window's buttons zoom too), a tap picks the nearest item (`picked`).
# Shows only the items whose filter is on (`shown`).

extends Control

signal picked(item)  # The item tapped, or {} for none

const TargetMarker = preload("res://src/core/ui/main_hud/target_marker.gd")

const ZOOM_STEP = 1.5
const MIN_METRES_PER_PX = 2.0
const MAX_METRES_PER_PX = 5.0e7
const FIT_MARGIN = 1.15  # Fit leaves this much room round everything
const GRID_PX = 120.0  # About this many px between grid lines
const PICK_PX = 36.0  # A tap picks the nearest item this close (a fingertip)
const TAP_PX = 12.0  # A press that moves less than this is a tap, not a drag
const MARK_SCALE = 0.8  # Of the brackets' marks
const MIN_BODY_PX = 5.0  # A planet or star never draws smaller
const LABEL_OFFSET = Vector2(12, -10)
const COLOR_GRID = Color(1, 1, 1, 0.06)
const COLOR_AXES = Color(1, 1, 1, 0.14)
const COLOR_TEXT = Color(1, 1, 1, 0.55)
const COLOR_ROUTE = Color(0.5, 0.8, 0.5, 0.6)
const SEGMENTS = 64
const NICE = [1.0, 2.0, 5.0]
const LABEL_ORDER = [["sector", "star", "planet"], ["station", "moon"], ["beacon", "distress", "hazard", "belt"], ["ship", "wreck", "pickup", "jump", "other"]]
const LABEL_TRIES = 3  # Places a name tries (each a line lower) before it is left out

var items: Array = []  # MapItems
var routes: Array = []  # The global map's: [[from id, to id]]
var shown: Dictionary = {}  # Filter key -> on; a key not there is on
var labels: bool = true
var units: bool = false  # Distances in UNITS (a km each: the global map's) rather than M and KM
var centre: Vector2 = Vector2.ZERO  # m at the middle of the view
var metres_per_px: float = 100.0
var selected: Dictionary = {}

var _press_at: Vector2 = Vector2.ZERO
var _pressed: bool = false
var _dragged: bool = false


func _ready() -> void:
	rect_clip_content = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_items(new_items: Array, new_routes: Array = []) -> void:
	items = new_items
	routes = new_routes
	if not selected.empty() and not _still_there(selected):
		selected = {}
	update()


func is_shown(item: Dictionary) -> bool:
	return shown.get(item.filter, true)


# The view takes in every shown item (their sizes too), centred on them.
func fit() -> void:
	var box := Rect2()
	var first := true
	for item in items:
		if not is_shown(item):
			continue
		var reach: Rect2 = Rect2(item.at - Vector2.ONE * item.radius, Vector2.ONE * item.radius * 2.0)
		box = reach if first else box.merge(reach)
		first = false
	if first:
		return
	centre = box.position + box.size * 0.5
	var size: Vector2 = rect_size if rect_size.x > 1.0 and rect_size.y > 1.0 else Vector2(800, 600)
	metres_per_px = clamp(max(box.size.x / size.x, box.size.y / size.y) * FIT_MARGIN, MIN_METRES_PER_PX, MAX_METRES_PER_PX)
	update()


func centre_on(at: Vector2) -> void:
	centre = at
	update()


# Zooms by `factor` (above 1: closer) about `pivot` (px in the view; the middle by default).
func zoom(factor: float, pivot = null) -> void:
	var about: Vector2 = pivot if pivot is Vector2 else rect_size * 0.5
	var before: Vector2 = to_metres(about)
	metres_per_px = clamp(metres_per_px / factor, MIN_METRES_PER_PX, MAX_METRES_PER_PX)
	centre += before - to_metres(about)
	update()


func to_px(at: Vector2) -> Vector2:
	return rect_size * 0.5 + (at - centre) / metres_per_px


func to_metres(px: Vector2) -> Vector2:
	return centre + (px - rect_size * 0.5) * metres_per_px


# The shown item nearest `px` within PICK_PX (a body's or a circle's edge counts as near), or {}.
func item_at(px: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = PICK_PX
	for item in items:
		if not is_shown(item) or item.kind in ["area", "player"]:
			continue
		var distance: float = to_px(item.at).distance_to(px)
		if item.kind in ["belt", "hazard"]:
			distance = abs(distance - item.radius / metres_per_px)  # Its ring
		elif item.radius > 0.0:
			distance = max(0.0, distance - item.radius / metres_per_px)  # Inside a planet
		if distance < best_distance:
			best_distance = distance
			best = item
	return best


# Mouse events alone: a finger arrives as the mouse too (the project emulates the mouse from touch,
# and touch from the mouse), so handling both would move the map twice.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP and event.pressed:
			zoom(ZOOM_STEP, event.position)
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			zoom(1.0 / ZOOM_STEP, event.position)
		elif event.button_index == BUTTON_LEFT:
			_press(event.pressed, event.position)
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		if _dragged or event.position.distance_to(_press_at) > TAP_PX:
			_dragged = true
			centre -= event.relative * metres_per_px
			update()
		accept_event()


func _press(down: bool, at: Vector2) -> void:
	if down:
		_pressed = true
		_dragged = false
		_press_at = at
		return
	if _pressed and not _dragged:
		selected = item_at(at)
		update()
		emit_signal("picked", selected)
	_pressed = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0, 0, 0, 0.35))
	_draw_grid()
	var by_id := {}
	for item in items:
		by_id[str(item.ref)] = item
	if shown.get("routes", true):
		for route in routes:
			if by_id.has(route[0]) and by_id.has(route[1]):
				draw_line(to_px(by_id[route[0]].at), to_px(by_id[route[1]].at), COLOR_ROUTE, 2.0, true)
	for layer in [["area", "hazard", "belt"], ["star", "planet", "moon"], ["rock"], ["mark"], ["sector"], ["player"]]:
		for item in items:
			if is_shown(item) and (item.kind in layer or (layer[0] == "mark" and _is_mark(item))):
				_draw_item(item)
	if labels:
		var taken: Array = []  # Rects of the names drawn: one that would overlap moves down, or is left out
		for rank in LABEL_ORDER:
			for item in items:
				if item.kind in rank and is_shown(item) and item.label != "" and _labelled(item):
					_label(item, taken)
	if not selected.empty() and is_shown(selected):
		_bracket(to_px(selected.at), max(14.0, selected.radius / metres_per_px + 8.0))
	_draw_scale()


func _is_mark(item: Dictionary) -> bool:
	return item.kind in ["ship", "station", "beacon", "distress", "wreck", "pickup", "jump", "other"]


# Bodies, stations, beacons, sectors, hazards and belts carry names; ships only when picked (else
# a crowd of names), rocks never.
func _labelled(item: Dictionary) -> bool:
	if item.kind in ["rock", "area", "player"]:
		return false
	if item.kind in ["ship", "wreck", "pickup"]:
		return item.get("ref") == selected.get("ref")
	return true


func _draw_item(item: Dictionary) -> void:
	var at: Vector2 = to_px(item.at)
	var color: Color = item.color
	var radius: float = item.radius / metres_per_px
	match item.kind:
		"area":
			draw_arc(at, radius, 0.0, TAU, SEGMENTS * 2, color, 2.0, true)
		"hazard":
			draw_circle(at, radius, Color(color.r, color.g, color.b, 0.08))
			draw_arc(at, radius, 0.0, TAU, SEGMENTS, Color(color.r, color.g, color.b, 0.6), 2.0, true)
			if item.get("core", 0.0) > 0.0:
				draw_arc(at, item.core / metres_per_px, 0.0, TAU, SEGMENTS, Color(color.r, color.g, color.b, 0.35), 1.5, true)
		"belt":
			draw_circle(at, radius, Color(color.r, color.g, color.b, 0.07))
			draw_arc(at, radius, 0.0, TAU, SEGMENTS, Color(color.r, color.g, color.b, 0.45), 1.5, true)
		"star":
			var size: float = max(radius, MIN_BODY_PX + 2.0)
			draw_circle(at, size * 1.6, Color(color.r, color.g, color.b, 0.12))  # Its glow
			draw_circle(at, size, color)
		"planet", "moon":
			var size: float = max(radius, MIN_BODY_PX if item.kind == "planet" else MIN_BODY_PX - 2.0)
			draw_circle(at, size, Color(color.r, color.g, color.b, 0.25))
			draw_arc(at, size, 0.0, TAU, SEGMENTS, color, 2.0, true)
		"rock":
			draw_circle(at, 1.6, Color(color.r, color.g, color.b, 0.7))
		"sector":
			var size: float = 13.0 if item.get("here") else 9.0
			draw_circle(at, size, Color(color.r, color.g, color.b, 0.3))
			draw_arc(at, size, 0.0, TAU, SEGMENTS, color, 2.5, true)
		"player":
			var heading: Vector2 = item.get("heading", Vector2(0, -1))
			var side: Vector2 = heading.tangent()
			var points := PoolVector2Array([at + heading * 14.0, at - heading * 9.0 + side * 9.0, at - heading * 4.0, at - heading * 9.0 - side * 9.0])
			draw_colored_polygon(points, Color(1, 1, 1, 0.9), PoolVector2Array(), null, null, true)
		_:
			TargetMarker.paint(self, at, item.kind, item.hostile, item.filled, color, -1, MARK_SCALE)


func _label(item: Dictionary, taken: Array) -> void:
	var text: String = item.label.to_upper()
	if item.kind == "sector" and item.get("here"):
		text += "  (HERE)"
	var radius: float = 0.0 if _is_mark(item) else min(item.radius / metres_per_px, 2000.0)
	var at: Vector2 = to_px(item.at) + LABEL_OFFSET + Vector2(radius * 0.7, -radius * 0.7)
	if item.kind in ["belt", "hazard"]:
		at = to_px(item.at) + Vector2(-_font().get_string_size(text).x * 0.5, -radius - 6.0)  # Over its circle
	var size: Vector2 = _font().get_string_size(text)
	var picked: bool = item.get("ref") == selected.get("ref")
	for attempt in range(LABEL_TRIES):
		var box := Rect2(at + Vector2(0, -_font().get_ascent()), size).grow(2.0)
		var free := true
		for other in taken:
			if other.intersects(box):
				free = false
				break
		if free or picked:  # The picked thing's name always shows
			taken.append(box)
			draw_string(_font(), at, text, Color(item.color.r, item.color.g, item.color.b, 0.9))
			return
		at.y += size.y
	# No room: the name shows when the thing is tapped (the side bar)


# Corner brackets round the picked item, as the HUD's selected bracket.
func _bracket(at: Vector2, half: float) -> void:
	var arm: float = max(6.0, half * 0.4)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip: Vector2 = at + corner * half
		draw_line(tip, tip - Vector2(corner.x * arm, 0), Color.white, 2.0, true)
		draw_line(tip, tip - Vector2(0, corner.y * arm), Color.white, 2.0, true)


func _draw_grid() -> void:
	var step: float = nice_step(GRID_PX * metres_per_px)
	var top_left: Vector2 = to_metres(Vector2.ZERO)
	var bottom_right: Vector2 = to_metres(rect_size)
	var x: float = floor(top_left.x / step) * step
	while x <= bottom_right.x:
		var px: float = to_px(Vector2(x, 0)).x
		draw_line(Vector2(px, 0), Vector2(px, rect_size.y), COLOR_AXES if abs(x) < step * 0.01 else COLOR_GRID, 1.0)
		x += step
	var z: float = floor(top_left.y / step) * step
	while z <= bottom_right.y:
		var py: float = to_px(Vector2(0, z)).y
		draw_line(Vector2(0, py), Vector2(rect_size.x, py), COLOR_AXES if abs(z) < step * 0.01 else COLOR_GRID, 1.0)
		z += step


# A bar a grid step long, bottom left, with its length.
func _draw_scale() -> void:
	var step: float = nice_step(GRID_PX * metres_per_px)
	var length: float = step / metres_per_px
	var start := Vector2(20, rect_size.y - 24)
	draw_line(start, start + Vector2(length, 0), COLOR_TEXT, 2.0)
	draw_line(start - Vector2(0, 6), start + Vector2(0, 6), COLOR_TEXT, 2.0)
	draw_line(start + Vector2(length, -6), start + Vector2(length, 6), COLOR_TEXT, 2.0)
	draw_string(_font(), start + Vector2(length + 10, 6), units_text(step) if units else distance_text(step), COLOR_TEXT)


# The smallest 1, 2 or 5 x 10^n m not below `at_least`.
static func nice_step(at_least: float) -> float:
	if at_least <= 0.0:
		return 1.0
	var power: float = pow(10.0, floor(log(at_least) / log(10.0)))
	for factor in NICE + [10.0]:
		if factor * power >= at_least * 0.999:
			return factor * power
	return 10.0 * power


# Between sectors: UNITS, a kilometre each (a word of the setting's, not of a ruler's).
static func units_text(metres: float) -> String:
	var count: float = metres / 1000.0
	var text: String = ("%d" % int(round(count))) if count >= 10.0 or count == floor(count) else ("%.1f" % count)
	return text + (" UNIT" if text == "1" else " UNITS")


static func distance_text(metres: float) -> String:
	if metres >= 1000.0:
		var km: float = metres / 1000.0
		return ("%d KM" % int(round(km))) if km >= 10.0 or km == floor(km) else ("%.1f KM" % km)
	return "%d M" % int(round(metres))


# The names' and the scale's lettering: main_theme's SmallLabel.
func _font() -> Font:
	return get_font("font", "SmallLabel")


func _still_there(item: Dictionary) -> bool:
	for other in items:
		if other.get("ref") == item.get("ref") and other.kind == item.kind:
			return true
	return false
