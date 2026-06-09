#
# PROJECT: GDTLancer
# MODULE: test_main_hud_projected_targeting.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §4.2, §6.1, §6.3; TACTICAL_TODO.md TASK_4
# LOG_REF: 2026-06-09 20:56:00
#

extends "res://addons/gut/test.gd"

var MainHUDScene = load("res://scenes/ui/hud/main_hud.tscn")
var MainHUDScript = load("res://src/core/ui/main_hud/main_hud.gd")
var ProjectedTargetBracketScene = load("res://scenes/ui/hud/projected_target_bracket.tscn")
var ProjectedTargetBracketScript = load("res://src/core/ui/main_hud/projected_target_bracket.gd")
var LocationTemplateScript = load("res://database/definitions/location_template.gd")
var RouteTargetScript = load("res://src/core/targeting/route_target.gd")
var NavigationSystemScript = load("res://src/core/agents/components/navigation_system.gd")
var DockableStationScript = load("res://src/scenes/game_world/station/dockable_station.gd")
var AgentScript = load("res://src/core/agents/agent.gd")
var PlayerControllerShipScript = load("res://src/modules/piloting/player_controller_ship.gd")
var StateFreeFlightScript = load("res://src/modules/piloting/player_input_states/state_free_flight.gd")


func after_each():
	GlobalRefs.main_hud = null
	GlobalRefs.player_agent_body = null
	GlobalRefs.main_camera = null
	GlobalRefs.current_zone = null
	GameState.player_character_uid = ""
	GameState.reset_state()
	TemplateDatabase.locations.clear()


func test_main_hud_rebuilds_route_overlay_when_sim_tick_adds_current_sector_discovery() -> void:
	GameState.current_sector_id = "sector_star_elace"
	GameState.world_topology = {
		"sector_star_elace": {
			"connections": ["sector_star_cob"],
			"station_ids": ["sector_star_elace"],
			"development_level": "colony",
		},
		"sector_star_cob": {
			"connections": ["sector_star_elace"],
			"station_ids": ["sector_star_cob"],
			"development_level": "colony",
		},
	}
	TemplateDatabase.locations["sector_star_elace"] = _make_location_template(
		"sector_star_elace",
		"Elace System",
		Vector3.ZERO
	)
	TemplateDatabase.locations["sector_star_cob"] = _make_location_template(
		"sector_star_cob",
		"Cob System",
		Vector3(180000, 0, 0)
	)

	var camera = Camera.new()
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")

	assert_true(
		hud._route_target_buttons.has("jump_route:sector_star_elace:sector_star_cob"),
		"Initial route overlays should include the authored connected sector."
	)
	assert_false(
		hud._route_target_buttons.has("jump_route:sector_star_elace:discovered_1"),
		"Discovered routes should not exist before the topology mutation is applied."
	)

	var discovered_template = _make_location_template(
		"discovered_1",
		"Amber Gate",
		Vector3(96000, 12000, 42000)
	)
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
	GameState.world_topology["sector_star_elace"]["connections"] = ["sector_star_cob", "discovered_1"]

	hud._on_sim_tick_completed(1)

	assert_true(
		hud._route_target_buttons.has("jump_route:sector_star_elace:discovered_1"),
		"Sim tick refresh should rebuild jump-route overlays when a new route is added to the current sector."
	)
	assert_eq(hud._route_target_buttons.size(), 2, "Current-sector discoveries should add a second jump-route overlay without requiring sector travel.")
	assert_eq(
		hud._route_target_buttons["jump_route:sector_star_elace:discovered_1"].target_ref.display_name,
		"Amber Gate",
		"Rebuilt jump-route overlays should use the discovered sector's runtime display name."
	)


