# File: tests/autoload/test_core_mechanics_api.gd
# GUT Test Script for CoreMechanicsAPI.gd Autoload
# Version 1.2 - Updated for new perform_action_check() signature and ActionApproach

extends GutTest

# --- Test Parameters ---
# Dummy values to be used in tests, improving readability.
const ATTR = 4
const SKILL = 2
const FOCUS = 1
const CAUTIOUS = Constants.ActionApproach.CAUTIOUS
const RISKY = Constants.ActionApproach.RISKY


func test_perform_action_check_return_structure():
	var result = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, FOCUS, CAUTIOUS)
	assert_typeof(result, TYPE_DICTIONARY, "Result should be a Dictionary.")
	assert_has(result, "roll_total", "Result must contain 'roll_total'.")
	assert_has(result, "result_tier", "Result must contain 'result_tier'.")
	assert_has(result, "tier_name", "Result must contain 'tier_name'.")  # New key
	assert_has(result, "focus_gain", "Result must contain 'focus_gain'.")
	assert_has(result, "focus_loss_reset", "Result must contain 'focus_loss_reset'.")
	prints("Tested Action Check: Return Structure")


func test_action_check_focus_bonus_calculation():
	# With 0 focus spent, bonus should be 0.
	var result_0fp = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, 0, CAUTIOUS)
	assert_eq(result_0fp.focus_spent, 0)
	assert_eq(result_0fp.focus_bonus, 0)
	assert_eq(result_0fp.roll_total, result_0fp.dice_sum + ATTR + SKILL)

	# With 2 focus spent, bonus should be 2.
	var result_2fp = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, 2, RISKY)
	assert_eq(result_2fp.focus_spent, 2)
	assert_eq(result_2fp.focus_bonus, 2 * Constants.FOCUS_BOOST_PER_POINT)
	assert_eq(result_2fp.roll_total, result_2fp.dice_sum + ATTR + SKILL + 2)
	prints("Tested Action Check: Focus Bonus Calculation")


func test_action_check_focus_spending_clamp():
	# Spending more than max should clamp down to max.
	var result_over = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, 5, CAUTIOUS)
	assert_eq(result_over.focus_spent, Constants.FOCUS_MAX_DEFAULT)

	# Spending negative should clamp up to 0.
	var result_neg = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, -2, RISKY)
	assert_eq(result_neg.focus_spent, 0)
	prints("Tested Action Check: Focus Spending Clamp")


func test_action_check_tier_boundaries_cautious():
	# To guarantee failure, max roll (18) + mod + bonus must be less than SwC threshold.
	# 18 + mod < 10  => mod < -8. We use -9.
	var result_fail = CoreMechanicsAPI.perform_action_check(-9, 0, 0, CAUTIOUS)
	assert_eq(result_fail.result_tier, "Failure", "[Cautious] Guaranteed failure check.")
	assert_true(result_fail.focus_loss_reset, "[Cautious] Failure should reset focus.")

	# To guarantee critical success, min roll (3) + mod + bonus must be >= Crit threshold.
	# 3 + mod >= 14 => mod >= 11. We use 11.
	var result_crit = CoreMechanicsAPI.perform_action_check(11, 0, 0, CAUTIOUS)
	assert_eq(
		result_crit.result_tier, "CritSuccess", "[Cautious] Guaranteed critical success check."
	)
	assert_eq(result_crit.focus_gain, 1, "[Cautious] Crit should grant focus.")
	prints("Tested Action Check: Cautious Tier Boundaries")


func test_action_check_tier_boundaries_risky():
	# To guarantee failure: 18 + mod < 12 => mod < -6. We use -7.
	var result_fail = CoreMechanicsAPI.perform_action_check(-7, 0, 0, RISKY)
	assert_eq(result_fail.result_tier, "Failure", "[Risky] Guaranteed failure check.")

	# To guarantee critical success: 3 + mod >= 16 => mod >= 13. We use 13.
	var result_crit = CoreMechanicsAPI.perform_action_check(13, 0, 0, RISKY)
	assert_eq(result_crit.result_tier, "CritSuccess", "[Risky] Guaranteed critical success check.")
	prints("Tested Action Check: Risky Tier Boundaries")
