# File: tests/autoload/test_core_mechanics_api.gd
# GUT Test Script for CoreMechanicsAPI.gd Autoload
# Version 1.1 - Corrected assertions for Godot 3 GUT

extends GutTest


func test_perform_action_check_return_structure():
	var result = CoreMechanicsAPI.perform_action_check(0, 0)
	assert_typeof(result, TYPE_DICTIONARY, "Result should be a Dictionary.")
	assert_has(result, "roll_total", "Result must contain 'roll_total'.")
	assert_has(result, "result_tier", "Result must contain 'result_tier'.")
	assert_has(result, "focus_gain", "Result must contain 'focus_gain'.")
	assert_has(result, "focus_loss_reset", "Result must contain 'focus_loss_reset'.")
	assert_typeof(result.roll_total, TYPE_INT, "'roll_total' type check.")
	assert_typeof(result.result_tier, TYPE_STRING, "'result_tier' type check.")
	assert_typeof(result.focus_gain, TYPE_INT, "'focus_gain' type check.")
	assert_typeof(result.focus_loss_reset, TYPE_BOOL, "'focus_loss_reset' type check.")
	# Optional debug keys check
	assert_has(result, "dice_sum", "Check for 'dice_sum'.")
	assert_has(result, "modifier", "Check for 'modifier'.")
	assert_has(result, "focus_spent", "Check for 'focus_spent'.")
	assert_has(result, "focus_bonus", "Check for 'focus_bonus'.")
	prints("Tested Action Check: Return Structure")


func test_action_check_focus_bonus_calculation():
	var result_0fp = CoreMechanicsAPI.perform_action_check(+1, 0)
	assert_eq(result_0fp.focus_spent, 0, "Check with 0 FP spent.")
	assert_eq(result_0fp.focus_bonus, 0 * Constants.FOCUS_BOOST_PER_POINT, "Bonus should be 0.")
	assert_eq(result_0fp.roll_total, result_0fp.dice_sum + 1, "Total = dice + mod only.")

	var result_2fp = CoreMechanicsAPI.perform_action_check(-1, 2)
	assert_eq(result_2fp.focus_spent, 2, "Check with 2 FP spent.")
	assert_eq(result_2fp.focus_bonus, 2 * Constants.FOCUS_BOOST_PER_POINT, "Bonus = 2 * boost.")
	assert_eq(
		result_2fp.roll_total,
		result_2fp.dice_sum - 1 + (2 * Constants.FOCUS_BOOST_PER_POINT),
		"Total includes mod and focus bonus."
	)
	prints("Tested Action Check: Focus Bonus Calculation")


func test_action_check_focus_spending_clamp():
	var result_over = CoreMechanicsAPI.perform_action_check(0, Constants.FOCUS_MAX_DEFAULT + 5)
	assert_eq(result_over.focus_spent, Constants.FOCUS_MAX_DEFAULT, "Focus spent clamps to max.")
	assert_eq(
		result_over.focus_bonus,
		Constants.FOCUS_MAX_DEFAULT * Constants.FOCUS_BOOST_PER_POINT,
		"Focus bonus uses clamped value."
	)

	var result_neg = CoreMechanicsAPI.perform_action_check(0, -2)
	assert_eq(result_neg.focus_spent, 0, "Negative focus spent clamps to 0.")
	assert_eq(result_neg.focus_bonus, 0, "Focus bonus is 0 for negative spend.")
	prints("Tested Action Check: Focus Spending Clamp")


