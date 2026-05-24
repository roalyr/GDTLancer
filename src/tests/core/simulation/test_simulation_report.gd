#
# PROJECT: GDTLancer
# MODULE: test_simulation_report.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md TASK_1; TRUTH_SIMULATION-GRAPH.md §5, §6.4
# LOG_REF: 2026-05-24 14:43:54
#

extends GutTest

const PRINT_FULL_REPORTS = false

## Smoke tests for SimulationReport batch runs: 30, 300, 3000 ticks.
## Validates that the report generates correctly and contains expected sections.
## Also dumps full reports to console for LLM/human review.

var engine: Node = null

const TEST_SEED: String = "qualitative-default"


func before_each():
	_clear_state()
	_seed_template_database()
	var Script = load("res://src/core/simulation/simulation_engine.gd")
	engine = Script.new()
	add_child_autofree(engine)
	engine.initialize_simulation(TEST_SEED)


func after_each():
	engine = null
	_clear_state()


# =============================================================================
# === BATCH REPORT TESTS ======================================================
# =============================================================================

func test_batch_30_ticks():
	var report: String = engine.run_batch_and_report(30, 1)
	_validate_report(report, 30)
	if PRINT_FULL_REPORTS:
		print("\n\n===== GODOT CHRONO-30 =====")
		print(report)
		print("===== END GODOT CHRONO-30 =====\n")


func test_sector_focus_report_supports_requested_focus_and_sort_mode():
	var ReportScript = load("res://src/core/simulation/simulation_report.gd")
	var report_generator: Reference = ReportScript.new()
	var report: String = report_generator.run_and_report(engine, 30, 1, {
		"focus_mode": "sector",
		"focus_id": "sector_system_elace",
		"sort_mode": "sector",
		"detail_level": "verbose",
	})

	assert_true(report.find("REPORT MODE: SECTOR") != -1,
		"Focused report should expose the requested sector mode in the header.")
	assert_true(report.find("FOCUS: sector_system_elace") != -1,
		"Focused report should expose the requested sector id in the header.")
	assert_true(report.find("Detailed event log (sector order):") != -1,
		"Focused report should expose a sector-sorted detailed log section.")
	assert_true(report.find("FOCUSED SUMMARY") != -1,
		"Focused report should emit a focused summary instead of the default world summary.")


func test_agent_focus_report_supports_requested_focus_and_sort_mode():
	var agent_ids: Array = GameState.agents.keys()
	agent_ids.sort()
	var focus_agent_id: String = ""
	for agent_id in agent_ids:
		if str(agent_id) != "player":
			focus_agent_id = str(agent_id)
			break
	assert_true(focus_agent_id != "", "A non-player agent should exist for focused reporting.")
	if focus_agent_id == "":
		return

	var ReportScript = load("res://src/core/simulation/simulation_report.gd")
	var report_generator: Reference = ReportScript.new()
	var report: String = report_generator.run_and_report(engine, 10, 1, {
		"focus_mode": "agent",
		"focus_id": focus_agent_id,
		"sort_mode": "agent",
		"detail_level": "standard",
	})

	assert_true(report.find("REPORT MODE: AGENT") != -1,
		"Focused report should expose the requested agent mode in the header.")
	assert_true(report.find("FOCUS: %s" % focus_agent_id) != -1,
		"Focused report should expose the requested agent id in the header.")
	assert_true(report.find("Detailed event log (agent order):") != -1,
		"Focused report should expose an agent-sorted detailed log section.")
	assert_true(report.find("Current agent state:") != -1,
		"Agent-focused reports should include an integral agent-state summary.")


func test_composite_report_collects_requested_windows_with_deterministic_samples():
	var ReportScript = load("res://src/core/simulation/simulation_report.gd")
	var report_generator: Reference = ReportScript.new()
	var report: String = report_generator.run_composite_report(engine, [10, 30], {})

	assert_true(report.find("COMPOSITE RESEARCH CHRONICLE") != -1,
		"Composite reports should expose a dedicated research chronicle header.")
	assert_true(report.find("COMPOSITE WINDOW: 10 ticks") != -1,
		"Composite reports should capture the first requested cumulative window.")
	assert_true(report.find("COMPOSITE WINDOW: 30 ticks") != -1,
		"Composite reports should capture the later requested cumulative window from the same run.")
	assert_true(report.find("SAMPLED SECTORS") != -1,
		"Composite reports should include deterministic sampled sector sections.")
	assert_true(report.find("SAMPLED AGENTS") != -1,
		"Composite reports should include deterministic sampled agent sections.")
	assert_true(report.find("Focus mode: sector") != -1,
		"Composite reports should reuse the existing focused sector summary surface.")
	assert_true(report.find("Focus mode: agent") != -1,
		"Composite reports should reuse the existing focused agent summary surface.")


