#
# PROJECT: GDTLancer
# MODULE: test_simulation_reasonableness.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md TASK_1; TRUTH_SIMULATION-GRAPH.md §6.1, §6.2, §6.3, §6.4
# LOG_REF: 2026-05-24 19:24:50
#

extends GutTest

## Guardrail test: seeded long-run probe for qualitative simulation reasonableness.
##
## This stays read-only with respect to the chronicle/report tooling and asserts
## that a medium-length seeded run remains bounded, active, and non-collapsed.

const TEST_SEED: String = "reasonableness_guardrail_seed"
const TEST_TICK_COUNT: int = 360
const SAMPLE_INTERVAL: int = 30
const FRONTIER_COMPOSITE_SEED: String = "1779638654"
const FRONTIER_WINDOW_TICKS: Array = [300, 3000]
const FRONTIER_TOTAL_SECTOR_MAX: Dictionary = {300: 55, 3000: 210}
const FRONTIER_DISCOVERED_SECTOR_MAX: Dictionary = {300: 45, 3000: 200}
const FRONTIER_BOTTLENECK_RATIO_MAX: Dictionary = {300: 0.75, 3000: 0.67}
const FRONTIER_AVG_DEGREE_MIN: Dictionary = {300: 1.3, 3000: 2.0}
const FRONTIER_AVG_DEGREE_MAX: Dictionary = {300: 2.2, 3000: 2.3}
const FRONTIER_MAX_DEGREE_MAX: Dictionary = {300: 4, 3000: 4}
const FRONTIER_PERSISTENT_EXPLORER_DISCOVERY_MIN: Dictionary = {300: 4, 3000: 20}
const FRONTIER_PERSISTENT_EXPLORER_STAGNATION_RATIO_MAX: Dictionary = {300: 0.97, 3000: 0.97}
const FRONTIER_PERSISTENT_EXPLORER_STAGNANT_ACTIONS_PER_DISCOVERY_MAX: Dictionary = {
	300: 100.0,
	3000: 200.0,
}

var engine: Node = null


func before_each() -> void:
	_reinitialize_engine(TEST_SEED)


func after_each() -> void:
	engine = null
	_clear_state()


func test_seeded_long_run_remains_bounded_active_and_varied() -> void:
	var metrics: Dictionary = _run_reasonableness_probe(TEST_TICK_COUNT)

	assert_eq(Array(metrics.get("observed_ages", [])).size(), 3,
		"A 360-tick seeded run should traverse PROSPERITY, DISRUPTION, and RECOVERY.")
	assert_true(int(metrics.get("max_agent_count", 0)) <= Constants.MORTAL_GLOBAL_CAP,
		"Agent population should stay bounded by the configured mortal global cap.")
	assert_gt(int(metrics.get("spawn_count", 0)), 0,
		"A seeded long run should produce some mortal spawn churn instead of remaining static.")
	assert_gt(int(metrics.get("trade_count", 0)), 0,
		"A seeded long run should produce at least one trade event.")
	assert_gt(int(metrics.get("contract_activity_count", 0)), 0,
		"A seeded long run should produce actual contract claim/load/complete activity, not only open demand.")
	assert_true(
		int(metrics.get("max_runtime_contract_occurrences", 0)) > 0,
		"A seeded long run should surface live runtime contract occurrences at some point in the run.")
	assert_true(int(metrics.get("final_security_diversity", 0)) >= 2,
		"Final sector security should not collapse into a single uniform state across the whole map.")
	assert_true(int(metrics.get("final_economy_profile_diversity", 0)) >= 2,
		"Final sector economy profiles should retain at least two distinct qualitative combinations.")


