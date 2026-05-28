#
# PROJECT: GDTLancer
# MODULE: test_contract_generation_system.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md TASK_1; TRUTH_SIMULATION-GRAPH.md §6.3, §6.4
# LOG_REF: 2026-05-27 05:18:00
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
	GameState.world_topology["b"]["connections"].append("e")
	GameState.world_topology["e"] = {"connections": ["b"], "sector_type": "colony", "station_ids": ["e"]}
	GameState.sector_tags["e"] = ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_POOR", "CURRENCY_POOR"]
	GameState.contract_cargo_supply["e"] = {"RAW": 1, "MANUFACTURED": 0, "CURRENCY": 0}
	GameState.contract_cargo_reserved["e"] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}
	GameState.contract_payment_supply["e"] = {"RAW": 1, "MANUFACTURED": 1, "CURRENCY": 1}
	GameState.contract_payment_reserved["e"] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0}

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


func test_process_tick_releases_reserved_claim_when_claimant_is_invalid_before_pickup() -> void:
	GameState.sector_tags["a"] = [
		"STATION", "CONTESTED", "MILD",
		"RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"
	]
	GameState.contract_cargo_supply["b"]["RAW"] = 1
	GameState.contract_cargo_reserved["b"]["RAW"] = 1
	GameState.contract_payment_supply["a"]["RAW"] = 0
	GameState.contract_payment_reserved["a"]["RAW"] = 1
	GameState.runtime_contract_occurrences = {
		"runtime_contract:a:RAW": {
			"occurrence_id": "runtime_contract:a:RAW",
			"generator_id": "qualitative_demand",
			"contract_type": "delivery",
			"commodity_category": "RAW",
			"demand_tag": "CONTRACT_DEMAND_RAW",
			"source_sector_id": "b",
			"target_sector_id": "a",
			"source_accounting_sector_id": "b",
			"payment_accounting_sector_id": "a",
			"origin_location_id": "b",
			"destination_location_id": "a",
			"status": "claimed",
			"claimant_agent_id": "hauler_1",
			"required_roles": ["trader", "hauler"],
			"priority_tags": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
			"route_hops": 1,
			"created_at_tick": 4,
			"claimed_at_tick": 4,
			"last_refreshed_tick": 4,
			"player_displayable": true,
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
			"source_reserved": true,
			"payment_reserved": true,
			"cargo_picked_up": false,
			"completed_at_tick": -1,
		}
	}

	generator.process_tick({})

	assert_false(GameState.runtime_contract_occurrences.has("runtime_contract:a:RAW"),
		"Generator should drop a pre-pickup claimed occurrence when its claimant is no longer valid.")
	assert_eq(int(GameState.contract_cargo_supply["b"].get("RAW", -1)), 2,
		"Dropping an invalid pre-pickup claim should restore the reserved source-side cargo unit.")
	assert_eq(int(GameState.contract_cargo_reserved["b"].get("RAW", -1)), 0,
		"Dropping an invalid pre-pickup claim should clear the source-side reservation bucket.")
	assert_eq(int(GameState.contract_payment_supply["a"].get("RAW", -1)), 1,
		"Dropping an invalid pre-pickup claim should restore the reserved target-side payment bundle.")
	assert_eq(int(GameState.contract_payment_reserved["a"].get("RAW", -1)), 0,
		"Dropping an invalid pre-pickup claim should clear the target-side payment reservation bucket.")


