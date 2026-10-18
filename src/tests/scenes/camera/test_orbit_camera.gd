# Tests for the orbit camera: FoV overrides, orbit orientation and particle toggling.

extends GutTest

const OrbitCameraScene = preload("res://scenes/prefabs/camera/orbit_camera.tscn")
const OrbitCameraScript = preload("res://src/scenes/camera/orbit_camera.gd")


func test_temporary_fov_override_takes_priority_over_zoom_controller_fov():
	var camera = OrbitCameraScript.new()
	add_child_autofree(camera)

	camera.apply_zoom_controller_fov(65.0)
	assert_eq(camera.fov, 65.0, "Without an override, zoom-controller FoV should drive the live camera FoV.")

	camera.set_temporary_fov_override(170.0)
	camera.apply_zoom_controller_fov(72.0)
	assert_eq(camera.fov, 170.0, "Temporary jump-transition overrides should take priority over zoom-controller FoV updates.")
	assert_eq(camera.get_zoom_controller_fov(), 72.0, "The base FoV should continue tracking zoom-controller updates while the override is active.")

	camera.clear_temporary_fov_override()
	assert_eq(camera.fov, 72.0, "Clearing the temporary override should restore the latest zoom-controller FoV.")


func test_set_orbit_forward_direction_updates_orbit_orientation():
	var camera = OrbitCameraScript.new()
	add_child_autofree(camera)

	camera.set_orbit_forward_direction(Vector3(1, 0, 0))

	assert_true(
		camera.get_orbit_forward_direction().is_equal_approx(Vector3(1, 0, 0)),
		"Orbit-camera jump preparation should be able to aim the camera along the destination route before input locking begins."
	)


func test_restore_orbit_from_transition_view_snaps_camera_to_transition_facing():
	var camera = OrbitCameraScript.new()
	add_child_autofree(camera)

	var player = Spatial.new()
	add_child_autofree(player)
	player.global_transform = Transform(Basis(), Vector3(120.0, 0.0, -40.0))

	camera.restore_orbit_from_transition_view(player, Vector3(1, 0, 0))

	assert_true(
		camera.get_orbit_forward_direction().is_equal_approx(Vector3(1, 0, 0)),
		"Transition restore should keep the gameplay orbit camera aligned to the jump rig's final forward direction."
	)
	assert_true(
		(player.global_transform.origin - camera.global_transform.origin).normalized().is_equal_approx(Vector3(1, 0, 0)),
		"Transition restore should snap the gameplay orbit camera behind the newly spawned player instead of resuming from stale pre-jump coordinates."
	)


func test_set_local_scene_particles_active_toggles_group_visibility_and_clears_emitters():
	var camera = OrbitCameraScene.instance()
	add_child_autofree(camera)

	var local_particles = camera.get_node("LocalSceneParticles")

	camera.set_local_scene_particles_active(false, true)

	assert_false(local_particles.visible, "Disabling local-scene particles should hide the dedicated gameplay particle group during jump transition pause.")
	for emitter in local_particles.get_children():
		assert_false(emitter.visible, "Disabling local-scene particles should hide each gameplay-camera emitter.")
		assert_false(emitter.emitting, "Disabling local-scene particles with clear_existing should leave every gameplay-camera emitter cleared and idle.")

	camera.set_local_scene_particles_active(true, true)

	assert_true(local_particles.visible, "Re-enabling local-scene particles should restore the gameplay particle group after the transition ends.")
	for emitter in local_particles.get_children():
		assert_true(emitter.visible, "Re-enabling local-scene particles should restore each emitter's visibility under the gameplay camera.")


func _make_zoom_target(radius: float) -> Spatial:
	var script = GDScript.new()
	script.source_code = "extends Spatial\nvar radius = 12.0\nfunc get_apparent_radius():\n\treturn radius\n"
	script.reload()
	var target = Spatial.new()
	target.set_script(script)
	target.radius = radius
	add_child_autofree(target)
	return target


