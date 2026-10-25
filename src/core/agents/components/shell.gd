# Shell: a cannon round, a Projectile that keeps the velocity it left the muzzle with (the ship's
# own plus the muzzle speed along its nose): no guidance, so the gunner leads the target. A hot
# streak to see it by; a hit flashes as a laser's does.

extends "res://src/core/agents/components/projectile.gd"

const LaserHitScene = preload("res://scenes/prefabs/effects/laser_hit.tscn")

var size: float = 1.0  # Streak scale: 1 for a reference round


func _ready() -> void:
	var streak := MeshInstance.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = Constants.SHELL_MODEL_RADIUS
	mesh.bottom_radius = Constants.SHELL_MODEL_RADIUS * 0.3
	mesh.height = Constants.SHELL_MODEL_LENGTH
	mesh.radial_segments = 6
	mesh.rings = 1
	var material := SpatialMaterial.new()
	material.flags_unshaded = true
	material.albedo_color = Constants.SHELL_COLOR
	mesh.material = material
	streak.mesh = mesh
	streak.rotation_degrees = Vector3(-90, 0, 0)
	streak.scale = Vector3(size, 1.0, size)
	add_child(streak)


func _burst_effect(body) -> void:
	if body == null or not body.is_inside_tree() or damage <= 0.0:
		return
	var effect = LaserHitScene.instance()
	effect.damage = damage
	effect.outward = -velocity.normalized()
	body.add_child(effect)
	effect.global_transform = Transform(Basis(), global_transform.origin)
