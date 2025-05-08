extends MeshInstance

export var rotation_speed = 0.01

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	self.rotate(Vector3(0,1,0), delta * rotation_speed)
