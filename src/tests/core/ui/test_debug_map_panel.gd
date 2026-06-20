# PROJECT: GDTLancer
# MODULE: test_debug_map_panel.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

##
## PROJECT: GDTLancer
## MODULE: test_debug_map_panel.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: GDD-REVISION-LEDGER.md REV_005; universe_topology_architecture.md
## LOG_REF: 2026-06-07 16:45:00
##

extends "res://addons/gut/test.gd"

const LocationTemplateScript = preload("res://database/definitions/location_template.gd")
const MainHUDScript = preload("res://src/core/ui/main_hud/main_hud.gd")

var _panel_scene = preload("res://src/core/ui/debug_map_panel/debug_map_panel.tscn")
var _panel_instance = null

const LOCATION_TRES_PATHS = [
	"res://database/registry/locations/sector_star_elace.tres",
	"res://database/registry/locations/sector_star_cob.tres",
	"res://database/registry/locations/sector_star_lywin.tres",
	"res://database/registry/locations/sector_star_vidr.tres",
	"res://database/registry/locations/sector_star_ebreeta.tres",
]


func before_each():
	get_tree().paused = false
	GameState.reset_state()
	_seed_template_database()
	_seed_topology()
	GameState.current_sector_id = "sector_star_elace"
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
	for sector_id in TemplateDatabase.locations.keys():
		var template = TemplateDatabase.locations[sector_id]
		var connections: Array = []
		for connected_sector_id in template.connections:
			connections.append(connected_sector_id)
		GameState.world_topology[sector_id] = {
			"connections": connections,
			"station_ids": [sector_id],
			"sector_type": template.sector_type,
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


func test_opening_panel_uses_isolated_viewport_world_and_cleans_up_backdrop():
	_show_panel()
	assert_true(
		_panel_instance._viewport.own_world,
		"Debug map viewport should render in its own world so it does not inherit live gameplay starsphere content."
	)
	assert_not_null(
		_panel_instance._map_nebula_holder,
		"Opening the panel should create a dedicated nebula backdrop inside the map viewport."
	)
	var star_elace = _panel_instance._map_nebula_holder.get_node_or_null(
		"Globalnebulas/SectorStars (clipped by near plane which is 10u)/Star Elace Sprite"
	)
	assert_not_null(star_elace, "The dedicated map backdrop should include the sector-star anchors.")
	_close_panel_if_open()
	assert_null(_panel_instance._map_nebula_holder, "Closing the panel should release the dedicated map backdrop.")
	assert_null(_panel_instance._map_world_env, "Closing the panel should release the map world environment.")



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
	var current_marker = map_content.get_node_or_null("Sector_sector_star_elace")
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


func test_readability_toggles_hide_labels_lines_and_icons_and_survive_refresh():
	_show_panel()
	yield(get_tree(), "idle_frame")
	var header = _panel_instance.get_node("Panel/VBoxContainer/HeaderRow")
	assert_not_null(header.get_node_or_null("BtnLabels"), "TASK_1 should add a dedicated labels toggle button to the header row.")
	assert_not_null(header.get_node_or_null("BtnLines"), "TASK_1 should add a dedicated lines toggle button to the header row.")
	assert_not_null(header.get_node_or_null("BtnIcons"), "TASK_1 should add a dedicated icons toggle button to the header row.")

	var label = _panel_instance._sector_labels["sector_star_elace"]["label"]
	var marker = _panel_instance._sector_labels["sector_star_elace"]["marker"]
	var connection_lines = _panel_instance._map_content.get_node_or_null("ConnectionLines")
	assert_true(label.visible, "Sector labels should be visible before the readability toggles are disabled.")
	assert_true(marker.visible, "Sector icons should be visible before the readability toggles are disabled.")
	assert_true(connection_lines.visible, "Connection lines should be visible before the readability toggles are disabled.")

	_panel_instance._on_toggle_labels()
	_panel_instance._on_toggle_lines()
	_panel_instance._on_toggle_icons()

	assert_eq(header.get_node("BtnLabels").text, "Labels Off")
	assert_eq(header.get_node("BtnLines").text, "Lines Off")
	assert_eq(header.get_node("BtnIcons").text, "Icons Off")
	assert_false(label.visible, "Disabling labels should hide existing sector labels immediately.")
	assert_false(marker.visible, "Disabling icons should hide existing sector markers immediately.")
	assert_false(connection_lines.visible, "Disabling lines should hide existing route geometry immediately.")

	_panel_instance._on_sim_tick_completed(1)
	var refreshed_label = _panel_instance._sector_labels["sector_star_elace"]["label"]
	var refreshed_marker = _panel_instance._sector_labels["sector_star_elace"]["marker"]
	var refreshed_connection_lines = _panel_instance._map_content.get_node_or_null("ConnectionLines")
	assert_false(refreshed_label.visible, "Readability label state should survive sim-tick-driven map repopulation.")
	assert_false(refreshed_marker.visible, "Readability icon state should survive sim-tick-driven map repopulation.")
	assert_false(refreshed_connection_lines.visible, "Readability line state should survive sim-tick-driven map repopulation.")


func test_contract_count_toggle_shows_source_side_board_counts_in_separate_colored_labels():
	_seed_contract_occurrences()
	_show_panel()
	yield(get_tree(), "idle_frame")

	var header = _panel_instance.get_node("Panel/VBoxContainer/HeaderRow")
	var contract_button: Button = header.get_node_or_null("BtnContractCounts")
	assert_not_null(contract_button, "Debug map should expose a dedicated contract-count toggle button in the header row.")
	assert_eq(contract_button.text, "Contracts On")

	var sector_label_data: Dictionary = _panel_instance._sector_labels["sector_star_elace"]
	var name_label: Label = sector_label_data["label"]
	var contract_label: Label = sector_label_data["contract_label"]
	assert_true(contract_label != name_label,
		"Contract counts should render in a separate label node instead of being folded into the sector name label.")
	assert_true(contract_label.visible,
		"Contract count labels should be visible by default while the contract-count toggle is enabled.")
	assert_true(contract_label.text.find("3") != -1,
		"Contract count labels should show all source-side player-displayable runtime contracts the station board can surface, including already-claimed rows.")
	assert_ne(contract_label.get("custom_colors/font_color"), name_label.get("custom_colors/font_color"),
		"Contract count labels should use a distinct color from the sector name labels.")

	_panel_instance._on_toggle_contract_counts()
	assert_eq(contract_button.text, "Contracts Off")
	assert_false(contract_label.visible,
		"Turning contract counts off should hide the separate contract-count labels immediately.")

	_panel_instance._on_sim_tick_completed(1)
	var refreshed_contract_label: Label = _panel_instance._sector_labels["sector_star_elace"]["contract_label"]
	assert_false(refreshed_contract_label.visible,
		"Contract count visibility should survive sim-tick-driven map repopulation.")


func test_task2_header_buttons_adjust_fov_with_clamping():
	_show_panel()
	yield(get_tree(), "idle_frame")
	var header = _panel_instance.get_node("Panel/VBoxContainer/HeaderRow")
	assert_not_null(header.get_node_or_null("BtnFovIn"), "TASK_2 should add a dedicated FoV+ button to the header row.")
	assert_not_null(header.get_node_or_null("BtnFovOut"), "TASK_2 should add a dedicated FoV- button to the header row.")

	var initial_fov = _panel_instance._camera.fov
	_panel_instance._on_fov_in()
	assert_true(
		_panel_instance._camera.fov < initial_fov,
		"FoV+ controls should narrow the map camera field of view for a tighter framing."
	)
	for _step in range(20):
		_panel_instance._on_fov_in()
	assert_eq(
		_panel_instance._camera.fov,
		_panel_instance.MIN_MAP_CAMERA_FOV,
		"FoV+ controls should clamp at the contracted minimum field of view."
	)
	for _step in range(40):
		_panel_instance._on_fov_out()
	assert_eq(
		_panel_instance._camera.fov,
		_panel_instance.MAX_MAP_CAMERA_FOV,
		"FoV- controls should clamp at the contracted maximum field of view."
	)


func test_task2_aa_button_cycles_disabled_2x_and_4x():
	_show_panel()
	yield(get_tree(), "idle_frame")
	var header = _panel_instance.get_node("Panel/VBoxContainer/HeaderRow")
	var aa_button = header.get_node_or_null("BtnAA")
	assert_not_null(aa_button, "TASK_2 should add a dedicated AA cycle button to the header row.")
	assert_eq(aa_button.text, "AA Off")
	assert_eq(_panel_instance._viewport.msaa, Viewport.MSAA_DISABLED)

	_panel_instance._on_cycle_aa()
	assert_eq(_panel_instance._viewport.msaa, Viewport.MSAA_2X)
	assert_eq(aa_button.text, "AA 2x")

	_panel_instance._on_cycle_aa()
	assert_eq(_panel_instance._viewport.msaa, Viewport.MSAA_4X)
	assert_eq(aa_button.text, "AA 4x")

	_panel_instance._on_cycle_aa()
	assert_eq(_panel_instance._viewport.msaa, Viewport.MSAA_DISABLED)
	assert_eq(aa_button.text, "AA Off")


func test_map_label_fade_curve_uses_debug_map_normalized_distance_power_with_main_hud_edge_alpha():
	var edge_alpha: float = MainHUDScript.PROJECTED_TARGET_EDGE_ALPHA
	var normalized_distance_pow: float = _panel_instance.MAP_LABEL_NORMALIZED_DISTANCE_POW
	assert_almost_eq(
		_panel_instance._compute_map_label_distance_fade_alpha(0.0),
		lerp(1.0, edge_alpha, pow(0.0, normalized_distance_pow)),
		0.0001,
		"Map labels should stay fully opaque at the viewport center."
	)
	assert_almost_eq(
		_panel_instance._compute_map_label_distance_fade_alpha(0.5),
		lerp(1.0, edge_alpha, pow(0.5, normalized_distance_pow)),
		0.0001,
		"Map labels should use the dedicated debug-map normalized-distance power instead of reusing MainHUD's edge-distance exponent."
	)
	assert_almost_eq(
		_panel_instance._compute_map_label_distance_fade_alpha(1.0),
		lerp(1.0, edge_alpha, pow(1.0, normalized_distance_pow)),
		0.0001,
		"Map labels should still clamp to the same MainHUD-derived edge alpha at the fade limit."
	)


func test_map_label_camera_distance_fade_starts_around_1e5_and_reduces_far_labels():
	assert_almost_eq(
		_panel_instance._compute_map_label_camera_distance_fade_alpha(50000.0),
		1.0,
		0.0001,
		"Map labels should stay fully opaque before the configured camera-distance fade start."
	)
	assert_almost_eq(
		_panel_instance._compute_map_label_camera_distance_fade_alpha(100000.0),
		1.0,
		0.0001,
		"Map labels should begin fading at roughly 1e5 units, not before it."
	)
	assert_true(
		_panel_instance._compute_map_label_camera_distance_fade_alpha(500000.0) < 1.0,
		"Labels farther than the configured 1e5-unit threshold should become fainter with camera distance."
	)
	assert_almost_eq(
		_panel_instance._compute_map_label_camera_distance_fade_alpha(1100000.0),
		MainHUDScript.PROJECTED_TARGET_EDGE_ALPHA,
		0.0001,
		"Very distant labels should clamp to the same minimum alpha used by the existing screen-position fade."
	)


func test_map_label_projection_multiplies_screen_fade_with_camera_distance_fade():
	_show_panel()
	yield(get_tree(), "idle_frame")
	var label = _panel_instance._sector_labels["sector_star_elace"]["label"]
	var projected_screen_pos = _panel_instance._camera.unproject_position(Vector3.ZERO)
	var screen_fade_alpha = _panel_instance._get_map_label_distance_fade_alpha(projected_screen_pos, Rect2(Vector2.ZERO, _panel_instance._viewport.size))
	var camera_fade_alpha = _panel_instance._get_map_label_camera_distance_fade_alpha(Vector3.ZERO)
	_panel_instance._update_projected_label(label, Vector3.ZERO, Vector2.ZERO, _panel_instance._viewport.size, 50.0, camera_fade_alpha)
	assert_almost_eq(
		label.modulate.a,
		screen_fade_alpha * camera_fade_alpha,
		0.0001,
		"Projected map labels should multiply the existing screen-position fade by the new camera-distance fade."
	)


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
	var label = _panel_instance._sector_labels["sector_star_elace"]["label"]
	assert_true(label.text.find("[") == -1, "Coordinates should be hidden by default")
	_panel_instance._on_toggle_coords()
	assert_true(_panel_instance._show_sector_coordinates, "Coordinate toggle should enable coordinate state")
	assert_true(label.text.find("\n[") != -1, "Coordinate toggle should place coordinates on a new line")


func test_sector_labels_use_wrapped_large_font_box():
	_panel_instance._populate_map()
	var label = _panel_instance._sector_labels["sector_star_elace"]["label"]
	assert_true(label.autowrap, "Sector labels should wrap long text")
	assert_eq(label.rect_min_size.x, _panel_instance.SECTOR_LABEL_MAX_WIDTH)
	assert_eq(label.rect_min_size.y, _panel_instance.SECTOR_LABEL_BOX_HEIGHT)
	assert_not_null(_panel_instance._sector_label_font, "Sector label font should be created")
	if _panel_instance._sector_label_font:
		assert_eq(_panel_instance._sector_label_font.size, _panel_instance.SECTOR_LABEL_FONT_SIZE)


func test_discovered_sector_marker_uses_distinct_color_and_label_prefix():
	_seed_discovered_sector()
	_panel_instance._populate_map()
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	var marker = map_content.get_node_or_null("Sector_discovered_1")
	assert_not_null(marker, "Discovered sectors should create a map marker once their runtime template is registered.")
	var material = marker.material_override as SpatialMaterial
	assert_eq(
		material.albedo_color,
		_panel_instance._get_sector_marker_color("discovered_1", TemplateDatabase.locations["discovered_1"]),
		"Discovered markers should use their discovery-specific color instead of the authored-sector cyan."
	)
	var label = _panel_instance._sector_labels["discovered_1"]["label"]
	assert_true(label.text.find("DISC ") != -1, "Discovered sector labels should carry an explicit discovery prefix.")


func test_sim_tick_refresh_adds_discovered_sector_marker_when_panel_visible():
	_show_panel()
	yield(get_tree(), "idle_frame")
	_seed_discovered_sector()
	_panel_instance._on_sim_tick_completed(1)
	var map_content = _panel_instance.get_node("Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent")
	assert_not_null(
		map_content.get_node_or_null("Sector_discovered_1"),
		"Visible debug map panels should repopulate and show newly discovered runtime sectors on sim-tick refresh."
	)
	assert_ne(
		_panel_instance._get_connection_line_color("sector_star_elace", "discovered_1"),
		_panel_instance._get_connection_line_color("sector_star_elace", "sector_star_cob"),
		"Discovered routes should use a distinct line color from authored handcrafted links."
	)


func _seed_discovered_sector():
	var discovered_template = LocationTemplateScript.new()
	discovered_template.template_id = "discovered_1"
	discovered_template.location_name = "Amber Gate"
	discovered_template.global_position = Vector3(48000, 4000, 0)
	discovered_template.is_procedural = true
	discovered_template.procedural_type = "asteroid_field"
	discovered_template.procedural_hints = {
		"low_visibility": true,
		"discovered_from": "sector_star_elace",
	}
	TemplateDatabase.locations["discovered_1"] = discovered_template
	GameState.world_topology["discovered_1"] = {
		"connections": ["sector_star_elace"],
		"station_ids": ["discovered_1"],
		"sector_type": "deep_space",
	}
	GameState.world_topology["sector_star_elace"]["connections"] = ["sector_star_cob", "sector_star_lywin", "discovered_1"]
	GameState.sector_names["discovered_1"] = "Amber Gate"


func _seed_contract_occurrences() -> void:
	GameState.runtime_contract_occurrences = {
		"runtime_contract:sector_star_elace:RAW_1": {
			"occurrence_id": "runtime_contract:sector_star_elace:RAW_1",
			"source_sector_id": "sector_star_elace",
			"status": "open",
			"claimant_agent_id": "",
			"player_displayable": true,
		},
		"runtime_contract:sector_star_elace:RAW_2": {
			"occurrence_id": "runtime_contract:sector_star_elace:RAW_2",
			"source_sector_id": "sector_star_elace",
			"status": "open",
			"claimant_agent_id": "",
			"player_displayable": true,
		},
		"runtime_contract:sector_star_elace:RAW_claimed": {
			"occurrence_id": "runtime_contract:sector_star_elace:RAW_claimed",
			"source_sector_id": "sector_star_elace",
			"status": "in_transit",
			"claimant_agent_id": "hauler_1",
			"player_displayable": true,
		},
		"runtime_contract:sector_star_cob:CURRENCY": {
			"occurrence_id": "runtime_contract:sector_star_cob:CURRENCY",
			"source_sector_id": "sector_star_cob",
			"status": "open",
			"claimant_agent_id": "",
			"player_displayable": true,
		},
		"runtime_contract:sector_star_vidr:HIDDEN": {
			"occurrence_id": "runtime_contract:sector_star_vidr:HIDDEN",
			"source_sector_id": "sector_star_vidr",
			"status": "open",
			"claimant_agent_id": "",
			"player_displayable": false,
		},
	}
	GameState.runtime_contract_occurrences_by_source_sector = {
		"sector_star_elace": [
			"runtime_contract:sector_star_elace:RAW_1",
			"runtime_contract:sector_star_elace:RAW_2",
			"runtime_contract:sector_star_elace:RAW_claimed",
		],
		"sector_star_cob": ["runtime_contract:sector_star_cob:CURRENCY"],
		"sector_star_vidr": ["runtime_contract:sector_star_vidr:HIDDEN"],
	}
