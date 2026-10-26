# Decoy: a flare a decoy launcher throws out against a missile coming in (Agent._launch_decoys). It
# drifts off with the ship's velocity plus DECOY_EJECT_SPEED sideways and burns for DECOY_LIFETIME s;
# a missile it took off chases it (it reads linear_velocity and is_wreck as from a ship) and bursts on
# it (Missile). Burnt out, it is gone, and a missile still after it flies on blind.

extends Spatial

const GROUP = "decoy"

var linear_velocity: Vector3 = Vector3.ZERO
var is_wreck: bool = false
var age: float = 0.0


func launch(holder: Node, position: Vector3, velocity: Vector3) -> void:
	linear_velocity = velocity
	holder.add_child(self)
	global_transform.origin = position


func _ready() -> void:
	add_to_group(GROUP)
	var flare := MeshInstance.new()
	var mesh := SphereMesh.new()
	mesh.radius = Constants.DECOY_MODEL_RADIUS
	mesh.height = Constants.DECOY_MODEL_RADIUS * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := SpatialMaterial.new()
	material.flags_unshaded = true
	material.albedo_color = Constants.DECOY_COLOR
	mesh.material = material
	flare.mesh = mesh
	add_child(flare)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= Constants.DECOY_LIFETIME:
		queue_free()
		return
	global_transform.origin += linear_velocity * delta
	scale = Vector3.ONE * (1.0 - 0.6 * age / Constants.DECOY_LIFETIME)  # Burning down
