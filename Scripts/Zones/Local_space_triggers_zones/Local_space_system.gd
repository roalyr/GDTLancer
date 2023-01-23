extends Area
class_name SystemLocalSpace, "res://Assets/UI_images/SVG/icons/system.svg"

export var system_brightness_variation = 0.0
export var system_contrast_variation = 0.0
export var system_saturation_variation = 0.0

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true
		
# Monitor if Paths.player Paths.player enters the local space. Pass the reference to scene
# Which should be used later on.
func _on_Local_space_trigger_zone_body_entered(_body):
	if _body == Paths.player: 
		Signals.emit_signal("sig_entered_local_space_system", self)
		Paths.environment.system_brightness_variation = system_brightness_variation
		Paths.environment.system_contrast_variation = system_contrast_variation
		Paths.environment.system_saturation_variation = system_saturation_variation

func _on_Local_space_trigger_zone_body_exited(_body):
	if _body == Paths.player: 
		Signals.emit_signal("sig_exited_local_space_system", self)
		Paths.environment.system_brightness_variation = 0.0
		Paths.environment.system_contrast_variation = 0.0
		Paths.environment.system_saturation_variation = 0.0

