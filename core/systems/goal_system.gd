extends Node

func _ready():
	GlobalRefs.set_goal_system(self)
	print("GoalSystem Ready.")
