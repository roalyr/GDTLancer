# File: core/resources/action_resource.gd
# Purpose: Defines the data structure for a character action.
# Version: 1.1 - Added properties for Action Checks.

extends Resource
class_name ActionResource

# The user-facing name of the action.
export var action_name: String = "Unnamed Action"

# The amount of Time Units (TU) required to complete the action.
export var tu_cost: int = 1

# --- Action Check Properties ---

# The base attribute for the check (e.g., "INT", "DEX", "SOC").
export var base_attribute: String = "INT"

# The associated skill for the check (e.g., "Piloting", "Mechanics").
export var associated_skill: String = "Computers"
