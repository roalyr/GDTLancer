# LaserHitEffect (scenes/prefabs/effects/laser_hit.tscn): what a laser hit looks like in vacuum.
# The beam itself is invisible, so only the hit point shows: a brief glowing flash and a puff of
# vaporized hull material. The flash also lights its surroundings, but only near the camera and only
# a few at a time (Constants.HIT_FX_LIGHT_*): GLES2 draws every lit object once more per light. Size, brightness and amount follow the damage dealt (never the size of
# what was hit), so hits can be judged by eye; no damage shows nothing. Looks are authored in the scene and its materials; this script only
# scales, fades and aims them. Parent it to the target body, then set its global position.

extends Spatial


var damage: float = 0.0
var outward: Vector3 = Vector3.UP  # World direction the vapour plume leaves the hull (toward the shooter).

var _intensity: float = 0.0
var _age := 0.0
var _glow_material: ShaderMaterial = null
var _base_energy := 0.0
var _light: OmniLight = null

onready var _glow: MeshInstance = $Glow
onready var _vapor: CPUParticles = $Vapor


# Square root of absolute damage, so brightness reads roughly proportional to the energy delivered:
# a quarter of the reference damage shows at half strength, four times it at double.
static func intensity_for_damage(amount: float) -> float:
	return clamp(sqrt(max(amount, 0.0) / Constants.HIT_FX_REFERENCE_DAMAGE), 0.0, Constants.HIT_FX_MAX_INTENSITY)


func _ready() -> void:
	_intensity = intensity_for_damage(damage)
	if _intensity <= 0.0:
		set_process(false)
		queue_free()
		return
	# Hotter beams flash whiter: orange-red for weak hits, white for powerful ones.
	var flash_color: Color = Constants.HIT_FX_COOL_COLOR.linear_interpolate(
		Constants.HIT_FX_HOT_COLOR, clamp(_intensity / Constants.HIT_FX_HOT_INTENSITY, 0.0, 1.0)
	)
	_light = $Light
	_light.visible = false  # Decided once placed (_start_vapor)
	_light.light_color = flash_color
	_glow_material = _glow.material_override.duplicate()
	_glow_material.set_shader_param("tint", flash_color)
	_glow.material_override = _glow_material
	_glow.scale = Vector3.ONE * (0.5 + 0.5 * _intensity)

	# More vapour, bigger puffs and a faster jet as the beam gets stronger.
	var vapor_material: ShaderMaterial = _vapor.material_override.duplicate()
	vapor_material.set_shader_param("intensity", min(_intensity, 1.0))
	_vapor.material_override = vapor_material
	_vapor.amount = int(max(2.0, _vapor.amount * _intensity))
	_vapor.scale_amount *= 0.5 + 0.5 * _intensity
	_vapor.initial_velocity *= sqrt(_intensity)
	call_deferred("_start_vapor")  # After the spawner has placed the effect


# A hit lights its surroundings only near the camera and while few other hits do.
func should_light(point: Vector3) -> bool:
	var camera = get_viewport().get_camera() if is_inside_tree() else null
	if camera == null or camera.global_transform.origin.distance_to(point) > Constants.HIT_FX_LIGHT_DISTANCE:
		return false
	return get_tree().get_nodes_in_group("hit_fx_light").size() < Constants.HIT_FX_MAX_LIGHTS


func _start_vapor() -> void:
	if should_light(global_transform.origin):
		_light.add_to_group("hit_fx_light")
		# Lifted off the contact point toward the shooter: hits land on the collision hull, and the
		# full-detail mesh can bulge out past it (rocks most of all), which would bury the light.
		_light.global_transform.origin = global_transform.origin + outward.normalized() * Constants.HIT_FX_LIGHT_LIFT
		_base_energy = _light.light_energy
		_light.light_energy = _base_energy * _intensity
		_light.visible = true
	else:
		_light.queue_free()
		_light = null
	_vapor.direction = global_transform.basis.xform_inv(outward).normalized()
	_vapor.emitting = true


func _process(delta: float) -> void:
	_age += delta
	var flash: float = clamp(1.0 - _age / Constants.HIT_FX_FLASH_DURATION, 0.0, 1.0)
	if _light != null and _light.visible:
		_light.light_energy = _base_energy * _intensity * flash
	_glow.visible = flash > 0.0
	_glow_material.set_shader_param("intensity", min(_intensity, 1.0) * flash)
	if _age >= Constants.HIT_FX_LIFETIME:
		queue_free()
