extends Node

# CONSTANTS
const camera_far = 9e18 # 9e18 is a safe cap.
const camera_near = 1e-2 # base value.
const camera_fov = 60 # Initial value.

const camera_turret_roll_vert_limit = 70 # Deg +\-
# Zoom out times is multiplied by minimum ship camera distance to define maximum.
# Sync with touchscreen control slider (max_val = camera_zoom_out_times/camera_zoom_step).
const camera_zoom_ticks_max = 100
#const camera_zoom_out_max = 1e3 # For sandnbox mode
const camera_zoom_step = 1 # 0.05 ... 0.2

# VARIABLES
onready var p = get_tree().get_root().get_node("Main/Paths")

func _ready():
	# Set camera properties.
	p.camera.fov = camera_fov
	p.camera.far = camera_far
	p.camera.near = camera_near
