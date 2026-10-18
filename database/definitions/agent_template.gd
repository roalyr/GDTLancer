# PROJECT: GDTLancer
# MODULE: agent_template.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

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
export var ship_template_id: String = "" # ShipTemplate flown by this agent; the player's comes from GameState.

# Persistence Properties
# defined in TACTICAL_TODO.md TASK_1

# --- Qualitative Simulation ---

