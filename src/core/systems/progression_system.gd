extends Node

func _ready():
	GlobalRefs.set_progression_system(self)
	print("ProgressionSystem Ready.")
