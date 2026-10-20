# Asteroid: a hand-placed rock. Static, solid (blocks ships and laser fire), shows hits, and is an obstacle the autopilot steers around. Pick its look with `model` (a rock mesh from
# assets/models/rocks/), size it with the node's uniform scale. The rock material is applied here,
# since the rock meshes come without one.

extends StaticBody

const MeshLod = preload("res://src/core/agents/components/mesh_lod.gd")
const CollisionHull = preload("res://src/core/agents/components/collision_hull.gd")
const RockMaterial = preload("res://assets/art/materials_generic/mat_asteroid_rock.tres")

export var model: PackedScene = null  # Rock mesh scene; the prefab's default is used if unset
export var stretch: Vector3 = Vector3.ONE  # Per-axis model stretch, for a non-spherical rock

var hull_bounds: AABB = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

onready var _model: Spatial = $Model
onready var _collision: CollisionShape = $CollisionShape


func _ready() -> void:
	add_to_group("asteroid")
	add_to_group("obstacle")
	if model != null:
		for child in _model.get_children():
			_model.remove_child(child)
			child.queue_free()
		_model.add_child(model.instance())
	_model.scale = stretch
	hull_bounds = _measure_model_bounds()
	for node in _all_nodes(_model):
		if node is MeshInstance:
			node.material_override = RockMaterial
	# Collision follows the rock's outline (convex hull of its lowest level of detail, stretch baked
	# in), so ships and shots touch rock, not air. Failing that, a sphere that fits inside the rock.
	var hull_shape = CollisionHull.shape_for(_model, _model.transform)
	if hull_shape != null:
		_collision.shape = hull_shape
		_collision.transform = Transform.IDENTITY
	else:
		var collision_radius: float = min(hull_bounds.size.x, min(hull_bounds.size.y, hull_bounds.size.z)) * 0.45
		_collision.transform = Transform(Basis().scaled(Vector3.ONE * collision_radius), hull_bounds.position + hull_bounds.size * 0.5)
	MeshLod.attach(_model, get_apparent_radius(), Constants.LOD_DISTANCE_RADII_DENSE)


func _measure_model_bounds() -> AABB:
	var bounds := AABB()
	var found := false
	var to_body: Transform = global_transform.affine_inverse()
	for node in _all_nodes(_model):
		if node is GeometryInstance:
			var box: AABB = (to_body * node.global_transform).xform(node.get_aabb())
			bounds = box if not found else bounds.merge(box)
			found = true
	return bounds if found else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


static func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for child in root.get_children():
		out += _all_nodes(child)
	return out


# World-space radius the autopilot keeps clear of.
func get_obstacle_radius() -> float:
	return get_apparent_radius()


func get_apparent_radius() -> float:
	var size: Vector3 = hull_bounds.size * global_transform.basis.get_scale()
	return max(size.x, max(size.y, size.z)) * 0.5


# A shot from `from_global` lands on the rock: returns the world point it hit. The shot line meets
# the rock's collision hull; failing that, the rock point facing the shooter.
func register_hit(from_global: Vector3, damage: float) -> Vector3:
	var aim: Vector3 = global_transform.xform(hull_bounds.position + hull_bounds.size * 0.5)
	var hit: Dictionary = CollisionHull.ray_onto(self, from_global, aim, get_apparent_radius() * 2.0)
	return hit.position if not hit.empty() else get_hull_point_facing(from_global)


func get_hull_point_facing(from_global: Vector3) -> Vector3:
	var to_rock: Vector3 = global_transform.origin - from_global
	return global_transform.origin - to_rock.normalized() * get_apparent_radius() * 0.8
