# RockDust (scenes/prefabs/effects/rock_dust.tscn): rocks do not burn, so a hit on one leaves only
# a slow grey dust puff that hangs a few seconds. Only near the camera, and only a few at once
# (Constants.ROCK_DUST_*). Looks are authored in the scene and its material.
# Parent it to the rock, set `outward` (world), then its global transform (unscaled: rocks are scaled).

extends Spatial


var outward: Vector3 = Vector3.UP

onready var _dust: CPUParticles = $Dust


# Whether a puff at `point` would be seen and fits the budget.
static func is_wanted(tree: SceneTree, viewport: Viewport, point: Vector3) -> bool:
	var camera = viewport.get_camera()
	if camera == null or camera.global_transform.origin.distance_to(point) > Constants.ROCK_DUST_VISIBLE_DISTANCE:
		return false
	return tree.get_nodes_in_group("rock_dust").size() < Constants.ROCK_DUST_MAX


func _ready() -> void:
	add_to_group("rock_dust")
	call_deferred("_start")  # After the spawner has placed it


func _start() -> void:
	_dust.direction = global_transform.basis.xform_inv(outward).normalized()
	_dust.emitting = true
	get_tree().create_timer(_dust.lifetime + 0.5, false).connect("timeout", self, "queue_free")
