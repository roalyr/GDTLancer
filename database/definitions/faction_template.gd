#
# PROJECT: GDTLancer
# MODULE: faction_template.gd
# STATUS: Level 1 - Prototype
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 2.1)
# LOG_REF: 2026-03-01-Impl
#

extends Template
class_name FactionTemplate

# The unique identifier for this faction (match template_id pattern, e.g., 'faction_miners')
export var faction_id: String = ""
export var display_name: String = "Unknown Faction"
export var description: String = ""
export var faction_color: Color = Color(1, 1, 1, 1)

# Base standing for new players (0 is neutral)
export var default_standing: int = 0
