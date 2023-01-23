extends Area
class_name StellarLocalSpace, "res://Assets/UI_images/SVG/icons/star.svg"

export var star_brightness_variation = 0.0
export var star_contrast_variation = 0.0
export var star_saturation_variation = 0.0

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true


# Monitor if Paths.player ship enters the local space. Pass the reference to scene
# Which should be used later on.
func _on_Local_space_trigger_zone_body_entered(_body):
	if _body == Paths.player: 
		Signals.emit_signal("sig_entered_local_space_star", self)
		Paths.environment.star_brightness_variation = star_brightness_variation
		Paths.environment.star_contrast_variation = star_contrast_variation
		Paths.environment.star_saturation_variation = star_saturation_variation

func _on_Local_space_trigger_zone_body_exited(_body):
	if _body == Paths.player: 
		Signals.emit_signal("sig_exited_local_space_star", self)
		Paths.environment.star_brightness_variation = 0.0
		Paths.environment.star_contrast_variation = 0.0
		Paths.environment.star_saturation_variation = 0.0
