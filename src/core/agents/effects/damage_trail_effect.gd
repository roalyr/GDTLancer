# DamageTrail (scenes/prefabs/effects/damage_trail.tscn): lasting damage. A badly hurt hull keeps
# shedding a few slow embers from where it was hit, left in space as a sparse trail, until the
# hull is repaired. Ships carry more of them the more hull they have lost (Agent, see
# Constants.DAMAGE_TRAIL_*); `strength` (0..1, the share of hull lost) sets how bright they are.
# Only trails near the camera, and only a few at once, emit.
# Parent it to the ship body, set `outward` (world) and `size_scale`, then set its global position.

extends Spatial


var outward: Vector3 = Vector3.UP
var size_scale: float = 1.0
var strength: float = 1.0 setget set_strength

var _check_timer := 0.0
var _material: ShaderMaterial = null

onready var _embers: CPUParticles = $Embers


func _ready() -> void:
	scale = Vector3.ONE * size_scale
	_embers.direction = global_transform.basis.xform_inv(outward).normalized()
	_material = _embers.material_override.duplicate()
	_embers.material_override = _material
	set_strength(strength)


func set_strength(value: float) -> void:
	strength = clamp(value, 0.0, 1.0)
	if _material != null:
		_material.set_shader_param("intensity", 0.5 + 0.5 * strength)


func is_shown() -> bool:
	return is_in_group("damage_trail_shown")


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = Constants.SMOULDER_CHECK_INTERVAL
	var camera = get_viewport().get_camera()
	var near: bool = camera != null and camera.global_transform.origin.distance_to(global_transform.origin) <= Constants.DAMAGE_TRAIL_VISIBLE_DISTANCE
	if near and not is_shown() and get_tree().get_nodes_in_group("damage_trail_shown").size() < Constants.DAMAGE_TRAIL_MAX_SHOWN:
		add_to_group("damage_trail_shown")
	elif not near and is_shown():
		remove_from_group("damage_trail_shown")
	_embers.emitting = is_shown()
