# HullSmoulder (scenes/prefabs/effects/hull_smoulder.tscn): where hits landed, the hull smoulders
# a while. For the first moments bright sparks spit out; then glowing flakes peel off, like burning
# paper, until the spot goes out. Both are left in space (world coordinates), so a damaged ship that
# manoeuvres trails a few ship lengths of embers. A hit near a spot reheats it (reheat()) instead of
# adding another. Only spots on ships shown in detail (their view band), and only a few at once, emit
# (Constants.SMOULDER_*).
# Looks are authored in the scene and its materials; this script times, scales and aims them.
# Parent it to the ship body, set `outward` (world) and `heat`, then set its global position.

extends Spatial

const ViewDetail = preload("res://src/core/agents/components/view_detail.gd")


var outward: Vector3 = Vector3.UP  # World direction the embers leave the hull, at spawn
var heat: float = 1.0  # Hit intensity put into the spot (LaserHitEffect.intensity_for_damage)
var size_scale: float = 1.0
var duration_factor: float = 1.0  # Wrecks smoulder longer (Constants.SMOULDER_WRECK_FACTOR)

var _age := 0.0
var _check_timer := 0.0
var _ember_velocity := 0.0
var _ember_material: ShaderMaterial = null

onready var _sparks: CPUParticles = $Sparks
onready var _embers: CPUParticles = $Embers


func _ready() -> void:
	add_to_group("hull_smoulder")
	scale = Vector3.ONE * size_scale
	var direction: Vector3 = global_transform.basis.xform_inv(outward).normalized()
	_sparks.direction = direction
	_embers.direction = direction
	_ember_velocity = _embers.initial_velocity
	_ember_material = _embers.material_override.duplicate()
	_embers.material_override = _ember_material


# Seconds the spot keeps smouldering after its last hit.
func get_duration() -> float:
	return Constants.SMOULDER_DURATION * min(heat, Constants.SMOULDER_MAX_HEAT) * duration_factor


# Another hit near the spot: hotter, and the clock starts again.
func reheat(amount: float) -> void:
	heat = min(heat + amount, Constants.SMOULDER_MAX_HEAT)
	_age = 0.0


func is_shown() -> bool:
	return is_in_group("hull_smoulder_shown")


# Emits only while its ship's view band is within Constants.SMOULDER_MAX_BAND, and while few other spots do.
func _update_shown() -> void:
	var camera = get_viewport().get_camera()
	var near: bool = camera != null and ViewDetail.band_of_host(self) <= Constants.SMOULDER_MAX_BAND  # Its ship's band
	if near and not is_shown() and get_tree().get_nodes_in_group("hull_smoulder_shown").size() < Constants.SMOULDER_MAX_SHOWN:
		add_to_group("hull_smoulder_shown")
	elif not near and is_shown():
		remove_from_group("hull_smoulder_shown")


func _process(delta: float) -> void:
	_age += delta
	var duration: float = get_duration()
	if _age >= duration + _embers.lifetime:
		queue_free()
		return
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = Constants.SMOULDER_CHECK_INTERVAL
		_update_shown()
	var glow: float = clamp(1.0 - _age / duration, 0.0, 1.0)
	_sparks.emitting = is_shown() and _age < Constants.SMOULDER_SPARK_TIME
	_embers.emitting = is_shown() and glow > 0.0
	_embers.initial_velocity = _ember_velocity * (0.4 + 0.6 * glow)
	_ember_material.set_shader_param("intensity", 0.3 + 0.7 * glow)
