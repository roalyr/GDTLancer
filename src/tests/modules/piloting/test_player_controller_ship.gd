# Tests for PlayerControllerShip docking input.

extends "res://addons/gut/test.gd"

var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")


func before_each():
	GameState.reset_state()


func after_each():
	GameState.reset_state()


func test_dock_without_a_station_never_docks_at_the_sector():
	var controller = PlayerControllerScript.new()
	GameState.current_sector_id = "sector_star_elace"
	watch_signals(EventBus)

	controller._on_dock_button_pressed()

	assert_signal_not_emitted(EventBus, "player_docked", "Docking is only ever at a station.")
	assert_signal_emitted(EventBus, "dock_action_feedback")
	GameState.current_sector_id = ""
	controller.free()


func test_docking_at_a_selected_station_depends_on_distance_to_its_hull():
	var station = StaticBody.new()
	station.set_script(load("res://src/scenes/game_world/station/dockable_station.gd"))
	station.location_id = "station_test"
	station.obstacle_radius = 100.0
	add_child_autofree(station)
	var ship = RigidBody.new()
	add_child_autofree(ship)
	var controller = PlayerControllerScript.new()
	controller.agent_body = ship
	controller._selected_target = station
	watch_signals(EventBus)

	ship.global_transform.origin = Vector3(0, 0, 100.0 + Constants.DOCKING_ACTION_RADIUS + 50.0)
	controller._on_dock_button_pressed()
	assert_signal_not_emitted(EventBus, "player_docked", "Too far from the hull.")

	ship.global_transform.origin = Vector3(0, 0, 100.0 + Constants.DOCKING_ACTION_RADIUS - 50.0)
	controller._on_dock_button_pressed()
	assert_signal_emitted_with_parameters(EventBus, "player_docked", ["station_test"])
	controller.free()


func test_dock_without_target_or_sector_reports_failure():
	var controller = PlayerControllerScript.new()
	watch_signals(EventBus)

	controller._on_dock_button_pressed()

	assert_signal_not_emitted(EventBus, "player_docked")
	assert_signal_emitted(EventBus, "dock_action_feedback")
	controller.free()
