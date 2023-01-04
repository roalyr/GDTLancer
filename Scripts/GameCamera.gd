extends Camera

func _ready():
	self.fov = Constants.camera_fov
	self.far = Constants.camera_far
	self.near = Constants.camera_near
