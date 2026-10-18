# Editor-only mesh: hidden at runtime.

extends MeshInstance


func _ready():
	self.hide()