func test_collect_world_projected_targets_includes_scene_objects_and_npcs_but_excludes_player_and_jump_points():
	var zone = Spatial.new()
	zone.name = "ZoneRoot"
	add_child_autofree(zone)

	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.name = "Station Elace a1"
	zone.add_child(station)

	var star = StaticBody.new()
	star.name = "Star Elace"
	zone.add_child(star)

	var jump_point = StaticBody.new()
	jump_point.name = "JumpPoint"
	zone.add_child(jump_point)
	jump_point.add_to_group("jump_point")

	var player = RigidBody.new()
	player.set_script(AgentScript)
	player.name = "Player"
	player.character_uid = 5
	zone.add_child(player)

	var npc = RigidBody.new()
	npc.set_script(AgentScript)
	npc.name = "NPC Ship"
	npc.character_uid = 1001
	zone.add_child(npc)

	GameState.player_character_uid = "5"
	GlobalRefs.current_zone = zone
	GlobalRefs.player_agent_body = player

	var camera = Camera.new()
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")
	var targets: Array = hud._collect_world_projected_targets()

	assert_has(targets, station, "Dockable stations should get projected HUD targets.")
	assert_has(targets, star, "Static scene objects should get projected HUD targets.")
	assert_has(targets, npc, "NPC agents should get projected HUD targets.")
	assert_false(targets.has(player), "The player agent should not get a self-targeting HUD bracket.")
	assert_false(targets.has(jump_point), "Legacy physical jump points should not get projected HUD brackets.")


func test_navigation_system_accessor_returns_current_command_type() -> void:
	var navigation_system = autofree(NavigationSystemScript.new())
	navigation_system._current_command = {"type": navigation_system.CommandType.APPROACH}

	assert_eq(
		navigation_system.get_current_command_type(),
		navigation_system.CommandType.APPROACH,
		"NavigationSystem should expose the active command type through the HUD-safe accessor."
	)

	navigation_system._current_command = {}
	assert_eq(
		navigation_system.get_current_command_type(),
		navigation_system.CommandType.IDLE,
		"NavigationSystem should fall back to IDLE when no command is active."
	)


func test_player_controller_accessors_report_free_flight_and_navigation_command() -> void:
	var controller = autofree(PlayerControllerShipScript.new())
	controller._current_input_state = autofree(StateFreeFlightScript.new())

	var agent_body = RigidBody.new()
	add_child_autofree(agent_body)
	var navigation_system = NavigationSystemScript.new()
	navigation_system.name = "NavigationSystem"
	navigation_system._current_command = {"type": navigation_system.CommandType.FLEE}
	agent_body.add_child(navigation_system)
	controller.agent_body = agent_body

	assert_true(controller.is_free_flight_active(), "PlayerControllerShip should expose free-flight state through the new accessor.")
	assert_eq(
		controller.get_active_navigation_command_type(),
		navigation_system.CommandType.FLEE,
		"PlayerControllerShip should surface the live NavigationSystem command type through the new accessor."
	)

	controller._current_input_state = null
	assert_false(controller.is_free_flight_active(), "Free-flight accessor should turn off once the free-flight state is no longer active.")


func test_main_hud_overlay_classification_and_filtering_track_requested_categories() -> void:
	var camera = Camera.new()
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")

	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		Vector3(0, 0, -100)
	)
	var stellar = StaticBody.new()
	stellar.name = "Planet Elace A"
	add_child_autofree(stellar)
	var structure = StaticBody.new()
	structure.name = "Relay Station"
	structure.add_to_group("dockable_station")
	add_child_autofree(structure)

	assert_eq(hud._get_projected_target_overlay_kind(route_target), hud.OVERLAY_KIND_JUMP, "Jump routes should classify into the Jump overlay bucket.")
	assert_eq(hud._get_projected_target_overlay_kind(stellar), hud.OVERLAY_KIND_STELLAR, "Named celestial bodies should classify into the Stellar overlay bucket.")
	assert_eq(hud._get_projected_target_overlay_kind(structure), hud.OVERLAY_KIND_STRUCTURES, "Stations and other non-celestial world targets should stay in the Structures overlay bucket.")

	hud._on_ButtonOverlayStructures_pressed()
	assert_false(hud._is_projected_target_overlay_enabled(hud.OVERLAY_KIND_STRUCTURES), "Structures overlay toggle should disable the Structures bucket when switched off.")
	assert_true(hud._is_projected_target_overlay_enabled(hud.OVERLAY_KIND_STELLAR), "Disabling Structures must not disable Stellar overlays.")
	hud._on_ButtonOverlayStructures_pressed()
	assert_true(hud._is_projected_target_overlay_enabled(hud.OVERLAY_KIND_STRUCTURES), "Structures overlay toggle should re-enable the Structures bucket on the next press.")


