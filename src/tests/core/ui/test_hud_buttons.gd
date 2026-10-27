# Tests for the HUD debug button (the readout and its map), main menu close and HUD dock button.

extends "res://addons/gut/test.gd"

var MainHUDScene = load("res://scenes/ui/hud/main_hud.tscn")
var MainMenuScene = load("res://scenes/ui/menus/main_menu.tscn")


func after_each() -> void:
	get_tree().paused = false
	GlobalRefs.main_hud = null
	GlobalRefs.main_camera = null
	GlobalRefs.player_agent_body = null
	GlobalRefs.current_zone = null
	GameState.current_sector_id = ""
	GameState.player_docked_at = ""


func test_button_debug_toggles_the_readout() -> void:
	var root = Node.new()
	add_child_autofree(root)

	var camera = Camera.new()
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var hud = MainHUDScene.instance()
	root.add_child(hud)
	yield(get_tree(), "idle_frame")

	var button_debug: TextureButton = hud.get_node("ScreenControls/CenterLeftZone/ButtonDebug")
	assert_false(hud.debug_overlay.visible, "The debug overlay starts hidden.")

	button_debug.emit_signal("pressed")
	assert_true(hud.debug_overlay.visible, "The debug button shows it")
	for block in ["LeftColumn/LabelShip", "LeftColumn/LabelTools", "RightColumn/LabelTarget", "RightColumn/LabelWorld", "LabelRender", "LabelFrame"]:
		assert_ne(hud.debug_overlay.get_node(block).text, "", "Every block is filled: " + block)

	button_debug.emit_signal("pressed")
	assert_false(hud.debug_overlay.visible, "and hides it again.")


func test_debug_overlay_opens_the_debug_map() -> void:
	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")
	GameState.current_sector_id = Constants.INITIAL_SECTOR_ID

	assert_false(hud.debug_map.visible, "The debug map starts closed.")
	hud.get_node("ScreenControls/DebugOverlay/RightColumn/ButtonDebugMap").emit_signal("pressed")
	assert_true(hud.debug_map.visible, "The overlay's map button opens it")
	var content: Spatial = hud.debug_map.get_node("Panel/Layout/MapArea/ViewportContainer/Viewport/MapContent")
	for sector_id in TemplateDatabase.locations:
		var marker: Spatial = content.get_node("Sector_" + sector_id)
		assert_eq(marker.translation, TemplateDatabase.locations[sector_id].global_position - TemplateDatabase.locations[Constants.INITIAL_SECTOR_ID].global_position,
			"Each sector sits at its global position, centred on the current one: " + sector_id)
	assert_not_null(content.get_node_or_null("Routes"), "with the jump routes between them.")

	hud.debug_map.get_node("Panel/Layout/Header/ButtonClose").emit_signal("pressed")
	assert_false(hud.debug_map.visible, "Close shuts it")
	yield(get_tree(), "idle_frame")
	assert_eq(content.get_child_count(), 0, "and clears the map.")


func test_main_menu_close_hides_and_unpauses_live_session() -> void:
	GameState.current_sector_id = "sector_elace"

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

	GameState.player_docked_at = ""
	watch_signals(EventBus)

	hud._on_ButtonDock_pressed()
	yield(get_tree(), "idle_frame")

	assert_signal_emitted(EventBus, "player_dock_pressed", "MainHUD dock button should route docking through the player controller.")

	GameState.player_docked_at = "station_elace_home"
	hud._update_dock_button_label()
	assert_eq(hud.label_button_dock.text, "UNDOCK", "Docked: the button undocks (mouse-only players need a way out).")
	hud._on_ButtonDock_pressed()
	assert_signal_emitted(EventBus, "player_undocked")
