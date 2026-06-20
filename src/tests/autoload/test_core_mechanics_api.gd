# PROJECT: GDTLancer
# MODULE: test_core_mechanics_api.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1; TRUTH_PROJECT.md § Automated Testing Boundary
# LOG_REF: 2026-06-20 19:48:00

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


func test_wealth_modifier_shifts_roll():
	# Seed the RNG to be identical before each check to get exactly identical dice rolls
	CoreMechanicsAPI._rng.seed = 12345
	var result_default = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_comfortable = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, 0)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_broke = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, -2)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_wealthy = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, 2)
	
	# Verify values
	assert_eq(result_default.roll_total, result_comfortable.roll_total, "Omitting modifier defaults to 0.")
	assert_eq(result_broke.roll_total, result_comfortable.roll_total - 2, "Broke modifier shifts total down by 2.")
	assert_eq(result_wealthy.roll_total, result_comfortable.roll_total + 2, "Wealthy modifier shifts total up by 2.")
	
	# Verify returned dict key
	assert_eq(result_default.wealth_modifier, 0, "Default wealth_modifier key is 0.")
	assert_eq(result_comfortable.wealth_modifier, 0, "Comfortable wealth_modifier key is 0.")
	assert_eq(result_broke.wealth_modifier, -2, "Broke wealth_modifier key is -2.")
	assert_eq(result_wealthy.wealth_modifier, 2, "Wealthy wealth_modifier key is 2.")
	prints("Tested Action Check: Wealth Modifier Shifts Roll")


func test_health_modifier_shifts_roll():
	# Seed the RNG to be identical before each check to get exactly identical dice rolls
	CoreMechanicsAPI._rng.seed = 12345
	var result_default = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_healthy = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, 0, 0)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_damaged = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, 0, -2)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_destroyed = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, 0, -4)
	
	# Verify values
	assert_eq(result_default.roll_total, result_healthy.roll_total, "Omitting health modifier defaults to 0.")
	assert_eq(result_damaged.roll_total, result_healthy.roll_total - 2, "Damaged modifier shifts total down by 2.")
	assert_eq(result_destroyed.roll_total, result_healthy.roll_total - 4, "Destroyed modifier shifts total down by 4.")
	
	# Verify returned dict key
	assert_eq(result_default.health_modifier, 0, "Default health_modifier key is 0.")
	assert_eq(result_healthy.health_modifier, 0, "Healthy health_modifier key is 0.")
	assert_eq(result_damaged.health_modifier, -2, "Damaged health_modifier key is -2.")
	assert_eq(result_destroyed.health_modifier, -4, "Destroyed health_modifier key is -4.")
	prints("Tested Action Check: Health Modifier Shifts Roll")


func test_morale_modifier_shifts_roll():
	CoreMechanicsAPI._rng.seed = 12345
	var result_default = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_neutral = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, 0, 0, 0)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_high = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, 0, 0, 2)
	
	CoreMechanicsAPI._rng.seed = 12345
	var result_low = CoreMechanicsAPI.perform_action_check(ATTR, SKILL, CAUTIOUS, 0, 0, -2)
	
	assert_eq(result_default.roll_total, result_neutral.roll_total, "Omitting morale modifier defaults to 0.")
	assert_eq(result_high.roll_total, result_neutral.roll_total + 2, "High morale modifier shifts total up by 2.")
	assert_eq(result_low.roll_total, result_neutral.roll_total - 2, "Low morale modifier shifts total down by 2.")
	
	assert_eq(result_default.morale_modifier, 0, "Default morale_modifier key is 0.")
	assert_eq(result_neutral.morale_modifier, 0, "Neutral morale_modifier key is 0.")
	assert_eq(result_high.morale_modifier, 2, "High morale_modifier key is 2.")
	assert_eq(result_low.morale_modifier, -2, "Low morale_modifier key is -2.")
	prints("Tested Action Check: Morale Modifier Shifts Roll")
