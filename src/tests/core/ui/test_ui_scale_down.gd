# Below x1.0 (large monitors) the HUD's and the main menu's buttons, icon-only ones too, shrink with
# the lettering, also when the scale changes while they are shown.

extends GutTest

var MainHUDScene = load("res://scenes/ui/hud/main_hud.tscn")
var MainMenuScene = load("res://scenes/ui/menus/main_menu.tscn")


func after_each():
	get_tree().paused = false  # The main menu pauses the game as it comes in
	UiScale.set_factor(1.0)
	Settings.reset_to_defaults()
	GlobalRefs.main_hud = null


func _sizes(nodes: Array) -> Array:
	var sizes := []
	for node in nodes:
		sizes.append(node.rect_size)
	return sizes


func test_hud_and_menu_buttons_shrink_below_one():
	var hud = MainHUDScene.instance()
	add_child_autofree(hud)
	var menu = MainMenuScene.instance()
	add_child_autofree(menu)
	menu.visible = true
	for i in range(3):
		yield(get_tree(), "idle_frame")
	var hud_buttons := []
	for path in ["ScreenControls/CenterLeftZone/ButtonMenu", "ScreenControls/CenterLeftZone/ButtonOverlayStellar", "ScreenControls/CenterRightZone/ButtonHideHud", "ScreenControls/CenterRightZone/ButtonCharacter", "ScreenControls/TemporaryToolZone/ButtonTool1"]:
		var node = hud.get_node_or_null(path)
		if node != null:
			hud_buttons.append(node)
	var menu_buttons: Array = menu.get_node("ScreenControls/MainButtonsHBoxContainer").get_children() + [menu.get_node("ScreenControls/ButtonClose")]
	var before := _sizes(hud_buttons + menu_buttons)
	Settings.set_option("ui_scale", 0.5)
	for i in range(3):
		yield(get_tree(), "idle_frame")
	var after := _sizes(hud_buttons + menu_buttons)
	var names := []
	for node in hud_buttons + menu_buttons:
		names.append(node.name)
	gut.p("before %s" % [before])
	gut.p("after  %s" % [after])
	gut.p("names  %s" % [names])
	for i in range(before.size()):
		assert_almost_eq(after[i].x, before[i].x * 0.5, 1.5, "Half as wide: " + names[i])
		assert_almost_eq(after[i].y, before[i].y * 0.5, 1.5, "Half as tall: " + names[i])
