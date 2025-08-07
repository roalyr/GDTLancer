# File: autoload/GameState.gd
# Autoload Singleton: Game state
# Version: 1.0 

extends Node

# Global world seed
var world_seed: String = ""

# Global time counter
var current_tu = 0

# Global dictionaries of instances
var characters: Dictionary = {}

var active_actions: Dictionary = {}

var assets_ships: Dictionary = {}
var assets_modules: Dictionary = {}
var assets_commodities: Dictionary = {}

var inventories_ships: Dictionary = {}
var inventories_modules: Dictionary = {}
var inventories_commodieties: Dictionary = {}

# Defines which character is controlled by player.
var player_character_uid: int = -1

# Currently loaded zone.
var current_zone_instance: Node = null