func test_process_tick_releases_prepickup_claim_when_target_sector_is_disabled() -> void:
	GameState.agents["hauler_1"] = {
		"agent_role": "hauler",
		"current_sector_id": "b",
		"is_disabled": false,
		"cargo_tag": "EMPTY",
	}
	GameState.sector_tags["a"] = [
		"STATION", "CONTESTED", "MILD", "DISABLED",
		"RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"
	]
	GameState.contract_cargo_supply["b"]["RAW"] = 1
	GameState.contract_cargo_reserved["b"]["RAW"] = 1
	GameState.contract_payment_supply["a"]["RAW"] = 0
	GameState.contract_payment_reserved["a"]["RAW"] = 1
	GameState.runtime_contract_occurrences = {
		"runtime_contract:a:RAW": {
			"occurrence_id": "runtime_contract:a:RAW",
			"generator_id": "qualitative_demand",
			"contract_type": "delivery",
			"commodity_category": "RAW",
			"demand_tag": "CONTRACT_DEMAND_RAW",
			"source_sector_id": "b",
			"target_sector_id": "a",
			"source_accounting_sector_id": "b",
			"payment_accounting_sector_id": "a",
			"origin_location_id": "b",
			"destination_location_id": "a",
			"status": "claimed",
			"claimant_agent_id": "hauler_1",
			"required_roles": ["trader", "hauler"],
			"priority_tags": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
			"route_hops": 1,
			"created_at_tick": 4,
			"claimed_at_tick": 4,
			"last_refreshed_tick": 4,
			"player_displayable": true,
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
			"source_reserved": true,
			"payment_reserved": true,
			"cargo_picked_up": false,
			"completed_at_tick": -1,
		}
	}

	generator.process_tick({})

	assert_false(GameState.runtime_contract_occurrences.has("runtime_contract:a:RAW"),
		"Generator should drop a pre-pickup claim when the target sector is disabled before cargo is loaded.")
	assert_eq(int(GameState.contract_cargo_supply["b"].get("RAW", -1)), 2,
		"Disabled-sector pre-pickup cleanup should restore the reserved source-side cargo unit.")
	assert_eq(int(GameState.contract_payment_supply["a"].get("RAW", -1)), 1,
		"Disabled-sector pre-pickup cleanup should restore the reserved target-side payment bundle.")


func test_process_tick_retains_in_transit_occurrence_when_target_sector_is_disabled() -> void:
	GameState.agents["hauler_1"] = {
		"agent_role": "hauler",
		"current_sector_id": "b",
		"is_disabled": false,
		"cargo_tag": "LOADED",
	}
	GameState.sector_tags["a"] = [
		"STATION", "CONTESTED", "MILD", "DISABLED",
		"RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"
	]
	GameState.contract_payment_supply["a"]["RAW"] = 0
	GameState.contract_payment_reserved["a"]["RAW"] = 1
	GameState.runtime_contract_occurrences = {
		"runtime_contract:a:RAW": {
			"occurrence_id": "runtime_contract:a:RAW",
			"generator_id": "qualitative_demand",
			"contract_type": "delivery",
			"commodity_category": "RAW",
			"demand_tag": "CONTRACT_DEMAND_RAW",
			"source_sector_id": "b",
			"target_sector_id": "a",
			"source_accounting_sector_id": "b",
			"payment_accounting_sector_id": "a",
			"origin_location_id": "b",
			"destination_location_id": "a",
			"status": "in_transit",
			"claimant_agent_id": "hauler_1",
			"required_roles": ["trader", "hauler"],
			"priority_tags": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
			"route_hops": 1,
			"created_at_tick": 4,
			"claimed_at_tick": 4,
			"last_refreshed_tick": 4,
			"player_displayable": true,
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
			"source_reserved": false,
			"payment_reserved": true,
			"cargo_picked_up": true,
			"completed_at_tick": -1,
		}
	}

	generator.process_tick({})

	var retained_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_eq(str(retained_contract.get("status", "")), "in_transit",
		"Generator should retain a picked-up in-transit occurrence even while the target sector is disabled.")
	assert_eq(bool(retained_contract.get("payment_reserved", false)), true,
		"Target-side payment reservation should stay held while the disabled target blocks completion.")
	assert_eq(int(GameState.contract_payment_supply["a"].get("RAW", -1)), 0,
		"Blocked in-transit retention should keep the reserved payment bundle out of the available pool.")