func test_main_hud_refreshes_persistent_button_states_from_live_owners() -> void:
	var camera = _create_toggle_state_camera()
	GlobalRefs.main_camera = camera

	var player_body = RigidBody.new()
	player_body.name = "Player"
	add_child_autofree(player_body)
	var controller = _create_toggle_state_controller()
	controller.name = Constants.PLAYER_INPUT_HANDLER_NAME
	player_body.add_child(controller)
	GlobalRefs.player_agent_body = player_body

	var tracked_target = Spatial.new()
	add_child_autofree(tracked_target)

	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")

	assert_eq(hud.button_overlay_structures.modulate, MainHUDScript.BUTTON_ACTIVE_MODULATE, "Overlay toggles should start in the ON visual state.")
	assert_eq(hud.button_overlay_stellar.modulate, MainHUDScript.BUTTON_ACTIVE_MODULATE, "Overlay toggles should start in the ON visual state.")
	assert_eq(hud.button_overlay_jump.modulate, MainHUDScript.BUTTON_ACTIVE_MODULATE, "Overlay toggles should start in the ON visual state.")

	controller.free_flight_active = true
	controller.nav_command_type = MainHUDScript.NAV_COMMAND_IDLE
	hud._refresh_toggle_button_states()
	assert_eq(hud.button_manual_flight.modulate, MainHUDScript.BUTTON_ACTIVE_MODULATE, "Manual Flight should highlight while free flight is active.")
	assert_eq(hud.button_orbit.modulate, MainHUDScript.BUTTON_INACTIVE_MODULATE, "Orbit should remain inactive while free flight owns piloting.")

	controller.free_flight_active = false
	controller.nav_command_type = MainHUDScript.NAV_COMMAND_ORBIT
	hud._refresh_toggle_button_states()
	assert_eq(hud.button_manual_flight.modulate, MainHUDScript.BUTTON_INACTIVE_MODULATE, "Manual Flight should clear once free flight is inactive.")
	assert_eq(hud.button_orbit.modulate, MainHUDScript.BUTTON_ACTIVE_MODULATE, "Orbit should highlight while orbit command is active.")

	controller.nav_command_type = MainHUDScript.NAV_COMMAND_APPROACH
	hud._refresh_toggle_button_states()
	assert_eq(hud.button_approach.modulate, MainHUDScript.BUTTON_ACTIVE_MODULATE, "Approach should highlight while the approach command is active.")
	assert_eq(hud.button_orbit.modulate, MainHUDScript.BUTTON_INACTIVE_MODULATE, "Only the active persistent command should stay highlighted.")

	controller.nav_command_type = MainHUDScript.NAV_COMMAND_FLEE
	hud._refresh_toggle_button_states()
	assert_eq(hud.button_flee.modulate, MainHUDScript.BUTTON_ACTIVE_MODULATE, "Flee should highlight while the flee command is active.")
	assert_eq(hud.button_approach.modulate, MainHUDScript.BUTTON_INACTIVE_MODULATE, "Approach should clear after the command changes.")

	camera.camera_mode = MainHUDScript.CAMERA_MODE_TARGET_TRACKING
	camera.look_target = tracked_target
	hud._refresh_toggle_button_states()
	assert_eq(hud.button_camera.modulate, MainHUDScript.BUTTON_ACTIVE_MODULATE, "Camera button should highlight while target-follow mode is active.")

	hud._on_ButtonOverlayJump_pressed()
	assert_eq(hud.button_overlay_jump.modulate, MainHUDScript.BUTTON_INACTIVE_MODULATE, "Overlay buttons should use the OFF visual state after their toggle is disabled.")


func test_main_hud_projected_target_distance_fade_alpha_matches_center_and_edge_targets() -> void:
	var hud = autofree(MainHUDScript.new())

	assert_almost_eq(
		hud._compute_projected_target_distance_fade_alpha(0.0),
		1.0,
		0.0001,
		"Projected targets should stay fully opaque at screen center."
	)
	assert_almost_eq(
		hud._compute_projected_target_distance_fade_alpha(1.0),
		0.1,
		0.0001,
		"Projected targets should retain roughly 10% opacity at the screen edge."
	)
	assert_true(
		hud._compute_projected_target_distance_fade_alpha(0.5) < 1.0 and hud._compute_projected_target_distance_fade_alpha(0.5) > 0.1,
		"Projected target fade should interpolate between center and edge opacity."
	)


