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


func test_each_tool_button_toggles_only_its_own_tool_on_a_valid_target():
	var Agent = load("res://src/core/agents/agent.gd")
	var Tools = load("res://src/core/agents/components/tool_controller.gd")
	var ship = Agent.new()
	add_child_autofree(ship)
	ship.power = 100.0
	var tools = Tools.new()
	ship.add_child(tools)
	var laser = UtilityToolTemplate.new()
	laser.tool_type = "laser"
	var harpoon = UtilityToolTemplate.new()
	harpoon.tool_type = "harpoon"
	tools.set_tools([laser, harpoon])
	var enemy = Agent.new()
	add_child_autofree(enemy)
	enemy.global_transform.origin = Vector3(0, 0, -300)
	var controller = PlayerControllerScript.new()
	controller.agent_body = ship
	controller._tool_controller = tools
	controller._selected_target = enemy
	watch_signals(EventBus)

	controller._on_tool_button_pressed(0)
	assert_true(tools.is_active(0), "Laser button fires the laser at the selected ship.")
	assert_false(tools.is_active(1))
	controller._on_tool_button_pressed(1)
	assert_false(tools.is_active(1), "Harpoon button refuses a live ship")
	assert_signal_emitted(EventBus, "attack_action_feedback")
	controller._on_tool_button_pressed(0)
	assert_false(tools.is_active(0), "Pressed again: ceases.")
	controller.free()
