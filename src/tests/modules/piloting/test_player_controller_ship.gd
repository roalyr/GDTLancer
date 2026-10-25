# Tests for PlayerControllerShip docking input.

extends "res://addons/gut/test.gd"

var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")


func before_each():
	GameState.reset_state()


func after_each():
	GameState.reset_state()


func test_dock_without_a_station_never_docks_at_the_sector():
	var controller = PlayerControllerScript.new()
	GameState.current_sector_id = "sector_elace"
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


func test_double_click_on_a_target_issues_approach():
	var Agent = load("res://src/core/agents/agent.gd")
	var ship = Agent.new()
	add_child_autofree(ship)
	var controller = PlayerControllerScript.new()
	controller.agent_body = ship
	controller.agent_script = ship
	watch_signals(EventBus)

	controller.handle_target_double_click()

	assert_signal_emitted(EventBus, "player_approach_pressed", "As the Approach button does.")
	controller.free()


class CommandRecorder:
	extends Node
	var last := ""
	func command_ram(_target):
		last = "ram"
	func command_approach(_target):
		last = "approach"
	func command_stop():
		last = "stop"


class NavStub:
	extends Node
	var type := 0
	var _current_command := {}
	func get_current_command_type() -> int:
		return type


func test_approach_rams_while_the_lance_is_armed():
	var Agent = load("res://src/core/agents/agent.gd")
	var ShipLaws = load("res://src/core/systems/ship_laws.gd")
	var Nav = load("res://src/core/agents/components/navigation_system.gd")
	var ship = Agent.new()
	add_child_autofree(ship)
	var lance = load("res://src/core/agents/components/lance_controller.gd").new()
	ship.add_child(lance)
	lance.setup(ship, "lance", ShipLaws.lance_stats({"nail_mass": 200.0, "count": 3.0}))
	var nav = NavStub.new()
	nav.name = "NavigationSystem"
	ship.add_child(nav)
	var enemy = Agent.new()
	add_child_autofree(enemy)
	var controller = PlayerControllerScript.new()
	var recorder = CommandRecorder.new()
	controller.agent_body = ship
	controller.agent_script = recorder
	controller._selected_target = enemy

	controller._on_Player_Approach_Pressed()
	assert_eq(recorder.last, "approach", "Safe lance: approach")
	lance.armed = true
	controller._on_Player_Approach_Pressed()
	assert_eq(recorder.last, "ram", "Armed: the button rams")

	nav._current_command = {"target_node": enemy}
	nav.type = Nav.CommandType.RAM
	lance.armed = false
	controller._sync_ram_command()
	assert_eq(recorder.last, "approach", "Made safe while ramming: back to approaching")
	nav.type = Nav.CommandType.APPROACH
	lance.armed = true
	controller._sync_ram_command()
	assert_eq(recorder.last, "ram", "Armed while approaching: ramming")
	lance.nails = 0
	assert_false(controller.is_ram_ready(enemy), "No lances left: no ramming")
	controller.free()
	recorder.free()


func test_a_lost_target_stops_the_commands_on_it():
	var Agent = load("res://src/core/agents/agent.gd")
	var ship = Agent.new()
	add_child_autofree(ship)
	var nav = NavStub.new()
	nav.name = "NavigationSystem"
	ship.add_child(nav)
	var enemy = Agent.new()
	add_child_autofree(enemy)
	var controller = PlayerControllerScript.new()
	var recorder = CommandRecorder.new()
	controller.agent_body = ship
	controller.agent_script = recorder
	controller._set_selected_target(enemy)
	nav._current_command = {"target_node": enemy}
	controller._set_selected_target(null)
	assert_eq(recorder.last, "stop", "Lost: no more following it")
	controller.free()
	recorder.free()