func test_projected_target_bracket_scene_owns_centered_info_label_for_jump_routes() -> void:
	var bracket = _create_projected_target_bracket()
	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		Vector3(1, 0, 0)
	)
	bracket.configure_target(route_target)
	yield(get_tree(), "idle_frame")

	var info_label = bracket.get_node_or_null("InfoPanel/InfoLabel")
	assert_not_null(info_label, "Projected target bracket scene should own the info label node.")
	assert_eq(
		info_label.get_script().resource_path,
		"res://src/core/ui/helpers/CenteredGrowingLabel.gd",
		"Projected target labels should reuse CenteredGrowingLabel."
	)
	assert_eq(info_label.text, "Cob System", "Route brackets should show jump context under the bracket.")
	assert_eq(info_label.get_color("font_color"), Constants.COLOR_UI_JUMP_ROUTE, "Route label should be colored as a jump route.")
	assert_true(bracket.get_node("InfoPanel").visible, "Configured brackets should reveal their info panel.")


func test_projected_target_bracket_applies_colors_by_jump_type() -> void:
	var bracket = _create_projected_target_bracket()
	var types = ["star", "star_companion", "planet", "moon", "deep_space"]
	var colors = [
		Constants.COLOR_UI_JUMP_STAR,
		Constants.COLOR_UI_JUMP_STAR_COMPANION,
		Constants.COLOR_UI_JUMP_PLANET,
		Constants.COLOR_UI_JUMP_MOON,
		Constants.COLOR_UI_JUMP_DEEP_SPACE
	]
	
	for i in range(types.size()):
		var type = types[i]
		var expected_color = colors[i]
		var sector_id = "sector_test_" + type
		GameState.world_topology[sector_id] = {
			"sector_type": type,
			"connections": [],
			"station_ids": []
		}
		
		var route_target = RouteTargetScript.new().configure(
			"sector_star_elace",
			sector_id,
			"Test System " + type,
			Vector3(1, 0, 0)
		)
		bracket.configure_target(route_target)
		yield(get_tree(), "idle_frame")
		
		var info_label = bracket.get_node("InfoPanel/InfoLabel")
		var normal_bracket = bracket.get_node("BracketNormal")
		
		assert_eq(info_label.get_color("font_color"), expected_color, "Label font color should match the jump type: " + type)
		assert_eq(normal_bracket.modulate, expected_color, "Normal bracket modulate should match the jump type: " + type)


func test_projected_target_bracket_station_label_shows_dock_context() -> void:
	var bracket = _create_projected_target_bracket()
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.station_name = "Elace Exchange"
	add_child_autofree(station)
	bracket.configure_target(station, station.station_name)
	yield(get_tree(), "idle_frame")

	var info_label = bracket.get_node("InfoPanel/InfoLabel")
	assert_eq(info_label.text, "Elace Exchange\nDock Target", "Dockable stations should show dock context under their brackets.")


func test_projected_target_bracket_distance_formatter_matches_requested_magnitudes() -> void:
	var bracket = _create_projected_target_bracket()

	assert_eq(bracket._format_distance_label(3.0), "3", "Single-digit distances should render without padding or suffix.")
	assert_eq(bracket._format_distance_label(14.0), "14", "Two-digit distances should render without padding or suffix.")
	assert_eq(bracket._format_distance_label(211.0), "211", "Three-digit distances should render without padding or suffix.")
	assert_eq(bracket._format_distance_label(1899.0), "1899", "Four-digit short distances should remain in local units.")
	assert_eq(bracket._format_distance_label(2340.0), "2.34k", "Lower kilounit distances should keep two decimals.")
	assert_eq(bracket._format_distance_label(34500.0), "34.5k", "Mid-range kilounit distances should keep one decimal.")
	assert_eq(bracket._format_distance_label(276000.0), "276k", "Large kilounit distances should render as whole kilounits.")
	assert_eq(bracket._format_distance_label(999000.0), "999k", "Upper in-range kilounit distances should cap at whole kilounits.")
	assert_eq(bracket._format_distance_label(1000000.0), "FAR", "Distances beyond the readable range should render as FAR.")


func test_projected_target_bracket_selected_jump_route_shows_far_distance_label() -> void:
	var bracket = _create_projected_target_bracket()
	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		Vector3(1, 0, 0)
	)

	bracket.configure_target(route_target)
	bracket.set_selected_state(true)
	yield(get_tree(), "idle_frame")

	var distance_panel = bracket.get_node("BracketSelected/DistancePanel")
	var distance_label = bracket.get_node("BracketSelected/DistancePanel/DistanceLabel")
	assert_true(distance_panel.is_visible_in_tree(), "Selected jump routes should not suppress the distance panel visibility.")
	assert_eq(distance_label.text, "FAR", "Selected jump routes should render FAR in the distance label.")


