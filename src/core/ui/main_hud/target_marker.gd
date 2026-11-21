# TargetMarker: the mark of an unselected target on the HUD, drawn as lines at its own size (a
# texture scaled up went soft): a shape per kind, diamond ship, square station, triangle beacon
# (filled for a mayday's), ring planet, moon or jump point, dot rock, x wreck, small filled
# diamond for ore chunks and loose lances. A hostile's mark is bigger; a ship's is filled once it
# has seen the player (`filled`), a station's never is. A hostile ship's pilot level (PilotLevel)
# shows as pips in a row under its mark, one for a rookie to four for an ace. Drawn white: the bracket's
# BracketNormal tints it (side, kind), and the bracket fades it with distance. paint() draws the same
# marks on any canvas (the map's).

extends Control

const LINE = 2.5  # px
const SIZE = 1.5  # Every mark's size, times (a phone held at arm's length wants them this big)
const SEGMENTS = 24
const PIP_GAP = 7.0  # px from the mark's bottom to the pips' centres
const PIP_STEP = 8.0  # px between pips
const PIP_RADIUS = 2.0

var kind: String = "other"  # TargetKinds.kind_of
var hostile: bool = false
var filled: bool = false
var level: int = -1  # Pips under the mark: level + 1 of them; -1 none


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func set_mark(new_kind: String, new_hostile: bool, new_filled: bool = false, new_level: int = -1) -> void:
	if new_kind == kind and new_hostile == hostile and new_filled == filled and new_level == level:
		return
	kind = new_kind
	hostile = new_hostile
	filled = new_filled
	level = new_level
	update()


func _draw() -> void:
	paint(self, rect_size * 0.5, kind, hostile, filled, Color.white, level)


# Draws the mark of a `kind` target (TargetKinds.kind_of) centred on `centre`, on any CanvasItem in
# its _draw: the brackets draw it white and tint it, the map (MapView) in its colour. `scale`: of
# the mark's size (the map's are smaller).
static func paint(canvas: CanvasItem, centre: Vector2, mark_kind: String, is_hostile: bool, is_filled: bool, color: Color,
		pips: int = -1, scale: float = 1.0) -> void:
	var grow: float = (1.35 if is_hostile else 1.0) * SIZE * scale
	_shape(canvas, centre, mark_kind, grow, SIZE * scale, is_filled, color)
	if pips >= 0:
		_pips(canvas, centre + Vector2(0, 5.0 * grow + PIP_GAP * scale), pips + 1, color, scale)  # Under the diamond


# `count` dots in a row centred on `centre`.
static func _pips(canvas: CanvasItem, centre: Vector2, count: int, color: Color, scale: float) -> void:
	for index in range(count):
		_dot(canvas, centre + Vector2((index - (count - 1) * 0.5) * PIP_STEP * scale, 0), PIP_RADIUS * scale, color)


static func _shape(canvas: CanvasItem, centre: Vector2, mark_kind: String, grow: float, size: float, is_filled: bool, color: Color) -> void:
	match mark_kind:
		"ship":
			_polygon(canvas, centre, [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)], 5.0 * grow, is_filled, color)
		"station":
			_polygon(canvas, centre, [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)], 6.0 * grow, false, color)
		"beacon":
			_polygon(canvas, centre, [Vector2(0, -1.15), Vector2(1, 0.7), Vector2(-1, 0.7)], 5.0 * size, false, color)
		"distress":
			_polygon(canvas, centre, [Vector2(0, -1.15), Vector2(1, 0.7), Vector2(-1, 0.7)], 6.0 * size, true, color, Constants.UI_DISTRESS_FILL_ALPHA)
		"body", "jump":
			_ring(canvas, centre, 6.0 * size, LINE, color)
		"rock":
			_dot(canvas, centre, 2.5 * size, color)
		"wreck":
			var arm: float = 4.5 * size
			canvas.draw_line(centre + Vector2(-arm, -arm), centre + Vector2(arm, arm), color, LINE, true)
			canvas.draw_line(centre + Vector2(arm, -arm), centre + Vector2(-arm, arm), color, LINE, true)
		"pickup":
			_polygon(canvas, centre, [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)], 4.0 * size, true, color)
		_:
			_dot(canvas, centre, 3.0 * size, color)


static func _dot(canvas: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(_circle(centre, radius), color, PoolVector2Array(), null, null, true)


static func _ring(canvas: CanvasItem, centre: Vector2, radius: float, width: float, color: Color) -> void:
	canvas.draw_arc(centre, radius, 0.0, TAU, SEGMENTS, color, width, true)


# A closed outline through `corners` (unit offsets times `size`), filled if `fill` (at `fill_alpha`
# of the colour's own).
static func _polygon(canvas: CanvasItem, centre: Vector2, corners: Array, size: float, fill: bool, color: Color, fill_alpha: float = 1.0) -> void:
	var points := PoolVector2Array()
	for corner in corners:
		points.append(centre + corner * size)
	if fill:
		canvas.draw_colored_polygon(points, Color(color.r, color.g, color.b, color.a * fill_alpha), PoolVector2Array(), null, null, true)
	points.append(points[0])
	canvas.draw_polyline(points, color, LINE, true)


static func _circle(centre: Vector2, radius: float) -> PoolVector2Array:
	var points := PoolVector2Array()
	for index in range(SEGMENTS):
		points.append(centre + Vector2(radius, 0).rotated(TAU * index / SEGMENTS))
	return points
