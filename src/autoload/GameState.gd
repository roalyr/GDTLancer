#
# PROJECT: GDTLancer
# MODULE: GameState.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1, §3.2, §6.4; TACTICAL_TODO.md TASK_4
# LOG_REF: 2026-05-26 16:38:00
#

extends Node

## Global Game State singleton — Qualitative Tag Simulation Data Store.
## All simulation systems read/write through this singleton.
## Pure data store. No logic. All fields default-initialized.


# =========================================================================
# === LAYER 1: WORLD (static topology, set at init) =====================
# =========================================================================

## Sector connectivity graph. Key: sector_id (String).
## Value: {connections: Array, station_ids: Array, sector_type: String}
var world_topology: Dictionary = {}

## Environmental hazards per sector. Key: sector_id (String).
## Value: {environment: String}
var world_hazards: Dictionary = {}

## World-level qualitative tags (derived from world_age).
var world_tags: Array = []

## World generation seed — determines all procedural content.
var world_seed: String = ""


# =========================================================================
# === LAYER 2: GRID (dynamic, tag-transition CA, updated each tick) ======
# =========================================================================

## Faction control and security per sector. Key: sector_id (String).
## Value: {controlling_faction_id: String, security_tag: String}
var grid_dominion: Dictionary = {}

## Qualitative tags per sector. Key: sector_id (String). Value: Array of String tags.
var sector_tags: Dictionary = {}


# =========================================================================
# === LAYER 3: AGENTS (cognitive entities) ===============================
# =========================================================================

## All character data. Key: character_id (String), Value: character data Dictionary.
var characters: Dictionary = {}

## All agent simulation state. Key: agent_id (String), Value: agent state Dictionary.
var agents: Dictionary = {}

## Derived agent tags (refreshed by BridgeSystems). Key: agent_id, Value: Array of tags.
var agent_tags: Dictionary = {}

## Player character identifier.
var player_character_uid: String = ""


# =========================================================================
# === COLONY PROGRESSION =================================================
# =========================================================================

## Colony level per sector. Key: sector_id, Value: String (frontier/outpost/colony/hub).
var colony_levels: Dictionary = {}

## Consecutive qualifying ticks toward colony upgrade. Key: sector_id, Value: int.
var colony_upgrade_progress: Dictionary = {}

## Consecutive bad ticks toward colony downgrade. Key: sector_id, Value: int.
var colony_downgrade_progress: Dictionary = {}

## History of colony level changes.
var colony_level_history: Array = []


# =========================================================================
# === SECURITY PROGRESSION ===============================================
# =========================================================================

## Consecutive ticks of upgrade pressure per sector. Key: sector_id, Value: int.
var security_upgrade_progress: Dictionary = {}

## Consecutive ticks of downgrade pressure per sector. Key: sector_id, Value: int.
var security_downgrade_progress: Dictionary = {}

## Per-sector ticks required to shift security. Key: sector_id, Value: int.
var security_change_threshold: Dictionary = {}


# =========================================================================
# === ECONOMY PROGRESSION ================================================
# =========================================================================

## Per-sector per-category upgrade progress. Key: sector_id, Value: {category: int}.
var economy_upgrade_progress: Dictionary = {}

## Per-sector per-category downgrade progress. Key: sector_id, Value: {category: int}.
var economy_downgrade_progress: Dictionary = {}

## Per-sector per-category change threshold. Key: sector_id, Value: {category: int}.
var economy_change_threshold: Dictionary = {}


# =========================================================================
# === QUALITATIVE CONTRACT DEMAND ========================================
# =========================================================================

## Per-sector per-category pressure toward runtime demand tags.
## Key: sector_id, Value: {category: int}.
var contract_generation_pressure: Dictionary = {}

## Per-sector per-category ticks required before demand tags appear.
## Key: sector_id, Value: {category: int}.
var contract_generation_threshold: Dictionary = {}

## Per-sector per-category unreserved source-side contract cargo units.
## Key: sector_id, Value: {category: int}.
var contract_cargo_supply: Dictionary = {}

## Per-sector per-category reserved source-side contract cargo units.
## Key: sector_id, Value: {category: int}.
var contract_cargo_reserved: Dictionary = {}

## Per-sector per-category unreserved target-side reward/specie bundles.
## Key: sector_id, Value: {category: int}.
var contract_payment_supply: Dictionary = {}

## Per-sector per-category reserved target-side reward/specie bundles.
## Key: sector_id, Value: {category: int}.
var contract_payment_reserved: Dictionary = {}


# =========================================================================
# === RUNTIME CONTRACT OCCURRENCES =======================================
# =========================================================================

## Generated runtime contract occurrences keyed by occurrence_id.
## Value: qualitative delivery contract Dictionary.
var runtime_contract_occurrences: Dictionary = {}

## Occurrence ids grouped by demand/target sector. Key: sector_id, Value: Array.
var runtime_contract_occurrences_by_target_sector: Dictionary = {}

## Occurrence ids grouped by source sector. Key: sector_id, Value: Array.
var runtime_contract_occurrences_by_source_sector: Dictionary = {}


# =========================================================================
# === HOSTILE INFESTATION PROGRESSION ====================================
# =========================================================================

## Infestation build/clear progress per sector. Key: sector_id, Value: int.
var hostile_infestation_progress: Dictionary = {}


