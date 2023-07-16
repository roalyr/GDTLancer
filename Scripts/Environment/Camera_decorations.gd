extends Spatial

func _process(_delta):
	# Translation follows camera. Prevents artifacts due to origin rebase at high V.
	if PlayerState.ship_linear_velocity > 50000000000000:
		self.global_transform.origin = Paths.camera.global_transform.origin
