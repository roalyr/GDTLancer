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

# Key: Character UID, Value: An Inventory object/dictionary for that character.
var inventories: Dictionary = {}

# Defines which character is controlled by player.
var player_character_uid: int = -1

# Currently loaded zone.
var current_zone_instance: Node = null
