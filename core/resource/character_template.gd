# File: core/resource/character_template.gd
# Purpose: Defines the data structure for a single character linked to an agent.
# Version: 1.0

extends Template
class_name CharacterTemplate

export var character_name: String = "Unnamed"
export var character_icon_id: String = "character_default_icon"
export var faction_id: String = "faction_default" # Affiliation

export var wealth_points: int = 0
export var focus_points: int = 0
export var active_ship_uid: int = -1

export var skills: Dictionary = {
	"piloting": 1,
	"combat": 1,
	"trading": 1
}

# --- Narrative Stubs ---
export var age: int = 30
export var reputation: int = 0
export var faction_standings: Dictionary = {} # e.g., {"pirates": -10, "corp": 5}
export var character_standings: Dictionary = {} # For relationships

