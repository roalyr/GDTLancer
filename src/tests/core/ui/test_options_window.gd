# Tests for the Options window and Settings: it pauses while open, each button steps its option,
# and options reach who applies them (HUD look, hit effects).

extends GutTest

const OptionsScene = preload("res://scenes/ui/menus/options_window.tscn")
const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")
const TabLook = preload("res://src/core/ui/helpers/tab_look.gd")


func after_each():
	Settings.reset_to_defaults()
	get_tree().paused = false


func test_it_pauses_while_open_and_puts_the_pause_back():
	var window = OptionsScene.instance()
	add_child_autofree(window)
	window.open()
	assert_true(window.visible)
	assert_true(get_tree().paused, "Open: paused")
	window.close()
	assert_false(get_tree().paused, "Closed: as it was")
	get_tree().paused = true
	window.open()
	window.close()
	assert_true(get_tree().paused, "Opened from a paused menu: still paused")


func test_buttons_step_their_options():
	var window = OptionsScene.instance()
	add_child_autofree(window)
	window.step("particles")
	assert_false(Settings.get_option("particles"))
	assert_eq(window.row_text("ButtonParticles"), "PARTICLES: OFF")
	var value: Label = window.get_node("Panel/Overflow/Layout/Body/Scroll/List/ButtonParticles/Row/Value")
	assert_eq(value.theme_type_variation, "LargeOffLabel", "OFF reads grey")
	window.step("particles")
	assert_eq(value.theme_type_variation, "LargeValueLabel", "and ON yellow")
	window.step("render_scale")
	assert_eq(Settings.get_option("render_scale"), Constants.RENDER_SCALE_STEPS[1])
	assert_eq(window.row_text("ButtonRenderScale"), "RENDER SCALE: X0.75")
	window.step("hud_preset")
	assert_eq(Settings.get_option("hud_preset"), Constants.HUD_PRESET_ORDER[1])
	window.step("dynamic_lights")
	assert_eq(Settings.get_option("dynamic_lights"), "few")
	assert_eq(window.row_text("ButtonDynamicLights"), "DYNAMIC LIGHTS: FEW")


func test_every_option_is_in_one_tab_and_tabs_show_their_own():
	var window = OptionsScene.instance()
	add_child_autofree(window)
	var seen := {}
	for category in window.CATEGORIES:
		for name in category[1]:
			assert_false(seen.has(name), name + " is in one tab only")
			seen[name] = true
	for name in window.OPTIONS:
		assert_true(seen.has(name), name + " has a tab")
	window.show_tab("sound")
	assert_true(window.get_node("Panel/Overflow/Layout/Body/Scroll/List/ButtonMusic").visible, "SOUND shows the music")
	assert_false(window.get_node("Panel/Overflow/Layout/Body/Scroll/List/ButtonParticles").visible, "and not the particles")
	assert_eq(window.get_node("Panel/Overflow/Layout/Tabs/Tab_sound").text, "[SOUND]")
	assert_eq(window.row_text("ButtonHudLook"), "HUD LOOK: NORMAL", "The standard look reads NORMAL")


func test_hud_look_greys_the_marks():
	var red: Color = TargetKinds.side_color("hostile")
	assert_eq(red, Constants.COLOR_UI_TARGET_HOSTILE, "Standard: as they are")
	Settings.set_option("hud_preset", "dim")
	var dim: Color = TargetKinds.side_color("hostile")
	assert_true(dim.r - dim.g < red.r - red.g, "Less saturated")


func test_hit_effects_off_hides_scars_and_makes_none():
	var AgentScript = load("res://src/core/agents/agent.gd")
	var ship = AgentScript.new()
	add_child_autofree(ship)
	var scars = Spatial.new()
	ship._hull_scars = scars
	add_child_autofree(scars)
	ship.set_hit_effects(false)
	assert_false(scars.visible)
	ship.set_hit_effects(true)
	assert_true(scars.visible)


