extends Node

func _ready():
	GlobalRefs.set_world_map_system(self)
	print("WorldMapSystem Ready.")
