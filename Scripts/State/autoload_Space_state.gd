extends Node

# Coordinates.
var global_space_translation = Vector3(0,0,0)
var local_system_space_translation = Vector3(0,0,0)
var local_star_space_translation = Vector3(0,0,0)
var local_planet_space_translation = Vector3(0,0,0)
var local_structure_space_translation = Vector3(0,0,0)
var ship_translation = Vector3(0,0,0)
var ship_rotation = Vector3(0,0,0)

# Local space zones.
var current_local_system_space_zone = Position3D
var current_local_star_space_zone = Position3D
var current_local_planet_space_zone = Position3D
var current_local_structure_space_zone = Position3D

# Arrays of global markers.
var markers_nebulas_constellations = []
var markers_systems = []
var markers_stars = []
var markers_planets = []
var markers_structures= []

# Procedural space.
var system_coordinates = Position3D # Selected while targeting.
var systems_spawned = [] # Queue of spawned systems in order to manage memory.
var systems_visited = [] # Queue of spawned systems in order to manage memory.
