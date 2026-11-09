# Tests for FrameGovernor (Settings "slow_down_on_lag"): long frames slow the game down so a frame
# runs at most LAG_MAX_STEPS physics steps, each still 1/60 s of game time.

extends GutTest

const FrameGovernor = preload("res://src/core/utils/frame_governor.gd")

var _saved = []


func before_each():
	_saved = [Engine.time_scale, Engine.iterations_per_second, Settings.get_option("slow_down_on_lag")]


func after_each():
	Engine.time_scale = _saved[0]
	Engine.iterations_per_second = _saved[1]
	Settings.set_option("slow_down_on_lag", _saved[2])


func test_the_speed_that_keeps_a_frame_to_its_steps():
	assert_eq(FrameGovernor.wanted_speed(1.0 / 60.0), 1.0, "A step a frame: full speed")
	assert_eq(FrameGovernor.wanted_speed(Constants.LAG_MAX_STEPS / 60.0), 1.0, "Up to the most steps: full speed")
	assert_almost_eq(FrameGovernor.wanted_speed(0.1), Constants.LAG_MAX_STEPS / 6.0, 0.001, "10 FPS: slowed so it runs only that many")
	assert_eq(FrameGovernor.wanted_speed(10.0), Constants.LAG_MIN_SPEED, "Never below the floor")


func test_slowed_each_step_stays_a_sixtieth_of_game_time():
	Settings.set_option("slow_down_on_lag", true)
	var governor = FrameGovernor.new()
	add_child_autofree(governor)
	governor._set_speed(0.5)
	assert_eq(Engine.iterations_per_second, 30, "Half the steps a second")
	assert_almost_eq(Engine.time_scale / Engine.iterations_per_second, 1.0 / 60.0, 0.00001, "each 1/60 s of game time")
	assert_eq(governor.speed, 0.5)
	governor._set_speed(0.41)
	assert_almost_eq(Engine.time_scale * 60.0, float(Engine.iterations_per_second), 0.0001, "Speed matched to whole steps")


func test_turned_off_it_puts_the_engine_back_and_otherwise_leaves_it_alone():
	Settings.set_option("slow_down_on_lag", true)
	var governor = FrameGovernor.new()
	add_child_autofree(governor)
	governor._set_speed(0.5)
	Settings.set_option("slow_down_on_lag", false)
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(Engine.iterations_per_second, 60)
	Engine.iterations_per_second = 480  # As the evolution sim sets it
	Engine.time_scale = 8.0
	governor._process(0.0)
	assert_eq(Engine.time_scale, 8.0, "Off: not its business")
	assert_eq(Engine.iterations_per_second, 480)
