# FuelLeakEffect (scenes/prefabs/effects/fuel_leak.tscn): a punctured line venting gas from the
# hull where a hit landed. A thin jet of pale gas that weakens until the line has bled out.
# Looks are authored in the scene and its material; this script scales, aims and fades them.
# Parent it to the ship body (it rides along with the hull), set `outward` in world space, then
# set its global position. Placement comes from hit points, so ships need no hardpoints.

extends Spatial


var outward: Vector3 = Vector3.UP  # World direction the jet leaves the hull
var size_scale: float = 1.0

var _age := 0.0
var _base_velocity := 0.0
var _material: ShaderMaterial = null

onready var _jet: CPUParticles = $Jet


func _ready() -> void:
	scale = Vector3.ONE * size_scale
	_material = _jet.material_override.duplicate()
	_jet.material_override = _material
	_base_velocity = _jet.initial_velocity
	_jet.direction = global_transform.basis.xform_inv(outward).normalized()
	_jet.emitting = true


# 1 when fresh, 0 when bled out.
func get_pressure() -> float:
	return clamp(1.0 - _age / Constants.FUEL_LEAK_DURATION, 0.0, 1.0)


func _process(delta: float) -> void:
	_age += delta
	var pressure: float = get_pressure()
	_material.set_shader_param("intensity", pressure)
	_jet.initial_velocity = _base_velocity * (0.3 + 0.7 * pressure)
	if pressure <= 0.0:
		_jet.emitting = false
	if _age >= Constants.FUEL_LEAK_DURATION + _jet.lifetime:
		queue_free()