func test_process_tick_retains_recent_open_occurrence_for_one_refresh_without_active_demand_tag() -> void:
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
			"status": "open",
			"claimant_agent_id": "",
			"required_roles": ["trader", "hauler"],
			"priority_tags": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
			"route_hops": 1,
			"created_at_tick": 4,
			"last_refreshed_tick": 4,
			"player_displayable": true,
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
		}
	}

	generator.process_tick({})

	assert_true(GameState.runtime_contract_occurrences.has("runtime_contract:a:RAW"),
		"A newly opened player-facing occurrence should survive one generator refresh even if demand cleared on the next tick.")
	assert_has(GameState.runtime_contract_occurrences_by_source_sector.get("b", []), "runtime_contract:a:RAW",
		"Recent open occurrence retention should keep the source-sector index populated for the grace refresh.")


func test_process_tick_requires_backing_supply_and_payment_bundles() -> void:
	GameState.contract_cargo_supply["b"]["RAW"] = 0
	GameState.contract_cargo_supply["c"]["RAW"] = 0
	GameState.contract_payment_supply["a"]["MANUFACTURED"] = 0

	generator.process_tick({})

	assert_false(GameState.runtime_contract_occurrences.has("runtime_contract:a:RAW"),
		"Generator should not advertise a RAW occurrence when no source cargo unit backs it.")
	assert_false(GameState.runtime_contract_occurrences.has("runtime_contract:a:MANUFACTURED"),
		"Generator should not advertise a MANUFACTURED occurrence when the target cannot fund its reward bundle.")
	assert_true(GameState.runtime_contract_occurrences.has("runtime_contract:a:CURRENCY"),
		"Unaffected categories should still generate when both source cargo and target payment backing exist.")


func test_player_facing_metadata_present_in_generated_occurrences() -> void:
	generator.process_tick({})

	var raw_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_true(raw_contract.has("player_displayable"),
		"Generated occurrence should have player_displayable field.")
	assert_eq(bool(raw_contract.get("player_displayable", false)), true,
		"player_displayable should be true for runtime-generated occurrences.")
	assert_true(raw_contract.has("source_sector_id"),
		"Generated occurrence should have source_sector_id field.")
	assert_eq(raw_contract.get("source_sector_id", ""), "b",
		"source_sector_id should match the source sector.")
	assert_true(raw_contract.has("source_accounting_sector_id"),
		"Generated occurrence should have source_accounting_sector_id field.")
	assert_eq(raw_contract.get("source_accounting_sector_id", ""), "b",
		"source_accounting_sector_id should match the sector backing source cargo supply.")
	assert_eq(bool(raw_contract.get("source_reserved", true)), false,
		"Generated occurrences should start with no source-side reservation consumed.")
	assert_eq(bool(raw_contract.get("payment_reserved", true)), false,
		"Generated occurrences should start with no target-side payment reservation consumed.")
	assert_eq(bool(raw_contract.get("cargo_picked_up", true)), false,
		"Generated occurrences should start before any cargo has been picked up.")
	assert_true(raw_contract.has("destination_sector_id"),
		"Generated occurrence should have destination_sector_id field.")
	assert_eq(raw_contract.get("destination_sector_id", ""), "a",
		"destination_sector_id should match the demand sector.")
	assert_true(raw_contract.has("target_sector_id"),
		"Generated occurrence should have target_sector_id field.")
	assert_eq(raw_contract.get("target_sector_id", ""), "a",
		"target_sector_id should match the demand sector.")
	assert_true(raw_contract.has("payment_accounting_sector_id"),
		"Generated occurrence should have payment_accounting_sector_id field.")
	assert_eq(raw_contract.get("payment_accounting_sector_id", ""), "a",
		"payment_accounting_sector_id should match the sector backing target-side payment supply.")
	assert_true(raw_contract.has("required_cargo_tag"),
		"Generated occurrence should have required_cargo_tag field.")
	assert_eq(raw_contract.get("required_cargo_tag", ""), "RAW_COMMODITY",
		"required_cargo_tag should be derived from the commodity category.")
	assert_true(raw_contract.has("reward_credits"),
		"Generated occurrence should have reward_credits field.")
	assert_gt(int(raw_contract.get("reward_credits", 0)), 0,
		"reward_credits should be a positive integer.")
	assert_true(raw_contract.has("completed_at_tick"),
		"Generated occurrence should have completed_at_tick field.")
	assert_eq(int(raw_contract.get("completed_at_tick", -2)), -1,
		"Generated occurrences should initialize completion state as incomplete.")


