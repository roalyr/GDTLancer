# PROJECT: GDTLancer
# MODULE: test_simulation_raw_logger.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: test_simulation_raw_logger.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6.5; TACTICAL_TODO.md TASK_1
# LOG_REF: 2026-05-28 14:01:46
#

extends GutTest

var logger: Reference = null
var zone_node: Node = null


class FakeEngine:
	extends Reference

	var tick_config: Dictionary = {
		"contract_occurrence_global_cap": 8,
		"contract_occurrence_per_sector_cap": 2,
	}

	func get_config() -> Dictionary:
		return tick_config.duplicate(true)


func before_each() -> void:
	if GameState.has_method("reset_state"):
		GameState.reset_state()
	var Script = load("res://src/core/simulation/simulation_raw_logger.gd")
	logger = Script.new()
	zone_node = Node.new()
	zone_node.name = "ZoneNode"
	add_child_autofree(zone_node)
	_seed_state()


func after_each() -> void:
	logger = null
	zone_node = null
	if GameState.has_method("reset_state"):
		GameState.reset_state()


func test_run_started_record_advertises_schema_contract_and_game_state_fields() -> void:
	var fake_engine = FakeEngine.new()
	var record: Dictionary = logger._build_run_started_record(fake_engine, "seed:0:3", 3, 0, {"requested_by": "test"})
	var expected_fields: Array = logger._game_state_property_names()

	assert_eq(str(record.get("schema_id", "")), "gdtlancer.sim_snapshot.v1",
		"Run-started records should advertise the raw snapshot schema id.")
	assert_eq(str(record.get("record_type", "")), "run_started",
		"Run-started records should advertise their record type explicitly.")
	assert_eq(int(record.get("tick_count_requested", -1)), 3,
		"Run-started records should report the requested tick count.")
	assert_eq(str(record.get("schema_contract", {}).get("game_state_source", "")), "GameState.get_script().get_script_property_list()",
		"Run-started records should document the automatic GameState property source for future parser work.")
	assert_true(expected_fields.has("world_seed"),
		"The auto-captured GameState field list must include known live fields instead of collapsing to an empty set.")
	assert_true(expected_fields.has("sim_tick_count"),
		"The auto-captured GameState field list must include the live tick counter field.")
	var field_compare = compare_deep(expected_fields, Array(record.get("game_state_fields", [])))
	assert_true(field_compare.are_equal(),
		"Run-started records should advertise the full auto-captured GameState field list.\n" + field_compare.summary)


func test_tick_snapshot_record_normalizes_vectors_nodes_and_resources() -> void:
	var fake_engine = FakeEngine.new()
	GameState.sim_tick_count = 9
	var tick_record: Dictionary = logger._build_tick_snapshot_record(fake_engine, "seed:0:3", 1)
	var snapshot: Dictionary = tick_record.get("game_state", {})
	var snapshot_keys: Array = snapshot.keys()
	snapshot_keys.sort()
	var expected_fields: Array = logger._game_state_property_names()
	var key_compare = compare_deep(expected_fields, snapshot_keys)

	assert_true(key_compare.are_equal(),
		"Tick snapshots should capture every script-defined GameState field automatically.\n" + key_compare.summary)
	assert_true(snapshot.has("world_seed"),
		"Tick snapshots must include known GameState fields so empty payload regressions are caught directly.")
	assert_true(snapshot.has("sim_tick_count"),
		"Tick snapshots must include the live tick counter field so raw streams expose tick state directly.")
	assert_eq(str(snapshot.get("player_position", {}).get("__type", "")), "Vector3",
		"Tick snapshots should normalize Vector3 fields into tagged JSON-safe dictionaries.")
	assert_eq(float(snapshot.get("player_position", {}).get("x", -1.0)), 1.0,
		"Vector3 normalization should preserve numeric components.")
	assert_eq(str(snapshot.get("current_zone_instance", {}).get("__type", "")), "Node",
		"Tick snapshots should normalize Node references into tagged metadata dictionaries.")
	assert_eq(str(snapshot.get("locations", {}).get("debug_location", {}).get("__type", "")), "Resource",
		"Tick snapshots should normalize Resource values inside GameState dictionaries.")
	assert_eq(str(tick_record.get("tick_config", {}).get("contract_occurrence_global_cap", "")), "8",
		"Tick snapshots should include the engine tick config alongside the full GameState snapshot.")


func test_begin_continuous_run_reports_an_active_unbounded_stream() -> void:
	var fake_engine = FakeEngine.new()
	var summary: Dictionary = logger.begin_continuous_run(fake_engine, {"requested_by": "test"})

	assert_eq(str(summary.get("stream_mode", "")), "continuous",
		"Continuous raw logging should advertise the continuous stream mode in its summary metadata.")
	assert_true(bool(summary.get("active", false)),
		"Continuous raw logging should report itself as active after the run-start record is emitted.")
	assert_eq(int(summary.get("record_count", -1)), 1,
		"Continuous raw logging should only emit the run-start record before the first live tick is processed.")
	assert_true(str(summary.get("run_id", "")).find(":continuous") != -1,
		"Continuous raw logging should stamp a deterministic run id that advertises the unbounded mode.")

	var finished_summary: Dictionary = logger.finish_continuous_run(fake_engine)
	assert_false(bool(finished_summary.get("active", true)),
		"Finishing the continuous raw stream should clear the active-run state.")


func _seed_state() -> void:
	GameState.world_seed = "raw_logger_seed"
	GameState.sim_tick_count = 0
	GameState.world_age = "PROSPERITY"
	GameState.player_position = Vector3(1, 2, 3)
	GameState.current_zone_instance = zone_node
	GameState.world_topology = {
		"sector_star_elace": {"connections": ["sector_star_cob"], "station_ids": ["sector_star_elace"], "development_level": "colony"},
	}
	GameState.locations = {
		"debug_location": Resource.new(),
	}