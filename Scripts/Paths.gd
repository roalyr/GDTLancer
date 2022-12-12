extends Node

# TODO: PREFIXES TO PATHS BY CATEGORY?

# MAIN
onready var main = get_node("/root/Main")
onready var signals = main.get_node("Signals")

# COMMON
onready var common = main.get_node("Common")
onready var common_camera = common.get_node("Camera")
onready var common_engine = common.get_node("Engine")
onready var common_game_options = common.get_node("Game_options")
onready var ship_state = common.get_node("Ship_state")
onready var common_space_state = common.get_node("Space_state")
onready var common_constants = common.get_node("Constants")
onready var common_resources = common.get_node("Resources")

# VIEWPORT CONTAINER
onready var container = main.get_node("Container")
onready var viewport = container.get_node("Viewport")
onready var environment = viewport.get_node("Environment")

# SPACE
onready var global_space = viewport.get_node("Global_space")
#onready var local_space_galaxy = viewport.get_node("_Local_space_galaxy")
onready var local_space_system = viewport.get_node("Local_space_system")
onready var local_space_star = viewport.get_node("Local_space_star")
onready var local_space_planet = viewport.get_node("Local_space_planet")
onready var local_space_structure = viewport.get_node("Local_space_structure")
onready var ship_space = viewport.get_node("Ship_space")

# SHIP
onready var ship = ship_space.get_node("Ship")

# CAMERA
onready var camera_rig = ship.get_node("Camera_rig")
onready var camera = camera_rig.get_node("Camera")

# INPUT
onready var input = main.get_node("Input")
onready var input_keyboard = input.get_node("Keyboard")
onready var input_mouse = input.get_node("Mouse")
onready var input_pad = input.get_node("Pad")
onready var input_throttle = input.get_node("Throttle")

# UI
onready var ui = container.get_node("UI")
onready var ui_paths = ui.get_node("UI_paths")






