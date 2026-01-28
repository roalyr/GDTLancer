#
# PROJECT: GDTLancer
# MODULE: contract_template.gd
# STATUS: Level 2 - Implementation
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-27-Senior-Dev
#

extends "res://database/definitions/template.gd"
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
export var reward_credits: int = 0
export var reward_reputation: int = 0
export var reward_items: Dictionary = {}  # template_id -> quantity

# Constraints
export var time_limit_seconds: int = -1  # -1 = no limit
export var difficulty: int = 1         # 1-5 scale for filtering/matching

# Runtime state (set when contract is active)
export var accepted_at_seconds: int = -1 # When player accepted
export var progress: Dictionary = {}   # Track partial completion


# Check if contract has expired based on current time
func is_expired(game_time_seconds: int) -> bool:
	if time_limit_seconds < 0:
		return false
	if accepted_at_seconds < 0:
		return false
	return (game_time_seconds - accepted_at_seconds) >= time_limit_seconds


# Get remaining time in seconds, -1 if no limit
func get_remaining_time(game_time_seconds: int) -> int:
	if time_limit_seconds < 0:
		return -1
	if accepted_at_seconds < 0:
		return time_limit_seconds
	var elapsed = game_time_seconds - accepted_at_seconds
	return int(max(0, time_limit_seconds - elapsed))


# Create a summary for UI display
func get_summary() -> Dictionary:
	return {
		"title": title,
		"type": contract_type,
		"destination": destination_location_id,
		"reward_credits": reward_credits,
		"difficulty": difficulty,
		"has_time_limit": time_limit_seconds > 0
	}
