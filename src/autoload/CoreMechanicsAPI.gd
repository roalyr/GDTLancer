# PROJECT: GDTLancer
# MODULE: CoreMechanicsAPI.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
# LOG_REF: 2026-06-14 02:24:48

extends Node

## CoreMechanicsAPI: Stateless API for dice rolling and action check resolution.
## Implements 3d6 rolls with attribute/skill modifiers and approach-based thresholds.

# Random Number Generator for dice rolls
var _rng = RandomNumberGenerator.new()


func _ready():
	# Seed the random number generator once when the game starts
	_rng.randomize()
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("CoreMechanicsAPI Ready.")


# --- Core Action Resolution ---


# Performs the standard Action Check.
# - attribute_value: The character's core attribute value (e.g., INT 4).
# - skill_level: The character's relevant skill level (e.g., Computers 2).
# - action_approach: The method used, from Constants.ActionApproach.
# - wealth_modifier: Optional modifier based on character wealth tier.
# - health_modifier: Optional modifier based on character health/condition tag.
# Returns a Dictionary containing the detailed results of the check.
func perform_action_check(
	attribute_value: int, skill_level: int, action_approach: int, wealth_modifier: int = 0, health_modifier: int = 0
) -> Dictionary:

	# --- Determine Thresholds based on Approach ---
	var crit_threshold: int
	var swc_threshold: int  # Success with Complication

	if action_approach == Constants.ActionApproach.RISKY:
		crit_threshold = Constants.ACTION_CHECK_CRIT_THRESHOLD_RISKY
		swc_threshold = Constants.ACTION_CHECK_SWC_THRESHOLD_RISKY
	elif action_approach == Constants.ActionApproach.NEUTRAL:
		crit_threshold = Constants.ACTION_CHECK_CRIT_THRESHOLD_NEUTRAL
		swc_threshold = Constants.ACTION_CHECK_SWC_THRESHOLD_NEUTRAL
	else:  # Default to CAUTIOUS
		crit_threshold = Constants.ACTION_CHECK_CRIT_THRESHOLD_CAUTIOUS
		swc_threshold = Constants.ACTION_CHECK_SWC_THRESHOLD_CAUTIOUS

	# --- Roll Dice ---
	var d1 = _rng.randi_range(1, 6)
	var d2 = _rng.randi_range(1, 6)
	var d3 = _rng.randi_range(1, 6)
	var dice_sum = d1 + d2 + d3

	# --- Calculate Bonuses & Final Roll ---
	var module_modifier = attribute_value + skill_level
	var total_roll = dice_sum + module_modifier + wealth_modifier + health_modifier

	# --- Determine Outcome Tier ---
	var result_tier: String
	var tier_name: String

	if total_roll >= crit_threshold:
		result_tier = "CritSuccess"
		tier_name = "Critical Success"
	elif total_roll >= swc_threshold:
		result_tier = "SwC"
		tier_name = "Success with Complication"
	else:
		result_tier = "Failure"
		tier_name = "Failure"

	# --- Assemble Results Dictionary ---
	var results = {
		"roll_total": total_roll,
		"dice_sum": dice_sum,
		"modifier": module_modifier,
		"wealth_modifier": wealth_modifier,
		"health_modifier": health_modifier,
		"result_tier": result_tier,
		"tier_name": tier_name,  # Added for user-facing display
	}

	return results


# --- Potential Future Core Mechanic Functions ---

# func update_focus_state(agent_stats_ref, focus_change: int):
#       # Central logic for applying focus gain/loss, respecting cap
#       pass

# func calculate_upkeep_cost(agent_assets_ref):
#       # Central logic for determining periodic Credits upkeep cost
#       return 0 # Placeholder Credits cost

# func advance_time_clock(agent_stats_ref_or_global, tu_amount: int):
#       # Central logic for adding TU and checking for World Event Tick trigger
#       pass
