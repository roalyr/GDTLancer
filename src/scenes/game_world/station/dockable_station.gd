# PROJECT: GDTLancer
# MODULE: dockable_station.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

##
## PROJECT: GDTLancer
## MODULE: dockable_station.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: gameplay_milestone_audit.md
## LOG_REF: 2026-06-12 23:00:00
##

extends StaticBody

# NOTE: GDD REVISION - Stations as physical dockable bodies within a sector are being deprecated.
# In the upcoming TTRPG-like simulation model, sectors themselves are treated as dockables,
# rather than nested stations. Players dock directly to the sector to access services.
# This StaticBody entity is maintained for physical/visual reference and collision compatibility.

export var location_id: String = "sector_star_elace"
export var station_name: String = "Elace System"


func _ready():
	add_to_group("dockable_station")
