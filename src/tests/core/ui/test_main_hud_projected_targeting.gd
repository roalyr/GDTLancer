extends "res://addons/gut/test.gd"

var MainHUDScript = load("res://src/core/ui/main_hud/main_hud.gd")
var DockableStationScript = load("res://src/scenes/game_world/station/dockable_station.gd")
var AgentScript = load("res://src/core/agents/agent.gd")


func after_each():
	GlobalRefs.player_agent_body = null
	GlobalRefs.current_zone = null
	GameState.player_character_uid = ""


func test_collect_world_projected_targets_includes_scene_objects_and_npcs_but_excludes_player_and_jump_points():
	var zone = Spatial.new()
	zone.name = "ZoneRoot"
	add_child(zone)

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

	var hud = Control.new()
	hud.set_script(MainHUDScript)
	var targets: Array = hud._collect_world_projected_targets()

	assert_has(targets, station, "Dockable stations should get projected HUD targets.")
	assert_has(targets, star, "Static scene objects should get projected HUD targets.")
	assert_has(targets, npc, "NPC agents should get projected HUD targets.")
	assert_false(targets.has(player), "The player agent should not get a self-targeting HUD bracket.")
	assert_false(targets.has(jump_point), "Legacy physical jump points should not get projected HUD brackets.")

	zone.queue_free()