
#
# PROJECT: GDTLancer
# MODULE: database/definitions/quirk_template.gd
# STATUS: [Level 3 - Verified]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2025-10-31.md Section 2.1 Milestone 1
# LOG_REF: 2025-12-23
#

extends Resource
class_name QuirkTemplate

## Resource definition for Ship Quirks.
## Ship Quirks are negative traits acquired through damage or failed actions.

# Unique Identifier
export var template_id: String = ""

# Display Properties
export var display_name: String = ""
export var description: String = ""

# Functional Properties
## effect_type examples: "stat_penalty", "turn_rate_multiplier", "move_speed_multiplier"
export var effect_type: String = "" 
export var effect_value: float = 0.0

# Origin category e.g. "combat", "piloting", "trading", "event"
export var source_category: String = "event"
