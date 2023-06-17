extends Area
class_name ZoneNebula, "res://Assets/UI_images/SVG/icons/nebula.svg"

export var nebula_brightness_variation = 0.0
export var nebula_contrast_variation = 0.0
export var nebula_saturation_variation = 0.0

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true

func _on_Zone_nebula_body_entered(_body):
	if _body == Paths.player: 
		print("Entered: ", self.name)
		Paths.environment.nebula_brightness_variation = nebula_brightness_variation
		Paths.environment.nebula_contrast_variation = nebula_contrast_variation
		Paths.environment.nebula_saturation_variation = nebula_saturation_variation
		Signals.emit_signal("sig_nebula_entered", true)


func _on_Zone_nebula_body_exited(_body):
	if _body == Paths.player: 
		print("Exited: ", self.name)
		Paths.environment.nebula_brightness_variation = 0.0
		Paths.environment.nebula_contrast_variation = 0.0
		Paths.environment.nebula_saturation_variation = 0.0
		Signals.emit_signal("sig_nebula_entered", false)
		
