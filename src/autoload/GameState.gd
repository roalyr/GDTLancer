#
# PROJECT: GDTLancer
# MODULE: GameState.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 8 (Simulation Architecture)
# LOG_REF: 2026-02-13
#

extends Node

## Global Game State singleton — Four-Layer Simulation Data Store.
## Structured as: World (static) → Grid (CA-driven) → Agents (cognitive) → Chronicle (events).
## All simulation systems read/write through this singleton.
## Conservation Axiom 1: world_total_matter must remain constant across ticks.


# =========================================================================
# === LAYER 1: WORLD (static, set at init, read-only at runtime) =========
# =========================================================================

## Sector connectivity graph. Key: sector_id (String).
## Value: {connections: Array, station_ids: Array, sector_type: String}
var world_topology: Dictionary = {}

## Environmental hazards per sector. Key: sector_id (String).
## Value: {radiation_level: float, thermal_background_k: float, gravity_well_penalty: float}
var world_hazards: Dictionary = {}

## Finite resource deposits per sector. Key: sector_id (String).
## Value: {mineral_density: float, energy_potential: float, propellant_sources: float}
var world_resource_potential: Dictionary = {}

## Axiom 1 checksum — total matter in the universe, set at init, verified each tick.
var world_total_matter: float = 0.0


# =========================================================================
# === LAYER 2: GRID (dynamic, CA-driven, updated each tick) ==============
# =========================================================================

## Consumable resource supply levels per sector. Key: sector_id (String).
## Value: {propellant_supply: float, consumables_supply: float, energy_supply: float}
var grid_resource_availability: Dictionary = {}

## Faction control and security per sector. Key: sector_id (String).
## Value: {faction_influence: Dictionary, security_level: float, pirate_activity: float}
var grid_dominion: Dictionary = {}

## Market conditions per sector. Key: sector_id (String).
## Value: {commodity_price_deltas: Dictionary, population_density: float, service_cost_modifier: float}
var grid_market: Dictionary = {}

## Commodity storage per sector. Key: sector_id (String).
## Value: {commodity_stockpiles: Dictionary, stockpile_capacity: int, extraction_rate: Dictionary}
var grid_stockpiles: Dictionary = {}

## Wear and degradation rates per sector. Key: sector_id (String).
## Value: {local_entropy_rate: float, maintenance_cost_modifier: float}
var grid_maintenance: Dictionary = {}

## Station power budget per sector. Key: sector_id (String).
## Value: {station_power_output: float, station_power_draw: float, power_load_ratio: float}
var grid_power: Dictionary = {}

## Active wreck objects in the world. Key: wreck_uid (int).
## Value: {sector_id: String, wreck_integrity: float, wreck_inventory: Dictionary,
##         ship_template_id: String, created_at_tick: int}
var grid_wrecks: Dictionary = {}


# =========================================================================
# === LAYER 3: AGENTS (cognitive entities) ===============================
# =========================================================================

## All character instances. Key: char_uid (int), Value: CharacterTemplate instance.
var characters: Dictionary = {}

## All agent simulation state. Key: agent_id (String), Value: agent state Dictionary.
## State dict keys:
##   char_uid: int, current_sector_id: String, hull_integrity: float,
##   propellant_reserves: float, energy_reserves: float, consumables_reserves: float,
##   cash_reserves: float, fleet_ships: Array, current_heat_level: float,
##   is_persistent: bool, home_location_id: String, is_disabled: bool,
##   disabled_at_tick: int, known_grid_state: Dictionary, knowledge_timestamps: Dictionary,
##   goal_queue: Array, goal_archetype: String, event_memory: Array,
##   faction_standings: Dictionary, character_standings: Dictionary, sentiment_tags: Array
var agents: Dictionary = {}

## Per-character inventories. Key: char_uid (int), Value: inventory Dictionary.
var inventories: Dictionary = {}

## All ship instances. Key: ship_uid (int), Value: ShipTemplate instance.
var assets_ships: Dictionary = {}

## Defines which character is controlled by the player.
var player_character_uid: int = -1

## Hostile population tracking. Key: hostile_type_id (String).
## Value: {current_count: int, carrying_capacity: int, sector_counts: Dictionary}
var hostile_population_integral: Dictionary = {}


# =========================================================================
# === LAYER 4: CHRONICLE (event capture) =================================
# =========================================================================

## Event buffer for the current/recent ticks. Array of Event Packet dicts.
## Packet: {actor_uid, action_id, target_uid, target_sector_id, tick_count, outcome, metadata}
var chronicle_event_buffer: Array = []

## Generated rumor strings derived from events.
var chronicle_rumors: Array = []


# =========================================================================
# === SIMULATION META ====================================================
# =========================================================================

## Number of simulation ticks elapsed since world init.
var sim_tick_count: int = 0

## Global time counter (seconds of game time).
var game_time_seconds: int = 0

## World generation seed — determines all procedural content.
var world_seed: String = ""


# =========================================================================
# === SCENE STATE (kept separate from simulation) ========================
# =========================================================================

## Currently loaded zone node.
var current_zone_instance: Node = null

## Location ID of docked station, or empty string if in space.
var player_docked_at: String = ""

## Player spatial position in the active zone.
var player_position: Vector3 = Vector3.ZERO

## Player spatial rotation in the active zone (degrees).
var player_rotation: Vector3 = Vector3.ZERO


# =========================================================================
# === LEGACY (kept for KEPT-system compatibility, will be pruned later) ==
# =========================================================================

## Locations loaded from TemplateDatabase. Key: location_id, Value: LocationTemplate instance.
## NOTE: Will be superseded by world_topology + world_hazards once WorldLayer initializer is built.
var locations: Dictionary = {}

## Faction data loaded from TemplateDatabase. Key: faction_id, Value: FactionTemplate instance.
## NOTE: Will feed into grid_dominion initialization once GridLayer is built.
var factions: Dictionary = {}

## Commodity master data. Key: commodity_id, Value: CommodityTemplate.
## NOTE: Will feed into grid_stockpiles initialization.
var assets_commodities: Dictionary = {}

## Legacy alias — persistent_agents now lives in agents dict above.
## Kept so agent_system.gd doesn't crash before its own rework task.
var persistent_agents: Dictionary = {}
