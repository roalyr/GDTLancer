##
## PROJECT: GDTLancer
## MODULE: dockable_station.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_CONTENT-CREATION-MANUAL.md §3.4, TACTICAL_TODO.md §TASK_1
## LOG_REF: 2026-05-09 20:56:15
##

extends StaticBody

export var location_id: String = "sector_star_elace"
export var station_name: String = "Elace System"


func _ready():
	add_to_group("dockable_station")
