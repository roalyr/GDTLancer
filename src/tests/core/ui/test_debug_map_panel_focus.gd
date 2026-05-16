##
## PROJECT: GDTLancer
## MODULE: test_debug_map_panel_focus.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_PROJECT.md, user request: debug map should keep camera at origin and shift nodes relative to current sector
## LOG_REF: 2026-05-10 20:54:26
##

extends "res://addons/gut/test.gd"

var _panel_scene = preload("res://src/core/ui/debug_map_panel/debug_map_panel.tscn")
var _panel_instance = null


func before_each():
	get_tree().paused = false
	GameState.reset_state()
	TemplateDatabase.locations.clear()
	_seed_template_database()
	GameState.current_sector_id = "sector_system_cob"
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
		"res://database/registry/locations/sector_system_cob.tres",
	]:
		var res = load(path)
		if res:
			TemplateDatabase.locations[res.template_id] = res


func test_opening_panel_keeps_camera_at_origin_and_shifts_sector_markers():
	var elace_template = TemplateDatabase.locations["sector_system_elace"]
	var cob_template = TemplateDatabase.locations["sector_system_cob"]
	assert_not_null(elace_template, "Expected sector_system_elace template to load for map-anchor test.")
	assert_not_null(cob_template, "Expected sector_system_cob template to load for pivot test.")
	_panel_instance._toggle_panel()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var cob_marker = map_content.get_node_or_null("Sector_sector_system_cob")
	var elace_marker = map_content.get_node_or_null("Sector_sector_system_elace")
	assert_not_null(cob_marker, "Expected sector_system_cob marker to exist after opening the panel.")
	assert_not_null(elace_marker, "Expected sector_system_elace marker to exist after opening the panel.")
	assert_eq(
		_panel_instance._pivot,
		Vector3.ZERO,
		"Opening the map should keep the camera pivot at origin so the starsphere frame stays stable."
	)
	assert_eq(
		cob_marker.transform.origin,
		Vector3.ZERO,
		"The current sector marker should be shifted to map origin when the panel opens."
	)
	assert_eq(
		elace_marker.transform.origin,
		Constants.get_reference_origin_offset(cob_template.global_position),
		"Elace should align with the starsphere reference origin in current-sector-local map space."
	)


func test_opening_panel_aligns_backdrop_sector_stars_with_sector_markers():
	var cob_template = TemplateDatabase.locations["sector_system_cob"]
	assert_not_null(cob_template, "Expected sector_system_cob template to load for backdrop-alignment test.")
	_panel_instance._toggle_panel()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var cob_marker = map_content.get_node_or_null("Sector_sector_system_cob")
	var elace_marker = map_content.get_node_or_null("Sector_sector_system_elace")
	assert_not_null(cob_marker, "Expected sector_system_cob marker to exist for backdrop alignment test.")
	assert_not_null(elace_marker, "Expected sector_system_elace marker to exist for backdrop alignment test.")
	var backdrop = _panel_instance._map_nebula_holder
	assert_not_null(backdrop, "Opening the panel should create a dedicated nebula backdrop inside the map viewport.")
	assert_eq(
		backdrop.transform.origin,
		Constants.get_reference_origin_offset(cob_template.global_position),
		"The map nebula backdrop should use the same current-sector-local offset as the reference origin."
	)
	var star_root_path = "Globalnebulas/SectorStars (clipped by near plane which is 10u)"
	var star_cob = backdrop.get_node_or_null("%s/Star Cob" % star_root_path)
	var star_elace = backdrop.get_node_or_null("%s/Star Elace" % star_root_path)
	assert_not_null(star_cob, "Expected Star Cob to exist in the dedicated map backdrop.")
	assert_not_null(star_elace, "Expected Star Elace to exist in the dedicated map backdrop.")
	assert_eq(
		star_cob.global_transform.origin,
		cob_marker.global_transform.origin,
		"Star Cob in the backdrop should land on the same map-space position as the Cob sector marker."
	)
	assert_eq(
		star_elace.global_transform.origin,
		elace_marker.global_transform.origin,
		"Star Elace in the backdrop should land on the same map-space position as the Elace sector marker."
	)