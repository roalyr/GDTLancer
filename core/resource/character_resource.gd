# File: core/resource/character_resource.gd
# Purpose: Defines the data structure for a single character agent.
# Version: 1.0

extends Resource
class_name CharacterResource

# --- Narrative & Identity ---
export var character_name: String = "Unnamed"
export var faction: String = "unaligned" # Should match a key in FactionSystem

# --- Core Stats ---
export var wealth_points: int = 0
export var focus_points: int = 0

# --- Skills ---
# Stored in a dictionary for easy lookup.
export var skills: Dictionary = {
	"piloting": 1,
	"tactics": 1,
	"trading": 1
}

# --- Narrative Stubs ---
export var reputation: int = 0
export var faction_standings: Dictionary = {} # e.g., {"pirates": -10, "corp": 5}
