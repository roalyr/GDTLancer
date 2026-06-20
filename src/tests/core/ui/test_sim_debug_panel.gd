# PROJECT: GDTLancer
# MODULE: test_sim_debug_panel.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

##
## PROJECT: GDTLancer
## MODULE: test_sim_debug_panel.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TACTICAL_TODO.md TASK_1; TRUTH_SIMULATION-GRAPH.md §6.5
## LOG_REF: 2026-05-28 14:01:46
##

extends "res://addons/gut/test.gd"

const SimDebugPanelScene = preload("res://scenes/ui/hud/sim_debug_panel.tscn")

var _panel_instance = null
var _engine_double = null


class FakeSimulationEngine extends Node:
	var request_tick_calls: int = 0
	var last_tick_count: int = -1
	var last_epoch_size: int = -1
	var last_report_request: Dictionary = {}
	var last_composite_tick_counts: Array = []
	var last_composite_request: Dictionary = {}
	var last_raw_stream_request: Dictionary = {}
	var raw_stream_calls: int = 0

	func request_tick() -> void:
		request_tick_calls += 1

	func run_batch_and_report(tick_count: int, epoch_size: int = 1, report_request: Dictionary = {}) -> String:
		last_tick_count = tick_count
		last_epoch_size = epoch_size
		last_report_request = report_request.duplicate(true)
		return "================================================================\nCHRONICLE OF THE SECTOR  (seed: panel-test-seed)\n================================================================\nREPORT MODE: %s  |  FOCUS: %s  |  SORT: %s  |  DETAIL: %s\n\n--- Epoch 1: ticks 1-1 [PROSPERITY] ---\n  A quiet period. Routine patrols continued without incident.\n\nFOCUSED SUMMARY\n  Focus mode: %s  |  focus id: %s\n" % [
			str(report_request.get("focus_mode", "world")).to_upper(),
			str(report_request.get("focus_id", "world")),
			str(report_request.get("sort_mode", "chronological")),
			str(report_request.get("detail_level", "standard")),
			str(report_request.get("focus_mode", "world")),
			str(report_request.get("focus_id", "world")),
		]

	func run_composite_research_report(tick_counts: Array, composite_request: Dictionary = {}) -> String:
		last_composite_tick_counts = tick_counts.duplicate()
		last_composite_request = composite_request.duplicate(true)
		return "================================================================\nCOMPOSITE RESEARCH CHRONICLE  (seed: panel-test-seed)\n================================================================\nWINDOWS: %s\n\n================================================================\nCOMPOSITE WINDOW: %d ticks\n================================================================\nSAMPLED SECTORS\n  (stub)\n\nSAMPLED AGENTS\n  (stub)\n" % [
			PoolStringArray(tick_counts).join(", "),
			int(tick_counts[tick_counts.size() - 1]) if not tick_counts.empty() else 0,
		]

	func start_silent_raw_stream(log_request: Dictionary = {}) -> Dictionary:
		raw_stream_calls += 1
		last_raw_stream_request = log_request.duplicate(true)
		return {
			"schema_id": "gdtlancer.sim_snapshot.v1",
			"run_id": "panel-test-seed:7:continuous",
			"tick_start": GameState.sim_tick_count,
			"tick_end": GameState.sim_tick_count,
			"ticks_processed": 0,
			"record_count": 1,
			"stream_mode": "continuous",
			"active": true,
		}


func before_each() -> void:
	get_tree().paused = false
	_seed_sim_state()
	_engine_double = FakeSimulationEngine.new()
	add_child_autofree(_engine_double)
	GlobalRefs.simulation_engine = _engine_double
	_panel_instance = SimDebugPanelScene.instance()
	add_child_autofree(_panel_instance)


func after_each() -> void:
	get_tree().paused = false
	GlobalRefs.simulation_engine = null
	_panel_instance = null
	_engine_double = null
	TemplateDatabase.locations.clear()
	if GameState.has_method("reset_state"):
		GameState.reset_state()
	else:
		GameState.world_topology.clear()
		GameState.world_hazards.clear()
		GameState.world_tags.clear()
		GameState.sector_tags.clear()
		GameState.grid_dominion.clear()
		GameState.colony_levels.clear()
		GameState.agents.clear()
		GameState.characters.clear()
		GameState.chronicle_events.clear()
		GameState.chronicle_rumors.clear()
		GameState.discovery_log.clear()
		GameState.sector_names.clear()


