# PROJECT: GDTLancer
# MODULE: test_narrative_pipeline.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-MASTER-DESIGN-DIRECTIVE.md §2.2, §7.4; TRUTH_GAME-LOOP-VISION.md §5.2
# LOG_REF: 2026-06-21 16:15:00

extends "res://addons/gut/test.gd"

var NarrativeTemplateClass = load("res://database/definitions/narrative_template.gd")
var InteractionWindowScene = load("res://scenes/ui/menus/interaction_window/InteractionWindow.tscn")

class MockNarrativeSystem:
	extends "res://src/core/systems/narrative_system.gd"
	
	var mock_files: Dictionary = {}
	
	func _safe_load_narrative(path: String) -> Resource:
		if mock_files.has(path):
			return mock_files[path]
		return null

class MockChronicleLayer:
	extends "res://src/core/simulation/chronicle_layer.gd"
	
	var mock_system: MockNarrativeSystem = null
	
	func _init() -> void:
		mock_system = MockNarrativeSystem.new()
		_narrative_system = mock_system

class MockSimulationEngine:
	extends Node
	
	var chronicle = null
	
	func get_chronicle() -> Reference:
		return chronicle

var _chronicle: MockChronicleLayer = null
var _sim_engine: MockSimulationEngine = null
var _original_sim_engine = null

func before_each() -> void:
	_original_sim_engine = GlobalRefs.simulation_engine
	
	# Clean GameState variables
	GameState.reset_state()
	GameState.world_topology["s1"] = {
		"sector_type": "star",
		"connections": []
	}
	GameState.sector_tags["s1"] = ["RAW_ADEQUATE", "LAWLESS"]
	GameState.current_sector_id = "s1"
	
	_chronicle = MockChronicleLayer.new()
	_sim_engine = MockSimulationEngine.new()
	_sim_engine.chronicle = _chronicle
	GlobalRefs.simulation_engine = _sim_engine

func after_each() -> void:
	GlobalRefs.simulation_engine = _original_sim_engine
	if is_instance_valid(_sim_engine):
		_sim_engine.free()
	_chronicle = null
	GameState.reset_state()

func test_exact_path_resolution() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Exact Title"
	t.body_text = "Exact Body"
	
	var expected_path = "res://database/registry/narrative_templates/star/RAW_ADEQUATE/LAWLESS/ambient.tres"
	_chronicle.mock_system.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Exact Title")
	assert_eq(resolved.body_text, "Exact Body")

func test_fallback_to_default_event() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Default Event Title"
	
	var expected_path = "res://database/registry/narrative_templates/star/RAW_ADEQUATE/LAWLESS/default.tres"
	_chronicle.mock_system.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Default Event Title")

func test_fallback_to_default_security() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Default Security Title"
	
	var expected_path = "res://database/registry/narrative_templates/star/RAW_ADEQUATE/default/default.tres"
	_chronicle.mock_system.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Default Security Title")

func test_fallback_to_default_sector() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Default Sector Title"
	
	var expected_path = "res://database/registry/narrative_templates/star/default.tres"
	_chronicle.mock_system.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Default Sector Title")

func test_fallback_to_global_default() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Global Default Title"
	
	var expected_path = "res://database/registry/narrative_templates/default.tres"
	_chronicle.mock_system.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Global Default Title")

func test_complete_missing_returns_hardcoded_fallback() -> void:
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Local Transmission")
	assert_eq(resolved.body_text, "Static interference on the local frequency. The sector is quiet.")

func test_ui_interaction_window_displays_resolved_narrative() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Story Title"
	t.body_text = "Story Body text creole jargon."
	
	_chronicle.mock_system.mock_files["res://database/registry/narrative_templates/default.tres"] = t
	
	var window = InteractionWindowScene.instance()
	add_child_autofree(window)
	yield(get_tree(), "idle_frame")
	
	# Trigger npc populate
	GameState.agents["npc_test"] = {
		"agent_role": "trader"
	}
	window.open_for_target("npc_test", null)
	yield(get_tree(), "idle_frame")
	
	var header = window.get_node("Panel/VBoxContainer/HeaderRow/LabelTargetName")
	var body = window.get_node("Panel/VBoxContainer/TabContainer/Chronicle Log/LabelContextInfo")
	
	assert_not_null(header)
	assert_not_null(body)
	assert_true(header.text.find("Story Title") != -1, "Header should contain story title.")
	assert_eq(body.text, "Story Body text creole jargon.", "Body should display resolved narrative body.")

func test_diverse_narrative_templates_resolution() -> void:
	var t_rescue = NarrativeTemplateClass.new()
	t_rescue.title = "Rescue"
	var t_sabotage = NarrativeTemplateClass.new()
	t_sabotage.title = "Sabotage"
	var t_dispute = NarrativeTemplateClass.new()
	t_dispute.title = "Dispute"
	var t_anomaly = NarrativeTemplateClass.new()
	t_anomaly.title = "Anomaly"
	
	_chronicle.mock_system.mock_files["res://database/registry/narrative_templates/star/default/LAWLESS/distress.tres"] = t_rescue
	_chronicle.mock_system.mock_files["res://database/registry/narrative_templates/planet/MANUFACTURED_ADEQUATE/CONTESTED/sabotage.tres"] = t_sabotage
	_chronicle.mock_system.mock_files["res://database/registry/narrative_templates/star/RAW_RICH/SECURE/dispute.tres"] = t_dispute
	_chronicle.mock_system.mock_files["res://database/registry/narrative_templates/deep_space/default/default/anomaly.tres"] = t_anomaly
	
	# Test Rescue
	GameState.world_topology["s1"]["sector_type"] = "star"
	GameState.sector_tags["s1"] = ["LAWLESS"]
	var resolved_rescue = _chronicle.resolve_narrative_template("s1", "distress")
	assert_not_null(resolved_rescue)
	if resolved_rescue != null:
		assert_eq(resolved_rescue.title, "Rescue")
	
	# Test Sabotage
	GameState.world_topology["s1"]["sector_type"] = "planet"
	GameState.sector_tags["s1"] = ["MANUFACTURED_ADEQUATE", "CONTESTED"]
	var resolved_sabotage = _chronicle.resolve_narrative_template("s1", "sabotage")
	assert_not_null(resolved_sabotage)
	if resolved_sabotage != null:
		assert_eq(resolved_sabotage.title, "Sabotage")
	
	# Test Dispute
	GameState.world_topology["s1"]["sector_type"] = "star"
	GameState.sector_tags["s1"] = ["RAW_RICH", "SECURE"]
	var resolved_dispute = _chronicle.resolve_narrative_template("s1", "dispute")
	assert_not_null(resolved_dispute)
	if resolved_dispute != null:
		assert_eq(resolved_dispute.title, "Dispute")
	
	# Test Anomaly
	GameState.world_topology["s1"]["sector_type"] = "deep_space"
	GameState.sector_tags["s1"] = []
	var resolved_anomaly = _chronicle.resolve_narrative_template("s1", "anomaly")
	assert_not_null(resolved_anomaly)
	if resolved_anomaly != null:
		assert_eq(resolved_anomaly.title, "Anomaly")
