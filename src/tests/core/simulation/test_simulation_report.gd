#
# PROJECT: GDTLancer
# MODULE: test_simulation_report.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md
# LOG_REF: 2026-02-24
#

extends GutTest

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
	add_child(engine)
	engine.initialize_simulation(TEST_SEED)


func after_each():
	if is_instance_valid(engine):
		engine.queue_free()
	engine = null
	_clear_state()


# =============================================================================
# === BATCH REPORT TESTS ======================================================
# =============================================================================

func test_batch_30_ticks():
	var report: String = engine.run_batch_and_report(30, 1)
	_validate_report(report, 30)
	print("\n\n===== GODOT CHRONO-30 =====")
	print(report)
	print("===== END GODOT CHRONO-30 =====\n")


func test_batch_300_ticks():
	var report: String = engine.run_batch_and_report(300, 10)
	_validate_report(report, 300)
	print("\n\n===== GODOT CHRONO-300 =====")
	print(report)
	print("===== END GODOT CHRONO-300 =====\n")


func test_batch_3000_ticks():
	var report: String = engine.run_batch_and_report(3000, 100)
	_validate_report(report, 3000)
	print("\n\n===== GODOT CHRONO-3000 =====")
	print(report)
	print("===== END GODOT CHRONO-3000 =====\n")


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


func _seed_template_database():
	if TemplateDatabase.locations.empty():
		var TemplateIndexer = load("res://src/core/database/template_indexer.gd")
		var indexer = TemplateIndexer.new()
		indexer.index_all()
