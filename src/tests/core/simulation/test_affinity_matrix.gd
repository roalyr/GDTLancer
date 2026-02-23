#
# PROJECT: GDTLancer
# MODULE: test_affinity_matrix.gd  (replaces test_ca_rules.gd)
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1 + TACTICAL_TODO.md TASK_13
# LOG_REF: 2026-02-21 (TASK_13)
#

extends GutTest

## Unit tests for AffinityMatrix: tag vocabulary, affinity scoring, tag derivation.

var affinity: Reference = null


func before_each():
	var Script = load("res://src/core/simulation/affinity_matrix.gd")
	affinity = Script.new()


# =============================================================================
# === compute_affinity ========================================================
# =============================================================================

func test_compute_affinity_positive_pair():
	var score: float = affinity.compute_affinity(["TRADER"], ["STATION"])
	assert_gt(score, 0.0, "TRADER vs STATION should be positive affinity.")

func test_compute_affinity_negative_pair():
	var score: float = affinity.compute_affinity(["PIRATE"], ["MILITARY"])
	assert_lt(score, 0.0, "PIRATE vs MILITARY should be negative affinity.")

func test_compute_affinity_empty_inputs():
	assert_eq(affinity.compute_affinity([], []), 0.0, "Empty tags → zero affinity.")
	assert_eq(affinity.compute_affinity(["TRADER"], []), 0.0, "Empty target → zero.")

func test_attack_threshold_reachable():
	# At least one pair in the matrix should reach ATTACK_THRESHOLD
	var found: bool = false
	for key in affinity.AFFINITY_MATRIX:
		if affinity.AFFINITY_MATRIX[key] >= Constants.ATTACK_THRESHOLD:
			found = true
			break
	assert_true(found, "At least one AFFINITY_MATRIX entry should reach ATTACK_THRESHOLD.")

func test_thresholds_ordered():
	assert_lt(Constants.FLEE_THRESHOLD, 0.0, "FLEE_THRESHOLD must be negative.")
	assert_gt(Constants.TRADE_THRESHOLD, 0.0, "TRADE_THRESHOLD must be positive.")
	assert_gt(Constants.ATTACK_THRESHOLD, Constants.TRADE_THRESHOLD,
		"ATTACK_THRESHOLD must exceed TRADE_THRESHOLD.")

func test_compute_affinity_accumulates_multiple_pairs():
	# PIRATE vs TRADER and PIRATE vs LOADED should both contribute
	var score_single: float = affinity.compute_affinity(["PIRATE"], ["TRADER"])
	var score_multi: float = affinity.compute_affinity(["PIRATE"], ["TRADER", "LOADED"])
	# PIRATE:LOADED should add to PIRATE:TRADER
	assert_ne(score_single, score_multi, "Multiple target tags should change the total score.")


# =============================================================================
# === derive_agent_tags =======================================================
# =============================================================================

func test_derive_agent_tags_includes_role_and_state():
	var char_data: Dictionary = {
		"personality_traits": {"aggression": 0.8, "greed": 0.7}
	}
	var agent: Dictionary = {
		"agent_role": "trader",
		"condition_tag": "DAMAGED",
		"wealth_tag": "BROKE",
		"cargo_tag": "LOADED",
		"dynamic_tags": ["DESPERATE"],
	}
	var tags: Array = affinity.derive_agent_tags(char_data, agent)
	assert_has(tags, "TRADER", "Role should appear UPPERCASED.")
	assert_has(tags, "DAMAGED", "condition_tag should appear.")
	assert_has(tags, "BROKE", "wealth_tag should appear.")
	assert_has(tags, "LOADED", "cargo_tag should appear.")
	assert_has(tags, "DESPERATE", "dynamic_tags should be included.")

func test_derive_agent_tags_no_duplicates():
	var char_data: Dictionary = {}
	var agent: Dictionary = {
		"agent_role": "pirate",
		"condition_tag": "HEALTHY",
		"wealth_tag": "COMFORTABLE",
		"cargo_tag": "EMPTY",
		"dynamic_tags": ["HEALTHY"],
	}
	var tags: Array = affinity.derive_agent_tags(char_data, agent)
	var healthy_count: int = 0
	for tag in tags:
		if tag == "HEALTHY":
			healthy_count += 1
	assert_eq(healthy_count, 1, "HEALTHY should appear only once (deduplication).")


# =============================================================================
# === derive_sector_tags ======================================================
# =============================================================================

func test_derive_sector_tags_fresh_sector():
	GameState.sector_tags["test_sector"] = ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.grid_dominion["test_sector"] = {"security_tag": "SECURE"}
	GameState.world_hazards["test_sector"] = {"environment": "MILD"}

	var tags: Array = affinity.derive_sector_tags("test_sector")
	assert_has(tags, "SECURE", "Security tag should be present.")
	assert_has(tags, "MILD", "Environment tag should be present.")
	assert_has(tags, "RAW_RICH", "Economy tag RAW_RICH should be present.")

	# Cleanup
	GameState.sector_tags.erase("test_sector")
	GameState.grid_dominion.erase("test_sector")
	GameState.world_hazards.erase("test_sector")
