extends Area
class_name EnvironmentZone, "res://Assets/UI_images/SVG/icons/environment_zone.svg"

export var zone_brightness_variation = 0.0
export var zone_contrast_variation = 0.0
export var zone_saturation_variation = 0.0

onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true


func _on_Zone_environment_body_entered(_body):
	if _body == p.ship: 
		p.environment.zone_brightness_variation = zone_brightness_variation
		p.environment.zone_contrast_variation = zone_contrast_variation
		p.environment.zone_saturation_variation = zone_saturation_variation

func _on_Zone_environment_body_exited(_body):
	if _body == p.ship: 
		p.environment.zone_brightness_variation = 0.0
		p.environment.zone_contrast_variation = 0.0
		p.environment.zone_saturation_variation = 0.0