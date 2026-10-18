# Asteroid: a hand-placed rock. Static, solid (blocks ships and laser fire), takes hull marks from
# hits, and is an obstacle the autopilot steers around. Size it with the node's uniform scale and
# shape it with `stretch` (applied to the model only, so the collision sphere stays a sphere).

extends StaticBody

const HullScorch = preload("res://src/core/agents/components/hull_scorch.gd")

export var stretch: Vector3 = Vector3.ONE  # Per-axis model stretch, for a non-spherical rock

var hull_bounds: AABB = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
var _hull_scorch: Node = null

onready var _model: Spatial = $Model
onready var _collision: CollisionShape = $CollisionShape


func _ready() -> void:
	add_to_group("asteroid")
	add_to_group("obstacle")
	_model.scale = stretch
	# Collision sphere fits the stretched rock's smallest axis, so ships and shots touch rock, not air.
	_collision.scale = Vector3.ONE * min(stretch.x, min(stretch.y, stretch.z))
	hull_bounds = AABB(-stretch * 1.25, stretch * 2.5)
	_hull_scorch = HullScorch.new()
	add_child(_hull_scorch)
	_hull_scorch.setup(_model)


# World-space radius the autopilot keeps clear of.
func get_obstacle_radius() -> float:
	return get_apparent_radius()


func get_apparent_radius() -> float:
	var size: Vector3 = hull_bounds.size * global_transform.basis.get_scale()
	return max(size.x, max(size.y, size.z)) * 0.5


# A shot from `from_global` lands on the rock: marks it and returns the world point it hit.
func register_hit(from_global: Vector3, damage: float) -> Vector3:
	if is_instance_valid(_hull_scorch) and damage > 0.0:
		_hull_scorch.add_hit(from_global, global_transform.origin, damage)
		if _hull_scorch.last_hit_point != null:
			return _hull_scorch.last_hit_point
	return get_hull_point_facing(from_global)


func get_hull_point_facing(from_global: Vector3) -> Vector3:
	var to_rock: Vector3 = global_transform.origin - from_global
	return global_transform.origin - to_rock.normalized() * get_apparent_radius() * 0.8
