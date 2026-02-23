#
# PROJECT: GDTLancer
# MODULE: database/definitions/character_template.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md Section 3 (Architecture)
# LOG_REF: 2026-01-30
#

extends Template
class_name CharacterTemplate

## CharacterTemplate: Resource definition for character instances.
## Stores name, credits, FP, skills, and active ship reference.

export var character_name: String = "Unnamed"
export var character_icon_id: String = "character_default_icon"
export var faction_id: String = "faction_default" # Affiliation

export var credits: int = 0
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

# Personality & Goals (Task 2)
export var personality_traits: Dictionary = {} # e.g., {"risk_tolerance": 0.7, "greed": 0.5, "loyalty": 0.6, "aggression": 0.3}
export var description: String = "" # Lore/bio text
export var goals: Array = [] # Current goals (for future Goal System integration)

# --- Qualitative Simulation ---
export var initial_condition_tag: String = "HEALTHY"
export var initial_wealth_tag: String = "COMFORTABLE"

