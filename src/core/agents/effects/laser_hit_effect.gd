# LaserHitEffect: what a laser hit looks like in vacuum. The beam itself is invisible, so only
# the hit point shows: a brief flash of light and a puff of vaporized hull material.
# Parent it to the target body so it moves with the hull, then set global position.

extends Spatial

var intensity: float = 1.0  # Hit quality, 0..1; scales the flash and the amount of vapour.
var size_scale: float = 1.0  # Grows the effect with the target's size so large hulls show a visible hit.
var outward: Vector3 = Vector3.UP  # World direction the vapour plume leaves the hull (toward the shooter).

const FLASH_DURATION = 0.15
const LIFETIME = 2.0
const FLASH_ENERGY = 6.0
const FLASH_RANGE = 40.0
const FLASH_COLOR = Color(1.0, 0.85, 0.65)
const VAPOR_AMOUNT = 24
const VAPOR_SIZE = 2.5  # Metres.

var _light: OmniLight = null
var _glow: MeshInstance = null
var _age: float = 0.0


func _ready() -> void:
	_light = OmniLight.new()
	_light.light_color = FLASH_COLOR
	_light.omni_range = FLASH_RANGE * size_scale
	_light.light_energy = FLASH_ENERGY * intensity
	add_child(_light)

	_glow = MeshInstance.new()
	var glow_mesh = QuadMesh.new()
	glow_mesh.size = Vector2.ONE * VAPOR_SIZE * 2.0 * size_scale
	glow_mesh.material = _make_sprite_material(false)
	_glow.mesh = glow_mesh
	add_child(_glow)

	add_child(_make_vapor())


func _process(delta: float) -> void:
	_age += delta
	var flash: float = clamp(1.0 - _age / FLASH_DURATION, 0.0, 1.0)
	_light.light_energy = FLASH_ENERGY * intensity * flash
	_glow.visible = flash > 0.0
	_glow.scale = Vector3.ONE * (0.5 + intensity * flash)
	if _age >= LIFETIME:
		queue_free()


# Glowing then cooling, expanding and fading puffs that drift off the hull.
func _make_vapor() -> CPUParticles:
	var vapor = CPUParticles.new()
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE * VAPOR_SIZE * size_scale
	mesh.material = _make_sprite_material(true)
	vapor.mesh = mesh
	vapor.one_shot = true
	vapor.explosiveness = 0.85
	vapor.amount = int(max(4.0, VAPOR_AMOUNT * intensity))
	vapor.lifetime = LIFETIME * 0.8
	vapor.direction = global_transform.basis.xform_inv(outward).normalized()
	vapor.spread = 70.0
	vapor.gravity = Vector3.ZERO
	vapor.initial_velocity = 12.0 * size_scale
	vapor.initial_velocity_random = 0.7
	vapor.damping = 6.0 * size_scale
	vapor.scale_amount = 0.4
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


func _make_sprite_material(use_vertex_color: bool) -> SpatialMaterial:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material = SpatialMaterial.new()
	material.flags_transparent = true
	material.flags_unshaded = true
	material.albedo_texture = texture
	if use_vertex_color:
		material.vertex_color_use_as_albedo = true
		material.params_billboard_mode = SpatialMaterial.BILLBOARD_PARTICLES
	else:
		material.albedo_color = FLASH_COLOR
		material.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
		material.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	return material