func test_panel_builds_report_controls_without_leaving_live_snapshot_mode() -> void:
	yield(get_tree(), "idle_frame")

	assert_false(_panel_instance._showing_report,
		"SimDebugPanel should remain in the live snapshot mode by default.")
	assert_not_null(_panel_instance._controls_row,
		"TASK_3 coverage expects the panel to build a dedicated report-controls row.")
	assert_eq(_panel_instance._selected_option_value(_panel_instance._report_mode_option, ""), "focused",
		"Report output mode should default to the focused chronicle flow.")
	assert_eq(_panel_instance._selected_option_value(_panel_instance._focus_mode_option, ""), "world",
		"Focus mode should default to the world-wide chronicle report.")
	assert_eq(_panel_instance._btn_run_silent.text, "Run Raw Simulation",
		"The raw-stream button should advertise the continuous unfiltered logging mode explicitly.")
	assert_true(_panel_instance._focus_id_option.disabled,
		"Entity selection should stay disabled while the focus mode is world-wide.")
	assert_eq(_panel_instance._selected_option_value(_panel_instance._focus_id_option, ""), "world",
		"The world-wide focus should pin the entity selector to the world sentinel value.")


func test_focus_mode_selection_refreshes_sector_and_agent_entities() -> void:
	yield(get_tree(), "idle_frame")

	var sector_focus_index: int = _find_option_index_by_metadata(_panel_instance._focus_mode_option, "sector")
	assert_true(sector_focus_index >= 0, "Sector focus option should exist.")
	_panel_instance._focus_mode_option.select(sector_focus_index)
	_panel_instance._on_focus_mode_selected(sector_focus_index)

	assert_false(_panel_instance._focus_id_option.disabled,
		"Sector focus should enable entity selection.")
	assert_true(_option_button_contains_metadata(_panel_instance._focus_id_option, "sector_star_elace"),
		"Sector focus should list current sector ids as report entities.")
	assert_true(_option_button_contains_text(_panel_instance._focus_id_option, "Elace"),
		"Sector focus labels should be human-readable when sector names are available.")

	var agent_focus_index: int = _find_option_index_by_metadata(_panel_instance._focus_mode_option, "agent")
	assert_true(agent_focus_index >= 0, "Agent focus option should exist.")
	_panel_instance._focus_mode_option.select(agent_focus_index)
	_panel_instance._on_focus_mode_selected(agent_focus_index)

	assert_true(_option_button_contains_metadata(_panel_instance._focus_id_option, "agent_vera"),
		"Agent focus should list the current simulation agents as report entities.")
	assert_true(_option_button_contains_text(_panel_instance._focus_id_option, "Vera"),
		"Agent focus labels should use character names when available.")


func test_run_batch_passes_selected_report_request_and_returns_to_live_state() -> void:
	yield(get_tree(), "idle_frame")
	_panel_instance._toggle()

	var sector_focus_index: int = _find_option_index_by_metadata(_panel_instance._focus_mode_option, "sector")
	_panel_instance._focus_mode_option.select(sector_focus_index)
	_panel_instance._on_focus_mode_selected(sector_focus_index)
	_select_option_by_metadata(_panel_instance._focus_id_option, "sector_star_elace")

	_panel_instance._on_run_batch(300)

	assert_eq(_engine_double.last_tick_count, 300,
		"Run 300 should still request a 300-tick batch from the simulation engine.")
	assert_eq(_engine_double.last_epoch_size, 10,
		"Run 300 should preserve the contracted epoch-size scaling.")
	assert_eq(str(_engine_double.last_report_request.get("focus_mode", "")), "sector",
		"SimDebugPanel should forward the selected focus mode to the batch-report request.")
	assert_eq(str(_engine_double.last_report_request.get("focus_id", "")), "sector_star_elace",
		"SimDebugPanel should forward the selected focus entity to the batch-report request.")
	assert_eq(str(_engine_double.last_report_request.get("sort_mode", "")), "chronological",
		"SimDebugPanel should use chronological sort mode.")
	assert_eq(str(_engine_double.last_report_request.get("detail_level", "")), "standard",
		"SimDebugPanel should use standard detail level.")
	assert_true(_panel_instance._showing_report,
		"Running a batch should switch the panel into report mode.")
	assert_true(_panel_instance._header_label.text.find("sector:") != -1,
		"The report header should reflect the selected scoped-analysis mode.")
	assert_true(_panel_instance._header_label.text.find("sector_star_elace") != -1,
		"The report header should reflect the selected scoped-analysis entity.")

	_panel_instance._on_back_pressed()

	assert_false(_panel_instance._showing_report,
		"Back should restore the live snapshot view instead of leaving the panel in report mode.")
	assert_eq(_panel_instance._header_label.text, "SIM DEBUG  [F3 to close]",
		"Back should restore the standard live-view panel header.")


