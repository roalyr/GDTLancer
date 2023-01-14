extends Area
class_name PlanetLocalSpace, "res://Assets/UI_images/SVG/icons/planet.svg"

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true
	
# Monitor if Paths.player ship enters the local space. Pass the reference to scene
# Which should be used later on.
func _on_Local_space_trigger_zone_body_entered(_body):
	if _body == Paths.player: 
		Signals.emit_signal("sig_entered_local_space_planet", self)

func _on_Local_space_trigger_zone_body_exited(_body):
	if _body == Paths.player: 
		Signals.emit_signal("sig_exited_local_space_planet", self)