func test_player_facing_metadata_categorizes_correctly_by_type() -> void:
	generator.process_tick({})

	var raw_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_eq(raw_contract.get("required_cargo_tag", ""), "RAW_COMMODITY",
		"RAW category should produce RAW_COMMODITY tag.")

	var manufactured_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:MANUFACTURED", {})
	assert_eq(manufactured_contract.get("required_cargo_tag", ""), "MANUFACTURED_COMMODITY",
		"MANUFACTURED category should produce MANUFACTURED_COMMODITY tag.")

	var currency_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:CURRENCY", {})
	assert_eq(currency_contract.get("required_cargo_tag", ""), "CURRENCY_COMMODITY",
		"CURRENCY category should produce CURRENCY_COMMODITY tag.")


func test_reward_credits_calculated_by_distance() -> void:
	generator.process_tick({})

	var raw_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	var raw_reward: int = int(raw_contract.get("reward_credits", 0))
	var raw_hops: int = int(raw_contract.get("route_hops", 0))
	assert_eq(raw_reward, 100 + (raw_hops * 25),
		"RAW reward should equal base 100 plus 25 per hop.")

	var manufactured_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:MANUFACTURED", {})
	var manufactured_reward: int = int(manufactured_contract.get("reward_credits", 0))
	var manufactured_hops: int = int(manufactured_contract.get("route_hops", 0))
	assert_eq(manufactured_reward, 150 + (manufactured_hops * 25),
		"MANUFACTURED reward should equal base 150 plus 25 per hop.")

	var currency_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:CURRENCY", {})
	var currency_reward: int = int(currency_contract.get("reward_credits", 0))
	var currency_hops: int = int(currency_contract.get("route_hops", 0))
	assert_eq(currency_reward, 200 + (currency_hops * 25),
		"CURRENCY reward should equal base 200 plus 25 per hop.")


func test_player_facing_metadata_survives_generator_refresh() -> void:
	generator.process_tick({})

	var original_raw_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	var original_displayable: bool = bool(original_raw_contract.get("player_displayable", false))
	var original_cargo_tag: String = str(original_raw_contract.get("required_cargo_tag", ""))
	var original_reward: int = int(original_raw_contract.get("reward_credits", 0))

	GameState.sim_tick_count += 1
	generator.process_tick({})

	var refreshed_raw_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_eq(bool(refreshed_raw_contract.get("player_displayable", false)), original_displayable,
		"player_displayable should survive generator refresh.")
	assert_eq(str(refreshed_raw_contract.get("required_cargo_tag", "")), original_cargo_tag,
		"required_cargo_tag should survive generator refresh.")
	assert_eq(int(refreshed_raw_contract.get("reward_credits", 0)), original_reward,
		"reward_credits should survive generator refresh.")


func test_player_facing_metadata_preserved_when_claimed_occurrence_retained() -> void:
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
			"source_accounting_sector_id": "b",
			"payment_accounting_sector_id": "a",
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
			"player_displayable": true,
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
			"source_reserved": true,
			"payment_reserved": true,
			"cargo_picked_up": true,
			"completed_at_tick": -1,
		}
	}

	generator.process_tick({})

	var retained_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_eq(bool(retained_contract.get("player_displayable", false)), true,
		"player_displayable should survive claimed occurrence retention.")
	assert_eq(str(retained_contract.get("required_cargo_tag", "")), "RAW_COMMODITY",
		"required_cargo_tag should survive claimed occurrence retention.")
	assert_eq(int(retained_contract.get("reward_credits", 0)), 125,
		"reward_credits should survive claimed occurrence retention.")
	assert_eq(str(retained_contract.get("source_accounting_sector_id", "")), "b",
		"source_accounting_sector_id should survive claimed occurrence retention.")
	assert_eq(str(retained_contract.get("payment_accounting_sector_id", "")), "a",
		"payment_accounting_sector_id should survive claimed occurrence retention.")
	assert_eq(bool(retained_contract.get("source_reserved", false)), true,
		"source-side reservation state should survive claimed occurrence retention.")
	assert_eq(bool(retained_contract.get("payment_reserved", false)), true,
		"target-side payment reservation state should survive claimed occurrence retention.")
	assert_eq(bool(retained_contract.get("cargo_picked_up", false)), true,
		"Cargo pickup state should survive claimed occurrence retention.")
	assert_eq(int(retained_contract.get("completed_at_tick", -2)), -1,
		"Incomplete retained occurrences should preserve their completion-state sentinel.")


