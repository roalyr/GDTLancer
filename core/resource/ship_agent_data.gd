# File: core/resource/agent/ship_agent_data.gd
# Purpose: Defines the template for a class of ship, specializing the base AgentTemplate.
# Version: 1.3 - Using direct path for extends to improve test stability

extends "res://core/agents/agent_template.gd" # <-- THE FIX: Use the direct file path.
class_name ShipAgentData

# --- Ship-Specific Identity & Description ---
export var ship_class_name: String = "Default Ship Class"
export var description: String = "A standard vessel."

# --- Ship-Specific Base Stats (Blueprint Values) ---
export var base_hull_integrity: int = 100
export var base_shields: int = 50
export var base_cargo_capacity: int = 50

# --- NOTE ---
# All other stats are still inherited from AgentTemplate. This change only affects
# how the script is loaded by the engine, not its functionality.