func test_composite_mode_runs_cumulative_bundle_and_disables_manual_focus_controls() -> void:
	yield(get_tree(), "idle_frame")
	_panel_instance._toggle()

	_select_option_by_metadata(_panel_instance._report_mode_option, "composite")
	_panel_instance._on_report_mode_selected(_panel_instance._report_mode_option.get_selected())

	assert_true(_panel_instance._focus_mode_option.disabled,
		"Composite research mode should disable manual focus selection.")
	assert_true(_panel_instance._focus_id_option.disabled,
		"Composite research mode should disable the manual entity selector.")

	_panel_instance._on_run_batch(300)

	var tick_compare = compare_deep([30, 300], _engine_double.last_composite_tick_counts)
	assert_true(tick_compare.are_equal(),
		"Composite mode should request the cumulative milestone windows up to the selected button.\n" + tick_compare.summary)
	assert_eq(str(_engine_double.last_composite_request.get("sort_mode", "")), "chronological",
		"Composite mode should default to chronological sort mode.")
	assert_eq(str(_engine_double.last_composite_request.get("detail_level", "")), "standard",
		"Composite mode should default to standard detail level.")
	assert_true(bool(_engine_double.last_composite_request.get("include_persistent", false)),
		"Composite mode should include persistent agents in the sampled research request.")
	assert_true(bool(_engine_double.last_composite_request.get("include_mortal", false)),
		"Composite mode should include mortal agents in the sampled research request.")
	assert_true(Array(_engine_double.last_composite_request.get("sector_types", [])).has("star"),
		"Composite mode should sample the currently loaded sector types.")
	assert_true(Array(_engine_double.last_composite_request.get("agent_roles", [])).has("trader"),
		"Composite mode should sample the currently loaded agent roles.")
	assert_true(Array(_engine_double.last_composite_request.get("agent_roles", [])).has("hauler"),
		"Composite mode should include each visible non-player role once.")
	assert_true(_panel_instance._header_label.text.find("COMPOSITE RESEARCH REPORT") != -1,
		"Composite mode should show a dedicated research header in the panel.")
	assert_true(_panel_instance._last_plain_text.find("COMPOSITE RESEARCH CHRONICLE") != -1,
		"Composite mode should cache the bundled research report as the last plain-text output.")


func test_silent_run_starts_continuous_unfiltered_stream_and_keeps_live_snapshot_mode() -> void:
	yield(get_tree(), "idle_frame")
	_panel_instance._toggle()

	var sector_focus_index: int = _find_option_index_by_metadata(_panel_instance._focus_mode_option, "sector")
	_panel_instance._focus_mode_option.select(sector_focus_index)
	_panel_instance._on_focus_mode_selected(sector_focus_index)
	_select_option_by_metadata(_panel_instance._focus_id_option, "sector_star_elace")

	_panel_instance._on_run_silent_pressed()

	assert_eq(_engine_double.raw_stream_calls, 1,
		"Raw simulation should route through the continuous engine stream helper exactly once.")
	assert_eq(str(_engine_double.last_raw_stream_request.get("requested_by", "")), "sim_debug_panel",
		"Raw simulation should identify the Sim Debug Panel as the request source.")
	assert_eq(str(_engine_double.last_raw_stream_request.get("stream_mode", "")), "continuous",
		"Raw simulation should request the continuous stream mode instead of a bounded batch.")
	assert_eq(str(_engine_double.last_raw_stream_request.get("capture_scope", "")), "full_game_state",
		"Raw simulation should request the full unfiltered GameState capture.")
	assert_false(_engine_double.last_raw_stream_request.has("focus_mode"),
		"Raw simulation should not forward scoped-analysis filters into the raw stream request.")
	assert_false(_engine_double.last_raw_stream_request.has("sort_mode"),
		"Raw simulation should not forward report sorting hints into the raw stream request.")
	assert_false(_engine_double.last_raw_stream_request.has("detail_level"),
		"Raw simulation should not forward report detail hints into the raw stream request.")
	assert_false(_panel_instance._showing_report,
		"Silent run must keep the panel in live snapshot mode instead of switching to report mode.")
	assert_eq(_panel_instance._header_label.text, "SIM DEBUG  [F3 to close]",
		"Silent run should keep the standard live-view header instead of replacing it with a report banner.")


