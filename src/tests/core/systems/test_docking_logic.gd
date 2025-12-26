extends "res://addons/gut/test.gd"

var DockableStationScript = load("res://src/scenes/game_world/station/dockable_station.gd")
var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")

func test_docking_signals():
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.location_id = "test_station"
	
	var docking_zone = Area.new()
	docking_zone.name = "DockingZone"
	station.add_child(docking_zone)
	
	add_child(station)
	
	var player = RigidBody.new()
	player.name = "Player"
	player.gravity_scale = 0.0
	# Mock is_player method
	var script = GDScript.new()
	script.source_code = "extends RigidBody\nfunc is_player(): return true"
	script.reload()
	player.set_script(script)
	add_child(player)
	
	watch_signals(EventBus)
	
	# Simulate enter
	station._on_body_entered(player)
	assert_signal_emitted_with_parameters(EventBus, "dock_available", ["test_station"])
	
	# Simulate exit
	station._on_body_exited(player)
	assert_signal_emitted(EventBus, "dock_unavailable")
	
	station.free()
	player.free()

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
	
	# Simulate dock available
	controller._on_dock_available("station_beta")
	assert_eq(controller._can_dock_at, "station_beta")
	
	# Simulate dock unavailable
	controller._on_dock_unavailable()
	assert_eq(controller._can_dock_at, "")
	
	# Simulate docking
	controller._on_player_docked("station_gamma")
	assert_false(controller.is_processing_unhandled_input())
	assert_false(controller.is_physics_processing())
	
	# Simulate undocking
	controller._on_player_undocked()
	assert_true(controller.is_processing_unhandled_input())
	assert_true(controller.is_physics_processing())
	
	agent.free()
