# GameStartTemplate: starting ship and location for a new run.

extends Template
class_name GameStartTemplate

export var player_ship_template: String = "ship_default"  # The ship the run starts in: a hull id (database/registry/assets/ships/, or an archetype's preset_ship_archetype_<name>)
export var player_starting_location: String = ""  # The haven the run starts docked at and calls home: a haven_id (a HavenMarker in a sector layout), not a sector's Location id
export var starting_bank: int = 0  # WP banked at the start of the run (start_default: a few thousand, with the ship's standard fit)
# Spare parts in the home storage at the start ({part id: count}), to refit from: the starter pack.
# Only at a new run: a lost ship comes back with its standard fit, never a new pack.
export var starting_storage: Dictionary = {}
export var starting_standing: Dictionary = {}  # Faction id -> the player's standing at the start (-1..1), instead of the faction's own starting_standing