func test_process_tick_retains_player_in_transit_occurrence_without_active_demand_tag() -> void:
	GameState.agents["player"] = {
		"agent_role": "idle",
		"current_sector_id": "b",
		"is_disabled": false,
		"cargo_tag": "LOADED",
	}
	GameState.player_claimed_occurrence_id = "runtime_contract:a:RAW"
	GameState.player_cargo_tag = "LOADED"
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
			"source_accounting_sector_id": "b",
			"payment_accounting_sector_id": "a",
			"origin_location_id": "b",
			"destination_location_id": "a",
			"status": "in_transit",
			"claimant_agent_id": "player",
			"required_roles": ["trader", "hauler"],
			"priority_tags": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
			"route_hops": 1,
			"created_at_tick": 2,
			"claimed_at_tick": 3,
			"last_refreshed_tick": 4,
			"player_displayable": true,
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
			"source_reserved": false,
			"payment_reserved": true,
			"cargo_picked_up": true,
			"completed_at_tick": -1,
		}
	}

	generator.process_tick({})

	var retained_contract: Dictionary = GameState.runtime_contract_occurrences.get("runtime_contract:a:RAW", {})
	assert_eq(str(retained_contract.get("claimant_agent_id", "")), "player",
		"Player-held in-transit occurrences should survive generator refresh even though the player agent role stays idle.")
	assert_eq(str(retained_contract.get("status", "")), "in_transit",
		"Generator should preserve in-transit status for player-held runtime deliveries.")
	assert_eq(bool(retained_contract.get("player_displayable", false)), true,
		"Player-held retained occurrences must remain visible to the Contract Board.")
	assert_has(GameState.runtime_contract_occurrences_by_source_sector.get("b", []), "runtime_contract:a:RAW",
		"Retained player-held deliveries should stay indexed by source sector for board/debug visibility.")


func test_completed_occurrence_is_removed_on_next_generator_tick() -> void:
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
			"status": "completed",
			"claimant_agent_id": "",
			"required_roles": ["trader", "hauler"],
			"priority_tags": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
			"route_hops": 1,
			"created_at_tick": 4,
			"completed_at_tick": 5,
			"last_refreshed_tick": 5,
			"player_displayable": true,
			"required_cargo_tag": "RAW_COMMODITY",
			"reward_credits": 125,
		}
	}

	GameState.sim_tick_count = 6
	generator.process_tick({})

	assert_false(GameState.runtime_contract_occurrences.has("runtime_contract:a:RAW"),
		"Completed occurrences should be removed from active generation on the next tick.")


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
	GameState.contract_cargo_supply = {
		"a": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
		"b": {"RAW": 2, "MANUFACTURED": 1, "CURRENCY": 1},
		"c": {"RAW": 1, "MANUFACTURED": 2, "CURRENCY": 2},
	}
	GameState.contract_cargo_reserved = {
		"a": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
		"b": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
		"c": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
	}
	GameState.contract_payment_supply = {
		"a": {"RAW": 1, "MANUFACTURED": 1, "CURRENCY": 1},
		"b": {"RAW": 1, "MANUFACTURED": 1, "CURRENCY": 1},
		"c": {"RAW": 1, "MANUFACTURED": 1, "CURRENCY": 1},
	}
	GameState.contract_payment_reserved = {
		"a": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
		"b": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
		"c": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
	}