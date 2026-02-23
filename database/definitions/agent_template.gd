#
# PROJECT: GDTLancer
# MODULE: database/definitions/agent_template.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md Section 3 (Architecture)
# LOG_REF: 2025-12-23
#

extends Template
class_name AgentTemplate 

export var agent_type: String = "npc" # Defines whether it is controlled by AI or player.

# Persistence Properties
# defined in TACTICAL_TODO.md TASK_1
export var is_persistent: bool = false
export var home_location_id: String = "" # ID of the zone/station/base where this agent respawns
export var character_template_id: String = "" # Link to the CharacterTemplate defining personality/dialogue
export var respawn_timeout_seconds: float = 300.0 # Time in seconds before respawn after being disabled

# --- Qualitative Simulation ---
export var agent_role: String = "idle"
export var initial_tags: PoolStringArray = PoolStringArray()

var agent_uid: int = 0 # Assigned dynamically by agent spawner to link characters, ships, assets to specific agent in space.
