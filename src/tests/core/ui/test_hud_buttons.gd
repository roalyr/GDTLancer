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


class FakeTools extends Node:
	var count := 11

	func get_tool_count() -> int:
		return count

	func get_tool(_index: int) -> Resource:
		var laser = UtilityToolTemplate.new()
		laser.tool_name = "Laser"
		return laser

	func is_active(_index: int) -> bool:
		return false


func test_every_tool_gets_a_button_in_rows_of_eight() -> void:
	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")
	var player := Spatial.new()
	add_child_autofree(player)
	var tools := FakeTools.new()
	tools.name = "ToolController"
	player.add_child(tools)
	GlobalRefs.player_agent_body = player
	hud._update_tool_buttons()
	hud.button_lance.visible = false
	hud.button_afterburner.visible = false
	hud._layout_tool_rows()
	GlobalRefs.player_agent_body = null  # Before the HUD's next frame asks the fake ship for more
	assert_eq(hud.tool_buttons.size(), 11, "A button per tool, however many")
	var zone: Control = hud.get_node("ScreenControls/TemporaryToolZone")
	var upper: Control = hud.get_node("ScreenControls/TemporaryToolRow2")
	assert_eq(upper.get_child_count(), 8, "The first eight in the row above")
	assert_eq(hud.tool_buttons[0].get_parent(), upper)
	assert_eq(hud.tool_buttons[10].get_parent(), zone, "the rest in the bottom row")
	watch_signals(EventBus)
	hud.tool_buttons[10].emit_signal("pressed")
	assert_signal_emitted_with_parameters(EventBus, "player_tool_pressed", [10])  # The eleventh button works the eleventh tool
	tools.count = 2
	GlobalRefs.player_agent_body = player
	hud._update_tool_buttons()
	hud._layout_tool_rows()
	GlobalRefs.player_agent_body = null
	assert_eq(hud.tool_buttons[0].get_parent(), zone, "Back to one row")


func test_ship_info_shows_the_power_flow() -> void:
	var player := Spatial.new()
	var script := GDScript.new()
	script.source_code = "extends Spatial\nvar power_regen = 10.0\nvar power_max = 100.0\nvar fit_stats = {\"damper_mass\": 100.0, \"afterburner_thrust\": 100000.0}\n"
	script.reload()
	player.set_script(script)
	add_child_autofree(player)
	var tools := FakeTools.new()
	tools.count = 2
	tools.name = "ToolController"
	player.add_child(tools)
	var text: String = load("res://src/core/ui/main_hud/main_hud.gd").describe_power_flow(player)
	var laser = UtilityToolTemplate.new()
	var draw: float = 2.0 * laser.power_per_cycle / laser.cycle_time
	assert_string_contains(text, "REACTOR +%.1f/s" % (10.0 + Constants.LAW_DAMPER_POWER_PER_KG * 100.0))
	assert_string_contains(text, "DAMPER -%.1f/s" % (Constants.LAW_DAMPER_POWER_PER_KG * 100.0))
	assert_string_contains(text, "TOOLS ON -%.1f/s" % draw)
	assert_string_contains(text, "NET -%.1f/s" % (draw - 10.0))
	assert_string_contains(text, "AFTERBURNER -%.1f/s" % (100.0 * Constants.LAW_AFTERBURNER_POWER_PER_KN))


func test_docking_view_shows_the_power_flow_too() -> void:
	var ship := Spatial.new()
	var script := GDScript.new()
	script.source_code = "extends Spatial\nvar power_regen = 10.0\nvar power_max = 100.0\nvar mass = 3000.0\nvar fit_stats = {\"hull\": 100.0, \"power_capacity\": 100.0, \"power_regen\": 10.0, \"cargo_capacity\": 10.0, \"linear_thrust\": 300000.0, \"signature\": 2000.0, \"sensor_strength\": 1.0}\n"
	script.reload()
	ship.set_script(script)
	add_child_autofree(ship)
	var tools := FakeTools.new()
	tools.count = 1
	tools.name = "ToolController"
	ship.add_child(tools)
	var text: String = load("res://src/core/ui/fitting_window/fitting_window.gd").describe_stats(ship)
	assert_string_contains(text, "POWER FLOW   REACTOR +10.0/s   TOOLS ON -")


