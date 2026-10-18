# WreckExplosionEffect (scenes/prefabs/effects/wreck_explosion.tscn): the moment a ship is destroyed.
# A short, bright flash with hot fragments, then a slowly expanding cloud of gas and dust that cools
# from orange to grey and thins out. The cloud centre starts with the ship's velocity and slows
# under Constants.EXPLOSION_DRAG, a little faster than the wreck, so it settles around it.
# The scene is authored for a ship of Constants.EXPLOSION_REFERENCE_RADIUS and scaled to the ship's apparent radius.
# Add it to the zone (not to the wreck) and set its global position.

extends Spatial

var velocity: Vector3 = Vector3.ZERO  # The ship's velocity when it blew up
var radius: float = Constants.EXPLOSION_REFERENCE_RADIUS  # The ship's apparent radius

var _age := 0.0
var _base_energy := 0.0
var _flash_material: ShaderMaterial = null

onready var _light: OmniLight = $Light
onready var _flash: MeshInstance = $Flash
onready var _cloud: CPUParticles = $Cloud
onready var _fragments: CPUParticles = $Fragments


func _ready() -> void:
	var size_scale: float = radius / Constants.EXPLOSION_REFERENCE_RADIUS
	scale = Vector3.ONE * size_scale
	_light.omni_range *= size_scale
	_base_energy = _light.light_energy
	_flash_material = _flash.material_override.duplicate()
	_flash.material_override = _flash_material
	_cloud.emitting = true
	_fragments.emitting = true


func _process(delta: float) -> void:
	_age += delta
	velocity *= exp(-Constants.EXPLOSION_DRAG * delta)
	global_transform.origin += velocity * delta
	var flash: float = clamp(1.0 - _age / Constants.EXPLOSION_FLASH_DURATION, 0.0, 1.0)
	_light.light_energy = _base_energy * flash * flash
	_flash.visible = flash > 0.0
	_flash_material.set_shader_param("intensity", flash)
	if _age >= Constants.EXPLOSION_LIFETIME:
		queue_free()
