extends Area
class_name ZoneNebulaGlobal, "res://Assets/UI_images/SVG/icons/nebula.svg"

export var nebula_global_brightness_variation = -Constants.outside_fog_brightness
export var nebula_global_contrast_variation = -Constants.outside_fog_contrast
export var nebula_global_saturation_variation = -Constants.outside_fog_saturation

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true

func _on_Zone_nebula_global_body_entered(_body):
	if _body == Paths.player: 
		print("Entered: ", self.name)
		Paths.environment.nebula_global_brightness_variation = nebula_global_brightness_variation
		Paths.environment.nebula_global_contrast_variation = nebula_global_contrast_variation
		Paths.environment.nebula_global_saturation_variation = nebula_global_saturation_variation


func _on_Zone_nebula_global_body_exited(_body):
	if _body == Paths.player: 
		print("Exited: ", self.name)
		Paths.environment.nebula_global_brightness_variation = 0.0
		Paths.environment.nebula_global_contrast_variation = 0.0
		Paths.environment.nebula_global_saturation_variation = 0.0
