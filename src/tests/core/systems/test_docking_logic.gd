##
## PROJECT: GDTLancer
## MODULE: test_docking_logic.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: Current docking flow via player_controller_ship.gd proximity polling
## LOG_REF: 2026-05-09 19:55:46
##

extends "res://addons/gut/test.gd"

var DockableStationScript = load("res://src/scenes/game_world/station/dockable_station.gd")
var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")
var RouteTargetScript = load("res://src/core/targeting/route_target.gd")

func test_docking_signals():
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.location_id = "test_station"
	station.station_name = "Test Station"
	station.transform.origin = Vector3(100, 0, 0)
	add_child(station)
	
	var agent = RigidBody.new()
	agent.name = "Player"
	agent.gravity_scale = 0.0
	var agent_script = GDScript.new()
	agent_script.source_code = "extends RigidBody\nfunc command_stop(): pass\nfunc is_player(): return true"
	agent_script.reload()
	agent.set_script(agent_script)

	var movement_system = Node.new()
	movement_system.name = "MovementSystem"
	agent.add_child(movement_system)

	var controller = Node.new()
	controller.set_script(PlayerControllerScript)
	controller.name = "PlayerInputHandler"
	agent.add_child(controller)

	add_child(agent)
	
	watch_signals(EventBus)
	
	controller._set_selected_target(station)
	controller._poll_docking_proximity()
	assert_signal_emitted_with_parameters(EventBus, "dock_available", ["test_station"])
	assert_eq(controller._can_dock_at, "test_station")
	
	station.transform.origin = Vector3(1000, 0, 0)
	controller._poll_docking_proximity()
	assert_signal_emitted(EventBus, "dock_unavailable")
	assert_eq(controller._can_dock_at, "")
	
	station.free()
	agent.free()

func test_player_controller_docking():
	var agent = RigidBody.new()
	agent.gravity_scale = 0.0
	# Mock command_stop
	var agent_script = GDScript.new()
	agent_script.source_code = "extends RigidBody\nfunc command_stop(): pass"
	agent_script.reload()
	agent.set_script(agent_script)
	
	var movement_system = Node.new()
	movement_system.name = "MovementSystem"
	agent.add_child(movement_system)
	
	var controller = Node.new()
	controller.set_script(PlayerControllerScript)
	controller.name = "PlayerInputHandler"
	agent.add_child(controller)
	
	add_child(agent)
	assert_eq(controller._can_dock_at, "")
	
	# Simulate docking
	controller._on_player_docked("station_gamma")
	assert_eq(GameState.player_docked_at, "station_gamma")
	assert_false(controller.is_processing_unhandled_input())
	assert_false(controller.is_physics_processing())
	
	# Simulate undocking
	controller._on_player_undocked()
	assert_eq(GameState.player_docked_at, "")
	assert_true(controller.is_processing_unhandled_input())
	assert_true(controller.is_physics_processing())
	
	agent.free()


func test_route_target_selection_enables_jump_without_distance_gate():
	var agent = RigidBody.new()
	agent.gravity_scale = 0.0
	var agent_script = GDScript.new()
	agent_script.source_code = "extends RigidBody\nfunc command_stop(): pass"
	agent_script.reload()
	agent.set_script(agent_script)

	var movement_system = Node.new()
	movement_system.name = "MovementSystem"
	agent.add_child(movement_system)

	var controller = Node.new()
	controller.set_script(PlayerControllerScript)
	controller.name = "PlayerInputHandler"
	agent.add_child(controller)

	add_child(agent)
	watch_signals(EventBus)

	var route_target = RouteTargetScript.new().configure(
		"sector_system_elace",
		"sector_system_cob",
		"Cob System",
		Vector3(1, 0, 0)
	)
	controller._set_selected_target(route_target)
	controller._poll_docking_proximity()
	assert_signal_emitted_with_parameters(EventBus, "jump_available", ["sector_system_cob", "Cob System"])
	controller._handle_interact_input()
	assert_signal_emitted_with_parameters(EventBus, "player_jump_requested", ["sector_system_cob"])

	agent.free()


func test_single_click_clears_selection_without_world_raycast_pick():
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.location_id = "test_station"
	station.station_name = "Test Station"
	add_child(station)

	var agent = RigidBody.new()
	agent.gravity_scale = 0.0
	var agent_script = GDScript.new()
	agent_script.source_code = "extends RigidBody\nfunc command_stop(): pass"
	agent_script.reload()
	agent.set_script(agent_script)

	var movement_system = Node.new()
	movement_system.name = "MovementSystem"
	agent.add_child(movement_system)

	var controller = Node.new()
	controller.set_script(PlayerControllerScript)
	controller.name = "PlayerInputHandler"
	agent.add_child(controller)

	add_child(agent)
	watch_signals(EventBus)

	controller._set_selected_target(station)
	controller._target_under_cursor = station
	controller._handle_single_click(Vector2.ZERO)
	assert_eq(controller._selected_target, null, "Single-click fallback should now clear selection instead of picking the collider under the cursor.")
	assert_signal_emitted(EventBus, "player_target_deselected")

	agent.free()
	station.free()

