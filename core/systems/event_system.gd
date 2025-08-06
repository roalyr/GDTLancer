extends Node

func _ready():
	GlobalRefs.set_event_system(self)
	print("EventSystem Ready.")
