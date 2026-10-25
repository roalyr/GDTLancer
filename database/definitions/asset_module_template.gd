# ModuleTemplate: a part fitted in a module slot. Its effect is data: additive stat modifiers on
# the ship, so a new module is a new .tres, not new code.

extends AssetTemplate
class_name ModuleTemplate

export var module_name: String = "Unnamed Module"
export var description: String = ""
export var base_value: int = 10  # WP; buy price at the home station (sells back for half)
export var mass: float = 0.0  # kg, added to the ship
# Stat -> amount added: hull, power_capacity, power_regen, cargo_capacity, linear_thrust,
# angular_thrust, signature (m), sensor_strength.
export var stat_modifiers: Dictionary = {}
# A kinetic lance (ShipLaws.lance_stats; empty for other modules): the seat and its quiver of lances.
export var lance: Dictionary = {}
# Built by ShipLaws: the module's law ("plating", "thruster", "power_cell", "capacitor", "lance"), lineage 1-3
# and genes (empty and 0 for a hand-made one).
export var module_kind: String = ""
export var variant_type: int = 0
export var law_genes: Dictionary = {}
