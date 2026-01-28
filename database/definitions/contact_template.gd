#
# PROJECT: GDTLancer
# MODULE: contact_template.gd
# STATUS: Level 1 - Prototype
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 2.1)
# LOG_REF: 2026-03-01-Impl
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
