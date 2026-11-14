# CelestialBody: a star, planet or moon. Detected by the same rule as ships (see Constants
# SIGNATURE block): a star shines across the whole system, anything else shows within its size
# times SIG_PER_METRE_OF_SIZE. Its size is the collision sphere's radius. An obstacle the autopilot
# steers round (NavigationSystem), as rocks and stations are: a straight leg past a planet must not
# end against it.

extends StaticBody

const NavigationSystem = preload("res://src/core/agents/components/navigation_system.gd")

export var is_star: bool = false  # Detected anywhere: its own light gives it away


func _ready() -> void:
	add_to_group("celestial")
	add_to_group("obstacle")
	NavigationSystem.forget_obstacles(get_tree())  # Now that it is one


# The autopilot's obstacle list (NavigationSystem.get_obstacle_index) is kept while none comes or goes.
func _enter_tree() -> void:
	NavigationSystem.forget_obstacles(get_tree())


func _exit_tree() -> void:
	NavigationSystem.forget_obstacles(get_tree())


func get_obstacle_radius() -> float:
	return get_apparent_radius()


func get_apparent_radius() -> float:
	var shape_node = get_node_or_null("CollisionShape")
	if shape_node == null or not (shape_node.shape is SphereShape):
		return 0.0
	var scale: Vector3 = shape_node.global_transform.basis.get_scale()
	return shape_node.shape.radius * max(scale.x, max(scale.y, scale.z))


func get_signature() -> float:
	return INF if is_star else get_apparent_radius() * Constants.SIG_PER_METRE_OF_SIZE
