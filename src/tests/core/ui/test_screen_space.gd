# Tests for ScreenSpace.view_distance: camera distance scaled by the zoom, for distance-gated detail.

extends GutTest

const ScreenSpace = preload("res://src/core/ui/screen_space.gd")


func _camera(fov: float) -> Camera:
	var camera = Camera.new()
	camera.fov = fov
	add_child_autofree(camera)
	return camera


func test_reference_fov_gives_the_plain_distance():
	var camera = _camera(Constants.VIEW_REFERENCE_FOV_DEG)
	assert_almost_eq(ScreenSpace.view_distance(camera, Vector3(0, 0, -1000)), 1000.0, 0.01)


func test_zoomed_in_far_objects_count_as_near():
	var camera = _camera(6.0)  # Constants.CAMERA_TELEPHOTO_MIN_FOV_DEG
	var expected: float = 15000.0 * tan(deg2rad(3.0)) / tan(deg2rad(Constants.VIEW_REFERENCE_FOV_DEG * 0.5))
	assert_almost_eq(ScreenSpace.view_distance(camera, Vector3(0, 0, -15000)), expected, 0.5)
	assert_lt(expected, Constants.HULL_SCAR_VISIBLE_DISTANCE, "At full zoom a ship 15 km out shows its scars.")


func test_zoomed_out_near_objects_count_as_farther():
	var camera = _camera(100.0)
	assert_gt(ScreenSpace.view_distance(camera, Vector3(0, 0, -1000)), 1000.0)