func test_composite_sampling_helpers_are_deterministic_for_same_state():
	var ReportScript = load("res://src/core/simulation/simulation_report.gd")
	var report_generator: Reference = ReportScript.new()
	var normalized_request: Dictionary = report_generator._normalize_composite_request({})
	var sector_samples_a: Dictionary = report_generator._sample_sector_ids_by_type(30, normalized_request)
	var sector_samples_b: Dictionary = report_generator._sample_sector_ids_by_type(30, normalized_request)
	var sector_compare = compare_deep(sector_samples_a, sector_samples_b)
	assert_true(sector_compare.are_equal(),
		"Sector sampling should be deterministic for the same seed and milestone.\n" + sector_compare.summary)

	var agent_samples_a: Array = report_generator._sample_agent_entries(30, normalized_request)
	var agent_samples_b: Array = report_generator._sample_agent_entries(30, normalized_request)
	var agent_compare = compare_deep(agent_samples_a, agent_samples_b)
	assert_true(agent_compare.are_equal(),
		"Agent sampling should be deterministic for the same seed and milestone.\n" + agent_compare.summary)

# =============================================================================
# === VALIDATION ==============================================================
# =============================================================================

func _validate_report(report: String, tick_count: int) -> void:
	assert_true(report.length() > 100,
		"Report should be substantial (got %d chars)." % report.length())
	assert_true(report.find("CHRONICLE OF THE SECTOR") != -1,
		"Report should start with CHRONICLE header.")
	assert_true(report.find("OVERALL SUMMARY") != -1,
		"Report should contain OVERALL SUMMARY.")
	assert_true(report.find("Epoch 1:") != -1,
		"Report should contain at least Epoch 1.")
	assert_true(report.find("Detailed event log (chronological order):") != -1,
		"Default report should now include a detailed chronological event log section.")
	assert_true(report.find("Simulation ran for %d ticks" % tick_count) != -1,
		"Summary should state correct tick count (%d)." % tick_count)
	assert_true(report.find("Active pilots:") != -1,
		"Summary should list active pilots.")
	assert_true(report.find("Sector connections:") != -1,
		"Summary should show topology.")
	assert_true(report.find("Topology:") != -1,
		"Summary should include topology metrics.")
	assert_true(report.find("Final state of the sector:") != -1,
		"Summary should show final sector state.")
	# Check for meaningful content — at least some commerce or combat
	var has_commerce: bool = report.find("Commerce:") != -1
	var has_combat: bool = report.find("Combat:") != -1
	assert_true(has_commerce or has_combat,
		"Report should show at least some combat or commerce activity.")


# =============================================================================
# === STATE MANAGEMENT ========================================================
# =============================================================================

func _clear_state():
	if GameState.has_method("reset_state"):
		GameState.reset_state()
	else:
		GameState.world_topology.clear()
		GameState.world_hazards.clear()
		GameState.world_tags.clear()
		GameState.world_seed = ""
		GameState.sector_tags.clear()
		GameState.grid_dominion.clear()
		GameState.colony_levels.clear()
		GameState.colony_upgrade_progress.clear()
		GameState.colony_downgrade_progress.clear()
		GameState.colony_level_history.clear()
		GameState.security_upgrade_progress.clear()
		GameState.security_downgrade_progress.clear()
		GameState.security_change_threshold.clear()
		GameState.economy_upgrade_progress.clear()
		GameState.economy_downgrade_progress.clear()
		GameState.economy_change_threshold.clear()
		GameState.hostile_infestation_progress.clear()
		GameState.agents.clear()
		GameState.agent_tags.clear()
		GameState.characters.clear()
		GameState.chronicle_events.clear()
		GameState.chronicle_rumors.clear()
		GameState.catastrophe_log.clear()
		GameState.sector_disabled_until.clear()
		GameState.mortal_agent_counter = 0
		GameState.mortal_agent_deaths.clear()
		GameState.discovered_sector_count = 0
		GameState.discovery_log.clear()
		GameState.sector_names.clear()
		GameState.sim_tick_count = 0
		GameState.sub_tick_accumulator = 0
		GameState.world_age = ""
		GameState.world_age_timer = 0
		GameState.world_age_cycle_count = 0
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


func _seed_template_database():
	var TemplateIndexer = load("res://src/scenes/game_world/world_manager/template_indexer.gd")
	var indexer = TemplateIndexer.new()
	indexer.index_all_templates()
	indexer.free()