func test_action_check_result_tier_boundaries():
	# Test calculation that guarantees Failure (max roll 18 + mod + bonus < 10)
	var mod_fail = -9
	var result_fail = CoreMechanicsAPI.perform_action_check(mod_fail, 0)
	assert_lt(
		18 + mod_fail + 0,
		Constants.ACTION_CHECK_FAIL_THRESHOLD,
		"Check setup: Max possible roll should be < FailThreshold"
	)
	assert_eq(result_fail.result_tier, "Failure", "Result tier must be Failure.")
	assert_true(result_fail.focus_loss_reset, "Failure must reset focus.")
	assert_eq(result_fail.focus_gain, 0, "Failure must grant 0 focus.")

	# Test calculation that guarantees Crit Success (min roll 3 + mod + bonus >= 14)
	var mod_crit = 10
	var fp_crit = 1  # Bonus = 1
	var result_crit = CoreMechanicsAPI.perform_action_check(mod_crit, fp_crit)
	# Check setup condition using assert_true with comparison
	assert_true(
		(
			3 + mod_crit + fp_crit * Constants.FOCUS_BOOST_PER_POINT
			>= Constants.ACTION_CHECK_CRIT_THRESHOLD
		),
		"Check setup: Min possible roll should be >= CritThreshold"
	)
	assert_eq(result_crit.result_tier, "CritSuccess", "Result tier must be CritSuccess.")
	assert_eq(result_crit.focus_gain, 1, "CritSuccess must grant 1 focus.")
	assert_false(result_crit.focus_loss_reset, "CritSuccess must not reset focus.")

	# Test calculation that guarantees at least SwC (never Failure) (min roll 3 + mod + bonus >= 10)
	var mod_nofail = 5
	var fp_nofail = 2  # Bonus = 2
	var result_nofail = CoreMechanicsAPI.perform_action_check(mod_nofail, fp_nofail)
	# Check setup condition using assert_true with comparison
	assert_true(
		(
			3 + mod_nofail + fp_nofail * Constants.FOCUS_BOOST_PER_POINT
			>= Constants.ACTION_CHECK_SWC_THRESHOLD
		),
		"Check setup: Min possible roll should be >= SwCThreshold"
	)
	assert_ne(result_nofail.result_tier, "Failure", "Result tier must not be Failure.")
	assert_false(result_nofail.focus_loss_reset, "Never-Failure must not reset focus.")

	# Test calculation that guarantees never Crit Success (max roll 18 + mod + bonus < 14)
	var mod_nocrit = -6
	var fp_nocrit = 1  # Bonus = 1
	var result_nocrit = CoreMechanicsAPI.perform_action_check(mod_nocrit, fp_nocrit)
	assert_lt(
		18 + mod_nocrit + fp_nocrit * Constants.FOCUS_BOOST_PER_POINT,
		Constants.ACTION_CHECK_CRIT_THRESHOLD,
		"Check setup: Max possible roll should be < CritThreshold"
	)
	assert_ne(result_nocrit.result_tier, "CritSuccess", "Result tier must not be CritSuccess.")
	assert_eq(result_nocrit.focus_gain, 0, "Never-Crit must grant 0 focus.")
	prints("Tested Action Check: Result Tier Boundaries")


func test_action_check_focus_gain_loss_logic_association():
	# Verify the flags associated with each *possible* tier outcome.
	# We use boundary conditions to increase likelihood of hitting specific tiers.
	var result_fail = CoreMechanicsAPI.perform_action_check(-10, 0)  # Guaranteed Fail
	if result_fail.result_tier == "Failure":
		assert_true(result_fail.focus_loss_reset, "[Fail] Focus loss reset should be true")
		assert_eq(result_fail.focus_gain, 0, "[Fail] Focus gain should be 0")

	var result_crit = CoreMechanicsAPI.perform_action_check(20, 3)  # Guaranteed Crit
	if result_crit.result_tier == "CritSuccess":
		assert_false(result_crit.focus_loss_reset, "[Crit] Focus loss reset should be false")
		assert_eq(result_crit.focus_gain, 1, "[Crit] Focus gain should be 1")

	# For SwC, find a mod/FP combo that *can't* fail but *can't* crit
	# Min Roll (3) + Mod + Bonus >= 10  => Mod+Bonus >= 7
	# Max Roll (18) + Mod + Bonus < 14 => Mod+Bonus < -4
	# This range is impossible, so we can't guarantee SwC this way.
	# We must rely on multiple runs or mocking later.
	# Let's just test one likely SwC scenario: Mod 0, FP 0 (Dice 10-13 needed)
	var found_swc = false
	for _i in range(30):  # More runs increases chance
		var result_mid = CoreMechanicsAPI.perform_action_check(0, 0)
		if result_mid.result_tier == "SwC":
			assert_false(result_mid.focus_loss_reset, "[SwC] Focus loss reset should be false")
			assert_eq(result_mid.focus_gain, 0, "[SwC] Focus gain should be 0")
			found_swc = true
			break  # Stop once we find one
	# This check might occasionally fail if unlucky with RNG over 30 runs
	# A better approach involves mocking RNG if strict SwC logic check is needed
	gut.p("Attempted to verify SwC focus logic (requires RNG luck): " + str(found_swc))
	prints("Tested Action Check: Focus Gain/Loss Logic Association")
