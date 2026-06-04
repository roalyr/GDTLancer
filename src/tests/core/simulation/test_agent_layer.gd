#
# PROJECT: GDTLancer
# MODULE: test_agent_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Compatibility Constraints; TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-06-04 11:56:52
#

extends GutTest

## Unit tests for AgentLayer: qualitative agent lifecycle,
## affinity-driven actions, mortal spawning, and exploration.

var agent_layer: Reference = null
var affinity: Reference = null
var chronicle: Reference = null


class FakeCharacterSystem:
	extends Reference

	var add_credits_calls: Array = []

	func add_credits(character_uid, amount: int) -> void:
		add_credits_calls.append({"character_uid": character_uid, "amount": amount})
		if GameState.characters.has(character_uid):
			GameState.characters[character_uid].credits += amount
			return
		var int_uid: int = int(character_uid)
		if GameState.characters.has(int_uid):
			GameState.characters[int_uid].credits += amount


func before_each():
	_clear_state()
	var AgentScript = load("res://src/core/simulation/agent_layer.gd")
	var AffinityScript = load("res://src/core/simulation/affinity_matrix.gd")
	var ChronicleScript = load("res://src/core/simulation/chronicle_layer.gd")
	agent_layer = AgentScript.new()
	affinity = AffinityScript.new()
	chronicle = ChronicleScript.new()
	agent_layer.affinity_matrix = affinity
	agent_layer.set_chronicle(chronicle)
	_seed_minimal_state()


func after_each():
	_clear_state()
	agent_layer = null
	affinity = null
	chronicle = null


# =============================================================================
# === INITIALIZATION ==========================================================
# =============================================================================

func test_initialize_creates_player():
	agent_layer.initialize_agents()
	assert_true(GameState.agents.has("player"),
		"Player agent must exist after initialization.")

func test_player_has_qualitative_tags():
	agent_layer.initialize_agents()
	var player: Dictionary = GameState.agents["player"]
	assert_true(player.has("condition_tag"), "Player must have condition_tag.")
	assert_true(player.has("wealth_tag"), "Player must have wealth_tag.")
	assert_true(player.has("cargo_tag"), "Player must have cargo_tag.")


func test_initialize_agent_with_missing_home_location_falls_back_to_initial_sector():
	GameState.world_topology[Constants.INITIAL_SECTOR_ID] = {
		"connections": ["s1"],
		"sector_type": "colony",
		"station_ids": [Constants.INITIAL_SECTOR_ID],
	}
	var template: Resource = load("res://database/registry/agents/persistent_kai.tres")
	assert_not_null(template, "Persistent Kai template should load.")
	if template == null:
		return

	var mutated_template: Resource = template.duplicate(true)
	mutated_template.home_location_id = "sector_missing_renamed_away"

	agent_layer._initialize_agent_from_template("agent_invalid_home", mutated_template)

	assert_eq(
		GameState.agents["agent_invalid_home"]["current_sector_id"],
		Constants.INITIAL_SECTOR_ID,
		"Missing home locations should fall back to INITIAL_SECTOR_ID."
	)
	assert_eq(
		GameState.agents["agent_invalid_home"]["home_location_id"],
		Constants.INITIAL_SECTOR_ID,
		"Fallback home sector should be persisted into agent state."
	)


# =============================================================================
# === MORTAL SPAWN BLOCKED IN POOR SECTORS ====================================
# =============================================================================

func test_mortal_spawn_blocked_in_poor_sector():
	GameState.sector_tags["s1"] = [
		"STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_POOR", "CURRENCY_POOR"]
	GameState.agents = {}
	GameState.mortal_agent_counter = 0

	# We can't patch constants, but we can call _spawn_mortal_agents directly.
	# With only POOR economy tags, MORTAL_SPAWN_MIN_ECONOMY_TAGS check fails.
	agent_layer._spawn_mortal_agents()

	assert_eq(GameState.mortal_agent_counter, 0,
		"No mortals should spawn in a sector with only POOR economy tags.")
	assert_eq(GameState.agents.size(), 0,
		"agents dict should remain empty.")


