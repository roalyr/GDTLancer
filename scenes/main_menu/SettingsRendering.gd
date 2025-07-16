extends Control

var _viewport_size = Vector2(1920, 1080)


# Called when the node enters the scene tree for the first time.
func _ready():
	_viewport_size = get_viewport().size

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
