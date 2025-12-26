# File: core/resource/ship_template.gd
# Purpose: Defines ships.
# Version: 2.0 - RigidBody physics with thrust-based 6DOF flight.

extends AssetTemplate
class_name ShipTemplate

export var ship_model_name: String = "Default Ship Model" 
export var hull_integrity: int = 100
export var armor_integrity: int = 100
export var cargo_capacity: int = 100
export var interaction_radius: float = 15.0

export var ship_quirks: Array = [] # De-buffs or narrative elements
export var ship_upgrades: Array = [] # Buffs

# --- Weapon Mounts ---
export var weapon_slots_small: int = 2  # Number of small weapon mounts
export var weapon_slots_medium: int = 0  # Number of medium weapon mounts
export var weapon_slots_large: int = 0  # Number of large weapon mounts
export var equipped_weapons: Array = []  # Array of weapon template_ids

# --- Power ---
export var power_capacity: float = 100.0
export var power_regen: float = 10.0  # Per second

# --- RigidBody Physics (6DOF Flight) ---
export var mass: float = Constants.DEFAULT_SHIP_MASS
export var linear_thrust: float = Constants.DEFAULT_LINEAR_THRUST  # Forward/backward/strafe thrust force
export var angular_thrust: float = Constants.DEFAULT_ANGULAR_THRUST  # Rotational torque
export var alignment_threshold_angle_deg: float = Constants.DEFAULT_ALIGNMENT_ANGLE_THRESHOLD

# TODO: add fields which link to specific scenes that define each ship model?
