# Defines ships.

extends AssetTemplate
class_name ShipTemplate

export var ship_model_name: String = "Default Ship Model" 
export var base_value: int = 1000  # WP; buy price at the home station (the hull flown is traded in for half)
export(PackedScene) var ship_scene: PackedScene
export var hull_integrity: int = 100
export var cargo_capacity: int = 100
export var interaction_radius: float = 15.0
export var apparent_radius: float = 12.0  # Visual size (m); camera distances and framing scale from it.
export var signature: float = 1500.0  # m; base detectability of the hull (see Constants SIGNATURE block)
export var sensor_strength: float = 1.0  # Detects ships within their signature times this


# --- Tool Mounts ---
export var tool_slots_small: int = 2  # Number of small weapon mounts
export var tool_slots_medium: int = 0  # Number of medium weapon mounts
export var tool_slots_large: int = 0  # Number of large weapon mounts
export var module_slots: int = 2  # Number of module slots
export var equipped_tools: Array = []  # Default fit: UtilityToolTemplate ids, small slots first, then medium, then large
export var equipped_modules: Array = []  # Default fit: ModuleTemplate ids
export var salvage_yield: Dictionary = {}  # Commodity id -> units left in this ship's wreck (plus its cargo)

# --- Power ---
export var power_capacity: float = 100.0
export var power_regen: float = 10.0  # Per second

# --- RigidBody Physics (6DOF Flight) ---
export var mass: float = Constants.DEFAULT_SHIP_MASS
export var linear_thrust: float = Constants.DEFAULT_LINEAR_THRUST  # Forward/backward/strafe thrust force
export var angular_thrust: float = Constants.DEFAULT_ANGULAR_THRUST  # Rotational torque
export var alignment_threshold_angle_deg: float = Constants.DEFAULT_ALIGNMENT_ANGLE_THRESHOLD

# TODO: add fields which link to specific scenes that define each ship model?