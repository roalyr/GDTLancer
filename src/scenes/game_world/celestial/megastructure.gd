# Megastructure: a cluster of remnants left by successive builders (Constants MEGASTRUCTURE_LAYERS),
# each layer in its own material: a few vast ancient forms in the middle, old structures built into
# them, and recent debris strewn round them. Built from `seed_value` on load, the same every time.
# Every piece is an Asteroid (solid, an obstacle, seen by its size); the debris is mined for relics
# like rocks for ore (laser, lance, harpoon). Plain primitives for now, to judge scale by eye.

extends Spatial

const AsteroidScene = preload("res://scenes/prefabs/celestial/asteroid.tscn")

export var seed_value: int = 1
export var magnitude: float = 1.0  # Scales every piece and distance


func _ready() -> void:
	add_to_group("megastructure")  # A place to go to (DebugTools)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var core_size := 0.0
	for layer in Constants.MEGASTRUCTURE_LAYERS:
		var material: Material = load(layer.material)
		var count: int = rng.randi_range(int(layer.count[0]), int(layer.count[1]))
		for index in range(count):
			var size: float = rng.randf_range(float(layer.size[0]), float(layer.size[1])) * magnitude
			if core_size <= 0.0:
				core_size = size
			var distance: float = core_size * rng.randf_range(float(layer.spread[0]), float(layer.spread[1]))
			var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)).normalized()
			add_child(_piece(layer, material, size, direction * distance, rng))


func _piece(layer: Dictionary, material: Material, size: float, position: Vector3, rng: RandomNumberGenerator) -> StaticBody:
	var piece = AsteroidScene.instance()
	piece.model = null
	piece.surface = material
	piece.display_name = layer.name
	piece.mineable = bool(layer.mineable)
	if piece.mineable:
		piece.deposit_id = str(layer.deposit_id)
		piece.deposit = int(max(1.0, round(size * 0.5 * float(layer.deposit_per_metre))))
	var mesh_instance := MeshInstance.new()
	mesh_instance.mesh = _mesh(Constants.MEGASTRUCTURE_SHAPES[rng.randi() % Constants.MEGASTRUCTURE_SHAPES.size()], size, rng)
	piece.get_node("Model").add_child(mesh_instance)
	piece.transform = Transform(Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU), position)
	return piece


# A primitive `size` m along its longest side, the others a random share of it.
static func _mesh(shape: String, size: float, rng: RandomNumberGenerator) -> Mesh:
	var a: float = size * rng.randf_range(0.2, 1.0)
	var b: float = size * rng.randf_range(0.2, 1.0)
	match shape:
		"box":
			var box := CubeMesh.new()
			box.size = Vector3(a, b, size)
			return box
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = a * 0.5
			cylinder.bottom_radius = a * 0.5 * rng.randf_range(0.5, 1.0)
			cylinder.height = size
			cylinder.radial_segments = 24
			cylinder.rings = 1
			return cylinder
		"prism":
			var prism := PrismMesh.new()
			prism.size = Vector3(a, size, b)
			return prism
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = a * 0.25
			capsule.mid_height = size - a * 0.5
			capsule.radial_segments = 24
			capsule.rings = 6
			return capsule
	var sphere := SphereMesh.new()
	sphere.radius = size * 0.5
	sphere.height = size
	sphere.radial_segments = 24
	sphere.rings = 12
	return sphere
