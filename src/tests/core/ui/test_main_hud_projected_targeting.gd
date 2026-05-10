#
# PROJECT: GDTLancer
# MODULE: test_main_hud_projected_targeting.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §4.2, §6.1, §6.3
# LOG_REF: 2026-05-10 23:59:35
#

extends "res://addons/gut/test.gd"

var MainHUDScene = load("res://scenes/ui/hud/main_hud.tscn")
var MainHUDScript = load("res://src/core/ui/main_hud/main_hud.gd")
var ProjectedTargetBracketScript = load("res://src/core/ui/main_hud/projected_target_bracket.gd")
var DockableStationScript = load("res://src/scenes/game_world/station/dockable_station.gd")
var AgentScript = load("res://src/core/agents/agent.gd")


func after_each():
	GlobalRefs.main_hud = null
	GlobalRefs.player_agent_body = null
	GlobalRefs.main_camera = null
	GlobalRefs.current_zone = null
	GameState.player_character_uid = ""


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


func test_projected_target_bracket_drag_bridges_into_camera_rotation_path() -> void:
	var bracket = _create_projected_target_bracket()
	var camera = _create_mock_camera()
	GlobalRefs.main_camera = camera

	yield(_dispatch_bracket_mouse_button(Vector2(40, 40), true), "completed")
	yield(_dispatch_bracket_mouse_motion(Vector2(60, 40), Vector2(20, 0)), "completed")
	yield(_dispatch_bracket_mouse_motion(Vector2(78, 42), Vector2(18, 2)), "completed")
	yield(_dispatch_bracket_mouse_button(Vector2(78, 42), false), "completed")

	assert_eq(camera.rotating_states, [true, false], "Bracket drag should start and stop camera external rotation.")
	assert_eq(camera.forwarded_motion.size(), 2, "Bracket drag should forward motion events into the live camera input path.")
	assert_eq(camera.forwarded_motion[0], Vector2(20, 0), "The threshold-crossing drag motion should reach the camera.")
	assert_eq(camera.forwarded_motion[1], Vector2(18, 2), "Subsequent drag motion should continue reaching the camera.")


func _create_projected_target_bracket() -> Button:
	var bracket = Button.new()
	bracket.set_script(ProjectedTargetBracketScript)
	bracket.rect_position = Vector2(20, 20)
	bracket.rect_size = Vector2(180, 56)
	add_child_autofree(bracket)
	return bracket


func _create_mock_camera() -> Node:
	var script = GDScript.new()
	script.source_code = "extends Node\nvar rotating_states = []\nvar forwarded_motion = []\nfunc set_is_rotating(rotating):\n\trotating_states.append(rotating)\nfunc _unhandled_input(event):\n\tif event is InputEventMouseMotion:\n\t\tforwarded_motion.append(event.relative)\n"
	script.reload()
	var camera = Node.new()
	camera.set_script(script)
	add_child_autofree(camera)
	return camera


func _dispatch_bracket_mouse_button(position: Vector2, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")


func _dispatch_bracket_mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event = InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")