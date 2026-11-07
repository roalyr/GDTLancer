# Tests for the Options window and Settings: it pauses while open, each button steps its option,
# and options reach who applies them (HUD look, hit effects).

extends GutTest

const OptionsScene = preload("res://scenes/ui/menus/options_window.tscn")
const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")


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
	assert_eq(window.get_node("Panel/Layout/ButtonParticles").text, "PARTICLES: OFF")
	window.step("render_scale")
	assert_eq(Settings.get_option("render_scale"), Constants.RENDER_SCALE_STEPS[1])
	assert_eq(window.get_node("Panel/Layout/ButtonRenderScale").text, "RENDER SCALE: X0.5")
	window.step("hud_preset")
	assert_eq(Settings.get_option("hud_preset"), Constants.HUD_PRESET_ORDER[1])


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
