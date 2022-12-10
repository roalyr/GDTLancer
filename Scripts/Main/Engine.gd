extends Node

# CONSTANTS
const physics_fps = 120
const graphic_fps = 60


# Origin rebase
const rebase_limit_margin = 5000
const rebase_lag = 1.1

func _ready():
	Engine.set_iterations_per_second(physics_fps)
	Engine.set_target_fps(graphic_fps)
