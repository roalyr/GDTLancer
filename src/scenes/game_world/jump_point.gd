#
# PROJECT: GDTLancer
# MODULE: jump_point.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT §Architecture, TACTICAL_TODO §TASK_4
# LOG_REF: 2026-04-12
#

extends StaticBody

export var target_sector_id: String = ""
export var target_sector_name: String = ""


func _ready():
	add_to_group("jump_point")
