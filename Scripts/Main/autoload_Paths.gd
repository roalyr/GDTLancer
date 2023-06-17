extends Node

onready var viewport_container_3D = ViewportContainer3d
onready var viewport_3D = viewport_container_3D.get_node("Viewport3D")
onready var environment = viewport_3D.get_node("Environment")
onready var global_space = viewport_3D.get_node("Global_space")
onready var nebula_global = global_space.get_node("Nebula_global")

onready var local_space_system = viewport_3D.get_node("Local_space_system")
onready var local_space_star = viewport_3D.get_node("Local_space_star")
onready var local_space_planet = viewport_3D.get_node("Local_space_planet")
onready var local_space_structure = viewport_3D.get_node("Local_space_structure")
onready var player: RigidBody = viewport_3D.get_node("Player")
onready var camera_rig = player.get_node("Camera_rig")
onready var camera = camera_rig.get_node("GameCamera")
