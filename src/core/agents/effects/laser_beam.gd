# LaserBeam: a faint line from a shooter to where its laser shot landed, so it reads who is firing
# at whom. Lasers are invisible in vacuum: this is a gameplay cue, kept barely visible
# (Constants.LASER_BEAM_BRIGHTNESS), fading out over Constants.LASER_BEAM_DURATION.
# - One ImmediateGeometry line, top level (world space). Both ends follow their bodies while it
#   fades: the shooter's centre (inside its hull) and the hit point, kept in the hit body's space.
# - Shared material (laser_beam_material.tres); colour and brightness per beam in the vertex colour.

extends ImmediateGeometry

const BeamMaterial = preload("res://assets/art/effects/laser_beam_material.tres")

var _from: Spatial = null
var _to: Spatial = null
var _to_local := Vector3.ZERO  # Hit point in the hit body's space
var _color := Color.white
var _age := 0.0


# A beam from `from_body` to `hit_point` (world) on `to_body`, in `color`.
func setup(from_body: Spatial, to_body: Spatial, hit_point: Vector3, color: Color) -> void:
	_from = from_body
	_to = to_body
	_to_local = to_body.to_local(hit_point)
	_color = color


func _ready() -> void:
	set_as_toplevel(true)
	global_transform = Transform.IDENTITY
	material_override = BeamMaterial
	cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= Constants.LASER_BEAM_DURATION or not is_instance_valid(_from) or not is_instance_valid(_to):
		queue_free()
		return
	_redraw()


# Brightness now (vertex alpha): full when fired, fading linearly to 0.
func get_brightness() -> float:
	return Constants.LASER_BEAM_BRIGHTNESS * clamp(1.0 - _age / Constants.LASER_BEAM_DURATION, 0.0, 1.0)


func get_end_points() -> Array:
	return [_from.global_transform.origin, _to.to_global(_to_local)]


func _redraw() -> void:
	var ends: Array = get_end_points()
	clear()
	begin(Mesh.PRIMITIVE_LINES)
	set_color(Color(_color.r, _color.g, _color.b, get_brightness()))
	add_vertex(ends[0])
	add_vertex(ends[1])
	end()
