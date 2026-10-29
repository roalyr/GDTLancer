# GameStartTemplate: starting ship and location for a new run.

extends Template
class_name GameStartTemplate

export var player_ship_template: String = "ship_default"
export var player_starting_location: String = ""  # Station location_id the run starts docked at; also the run's home port
export var starting_bank: int = 0  # WP banked at the start of the run (start_default: a few thousand, with the ship's standard fit)
# Spare parts in the home storage at the start ({part id: count}), to refit from: the starter pack.
# Only at a new run: a lost ship comes back with its standard fit, never a new pack.
export var starting_storage: Dictionary = {}