# =========================================================================
# === CATASTROPHE + LIFECYCLE ============================================
# =========================================================================

## Log of catastrophe events.
var catastrophe_log: Array = []

## Sector disabled until tick N. Key: sector_id, Value: int (tick).
var sector_disabled_until: Dictionary = {}

## Counter for mortal agent IDs.
var mortal_agent_counter: int = 0

## Log of mortal agent deaths.
var mortal_agent_deaths: Array = []


# =========================================================================
# === DISCOVERY ==========================================================
# =========================================================================

## Number of sectors discovered by exploration.
var discovered_sector_count: int = 0

## Log of discovery events.
var discovery_log: Array = []

## Display names for discovered sectors. Key: sector_id, Value: String.
var sector_names: Dictionary = {}

## Discovered sector ids (ordered by discovery sequence).
var discovered_sectors: Array = []

## Generated station metadata keyed by station id.
## Value: {id, display_name, sector_id, location_id, docking_point: Vector3}
var station_by_id: Dictionary = {}


# =========================================================================
# === CHRONICLE (event capture) ==========================================
# =========================================================================

## Rolling buffer of chronicle events. Array of event packet Dictionaries.
var chronicle_events: Array = []

## Generated rumor strings derived from events.
var chronicle_rumors: Array = []


# =========================================================================
# === SIMULATION META ====================================================
# =========================================================================

## Number of simulation ticks elapsed since world init.
var sim_tick_count: int = 0

## Sub-tick accumulator toward SUB_TICKS_PER_TICK.
var sub_tick_accumulator: int = 0

## Current world age (PROSPERITY / DISRUPTION / RECOVERY).
var world_age: String = ""

## Ticks remaining in current world age.
var world_age_timer: int = 0

## Number of complete world-age cycles.
var world_age_cycle_count: int = 0

## Global time counter (seconds of game time).
var game_time_seconds: int = 0


# =========================================================================
# === SCENE STATE (kept separate from simulation) ========================
# =========================================================================

## Currently loaded zone node.
var current_zone_instance: Node = null

## ID of the currently loaded sector (e.g. "sector_system_elace").
var current_sector_id: String = ""

## Location ID of docked station, or empty string if in space.
var player_docked_at: String = ""

## Player-selected runtime contract occurrence id, or empty when none is selected.
var player_claimed_occurrence_id: String = ""

## Player contract cargo mirror for runtime contract flow (EMPTY/LOADED).
var player_cargo_tag: String = "EMPTY"

## Player spatial position in the active zone.
var player_position: Vector3 = Vector3.ZERO

## Player spatial rotation in the active zone (degrees).
var player_rotation: Vector3 = Vector3.ZERO

## Sector the player just jumped from (for arrival spawn at return jump point).
var player_arrived_from_sector: String = ""

## Direction from sector center toward the jump arrival shell spawn point.
var player_arrival_direction: Vector3 = Vector3.ZERO


# =========================================================================
# === LEGACY (kept for KEPT-system compatibility) ========================
# =========================================================================

## Locations loaded from TemplateDatabase.
var locations: Dictionary = {}

## Faction data loaded from TemplateDatabase.
var factions: Dictionary = {}

## Commodity master data.
var assets_commodities: Dictionary = {}

## Legacy alias for agents dict.
var persistent_agents: Dictionary = {}

## Per-character inventories (legacy).
var inventories: Dictionary = {}

## All ship instances (legacy).
var assets_ships: Dictionary = {}


# =========================================================================
# === RESET ===============================================================
# =========================================================================

## Resets all qualitative simulation fields to defaults.
func reset_state() -> void:
	world_topology.clear()
	world_hazards.clear()
	world_tags.clear()
	world_seed = ""
	grid_dominion.clear()
	sector_tags.clear()
	characters.clear()
	agents.clear()
	agent_tags.clear()
	player_character_uid = ""
	colony_levels.clear()
	colony_upgrade_progress.clear()
	colony_downgrade_progress.clear()
	colony_level_history.clear()
	security_upgrade_progress.clear()
	security_downgrade_progress.clear()
	security_change_threshold.clear()
	economy_upgrade_progress.clear()
	economy_downgrade_progress.clear()
	economy_change_threshold.clear()
	contract_generation_pressure.clear()
	contract_generation_threshold.clear()
	contract_cargo_supply.clear()
	contract_cargo_reserved.clear()
	contract_payment_supply.clear()
	contract_payment_reserved.clear()
	runtime_contract_occurrences.clear()
	runtime_contract_occurrences_by_target_sector.clear()
	runtime_contract_occurrences_by_source_sector.clear()
	hostile_infestation_progress.clear()
	catastrophe_log.clear()
	sector_disabled_until.clear()
	mortal_agent_counter = 0
	mortal_agent_deaths.clear()
	discovered_sector_count = 0
	discovery_log.clear()
	sector_names.clear()
	discovered_sectors.clear()
	station_by_id.clear()
	chronicle_events.clear()
	chronicle_rumors.clear()
	sim_tick_count = 0
	sub_tick_accumulator = 0
	world_age = ""
	world_age_timer = 0
	world_age_cycle_count = 0
	current_sector_id = ""
	player_docked_at = ""
	player_claimed_occurrence_id = ""
	player_cargo_tag = "EMPTY"
	player_arrived_from_sector = ""
	player_arrival_direction = Vector3.ZERO