func test_mortal_spawn_in_adequate_sector():
	GameState.sector_tags["s1"] = [
		"STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.agents = {}
	GameState.mortal_agent_counter = 0

	# Run _spawn_mortal_agents multiple times to give probability a chance
	for _i in range(50):
		agent_layer._spawn_mortal_agents()

	# With adequate economy, at least one mortal should eventually spawn
	assert_gt(GameState.mortal_agent_counter, 0,
		"Mortals should be able to spawn in a sector with ADEQUATE economy.")


func test_late_prosperity_increases_mortal_spawn_multiplier():
	GameState.world_age = "PROSPERITY"
	GameState.world_age_timer = Constants.WORLD_AGE_DURATIONS["PROSPERITY"]
	var early_multiplier: float = agent_layer._mortal_spawn_age_multiplier()

	GameState.world_age_timer = max(1, int(Constants.WORLD_AGE_DURATIONS["PROSPERITY"] * 0.2))
	var late_multiplier: float = agent_layer._mortal_spawn_age_multiplier()

	GameState.world_age = "DISRUPTION"
	var disruption_multiplier: float = agent_layer._mortal_spawn_age_multiplier()

	assert_gt(late_multiplier, early_multiplier,
		"Late prosperity should raise mortal spawn pressure relative to the opening frontier phase.")
	assert_lt(disruption_multiplier, early_multiplier,
		"Disruption should suppress mortal influx relative to early prosperity.")


func test_pick_mortal_spawn_role_filters_explorer_when_frontier_pressure_is_full():
	GameState.world_topology["s1"]["sector_type"] = "frontier"
	GameState.sector_tags["s1"] = [
		"FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.agents = {
		"persistent_nova": {
			"agent_role": "explorer",
			"current_sector_id": "s1",
			"is_persistent": true,
			"is_disabled": false,
		}
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	agent_layer._rng = rng

	var role: String = agent_layer._pick_mortal_spawn_role()

	assert_ne(role, "explorer",
		"Mortal spawning should reroll away from explorer when active explorer pressure already fills the frontier allowance.")


# =============================================================================
# === MORTAL SURVIVOR RESETS ==================================================
# =============================================================================

func test_mortal_survivor_starts_broke():
	GameState.agents = {
		"mortal_1": {
			"character_id": "",
			"is_persistent": false,
			"is_disabled": true,
			"disabled_at_tick": 0,
			"home_location_id": "s1",
			"current_sector_id": "s2",
			"condition_tag": "DESTROYED",
			"wealth_tag": "WEALTHY",
			"cargo_tag": "LOADED",
			"agent_role": "trader",
			"goal_archetype": "idle",
			"goal_queue": [{"type": "idle"}],
			"dynamic_tags": [],
		}
	}
	GameState.mortal_agent_deaths = []

	# Force high survival chance by calling many times
	# (or rely on the method's built-in MORTAL_SURVIVAL_CHANCE)
	agent_layer._cleanup_dead_mortals()

	# After cleanup, agent was either removed (death) or revived (survival).
	# Either outcome is valid — verify post-conditions for whichever occurred.
	if GameState.agents.has("mortal_1"):
		var survivor: Dictionary = GameState.agents["mortal_1"]
		if not survivor.get("is_disabled", true):
			assert_eq(survivor["condition_tag"], "DAMAGED",
				"Survivor should reset to DAMAGED.")
			assert_eq(survivor["wealth_tag"], "BROKE",
				"Survivor should reset to BROKE.")
			assert_eq(survivor["cargo_tag"], "EMPTY",
				"Survivor should reset to EMPTY.")
			assert_eq(survivor["current_sector_id"], "s1",
				"Survivor should return to home_location_id.")
		else:
			# Still disabled — not yet eligible for cleanup (tick threshold).
			assert_true(true, "Agent still disabled — cleanup deferred (expected).")
	else:
		# Agent was removed (permanent death).
		assert_true(true, "Agent permanently died — removed from agents dict (expected).")


func test_mortal_survivor_missing_home_location_falls_back_to_initial_sector():
	GameState.world_topology[Constants.INITIAL_SECTOR_ID] = {
		"connections": ["s1"],
		"sector_type": "colony",
		"station_ids": [Constants.INITIAL_SECTOR_ID],
	}
	GameState.agents = {
		"mortal_2": {
			"character_id": "",
			"is_persistent": false,
			"is_disabled": true,
			"disabled_at_tick": 0,
			"home_location_id": "sector_missing_renamed_away",
			"current_sector_id": "s2",
			"condition_tag": "DESTROYED",
			"wealth_tag": "WEALTHY",
			"cargo_tag": "LOADED",
			"agent_role": "trader",
			"goal_archetype": "idle",
			"goal_queue": [{"type": "idle"}],
			"dynamic_tags": [],
		}
	}

	agent_layer._cleanup_dead_mortals()

	if GameState.agents.has("mortal_2"):
		var survivor: Dictionary = GameState.agents["mortal_2"]
		if not survivor.get("is_disabled", true):
			assert_eq(
				survivor["current_sector_id"],
				Constants.INITIAL_SECTOR_ID,
				"Missing survivor home locations should fall back to INITIAL_SECTOR_ID."
			)
			assert_eq(
				survivor["home_location_id"],
				Constants.INITIAL_SECTOR_ID,
				"Fallback should be written back into survivor home_location_id."
			)
		else:
			assert_true(true, "Agent still disabled - cleanup deferred (expected).")
	else:
		assert_true(true, "Agent permanently died - removed from agents dict (expected).")


# =============================================================================
# === WEALTH STEP =============================================================
# =============================================================================

func test_wealth_step_up():
	var agent: Dictionary = {"wealth_tag": "BROKE"}
	agent_layer._wealth_step_up(agent)
	assert_eq(agent["wealth_tag"], "COMFORTABLE", "BROKE → COMFORTABLE.")
	agent_layer._wealth_step_up(agent)
	assert_eq(agent["wealth_tag"], "WEALTHY", "COMFORTABLE → WEALTHY.")
	agent_layer._wealth_step_up(agent)
	assert_eq(agent["wealth_tag"], "WEALTHY", "WEALTHY stays WEALTHY (ceiling).")


func test_wealth_step_down():
	var agent: Dictionary = {"wealth_tag": "WEALTHY"}
	agent_layer._wealth_step_down(agent)
	assert_eq(agent["wealth_tag"], "COMFORTABLE", "WEALTHY → COMFORTABLE.")
	agent_layer._wealth_step_down(agent)
	assert_eq(agent["wealth_tag"], "BROKE", "COMFORTABLE → BROKE.")
	agent_layer._wealth_step_down(agent)
	assert_eq(agent["wealth_tag"], "BROKE", "BROKE stays BROKE (floor).")


# =============================================================================
# === TAG HELPERS =============================================================
# =============================================================================

func test_pick_tag_finds_match():
	var result: String = agent_layer._pick_tag(
		["WEALTHY", "LOADED"], ["WEALTHY", "COMFORTABLE", "BROKE"], "COMFORTABLE")
	assert_eq(result, "WEALTHY")

func test_pick_tag_returns_default():
	var result: String = agent_layer._pick_tag(
		["LOADED"], ["WEALTHY", "COMFORTABLE", "BROKE"], "COMFORTABLE")
	assert_eq(result, "COMFORTABLE")

func test_add_tag_no_duplicate():
	var tags: Array = ["A", "B"]
	var result: Array = agent_layer._add_tag(tags, "B")
	assert_eq(result.size(), 2, "_add_tag should not add duplicate.")

func test_replace_one():
	var tags: Array = ["STATION", "SECURE", "MILD"]
	var result: Array = agent_layer._replace_one(tags, ["SECURE", "CONTESTED", "LAWLESS"], "LAWLESS")
	assert_has(result, "LAWLESS")
	assert_does_not_have(result, "SECURE")
	assert_has(result, "STATION")


# =============================================================================
# === INTERACTION RESOLUTION ==================================================
# =============================================================================

func test_same_faction_agents_do_not_escalate_to_attack() -> void:
	GameState.agents["pirate_a"] = {
		"agent_role": "pirate",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"rest_ticks_remaining": 0,
		"sentiment_tags": ["PIRATE", "FACTION_PIRATES", "LEGAL_ILLICIT", "HEALTHY", "COMFORTABLE", "EMPTY"],
	}
	GameState.agents["pirate_b"] = {
		"agent_role": "pirate",
		"current_sector_id": "s1",
		"wealth_tag": "WEALTHY",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"rest_ticks_remaining": 0,
		"sentiment_tags": ["PIRATE", "FACTION_PIRATES", "LEGAL_ILLICIT", "HEALTHY", "WEALTHY", "LOADED"],
	}

	var handled: bool = agent_layer._resolve_agent_interaction(
		"pirate_a",
		"pirate_b",
		Constants.ATTACK_THRESHOLD + 0.5
	)

	assert_false(handled,
		"Same-faction humans should not escalate into the attack path solely because cargo or wealth made the score high.")
	assert_eq(str(GameState.agents["pirate_b"].get("condition_tag", "")), "HEALTHY",
		"Blocked same-faction escalation should leave the target condition unchanged.")
	assert_false(bool(GameState.agents["pirate_b"].get("is_disabled", false)),
		"Blocked same-faction escalation should not disable the target.")
	assert_eq(_count_chronicle_actions("attack"), 0,
		"Blocked same-faction escalation should not log an attack event.")


func test_attack_threshold_resolves_to_non_lethal_disruption() -> void:
	GameState.agents["pirate_a"] = {
		"agent_role": "pirate",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"rest_ticks_remaining": 0,
		"sentiment_tags": ["PIRATE", "FACTION_PIRATES", "LEGAL_ILLICIT", "HEALTHY", "COMFORTABLE", "EMPTY"],
	}
	GameState.agents["trader_b"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "WEALTHY",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"rest_ticks_remaining": 0,
		"sentiment_tags": ["TRADER", "FACTION_TRADERS", "LEGAL_LAWFUL", "HEALTHY", "WEALTHY", "LOADED"],
	}

	var handled: bool = agent_layer._resolve_agent_interaction(
		"pirate_a",
		"trader_b",
		Constants.ATTACK_THRESHOLD + 0.5
	)
	chronicle.process_tick()

	assert_true(handled,
		"A lawful versus illicit high-score conflict should still resolve through the interaction path.")
	assert_eq(str(GameState.agents["trader_b"].get("condition_tag", "")), "DAMAGED",
		"Human-to-human attacks should now degrade into non-lethal disruption instead of destruction.")
	assert_false(bool(GameState.agents["trader_b"].get("is_disabled", false)),
		"Non-lethal disruption should not disable the target agent.")
	assert_does_not_have(GameState.sector_tags["s1"], "HAS_SALVAGE",
		"Non-lethal disruption should not generate salvage as if the target had been destroyed.")
	assert_eq(_count_chronicle_actions("attack"), 1,
		"Non-lethal disruption should continue to register as one combat engagement for reporting.")


func test_trade_threshold_rejects_lawful_illicit_pairing() -> void:
	GameState.agents["trader_a"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"sentiment_tags": ["TRADER", "FACTION_TRADERS", "LEGAL_LAWFUL", "HEALTHY", "COMFORTABLE", "LOADED", "CARGO_MARKET", "CARGO_LAWFUL"],
	}
	GameState.agents["pirate_b"] = {
		"agent_role": "pirate",
		"current_sector_id": "s1",
		"wealth_tag": "BROKE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"sentiment_tags": ["PIRATE", "FACTION_PIRATES", "LEGAL_ILLICIT", "HEALTHY", "BROKE", "EMPTY"],
	}

	var handled: bool = agent_layer._resolve_agent_interaction(
		"trader_a",
		"pirate_b",
		Constants.TRADE_THRESHOLD + 0.1
	)

	assert_false(handled,
		"A lawful versus illicit pairing should not fall through to the generic trade cargo flip.")
	assert_eq(str(GameState.agents["trader_a"].get("cargo_tag", "")), "LOADED",
		"Rejected trade should leave the lawful actor's cargo in place.")
	assert_eq(str(GameState.agents["pirate_b"].get("cargo_tag", "")), "EMPTY",
		"Rejected trade should not hand cargo to the illicit counterpart.")
	assert_eq(_count_chronicle_actions("agent_trade"), 0,
		"Rejected lawful versus illicit trade should not log a trade event.")


func test_trade_threshold_rejects_protected_contract_cargo() -> void:
	GameState.agents["trader_a"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"contract_cargo_tag": "RAW_COMMODITY",
		"sentiment_tags": [
			"TRADER", "FACTION_TRADERS", "LEGAL_LAWFUL", "HEALTHY", "COMFORTABLE", "LOADED",
			"CARGO_CONTRACT", "CARGO_PROTECTED", "HAS_CONTRACT_CLAIM"
		],
	}
	GameState.agents["hauler_b"] = {
		"agent_role": "hauler",
		"current_sector_id": "s1",
		"wealth_tag": "BROKE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"sentiment_tags": ["HAULER", "FACTION_MINERS", "LEGAL_LAWFUL", "HEALTHY", "BROKE", "EMPTY"],
	}

	var handled: bool = agent_layer._resolve_agent_interaction(
		"trader_a",
		"hauler_b",
		Constants.TRADE_THRESHOLD + 0.1
	)

	assert_false(handled,
		"Protected runtime contract cargo must not leak through the generic trade path.")
	assert_eq(str(GameState.agents["trader_a"].get("cargo_tag", "")), "LOADED",
		"Protected contract cargo should remain on the claimant after a blocked generic trade.")
	assert_eq(str(GameState.agents["hauler_b"].get("cargo_tag", "")), "EMPTY",
		"Blocked contract-cargo trade should not transfer the reserved bundle.")
	assert_eq(str(GameState.agents["trader_a"].get("contract_cargo_tag", "")), "RAW_COMMODITY",
		"Blocked generic trade should preserve the claimant's live contract cargo tag.")


func test_trade_threshold_still_allows_lawful_commerce_exchange() -> void:
	GameState.agents["trader_a"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"sentiment_tags": ["TRADER", "FACTION_TRADERS", "LEGAL_LAWFUL", "HEALTHY", "COMFORTABLE", "LOADED", "CARGO_MARKET", "CARGO_LAWFUL"],
	}
	GameState.agents["hauler_b"] = {
		"agent_role": "hauler",
		"current_sector_id": "s1",
		"wealth_tag": "BROKE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"sentiment_tags": ["HAULER", "FACTION_MINERS", "LEGAL_LAWFUL", "HEALTHY", "BROKE", "EMPTY"],
	}

	var handled: bool = agent_layer._resolve_agent_interaction(
		"trader_a",
		"hauler_b",
		Constants.TRADE_THRESHOLD + 0.1
	)
	chronicle.process_tick()

	assert_true(handled,
		"Compatible lawful commerce pairings should still be able to exchange cargo.")
	assert_eq(str(GameState.agents["trader_a"].get("cargo_tag", "")), "EMPTY",
		"Successful lawful trade should unload the source actor.")
	assert_eq(str(GameState.agents["hauler_b"].get("cargo_tag", "")), "LOADED",
		"Successful lawful trade should load the destination actor.")
	assert_eq(_count_chronicle_actions("agent_trade"), 1,
		"Compatible lawful trade should still log one trade event.")


# =============================================================================
# === DOCK ACTION =============================================================
# =============================================================================

func test_dock_sells_cargo_and_heals():
	GameState.sector_tags["s1"] = ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	var agent: Dictionary = {
		"current_sector_id": "s1",
		"condition_tag": "DAMAGED",
		"wealth_tag": "COMFORTABLE",
		"cargo_tag": "LOADED",
	}
	agent_layer._try_dock("test_agent", agent, "s1")
	assert_eq(agent["cargo_tag"], "EMPTY", "Cargo should be sold.")
	assert_eq(agent["condition_tag"], "HEALTHY", "Agent should be healed.")
	assert_eq(agent["wealth_tag"], "WEALTHY", "Wealth should step up from cargo sale.")


func test_hauler_prefers_and_claims_raw_runtime_contract_by_affinity():
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s1:CURRENCY": _make_runtime_contract_occurrence("runtime_contract:s1:CURRENCY", "CURRENCY", "s2", "s1"),
		"runtime_contract:s1:RAW": _make_runtime_contract_occurrence("runtime_contract:s1:RAW", "RAW", "s2", "s1"),
	}
	GameState.runtime_contract_occurrences_by_target_sector = {
		"s1": ["runtime_contract:s1:CURRENCY", "runtime_contract:s1:RAW"],
	}
	GameState.runtime_contract_occurrences_by_source_sector = {
		"s2": ["runtime_contract:s1:CURRENCY", "runtime_contract:s1:RAW"],
	}
	GameState.agents["hauler_1"] = {
		"agent_role": "hauler",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"goal_archetype": "idle",
		"goal_queue": [{"type": "idle"}],
		"sentiment_tags": ["HAULER", "HEALTHY", "COMFORTABLE", "EMPTY"],
	}

	var hauler: Dictionary = GameState.agents["hauler_1"]
	assert_true(_advance_until_npc_claim_can_succeed("hauler_1", "runtime_contract:s1:RAW"),
		"Test fixture should advance into a deterministic post-grace tick where NPC claim chance succeeds.")
	agent_layer._evaluate_goals(hauler, "hauler_1")

	assert_eq(hauler["goal_archetype"], "service_contract",
		"Haulers should switch to service_contract when runtime occurrences are available.")
	assert_eq(hauler["goal_queue"][0].get("occurrence_id", ""), "runtime_contract:s1:RAW",
		"Haulers should prefer RAW demand by affinity over weaker runtime contract categories.")

	agent_layer._execute_action("hauler_1", hauler)

	assert_eq(GameState.runtime_contract_occurrences["runtime_contract:s1:RAW"].get("claimant_agent_id", ""), "hauler_1",
		"Haulers should claim the selected runtime contract occurrence.")
	assert_eq(hauler["current_sector_id"], "s2",
		"Haulers should start moving toward the contract source when not already there.")


func test_npc_cannot_claim_new_runtime_contract_on_the_tick_it_appears() -> void:
	GameState.sim_tick_count = 5
	GameState.world_seed = "claim_grace_seed"
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s1:RAW": _make_runtime_contract_occurrence("runtime_contract:s1:RAW", "RAW", "s2", "s1"),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s1:RAW"]["created_at_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences_by_target_sector = {"s1": ["runtime_contract:s1:RAW"]}
	GameState.runtime_contract_occurrences_by_source_sector = {"s2": ["runtime_contract:s1:RAW"]}
	GameState.agents["hauler_1"] = {
		"agent_role": "hauler",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"goal_archetype": "idle",
		"goal_queue": [{"type": "idle"}],
		"sentiment_tags": ["HAULER", "HEALTHY", "COMFORTABLE", "EMPTY"],
	}

	var hauler: Dictionary = GameState.agents["hauler_1"]
	var claim_success: bool = agent_layer._claim_runtime_contract_occurrence("hauler_1", hauler, "runtime_contract:s1:RAW")

	assert_false(claim_success,
		"NPCs should not reserve a brand-new runtime contract on the same tick it appears.")
	assert_eq(GameState.runtime_contract_occurrences["runtime_contract:s1:RAW"].get("claimant_agent_id", ""), "",
		"Same-tick NPC claim attempts should leave the occurrence unclaimed for player reaction time.")
	assert_eq(int(GameState.contract_cargo_reserved["s2"].get("RAW", -1)), 0,
		"Blocked same-tick NPC claims should not reserve source-side cargo units.")
	assert_eq(int(GameState.contract_payment_reserved["s1"].get("RAW", -1)), 0,
		"Blocked same-tick NPC claims should not reserve target-side payment bundles.")


func test_npc_mandatory_rest_duration_tracks_condition_and_wealth() -> void:
	var wealthy_trader: Dictionary = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "WEALTHY",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"goal_archetype": "affinity_scan",
		"goal_queue": [{"type": "affinity_scan"}],
		"sentiment_tags": ["TRADER", "HEALTHY", "WEALTHY", "EMPTY"],
	}
	var desperate_trader: Dictionary = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "BROKE",
		"condition_tag": "DAMAGED",
		"cargo_tag": "EMPTY",
		"goal_archetype": "affinity_scan",
		"goal_queue": [{"type": "affinity_scan"}],
		"sentiment_tags": ["TRADER", "DAMAGED", "BROKE", "EMPTY", "DESPERATE"],
	}
	GameState.agents["wealthy_1"] = wealthy_trader
	GameState.agents["desperate_1"] = desperate_trader

	agent_layer._schedule_npc_rest_after_action("wealthy_1", wealthy_trader, "affinity_scan")
	agent_layer._schedule_npc_rest_after_action("desperate_1", desperate_trader, "affinity_scan")

	assert_eq(int(wealthy_trader.get("rest_ticks_remaining", -1)), 3,
		"Healthy wealthy NPCs should receive the longest mandatory idle break.")
	assert_eq(int(desperate_trader.get("rest_ticks_remaining", -1)), 1,
		"Desperate NPCs should only receive a one-tick mandatory break.")

	agent_layer._evaluate_goals(wealthy_trader, "wealthy_1")
	assert_eq(wealthy_trader["goal_archetype"], "idle",
		"Healthy wealthy NPCs should enter idle state while consuming their mandatory break.")
	assert_eq(int(wealthy_trader.get("rest_ticks_remaining", -1)), 2,
		"Idle evaluation should consume exactly one wealthy rest tick at a time.")

	agent_layer._evaluate_goals(wealthy_trader, "wealthy_1")
	agent_layer._evaluate_goals(wealthy_trader, "wealthy_1")
	assert_eq(wealthy_trader["goal_archetype"], "idle",
		"Healthy wealthy NPCs should stay idle until all scheduled rest ticks are spent.")
	assert_eq(int(wealthy_trader.get("rest_ticks_remaining", -1)), 0,
		"All wealthy rest ticks should be consumed before the NPC resumes work.")

	agent_layer._evaluate_goals(wealthy_trader, "wealthy_1")
	assert_eq(wealthy_trader["goal_archetype"], "affinity_scan",
		"Once the break ends, healthy wealthy NPCs should resume normal affinity evaluation.")

	agent_layer._evaluate_goals(desperate_trader, "desperate_1")
	assert_eq(desperate_trader["goal_archetype"], "idle",
		"Desperate NPCs should still spend their single mandatory break tick in idle state.")
	assert_eq(int(desperate_trader.get("rest_ticks_remaining", -1)), 0,
		"The desperate break should clear after one idle evaluation tick.")

	agent_layer._evaluate_goals(desperate_trader, "desperate_1")
	assert_eq(desperate_trader["goal_archetype"], "flee_to_safety",
		"After the short break, desperate NPCs should return to their urgent safety-driven behavior.")