func test_projected_target_bracket_selected_local_target_updates_distance_label_live() -> void:
	var bracket = _create_projected_target_bracket()
	var player = RigidBody.new()
	player.name = "Player"
	player.translation = Vector3.ZERO
	add_child_autofree(player)
	GlobalRefs.player_agent_body = player

	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.station_name = "Elace Exchange"
	station.translation = Vector3(3000, 0, 0)
	add_child_autofree(station)

	bracket.configure_target(station, station.station_name)
	bracket.set_selected_state(true)
	yield(get_tree(), "idle_frame")

	var distance_label = bracket.get_node("BracketSelected/DistancePanel/DistanceLabel")
	assert_eq(distance_label.text, "3k", "Selected local targets should use the compact distance format without leading zeros.")

	station.translation = Vector3(4000, 0, 0)
	yield(get_tree(), "idle_frame")

	assert_eq(distance_label.text, "4k", "Selected target distance should update while the target moves in the local scene.")


func test_projected_target_bracket_selected_jump_point_shows_far_distance_label() -> void:
	var bracket = _create_projected_target_bracket()
	var player = RigidBody.new()
	player.name = "Player"
	add_child_autofree(player)
	GlobalRefs.player_agent_body = player

	var jump_point = StaticBody.new()
	jump_point.name = "JumpPoint"
	jump_point.translation = Vector3(3000, 0, 0)
	jump_point.add_to_group("jump_point")
	add_child_autofree(jump_point)

	bracket.configure_target(jump_point, "Jump")
	bracket.set_selected_state(true)
	yield(get_tree(), "idle_frame")

	var distance_label = bracket.get_node("BracketSelected/DistancePanel/DistanceLabel")
	assert_eq(distance_label.text, "FAR", "Jump points should render FAR in the selected-target distance label.")


func test_projected_target_bracket_selected_texture_visibility_tracks_state() -> void:
	var bracket = _create_projected_target_bracket()
	yield(get_tree(), "idle_frame")

	var normal_bracket = bracket.get_node("BracketNormal")
	var selected_bracket = bracket.get_node("BracketSelected")
	assert_eq(normal_bracket.stretch_mode, TextureRect.STRETCH_KEEP_CENTERED, "Normal bracket should use the raw texture without scaling.")
	assert_eq(selected_bracket.stretch_mode, TextureRect.STRETCH_KEEP_CENTERED, "Selected bracket should use the raw texture without scaling.")
	assert_true(normal_bracket.visible, "Normal bracket texture should be visible by default.")
	assert_false(selected_bracket.visible, "Selected bracket texture should start hidden.")

	bracket.set_selected_state(true)

	assert_false(normal_bracket.visible, "Normal bracket texture should hide once selected.")
	assert_true(selected_bracket.visible, "Selected bracket texture should appear once selected.")


func test_projected_target_bracket_label_has_no_background_frame() -> void:
	var bracket = _create_projected_target_bracket()
	yield(get_tree(), "idle_frame")

	assert_false(bracket.get_node("InfoPanel") is PanelContainer, "Bracket label should render as text only without a panel frame.")


func test_main_hud_scene_no_longer_instantiates_removed_target_prompt_panels() -> void:
	var camera = Camera.new()
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")

	assert_null(
		hud.get_node_or_null("ScreenControls/TopCenterZone (to be removed)"),
		"MainHUD should not keep the old top-center prompt container in the active scene."
	)
	assert_null(
		hud.get_node_or_null("ScreenControls/TopRightZone/RadarDisplay (to be removed)"),
		"MainHUD should not keep the removed radar panel in the active scene."
	)

func test_projected_target_bracket_click_release_emits_pressed() -> void:
	var bracket = _create_projected_target_bracket()
	yield(get_tree(), "idle_frame")
	watch_signals(bracket)

	yield(_dispatch_bracket_mouse_button(Vector2(40, 40), true), "completed")
	yield(_dispatch_bracket_mouse_button(Vector2(40, 40), false), "completed")

	assert_signal_emitted(bracket, "pressed", "Click-release should still emit the bracket pressed signal.")


