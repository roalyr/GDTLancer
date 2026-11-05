# PrimitiveForm: a placeholder model from primitives (boxes, cylinders, cones, spheres), built from
# a parts list in Constants (HULL_FORMS for ships, STATION_FORMS for havens) until real models land.
# Each part is a Dictionary:
#   shape  "box", "cylinder", "cone" (tip forward, -Z) or "sphere"; cylinders and cones lie along Z
#   size   Vector3, shares of the form's length (x wide, y high, z long)
#   at     Vector3, its centre, shares of the length (nose to -Z, top to +Y)
#   turn   Vector3, degrees about X, Y, Z (optional)
#   look   "paint" (takes the owner's colour: paint()), "metal" or "glow" (optional, default metal)
#   mirror true: a copy on the other side (x flipped)
#   around n: n copies round the Y axis
#   from   "medium" or "heavy": only on hulls of that weight class or heavier
# `girth` scales the form across (x and y), so weight classes share one silhouette.

tool
extends Reference

const PAINT_PREFIX = "Paint"  # Parts named so take the faction colour
const MATERIALS = {
	"paint": preload("res://assets/art/materials_generic/mat_hull_panel_offwhite.tres"),
	"metal": preload("res://assets/art/materials_generic/mat_hull_dark_metal.tres"),
	"glow": preload("res://assets/art/materials_generic/mat_hull_glow.tres"),
}
const WEIGHTS = ["light", "medium", "heavy"]

static func build(parts: Array, length: float, girth: float = 1.0, weight: String = "heavy") -> Spatial:
	var root := Spatial.new()
	root.name = "PrimitiveForm"
	var rank: int = WEIGHTS.find(weight)
	var count := 0
	for part in parts:
		if WEIGHTS.find(str(part.get("from", "light"))) > rank:
			continue
		var sides: Array = [false, true] if part.get("mirror", false) else [false]
		var around: int = int(part.get("around", 1))
		for index in range(around):
			var spin := Transform(Basis(Vector3.UP, TAU * index / around), Vector3.ZERO)
			for mirrored in sides:
				var piece := _piece(part, length, girth, mirrored)
				piece.transform = spin * piece.transform
				var look: String = str(part.get("look", "metal"))
				piece.name = "%s%d" % [PAINT_PREFIX if look == "paint" else look.capitalize(), count]
				count += 1
				root.add_child(piece)
	return root


# Gives every painted part of `root` the `material` (null: leaves them).
static func paint(root: Node, material: Material) -> void:
	if material == null:
		return
	var stack: Array = [root]
	while not stack.empty():
		var node: Node = stack.pop_back()
		stack += node.get_children()
		if node is MeshInstance and node.name.begins_with(PAINT_PREFIX):
			node.material_override = material


# The far corner of `root`'s parts from its origin, and their top, in root space: [radius, top].
static func extent(root: Spatial) -> Array:
	var radius := 0.0
	var top := 0.0
	for piece in root.get_children():
		if not piece is MeshInstance:
			continue
		var box: AABB = piece.transform.xform(piece.get_aabb())
		for index in range(8):
			var corner: Vector3 = box.get_endpoint(index)
			radius = max(radius, corner.length())
			top = max(top, corner.y)
	return [radius, top]


static func _piece(part: Dictionary, length: float, girth: float, mirrored: bool) -> MeshInstance:
	var across := Vector3(girth, girth, 1.0)
	var at: Vector3 = part.at * length * across
	var turn: Vector3 = part.get("turn", Vector3.ZERO)
	if mirrored:  # The other side's copy, turned the other way rather than flipped inside out
		at.x = -at.x
		turn = Vector3(turn.x, -turn.y, -turn.z)
	var basis := Basis(Vector3(deg2rad(turn.x), deg2rad(turn.y), deg2rad(turn.z))) * Basis().scaled(part.size * length * across)
	var shape: String = str(part.shape)
	if shape == "cylinder" or shape == "cone":
		basis = basis * Basis(Vector3.RIGHT, -PI / 2)  # Their meshes stand along Y: lay them along Z, tip forward
	var piece := MeshInstance.new()
	piece.mesh = _mesh(shape)
	piece.material_override = MATERIALS.get(str(part.get("look", "metal")), MATERIALS.metal)
	piece.transform = Transform(basis, at)
	return piece


# A unit mesh (1 m across) of `shape`.
static func _mesh(shape: String) -> Mesh:
	match shape:
		"box":
			var box := CubeMesh.new()
			box.size = Vector3.ONE
			return box
		"cylinder", "cone":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.0 if shape == "cone" else 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 8
			cylinder.rings = 1
			return cylinder
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 5
	return sphere
