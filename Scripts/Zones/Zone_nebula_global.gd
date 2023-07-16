extends Area
class_name ZoneNebulaGlobal, "res://Assets/UI_images/SVG/icons/nebula.svg"

export var nebula_global_brightness_variation = 0.0
export var nebula_global_contrast_variation = 0.0
export var nebula_global_saturation_variation = 0.0

var nebula_visibility_array = []
var nebula_list = []

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true
	# ============================ Connect signals ============================
	Signals.connect_checked("sig_nebula_distance", self, "is_nebula_distance")
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

func is_nebula_distance(data):
	# First append all the possibble nebulas to the list.
	if not data in nebula_list:
		nebula_list.append(data)
		
		# If a duplicate by name apperas it means visibility should change. Reset the array then.
		for entry in nebula_list:
			if entry[0] == data[0] and data[1]:
				entry[1] = true # Change visibility flag.
				self.hide()
			
			elif entry[0] == data[0] and not data[1]:
				entry[1] = false # Change visibility flag to reverse.
				self.show()
				
		#print(nebula_list)
		
		
