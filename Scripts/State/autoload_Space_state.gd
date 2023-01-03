extends Node

# Arrays of global markers.
var markers_nebulas_constellations = []
var markers_systems = []
var markers_stars = []
var markers_planets = []
var markers_structures= []

var system_coordinates = Position3D # Selected while targeting.
var systems_spawned = [] # Queue of spawned systems in order to manage memory.
var systems_visited = [] # Queue of spawned systems in order to manage memory.
