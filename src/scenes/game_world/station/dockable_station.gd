# DockableStation: in-sector body the player can dock at.

extends StaticBody

export var location_id: String = "sector_star_elace"
export var station_name: String = "Elace System"


func _ready():
	add_to_group("dockable_station")
