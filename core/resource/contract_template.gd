# contract_template.gd
# Data structure for contracts - delivery, combat, exploration missions
extends "res://core/resource/template.gd"
class_name ContractTemplate

# Contract identification
export var contract_type: String = "delivery"  # delivery, combat, exploration
export var title: String = "Unnamed Contract"
export var description: String = ""

# Contract parties
export var issuer_id: String = ""      # Contact/NPC ID who gave the contract
export var faction_id: String = ""     # Faction associated with contract

# Location requirements
export var origin_location_id: String = ""       # Where contract was accepted
export var destination_location_id: String = ""  # Where to deliver/complete

# Delivery requirements (for delivery type)
export var required_commodity_id: String = ""
export var required_quantity: int = 0

# Combat requirements (for combat type)
export var target_type: String = ""    # e.g., "pirate", "hostile"
export var target_count: int = 0

# Rewards
export var reward_wp: int = 0
export var reward_reputation: int = 0
export var reward_items: Dictionary = {}  # template_id -> quantity

# Constraints
export var time_limit_tu: int = -1     # -1 = no limit
export var difficulty: int = 1         # 1-5 scale for filtering/matching

# Runtime state (set when contract is active)
export var accepted_at_tu: int = -1    # When player accepted
export var progress: Dictionary = {}   # Track partial completion


# Check if contract has expired based on current time
func is_expired(current_tu: int) -> bool:
	if time_limit_tu < 0:
		return false
	if accepted_at_tu < 0:
		return false
	return (current_tu - accepted_at_tu) >= time_limit_tu


# Get remaining time in TU, -1 if no limit
func get_remaining_time(current_tu: int) -> int:
	if time_limit_tu < 0:
		return -1
	if accepted_at_tu < 0:
		return time_limit_tu
	var elapsed = current_tu - accepted_at_tu
	return int(max(0, time_limit_tu - elapsed))


# Create a summary for UI display
func get_summary() -> Dictionary:
	return {
		"title": title,
		"type": contract_type,
		"destination": destination_location_id,
		"reward_wp": reward_wp,
		"difficulty": difficulty,
		"has_time_limit": time_limit_tu > 0
	}
