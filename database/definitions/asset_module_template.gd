# ModuleTemplate: a part fitted in a module slot. Its effect is data: additive stat modifiers on
# the ship, so a new module is a new .tres, not new code.

extends AssetTemplate
class_name ModuleTemplate

export var module_name: String = "Unnamed Module"
export var description: String = ""
export var base_value: int = 10  # WP; buy price at the home station (sells back for half)
export var mass: float = 0.0  # kg, added to the ship
# Stat -> amount added: hull, power_capacity, power_regen, cargo_capacity, linear_thrust, angular_thrust.
export var stat_modifiers: Dictionary = {}
