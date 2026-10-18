# JumpPoint: in-sector body that leads to another sector.

extends StaticBody

export var target_sector_id: String = ""
export var target_sector_name: String = ""


func _ready():
	add_to_group("jump_point")
