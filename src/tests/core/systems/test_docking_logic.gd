##
## PROJECT: GDTLancer
## MODULE: test_docking_logic.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §4.2, §6.1, §6.3
## LOG_REF: 2026-05-23 16:28:25
##

extends "res://addons/gut/test.gd"

var DockableStationScript = load("res://src/scenes/game_world/station/dockable_station.gd")
var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")
var RouteTargetScript = load("res://src/core/targeting/route_target.gd")
const TEST_ROUTE_DIRECTION = Vector3(0, 0, -1)


func after_each():
	GameState.player_docked_at = ""
	GlobalRefs.world_manager = null

func test_docking_signals():
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.location_id = "test_station"
	station.station_name = "Test Station"
	station.transform.origin = Vector3(100, 0, 0)
	add_child_autofree(station)

	var harness = _create_player_controller_harness()
	var controller = harness["controller"]
	
	watch_signals(EventBus)
	
	controller._set_selected_target(station)
	controller._poll_docking_proximity()
	assert_signal_emitted_with_parameters(EventBus, "dock_available", ["test_station"])
	assert_eq(controller._can_dock_at, "test_station")
	
	station.transform.origin = Vector3(1000, 0, 0)
	controller._poll_docking_proximity()
	assert_signal_emitted(EventBus, "dock_unavailable")
	assert_eq(controller._can_dock_at, "")

func test_player_controller_docking():
	var harness = _create_player_controller_harness()
	var agent = harness["agent"]
	var controller = harness["controller"]
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
	assert_eq(agent.stop_calls, 1, "Docking should still stop the ship exactly once.")


func test_route_target_selection_always_queues_alignment_before_jump():
	var harness = _create_player_controller_harness(true, true)
	var agent = harness["agent"]
	var controller = harness["controller"]
	watch_signals(EventBus)

	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		TEST_ROUTE_DIRECTION
	)
	controller._set_selected_target(route_target)
	controller._poll_docking_proximity()
	assert_signal_emitted_with_parameters(EventBus, "jump_available", ["sector_star_cob", "Cob System"])
	controller._handle_interact_input()
	assert_signal_not_emitted(EventBus, "player_jump_requested", "Jump interact should always enter the align-before-jump flow first.")
	assert_eq(agent.align_calls, [TEST_ROUTE_DIRECTION], "Jump interact should always issue an align command before travelling.")
	assert_eq(agent.align_options, [[true, 1.0, true]], "Queued jumps should keep the ship actively driving toward the jump point until the transition despawns the scene, even when already aligned.")
	assert_eq(controller._queued_jump_target_id, "sector_star_cob", "Jump interact should retain the queued jump until the post-align validation tick.")

	controller._physics_process(1.0 / 60.0)
	assert_signal_emitted_with_parameters(EventBus, "player_jump_requested", ["sector_star_cob"])
	assert_eq(controller._queued_jump_target_id, "", "Queued aligned jumps should clear once the first post-align validation tick fires.")


func test_route_target_interact_queues_alignment_before_jump():
	var harness = _create_player_controller_harness(false, false)
	var agent = harness["agent"]
	var controller = harness["controller"]
	watch_signals(EventBus)

	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		TEST_ROUTE_DIRECTION
	)
	controller._set_selected_target(route_target)
	controller._poll_docking_proximity()
	controller._handle_interact_input()

	assert_signal_not_emitted(EventBus, "player_jump_requested", "Misaligned route jumps should queue alignment before requesting travel.")
	assert_eq(agent.align_calls, [TEST_ROUTE_DIRECTION], "Queued route jumps should reuse the live align command with the route direction.")
	assert_eq(agent.align_options, [[true, 1.0, true]], "Misaligned queued jump alignment should keep applying full forward thrust and heading control until the old scene is torn down.")
	assert_eq(controller._queued_jump_target_id, "sector_star_cob", "Misaligned route jumps should remember the pending sector id until alignment completes.")
	assert_eq(controller._queued_jump_selection_token, route_target.selection_key, "Queued route jumps should bind to the currently selected route target.")


func test_queued_route_jump_auto_executes_after_alignment_completes():
	var harness = _create_player_controller_harness(false, false)
	var agent = harness["agent"]
	var movement_system = harness["movement_system"]
	var controller = harness["controller"]
	watch_signals(EventBus)

	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		TEST_ROUTE_DIRECTION
	)
	controller._set_selected_target(route_target)
	controller._poll_docking_proximity()
	controller._handle_interact_input()

	agent.rotation_degrees = Vector3.ZERO
	movement_system.rotation_stopped = true
	controller._physics_process(1.0 / 60.0)

	assert_signal_emitted_with_parameters(EventBus, "player_jump_requested", ["sector_star_cob"])
	assert_eq(controller._queued_jump_target_id, "", "Queued route jumps should clear once the auto-jump fires.")


func test_queued_route_jump_waits_for_tight_five_degree_alignment():
	var harness = _create_player_controller_harness(false, true)
	var agent = harness["agent"]
	var controller = harness["controller"]
	watch_signals(EventBus)

	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		TEST_ROUTE_DIRECTION
	)
	controller._set_selected_target(route_target)
	controller._poll_docking_proximity()
	controller._handle_interact_input()

	agent.rotation_degrees = Vector3(0, 7, 0)
	controller._physics_process(1.0 / 60.0)
	assert_signal_not_emitted(EventBus, "player_jump_requested", "Queued jumps should wait until the ship is within the tighter five-degree jump gate.")

	agent.rotation_degrees = Vector3(0, 5, 0)
	controller._physics_process(1.0 / 60.0)
	assert_signal_emitted_with_parameters(EventBus, "player_jump_requested", ["sector_star_cob"])


