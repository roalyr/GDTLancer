#
# PROJECT: GDTLancer
# MODULE: GameState.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md Section 3 (Architecture)
# LOG_REF: 2026-01-30
#

extends Node

## Global Game State singleton.
## Stores all runtime data for the current session.

# Global world seed
var world_seed: String = ""

# Global time counter (seconds)
var game_time_seconds: int = 0

# --- Character & Asset Instances ---
var characters: Dictionary = {}  # Key: character_uid, Value: CharacterTemplate instance

var active_actions: Dictionary = {}

var assets_ships: Dictionary = {}       # Key: ship_uid, Value: ShipTemplate instance
var assets_modules: Dictionary = {}     # Key: module_uid, Value: ModuleTemplate instance
var assets_commodities: Dictionary = {} # Key: commodity_id, Value: CommodityTemplate (master data)

# --- Ship Quirks Helper ---
## Returns the array of quirk IDs for a given ship.
func get_ship_quirks(ship_uid: int) -> Array:
	if assets_ships.has(ship_uid):
		return assets_ships[ship_uid].ship_quirks
	return []

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

# --- Factions & Contacts (World Data) ---
# Key: faction_id, Value: FactionTemplate
var factions: Dictionary = {}
# Key: contact_id, Value: ContactTemplate
# DEPRECATED: Use persistent_agents instead (ContactTemplate is now synonymous with persistent AgentTemplate/CharacterTemplate)
var contacts: Dictionary = {}

# --- Persistent Agents (New System) ---
# Key: agent_id (String), Value: Dictionary (State)
# State Structure:
# { 
#   "character_uid": int,         # Runtime Character Instance ID
#   "current_location": String,   # location_id where currently present/spawned
#   "is_disabled": bool,          # True if defeated/out of commisson
#   "disabled_at_time": float,    # Timestamp of disablement for respawn logic
#   "relationship": int,          # 0-100 Relationship with player
#   "is_known": bool              # True if player has met this agent (Contact Discovery)
# }
var persistent_agents: Dictionary = {}

# --- Contract System ---
# Available contracts at locations. Key: contract_id, Value: ContractTemplate instance
var contracts: Dictionary = {}
# Player's accepted contracts. Key: contract_id, Value: Dictionary with progress info
var active_contracts: Dictionary = {}

# --- Narrative State (Player-Centric) ---
var narrative_state: Dictionary = {
	"reputation": 0,           # Overall professional standing (-100 to 100)
	"faction_standings": {},    # Key: faction_id, Value: standing int
	"known_contacts": [],       # DEPRECATED: Migrated to persistent_agents[agent_id].is_known
	"contact_relationships": {}, # DEPRECATED: Migrated to persistent_agents[agent_id].relationship
	"chronicle_entries": []     # Log of significant events
}

# --- Session Tracking ---
var session_stats: Dictionary = {
	"contracts_completed": 0,
	"total_credits_earned": 0,
	"total_credits_spent": 0,
	"enemies_disabled": 0,
	"time_played_seconds": 0
}
