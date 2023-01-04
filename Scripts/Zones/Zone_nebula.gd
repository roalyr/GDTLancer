extends Area
class_name ZoneNebula, "res://Assets/UI_images/SVG/icons/nebula.svg"

func _ready():
	# Disable "Monitorable" for the sake of performance.
	self.monitorable = false
	self.monitoring = true

func _on_Zone_nebula_body_entered(_body):
	if _body == Player: 
		print("Entered: ", self.name)


func _on_Zone_nebula_body_exited(_body):
	if _body == Player: 
		print("Exited: ", self.name)
