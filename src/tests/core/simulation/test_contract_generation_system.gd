#
# PROJECT: GDTLancer
# MODULE: test_contract_generation_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md TASK_4; TRUTH_SIMULATION-GRAPH.md §6.4
# LOG_REF: 2026-05-23 23:11:32
#

extends GutTest

var generator: Reference = null


func before_each() -> void:
	GameState.reset_state()
	var Script = load("res://src/core/simulation/contract_generation_system.gd")
	generator = Script.new()
	_seed_runtime_contract_state()


func after_each() -> void:
	GameState.reset_state()
	generator = null


func test_process_tick_generates_occurrences_for_active_demand_tags() -> void:
	generator.process_tick({})

	assert_eq(GameState.runtime_contract_occurrences.size(), 3,
		"One runtime occurrence should be generated for each active demand tag.")
	assert_eq(GameState.runtime_contract_occurrences_by_target_sector.get("a", []).size(), 3,
		"Demand sector should index all generated occurrences.")

	var raw_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_eq(raw_contract.get("origin_location_id", ""), "b",
		"RAW demand should source from the strongest nearby RAW sector.")
	assert_eq(raw_contract.get("destination_location_id", ""), "a",
		"Generated occurrences should point at the demand sector.")
	assert_eq(raw_contract.get("contract_type", ""), "delivery",
		"Runtime occurrences should use delivery semantics.")
	assert_eq(raw_contract.get("required_roles", []), ["trader", "hauler"],
		"Runtime occurrences should advertise the trader/hauler roles for later agent use.")

	var manufactured_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:MANUFACTURED", {})
	assert_eq(manufactured_contract.get("origin_location_id", ""), "c",
		"MANUFACTURED demand should source from the best nearby manufactured supplier.")

	var currency_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:CURRENCY", {})
	assert_eq(currency_contract.get("origin_location_id", ""), "c",
		"CURRENCY demand should source from the best nearby currency supplier.")
	assert_has(GameState.runtime_contract_occurrences_by_source_sector.get("c", []), "runtime_contract:a:CURRENCY",
		"Source-sector index should include generated occurrences.")


func test_process_tick_respects_occurrence_caps() -> void:
	generator.process_tick({
		"contract_occurrence_global_cap": 1,
		"contract_occurrence_per_sector_cap": 1,
	})

	assert_eq(GameState.runtime_contract_occurrences.size(), 1,
		"Generator should respect the configured global occurrence cap.")
	assert_eq(GameState.runtime_contract_occurrences_by_target_sector.get("a", []).size(), 1,
		"Generator should respect the configured per-sector cap.")


func test_process_tick_requires_nearby_qualifying_sources() -> void:
	GameState.sector_tags["b"] = ["STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.sector_tags["c"] = ["STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_RICH", "CURRENCY_RICH"]
	GameState.world_topology["e"] = {"connections": ["b"], "sector_type": "colony", "station_ids": ["e"]}
	GameState.sector_tags["e"] = ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_POOR", "CURRENCY_POOR"]

	generator.process_tick({"contract_source_search_max_hops": 1})
	assert_false(GameState.runtime_contract_occurrences.has("runtime_contract:a:RAW"),
		"No RAW occurrence should be generated when the only valid source is beyond the hop limit.")

	generator.process_tick({"contract_source_search_max_hops": 2})
	var raw_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_eq(raw_contract.get("origin_location_id", ""), "e",
		"RAW demand should source from the nearest qualifying sector once the hop limit allows it.")
	assert_eq(raw_contract.get("route_hops", -1), 2,
		"Generated occurrences should record the qualitative route distance in hops.")


func test_process_tick_retains_claimed_occurrence_without_active_demand_tag() -> void:
	GameState.agents["hauler_1"] = {
		"agent_role": "hauler",
		"current_sector_id": "b",
		"is_disabled": false,
		"cargo_tag": "LOADED",
	}
	GameState.sector_tags["a"] = [
		"STATION", "CONTESTED", "MILD",
		"RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"
	]
	GameState.runtime_contract_occurrences = {
		"runtime_contract:a:RAW": {
			"occurrence_id": "runtime_contract:a:RAW",
			"generator_id": "qualitative_demand",
			"contract_type": "delivery",
			"commodity_category": "RAW",
			"demand_tag": "CONTRACT_DEMAND_RAW",
			"source_sector_id": "b",
			"target_sector_id": "a",
			"origin_location_id": "b",
			"destination_location_id": "a",
			"status": "in_transit",
			"claimant_agent_id": "hauler_1",
			"required_roles": ["trader", "hauler"],
			"priority_tags": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
			"route_hops": 1,
			"created_at_tick": 2,
			"claimed_at_tick": 3,
			"last_refreshed_tick": 4,
		}
	}

	generator.process_tick({})

	var retained_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_eq(retained_contract.get("claimant_agent_id", ""), "hauler_1",
		"Claimed occurrences should survive generator refresh even after the demand tag clears.")
	assert_eq(retained_contract.get("status", ""), "in_transit",
		"Generator should preserve the claimed occurrence status for in-flight deliveries.")
	assert_eq(int(retained_contract.get("created_at_tick", -1)), 2,
		"Generator should preserve the original creation tick while the delivery remains active.")
	assert_eq(int(retained_contract.get("last_refreshed_tick", -1)), GameState.sim_tick_count,
		"Generator should refresh retained occurrences to the current tick.")


func _seed_runtime_contract_state() -> void:
	GameState.world_seed = "runtime_contract_seed"
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 5
	GameState.world_topology = {
		"a": {"connections": ["b", "c"], "sector_type": "colony", "station_ids": ["a"]},
		"b": {"connections": ["a"], "sector_type": "colony", "station_ids": ["b"]},
		"c": {"connections": ["a"], "sector_type": "colony", "station_ids": ["c"]},
	}
	GameState.sector_names = {"a": "Alpha", "b": "Beta", "c": "Gamma", "e": "Epsilon"}
	GameState.sector_tags = {
		"a": [
			"STATION", "CONTESTED", "MILD",
			"RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR",
			"CONTRACT_DEMAND_RAW", "CONTRACT_DEMAND_MANUFACTURED", "CONTRACT_DEMAND_CURRENCY",
			"RELIEF_NEEDED"
		],
		"b": [
			"STATION", "SECURE", "MILD",
			"RAW_RICH", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE",
			"TRADE_LANE_ACTIVE"
		],
		"c": [
			"STATION", "SECURE", "MILD",
			"RAW_ADEQUATE", "MANUFACTURED_RICH", "CURRENCY_RICH"
		],
	}