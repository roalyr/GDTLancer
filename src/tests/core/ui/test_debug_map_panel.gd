##
## PROJECT: GDTLancer
## MODULE: test_debug_map_panel.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TACTICAL_TODO.md §TASK_1
## LOG_REF: 2026-05-14 01:14:26
##

extends "res://addons/gut/test.gd"

var _panel_scene = preload("res://src/core/ui/debug_map_panel/debug_map_panel.tscn")
var _panel_instance = null

const LOCATION_TRES_PATHS = [
	"res://database/registry/locations/sector_system_elace.tres",
	"res://database/registry/locations/sector_system_cob.tres",
	"res://database/registry/locations/sector_gamma.tres",
	"res://database/registry/locations/sector_system_lywin.tres",
	"res://database/registry/locations/sector_epsilon.tres",
]


func before_each():
	get_tree().paused = false
	GameState.reset_state()
	_seed_template_database()
	_seed_topology()
	GameState.current_sector_id = "sector_system_elace"
	_panel_instance = _panel_scene.instance()
	add_child_autofree(_panel_instance)


func after_each():
	if is_instance_valid(_panel_instance):
		_close_panel_if_open()
		_panel_instance = null
	get_tree().paused = false
	GameState.reset_state()


func _seed_template_database():
	TemplateDatabase.locations.clear()
	for path in LOCATION_TRES_PATHS:
		var res = load(path)
		if res:
			TemplateDatabase.locations[res.template_id] = res


func _seed_topology():
	GameState.world_topology["sector_system_elace"] = {
		"connections": ["sector_system_cob", "sector_gamma"],
		"station_ids": ["sector_system_elace"],
		"sector_type": "station",
	}
	GameState.world_topology["sector_system_cob"] = {
		"connections": ["sector_system_elace", "sector_system_lywin"],
		"station_ids": ["sector_system_cob"],
		"sector_type": "station",
	}
	GameState.world_topology["sector_gamma"] = {
		"connections": ["sector_system_elace", "sector_epsilon"],
		"station_ids": ["sector_gamma"],
		"sector_type": "station",
	}
	GameState.world_topology["sector_system_lywin"] = {
		"connections": ["sector_system_cob", "sector_epsilon"],
		"station_ids": ["sector_system_lywin"],
		"sector_type": "station",
	}
	GameState.world_topology["sector_epsilon"] = {
		"connections": ["sector_gamma", "sector_system_lywin"],
		"station_ids": ["sector_epsilon"],
		"sector_type": "station",
	}


func _show_panel():
	if not _panel_instance._is_visible:
		_panel_instance._toggle_panel()


func _close_panel_if_open():
	if is_instance_valid(_panel_instance) and _panel_instance._is_visible:
		_panel_instance._toggle_panel()


func _get_map_point() -> Vector2:
	var rect = _panel_instance._viewport_container.get_global_rect()
	return rect.position + (rect.size * 0.5)


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
	var current_marker = map_content.get_node_or_null("Sector_sector_system_elace")
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


func test_mouse_wheel_zoom_changes_zoom_distance():
	_show_panel()
	yield(get_tree(), "idle_frame")
	var initial_distance = _panel_instance._zoom_distance
	var event = InputEventMouseButton.new()
	event.button_index = BUTTON_WHEEL_UP
	event.pressed = true
	event.position = _get_map_point()
	_panel_instance._input(event)
	assert_true(
		_panel_instance._zoom_distance < initial_distance,
		"Mouse wheel up should zoom in by reducing orbit distance"
	)


func test_mouse_drag_rotates_camera_angles():
	_show_panel()
	yield(get_tree(), "idle_frame")
	var initial_yaw = _panel_instance._orbit_yaw
	var initial_pitch = _panel_instance._orbit_pitch
	var map_point = _get_map_point()

	var press = InputEventMouseButton.new()
	press.button_index = BUTTON_LEFT
	press.pressed = true
	press.position = map_point
	_panel_instance._input(press)

	var drag = InputEventMouseMotion.new()
	drag.position = map_point
	drag.relative = Vector2(24, -18)
	_panel_instance._input(drag)

	var release = InputEventMouseButton.new()
	release.button_index = BUTTON_LEFT
	release.pressed = false
	release.position = map_point
	_panel_instance._input(release)

	assert_true(
		_panel_instance._orbit_yaw != initial_yaw or _panel_instance._orbit_pitch != initial_pitch,
		"Mouse drag should change orbit yaw or pitch"
	)
	assert_false(_panel_instance._is_drag_orbiting, "Mouse release should stop drag orbit state")


func test_populate_creates_reference_axes():
	_panel_instance._populate_map()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var axes = map_content.get_node_or_null("ReferenceAxes")
	assert_not_null(axes, "Reference axes geometry should exist")
	assert_true(axes is ImmediateGeometry, "Reference axes should be drawn with ImmediateGeometry")


func test_axes_toggle_hides_reference_axes_and_labels():
	_panel_instance._populate_map()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var axes = map_content.get_node_or_null("ReferenceAxes")
	assert_not_null(axes, "Reference axes should exist before toggle")
	_panel_instance._on_toggle_axes()
	assert_false(_panel_instance._show_reference_axes, "Axes toggle should disable reference axes state")
	if axes:
		assert_false(axes.visible, "Reference axes geometry should be hidden after toggle")
	assert_eq(_panel_instance._btn_axes.text, "Axes Off")


func test_coordinate_toggle_updates_label_text_format():
	_panel_instance._populate_map()
	var label = _panel_instance._sector_labels["sector_system_elace"]["label"]
	assert_true(label.text.find("[") == -1, "Coordinates should be hidden by default")
	_panel_instance._on_toggle_coords()
	assert_true(_panel_instance._show_sector_coordinates, "Coordinate toggle should enable coordinate state")
	assert_true(label.text.find("\n[") != -1, "Coordinate toggle should place coordinates on a new line")


func test_sector_labels_use_wrapped_large_font_box():
	_panel_instance._populate_map()
	var label = _panel_instance._sector_labels["sector_system_elace"]["label"]
	assert_true(label.autowrap, "Sector labels should wrap long text")
	assert_eq(label.rect_min_size.x, _panel_instance.SECTOR_LABEL_MAX_WIDTH)
	assert_eq(label.rect_min_size.y, _panel_instance.SECTOR_LABEL_BOX_HEIGHT)
	assert_not_null(_panel_instance._sector_label_font, "Sector label font should be created")
	if _panel_instance._sector_label_font:
		assert_eq(_panel_instance._sector_label_font.size, _panel_instance.SECTOR_LABEL_FONT_SIZE)
