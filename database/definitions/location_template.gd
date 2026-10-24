# LocationTemplate: a sector — its scene, galactic position, jump connections and environment.

extends Template
class_name LocationTemplate

# --- Identity & Scene ---
export var location_name: String = "Unknown Station"
export var jump_in_distance: float = 5000.0  # Distance from origin or EntryPoint for spawning / jump-in (+/- 10% variation).
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

# --- Sector Graph ---
## IDs of connected sectors. These define the sector graph and jump routes.
export var connections: PoolStringArray = PoolStringArray()
## system (a whole star system: star, planets, moons, companions) / deep_space / hazard_zone
export var sector_type: String = "system"

# --- Hazards ---
## Environmental radiation (0.0 = safe, 1.0 = lethal).
export var radiation_level: float = 0.0
## Background thermal temperature in Kelvin. 300K = nominal.
export var thermal_background_k: float = 300.0
## Gravity well multiplier (1.0 = normal, >1 = heavier penalty).
export var gravity_well_penalty: float = 1.0

# --- Resource Potential ---
## Mineral deposit density.
export var mineral_density: float = 0.5
## Propellant source density.
export var propellant_sources: float = 0.5

# --- Danger ---
export var danger_level: int = 0
