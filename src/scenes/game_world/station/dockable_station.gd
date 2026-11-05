# DockableStation: in-sector body the player can dock at. An obstacle for the autopilot.
# Docking at the run's home station banks cargo and repairs the ship (see HomePort).
# Its look is whatever sits under its "Model" node (a StationModel scene): on ready it fits itself to
# it (fit_to_model), so a station scene needs no hand-set sizes.

extends StaticBody

const CollisionHull = preload("res://src/core/agents/components/collision_hull.gd")
const ModelLooks = preload("res://src/scenes/game_world/models/model_looks.gd")

export var location_id: String = "station_elace_home"
export var station_name: String = "Elace System"
export var obstacle_radius: float = 120.0  # m the autopilot keeps clear of
export var undock_offset: Vector3 = Vector3(0, 60, 0)  # Where a ship appears when it spawns docked, in station space
export var has_beacon: bool = false  # A beacon is detected anywhere, like a star; without one, by size


func _ready():
	add_to_group("dockable_station")
	add_to_group("obstacle")
	fit_to_model()


# Sizes the station by its model: it collides by the model's convex hull, the autopilot keeps clear
# of its far corner, and ships undock above its top. Leaves it as it is without a model.
func fit_to_model() -> void:
	var model: Spatial = get_node_or_null("Model")
	if model == null or model.get_child_count() == 0:
		return
	var shape: Shape = CollisionHull.shape_for(model, model.transform)
	var holder: Node = get_node_or_null("CollisionShape")
	if shape != null and holder != null:
		holder.shape = shape
		holder.transform = Transform.IDENTITY
	var extent: Array = ModelLooks.extent(model)
	obstacle_radius = extent[0] + model.transform.origin.length()
	undock_offset.y = max(undock_offset.y, model.transform.origin.y + extent[1] + Constants.STATION_UNDOCK_CLEARANCE)


# Gives the model's painted surfaces `material` (null: leaves them).
func paint(material: Material) -> void:
	var model: Node = get_node_or_null("Model")
	if model != null and material != null:
		ModelLooks.dress(model, material)


func get_obstacle_radius() -> float:
	return obstacle_radius


# Detected like anything else (see Constants SIGNATURE block): by its size, or anywhere if it
# runs a beacon.
func get_signature() -> float:
	return INF if has_beacon else obstacle_radius * Constants.SIG_PER_METRE_OF_SIZE


func get_undock_position() -> Vector3:
	return global_transform.xform(undock_offset)
