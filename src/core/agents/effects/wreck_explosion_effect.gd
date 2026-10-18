# WreckExplosionEffect (scenes/prefabs/effects/wreck_explosion.tscn): the moment a ship is destroyed.
# A short, bright flash with hot fragments, then a slowly expanding cloud of gas and dust that cools
# from orange to grey and thins out. The cloud keeps the ship's momentum at the moment of
# destruction (nothing slows it in vacuum), so it drifts apart from the wreck, which obeys ship drag.
# The scene is authored for a ship of REFERENCE_RADIUS and scaled to the ship's apparent radius.
# Add it to the zone (not to the wreck) and set its global position.

extends Spatial

const REFERENCE_RADIUS = 12.0  # Apparent radius the scene is authored for
const LIFETIME = 26.0
const FLASH_DURATION = 0.6

var velocity: Vector3 = Vector3.ZERO  # The ship's velocity when it blew up
var radius: float = REFERENCE_RADIUS  # The ship's apparent radius

var _age := 0.0
var _base_energy := 0.0
var _flash_material: ShaderMaterial = null

onready var _light: OmniLight = $Light
onready var _flash: MeshInstance = $Flash
onready var _cloud: CPUParticles = $Cloud
onready var _fragments: CPUParticles = $Fragments


func _ready() -> void:
	var size_scale: float = radius / REFERENCE_RADIUS
	scale = Vector3.ONE * size_scale
	_light.omni_range *= size_scale
	_base_energy = _light.light_energy
	_flash_material = _flash.material_override.duplicate()
	_flash.material_override = _flash_material
	_cloud.emitting = true
	_fragments.emitting = true


func _process(delta: float) -> void:
	_age += delta
	global_transform.origin += velocity * delta
	var flash: float = clamp(1.0 - _age / FLASH_DURATION, 0.0, 1.0)
	_light.light_energy = _base_energy * flash * flash
	_flash.visible = flash > 0.0
	_flash_material.set_shader_param("intensity", flash)
	if _age >= LIFETIME:
		queue_free()
