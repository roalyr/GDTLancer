# UtilityToolTemplate: a ship tool. Tools are switched on against a target and cycle on their own;
# the pilot never aims, so results depend on range and on how fast the target crosses the view.

extends Template
class_name UtilityToolTemplate

export var tool_name: String = "Unknown Tool"
export var hud_label: String = ""  # Short name on the tool's HUD button; tool_name if empty
export var description: String = ""
export var tool_type: String = "laser"  # Behaviour: "laser" (damages live ships), "missile" (guided rounds), "cannon" (fixed forward, the ship aims), "harpoon" (tethers wrecks); "drill" is a placeholder.
export var mount_size: String = "small"  # "small", "medium", "large"; fits slots of its size or larger
export var base_value: int = 100  # WP; buy price at the home station (sells back for half)
export var mass: float = 300.0  # kg, added to the ship

export var damage: float = 6.0  # Hull damage per cycle at full hit quality.
export var optimal_range: float = 500.0  # Full hit quality out to this distance (m).
export var falloff: float = 300.0  # Distance past optimal at which hit quality halves (m).
export var tracking: float = 0.2  # Angular velocity of the target (rad/s) at which hit quality halves.
export var cycle_time: float = 1.0  # Seconds per cycle.
export var power_per_cycle: float = 12.0  # Power spent at the start of each cycle (harpoon: per launch).

# Harpoon only. Reach is the same max range as other tools.
export var reel_speed: float = 15.0  # Tether reel-in speed (m/s) after the harpoon hits.
export var launch_speed: float = 0.0  # Harpoon hook flight speed (m/s); 0 = hits at once.
export var strip_interval: float = 1.0  # Seconds per salvage unit stripped once the wreck is reeled in.

# Missile racks and cannons: a magazine of rounds (restocked at a base, salvaged from wrecks).
export var ammo: int = 0  # Rounds a full magazine holds; 0 for tools that need none
export var round_mass: float = 0.0  # kg per round (counted in the tool's mass while loaded)
export var round_value: int = 0  # WP per round
export var projectile_speed: float = 0.0  # m/s: a missile's top speed, a cannon's muzzle speed
export var projectile_accel: float = 0.0  # m/s^2 (missiles)
export var turn_rate: float = 0.0  # rad/s (missiles)
export var flight_time: float = 0.0  # s a round flies

# Lineage 1-3 and genes of a tool built by ShipLaws (0 and empty for a hand-made one).
export var variant_type: int = 0
export var law_genes: Dictionary = {}

# Beyond this distance the tool stays switched on but does not cycle.


func get_max_range() -> float:
	return optimal_range + falloff * Constants.TOOL_MAX_RANGE_FALLOFFS


# EVE-style turret formula without the signature term:
# 0.5 ^ ((angular / tracking)^2 + (max(0, distance - optimal) / falloff)^2)
func get_hit_quality(distance: float, angular_velocity: float) -> float:
	var tracking_term: float = angular_velocity / tracking if tracking > 0.0 else 0.0
	var range_term: float = max(0.0, distance - optimal_range) / falloff if falloff > 0.0 else 0.0
	return pow(0.5, tracking_term * tracking_term + range_term * range_term)