func test_queued_route_jump_clears_on_target_change():
	var harness = _create_player_controller_harness(false, false)
	var agent = harness["agent"]
	var controller = harness["controller"]

	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		TEST_ROUTE_DIRECTION
	)
	controller._set_selected_target(route_target)
	controller._poll_docking_proximity()
	controller._handle_interact_input()

	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.location_id = "test_station"
	station.station_name = "Test Station"
	add_child_autofree(station)
	controller._set_selected_target(station)

	assert_eq(controller._queued_jump_target_id, "", "Changing targets should cancel any queued jump alignment.")
	assert_eq(controller._queued_jump_selection_token, "", "Changing targets should clear the queued jump validity token.")
	assert_eq(agent.idle_calls, 1, "Cancelling a queued jump via target change should clear the persistent jump-approach command.")


func test_queued_route_jump_clears_on_stop_override():
	var harness = _create_player_controller_harness(false, false)
	var agent = harness["agent"]
	var controller = harness["controller"]

	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		TEST_ROUTE_DIRECTION
	)
	controller._set_selected_target(route_target)
	controller._poll_docking_proximity()
	controller._handle_interact_input()
	controller._issue_stop_command()

	assert_eq(controller._queued_jump_target_id, "", "Explicit stop commands should cancel any queued jump alignment.")
	assert_eq(agent.stop_calls, 1, "Cancelling a queued jump via stop should still reuse the live stop command.")


func test_single_click_clears_selection_without_world_raycast_pick():
	var station = StaticBody.new()
	station.set_script(DockableStationScript)
	station.location_id = "test_station"
	station.station_name = "Test Station"
	add_child_autofree(station)

	var harness = _create_player_controller_harness()
	var controller = harness["controller"]
	watch_signals(EventBus)

	controller._set_selected_target(station)
	controller._target_under_cursor = station
	controller._handle_single_click(Vector2.ZERO)
	assert_eq(controller._selected_target, null, "Single-click fallback should now clear selection instead of picking the collider under the cursor.")
	assert_signal_emitted(EventBus, "player_target_deselected")


func test_jump_interact_ignores_input_while_transition_active():
	var transition_script = GDScript.new()
	transition_script.source_code = "extends Node\nfunc is_jump_transition_active():\n\treturn true\n"
	transition_script.reload()
	var transition_world_manager = Node.new()
	transition_world_manager.set_script(transition_script)
	add_child_autofree(transition_world_manager)
	GlobalRefs.world_manager = transition_world_manager

	var harness = _create_player_controller_harness(true, true)
	var agent = harness["agent"]
	var controller = harness["controller"]
	watch_signals(EventBus)

	var route_target = RouteTargetScript.new().configure(
		"sector_star_elace",
		"sector_star_cob",
		"Cob System",
		TEST_ROUTE_DIRECTION
	)
	controller._set_selected_target(route_target)
	controller._poll_docking_proximity()
	controller._handle_interact_input()

	assert_signal_not_emitted(EventBus, "player_jump_requested", "Jump input should be ignored while the world manager reports an active jump transition.")
	assert_eq(agent.align_calls.size(), 0, "Jump input should not queue new alignment while a jump transition is already active.")
	assert_eq(controller._queued_jump_target_id, "", "Jump input should not leave a queued jump behind while transition gating is active.")
	assert_true(controller._selected_target == route_target, "Ignoring input during a jump transition should not mutate the selected target.")


func _create_player_controller_harness(aligned: bool = true, rotation_stopped: bool = true) -> Dictionary:
	var agent_script = GDScript.new()
	agent_script.source_code = "extends RigidBody\nvar align_calls = []\nvar align_options = []\nvar idle_calls = 0\nvar stop_calls = 0\nfunc command_stop():\n\tstop_calls += 1\nfunc command_idle():\n\tidle_calls += 1\nfunc command_align_to(direction, apply_forward_thrust=false, forward_thrust_scale=1.0, persist_until_cleared=false):\n\talign_calls.append(direction)\n\talign_options.append([apply_forward_thrust, forward_thrust_scale, persist_until_cleared])\nfunc is_player():\n\treturn true\n"
	agent_script.reload()

	var movement_script = GDScript.new()
	movement_script.source_code = "extends Node\nvar thrust_throttle = 1.0\nvar aligned = true\nvar rotation_stopped = true\nfunc is_aligned_to(_target_direction):\n\treturn aligned\nfunc is_rotation_stopped():\n\treturn rotation_stopped\n"
	movement_script.reload()

	var agent = RigidBody.new()
	agent.name = "Player"
	agent.gravity_scale = 0.0
	agent.set_script(agent_script)
	agent.rotation_degrees = Vector3.ZERO if aligned else Vector3(0, 45, 0)

	var movement_system = Node.new()
	movement_system.name = "MovementSystem"
	movement_system.set_script(movement_script)
	movement_system.aligned = aligned
	movement_system.rotation_stopped = rotation_stopped
	agent.add_child(movement_system)

	var controller = Node.new()
	controller.set_script(PlayerControllerScript)
	controller.name = "PlayerInputHandler"
	agent.add_child(controller)

	add_child_autofree(agent)

	return {
		"agent": agent,
		"controller": controller,
		"movement_system": movement_system,
	}

