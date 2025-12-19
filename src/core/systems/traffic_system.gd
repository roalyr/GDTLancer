extends Node

func _ready():
	GlobalRefs.set_traffic_system(self)
	print("TrafficSystem Ready.")
