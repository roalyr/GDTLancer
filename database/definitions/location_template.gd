#
# PROJECT: GDTLancer
# MODULE: location_template.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 2 (World Layer)
# LOG_REF: 2026-02-13
#

extends Template
class_name LocationTemplate

## LocationTemplate: Defines a sector/location including its World Layer physical properties.
## Used both as scene-level location data AND as the source for simulation Layer 1 initialization.

# --- Identity & Scene ---
export var location_name: String = "Unknown Station"
export var location_type: String = "station"  # station, outpost, debris_field, asteroid_field
export var position_in_zone: Vector3 = Vector3.ZERO
export var interaction_radius: float = 100.0  # How close player must be to dock

# --- World Layer: Topology (Section 2) ---
## IDs of sectors this location connects to (defines the sector graph for CA neighbors).
export var connections: PoolStringArray = PoolStringArray()
## Classification: hub / frontier / deep_space / hazard_zone
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

# --- World Layer: Station Infrastructure ---
## Power output capacity of station infrastructure.
export var station_power_output: float = 100.0
## Maximum commodity stockpile the station can hold.
export var stockpile_capacity: int = 1000

# --- Market & Services (legacy, used by scene-level systems) ---
# Market inventory: commodity_template_id -> {price: int, quantity: int}
export var market_inventory: Dictionary = {}
export var available_services: Array = ["trade", "contracts"]

# --- Faction Control ---
export var controlling_faction_id: String = ""

# --- Danger (legacy, superseded by grid_dominion.pirate_activity) ---
export var danger_level: int = 0

# --- Contracts (legacy, will be rebuilt on Agent layer) ---
export var available_contract_ids: Array = []