func test_settings_never_touch_the_file_in_tests():
	Settings.set_option("particles", false)
	assert_false(Settings._persist, "Tests run on the defaults and write nothing")


func test_volumes_step_down_to_off_and_set_their_buses():
	var AudioBuses = load("res://src/core/sound/audio_buses.gd")
	var window = OptionsScene.instance()
	add_child_autofree(window)
	assert_eq(window.row_text("ButtonEffects"), "SOUND EFFECTS: 100%")
	window.step("effects")
	assert_eq(Settings.get_option("effects"), Constants.VOLUME_STEPS[1])
	assert_eq(window.row_text("ButtonEffects"), "SOUND EFFECTS: 75%")
	Settings.set_option("music", 0.0)
	assert_eq(window.row_text("ButtonMusic"), "MUSIC: OFF")
	AudioBuses.apply()
	var music: int = AudioServer.get_bus_index("Music")
	var effects: int = AudioServer.get_bus_index("Effects")
	assert_true(music > 0 and effects > 0, "The game's buses (default_bus_layout.tres)")
	assert_true(AudioServer.is_bus_mute(music), "Music at 0: muted")
	assert_false(AudioServer.is_bus_mute(effects))
	assert_almost_eq(AudioServer.get_bus_volume_db(effects), linear2db(0.75), 0.01)
	Settings.reset_to_defaults()
	AudioBuses.apply()
	assert_false(AudioServer.is_bus_mute(music), "Back to full")


func test_the_right_half_tells_of_the_row_tapped():
	var window = OptionsScene.instance()
	add_child_autofree(window)
	var info: Node = window.get_node("Panel/Overflow/Layout/Body/Info")
	assert_eq(info.get_node("Title").text, "GAME", "A tab's own words first")
	window.step("autolevel")
	assert_eq(info.get_node("Title").text, "AUTOLEVEL")
	assert_eq(info.get_node("Text").text, Strings.t("options.autolevel.about"))
	assert_null(info.get_node_or_null("Value"), "Its value is on its row only")
	assert_eq(window.row_text("ButtonAutolevel"), "AUTOLEVEL: OFF")


func test_the_language_switches_every_word_at_once():
	var window = OptionsScene.instance()
	add_child_autofree(window)
	Settings.set_option("language", "uk")
	assert_eq(window.get_node("Panel/Overflow/Layout/Header/Title").text, "НАЛАШТУВАННЯ")
	assert_eq(window.row_text("ButtonParticles"), "ЧАСТИНКИ: УВІМК")
	Settings.set_option("language", "en")
	assert_eq(window.row_text("ButtonParticles"), "PARTICLES: ON")


# Every window marks its open tab the one way (TabLook): its title in brackets and the open look,
# whose amber is the theme's.
func test_the_open_tab_is_bracketed_and_amber():
	var window = OptionsScene.instance()
	add_child_autofree(window)
	window.show_tab("sound")
	var tabs: Node = window.get_node("Panel/Overflow/Layout/Tabs")
	var open: Button = tabs.get_node("Tab_sound")
	var shut: Button = tabs.get_node("Tab_game")
	assert_eq(open.text, "[SOUND]")
	assert_eq(open.theme_type_variation, "LargeTabButtonOpen")
	assert_eq(shut.text, "GAME")
	assert_eq(shut.theme_type_variation, "LargeTabButton")
	assert_eq(open.get_color("font_color"), Color(1, 0.82, 0.45, 1), "Amber, from the theme")
	assert_eq(shut.get_color("font_color"), Color(1, 1, 1, 1))
	var button := Button.new()
	add_child_autofree(button)
	button.theme_type_variation = "TabButton"
	TabLook.show(button, "MAP", true)
	TabLook.show(button, "MAP", true)
	assert_eq(button.theme_type_variation, "TabButtonOpen", "Shown open twice: still one suffix")
	TabLook.show(button, "MAP", false)
	assert_eq([button.text, button.theme_type_variation], ["MAP", "TabButton"])
