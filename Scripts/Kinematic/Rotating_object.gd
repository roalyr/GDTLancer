extends Spatial
class_name RotatingObject, "res://Assets/UI_images/SVG/icons/rotating_object.svg"

export var axis = Vector3(0,1,0)
export var rotation_speed = 0.01

func _physics_process(delta):
	self.rotate(axis, rotation_speed*delta)
