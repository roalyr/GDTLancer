extends Area
class_name ZoneNebulaGlobal, "res://Assets/UI_images/SVG/icons/nebula.svg"

export var nebula_global_brightness_variation = 0.0
export var nebula_global_contrast_variation = 0.0
export var nebula_global_saturation_variation = 0.0

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true
	# ============================ Connect signals ============================
	Signals.connect_checked("sig_nebula_entered", self, "is_nebula_entered")
	# =========================================================================
	
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

func is_nebula_entered(flag):
	if flag:
		print("Global nebula hide")
		Paths.nebula_global.hide()
	else:
		print("Global nebula show")
		Paths.nebula_global.show()
		
