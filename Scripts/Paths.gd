extends Node

onready var camera_rig = Player.get_node("Camera_rig")
onready var camera = Player.get_node("Camera_rig/GameCamera")

onready var ui = ViewportContainer2d.get_node("UI")
onready var environment = GlobalEnvironment
