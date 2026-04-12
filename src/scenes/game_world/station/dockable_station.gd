extends StaticBody

export var location_id: String = "station_alpha"
export var station_name: String = "Station Alpha"


func _ready():
	add_to_group("dockable_station")
