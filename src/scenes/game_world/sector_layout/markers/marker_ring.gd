# Draws a flat ring in the editor only (layout markers' reach: a beacon's radius, a hazard's edge).

tool
extends ImmediateGeometry

var radius: float = 0.0 setget set_radius
var ring_color: Color = Color(1, 1, 1, 0.6) setget set_ring_color


func _ready() -> void:
	var material := SpatialMaterial.new()
	material.flags_unshaded = true
	material.vertex_color_use_as_albedo = true
	material_override = material
	_redraw()


func set_radius(value: float) -> void:
	radius = value
	_redraw()


func set_ring_color(value: Color) -> void:
	ring_color = value
	_redraw()


func _redraw() -> void:
	if not is_inside_tree():
		return
	clear()
	if radius <= 0.0:
		return
	begin(Mesh.PRIMITIVE_LINE_LOOP)
	for index in range(64):
		var angle: float = TAU * index / 64.0
		set_color(ring_color)
		add_vertex(Vector3(cos(angle), 0.0, sin(angle)) * radius)
	end()
