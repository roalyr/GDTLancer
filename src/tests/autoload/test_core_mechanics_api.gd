# PROJECT: GDTLancer
# MODULE: test_core_mechanics_api.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: gameplay_milestone_audit.md
# LOG_REF: 2026-06-12 23:10:00

extends GutTest

# --- Test Parameters ---
# Dummy values to be used in tests, improving readability.
const ATTR = 4
const SKILL = 2
const CAUTIOUS = Constants.ActionApproach.CAUTIOUS
const NEUTRAL = Constants.ActionApproach.NEUTRAL
const RISKY = Constants.ActionApproach.RISKY


func test_neutral_approach_thresholds():
	# Test Neutral thresholds via perform_action_check
	# To guarantee failure: 18 + mod < 11 => mod < -7. We use -8.
	var result_fail = CoreMechanicsAPI.perform_action_check(-8, 0, NEUTRAL)
	assert_eq(result_fail.result_tier, "Failure", "[Neutral] Guaranteed failure check.")

	# To guarantee critical success: 3 + mod >= 15 => mod >= 12. We use 12.
	var result_crit = CoreMechanicsAPI.perform_action_check(12, 0, NEUTRAL)
	assert_eq(result_crit.result_tier, "CritSuccess", "[Neutral] Guaranteed critical success check.")
	prints("Tested Action Check: Neutral Tier Boundaries")


func test_stakes_constants():
	assert_eq(Constants.ActionStakes.HIGH_STAKES, 0)
	assert_eq(Constants.ActionStakes.NARRATIVE, 1)
	assert_eq(Constants.ActionStakes.MUNDANE, 2)
	prints("Tested Action Stakes Enum Values")


func test_perform_action_check_return_structure():
	var result = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS)
	assert_typeof(result, TYPE_DICTIONARY, "Result should be a Dictionary.")
	assert_has(result, "roll_total", "Result must contain 'roll_total'.")
	assert_has(result, "result_tier", "Result must contain 'result_tier'.")
	assert_has(result, "tier_name", "Result must contain 'tier_name'.")
	prints("Tested Action Check: Return Structure")


func test_action_check_tier_boundaries_cautious():
	# To guarantee failure, max roll (18) + mod + bonus must be less than SwC threshold.
	# 18 + mod < 10  => mod < -8. We use -9.
	var result_fail = CoreMechanicsAPI.perform_action_check(-9, 0, CAUTIOUS)
	assert_eq(result_fail.result_tier, "Failure", "[Cautious] Guaranteed failure check.")

	# To guarantee critical success, min roll (3) + mod + bonus must be >= Crit threshold.
	# 3 + mod >= 14 => mod >= 11. We use 11.
	var result_crit = CoreMechanicsAPI.perform_action_check(11, 0, CAUTIOUS)
	assert_eq(
		result_crit.result_tier, "CritSuccess", "[Cautious] Guaranteed critical success check."
	)
	prints("Tested Action Check: Cautious Tier Boundaries")


func test_action_check_tier_boundaries_risky():
	# To guarantee failure: 18 + mod < 12 => mod < -6. We use -7.
	var result_fail = CoreMechanicsAPI.perform_action_check(-7, 0, RISKY)
	assert_eq(result_fail.result_tier, "Failure", "[Risky] Guaranteed failure check.")

	# To guarantee critical success: 3 + mod >= 16 => mod >= 13. We use 13.
	var result_crit = CoreMechanicsAPI.perform_action_check(13, 0, RISKY)
	assert_eq(result_crit.result_tier, "CritSuccess", "[Risky] Guaranteed critical success check.")
	prints("Tested Action Check: Risky Tier Boundaries")
