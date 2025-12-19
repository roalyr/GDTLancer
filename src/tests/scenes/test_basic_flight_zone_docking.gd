extends "res://addons/gut/test.gd"

var ZoneScene = load("res://scenes/levels/zones/zone1/basic_flight_zone.tscn")
var PlayerAgentScene = load("res://src/core/agents/player_agent.tscn")

func test_station_exists_in_zone():
	var zone = ZoneScene.instance()
	add_child(zone)
	
	var system_1 = zone.get_node("SceneAssets/System_1")
	assert_not_null(system_1, "System_1 should exist")
	
	var station = system_1.get_node("Station_Alpha")
	assert_not_null(station, "Station_Alpha should exist under System_1")
	assert_eq(station.location_id, "station_alpha")
	
	zone.free()

func test_docking_in_zone():
	var zone = ZoneScene.instance()
	add_child(zone)
	
	var station = zone.get_node("SceneAssets/System_1/Station_Alpha")
	
	# Create a player mock
	var player = KinematicBody.new()
	player.name = "PlayerMock"
	var script = GDScript.new()
	script.source_code = "extends KinematicBody\nfunc is_player(): return true"
	script.reload()
	player.set_script(script)
	
	# Add player to zone
	zone.add_child(player)
	
	# Move player to station position (global)
	player.global_transform.origin = station.global_transform.origin
	
	# Force physics update or manually call signal
	# Since we are in a test, we can manually trigger the area overlap if we don't want to wait for physics
	# But let's try to use the area's monitoring
	
	watch_signals(EventBus)
	
	# Manually trigger for reliability in unit test without physics engine running full cycle
	station._on_body_entered(player)
	
	assert_signal_emitted_with_parameters(EventBus, "dock_available", ["station_alpha"])
	
	station._on_body_exited(player)
	assert_signal_emitted(EventBus, "dock_unavailable")
	
	zone.free()
