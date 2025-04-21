# File: autoload/CoreMechanicsAPI.gd
# Autoload Singleton: CoreMechanicsAPI
# Purpose: Provides globally accessible functions for core mechanic resolutions,
#          ensuring consistency across the game.
# Version: 1.0

extends Node

# Random Number Generator for dice rolls
var _rng = RandomNumberGenerator.new()

func _ready():
	# Seed the random number generator once when the game starts
	_rng.randomize()
	print("CoreMechanicsAPI Ready.")

# --- Core Action Resolution ---

# Performs the standard 3d6+Mod Action Check based on passed parameters.
# Returns a Dictionary containing the detailed results of the check.
# - module_modifier: The calculated modifier for the current action context (Skill + Asset Diff).
# - focus_points_spent: How many FP the player chose to spend (0-3) *before* the roll.
# Return Dictionary keys:
#   "roll_total": int (Final result after mods/FP)
#   "dice_sum": int (Result of 3d6 only)
#   "modifier": int (Module modifier passed in)
#   "focus_spent": int (FP spent)
#   "focus_bonus": int (Bonus gained from FP)
#   "result_tier": String ("CritSuccess", "SwC", "Failure")
#   "focus_gain": int (FP gained from this result, usually 1 on Crit)
#   "focus_loss_reset": bool (True if FP should be reset to 0 due to Failure)
func perform_action_check(module_modifier: int, focus_points_spent: int) -> Dictionary:
	# Ensure focus spent is within valid range (0 to Max FP defined in Constants)
	focus_points_spent = clamp(focus_points_spent, 0, Constants.FOCUS_MAX_DEFAULT)

	# --- Roll Dice ---
	var d1 = _rng.randi_range(1, 6)
	var d2 = _rng.randi_range(1, 6)
	var d3 = _rng.randi_range(1, 6)
	var dice_sum = d1 + d2 + d3

	# --- Calculate Bonuses ---
	var focus_bonus = focus_points_spent * Constants.FOCUS_BOOST_PER_POINT

	# --- Calculate Final Roll ---
	var total_roll = dice_sum + module_modifier + focus_bonus

	# --- Determine Outcome Tier & Focus Effects ---
	var result_tier = ""
	var focus_gain = 0
	var focus_loss_reset = false

	if total_roll >= Constants.ACTION_CHECK_CRIT_THRESHOLD:
		result_tier = "CritSuccess"
		focus_gain = 1 # Standard gain on Crit
		focus_loss_reset = false
	elif total_roll >= Constants.ACTION_CHECK_SWC_THRESHOLD: # e.g., 10-13
		result_tier = "SwC" # Success with Complication
		focus_gain = 0
		focus_loss_reset = false
	else: # e.g., < 10
		result_tier = "Failure"
		focus_gain = 0
		focus_loss_reset = true # Standard reset on Failure

	# --- Assemble Results Dictionary ---
	var results = {
		"roll_total": total_roll,
		"dice_sum": dice_sum,
		"modifier": module_modifier,
		"focus_spent": focus_points_spent,
		"focus_bonus": focus_bonus,
		"result_tier": result_tier,
		"focus_gain": focus_gain,
		"focus_loss_reset": focus_loss_reset
	}

	# --- Optional: Emit Global Signal ---
	# If many systems need to react directly to *every* check result,
	# emitting a signal here could be useful later. Requires passing agent + approach.
	# EventBus.emit_signal("action_check_resolved", agent_ref, results, approach_ref)
	# For now, let the calling script handle reactions and FP updates.

	# print("Action Check: %d (3d6=%d, Mod=%d, FP=%d(+%d)) -> %s" % [total_roll, dice_sum, module_modifier, focus_points_spent, focus_bonus, result_tier]) # Debug

	return results


# --- Potential Future Core Mechanic Functions ---

# func update_focus_state(agent_stats_ref, focus_change: int):
#     # Central logic for applying focus gain/loss, respecting cap
#     pass

# func calculate_upkeep_cost(agent_assets_ref):
#     # Central logic for determining periodic WP upkeep cost
#     return 0 # Placeholder WP cost

# func advance_time_clock(agent_stats_ref_or_global, tu_amount: int):
#     # Central logic for adding TU and checking for World Event Tick trigger
#     pass
