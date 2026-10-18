# ScreenSpace: converts between the HUD's screen coordinates and a camera's own viewport.
# The camera renders in the world viewport (WorldRendering), at a share of the window's
# resolution, stretched by its ViewportContainer to fill the screen; the HUD is laid out at full
# resolution. A camera outside such a container (tests, tools) maps one to one.

extends Reference


# HUD position of a world point (Camera.unproject_position, scaled to the screen).
static func world_to_screen(camera: Camera, world_point: Vector3) -> Vector2:
	return camera.unproject_position(world_point) * _scale(camera)


static func ray_origin(camera: Camera, screen_point: Vector2) -> Vector3:
	return camera.project_ray_origin(screen_point / _scale(camera))


static func ray_normal(camera: Camera, screen_point: Vector2) -> Vector3:
	return camera.project_ray_normal(screen_point / _scale(camera))


# Screen units per camera-viewport pixel.
static func _scale(camera: Camera) -> Vector2:
	var viewport: Viewport = camera.get_viewport()
	var container = viewport.get_parent() if viewport != null else null
	if container is ViewportContainer and viewport.size.x > 0.0 and viewport.size.y > 0.0:
		return container.rect_size / viewport.size
	return Vector2.ONE