func test_composite_seeded_frontier_growth_stays_within_guardrails() -> void:
	_reinitialize_engine(FRONTIER_COMPOSITE_SEED)
	var metrics: Dictionary = _run_reasonableness_probe(
		int(FRONTIER_WINDOW_TICKS[FRONTIER_WINDOW_TICKS.size() - 1]),
		FRONTIER_WINDOW_TICKS
	)
	var persistent_explorer_ids: Array = Array(metrics.get("persistent_explorer_ids", []))
	assert_gt(
		persistent_explorer_ids.size(),
		0,
		"The composite-seed guardrail needs at least one persistent explorer to measure frontier behavior."
	)

	var window_metrics: Dictionary = Dictionary(metrics.get("window_metrics", {}))
	for tick_mark in FRONTIER_WINDOW_TICKS:
		assert_true(
			window_metrics.has(tick_mark),
			"The frontier guardrail should capture a cumulative snapshot at tick %d." % tick_mark
		)
		var snapshot: Dictionary = Dictionary(window_metrics.get(tick_mark, {}))
		var topology: Dictionary = Dictionary(snapshot.get("topology", {}))
		var explorer_mix: Dictionary = Dictionary(snapshot.get("persistent_explorer_mix", {}))

		assert_gt(
			int(snapshot.get("trade_count", 0)),
			0,
			"The %d-tick frontier guardrail should preserve live trade activity while measuring exploration pressure." % tick_mark
		)
		assert_gt(
			int(snapshot.get("contract_activity_count", 0)),
			0,
			"The %d-tick frontier guardrail should preserve runtime contract activity while measuring frontier growth." % tick_mark
		)
		assert_true(
			int(topology.get("total_sectors", 0)) <= int(FRONTIER_TOTAL_SECTOR_MAX.get(tick_mark, 0)),
			"Total sector count should stay bounded at tick %d." % tick_mark
		)
		assert_true(
			int(topology.get("discovered_sectors", 0)) <= int(FRONTIER_DISCOVERED_SECTOR_MAX.get(tick_mark, 0)),
			"Discovered sector count should stay bounded at tick %d." % tick_mark
		)
		assert_true(
			float(topology.get("bottleneck_ratio", 1.0)) <= float(FRONTIER_BOTTLENECK_RATIO_MAX.get(tick_mark, 0.0)),
			"Topology bottlenecks should remain below the composite-derived ceiling at tick %d." % tick_mark
		)
		assert_true(
			float(topology.get("avg_degree", 0.0)) >= float(FRONTIER_AVG_DEGREE_MIN.get(tick_mark, 0.0)),
			"Average degree should stay above the minimum composite-derived floor at tick %d." % tick_mark
		)
		assert_true(
			float(topology.get("avg_degree", 0.0)) <= float(FRONTIER_AVG_DEGREE_MAX.get(tick_mark, 0.0)),
			"Average degree should stay below the composite-derived ceiling at tick %d." % tick_mark
		)
		assert_true(
			int(topology.get("max_degree", 0)) <= int(FRONTIER_MAX_DEGREE_MAX.get(tick_mark, 0)),
			"Discovery branching should stay within the observed composite degree ceiling at tick %d." % tick_mark
		)
		assert_true(
			int(explorer_mix.get("sector_discovered", 0)) >= int(FRONTIER_PERSISTENT_EXPLORER_DISCOVERY_MIN.get(tick_mark, 0)),
			"Persistent explorers should keep producing some real discoveries by tick %d." % tick_mark
		)
		assert_true(
			float(explorer_mix.get("stagnation_ratio", 1.0)) <= float(FRONTIER_PERSISTENT_EXPLORER_STAGNATION_RATIO_MAX.get(tick_mark, 0.0)),
			"Persistent explorer action mix should not collapse entirely into move plus expedition_failed at tick %d." % tick_mark
		)
		assert_true(
			float(explorer_mix.get("stagnant_actions_per_discovery", 999999.0)) <= float(FRONTIER_PERSISTENT_EXPLORER_STAGNANT_ACTIONS_PER_DISCOVERY_MAX.get(tick_mark, 0.0)),
			"Persistent explorer stagnation should stay below the composite-derived ceiling at tick %d." % tick_mark
		)


