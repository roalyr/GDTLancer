extends Node

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	GlobalRefs.set_goal_system(self)
	print("GoalSystem Ready.")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
