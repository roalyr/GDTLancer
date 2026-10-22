# WreckExplosionEffect (scenes/prefabs/effects/wreck_explosion.tscn): the moment a ship is destroyed.
# A short, bright flash with hot fragments, then two billowing fireballs (the spheroid model with
# explosion_cloud.gdshader via explosion_puff_material) that swell, burn out to grey smoke and thin
# away. The cloud centre starts with the ship's
# velocity and slows under Constants.EXPLOSION_DRAG, a little faster than the wreck, so it
# settles around it.
# The scene is authored for a ship of Constants.EXPLOSION_REFERENCE_RADIUS and scaled to the ship's apparent radius.
# Add it to the zone (not to the wreck) and set its global position.

extends Spatial

var velocity: Vector3 = Vector3.ZERO  # The ship's velocity when it blew up
var radius: float = Constants.EXPLOSION_REFERENCE_RADIUS  # The ship's apparent radius

var _age := 0.0
var _base_energy := 0.0
var _flash_material: ShaderMaterial = null
var _puffs: Array = []  # [puff root, its material, drift direction, size factor, heat factor]

const PuffMaterial = preload("res://assets/art/effects/explosion_puff_material.tres")

onready var _light: OmniLight = $Light  # Freed if Constants.EXPLOSION_MAX_LIGHTS explosions light already
onready var _flash: MeshInstance = $Flash
onready var _puff_root: Spatial = $Puffs
onready var _fragments: CPUParticles = $Fragments


func _ready() -> void:
	var size_scale: float = radius / Constants.EXPLOSION_REFERENCE_RADIUS
	scale = Vector3.ONE * size_scale
	if get_tree().get_nodes_in_group("explosion_light").size() < Constants.EXPLOSION_MAX_LIGHTS:
		_light.add_to_group("explosion_light")
		_light.omni_range *= size_scale
		_base_energy = _light.light_energy
	else:
		_light.queue_free()
		_light = null
	_flash_material = _flash.material_override.duplicate()
	_flash.material_override = _flash_material
	for puff in _puff_root.get_children():
		var material: ShaderMaterial = PuffMaterial.duplicate()
		for node in [puff] + puff.get_children():
			if node is MeshInstance:
				node.material_override = material
		material.set_shader_param("seed", rand_range(0.0, 100.0))
		puff.rotation = Vector3(rand_range(-PI, PI), rand_range(-PI, PI), rand_range(-PI, PI))
		var drift := Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		_puffs.append([puff, material, drift, rand_range(0.8, 1.2), rand_range(0.75, 1.0)])
	_update_puffs()
	_fragments.emitting = true


func _process(delta: float) -> void:
	_age += delta
	velocity *= exp(-Constants.EXPLOSION_DRAG * delta)
	global_transform.origin += velocity * delta
	var flash: float = clamp(1.0 - _age / Constants.EXPLOSION_FLASH_DURATION, 0.0, 1.0)
	if _light != null:
		if flash <= 0.0:
			_light.remove_from_group("explosion_light")  # Done: let another explosion light
			_light.queue_free()
			_light = null
		else:
			_light.light_energy = _base_energy * flash * flash
	_flash.visible = flash > 0.0
	_flash_material.set_shader_param("intensity", flash)
	_update_puffs()
	if _age >= Constants.EXPLOSION_LIFETIME:
		queue_free()


# Each puff swells (fast at first, then slowly), burns out to smoke, then thins away.
func _update_puffs() -> void:
	var t: float = clamp(_age / Constants.EXPLOSION_LIFETIME, 0.0, 1.0)
	var grown: float = 1.0 - pow(1.0 - t, 4.0)  # Ease out: a fireball bursts, smoke drifts
	var cooling: float = clamp(1.0 - t / Constants.EXPLOSION_PUFF_COOL_SHARE, 0.0, 1.0)
	var opacity: float = Constants.EXPLOSION_PUFF_OPACITY * (1.0 - smoothstep(Constants.EXPLOSION_PUFF_FADE_START, 1.0, t))
	for puff in _puffs:
		var size: float = lerp(Constants.EXPLOSION_PUFF_START_SIZE, Constants.EXPLOSION_PUFF_END_SIZE, grown) * puff[3]
		puff[0].scale = Vector3.ONE * size
		puff[0].translation = puff[2] * Constants.EXPLOSION_PUFF_SPREAD * grown
		puff[1].set_shader_param("heat", cooling * puff[4])
		puff[1].set_shader_param("opacity", opacity)
		puff[0].visible = opacity >= Constants.EXPLOSION_PUFF_MIN_OPACITY

