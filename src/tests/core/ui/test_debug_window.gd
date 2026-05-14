##
## PROJECT: GDTLancer
## MODULE: test_debug_window.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §6; TACTICAL_TODO.md TASK_1
## LOG_REF: 2026-05-14 02:59:12
##

extends "res://addons/gut/test.gd"

var MainHUDScene = load("res://scenes/ui/hud/main_hud.tscn")
var DebugWindowScene = load("res://scenes/ui/menus/debug_window.tscn")
var MainMenuScene = load("res://scenes/ui/menus/main_menu.tscn")
var StationMenuScene = load("res://scenes/ui/menus/station_menu/StationMenu.tscn")


func after_each() -> void:
	get_tree().paused = false
	GlobalRefs.main_hud = null
	GlobalRefs.main_camera = null
	GlobalRefs.player_agent_body = null
	GlobalRefs.current_zone = null
	GameState.current_sector_id = ""
	GameState.player_docked_at = ""
	GameState.player_character_uid = ""
	GameState.locations.clear()


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
	GameState.current_sector_id = "sector_system_elace"

	var main_menu = MainMenuScene.instance()
	add_child_autofree(main_menu)
	main_menu._show_menu()

	assert_true(main_menu.visible, "MainMenu should be visible after showing the live-session menu.")
	assert_true(get_tree().paused, "Showing the main menu during a live session should pause gameplay.")

	var close_button: BaseButton = main_menu.get_node("ScreenControls/ButtonClose")
	close_button.emit_signal("pressed")

	assert_false(main_menu.visible, "MainMenu close should dismiss the menu during a live session.")
	assert_false(get_tree().paused, "MainMenu close should unpause gameplay during a live session.")


func test_station_menu_close_hides_without_undocking_and_reopens() -> void:
	var station_menu = StationMenuScene.instance()
	add_child_autofree(station_menu)
	GameState.player_docked_at = "station_beta"
	yield(get_tree(), "idle_frame")

	station_menu._on_player_docked("station_beta")
	assert_true(station_menu.visible, "Docking should open the station menu.")

	var close_button: BaseButton = station_menu.get_node("Panel/VBoxContainer/HeaderRow/BtnClose")
	close_button.emit_signal("pressed")
	yield(get_tree(), "idle_frame")

	assert_false(station_menu.visible, "Closing the station menu should hide it.")
	assert_eq(GameState.player_docked_at, "station_beta", "Closing the station menu must not undock the player.")

	station_menu.open_for_current_dock()
	yield(get_tree(), "idle_frame")
	assert_true(station_menu.visible, "StationMenu should reopen for the current docked location.")


func test_main_hud_dock_button_reopens_station_menu_while_docked() -> void:
	var root = Node.new()
	add_child_autofree(root)

	var camera = Camera.new()
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var hud = MainHUDScene.instance()
	root.add_child(hud)
	yield(get_tree(), "idle_frame")

	GameState.player_docked_at = "station_beta"
	watch_signals(EventBus)

	hud._on_ButtonDock_pressed()
	yield(get_tree(), "idle_frame")

	assert_true(hud._station_menu_instance.visible, "MainHUD dock button should reopen the station menu while already docked.")
	assert_signal_not_emitted(EventBus, "player_dock_pressed", "Reopening the station menu while docked should not emit a fresh docking request.")