func _seed_sim_state() -> void:
	if GameState.has_method("reset_state"):
		GameState.reset_state()
	TemplateDatabase.locations.clear()
	GameState.world_seed = "panel_test_seed"
	GameState.sim_tick_count = 7
	GameState.world_age = "PROSPERITY"
	GameState.world_age_timer = 5
	GameState.world_age_cycle_count = 1
	GameState.world_topology = {
		"sector_star_elace": {"connections": ["sector_star_cob"], "station_ids": ["sector_star_elace"], "development_level": "colony", "sector_type": "star"},
		"sector_star_cob": {"connections": ["sector_star_elace"], "station_ids": ["sector_star_cob"], "development_level": "colony", "sector_type": "star"},
	}
	GameState.world_hazards = {
		"sector_star_elace": {"environment": "MILD"},
		"sector_star_cob": {"environment": "HARSH"},
	}
	GameState.world_tags = ["WORLD_AGE_PROSPERITY"]
	GameState.sector_tags = {
		"sector_star_elace": ["STATION", "SECURE", "MILD", "RAW_POOR"],
		"sector_star_cob": ["STATION", "CONTESTED", "HARSH", "RAW_RICH"],
	}
	GameState.grid_dominion = {
		"sector_star_elace": {"security_tag": "SECURE"},
		"sector_star_cob": {"security_tag": "CONTESTED"},
	}
	GameState.colony_levels = {
		"sector_star_elace": "colony",
		"sector_star_cob": "outpost",
	}
	GameState.sector_names = {
		"sector_star_elace": "Elace",
		"sector_star_cob": "Cob",
	}
	GameState.characters = {
		"character_vera": {"character_name": "Vera"},
		"character_dax": {"character_name": "Dax"},
	}
	GameState.agents = {
		"player": {
			"character_id": "character_vera",
			"agent_role": "idle",
			"current_sector_id": "sector_star_elace",
			"condition_tag": "HEALTHY",
			"wealth_tag": "COMFORTABLE",
			"cargo_tag": "EMPTY",
			"goal_archetype": "idle",
			"is_disabled": false,
			"is_persistent": true,
		},
		"agent_vera": {
			"character_id": "character_vera",
			"agent_role": "trader",
			"current_sector_id": "sector_star_elace",
			"condition_tag": "HEALTHY",
			"wealth_tag": "WEALTHY",
			"cargo_tag": "EMPTY",
			"goal_archetype": "service_contract",
			"is_disabled": false,
			"is_persistent": true,
		},
		"agent_dax": {
			"character_id": "character_dax",
			"agent_role": "hauler",
			"current_sector_id": "sector_star_cob",
			"condition_tag": "DAMAGED",
			"wealth_tag": "BROKE",
			"cargo_tag": "LOADED",
			"goal_archetype": "service_contract",
			"is_disabled": false,
			"is_persistent": true,
		},
	}
	GameState.chronicle_events = []
	GameState.chronicle_rumors = []
	GameState.discovery_log = []


func _find_option_index_by_metadata(button: OptionButton, expected_value: String) -> int:
	for index in range(button.get_item_count()):
		if str(button.get_item_metadata(index)) == expected_value:
			return index
	return -1


func _select_option_by_metadata(button: OptionButton, expected_value: String) -> void:
	var option_index: int = _find_option_index_by_metadata(button, expected_value)
	assert_true(option_index >= 0,
		"OptionButton should contain metadata '%s'." % expected_value)
	if option_index >= 0:
		button.select(option_index)


func _option_button_contains_metadata(button: OptionButton, expected_value: String) -> bool:
	return _find_option_index_by_metadata(button, expected_value) >= 0


func _option_button_contains_text(button: OptionButton, expected_fragment: String) -> bool:
	for index in range(button.get_item_count()):
		if button.get_item_text(index).find(expected_fragment) != -1:
			return true
	return false