func _run_reasonableness_probe(tick_count: int, snapshot_ticks: Array = []) -> Dictionary:
	var snapshot_targets: Array = snapshot_ticks.duplicate()
	snapshot_targets.sort()
	var window_metrics: Dictionary = {}
	var processed_event_count: int = GameState.chronicle_events.size()
	var persistent_explorer_ids: Dictionary = _persistent_explorer_ids()
	var persistent_explorer_actions: Dictionary = {}
	var observed_ages: Array = []
	var max_agent_count: int = GameState.agents.size()
	var max_runtime_contract_occurrences: int = GameState.runtime_contract_occurrences.size()
	var trade_count: int = 0
	var contract_activity_count: int = 0
	var spawn_count: int = 0
	var sample_security_diversity: int = 0
	var sample_economy_profile_diversity: int = 0

	_observe_age(observed_ages)

	for tick_index in range(tick_count):
		engine.process_tick()
		_observe_age(observed_ages)
		max_agent_count = max(max_agent_count, GameState.agents.size())
		max_runtime_contract_occurrences = max(
			max_runtime_contract_occurrences,
			GameState.runtime_contract_occurrences.size()
		)

		for event_index in range(processed_event_count, GameState.chronicle_events.size()):
			var event: Dictionary = Dictionary(GameState.chronicle_events[event_index])
			var action: String = str(event.get("action", ""))
			var actor_id: String = str(event.get("actor_id", ""))
			if action == "agent_trade":
				trade_count += 1
			elif action in ["contract_claimed", "contract_loaded", "contract_completed"]:
				contract_activity_count += 1
			elif action == "spawn":
				spawn_count += 1

			if persistent_explorer_ids.has(actor_id):
				persistent_explorer_actions[action] = int(persistent_explorer_actions.get(action, 0)) + 1

		processed_event_count = GameState.chronicle_events.size()

		if ((tick_index + 1) % SAMPLE_INTERVAL) == 0 or tick_index == tick_count - 1:
			var diversity: Dictionary = _sector_diversity_snapshot()
			sample_security_diversity = max(
				sample_security_diversity,
				int(diversity.get("security_diversity", 0))
			)
			sample_economy_profile_diversity = max(
				sample_economy_profile_diversity,
				int(diversity.get("economy_profile_diversity", 0))
			)

		var current_tick: int = tick_index + 1
		if current_tick in snapshot_targets:
			window_metrics[current_tick] = {
				"trade_count": trade_count,
				"contract_activity_count": contract_activity_count,
				"topology": _topology_snapshot(),
				"persistent_explorer_mix": _persistent_explorer_mix_snapshot(persistent_explorer_actions),
			}

	var final_diversity: Dictionary = _sector_diversity_snapshot()
	return {
		"observed_ages": observed_ages,
		"max_agent_count": max_agent_count,
		"max_runtime_contract_occurrences": max_runtime_contract_occurrences,
		"trade_count": trade_count,
		"contract_activity_count": contract_activity_count,
		"spawn_count": spawn_count,
		"sample_security_diversity": sample_security_diversity,
		"sample_economy_profile_diversity": sample_economy_profile_diversity,
		"final_security_diversity": int(final_diversity.get("security_diversity", 0)),
		"final_economy_profile_diversity": int(final_diversity.get("economy_profile_diversity", 0)),
		"persistent_explorer_ids": persistent_explorer_ids.keys(),
		"window_metrics": window_metrics,
	}


func _observe_age(observed_ages: Array) -> void:
	var current_age: String = str(GameState.world_age)
	if current_age == "":
		return
	if not (current_age in observed_ages):
		observed_ages.append(current_age)


func _sector_diversity_snapshot() -> Dictionary:
	var security_states: Dictionary = {}
	var economy_profiles: Dictionary = {}

	for sector_id in GameState.sector_tags:
		var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
		var security_tag: String = _first_matching_tag(tags, ["SECURE", "CONTESTED", "LAWLESS"])
		if security_tag != "":
			security_states[security_tag] = true
		var economy_profile: String = _economy_profile_key(tags)
		if economy_profile != "":
			economy_profiles[economy_profile] = true

	return {
		"security_diversity": security_states.size(),
		"economy_profile_diversity": economy_profiles.size(),
	}


func _topology_snapshot() -> Dictionary:
	var degree_values: Array = []
	var bottlenecks: int = 0
	var degree_1: int = 0
	var degree_2: int = 0
	var degree_3: int = 0
	var degree_4: int = 0

	for sector_id in GameState.sector_tags:
		var degree: int = Array(GameState.world_topology.get(sector_id, {}).get("connections", [])).size()
		degree_values.append(degree)
		if degree <= 2:
			bottlenecks += 1
		if degree == 1:
			degree_1 += 1
		elif degree == 2:
			degree_2 += 1
		elif degree == 3:
			degree_3 += 1
		elif degree == 4:
			degree_4 += 1

	var total_sectors: int = GameState.sector_tags.size()
	var avg_degree: float = 0.0
	var max_degree: int = 0
	if not degree_values.empty():
		avg_degree = _array_sum_ints(degree_values) / float(degree_values.size())
		max_degree = _array_max_ints(degree_values)

	return {
		"total_sectors": total_sectors,
		"discovered_sectors": GameState.discovery_log.size(),
		"max_degree": max_degree,
		"avg_degree": avg_degree,
		"bottlenecks": bottlenecks,
		"bottleneck_ratio": float(bottlenecks) / float(max(1, total_sectors)),
		"degree_1": degree_1,
		"degree_2": degree_2,
		"degree_3": degree_3,
		"degree_4": degree_4,
	}


