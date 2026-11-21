# Tests for the HUD's SHIP and PILOT windows (InfoWindow: ShipWindow, PilotWindow), and saving on
# docking (Settings "autosave_on_dock").

extends GutTest

const AgentScript = preload("res://src/core/agents/agent.gd")
const ToolControllerScript = preload("res://src/core/agents/components/tool_controller.gd")
const PlayerControllerScript = preload("res://src/modules/piloting/player_controller_ship.gd")
const MainHUDScene = preload("res://scenes/ui/hud/main_hud.tscn")
const ShipWindowScene = preload("res://scenes/ui/menus/ship_window.tscn")
const PilotWindowScene = preload("res://scenes/ui/menus/pilot_window.tscn")

var _saved_tools: Dictionary = {}


func before_each():
	_saved_tools = TemplateDatabase.utility_tools
	var cannon = UtilityToolTemplate.new()
	cannon.template_id = "test_cannon"
	cannon.tool_name = "Test cannon"
	cannon.tool_type = "cannon"
	cannon.mount_size = "small"
	cannon.ammo = 20
	cannon.round_mass = 1.0
	TemplateDatabase.utility_tools = {"test_cannon": cannon}
	GameState.reset_state()
	GameState.player_bank = 1234


func after_each():
	TemplateDatabase.utility_tools = _saved_tools
	GameState.reset_state()
	GlobalRefs.player_agent_body = null
	GlobalRefs.main_hud = null
	Settings.reset_to_defaults()
	get_tree().paused = false


func _player_ship() -> RigidBody:
	var ship = ShipTemplate.new()
	ship.hull_integrity = 100
	ship.mass = 6000.0
	ship.linear_thrust = 500000.0
	ship.tool_slots_small = 2
	ship.module_slots = 1
	ship.equipped_tools = ["test_cannon"]
	var body = AgentScript.new()
	body.agent_type = "player"
	body.ship_template = ship
	add_child_autofree(body)
	var tools = ToolControllerScript.new()
	tools.name = "ToolController"
	body.add_child(tools)
	body._init_fit()
	body._init_hull_and_power()
	tools.load_tools_from_ship()
	body.cargo = {"ore": 3}
	return body


func _texts(window) -> String:
	var lines: Array = [window.get_node("Panel/Layout/Header/Title").text, window.get_node("Panel/Layout/Summary").text]
	var stats: Node = window.get_node_or_null("Panel/Layout/Stats")
	if stats != null and stats.visible:
		for grid in stats.get_children():
			for cell in grid.get_children():
				if not cell.is_queued_for_deletion():
					lines.append("%s %s" % [cell.get_node("Caption").text, cell.get_node("Value").text])
	for child in window.get_node("Panel/Layout/Scroll/List").get_children():
		if child is Label:
			lines.append(child.text)
		elif child.has_node("Row/Text/Name"):
			lines.append(child.get_node("Row/Text/Name").text + " | " + child.get_node("Row/Text/Detail").text)
	return PoolStringArray(lines).join("\n")


func test_the_hud_buttons_open_and_close_the_windows():
	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	yield(get_tree(), "idle_frame")
	hud.get_node("ScreenControls/CenterRightZone/ButtonShip").emit_signal("pressed")
	assert_true(hud.ship_window.visible, "SHIP opens the ship window")
	assert_true(get_tree().paused, "and pauses the game")
	hud.ship_window.get_node("Panel/Layout/Header/ButtonClose").emit_signal("pressed")
	assert_false(hud.ship_window.visible, "CLOSE shuts it")
	assert_false(get_tree().paused, "and the game goes on.")
	hud.get_node("ScreenControls/CenterRightZone/ButtonCharacter").emit_signal("pressed")
	assert_true(hud.pilot_window.visible, "PILOT opens the pilot window,")
	hud.get_node("ScreenControls/CenterRightZone/ButtonCharacter").emit_signal("pressed")
	assert_false(hud.pilot_window.visible, "and pressing it again shuts it.")


func test_ship_window_shows_the_fit_rounds_and_hold():
	var ship = _player_ship()
	GlobalRefs.player_agent_body = ship
	var window = ShipWindowScene.instance()
	add_child_autofree(window)
	window.open()
	var text: String = _texts(window)
	assert_string_contains(text, "WORTH")
	assert_string_contains(text, "TOP SPEED", "The stats, as docked")
	assert_string_contains(text, "SMALL SLOT: TEST CANNON", "Each slot and its part")
	assert_string_contains(text, "SMALL SLOT: EMPTY")
	assert_string_contains(text, "%d / %d rounds" % [ship.get_node("ToolController").get_ammo(0), ship.get_node("ToolController").get_capacity(0)], "A magazine's rounds")
	assert_string_contains(text, "ORE  X3", "The hold")
	window.close()


func test_ship_window_closes_on_docking():
	GlobalRefs.player_agent_body = _player_ship()
	var window = ShipWindowScene.instance()
	add_child_autofree(window)
	window.open()
	EventBus.emit_signal("player_docked", "home")
	assert_false(window.visible, "The docking view takes over")
	assert_false(get_tree().paused)


func test_pilot_window_shows_bank_standing_bounties_and_patrol_time():
	var ship = _player_ship()
	GlobalRefs.player_agent_body = ship
	GameState.player_standing = {"violet": -1.0, "verdant": 1.0}
	GameState.player_bounties = {"violet": 500}
	ship.set_meta("patrol_time", {"verdant": 1800.0})
	var window = PilotWindowScene.instance()
	add_child_autofree(window)
	window.open()
	var text: String = _texts(window)
	assert_string_contains(text, "BANK 1234 WP")
	assert_string_contains(text, "VIOLET  HOSTILE", "Each faction's standing, by its word")
	assert_string_contains(text, "VERDANT  FRIENDLY")
	assert_string_contains(text, "At war with Verdant", "and whom it is at war with")
	assert_string_contains(text, "Keeps no standing", "A faction without standing says so")
	assert_string_contains(text, "VIOLET  500 WP", "Bounties on the player")
	assert_string_contains(text, "VERDANT PATROL  30 MIN", "Patrol time owed")
	window.close()


func test_saves_on_docking_unless_switched_off():
	var path: String = GameStateManager._get_save_path(0)
	var dir = Directory.new()
	if dir.file_exists(path):
		dir.remove(path)
	var controller = PlayerControllerScript.new()
	GameState.player_docked_at = "home"
	Settings.set_option("autosave_on_dock", false)
	controller._autosave_on_dock()
	assert_false(dir.file_exists(path), "Switched off: no save")
	Settings.set_option("autosave_on_dock", true)
	controller._autosave_on_dock()
	assert_true(dir.file_exists(path), "On (the default): saved on docking")
	for leftover in [path, path + GameStateManager.SAVE_BACKUP_EXT]:
		if dir.file_exists(leftover):
			dir.remove(leftover)
	controller.free()