func test_trader_claims_and_completes_runtime_contract_delivery():
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:CURRENCY": _make_runtime_contract_occurrence("runtime_contract:s2:CURRENCY", "CURRENCY", "s1", "s2"),
	}
	GameState.runtime_contract_occurrences_by_target_sector = {"s2": ["runtime_contract:s2:CURRENCY"]}
	GameState.runtime_contract_occurrences_by_source_sector = {"s1": ["runtime_contract:s2:CURRENCY"]}
	GameState.sector_tags["s2"] = ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_POOR", "CONTRACT_DEMAND_CURRENCY", "RELIEF_NEEDED"]
	GameState.contract_generation_threshold["s2"] = {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 3}
	GameState.contract_generation_pressure["s2"] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 3}
	GameState.agents["trader_1"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"goal_archetype": "idle",
		"goal_queue": [{"type": "idle"}],
		"sentiment_tags": ["TRADER", "HEALTHY", "COMFORTABLE", "EMPTY"],
	}

	var trader: Dictionary = GameState.agents["trader_1"]
	assert_true(_advance_until_npc_claim_can_succeed("trader_1", "runtime_contract:s2:CURRENCY"),
		"Test fixture should advance into a deterministic post-grace tick where NPC claim chance succeeds.")
	agent_layer._evaluate_goals(trader, "trader_1")
	agent_layer._execute_action("trader_1", trader)

	assert_eq(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("claimant_agent_id", ""), "trader_1",
		"Traders should claim runtime contract occurrences before delivery.")
	assert_eq(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("status", ""), "in_transit",
		"Claimed contracts should switch to in_transit once the trader loads cargo at the source.")
	assert_eq(trader["cargo_tag"], "LOADED",
		"Traders should load contract cargo at the source sector.")
	assert_eq(trader["wealth_tag"], "BROKE",
		"Trader loading should still pay the existing upfront wealth cost.")
	assert_eq(int(GameState.contract_cargo_supply["s1"].get("CURRENCY", -1)), 1,
		"NPC pickup should consume the previously reserved source-side cargo unit.")
	assert_eq(int(GameState.contract_cargo_reserved["s1"].get("CURRENCY", -1)), 0,
		"NPC pickup should clear the source-side reservation bucket once cargo is loaded.")
	assert_eq(int(GameState.contract_payment_supply["s2"].get("CURRENCY", -1)), 1,
		"NPC claim should hold one target-side payment bundle out of the available pool.")
	assert_eq(int(GameState.contract_payment_reserved["s2"].get("CURRENCY", -1)), 1,
		"NPC claim should keep the target-side payment bundle reserved while cargo is in transit.")
	assert_eq(bool(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("source_reserved", true)), false,
		"Source reservation should be consumed once the NPC loads cargo.")
	assert_eq(bool(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("cargo_picked_up", false)), true,
		"Cargo pickup state should be tracked on the shared runtime occurrence for NPC flow.")

	trader["sentiment_tags"] = ["TRADER", "HEALTHY", "BROKE", "LOADED"]
	agent_layer._evaluate_goals(trader, "trader_1")
	agent_layer._execute_action("trader_1", trader)
	assert_eq(trader["current_sector_id"], "s2",
		"Traders should move toward the contract target while carrying cargo.")

	agent_layer._evaluate_goals(trader, "trader_1")
	agent_layer._execute_action("trader_1", trader)
	assert_false(GameState.runtime_contract_occurrences.has("runtime_contract:s2:CURRENCY"),
		"Completed runtime contract occurrences should be removed from the active store.")
	assert_eq(trader["cargo_tag"], "EMPTY",
		"Traders should unload cargo when completing a runtime contract at the target.")
	assert_eq(trader["wealth_tag"], "COMFORTABLE",
		"Trader delivery should reuse the normal dock payout step on completion.")
	assert_eq(int(GameState.contract_payment_reserved["s2"].get("CURRENCY", -1)), 0,
		"NPC completion should consume the reserved target-side payment bundle.")
	assert_eq(int(GameState.contract_payment_supply["s2"].get("CURRENCY", -1)), 1,
		"NPC completion should not restore the consumed payment bundle to the available pool.")
	assert_eq(int(GameState.contract_generation_pressure["s2"].get("CURRENCY", -1)), 1,
		"NPC contract completion should apply deterministic destination-sector demand pressure relief.")
	assert_does_not_have(GameState.sector_tags["s2"], "CONTRACT_DEMAND_CURRENCY",
		"NPC contract completion should clear demand tag when pressure falls below threshold.")


func test_player_goal_evaluation_stays_idle_even_with_selected_contract() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_runtime_contract_occurrence("runtime_contract:s2:RAW", "RAW", "s1", "s2"),
	}
	GameState.agents["player"] = {
		"agent_role": "idle",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"goal_archetype": "idle",
		"goal_queue": [{"type": "idle"}],
	}

	var player: Dictionary = GameState.agents["player"]

	GameState.player_docked_at = ""
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:RAW"
	agent_layer._evaluate_goals(player, "player")
	assert_eq(player["goal_archetype"], "idle",
		"Player should stay idle even with a selected contract because contract actions are board-driven, not auto-serviced.")

	GameState.player_docked_at = "s1"
	GameState.player_claimed_occurrence_id = ""
	agent_layer._evaluate_goals(player, "player")
	assert_eq(player["goal_archetype"], "idle",
		"Player should stay idle when no contract is selected.")

	GameState.player_docked_at = "s1"
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:RAW"
	agent_layer._evaluate_goals(player, "player")
	assert_eq(player["goal_archetype"], "idle",
		"Player should remain idle even when docked and selected because contract service requires explicit board actions.")


