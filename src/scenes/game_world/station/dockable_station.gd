# DockableStation: in-sector body the player can dock at. An obstacle for the autopilot.
# Docking at the run's home station banks cargo and repairs the ship (see HomePort).

extends StaticBody

export var location_id: String = "station_elace_home"
export var station_name: String = "Elace System"
export var obstacle_radius: float = 120.0  # m the autopilot keeps clear of
export var undock_offset: Vector3 = Vector3(0, 60, 0)  # Where a ship appears when it spawns docked, in station space


func _ready():
	add_to_group("dockable_station")
	add_to_group("obstacle")


func get_obstacle_radius() -> float:
	return obstacle_radius


func get_undock_position() -> Vector3:
	return global_transform.xform(undock_offset)
