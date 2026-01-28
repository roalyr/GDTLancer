#
# PROJECT: GDTLancer
# MODULE: CoreMechanicsAPI.gd
# STATUS: Level 2 - Implementation
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-27-Senior-Dev
#

extends Node

# Random Number Generator for dice rolls
var _rng = RandomNumberGenerator.new()


func _ready():
	# Seed the random number generator once when the game starts
	_rng.randomize()
	print("CoreMechanicsAPI Ready.")


# --- Core Action Resolution ---


# Performs the standard Action Check.
# - attribute_value: The character's core attribute value (e.g., INT 4).
# - skill_level: The character's relevant skill level (e.g., Computers 2).
# - focus_points_spent: How many FP the player chose to spend (0-3).
# - action_approach: The method used, from Constants.ActionApproach.
# Returns a Dictionary containing the detailed results of the check.
func perform_action_check(
	attribute_value: int, skill_level: int, focus_points_spent: int, action_approach: int
) -> Dictionary:
	# Clamp focus spent to be within a valid range.
	focus_points_spent = clamp(focus_points_spent, 0, Constants.FOCUS_MAX_DEFAULT)

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
	var focus_bonus = focus_points_spent * Constants.FOCUS_BOOST_PER_POINT
	var total_roll = dice_sum + module_modifier + focus_bonus

	# --- Determine Outcome Tier & Focus Effects ---
	var result_tier: String
	var tier_name: String
	var focus_gain = 0
	var focus_loss_reset = false

	if total_roll >= crit_threshold:
		result_tier = "CritSuccess"
		tier_name = "Critical Success"
		focus_gain = 1
	elif total_roll >= swc_threshold:
		result_tier = "SwC"
		tier_name = "Success with Complication"
	else:
		result_tier = "Failure"
		tier_name = "Failure"
		focus_loss_reset = true

	# --- Assemble Results Dictionary ---
	var results = {
		"roll_total": total_roll,
		"dice_sum": dice_sum,
		"modifier": module_modifier,
		"focus_spent": focus_points_spent,
		"focus_bonus": focus_bonus,
		"result_tier": result_tier,
		"tier_name": tier_name,  # Added for user-facing display
		"focus_gain": focus_gain,
		"focus_loss_reset": focus_loss_reset
	}

	# print("Action Check: %d (3d6=%d, Mod=%d, FP=%d(+%d)) -> %s" % [total_roll, dice_sum, module_modifier, focus_points_spent, focus_bonus, tier_name]) # Debug

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
