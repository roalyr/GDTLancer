extends Node

# TODO: move those somewhere else.
var fps = 0

func _process(_delta):
	fps = Engine.get_frames_per_second()
