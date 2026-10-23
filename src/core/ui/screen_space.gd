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


# How far `point` would be from `camera` at Constants.VIEW_REFERENCE_FOV_DEG to look the size it
# looks now: the camera distance scaled by the zoom (field of view). Distance-gated detail (levels
# of detail, scars, effects) uses this, so zooming in on a far object shows it in full detail.
static func view_distance(camera: Camera, point: Vector3) -> float:
	var distance: float = camera.global_transform.origin.distance_to(point)
	if camera.projection != Camera.PROJECTION_PERSPECTIVE:
		return distance
	return distance * tan(deg2rad(camera.fov) * 0.5) / tan(deg2rad(Constants.VIEW_REFERENCE_FOV_DEG) * 0.5)


# Screen units per camera-viewport pixel.
static func _scale(camera: Camera) -> Vector2:
	var viewport: Viewport = camera.get_viewport()
	var container = viewport.get_parent() if viewport != null else null
	if container is ViewportContainer and viewport.size.x > 0.0 and viewport.size.y > 0.0:
		return container.rect_size / viewport.size
	return Vector2.ONE
