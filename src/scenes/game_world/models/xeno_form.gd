# XenoForm: the xenohive's look, primitives lumped round one axis. A spindle of two cones along Z
# (nose to -Z) with a glowing core, rings of petals and spikes set round it at an odd count
# (Constants XENO_FORMS), each leaning off the axis and twisted about its own, so nothing meets at a
# right angle. The same `seed_value` builds the same form. Ships (xenohive_vessel.gd) and the hive
# (Arena) share it at their own sizes.

extends Reference

const BodyMaterial = preload("res://assets/art/materials_generic/mat_hull_faction_xenohive.tres")
const GlowMaterial = preload("res://assets/art/materials_generic/mat_hull_glow.tres")


# A Spatial of MeshInstances, `length` m nose to tail, built from `form` (a Constants XENO_FORMS entry).
static func build(form: Dictionary, length: float, seed_value: int) -> Spatial:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var root := Spatial.new()
	root.name = "XenoForm"
	var radius: float = length * float(form.girth)
	root.add_child(_part(_cone(radius, length * 0.55), BodyMaterial, Vector3.FORWARD, Vector3(0, 0, -length * 0.275), 0.0))
	root.add_child(_part(_cone(radius * 0.8, length * 0.45), BodyMaterial, Vector3.BACK, Vector3(0, 0, length * 0.225), 0.0))
	root.add_child(_part(_sphere(radius * 0.95, radius * 1.4), GlowMaterial, Vector3.FORWARD, Vector3(0, 0, -length * 0.06), 0.0))
	var phase := 0.0
	for ring in form.rings:
		var count: int = int(ring.count)
		var lean: float = deg2rad(float(ring.lean) + rng.randf_range(-6.0, 6.0))
		var twist: float = deg2rad(float(ring.twist) + rng.randf_range(-8.0, 8.0))
		var size: float = length * float(ring.size)
		var at_z: float = length * float(ring.z)
		var out: float = length * float(ring.out)
		phase += PI / count + rng.randf_range(0.0, 0.4)
		for index in range(count):
			var angle: float = phase + TAU * index / count
			var radial := Vector3(cos(angle), sin(angle), 0.0)
			var axis: Vector3 = (radial * sin(lean) + Vector3.BACK * cos(lean)).normalized()
			var mesh: Mesh
			match str(ring.shape):
				"petal":
					mesh = _sphere(size * 0.18, size)
				"spike":
					mesh = _cone(size * 0.12, size)
				_:
					mesh = _sphere(size * 0.5, size)  # "cell": a round bulb
			var material: Material = GlowMaterial if str(ring.shape) == "cell" else BodyMaterial
			root.add_child(_part(mesh, material, axis, radial * out + Vector3(0, 0, at_z) + axis * size * 0.4, twist))
	return root


# A mesh placed with its Y axis along `axis`, turned `twist` about it.
static func _part(mesh: Mesh, material: Material, axis: Vector3, position: Vector3, twist: float) -> MeshInstance:
	var y: Vector3 = axis.normalized()
	var helper: Vector3 = Vector3.RIGHT if abs(y.x) < 0.9 else Vector3.UP
	var x: Vector3 = helper.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	var part := MeshInstance.new()
	part.mesh = mesh
	part.material_override = material
	part.transform = Transform(Basis(y, twist) * Basis(x, y, z), position)
	return part


# A cone `height` m along Y, tip up.
static func _cone(radius: float, height: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 7
	cone.rings = 1
	return cone


static func _sphere(radius: float, height: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = 9
	sphere.rings = 5
	return sphere