func test_zoom_scales_with_apparent_radius_and_never_crosses_near_plane():
	var camera = OrbitCameraScene.instance()
	add_child_autofree(camera)
	for radius in [12.0, 40.0]:
		camera.set_target_node(_make_zoom_target(radius))
		var zoom = camera._zoom_controller
		camera.set_zoom_level(0.0)
		assert_true(zoom.current_distance - radius >= camera.near, "Hull stays beyond the near plane at full zoom (radius %s)." % radius)
		camera.set_zoom_level(1.0)
		assert_almost_eq(zoom.current_distance, radius * camera.max_distance_multiplier, 0.01, "Max distance scales with radius.")


func test_zooming_past_closest_distance_narrows_fov_instead():
	var camera = OrbitCameraScene.instance()
	add_child_autofree(camera)
	camera.set_target_node(_make_zoom_target(12.0))
	var zoom = camera._zoom_controller
	camera.set_zoom_level(camera.telephoto_zoom_fraction)
	var closest: float = zoom.current_distance
	assert_almost_eq(camera.fov, camera.min_fov_deg, 0.01)
	camera.set_zoom_level(0.0)
	assert_almost_eq(zoom.current_distance, closest, 0.001, "Telephoto keeps the closest distance.")
	assert_almost_eq(camera.fov, camera.telephoto_min_fov_deg, 0.01, "Full zoom reaches the narrowest FoV.")
	camera.set_zoom_level(1.0)
	assert_almost_eq(camera.fov, camera.max_fov_deg, 0.01)


func test_tracking_elevation_keeps_hull_below_sight_line_and_in_frame():
	var PositionController = load("res://src/scenes/camera/components/camera_position_controller.gd")
	for case in [[12.0, 27.0, 6.0], [12.0, 27.0, 25.0], [12.0, 60.0, 100.0]]:
		var radius: float = case[0]
		var distance: float = case[1]
		var fov: float = deg2rad(case[2])
		var elevation: float = PositionController.get_tracking_elevation(radius, distance, fov)
		var hull_angle: float = asin(radius / distance)
		var top_edge_below_centre: float = elevation - hull_angle
		assert_gt(top_edge_below_centre, 0.0, "Hull top edge is below the line of sight to the target %s." % [case])
		assert_lt(top_edge_below_centre, fov * 0.5, "Hull top edge is inside the frame %s." % [case])


func test_tracking_solver_puts_flat_hull_top_just_below_sight_line():
	var PositionController = load("res://src/scenes/camera/components/camera_position_controller.gd")
	var flat_hull = AABB(Vector3(-10, -2, -8.5), Vector3(20, 4, 17))
	var corners: Array = []
	for i in range(8):
		corners.append(flat_hull.get_endpoint(i))
	var to_target = Vector3(0, 0, -900)
	for case in [[27.0, 6.0], [27.0, 25.0], [60.0, 100.0]]:
		var half_fov: float = deg2rad(case[1]) * 0.5
		var margin: float = half_fov * Constants.CAMERA_TRACKING_TOP_EDGE_SHARE
		var elevation: float = PositionController.solve_tracking_elevation(corners, to_target, Vector3.UP, case[0], margin)
		var offset_dir = Vector3(0, 0, 1) * cos(elevation) + Vector3.UP * sin(elevation)
		var top: float = PositionController.get_hull_top_angle(corners, to_target, offset_dir, case[0], Vector3.UP)
		assert_almost_eq(top, -margin, 0.002, "Hull top edge sits at the set share of the lower half-frame %s." % [case])


func test_tracking_telephoto_backs_off_to_keep_ship_size_on_screen():
	var camera = OrbitCameraScene.instance()
	add_child_autofree(camera)
	camera.set_target_node(_make_zoom_target(12.0))
	var zoom = camera._zoom_controller
	camera.set_zoom_level(camera.telephoto_zoom_fraction)
	var base_size: float = zoom.get_tracking_distance() * tan(deg2rad(camera.fov) * 0.5)
	camera.set_zoom_level(0.0)
	assert_gt(zoom.get_tracking_distance(), zoom.current_distance, "Telephoto pulls the tracking camera back.")
	assert_almost_eq(zoom.get_tracking_distance() * tan(deg2rad(camera.fov) * 0.5), base_size, 0.01, "Frame height at the ship stays the same.")

