#
# PROJECT: GDTLancer
# MODULE: test_orbit_camera.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §6.1, §6.3; TRUTH_SIMULATION-GRAPH.md §3.2, §3.3
# LOG_REF: 2026-05-16 20:25:31
#

extends GutTest

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