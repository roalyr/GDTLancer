# TargetMarker: the mark of an unselected target on the HUD, drawn as lines at its own size (a
# texture scaled up went soft): a shape per kind, diamond ship, square station, triangle beacon
# (dimly filled for a mayday's), ring planet, moon or jump point, dot rock, x wreck, small filled
# diamond for ore chunks and loose lances. A hostile's mark is bigger; a ship's is filled once it
# has seen the player (`filled`), a station's never is. Drawn white: the bracket's BracketNormal
# tints it (side, kind), and the bracket fades it with distance.

extends Control

const LINE = 2.5  # px
const SIZE = 1.5  # Every mark's size, times (a phone held at arm's length wants them this big)
const SEGMENTS = 24

var kind: String = "other"  # TargetKinds.kind_of
var hostile: bool = false
var filled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func set_mark(new_kind: String, new_hostile: bool, new_filled: bool = false) -> void:
	if new_kind == kind and new_hostile == hostile and new_filled == filled:
		return
	kind = new_kind
	hostile = new_hostile
	filled = new_filled
	update()


func _draw() -> void:
	_shape(rect_size * 0.5, (1.35 if hostile else 1.0) * SIZE)


func _shape(centre: Vector2, grow: float) -> void:
	var size: float = SIZE
	match kind:
		"ship":
			_polygon(centre, [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)], 5.0 * grow, filled)
		"station":
			_polygon(centre, [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)], 6.0 * grow, false)
		"beacon":
			_polygon(centre, [Vector2(0, -1.15), Vector2(1, 0.7), Vector2(-1, 0.7)], 5.0 * size, false)
		"distress":
			_polygon(centre, [Vector2(0, -1.15), Vector2(1, 0.7), Vector2(-1, 0.7)], 6.0 * size, true, Constants.UI_DISTRESS_FILL_ALPHA)
		"body", "jump":
			_ring(centre, 6.0 * size, LINE)
		"rock":
			_dot(centre, 2.5 * size)
		"wreck":
			var arm: float = 4.5 * size
			draw_line(centre + Vector2(-arm, -arm), centre + Vector2(arm, arm), Color.white, LINE, true)
			draw_line(centre + Vector2(arm, -arm), centre + Vector2(-arm, arm), Color.white, LINE, true)
		"pickup":
			_polygon(centre, [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)], 4.0 * size, true)
		_:
			_dot(centre, 3.0 * size)


func _dot(centre: Vector2, radius: float) -> void:
	draw_colored_polygon(_circle(centre, radius), Color.white, PoolVector2Array(), null, null, true)


func _ring(centre: Vector2, radius: float, width: float) -> void:
	draw_arc(centre, radius, 0.0, TAU, SEGMENTS, Color.white, width, true)


# A closed outline through `corners` (unit offsets times `size`), filled if `fill` (this opaque).
func _polygon(centre: Vector2, corners: Array, size: float, fill: bool, fill_alpha: float = 1.0) -> void:
	var points := PoolVector2Array()
	for corner in corners:
		points.append(centre + corner * size)
	if fill:
		draw_colored_polygon(points, Color(1, 1, 1, fill_alpha), PoolVector2Array(), null, null, true)
	points.append(points[0])
	draw_polyline(points, Color.white, LINE, true)


static func _circle(centre: Vector2, radius: float) -> PoolVector2Array:
	var points := PoolVector2Array()
	for index in range(SEGMENTS):
		points.append(centre + Vector2(radius, 0).rotated(TAU * index / SEGMENTS))
	return points
