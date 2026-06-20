# PROJECT: GDTLancer
# MODULE: test_narrative_pipeline.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-MASTER-DESIGN-DIRECTIVE.md §2.2, §7.4; TRUTH_GAME-LOOP-VISION.md §5.2
# LOG_REF: 2026-06-20 19:57:00

extends "res://addons/gut/test.gd"

var NarrativeTemplateClass = load("res://database/definitions/narrative_template.gd")
var InteractionWindowScene = load("res://scenes/ui/menus/interaction_window/InteractionWindow.tscn")

class MockChronicleLayer:
	extends "res://src/core/simulation/chronicle_layer.gd"
	
	var mock_files: Dictionary = {}
	
	func _safe_load_narrative(path: String) -> Resource:
		if mock_files.has(path):
			return mock_files[path]
		return null

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
	
	var expected_path = "res://database/registry/narratives/star/RAW_ADEQUATE/LAWLESS/ambient.tres"
	_chronicle.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Exact Title")
	assert_eq(resolved.body_text, "Exact Body")

func test_fallback_to_default_event() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Default Event Title"
	
	var expected_path = "res://database/registry/narratives/star/RAW_ADEQUATE/LAWLESS/default.tres"
	_chronicle.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Default Event Title")

func test_fallback_to_default_security() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Default Security Title"
	
	var expected_path = "res://database/registry/narratives/star/RAW_ADEQUATE/default/default.tres"
	_chronicle.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Default Security Title")

func test_fallback_to_default_sector() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Default Sector Title"
	
	var expected_path = "res://database/registry/narratives/star/default.tres"
	_chronicle.mock_files[expected_path] = t
	
	var resolved = _chronicle.resolve_narrative_template("s1", "ambient")
	assert_not_null(resolved)
	assert_eq(resolved.title, "Default Sector Title")

func test_fallback_to_global_default() -> void:
	var t = NarrativeTemplateClass.new()
	t.title = "Global Default Title"
	
	var expected_path = "res://database/registry/narratives/default.tres"
	_chronicle.mock_files[expected_path] = t
	
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
	
	_chronicle.mock_files["res://database/registry/narratives/default.tres"] = t
	
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
	var body = window.get_node("Panel/VBoxContainer/LabelContextInfo")
	
	assert_not_null(header)
	assert_not_null(body)
	assert_true(header.text.find("Story Title") != -1, "Header should contain story title.")
	assert_eq(body.text, "Story Body text creole jargon.", "Body should display resolved narrative body.")