func _persistent_explorer_ids() -> Dictionary:
	var persistent_explorer_ids: Dictionary = {}
	for agent_id in GameState.agents:
		var agent: Dictionary = Dictionary(GameState.agents.get(agent_id, {}))
		if not bool(agent.get("is_persistent", false)):
			continue
		if str(agent.get("agent_role", "")) != "explorer":
			continue
		persistent_explorer_ids[agent_id] = true
	return persistent_explorer_ids


func _persistent_explorer_mix_snapshot(action_totals: Dictionary) -> Dictionary:
	var move_count: int = int(action_totals.get("move", 0))
	var expedition_failed_count: int = int(action_totals.get("expedition_failed", 0))
	var discovery_count: int = int(action_totals.get("sector_discovered", 0))
	var total_actions: int = 0
	for action_name in action_totals:
		total_actions += int(action_totals.get(action_name, 0))
	var stagnant_actions: int = move_count + expedition_failed_count
	return {
		"move": move_count,
		"expedition_failed": expedition_failed_count,
		"sector_discovered": discovery_count,
		"stagnant_actions": stagnant_actions,
		"total_actions": total_actions,
		"stagnation_ratio": float(stagnant_actions) / float(max(1, total_actions)),
		"stagnant_actions_per_discovery": float(stagnant_actions) / float(max(1, discovery_count)),
	}


func _array_sum_ints(values: Array) -> int:
	var total: int = 0
	for value in values:
		total += int(value)
	return total


func _array_max_ints(values: Array) -> int:
	var best_value: int = 0
	for value in values:
		best_value = max(best_value, int(value))
	return best_value


func _economy_profile_key(tags: Array) -> String:
	var parts: Array = []
	for prefix in ["RAW_", "MANUFACTURED_", "CURRENCY_"]:
		for tag in tags:
			var tag_string: String = str(tag)
			if tag_string.begins_with(prefix):
				parts.append(tag_string)
				break
	return PoolStringArray(parts).join("|")


func _first_matching_tag(tags: Array, candidates: Array) -> String:
	for candidate in candidates:
		if candidate in tags:
			return str(candidate)
	return ""


func _reinitialize_engine(seed_string: String) -> void:
	_clear_state()
	_seed_template_database()
	if engine == null:
		var Script = load("res://src/core/simulation/simulation_engine.gd")
		engine = Script.new()
		add_child_autofree(engine)
	engine.initialize_simulation(seed_string)


func _clear_state() -> void:
	GameState.world_topology.clear()
	GameState.world_hazards.clear()
	GameState.sector_tags.clear()
	GameState.grid_dominion.clear()
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.agent_tags.clear()
	GameState.colony_levels.clear()
	GameState.colony_upgrade_progress.clear()
	GameState.colony_downgrade_progress.clear()
	GameState.security_upgrade_progress.clear()
	GameState.security_downgrade_progress.clear()
	GameState.security_change_threshold.clear()
	GameState.economy_upgrade_progress.clear()
	GameState.economy_downgrade_progress.clear()
	GameState.economy_change_threshold.clear()
	GameState.contract_generation_pressure.clear()
	GameState.contract_generation_threshold.clear()
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()
	GameState.hostile_infestation_progress.clear()
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []
	GameState.world_tags = []
	GameState.mortal_agent_counter = 0
	GameState.mortal_agent_deaths = []
	GameState.discovered_sector_count = 0
	GameState.discovery_log = []
	GameState.sector_names.clear()
	GameState.catastrophe_log = []
	GameState.sector_disabled_until.clear()
	GameState.world_seed = ""
	GameState.world_age = ""
	GameState.world_age_timer = 0
	GameState.world_age_cycle_count = 0
	GameState.sim_tick_count = 0
	GameState.sub_tick_accumulator = 0
	TemplateDatabase.actions.clear()
	TemplateDatabase.agents.clear()
	TemplateDatabase.characters.clear()
	TemplateDatabase.assets_ships.clear()
	TemplateDatabase.assets_modules.clear()
	TemplateDatabase.assets_commodities.clear()
	TemplateDatabase.locations.clear()
	TemplateDatabase.contracts.clear()
	TemplateDatabase.utility_tools.clear()
	TemplateDatabase.factions.clear()
	TemplateDatabase.contacts.clear()


func _seed_template_database() -> void:
	var TemplateIndexer = load("res://src/scenes/game_world/world_manager/template_indexer.gd")
	var indexer = TemplateIndexer.new()
	indexer.index_all_templates()
	indexer.free()