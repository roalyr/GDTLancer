##
## PROJECT: GDTLancer
## MODULE: test_debug_map_panel_focus.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_CONTENT-CREATION-MANUAL.md §6.3; TRUTH_SIMULATION-GRAPH.md §6.4; TACTICAL_TODO.md TASK_2
## LOG_REF: 2026-05-17 20:19:04
##

extends "res://addons/gut/test.gd"

var _panel_scene = preload("res://src/core/ui/debug_map_panel/debug_map_panel.tscn")
var _panel_instance = null


func before_each():
	get_tree().paused = false
	GameState.reset_state()
	TemplateDatabase.locations.clear()
	_seed_template_database()
	GameState.current_sector_id = "sector_system_lywin_A"
	_panel_instance = _panel_scene.instance()
	add_child_autofree(_panel_instance)


func after_each():
	if is_instance_valid(_panel_instance) and _panel_instance._is_visible:
		_panel_instance._toggle_panel()
	_panel_instance = null
	get_tree().paused = false
	GameState.reset_state()
	TemplateDatabase.locations.clear()


func _seed_template_database():
	for path in [
		"res://database/registry/locations/sector_system_elace.tres",
		"res://database/registry/locations/sector_system_lywin_A.tres",
	]:
		var res = load(path)
		if res:
			TemplateDatabase.locations[res.template_id] = res


func test_opening_panel_keeps_camera_at_origin_and_shifts_sector_markers():
	var elace_template = TemplateDatabase.locations["sector_system_elace"]
	var lywin_a_template = TemplateDatabase.locations["sector_system_lywin_A"]
	assert_not_null(elace_template, "Expected sector_system_elace template to load for map-anchor test.")
	assert_not_null(lywin_a_template, "Expected sector_system_lywin_A template to load for pivot test.")
	_panel_instance._toggle_panel()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var lywin_a_marker = map_content.get_node_or_null("Sector_sector_system_lywin_A")
	var elace_marker = map_content.get_node_or_null("Sector_sector_system_elace")
	assert_not_null(lywin_a_marker, "Expected sector_system_lywin_A marker to exist after opening the panel.")
	assert_not_null(elace_marker, "Expected sector_system_elace marker to exist after opening the panel.")
	assert_eq(
		_panel_instance._pivot,
		Vector3.ZERO,
		"Opening the map should keep the camera pivot at origin so the starsphere frame stays stable."
	)
	assert_eq(
		lywin_a_marker.transform.origin,
		Vector3.ZERO,
		"The current sector marker should be shifted to map origin when the panel opens."
	)
	assert_eq(
		elace_marker.transform.origin,
		Constants.get_reference_origin_offset(lywin_a_template.global_position),
		"Elace should align with the starsphere reference origin in current-sector-local map space."
	)


func test_opening_panel_aligns_backdrop_sector_stars_with_sector_markers():
	var lywin_a_template = TemplateDatabase.locations["sector_system_lywin_A"]
	assert_not_null(lywin_a_template, "Expected sector_system_lywin_A template to load for backdrop-alignment test.")
	_panel_instance._toggle_panel()
	yield(get_tree(), "idle_frame")
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var lywin_a_marker = map_content.get_node_or_null("Sector_sector_system_lywin_A")
	var elace_marker = map_content.get_node_or_null("Sector_sector_system_elace")
	assert_not_null(lywin_a_marker, "Expected sector_system_lywin_A marker to exist for backdrop alignment test.")
	assert_not_null(elace_marker, "Expected sector_system_elace marker to exist for backdrop alignment test.")
	var backdrop = _panel_instance._map_nebula_holder
	assert_not_null(backdrop, "Opening the panel should create a dedicated nebula backdrop inside the map viewport.")
	assert_eq(
		backdrop.transform.origin,
		Constants.get_reference_origin_offset(lywin_a_template.global_position),
		"The map nebula backdrop should use the same current-sector-local offset as the reference origin."
	)
	var star_root_path = "Globalnebulas/SectorStars (clipped by near plane which is 10u)"
	var star_lywin_a = backdrop.get_node_or_null("%s/Star Lywin A Sprite" % star_root_path)
	var star_elace = backdrop.get_node_or_null("%s/Star Elace Sprite" % star_root_path)
	assert_not_null(star_lywin_a, "Expected Star Lywin A Sprite to exist in the dedicated map backdrop.")
	assert_not_null(star_elace, "Expected Star Elace to exist in the dedicated map backdrop.")
	if star_lywin_a and star_elace:
		assert_eq(
			star_lywin_a.global_transform.origin,
			lywin_a_marker.global_transform.origin,
			"Star Lywin A Sprite in the backdrop should land on the same map-space position as the Lywin A sector marker."
		)
		assert_eq(
			star_elace.global_transform.origin,
			elace_marker.global_transform.origin,
			"Star Elace in the backdrop should land on the same map-space position as the Elace sector marker."
		)


func test_right_mouse_drag_pans_camera_without_changing_orbit_angles():
	_panel_instance._toggle_panel()
	yield(get_tree(), "idle_frame")
	var initial_pivot = _panel_instance._pivot
	var initial_yaw = _panel_instance._orbit_yaw
	var initial_pitch = _panel_instance._orbit_pitch
	var viewport_rect = _panel_instance._viewport_container.get_global_rect()
	var map_point = viewport_rect.position + (viewport_rect.size * 0.5)

	var press = InputEventMouseButton.new()
	press.button_index = BUTTON_RIGHT
	press.pressed = true
	press.position = map_point
	_panel_instance._input(press)

	var drag = InputEventMouseMotion.new()
	drag.position = map_point
	drag.relative = Vector2(32, -20)
	_panel_instance._input(drag)

	var release = InputEventMouseButton.new()
	release.button_index = BUTTON_RIGHT
	release.pressed = false
	release.position = map_point
	_panel_instance._input(release)

	assert_ne(
		_panel_instance._pivot,
		initial_pivot,
		"Right mouse drag should pan the map by moving the camera pivot in camera space."
	)
	assert_eq(
		_panel_instance._orbit_yaw,
		initial_yaw,
		"Right mouse drag should not reuse the left-drag orbit yaw path."
	)
	assert_eq(
		_panel_instance._orbit_pitch,
		initial_pitch,
		"Right mouse drag should not reuse the left-drag orbit pitch path."
	)
	assert_false(
		_panel_instance._is_drag_panning,
		"Right mouse release should stop the dedicated drag-pan state."
	)