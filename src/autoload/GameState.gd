# File: autoload/GameState.gd
# Autoload Singleton: Game state
# Version: 1.1 - Extended with contracts, locations, and narrative state for Phase 1.

extends Node

# Global world seed
var world_seed: String = ""

# Global time counter
var current_tu: int = 0

# --- Character & Asset Instances ---
var characters: Dictionary = {}  # Key: character_uid, Value: CharacterTemplate instance

var active_actions: Dictionary = {}

var assets_ships: Dictionary = {}       # Key: ship_uid, Value: ShipTemplate instance
var assets_modules: Dictionary = {}     # Key: module_uid, Value: ModuleTemplate instance
var assets_commodities: Dictionary = {} # Key: commodity_id, Value: CommodityTemplate (master data)

# Key: Character UID, Value: An Inventory object/dictionary for that character.
var inventories: Dictionary = {}

# Defines which character is controlled by player.
var player_character_uid: int = -1

# Currently loaded zone.
var current_zone_instance: Node = null

# --- Player State ---
var player_docked_at: String = "" # Empty if in space, location_id if docked
var player_position: Vector3 = Vector3.ZERO  # Player position in zone
var player_rotation: Vector3 = Vector3.ZERO  # Player rotation (degrees)


# --- Locations (Stations, Points of Interest) ---
# Key: location_id (String), Value: LocationTemplate instance or Dictionary
var locations: Dictionary = {}

# --- Contract System ---
# Available contracts at locations. Key: contract_id, Value: ContractTemplate instance
var contracts: Dictionary = {}
# Player's accepted contracts. Key: contract_id, Value: Dictionary with progress info
var active_contracts: Dictionary = {}

# --- Narrative State (Player-Centric) ---
var narrative_state: Dictionary = {
	"reputation": 0,           # Overall professional standing (-100 to 100)
	"faction_standings": {},    # Key: faction_id, Value: standing int
	"known_contacts": [],       # Array of contact_ids the player has met
	"chronicle_entries": []     # Log of significant events
}

# --- Session Tracking ---
var session_stats: Dictionary = {
	"contracts_completed": 0,
	"total_wp_earned": 0,
	"total_wp_spent": 0,
	"enemies_disabled": 0,
	"time_played_tu": 0
}