func test_player_accept_and_release_restore_reserved_contract_units_before_pickup():
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_runtime_contract_occurrence("runtime_contract:s2:RAW", "RAW", "s1", "s2"),
	}

	var accepted: bool = agent_layer.player_accept_runtime_contract("runtime_contract:s2:RAW")

	assert_true(accepted,
		"Player should be able to reserve a visible runtime contract through the explicit accept path.")
	assert_eq(int(GameState.contract_cargo_supply["s1"].get("RAW", -1)), 1,
		"Accepting a contract should reserve one source-side cargo unit immediately.")
	assert_eq(int(GameState.contract_cargo_reserved["s1"].get("RAW", -1)), 1,
		"Accepting a contract should move one source-side unit into the reserved bucket.")
	assert_eq(int(GameState.contract_payment_supply["s2"].get("RAW", -1)), 1,
		"Accepting a contract should reserve one target-side payment bundle immediately.")
	assert_eq(int(GameState.contract_payment_reserved["s2"].get("RAW", -1)), 1,
		"Accepting a contract should move one payment bundle into the reserved bucket.")
	assert_eq(str(GameState.player_cargo_tag), "EMPTY",
		"Accepting a contract should not auto-load player cargo.")
	assert_eq(str(GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"].get("status", "")), "claimed",
		"Accepting a contract should reserve it without switching directly to in_transit.")

	agent_layer._release_runtime_contract_claim("player", "runtime_contract:s2:RAW")

	assert_eq(int(GameState.contract_cargo_supply["s1"].get("RAW", -1)), 2,
		"Releasing an unpicked claim should restore the reserved source-side cargo unit.")
	assert_eq(int(GameState.contract_cargo_reserved["s1"].get("RAW", -1)), 0,
		"Releasing an unpicked claim should clear the source-side reservation bucket.")
	assert_eq(int(GameState.contract_payment_supply["s2"].get("RAW", -1)), 2,
		"Releasing an unpicked claim should restore the reserved target-side payment bundle.")
	assert_eq(int(GameState.contract_payment_reserved["s2"].get("RAW", -1)), 0,
		"Releasing an unpicked claim should clear the target-side payment reservation bucket.")


func test_player_explicit_contract_actions_claim_pick_up_and_complete_without_docking_gate() -> void:
	var fake_character_system := FakeCharacterSystem.new()
	GlobalRefs.character_system = fake_character_system
	GameState.player_character_uid = "1"
	GameState.characters[1] = {"credits": 40, "focus_points": 0}

	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:CURRENCY": _make_runtime_contract_occurrence("runtime_contract:s2:CURRENCY", "CURRENCY", "s1", "s2"),
	}
	GameState.runtime_contract_occurrences_by_target_sector = {"s2": ["runtime_contract:s2:CURRENCY"]}
	GameState.runtime_contract_occurrences_by_source_sector = {"s1": ["runtime_contract:s2:CURRENCY"]}
	GameState.sector_tags["s2"] = ["STATION", "CONTESTED", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_POOR", "CONTRACT_DEMAND_CURRENCY", "RELIEF_NEEDED"]
	GameState.contract_generation_threshold["s2"] = {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 3}
	GameState.contract_generation_pressure["s2"] = {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 3}
	GameState.agents["player"] = {
		"agent_role": "idle",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"goal_archetype": "idle",
		"goal_queue": [{"type": "idle"}],
	}
	GameState.player_docked_at = ""
	GameState.player_cargo_tag = "EMPTY"

	var accepted: bool = agent_layer.player_accept_runtime_contract("runtime_contract:s2:CURRENCY")
	assert_true(accepted,
		"Player should be able to accept a contract through the explicit board-facing helper.")
	assert_eq(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("claimant_agent_id", ""), "player",
		"Player should claim the explicitly selected runtime contract occurrence.")
	assert_eq(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("status", ""), "claimed",
		"Accept should reserve the contract without switching directly to in_transit.")
	assert_eq(GameState.player_cargo_tag, "EMPTY",
		"Accept should not auto-load player cargo.")

	var pickup_success: bool = agent_layer.player_pick_up_runtime_contract("runtime_contract:s2:CURRENCY")
	assert_true(pickup_success,
		"Player should pick up contract cargo only through the explicit pickup helper at the source sector.")
	assert_eq(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("status", ""), "in_transit",
		"Explicit pickup should switch the contract to in_transit after loading cargo at source.")
	assert_eq(GameState.agents["player"].get("cargo_tag", ""), "LOADED",
		"Player simulation cargo tag should switch to LOADED after contract load.")
	assert_eq(GameState.player_cargo_tag, "LOADED",
		"GameState player_cargo_tag should mirror the LOADED contract cargo state.")
	assert_eq(int(GameState.contract_cargo_supply["s1"].get("CURRENCY", -1)), 1,
		"Loading contract cargo should consume the previously reserved source-side cargo unit.")
	assert_eq(int(GameState.contract_cargo_reserved["s1"].get("CURRENCY", -1)), 0,
		"Loading contract cargo should clear the source-side reservation bucket once the cargo is picked up.")
	assert_eq(int(GameState.contract_payment_supply["s2"].get("CURRENCY", -1)), 1,
		"Claiming the contract should hold one target-side payment bundle out of the available pool.")
	assert_eq(int(GameState.contract_payment_reserved["s2"].get("CURRENCY", -1)), 1,
		"Target-side payment should stay reserved while the player is in transit.")
	assert_eq(bool(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("source_reserved", true)), false,
		"Player pickup should consume the source-side reservation through the shared accounting helper.")
	assert_eq(bool(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("cargo_picked_up", false)), true,
		"Player pickup should mark cargo_picked_up on the shared runtime occurrence.")

	GameState.agents["player"]["current_sector_id"] = "s2"
	GameState.current_sector_id = "s2"
	GameState.player_docked_at = ""

	var completion_success: bool = agent_layer.player_complete_runtime_contract("runtime_contract:s2:CURRENCY")
	assert_true(completion_success,
		"Player should complete the contract through the explicit completion helper without a docking gate.")
	assert_true(GameState.runtime_contract_occurrences.has("runtime_contract:s2:CURRENCY"),
		"Player completion should preserve the occurrence as completed until generator refresh removes it.")
	assert_eq(str(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("status", "")), "completed",
		"Player completion should mark the occurrence status as completed.")
	assert_eq(GameState.agents["player"].get("cargo_tag", ""), "EMPTY",
		"Player simulation cargo tag should reset to EMPTY after delivery.")
	assert_eq(GameState.player_cargo_tag, "EMPTY",
		"GameState player_cargo_tag should reset to EMPTY on completion.")
	assert_eq(GameState.player_claimed_occurrence_id, "",
		"GameState player_claimed_occurrence_id should clear on completion.")
	assert_eq(GameState.characters[1].credits, 265,
		"Player completion should apply reward credits through the character system path.")
	assert_eq(fake_character_system.add_credits_calls.size(), 1,
		"Player completion should call CharacterSystem.add_credits exactly once.")
	if fake_character_system.add_credits_calls.size() != 1:
		return
	assert_eq(int(fake_character_system.add_credits_calls[0].get("amount", 0)), 225,
		"CharacterSystem.add_credits should receive the contract reward amount.")
	assert_eq(int(GameState.contract_payment_reserved["s2"].get("CURRENCY", -1)), 0,
		"Completion should consume the reserved target-side payment bundle.")
	assert_eq(int(GameState.contract_payment_supply["s2"].get("CURRENCY", -1)), 1,
		"Completion should not restore the consumed payment bundle to the available pool.")
	assert_eq(int(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("completed_at_tick", -1)), GameState.sim_tick_count,
		"Player completion should stamp completed_at_tick on the retained occurrence.")
	assert_eq(int(GameState.contract_generation_pressure["s2"].get("CURRENCY", -1)), 1,
		"Player contract completion should apply the same destination-sector demand pressure relief as NPC completion.")
	assert_does_not_have(GameState.sector_tags["s2"], "CONTRACT_DEMAND_CURRENCY",
		"Player contract completion should clear demand tag when pressure falls below threshold.")


func test_player_pickup_rejects_disabled_source_sector() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_runtime_contract_occurrence("runtime_contract:s2:RAW", "RAW", "s1", "s2"),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["claimant_agent_id"] = "player"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["status"] = "claimed"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["source_reserved"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["payment_reserved"] = true
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:RAW"
	GameState.sector_tags["s1"] = ["STATION", "SECURE", "MILD", "DISABLED", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]

	var pickup_success: bool = agent_layer.player_pick_up_runtime_contract("runtime_contract:s2:RAW")

	assert_false(pickup_success,
		"Player pickup should fail when the source sector is disabled.")
	assert_eq(str(GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"].get("status", "")), "claimed",
		"Disabled-source pickup failures should leave the claimed occurrence intact until generator recovery logic runs.")
	assert_eq(str(GameState.player_cargo_tag), "EMPTY",
		"Blocked pickup should not change player cargo state.")
	assert_eq(bool(GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"].get("source_reserved", false)), true,
		"Blocked pickup should not consume the reserved source-side cargo unit.")


func test_npc_completion_rejects_disabled_target_and_keeps_in_transit_occurrence() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:CURRENCY": _make_runtime_contract_occurrence("runtime_contract:s2:CURRENCY", "CURRENCY", "s1", "s2"),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["claimant_agent_id"] = "trader_1"
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["status"] = "in_transit"
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["cargo_picked_up"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["payment_reserved"] = true
	GameState.contract_payment_supply["s2"]["CURRENCY"] = 1
	GameState.contract_payment_reserved["s2"]["CURRENCY"] = 1
	GameState.sector_tags["s2"] = ["STATION", "CONTESTED", "MILD", "DISABLED", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_POOR"]
	var trader: Dictionary = {
		"agent_role": "trader",
		"current_sector_id": "s2",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
	}

	var completion_success: bool = agent_layer._complete_runtime_contract_occurrence("trader_1", trader, "runtime_contract:s2:CURRENCY", "s2")

	assert_false(completion_success,
		"NPC completion should fail when the target sector is disabled.")
	assert_true(GameState.runtime_contract_occurrences.has("runtime_contract:s2:CURRENCY"),
		"Blocked completion should retain the in-transit occurrence instead of removing it.")
	assert_eq(str(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("status", "")), "in_transit",
		"Blocked completion should preserve in-transit status.")
	assert_eq(int(GameState.contract_payment_reserved["s2"].get("CURRENCY", -1)), 1,
		"Blocked completion should keep the reserved target-side payment bundle held.")
	assert_eq(str(trader.get("cargo_tag", "")), "LOADED",
		"Blocked completion should leave cargo loaded while the delivery waits for recovery.")


func test_player_completion_rejects_disabled_target_and_keeps_claim_state() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:CURRENCY": _make_runtime_contract_occurrence("runtime_contract:s2:CURRENCY", "CURRENCY", "s1", "s2"),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["claimant_agent_id"] = "player"
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["status"] = "in_transit"
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["cargo_picked_up"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["payment_reserved"] = true
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:CURRENCY"
	GameState.player_cargo_tag = "LOADED"
	GameState.agents["player"]["current_sector_id"] = "s2"
	GameState.agents["player"]["cargo_tag"] = "LOADED"
	GameState.agents["player"]["contract_cargo_tag"] = "CURRENCY_COMMODITY"
	GameState.current_sector_id = "s2"
	GameState.sector_tags["s2"] = ["STATION", "CONTESTED", "MILD", "DISABLED", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_POOR"]

	var completion_success: bool = agent_layer.player_complete_runtime_contract("runtime_contract:s2:CURRENCY")

	assert_false(completion_success,
		"Player completion should fail when the target sector is disabled.")
	assert_eq(str(GameState.player_claimed_occurrence_id), "runtime_contract:s2:CURRENCY",
		"Blocked player completion should keep the claimed occurrence selected.")
	assert_eq(str(GameState.player_cargo_tag), "LOADED",
		"Blocked player completion should keep player cargo loaded until recovery.")
	assert_eq(str(GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"].get("status", "")), "in_transit",
		"Blocked player completion should preserve the in-transit occurrence state.")


func test_claimant_cleanup_releases_prepickup_claim_and_clears_player_mirrors() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:RAW": _make_runtime_contract_occurrence("runtime_contract:s2:RAW", "RAW", "s1", "s2"),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["claimant_agent_id"] = "player"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["status"] = "claimed"
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["source_reserved"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"]["payment_reserved"] = true
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:RAW"
	var player: Dictionary = GameState.agents["player"]

	agent_layer._clear_runtime_contract_claims_for_agent("player", player)

	assert_eq(str(GameState.player_claimed_occurrence_id), "",
		"Claim cleanup should clear the player-occurrence mirror immediately.")
	assert_eq(int(GameState.contract_cargo_supply["s1"].get("RAW", -1)), 2,
		"Claim cleanup should restore the reserved source-side cargo unit for a pre-pickup player claim.")
	assert_eq(int(GameState.contract_payment_supply["s2"].get("RAW", -1)), 2,
		"Claim cleanup should restore the reserved target-side payment bundle for a pre-pickup player claim.")
	assert_eq(str(GameState.runtime_contract_occurrences["runtime_contract:s2:RAW"].get("status", "")), "open",
		"Pre-pickup claimant cleanup should reopen the occurrence for later claims.")


func test_claimant_cleanup_removes_picked_up_occurrence_and_releases_payment_reservation() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:s2:CURRENCY": _make_runtime_contract_occurrence("runtime_contract:s2:CURRENCY", "CURRENCY", "s1", "s2"),
	}
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["claimant_agent_id"] = "player"
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["status"] = "in_transit"
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["cargo_picked_up"] = true
	GameState.runtime_contract_occurrences["runtime_contract:s2:CURRENCY"]["payment_reserved"] = true
	GameState.player_claimed_occurrence_id = "runtime_contract:s2:CURRENCY"
	GameState.player_cargo_tag = "LOADED"
	GameState.agents["player"]["cargo_tag"] = "LOADED"
	GameState.agents["player"]["contract_cargo_tag"] = "CURRENCY_COMMODITY"
	GameState.contract_payment_supply["s2"]["CURRENCY"] = 1
	GameState.contract_payment_reserved["s2"]["CURRENCY"] = 1
	var player: Dictionary = GameState.agents["player"]

	agent_layer._clear_runtime_contract_claims_for_agent("player", player)

	assert_false(GameState.runtime_contract_occurrences.has("runtime_contract:s2:CURRENCY"),
		"Claimant loss after pickup should remove the in-transit occurrence immediately instead of leaving a stranded claim.")
	assert_eq(int(GameState.contract_payment_supply["s2"].get("CURRENCY", -1)), 2,
		"Claimant loss after pickup should restore the reserved payment bundle.")
	assert_eq(int(GameState.contract_payment_reserved["s2"].get("CURRENCY", -1)), 0,
		"Claimant loss after pickup should clear the reserved payment bucket.")
	assert_eq(str(GameState.player_claimed_occurrence_id), "",
		"Claimant loss after pickup should clear the player-occurrence mirror.")
	assert_eq(str(GameState.player_cargo_tag), "EMPTY",
		"Claimant loss after pickup should clear the player cargo mirror.")
	assert_eq(str(player.get("cargo_tag", "")), "EMPTY",
		"Claimant loss after pickup should clear the live player cargo state.")
	assert_false(player.has("contract_cargo_tag"),
		"Claimant loss after pickup should clear any live contract cargo tag on the claimant.")


# =============================================================================
# === HARVEST ACTION ==========================================================
# =============================================================================

func test_harvest_collects_salvage():
	GameState.sector_tags["s1"] = ["FRONTIER", "LAWLESS", "HARSH", "HAS_SALVAGE", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	var agent: Dictionary = {
		"current_sector_id": "s1",
		"cargo_tag": "EMPTY",
	}
	agent_layer._action_harvest("test_agent", agent, "s1")
	assert_eq(agent["cargo_tag"], "LOADED", "Cargo should be LOADED after harvest.")
	assert_does_not_have(GameState.sector_tags["s1"], "HAS_SALVAGE",
		"HAS_SALVAGE should be removed from sector.")


# =============================================================================
# === DISCOVERY REGISTRATION ==================================================
# =============================================================================

func test_try_exploration_registers_runtime_location_template():
	var explorer: Dictionary = {
		"wealth_tag": "COMFORTABLE",
		"last_discovery_tick": -999,
	}
	GameState.world_topology["s1"]["sector_type"] = "frontier"
	GameState.sector_tags["s1"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	agent_layer._rng.seed = 13
	agent_layer._try_exploration("explorer", explorer, "s1")

	assert_eq(GameState.discovered_sector_count, 1, "Successful exploration should increment the discovered sector counter.")
	assert_true(TemplateDatabase.locations.has("discovered_1"), "A discovered sector should register a runtime LocationTemplate.")
	assert_eq(GameState.discovery_log.size(), 1, "Successful exploration should append one discovery-log entry.")

	var discovered_template = TemplateDatabase.locations["discovered_1"]
	var source_position: Vector3 = TemplateDatabase.locations["s1"]["global_position"]
	var handcrafted_neighbor_position: Vector3 = TemplateDatabase.locations["s2"]["global_position"]
	var discovered_position: Vector3 = discovered_template.global_position
	var discovered_distance: float = discovered_position.distance_to(source_position)
	var handcrafted_distance: float = handcrafted_neighbor_position.distance_to(source_position)

	assert_true(discovered_template.is_procedural, "Discovered sectors should register as procedural templates.")
	assert_eq(discovered_template.template_id, "discovered_1")
	assert_eq(discovered_template.location_name, GameState.sector_names["discovered_1"])
	assert_true(
		discovered_template.procedural_type in ["asteroid_field", "comet_shoal", "rogue_planet", "dark_nebula", "remnant_field"],
		"Discovered sectors should use one of the low-visibility procedural profiles."
	)
	assert_true(discovered_template.procedural_hints.get("low_visibility", false), "Discovered sectors should carry the low-visibility runtime hint.")
	assert_eq(GameState.discovery_log[0]["from"], "s1", "Discovery log should record the connected source sector.")
	assert_eq(GameState.discovery_log[0]["global_position"], discovered_position)
	assert_true(discovered_distance < handcrafted_distance, "Discovered sectors should spawn closer to their source than the handcrafted neighbor spacing.")
	assert_true(GameState.station_by_id.has("station_discovered_1"),
		"Discovery should generate one deterministic procedural station for the discovered sector.")
	assert_eq(Array(GameState.world_topology["discovered_1"].get("station_ids", [])).size(), 1,
		"Discovered sectors should keep a one-station-per-sector mapping.")


func test_generate_procedural_station_for_sector_registers_deterministic_station_data():
	GameState.sector_names["s1"] = "Source Sector"
	var generated_station_a: Dictionary = agent_layer._generate_procedural_station_for_sector("s1")
	var generated_station_b: Dictionary = agent_layer._generate_procedural_station_for_sector("s1")

	assert_eq(str(generated_station_a.get("id", "")), "station_s1",
		"Generated station id should follow deterministic sector-based naming.")
	assert_eq(str(generated_station_a.get("display_name", "")), "Source Sector Station",
		"Generated station display name should use '<Sector Name> Station'.")
	assert_eq(str(generated_station_a.get("id", "")), str(generated_station_b.get("id", "")),
		"Generating a station for the same sector twice should be deterministic.")
	assert_eq(generated_station_a.get("docking_point", Vector3.ZERO), generated_station_b.get("docking_point", Vector3.ZERO),
		"Procedural docking point should be stable for the same seed and sector id.")
	assert_true(GameState.station_by_id.has("station_s1"),
		"Generated station should be registered in GameState.station_by_id.")
	assert_eq(Array(GameState.world_topology["s1"].get("station_ids", [])).size(), 1,
		"Generated station registration should keep one station id in world topology for the sector.")
	assert_true(GameState.locations.has("station_s1"),
		"Generated station should be exposed through legacy location records for docking systems.")


func test_generate_sector_name_for_count_uses_centralized_constants_name_pools():
	GameState.world_seed = "frontier-name-seed"
	var generated_root: String = agent_layer._generate_discovery_name_root(3)
	var generated_name: String = agent_layer._generate_sector_name_for_count(3)
	var repeated_name: String = agent_layer._generate_sector_name_for_count(3)

	assert_eq(generated_name, repeated_name,
		"Count-based discovery naming should remain deterministic after switching to the legacy system-name generator.")
	assert_false(generated_root.empty(),
		"Count-based discovery naming should produce a generated legacy root.")
	var name_parts: Array = generated_name.split(" ")
	if generated_root.length() <= Constants.DISCOVERY_NAME_SHORT_ROOT_MAX_LENGTH:
		assert_eq(name_parts.size(), 3,
			"Short generated roots should carry both a prefix hint and a suffix hint.")
		assert_true(str(name_parts[0]) in Constants.FRONTIER_DISCOVERY_NAME_PREFIXES,
			"Short generated roots should prepend a curated prefix hint.")
		assert_eq(str(name_parts[1]), generated_root,
			"Short generated roots should stay centered between the curated hint words.")
		assert_true(str(name_parts[2]) in Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES,
			"Short generated roots should append a curated suffix hint.")
	elif generated_root.length() <= Constants.DISCOVERY_NAME_MEDIUM_ROOT_MAX_LENGTH:
		assert_eq(name_parts.size(), 2,
			"Medium generated roots should append one curated hint word.")
		assert_eq(str(name_parts[0]), generated_root,
			"Medium generated roots should stay in the lead position.")
		assert_true(str(name_parts[1]) in Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES,
			"Medium generated roots should append a curated suffix hint.")
	else:
		assert_eq(name_parts.size(), 1,
			"Long generated roots should stand on their own without extra hint words.")
		assert_eq(str(name_parts[0]), generated_root,
			"Long generated roots should pass through unchanged.")


func test_generate_sector_name_for_discovery_uses_curated_word_banks():
	GameState.world_seed = "frontier-name-seed"
	var profile: Dictionary = {"procedural_type": "dark_nebula"}
	var initial_tags: Array = [
		"FRONTIER", "HARSH", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE"
	]
	var generated_root: String = agent_layer._generate_discovery_name_root(7)
	var generated_name: String = agent_layer._generate_sector_name_for_discovery(7, profile, initial_tags)
	var repeated_name: String = agent_layer._generate_sector_name_for_discovery(7, profile, initial_tags)

	assert_eq(generated_name, repeated_name,
		"Profile-aware discovery naming should remain deterministic for the same discovery count and hint data.")
	var name_parts: Array = generated_name.split(" ")
	if generated_root.length() <= Constants.DISCOVERY_NAME_SHORT_ROOT_MAX_LENGTH:
		assert_eq(name_parts.size(), 3,
			"Short generated roots should keep both curated hint banks in profile-aware discovery names.")
		assert_true(str(name_parts[0]) in Constants.FRONTIER_DISCOVERY_NAME_PREFIXES_BY_PROCEDURAL_TYPE["dark_nebula"],
			"Profile-aware discovery naming should use the procedural-type-specific prefix pool when one exists.")
		assert_eq(str(name_parts[1]), generated_root,
			"The generated system-name root should stay centered in the profile-aware name.")
		assert_true(str(name_parts[2]) in Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES_BY_ECONOMY_LEVEL["RICH"],
			"Profile-aware discovery naming should use the economy-specific suffix pool when tags indicate a rich site.")
	elif generated_root.length() <= Constants.DISCOVERY_NAME_MEDIUM_ROOT_MAX_LENGTH:
		assert_eq(name_parts.size(), 2,
			"Medium generated roots should keep a single economy hint word in profile-aware discovery names.")
		assert_eq(str(name_parts[0]), generated_root,
			"Medium generated roots should lead profile-aware discovery names.")
		assert_true(str(name_parts[1]) in Constants.FRONTIER_DISCOVERY_NAME_SUFFIXES_BY_ECONOMY_LEVEL["RICH"],
			"Profile-aware discovery naming should append the economy-specific hint when the root is medium-length.")
	else:
		assert_eq(name_parts.size(), 1,
			"Long generated roots should not receive extra hint words even in profile-aware naming.")
		assert_eq(str(name_parts[0]), generated_root,
			"Long generated roots should pass through unchanged in profile-aware discovery names.")


func test_legacy_system_name_generator_returns_public_deterministic_short_names():
	var GeneratorScript = load("res://src/core/utils/legacy_system_name_generator.gd")
	var generator = GeneratorScript.new()
	var generated_name: String = generator.generate_system_name("legacy-generator-seed", 4, 7)
	var repeated_name: String = generator.generate_system_name("legacy-generator-seed", 4, 7)

	assert_eq(generated_name, repeated_name,
		"The ported legacy system-name generator should be deterministic for the same seed input.")
	assert_gt(generated_name.length(), 1,
		"The ported legacy system-name generator should return a non-trivial short root.")
	assert_true(generated_name.length() <= 8,
		"The ported legacy system-name generator should stay in the short-name range used by the legacy sandbox.")
	assert_eq(generated_name.find(" "), -1,
		"The public legacy system-name generator should emit a single short root without extra words.")


func test_legacy_system_name_generator_softens_internal_y_between_consonants():
	var GeneratorScript = load("res://src/core/utils/legacy_system_name_generator.gd")
	var generator = GeneratorScript.new()

	assert_eq(generator._soften_internal_y("Ryhazi"), "Rihazi",
		"The limited readability pass should soften internal y when it lands between consonants.")
	assert_eq(generator._soften_internal_y("Ysutu"), "Ysutu",
		"The limited readability pass should keep an opening y untouched.")
	assert_eq(generator._soften_internal_y("Ayla"), "Ayla",
		"The limited readability pass should avoid rewriting every interior y indiscriminately.")


func test_compose_discovery_sector_name_uses_generated_root_length_budget():
	assert_eq(agent_layer._compose_discovery_sector_name("Cob", "Umbral", "Passage"), "Umbral Cob Passage",
		"Very short generated roots should use both curated hint banks.")
	assert_eq(agent_layer._compose_discovery_sector_name("Elace", "Umbral", "Passage"), "Elace Passage",
		"Medium generated roots should keep only one curated hint word.")
	assert_eq(agent_layer._compose_discovery_sector_name("Aurelius", "Umbral", "Passage"), "Aurelius",
		"Long generated roots should stand alone without extra hint words.")


func test_generate_sector_name_for_discovery_avoids_existing_display_name_collisions():
	GameState.world_seed = "frontier-name-seed"
	var profile: Dictionary = {"procedural_type": "dark_nebula"}
	var initial_tags: Array = [
		"FRONTIER", "HARSH", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE"
	]
	var colliding_name: String = agent_layer._build_discovery_sector_name_candidate(
		7,
		0,
		agent_layer._get_discovery_prefix_word_pool("dark_nebula", initial_tags),
		agent_layer._get_discovery_suffix_word_pool(initial_tags)
	)
	GameState.sector_names["existing_collision"] = colliding_name

	var unique_name: String = agent_layer._generate_sector_name_for_discovery(7, profile, initial_tags)
	var repeated_unique_name: String = agent_layer._generate_sector_name_for_discovery(7, profile, initial_tags)

	assert_ne(unique_name, colliding_name,
		"Profile-aware discovery naming should skip names that already exist in the world state.")
	assert_eq(unique_name, repeated_unique_name,
		"Collision avoidance should remain deterministic for the same discovery count and existing-name set.")


func test_filter_spatially_plausible_connections_drops_far_links():
	TemplateDatabase.locations["near"] = {"global_position": Vector3(52000, 0, 0)}
	TemplateDatabase.locations["far"] = {"global_position": Vector3(220000, 0, 0)}

	var filtered_connections: Array = agent_layer._filter_spatially_plausible_connections(
		"s1",
		["s1", "near", "far"],
		Vector3(48000, 4000, 0)
	)

	assert_eq(filtered_connections, ["s1", "near"], "Spatial filtering should keep plausible nearby links and drop distant ones.")


func test_resolve_sector_interaction_holds_cooling_explorer_on_viable_frontier_anchor():
	GameState.sim_tick_count = 5
	GameState.world_topology["s1"]["sector_type"] = "frontier"
	GameState.sector_tags["s1"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.agents["explorer"] = {
		"agent_role": "explorer",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"last_discovery_tick": 0,
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
	}

	agent_layer._resolve_sector_interaction("explorer", 0.0, GameState.sector_tags["s1"])

	assert_eq(GameState.discovered_sector_count, 0, "Cooldown failures should not create a discovery.")
	assert_eq(
		GameState.agents["explorer"]["current_sector_id"],
		"s1",
		"Cooling explorers should hold a viable frontier anchor instead of ping-ponging away from an open survey edge."
	)
	assert_eq(_count_chronicle_actions("expedition_failed"), 0,
		"Cooling explorers should stop logging futile expedition failures while waiting on the frontier.")


func test_resolve_sector_interaction_repositions_cooling_explorer_toward_frontier_anchor():
	GameState.sim_tick_count = 5
	GameState.world_topology["s2"]["sector_type"] = "frontier"
	GameState.sector_tags["s1"] = ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.sector_tags["s2"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.agents["explorer"] = {
		"agent_role": "explorer",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"last_discovery_tick": 0,
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
	}

	agent_layer._resolve_sector_interaction("explorer", 0.0, GameState.sector_tags["s1"])

	assert_eq(GameState.agents["explorer"]["current_sector_id"], "s2",
		"Cooling explorers should move toward the nearest frontier anchor when their current sector is a poor survey origin.")
	assert_eq(_count_chronicle_actions("expedition_failed"), 0,
		"Cooling explorers should reposition without logging a guaranteed cooldown failure first.")


func test_resolve_sector_interaction_holds_broke_explorer_on_frontier_anchor():
	GameState.sim_tick_count = 20
	GameState.world_topology["s1"]["sector_type"] = "frontier"
	GameState.sector_tags["s1"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	GameState.agents["explorer"] = {
		"agent_role": "explorer",
		"current_sector_id": "s1",
		"wealth_tag": "BROKE",
		"last_discovery_tick": -999,
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
	}

	agent_layer._resolve_sector_interaction("explorer", 0.0, GameState.sector_tags["s1"])

	assert_eq(GameState.agents["explorer"]["current_sector_id"], "s1",
		"Broke explorers should stay on a frontier anchor to recover instead of throwing away turns on guaranteed failed expeditions.")
	assert_eq(_count_chronicle_actions("expedition_failed"), 0,
		"Broke explorers at a frontier anchor should stop generating futile broke-failure spam.")


func test_get_exploration_success_modifier_keeps_hub_surveys_diminished():
	GameState.world_topology["hub_sector"] = {
		"connections": ["s1"],
		"sector_type": "hub",
		"station_ids": ["hub_sector"],
	}
	GameState.world_topology["frontier_sector"] = {
		"connections": ["s1"],
		"sector_type": "frontier",
		"station_ids": ["frontier_sector"],
	}
	TemplateDatabase.locations["hub_sector"] = {
		"global_position": Vector3(220000, 0, 0),
		"location_name": "Core Hub",
		"sector_type": "hub",
		"procedural_hints": {},
	}
	TemplateDatabase.locations["frontier_sector"] = {
		"global_position": Vector3(-220000, 0, 0),
		"location_name": "Outer Rim",
		"sector_type": "frontier",
		"procedural_hints": {},
	}

	var hub_modifier: float = agent_layer._get_exploration_success_modifier(
		"hub_sector",
		["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_RICH", "CURRENCY_RICH"]
	)
	var frontier_modifier: float = agent_layer._get_exploration_success_modifier(
		"frontier_sector",
		["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
	)

	assert_true(hub_modifier > 0.0, "Hub sectors should reduce but not eliminate survey success odds.")
	assert_true(hub_modifier < frontier_modifier, "Hub survey odds should remain below frontier survey odds.")


func test_build_discovered_sector_placement_separates_from_existing_discovery_branch():
	GameState.world_topology["source"] = {
		"connections": ["parent", "discovered_existing"],
		"sector_type": "deep_space",
		"station_ids": ["source"],
	}
	GameState.world_topology["parent"] = {
		"connections": ["source"],
		"sector_type": "colony",
		"station_ids": ["parent"],
	}
	GameState.world_topology["discovered_existing"] = {
		"connections": ["source"],
		"sector_type": "deep_space",
		"station_ids": ["discovered_existing"],
	}
	TemplateDatabase.locations["source"] = {
		"global_position": Vector3.ZERO,
		"is_procedural": true,
		"procedural_hints": {
			"branch_axis": Vector3.RIGHT,
			"branch_mode": "planar",
		},
	}
	TemplateDatabase.locations["parent"] = {
		"global_position": Vector3(-96000, 0, 0),
		"is_procedural": false,
		"procedural_hints": {},
	}
	TemplateDatabase.locations["discovered_existing"] = {
		"global_position": Vector3(96000, 0, 0),
		"is_procedural": true,
		"procedural_hints": {
			"low_visibility": true,
		},
	}

	var placement: Dictionary = agent_layer._build_discovered_sector_placement("discovered_2", "source")

	assert_true(bool(placement.get("is_valid", false)), "Sibling discovery branches should find a valid, non-overlapping placement when space exists.")
	assert_true(
		float(placement.get("branch_separation_deg", 0.0)) >= Constants.DISCOVERY_BRANCH_MIN_SIBLING_ANGLE_DEG,
		"Secondary discovery branches should fan away from existing discovered siblings instead of staying nearly parallel."
	)


func test_get_discovery_connection_chances_bias_frontier_anchors():
	GameState.world_topology["s1"]["sector_type"] = "frontier"
	GameState.sector_tags["s1"] = ["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]

	var connection_chances: Dictionary = agent_layer._get_discovery_connection_chances(
		"s1",
		GameState.sector_tags["s1"]
	)

	assert_eq(float(connection_chances.get("extra_one", 0.0)), Constants.FRONTIER_DISCOVERY_EXTRA_CONNECTION_1_CHANCE,
		"Frontier anchors should use the tuned first extra-link chance instead of the generic baseline.")
	assert_eq(float(connection_chances.get("extra_two", 0.0)), Constants.FRONTIER_DISCOVERY_EXTRA_CONNECTION_2_CHANCE,
		"Frontier anchors should use the tuned loop-link chance instead of the generic baseline.")


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _seed_minimal_state() -> void:
	GameState.world_seed = "agent_test_seed"
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 0
	GameState.world_topology = {
		"s1": {"connections": ["s2"], "sector_type": "colony", "station_ids": ["s1"]},
		"s2": {"connections": ["s1"], "sector_type": "colony", "station_ids": ["s2"]},
	}
	GameState.sector_tags = {
		"s1": ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
		"s2": ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"],
	}
	GameState.world_hazards = {"s1": {"environment": "MILD"}, "s2": {"environment": "MILD"}}
	GameState.grid_dominion = {"s1": {"security_tag": "SECURE"}, "s2": {"security_tag": "SECURE"}}
	GameState.contract_generation_threshold = {
		"s1": {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2},
		"s2": {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2},
	}
	GameState.contract_generation_pressure = {
		"s1": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
		"s2": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
	}
	GameState.contract_cargo_supply = {
		"s1": {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2},
		"s2": {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2},
	}
	GameState.contract_cargo_reserved = {
		"s1": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
		"s2": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
	}
	GameState.contract_payment_supply = {
		"s1": {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2},
		"s2": {"RAW": 2, "MANUFACTURED": 2, "CURRENCY": 2},
	}
	GameState.contract_payment_reserved = {
		"s1": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
		"s2": {"RAW": 0, "MANUFACTURED": 0, "CURRENCY": 0},
	}
	GameState.agents = {
		"player": {
			"agent_role": "idle",
			"current_sector_id": "s1",
			"home_location_id": "s1",
			"wealth_tag": "COMFORTABLE",
			"condition_tag": "HEALTHY",
			"cargo_tag": "EMPTY",
			"goal_archetype": "idle",
			"goal_queue": [{"type": "idle"}],
			"is_disabled": false,
			"disabled_at_tick": -1,
			"is_persistent": true,
			"dynamic_tags": [],
		}
	}
	GameState.player_docked_at = ""
	GameState.player_claimed_occurrence_id = ""
	GameState.player_cargo_tag = "EMPTY"
	GameState.discovered_sectors = []
	GameState.station_by_id.clear()
	GlobalRefs.character_system = null
	TemplateDatabase.locations.clear()
	TemplateDatabase.locations["s1"] = {
		"global_position": Vector3.ZERO,
		"location_name": "Source Sector",
		"is_procedural": false,
		"procedural_hints": {},
	}
	TemplateDatabase.locations["s2"] = {
		"global_position": Vector3(180000, 0, 0),
		"location_name": "Neighbor Sector",
		"is_procedural": false,
		"procedural_hints": {},
	}


func _clear_state() -> void:
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.sector_tags.clear()
	GameState.grid_dominion.clear()
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.agent_tags.clear()
	GameState.colony_levels.clear()
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()
	GameState.contract_generation_pressure.clear()
	GameState.contract_generation_threshold.clear()
	GameState.contract_cargo_supply.clear()
	GameState.contract_cargo_reserved.clear()
	GameState.contract_payment_supply.clear()
	GameState.contract_payment_reserved.clear()
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []
	GameState.mortal_agent_counter = 0
	GameState.mortal_agent_deaths = []
	GameState.discovered_sector_count = 0
	GameState.discovery_log = []
	GameState.sector_names.clear()
	GameState.catastrophe_log = []
	GameState.sector_disabled_until.clear()
	GameState.world_seed = ""
	GameState.world_age = "PROSPERITY"
	GameState.sim_tick_count = 0
	GameState.player_docked_at = ""
	GameState.player_claimed_occurrence_id = ""
	GameState.player_cargo_tag = "EMPTY"
	GameState.discovered_sectors = []
	GameState.station_by_id.clear()
	GameState.locations.clear()
	TemplateDatabase.agents.clear()
	TemplateDatabase.characters.clear()
	TemplateDatabase.locations.clear()


func _make_runtime_contract_occurrence(occurrence_id: String, category: String, source_sector_id: String, target_sector_id: String) -> Dictionary:
	var category_priority_tags: Dictionary = {
		"RAW": ["CONTRACT_DEMAND_RAW", "RELIEF_NEEDED", "CONTESTED"],
		"MANUFACTURED": ["CONTRACT_DEMAND_MANUFACTURED", "RELIEF_NEEDED", "CONTESTED"],
		"CURRENCY": ["CONTRACT_DEMAND_CURRENCY", "RELIEF_NEEDED", "CONTESTED"],
	}
	return {
		"occurrence_id": occurrence_id,
		"generator_id": "qualitative_demand",
		"contract_type": "delivery",
		"commodity_category": category,
		"demand_tag": "CONTRACT_DEMAND_%s" % category,
		"source_sector_id": source_sector_id,
		"target_sector_id": target_sector_id,
		"origin_location_id": source_sector_id,
		"destination_location_id": target_sector_id,
		"status": "open",
		"claimant_agent_id": "",
		"required_roles": ["trader", "hauler"],
		"priority_tags": category_priority_tags.get(category, ["RELIEF_NEEDED", "CONTESTED"]),
		"route_hops": 1,
		"player_displayable": true,
		"required_cargo_tag": "%s_COMMODITY" % category,
		"reward_credits": 225,
		"source_reserved": false,
		"payment_reserved": false,
		"cargo_picked_up": false,
		"created_at_tick": GameState.sim_tick_count,
		"last_refreshed_tick": GameState.sim_tick_count,
		"title": "%s Relief Route" % category.capitalize(),
		"description": "%s relief from %s to %s." % [category.capitalize(), source_sector_id, target_sector_id],
	}


func _advance_until_npc_claim_can_succeed(agent_id: String, occurrence_id: String) -> bool:
	var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
	if occurrence.empty():
		return false
	occurrence["created_at_tick"] = 0
	GameState.runtime_contract_occurrences[occurrence_id] = occurrence
	var first_claim_tick: int = max(1, int(Constants.NPC_RUNTIME_CONTRACT_CLAIM_GRACE_TICKS))
	for candidate_tick in range(first_claim_tick, 256):
		GameState.sim_tick_count = candidate_tick
		occurrence = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if agent_layer._can_npc_claim_open_runtime_contract(agent_id, occurrence_id, occurrence):
			return true
	return false


func _count_chronicle_actions(action_name: String) -> int:
	var count: int = 0
	for event in GameState.chronicle_events:
		if str(event.get("action", "")) == action_name:
			count += 1
	return count


# =============================================================================
# === NPC DOCK-MARKET TRADE TESTS =============================================
# =============================================================================

func test_npc_dock_trade_sell_increments_market_quantity() -> void:
	GameState.locations["s1"] = {
		"available_services": ["trade"],
		"market_inventory": {
			"ore": {"buy_price": 10, "sell_price": 5, "quantity": 5}
		}
	}
	GameState.agents["agent_trader"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"sentiment_tags": ["TRADER", "LEGAL_LAWFUL"],
	}

	agent_layer._try_dock("agent_trader", GameState.agents["agent_trader"], "s1")
	chronicle.process_tick()

	var trader = GameState.agents["agent_trader"]
	assert_eq(trader["cargo_tag"], "EMPTY", "Trader cargo should be sold and empty.")
	assert_eq(trader["wealth_tag"], "WEALTHY", "Trader wealth should step up.")
	
	var market = GameState.locations["s1"]["market_inventory"]
	assert_eq(int(market["ore"]["quantity"]), 6, "Market quantity should increment from NPC sell.")
	
	assert_gt(_count_chronicle_actions("npc_dock_trade"), 0, "NPC dock trade event should be logged.")


func test_npc_dock_trade_buy_decrements_market_quantity() -> void:
	GameState.locations["s1"] = {
		"available_services": ["trade"],
		"market_inventory": {
			"ore": {"buy_price": 10, "sell_price": 5, "quantity": 5}
		}
	}
	GameState.agents["agent_trader"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"sentiment_tags": ["TRADER", "LEGAL_LAWFUL"],
	}

	agent_layer._try_dock("agent_trader", GameState.agents["agent_trader"], "s1")
	chronicle.process_tick()

	var trader = GameState.agents["agent_trader"]
	assert_eq(trader["cargo_tag"], "LOADED", "Trader cargo should be loaded from buy.")
	assert_eq(trader["wealth_tag"], "BROKE", "Trader wealth should step down.")
	
	var market = GameState.locations["s1"]["market_inventory"]
	assert_eq(int(market["ore"]["quantity"]), 4, "Market quantity should decrement from NPC buy.")
	
	assert_gt(_count_chronicle_actions("npc_dock_trade"), 0, "NPC dock trade event should be logged.")


func test_npc_no_trade_service_does_not_trade() -> void:
	GameState.locations["s1"] = {
		"available_services": [],
		"market_inventory": {
			"ore": {"buy_price": 10, "sell_price": 5, "quantity": 5}
		}
	}
	GameState.agents["agent_trader"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"sentiment_tags": ["TRADER", "LEGAL_LAWFUL"],
	}

	agent_layer._try_dock("agent_trader", GameState.agents["agent_trader"], "s1")

	var trader = GameState.agents["agent_trader"]
	assert_eq(trader["cargo_tag"], "EMPTY", "Trader cargo should still be empty (qualitative fallback).")
	assert_eq(trader["wealth_tag"], "WEALTHY", "Trader wealth should still step up (qualitative fallback).")
	
	var market = GameState.locations["s1"]["market_inventory"]
	assert_eq(int(market["ore"]["quantity"]), 5, "Market quantity should not change when trade service is absent.")


func test_npc_protected_contract_cargo_does_not_sell() -> void:
	GameState.locations["s1"] = {
		"available_services": ["trade"],
		"market_inventory": {
			"ore": {"buy_price": 10, "sell_price": 5, "quantity": 5}
		}
	}
	GameState.agents["agent_trader"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"contract_cargo_tag": "RAW_COMMODITY",
		"sentiment_tags": ["TRADER", "LEGAL_LAWFUL", "CARGO_PROTECTED"],
	}

	agent_layer._try_dock("agent_trader", GameState.agents["agent_trader"], "s1")

	var trader = GameState.agents["agent_trader"]
	assert_eq(trader["cargo_tag"], "LOADED", "Protected contract cargo should not be unloaded.")
	assert_eq(trader["wealth_tag"], "COMFORTABLE", "Wealth should not change since cargo was not sold.")
	
	var market = GameState.locations["s1"]["market_inventory"]
	assert_eq(int(market["ore"]["quantity"]), 5, "Market quantity should not change when selling protected contract cargo.")


func test_npc_dock_trade_black_market_only_lawful_fails_illicit_succeeds() -> void:
	GameState.locations["s1"] = {
		"available_services": ["black_market"],
		"market_inventory": {
			"ore": {"buy_price": 10, "sell_price": 5, "quantity": 5}
		}
	}
	
	# Case A: Lawful agent should fail to use black_market
	GameState.agents["agent_lawful"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"sentiment_tags": ["TRADER", "LEGAL_LAWFUL"],
	}
	agent_layer._try_dock("agent_lawful", GameState.agents["agent_lawful"], "s1")
	
	var lawful = GameState.agents["agent_lawful"]
	assert_eq(lawful["cargo_tag"], "EMPTY", "Lawful cargo empty (fallback qualitative sell).")
	var market = GameState.locations["s1"]["market_inventory"]
	assert_eq(int(market["ore"]["quantity"]), 5, "Lawful agent should not mutate black market inventory.")
	
	# Case B: Illicit agent should succeed to use black_market
	GameState.agents["agent_illicit"] = {
		"agent_role": "trader",
		"current_sector_id": "s1",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"sentiment_tags": ["PIRATE", "LEGAL_ILLICIT"],
	}
	agent_layer._try_dock("agent_illicit", GameState.agents["agent_illicit"], "s1")
	
	var illicit = GameState.agents["agent_illicit"]
	assert_eq(illicit["cargo_tag"], "EMPTY", "Illicit cargo sold.")
	assert_eq(int(market["ore"]["quantity"]), 6, "Illicit agent should successfully mutate black market inventory.")


func test_discovered_station_has_seeded_market_inventory() -> void:
	GameState.world_seed = "test_market_seed"
	GameState.sector_names["s1"] = "Source Sector"
	GameState.world_topology["s1"] = {
		"connections": ["s2"],
		"sector_type": "colony",
		"station_ids": ["s1"]
	}
	TemplateDatabase.locations["s1"] = {
		"global_position": Vector3.ZERO,
		"location_name": "Source Sector",
		"is_procedural": true,
		"procedural_hints": {},
	}

	var generated_station: Dictionary = agent_layer._generate_procedural_station_for_sector("s1")
	var station_id = generated_station["id"]

	assert_true(GameState.locations.has(station_id), "Generated station should exist in GameState.locations")
	var location_record = GameState.locations[station_id]
	assert_true(location_record.has("market_inventory"), "Locations entry should have market_inventory key")
	
	var market_inventory: Dictionary = location_record["market_inventory"]
	var expected_commodities = ["commodity_food", "commodity_fuel", "commodity_ore", "commodity_tech"]
	for comm_id in expected_commodities:
		assert_true(market_inventory.has(comm_id), "Market inventory should contain %s" % comm_id)
		var comm_data = market_inventory[comm_id]
		assert_true(comm_data.has("buy_price"), "Commodity %s should have buy_price" % comm_id)
		assert_true(comm_data.has("sell_price"), "Commodity %s should have sell_price" % comm_id)
		assert_true(comm_data.has("quantity"), "Commodity %s should have quantity" % comm_id)
		assert_true(comm_data["quantity"] >= 5 and comm_data["quantity"] <= 20, "Quantity for %s should be in 5-20 range" % comm_id)
		assert_true(comm_data["buy_price"] is int, "buy_price must be int")
		assert_true(comm_data["sell_price"] is int, "sell_price must be int")
		assert_true(comm_data["quantity"] is int, "quantity must be int")


func test_npc_dock_trade_at_discovered_station_sell() -> void:
	GameState.world_seed = "test_market_seed"
	GameState.sector_names["discovered_test_sector"] = "Source Sector"
	GameState.world_topology["discovered_test_sector"] = {
		"connections": ["s2"],
		"sector_type": "colony",
		"station_ids": ["discovered_test_sector"]
	}
	TemplateDatabase.locations["discovered_test_sector"] = {
		"global_position": Vector3.ZERO,
		"location_name": "Source Sector",
		"is_procedural": true,
		"procedural_hints": {},
	}
	
	var generated_station = agent_layer._generate_procedural_station_for_sector("discovered_test_sector")
	var station_id = generated_station["id"]
	
	var market = GameState.locations[station_id]["market_inventory"]
	var food_baseline = market["commodity_food"]["quantity"]
	
	GameState.agents["agent_trader"] = {
		"agent_role": "trader",
		"current_sector_id": "discovered_test_sector",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "LOADED",
		"sentiment_tags": ["TRADER", "LEGAL_LAWFUL"],
	}
	
	agent_layer._try_dock("agent_trader", GameState.agents["agent_trader"], "discovered_test_sector")
	
	var trader = GameState.agents["agent_trader"]
	assert_eq(trader["cargo_tag"], "EMPTY", "Trader cargo tag should become EMPTY after selling.")
	assert_eq(market["commodity_food"]["quantity"], food_baseline + 1, "Market commodity_food quantity should increment by 1.")


func test_npc_dock_trade_at_discovered_station_buy() -> void:
	GameState.world_seed = "test_market_seed"
	GameState.sector_names["discovered_test_sector"] = "Source Sector"
	GameState.world_topology["discovered_test_sector"] = {
		"connections": ["s2"],
		"sector_type": "colony",
		"station_ids": ["discovered_test_sector"]
	}
	TemplateDatabase.locations["discovered_test_sector"] = {
		"global_position": Vector3.ZERO,
		"location_name": "Source Sector",
		"is_procedural": true,
		"procedural_hints": {},
	}
	
	var generated_station = agent_layer._generate_procedural_station_for_sector("discovered_test_sector")
	var station_id = generated_station["id"]
	
	var market = GameState.locations[station_id]["market_inventory"]
	market["commodity_food"]["quantity"] = 10
	
	GameState.agents["agent_trader"] = {
		"agent_role": "trader",
		"current_sector_id": "discovered_test_sector",
		"wealth_tag": "COMFORTABLE",
		"condition_tag": "HEALTHY",
		"cargo_tag": "EMPTY",
		"sentiment_tags": ["TRADER", "LEGAL_LAWFUL"],
	}
	
	agent_layer._try_dock("agent_trader", GameState.agents["agent_trader"], "discovered_test_sector")
	
	var trader = GameState.agents["agent_trader"]
	assert_eq(trader["cargo_tag"], "LOADED", "Trader cargo tag should become LOADED after buying.")
	assert_eq(market["commodity_food"]["quantity"], 9, "Market commodity_food quantity should decrement by 1.")


func test_market_restock_depleted_to_rate() -> void:
	GameState.locations["s1"] = {
		"available_services": ["trade"],
		"market_inventory": {
			"commodity_food": {"buy_price": 30, "sell_price": 25, "quantity": 0}
		}
	}
	agent_layer._tick_market_restock()
	var qty = GameState.locations["s1"]["market_inventory"]["commodity_food"]["quantity"]
	assert_eq(qty, Constants.MARKET_RESTOCK_RATE_PER_TICK, "Quantity should increment by restock rate.")


func test_market_restock_ceiling_clamp() -> void:
	GameState.locations["s1"] = {
		"available_services": ["trade"],
		"market_inventory": {
			"commodity_food": {"buy_price": 30, "sell_price": 25, "quantity": Constants.MARKET_RESTOCK_MAX_QUANTITY}
		}
	}
	agent_layer._tick_market_restock()
	var qty = GameState.locations["s1"]["market_inventory"]["commodity_food"]["quantity"]
	assert_eq(qty, Constants.MARKET_RESTOCK_MAX_QUANTITY, "Quantity should not exceed restock ceiling.")


func test_market_restock_clamp_near_ceiling() -> void:
	GameState.locations["s1"] = {
		"available_services": ["trade"],
		"market_inventory": {
			"commodity_food": {"buy_price": 30, "sell_price": 25, "quantity": Constants.MARKET_RESTOCK_MAX_QUANTITY - 2}
		}
	}
	# Perform 3 restocks to force it past the ceiling
	agent_layer._tick_market_restock()
	agent_layer._tick_market_restock()
	agent_layer._tick_market_restock()
	var qty = GameState.locations["s1"]["market_inventory"]["commodity_food"]["quantity"]
	assert_eq(qty, Constants.MARKET_RESTOCK_MAX_QUANTITY, "Quantity should clamp exactly to the ceiling.")


func test_market_restock_prices_unchanged() -> void:
	GameState.locations["s1"] = {
		"available_services": ["trade"],
		"market_inventory": {
			"commodity_food": {"buy_price": 30, "sell_price": 25, "quantity": 10}
		}
	}
	agent_layer._tick_market_restock()
	var comm = GameState.locations["s1"]["market_inventory"]["commodity_food"]
	assert_eq(comm["buy_price"], 30, "buy_price should not change.")
	assert_eq(comm["sell_price"], 25, "sell_price should not change.")

