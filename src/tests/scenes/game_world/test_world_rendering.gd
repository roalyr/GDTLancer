# Tests for WorldRendering's render scale: the viewport renders at a share of the window.

extends GutTest

const WorldRenderingScript = preload("res://src/scenes/game_world/world_rendering.gd")

var world_rendering: Node = null


func before_each():
	world_rendering = WorldRenderingScript.new()
	add_child_autofree(world_rendering)


func after_each():
	world_rendering.set_downscale_factor(1.0)  # Never leave the test runner's window scaled


func test_cycles_full_half_quarter_and_back():
	assert_eq(world_rendering.cycle_downscale_factor(), 0.5)
	assert_eq(world_rendering.cycle_downscale_factor(), 0.25)
	assert_eq(world_rendering.cycle_downscale_factor(), 1.0)


func test_renders_at_that_share_of_the_window():
	world_rendering.set_downscale_factor(0.5)
	assert_eq(get_viewport().size, (OS.window_size * 0.5).floor())
	world_rendering.set_downscale_factor(1.0)
	assert_eq(get_viewport().size, OS.window_size)
