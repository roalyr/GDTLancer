# Tests for PlayerControllerShip docking input.

extends "res://addons/gut/test.gd"

var PlayerControllerScript = load("res://src/modules/piloting/player_controller_ship.gd")


func before_each():
	GameState.reset_state()


func after_each():
	GameState.reset_state()


func test_dock_without_target_docks_at_current_sector():
	var controller = PlayerControllerScript.new()
	GameState.current_sector_id = "sector_star_elace"
	watch_signals(EventBus)

	controller._on_dock_button_pressed()

	assert_signal_emitted_with_parameters(EventBus, "player_docked", ["sector_star_elace"])
	controller.free()


func test_dock_without_target_or_sector_reports_failure():
	var controller = PlayerControllerScript.new()
	watch_signals(EventBus)

	controller._on_dock_button_pressed()

	assert_signal_not_emitted(EventBus, "player_docked")
	assert_signal_emitted(EventBus, "dock_action_feedback")
	controller.free()
