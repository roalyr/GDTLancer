extends Spatial

# Nodes.
onready var p = get_tree().get_root().get_node("Main/Paths")


func _process(_delta):
	# Translation follows camera. Prevents artifacts due to origin rebase at high V.
	if p.ship_state.apparent_velocity > 50000000000000:
		self.global_transform.origin = p.camera.global_transform.origin