func test_projected_target_bracket_drag_does_not_emit_pressed() -> void:
	var bracket = _create_projected_target_bracket()
	yield(get_tree(), "idle_frame")
	watch_signals(bracket)

	yield(_dispatch_bracket_mouse_button(Vector2(40, 40), true), "completed")
	yield(_dispatch_bracket_mouse_motion(Vector2(60, 40), Vector2(20, 0)), "completed")
	yield(_dispatch_bracket_mouse_button(Vector2(60, 40), false), "completed")

	assert_signal_not_emitted(bracket, "pressed", "Drag-release should cancel the pending bracket click.")
	assert_false(bracket.disabled, "Bracket should restore its enabled state after the drag ends.")



func test_projected_target_bracket_hover_wheel_forwards_zoom_input_to_camera() -> void:
	var bracket = _create_projected_target_bracket()
	var camera = _create_scroll_mock_camera()
	GlobalRefs.main_camera = camera

	yield(_dispatch_bracket_mouse_wheel(Vector2(40, 40), BUTTON_WHEEL_UP), "completed")
	yield(_dispatch_bracket_mouse_wheel(Vector2(40, 40), BUTTON_WHEEL_DOWN), "completed")

	assert_eq(camera.forwarded_wheel_buttons, [BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN], "Hovering a target bracket should still forward mouse wheel zoom input to the camera.")


func test_projected_target_bracket_forwards_mouse_motion_to_controller_in_free_flight() -> void:
	var bracket = _create_projected_target_bracket()

	var player_body = RigidBody.new()
	player_body.name = "Player"
	add_child_autofree(player_body)

	var script = GDScript.new()
	script.source_code = "extends Node\nvar received_motion_events = []\nfunc is_free_flight_active() -> bool:\n\treturn true\nfunc _unhandled_input(event):\n\tif event is InputEventMouseMotion:\n\t\treceived_motion_events.append(event)\n"
	script.reload()
	var controller = Node.new()
	controller.set_script(script)
	controller.name = Constants.PLAYER_INPUT_HANDLER_NAME
	player_body.add_child(controller)
	GlobalRefs.player_agent_body = player_body

	yield(get_tree(), "idle_frame")

	var motion_event = InputEventMouseMotion.new()
	motion_event.position = Vector2(40, 40)
	motion_event.relative = Vector2(5, 5)

	bracket._input(motion_event)

	assert_eq(controller.received_motion_events.size(), 1, "Bracket should forward passive mouse motion to player controller when free flight is active.")
	assert_eq(controller.received_motion_events[0].relative, Vector2(5, 5), "Forwarded event should match the original event details.")




func _create_projected_target_bracket() -> Button:
	var bracket = ProjectedTargetBracketScene.instance()
	bracket.rect_position = Vector2(20, 20)
	bracket.rect_size = Vector2(150, 150)
	add_child_autofree(bracket)
	return bracket


func _make_location_template(template_id: String, location_name: String, global_position: Vector3):
	var template = LocationTemplateScript.new()
	template.template_id = template_id
	template.location_name = location_name
	template.global_position = global_position
	return template


func _create_mock_camera() -> Node:
	var script = GDScript.new()
	script.source_code = "extends Node\nvar rotating_states = []\nvar forwarded_motion = []\nfunc set_is_rotating(rotating):\n\trotating_states.append(rotating)\nfunc _unhandled_input(event):\n\tif event is InputEventMouseMotion:\n\t\tforwarded_motion.append(event.relative)\n"
	script.reload()
	var camera = Node.new()
	camera.set_script(script)
	add_child_autofree(camera)
	return camera


func _create_scroll_mock_camera() -> Node:
	var script = GDScript.new()
	script.source_code = "extends Node\nvar forwarded_wheel_buttons = []\nfunc _unhandled_input(event):\n\tif event is InputEventMouseButton and event.pressed and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN):\n\t\tforwarded_wheel_buttons.append(event.button_index)\n"
	script.reload()
	var camera = Node.new()
	camera.set_script(script)
	add_child_autofree(camera)
	return camera


func _create_main_hud_drag_harness(stop_camera_on_release: bool = true) -> Dictionary:
	var camera = _create_external_rotation_camera()
	GlobalRefs.main_camera = camera

	var player_body = RigidBody.new()
	player_body.name = "Player"
	player_body.gravity_scale = 0.0
	add_child_autofree(player_body)

	var controller = _create_mock_player_input_handler(stop_camera_on_release)
	controller.name = Constants.PLAYER_INPUT_HANDLER_NAME
	player_body.add_child(controller)
	GlobalRefs.player_agent_body = player_body

	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")

	return {"hud": hud, "camera": camera, "controller": controller}


