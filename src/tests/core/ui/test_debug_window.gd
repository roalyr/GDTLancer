# Tests for the debug window, main menu close and HUD dock button.

extends "res://addons/gut/test.gd"

var MainHUDScene = load("res://scenes/ui/hud/main_hud.tscn")
var DebugWindowScene = load("res://scenes/ui/menus/debug_window.tscn")
var MainMenuScene = load("res://scenes/ui/menus/main_menu.tscn")


func after_each() -> void:
	get_tree().paused = false
	GlobalRefs.main_hud = null
	GlobalRefs.main_camera = null
	GlobalRefs.player_agent_body = null
	GlobalRefs.current_zone = null
	GameState.current_sector_id = ""
	GameState.player_docked_at = ""


func test_button_debug_toggles_debug_window_sibling() -> void:
	var root = Node.new()
	add_child_autofree(root)

	var camera = Camera.new()
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var debug_window = DebugWindowScene.instance()
	root.add_child(debug_window)

	var hud = MainHUDScene.instance()
	root.add_child(hud)
	yield(get_tree(), "idle_frame")

	var button_debug: TextureButton = hud.get_node("ScreenControls/CenterLeftZone/ButtonDebug")
	assert_false(debug_window.visible, "DebugWindow should start hidden.")

	button_debug.emit_signal("pressed")
	yield(get_tree(), "idle_frame")
	assert_true(debug_window.visible, "MainHUD ButtonDebug should open the dedicated DebugWindow.")

	button_debug.emit_signal("pressed")
	yield(get_tree(), "idle_frame")
	assert_false(debug_window.visible, "Pressing ButtonDebug again should hide the DebugWindow.")


func test_main_menu_close_hides_and_unpauses_live_session() -> void:
	GameState.current_sector_id = "sector_star_elace"

	var main_menu = MainMenuScene.instance()
	add_child_autofree(main_menu)
	main_menu._show_menu()

	assert_true(main_menu.visible, "MainMenu should be visible after showing the live-session menu.")
	assert_true(get_tree().paused, "Showing the main menu during a live session should pause gameplay.")

	var close_button: BaseButton = main_menu.get_node("ScreenControls/ButtonClose")
	close_button.emit_signal("pressed")

	assert_false(main_menu.visible, "MainMenu close should dismiss the menu during a live session.")
	assert_false(get_tree().paused, "MainMenu close should unpause gameplay during a live session.")


func test_main_hud_dock_button_requests_dock_from_player_controller() -> void:
	var root = Node.new()
	add_child_autofree(root)

	var camera = Camera.new()
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var hud = MainHUDScene.instance()
	root.add_child(hud)
	yield(get_tree(), "idle_frame")

	GameState.player_docked_at = "sector_star_elace"
	watch_signals(EventBus)

	hud._on_ButtonDock_pressed()
	yield(get_tree(), "idle_frame")

	assert_signal_emitted(EventBus, "player_dock_pressed", "MainHUD dock button should route docking through the player controller.")
