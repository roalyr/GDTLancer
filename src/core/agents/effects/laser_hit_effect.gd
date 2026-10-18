# LaserHitEffect: what a laser hit looks like in vacuum. The beam itself is invisible, so only
# the hit point shows: a brief flash of light and a puff of vaporized hull material.
# Brightness and amount follow the damage dealt, so hits can be judged by eye; no damage shows nothing.
# Parent it to the target body so it moves with the hull, then set global position.

extends Spatial

const FlashShader = preload("res://assets/art/shaders/hit_flash.gdshader")
const VaporShader = preload("res://assets/art/shaders/hit_vapor.gdshader")

const FULL_INTENSITY_DAMAGE = 6.0  # Damage of a full-strength hit; bigger hits flash brighter, up to MAX_INTENSITY.
const MAX_INTENSITY = 2.0
const FLASH_DURATION = 0.15
const LIFETIME = 2.0
const FLASH_ENERGY = 6.0
const FLASH_RANGE = 40.0
const FLASH_COLOR = Color(1.0, 0.85, 0.65)
const VAPOR_AMOUNT = 24
const VAPOR_SIZE = 2.5  # Metres.
const FLASH_MIN_SCREEN_HEIGHT = 0.02  # The flash stays readable at any range; vapour uses the shader default.

var damage: float = 0.0
var size_scale: float = 1.0  # Grows the effect with the target's size so large hulls show a visible hit.
var outward: Vector3 = Vector3.UP  # World direction the vapour plume leaves the hull (toward the shooter).

var _intensity: float = 0.0
var _light: OmniLight = null
var _glow: MeshInstance = null
var _glow_material: ShaderMaterial = null
var _age: float = 0.0


# Square root so brightness reads roughly proportional to damage: a quarter-damage hit shows at half strength.
static func intensity_for_damage(amount: float) -> float:
	return clamp(sqrt(max(amount, 0.0) / FULL_INTENSITY_DAMAGE), 0.0, MAX_INTENSITY)


func _ready() -> void:
	_intensity = intensity_for_damage(damage)
	if _intensity <= 0.0:
		set_process(false)
		queue_free()
		return

	_light = OmniLight.new()
	_light.light_color = FLASH_COLOR
	_light.omni_range = FLASH_RANGE * size_scale
	_light.light_energy = FLASH_ENERGY * _intensity
	add_child(_light)

	_glow_material = ShaderMaterial.new()
	_glow_material.shader = FlashShader
	_glow_material.set_shader_param("tint", FLASH_COLOR)
	_glow_material.set_shader_param("min_screen_height", FLASH_MIN_SCREEN_HEIGHT)
	_glow_material.set_shader_param("intensity", min(_intensity, 1.0))
	var glow_mesh = QuadMesh.new()
	glow_mesh.size = Vector2.ONE * VAPOR_SIZE * 2.0 * size_scale * (0.5 + 0.5 * _intensity)
	glow_mesh.material = _glow_material
	_glow = MeshInstance.new()
	_glow.mesh = glow_mesh
	add_child(_glow)

	add_child(_make_vapor())


func _process(delta: float) -> void:
	_age += delta
	var flash: float = clamp(1.0 - _age / FLASH_DURATION, 0.0, 1.0)
	_light.light_energy = FLASH_ENERGY * _intensity * flash
	_glow.visible = flash > 0.0
	_glow_material.set_shader_param("intensity", min(_intensity, 1.0) * flash)
	if _age >= LIFETIME:
		queue_free()


# Glowing then cooling, expanding and fading puffs that drift off the hull.
func _make_vapor() -> CPUParticles:
	var material = ShaderMaterial.new()
	material.shader = VaporShader
	material.set_shader_param("intensity", min(_intensity, 1.0))
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE * VAPOR_SIZE * size_scale
	mesh.material = material

	var vapor = CPUParticles.new()
	vapor.mesh = mesh
	vapor.one_shot = true
	vapor.explosiveness = 0.85
	vapor.amount = int(max(2.0, VAPOR_AMOUNT * min(_intensity, 1.0)))
	vapor.lifetime = LIFETIME * 0.8
	vapor.direction = global_transform.basis.xform_inv(outward).normalized()
	vapor.spread = 70.0
	vapor.gravity = Vector3.ZERO
	vapor.initial_velocity = 12.0 * size_scale
	vapor.initial_velocity_random = 0.7
	vapor.damping = 6.0 * size_scale
	vapor.scale_amount = 0.4 * (0.5 + 0.5 * _intensity)
	vapor.scale_amount_random = 0.5
	var growth = Curve.new()
	growth.add_point(Vector2(0.0, 0.3))
	growth.add_point(Vector2(1.0, 1.0))
	vapor.scale_amount_curve = growth
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.7, 1.0))  # Incandescent
	ramp.set_color(1, Color(0.35, 0.33, 0.32, 0.0))  # Cooled dust, faded
	ramp.add_point(0.15, Color(1.0, 0.45, 0.15, 0.9))
	ramp.add_point(0.4, Color(0.5, 0.45, 0.42, 0.5))
	vapor.color_ramp = ramp
	vapor.emitting = true
	return vapor
