# LaserHitEffect (scenes/prefabs/effects/laser_hit.tscn): what a laser hit looks like in vacuum.
# The beam itself is invisible, so only the hit point shows: a brief flash of light and a puff of
# vaporized hull material. Brightness and amount follow the damage dealt, so hits can be judged by
# eye; no damage shows nothing. Looks are authored in the scene and its materials; this script only
# scales, fades and aims them. Parent it to the target body, then set its global position.

extends Spatial


var damage: float = 0.0
var full_damage: float = 6.0  # The firing tool's preset damage: a full-quality hit shows at intensity 1.
var size_scale: float = 1.0  # Grows the effect with the target's size so large hulls show a visible hit.
var outward: Vector3 = Vector3.UP  # World direction the vapour plume leaves the hull (toward the shooter).

var _intensity: float = 0.0
var _age := 0.0
var _base_energy := 0.0
var _glow_material: ShaderMaterial = null

onready var _light: OmniLight = $Light
onready var _glow: MeshInstance = $Glow
onready var _vapor: CPUParticles = $Vapor


# Square root so brightness reads roughly proportional to damage: a quarter-damage hit shows at half strength.
static func intensity_for_damage(amount: float, full: float) -> float:
	if full <= 0.0:
		return 0.0
	return clamp(sqrt(max(amount, 0.0) / full), 0.0, Constants.HIT_FX_MAX_INTENSITY)


func _ready() -> void:
	_intensity = intensity_for_damage(damage, full_damage)
	if _intensity <= 0.0:
		set_process(false)
		queue_free()
		return
	scale = Vector3.ONE * size_scale
	_base_energy = _light.light_energy
	_light.omni_range *= size_scale
	_light.light_energy = _base_energy * _intensity
	_glow_material = _glow.material_override.duplicate()
	_glow.material_override = _glow_material
	_glow.scale = Vector3.ONE * (0.5 + 0.5 * _intensity)

	var vapor_material: ShaderMaterial = _vapor.material_override.duplicate()
	vapor_material.set_shader_param("intensity", min(_intensity, 1.0))
	_vapor.material_override = vapor_material
	_vapor.amount = int(max(2.0, _vapor.amount * min(_intensity, 1.0)))
	_vapor.scale_amount *= 0.5 + 0.5 * _intensity
	_vapor.direction = global_transform.basis.xform_inv(outward).normalized()
	_vapor.emitting = true


func _process(delta: float) -> void:
	_age += delta
	var flash: float = clamp(1.0 - _age / Constants.HIT_FX_FLASH_DURATION, 0.0, 1.0)
	_light.light_energy = _base_energy * _intensity * flash
	_glow.visible = flash > 0.0
	_glow_material.set_shader_param("intensity", min(_intensity, 1.0) * flash)
	if _age >= Constants.HIT_FX_LIFETIME:
		queue_free()
