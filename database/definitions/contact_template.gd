#
# PROJECT: GDTLancer
# MODULE: database/definitions/contact_template.gd
# STATUS: [DEPRECATED]
# DEPRECATION_NOTE: Replaced by AgentTemplate + CharacterTemplate system (See TACTICAL_TODO Task 12)
#                   Contacts are now Persistent Agents.
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md Section 1.1 System 6
# LOG_REF: 2026-01-30
#

extends Template
class_name ContactTemplate

# Unique identifier (e.g., 'contact_kai')
export var contact_id: String = ""
export var display_name: String = "Unknown Contact"
export var description: String = ""

# The faction this contact belongs to (e.g., 'faction_miners')
export var faction_id: String = ""

# The location where this contact can be found (e.g., 'station_alpha')
export var location_id: String = ""

# Initial relationship score (0-100)
export var initial_relationship: int = 0
