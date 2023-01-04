extends Position3D
class_name MarkerNebula, "res://Assets/UI_images/SVG/icons/nebula_marker.svg"

export var autopilot_range = 1e16
export var targetable = true
export var translations_name = ""
export var translations_description = ""


func _ready():

	# Insert marker into the global marker list (and keep it there)
	SpaceState.markers_nebulas_constellations.append(self)
	
