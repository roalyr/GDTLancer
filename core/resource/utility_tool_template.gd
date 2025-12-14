# File: core/resource/utility_tool_template.gd
# Purpose: Defines utility tools (weapons/industrial tools) for ships
# Version: 1.0

extends Resource
class_name UtilityToolTemplate

# --- Identity ---
export var template_id: String = ""
export var tool_name: String = "Unknown Tool"
export var description: String = ""
export var tool_type: String = "weapon"  # "weapon", "mining", "utility", "grapple"

# --- Combat Stats ---
export var damage: float = 10.0
export var range_effective: float = 100.0
export var range_max: float = 150.0
export var fire_rate: float = 1.0  # Shots per second
export var projectile_speed: float = 200.0  # 0 = hitscan
export var accuracy: float = 0.9  # Base hit chance at optimal range (0.0 - 1.0)
export var hull_damage_multiplier: float = 1.0
export var armor_damage_multiplier: float = 1.0

# --- Resource Costs ---
export var energy_per_shot: float = 5.0
export var ammo_type: String = ""  # Empty = unlimited/energy-based
export var ammo_per_shot: int = 1

# --- Timing ---
export var cooldown_time: float = 0.0  # Time between shots beyond fire_rate
export var charge_time: float = 0.0  # Time to charge before firing
export var warmup_time: float = 0.0  # Time to spin up

# --- Special Effects ---
export var effect_type: String = ""  # "disable", "grapple", "breach", etc.
export var effect_strength: float = 0.0
export var effect_duration: float = 0.0

# --- Mount Requirements ---
export var mount_size: String = "small"  # "small", "medium", "large", "turret"
export var power_draw: float = 10.0

# --- Visual/Audio ---
export var projectile_scene: String = ""
export var muzzle_effect: String = ""
export var impact_effect: String = ""
export var fire_sound: String = ""


func get_damage_at_range(distance: float) -> float:
	# Damage falls off beyond effective range
	if distance <= range_effective:
		return damage
	elif distance <= range_max:
		var falloff = 1.0 - ((distance - range_effective) / (range_max - range_effective))
		return damage * falloff
	return 0.0


func get_accuracy_at_range(distance: float) -> float:
	# Accuracy decreases at range
	if distance <= range_effective:
		return accuracy
	elif distance <= range_max:
		var falloff = 1.0 - ((distance - range_effective) / (range_max - range_effective)) * 0.5
		return accuracy * falloff
	return 0.0
