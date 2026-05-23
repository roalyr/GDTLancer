#
# PROJECT: GDTLancer
# MODULE: location_template.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TRUTH_SIMULATION-GRAPH.md §2.1, §6.4; TRUTH_CONTENT-CREATION-MANUAL.md §3.4, §7
# LOG_REF: 2026-05-23 14:59:44
#

extends Template
class_name LocationTemplate

## LocationTemplate: Canonical sector/location resource contract.
## Authored registry entries are sector-level resources keyed by ids such as
## `sector_system_elace`; scene-local dockables remain inside `sector_scene_path`.
## This resource drives sector loading, topology, and the current compatibility
## data consumed by docked UI and bootstrap flows.

# --- Identity & Scene ---
export var location_name: String = "Unknown Station"
export var location_type: String = "station"  # system, outpost, station, debris_field, asteroid_field
export var position_in_zone: Vector3 = Vector3.ZERO  # Optional in-scene dock anchor or interaction point.
export var interaction_radius: float = 100.0  # Dock/interact radius when a scene-level anchor uses this resource directly.

# --- Sector Scene Configuration ---
## Path to the handcrafted sector .tscn. Leave empty only for procedural sectors.
export var sector_scene_path: String = ""
## Galactic position of this sector. Drives starsphere offset and JumpPoint directions.
export var global_position: Vector3 = Vector3.ZERO

# --- Procedural Generation Hints (for runtime-discovered sectors) ---
## If true, this sector has no handcrafted .tscn and uses procedural generation.
export var is_procedural: bool = false
## Type hint for future procedural generator: deep_space, asteroid_field, stellar_approach, nebula_interior, etc.
export var procedural_type: String = "deep_space"
## Generator parameters: {density: float, hazard_type: String, celestial_count: int, etc.}
export var procedural_hints: Dictionary = {}
## Human-readable description of the sector for UI and generator context.
export var sector_description: String = ""

# --- World Layer: Topology (Section 2) ---
## IDs of connected sectors. These define the world-topology graph and jump routes.
export var connections: PoolStringArray = PoolStringArray()
## Classification: colony / outpost / frontier / deep_space / hazard_zone
export var sector_type: String = "frontier"

# --- World Layer: Hazards (Section 2) ---
## Environmental radiation (0.0 = safe, 1.0 = lethal). Increases entropy and wreck degradation.
export var radiation_level: float = 0.0
## Background thermal temperature in Kelvin. 300K = nominal. Deviations increase entropy.
export var thermal_background_k: float = 300.0
## Gravity well multiplier on entropy/maintenance (1.0 = normal, >1 = heavier penalty).
export var gravity_well_penalty: float = 1.0

# --- World Layer: Resource Potential (Section 2) ---
## Finite mineral deposit density. Depleted by extraction over ticks.
export var mineral_density: float = 0.5
## Finite propellant source density. Depleted by extraction over ticks.
export var propellant_sources: float = 0.5

# --- World Layer: Settlement Infrastructure ---
## Power output capacity of the sector's primary service hub / station infrastructure.
export var station_power_output: float = 100.0
## Maximum commodity stockpile the sector's service hub can hold.
export var stockpile_capacity: int = 1000

# --- Market & Services (compatibility boundary for current scene/UI systems) ---
# Market inventory: commodity_template_id -> {buy_price: int, sell_price: int, quantity: int}
export var market_inventory: Dictionary = {}
## Service ids exposed by the current docked UI until service simulation is rebuilt.
export var available_services: Array = ["trade", "contracts"]

# --- Faction Control ---
export var controlling_faction_id: String = ""

# --- Danger (legacy scene/UI hint; superseded by richer simulation state) ---
export var danger_level: int = 0

# --- Qualitative Simulation ---
## Initial sector tags for qualitative tag simulation.
export var initial_sector_tags: PoolStringArray = PoolStringArray()

# --- Contracts (compatibility ids retained until Agent-layer contract flow lands) ---
export var available_contract_ids: Array = []