func _create_external_rotation_camera() -> Camera:
	var script = GDScript.new()
	script.source_code = "extends Camera\nvar externally_rotating = false\nvar forwarded_motion = []\nfunc set_is_rotating(rotating):\n\texternally_rotating = rotating\nfunc is_externally_rotating():\n\treturn externally_rotating\nfunc _unhandled_input(event):\n\tif event is InputEventMouseMotion:\n\t\tforwarded_motion.append(event.relative)\n"
	script.reload()
	var camera = Camera.new()
	camera.set_script(script)
	add_child_autofree(camera)
	return camera


func _create_toggle_state_camera() -> Camera:
	var script = GDScript.new()
	script.source_code = "extends Camera\nvar camera_mode = 0\nvar look_target = null\nfunc get_camera_mode() -> int:\n\treturn camera_mode\nfunc get_look_at_target():\n\treturn look_target\n"
	script.reload()
	var camera = Camera.new()
	camera.set_script(script)
	add_child_autofree(camera)
	return camera


func _create_toggle_state_controller() -> Node:
	var script = GDScript.new()
	script.source_code = "extends Node\nvar free_flight_active = false\nvar nav_command_type = 0\nfunc is_free_flight_active() -> bool:\n\treturn free_flight_active\nfunc get_active_navigation_command_type() -> int:\n\treturn nav_command_type\n"
	script.reload()
	var controller = Node.new()
	controller.set_script(script)
	return controller


func _create_mock_player_input_handler(stop_camera_on_release: bool = true) -> Node:
	var script = GDScript.new()
	var source = "extends Node\nvar release_events = []\nfunc _unhandled_input(event):\n\tif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:\n\t\trelease_events.append(event.position)\n"
	if stop_camera_on_release:
		source += "\t\tvar camera = GlobalRefs.main_camera\n\t\tif is_instance_valid(camera):\n\t\t\tcamera.externally_rotating = false\n"
	script.source_code = source
	script.reload()
	var controller = Node.new()
	controller.set_script(script)
	return controller


func _begin_external_drag(camera: Camera, press_position: Vector2) -> void:
	camera.externally_rotating = true
	yield(_dispatch_mouse_button(press_position, true), "completed")


func _get_control_center(control: Control) -> Vector2:
	var control_rect = control.get_global_rect()
	return control_rect.position + (control_rect.size / 2.0)


func _dispatch_mouse_button(position: Vector2, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")


func _dispatch_mouse_wheel(position: Vector2, button_index: int) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = position
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")


func _dispatch_mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event = InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")


func _dispatch_bracket_mouse_button(position: Vector2, pressed: bool) -> void:
	yield(_dispatch_mouse_button(position, pressed), "completed")


func _dispatch_bracket_mouse_wheel(position: Vector2, button_index: int) -> void:
	yield(_dispatch_mouse_wheel(position, button_index), "completed")


func _dispatch_bracket_mouse_motion(position: Vector2, relative: Vector2) -> void:
	yield(_dispatch_mouse_motion(position, relative), "completed")


func test_main_hud_dock_button_label_toggles_between_dock_and_travel() -> void:
	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")

	var label_dock = hud.get_node("ScreenControls/BottomCenterZone/ButtonDock/LabelButtonDock")
	assert_eq(label_dock.text, "DOCK", "Dock button label should be DOCK by default.")

	# Select a non-jump target (e.g. station)
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.station_name = "Elace Exchange"
	add_child_autofree(station)
	hud._on_Player_Target_Selected(station)
	yield(get_tree(), "idle_frame")
	assert_eq(label_dock.text, "DOCK", "Dock button label should remain DOCK when a station target is selected.")

	# Select a route target (jump target)
	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		Vector3(1, 0, 0)
	)
	hud._on_Player_Target_Selected(route_target)
	yield(get_tree(), "idle_frame")
	assert_eq(label_dock.text, "TRAVEL", "Dock button label should change to TRAVEL when a jump route is selected.")

	# Deselect target
	hud._on_Player_Target_Deselected()
	yield(get_tree(), "idle_frame")
	assert_eq(label_dock.text, "DOCK", "Dock button label should return to DOCK on target deselect.")
