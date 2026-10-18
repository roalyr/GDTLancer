# Tests for WorldRendering (the 3D world in its own viewport at a share of the window's
# resolution) and ScreenSpace (HUD coordinates <-> that viewport's camera).

extends GutTest

const WorldRenderingScript = preload("res://src/scenes/game_world/world_rendering.gd")
const ScreenSpace = preload("res://src/core/ui/screen_space.gd")

var world_rendering: Node = null
var container: ViewportContainer = null
var viewport: Viewport = null


func before_each():
	var scene = Node.new()
	add_child_autofree(scene)
	container = ViewportContainer.new()
	container.name = "WorldViewContainer"
	container.stretch = true
	container.rect_size = Vector2(1600, 900)
	scene.add_child(container)
	viewport = Viewport.new()
	viewport.name = "WorldViewport"
	container.add_child(viewport)
	world_rendering = WorldRenderingScript.new()
	scene.add_child(world_rendering)


func test_cycles_full_half_quarter_and_back():
	assert_eq(world_rendering.cycle_downscale_factor(), 0.5)
	assert_eq(world_rendering.cycle_downscale_factor(), 0.25)
	assert_eq(world_rendering.cycle_downscale_factor(), 1.0)


func test_world_renders_at_that_share_of_the_window_and_the_window_does_not():
	var window_size: Vector2 = get_viewport().size
	world_rendering.set_downscale_factor(0.5)
	assert_eq(viewport.size, (OS.window_size * 0.5).floor())
	assert_eq(get_viewport().size, window_size, "The window (and the HUD in it) keeps its full resolution.")
	viewport.size = Vector2(100, 100)  # What the container does when resized
	world_rendering._process(0.016)
	assert_eq(viewport.size, (OS.window_size * 0.5).floor(), "Put back after a resize.")


func test_screen_points_map_through_the_reduced_viewport_and_back():
	viewport.size = Vector2(400, 225)  # A quarter of the container's 1600 x 900
	var camera = Camera.new()
	viewport.add_child(camera)
	camera.current = true
	var point := Vector3(3, 2, -20)
	var screen: Vector2 = ScreenSpace.world_to_screen(camera, point)
	assert_almost_eq(screen, camera.unproject_position(point) * 4.0, Vector2(0.01, 0.01), "Viewport pixels scale up to the screen.")
	var origin: Vector3 = ScreenSpace.ray_origin(camera, screen)
	var direction: Vector3 = ScreenSpace.ray_normal(camera, screen)
	var along: float = (point - origin).dot(direction)
	assert_almost_eq((origin + direction * along).distance_to(point), 0.0, 0.05, "A click there points back at the same spot.")
