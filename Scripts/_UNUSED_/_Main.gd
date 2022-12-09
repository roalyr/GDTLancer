
extends Node

var fps = 0
var touchscreen_mode = false

func _process(_delta):
	fps = Engine.get_frames_per_second()
