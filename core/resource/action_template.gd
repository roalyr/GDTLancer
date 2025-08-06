# File: core/resources/action_template.gd
# Purpose: Defines the data structure for an agent action.
# Version: 1.1 - Added properties for Action Checks.

extends Template
class_name ActionTemplate

export var action_name: String = "Unnamed Action"
export var tu_cost: int = 1
export var base_attribute: String = "int" # stub
export var associated_skill: String = "computers" # stub
