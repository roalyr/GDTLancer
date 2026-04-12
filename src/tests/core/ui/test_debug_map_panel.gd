#
# PROJECT: GDTLancer
# MODULE: test_debug_map_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md §TASK_6 — Debug Map Panel unit tests
# LOG_REF: 2026-04-12
#

extends "res://addons/gut/test.gd"

var _panel_scene = preload("res://src/core/ui/debug_map_panel/debug_map_panel.tscn")
var _panel_instance = null

const LOCATION_TRES_PATHS = [
	"res://database/registry/locations/station_alpha.tres",
	"res://database/registry/locations/station_beta.tres",
	"res://database/registry/locations/station_gamma.tres",
	"res://database/registry/locations/station_delta.tres",
	"res://database/registry/locations/station_epsilon.tres",
]


func before_each():
	GameState.reset_state()
	_seed_template_database()
	_seed_topology()
	GameState.current_sector_id = "station_alpha"
	_panel_instance = _panel_scene.instance()
	add_child(_panel_instance)


func after_each():
	if is_instance_valid(_panel_instance):
		_panel_instance.queue_free()
		_panel_instance = null
	GameState.reset_state()


func _seed_template_database():
	TemplateDatabase.locations.clear()
	for path in LOCATION_TRES_PATHS:
		var res = load(path)
		if res:
			TemplateDatabase.locations[res.template_id] = res


func _seed_topology():
	GameState.world_topology["station_alpha"] = {
		"connections": ["station_beta", "station_delta"],
		"station_ids": ["station_alpha"],
		"sector_type": "station",
	}
	GameState.world_topology["station_beta"] = {
		"connections": ["station_alpha", "station_gamma"],
		"station_ids": ["station_beta"],
		"sector_type": "station",
	}
	GameState.world_topology["station_gamma"] = {
		"connections": ["station_beta", "station_epsilon"],
		"station_ids": ["station_gamma"],
		"sector_type": "station",
	}
	GameState.world_topology["station_delta"] = {
		"connections": ["station_alpha", "station_epsilon"],
		"station_ids": ["station_delta"],
		"sector_type": "station",
	}
	GameState.world_topology["station_epsilon"] = {
		"connections": ["station_gamma", "station_delta"],
		"station_ids": ["station_epsilon"],
		"sector_type": "station",
	}


func test_panel_starts_hidden():
	var panel_node = _panel_instance.get_node("Panel")
	assert_false(panel_node.visible, "Panel should start hidden")


func test_toggle_shows_panel():
	var event = InputEventKey.new()
	event.scancode = KEY_F4
	event.pressed = true
	_panel_instance._input(event)
	var panel_node = _panel_instance.get_node("Panel")
	assert_true(panel_node.visible, "Panel should be visible after F4 toggle")


func test_populate_creates_sector_markers():
	_panel_instance._populate_map()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var sector_count = 0
	for child in map_content.get_children():
		if child.name.begins_with("Sector_"):
			sector_count += 1
	assert_gt(sector_count, 4, "Should have at least 5 sector markers")


func test_populate_creates_connection_lines():
	_panel_instance._populate_map()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var has_ig = false
	for child in map_content.get_children():
		if child is ImmediateGeometry:
			has_ig = true
			break
	assert_true(has_ig, "Should have an ImmediateGeometry child for connection lines")


func test_current_sector_highlighted():
	_panel_instance._populate_map()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var current_marker = map_content.get_node_or_null("Sector_station_alpha")
	assert_not_null(current_marker, "Current sector marker should exist")
	if current_marker:
		var sphere = current_marker.mesh as SphereMesh
		assert_gt(sphere.radius, 2000.0, "Current sector should have larger marker")


func test_camera_initial_position():
	var camera = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapCamera")
	assert_gt(camera.transform.origin.length(), 0.0, "Camera should not be at origin")


func test_label_count_matches_sectors():
	_panel_instance._populate_map()
	var label_overlay = _panel_instance.get_node("Panel/VBoxContainer/MapArea/LabelOverlay")
	var label_count = 0
	for child in label_overlay.get_children():
		if child is Label:
			label_count += 1
	assert_gt(label_count, 4, "Should have at least 5 labels matching sectors")
