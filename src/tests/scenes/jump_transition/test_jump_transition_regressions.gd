#
# PROJECT: GDTLancer
# MODULE: test_jump_transition_regressions.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §2, §6.3, §7; TRUTH_DOCS_CanvasItem_Godot_3.6.md §Render modes; TRUTH_DOCS_Particle shaders_Godot_3.6.md note plus §Render modes; TRUTH_SIMULATION-GRAPH.md §1
# LOG_REF: 2026-05-16 23:40:29
#

extends GutTest

const WorldManagerScript = preload("res://src/scenes/game_world/world_manager.gd")
const JumpTransitionRigScene = preload("res://scenes/prefabs/navigation/jump_transition_rig.tscn")

var _original_mouse_mode: int = Input.MOUSE_MODE_VISIBLE


func before_each():
	_original_mouse_mode = Input.get_mouse_mode()
	GameState.world_topology = {
		Constants.INITIAL_SECTOR_ID: {"connections": ["station_beta"]},
		"station_beta": {"connections": [Constants.INITIAL_SECTOR_ID]},
	}
	TemplateDatabase.locations = {
		Constants.INITIAL_SECTOR_ID: {"global_position": Vector3(1200, 50, -300)},
		"station_beta": {"global_position": Vector3(2200, 50, -300)},
	}


func after_each():
	Input.set_mouse_mode(_original_mouse_mode)
	GameState.world_topology.clear()
	TemplateDatabase.locations.clear()
	GlobalRefs.main_camera = null
	GlobalRefs.player_agent_body = null


func test_world_manager_unlock_restores_previous_mouse_capture_state():
	var world_manager = WorldManagerScript.new()
	add_child_autofree(world_manager)

	var camera_script = GDScript.new()
	camera_script.source_code = "extends Node\nvar rotation_input_calls = []\nvar rotating_calls = []\nfunc set_rotation_input_active(is_active):\n\trotation_input_calls.append(is_active)\nfunc set_is_rotating(rotating):\n\trotating_calls.append(rotating)\n"
	camera_script.reload()
	var camera = Node.new()
	camera.set_script(camera_script)
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	world_manager._set_jump_transition_camera_locked(true)

	assert_eq(
		Input.get_mouse_mode(),
		Input.MOUSE_MODE_VISIBLE,
		"Locking the jump transition should release the mouse while the cosmetic sequence is active."
	)

	world_manager._set_jump_transition_camera_locked(false)

	assert_eq(
		Input.get_mouse_mode(),
		Input.MOUSE_MODE_CAPTURED,
		"Unlocking the jump transition should restore the pre-jump mouse capture mode."
	)
	assert_eq(
		camera.rotation_input_calls,
		[false, true],
		"Jump locking should disable live rotation input during the transition and restore it afterward when free-flight was active."
	)
	assert_eq(
		camera.rotating_calls,
		[false, false],
		"Jump locking and unlock should both clear any held external camera rotation so the camera does not keep spinning after arrival."
	)


func test_prepare_jump_transition_departure_visuals_aims_before_lock_and_hides_hud():
	var container = Node.new()
	add_child_autofree(container)
	var world_manager = WorldManagerScript.new()
	container.add_child(world_manager)

	var event_order = []

	var rig_script = GDScript.new()
	rig_script.source_code = "extends Node\nvar events_ref = null\nfunc capture_from_camera(_camera):\n\tevents_ref.append(\"capture\")\nfunc set_transition_particles_active(is_active, clear_existing=false):\n\tevents_ref.append(\"transition_particles_\" + str(is_active) + \"_\" + str(clear_existing))\nfunc _set_transition_overlay_active(is_active):\n\tevents_ref.append(\"cover_\" + str(is_active))\n"
	rig_script.reload()
	var rig = Node.new()
	rig.name = Constants.JUMP_TRANSITION_RIG_NODE_NAME
	rig.set_script(rig_script)
	rig.events_ref = event_order
	container.add_child(rig)

	var camera_script = GDScript.new()
	camera_script.source_code = "extends Node\nvar events_ref = null\nfunc set_orbit_forward_direction(_direction):\n\tevents_ref.append(\"aim\")\nfunc set_local_scene_particles_active(is_active, clear_existing=false):\n\tevents_ref.append(\"local_particles_\" + str(is_active) + \"_\" + str(clear_existing))\nfunc set_is_rotating(_rotating):\n\tevents_ref.append(\"stop_rotate\")\nfunc set_rotation_input_active(is_active):\n\tevents_ref.append(\"lock_\" + str(is_active))\n"
	camera_script.reload()
	var camera = Node.new()
	camera.set_script(camera_script)
	camera.events_ref = event_order
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var hud = Control.new()
	add_child_autofree(hud)
	GlobalRefs.main_hud = hud

	var departure_state = world_manager._prepare_jump_transition_departure_visuals(Vector3(1, 0, 0))
	if departure_state is GDScriptFunctionState:
		yield(departure_state, "completed")

	assert_eq(
		event_order,
		["aim", "capture", "transition_particles_False_True", "stop_rotate", "lock_False", "cover_True"],
		"Jump departure visuals should aim the orbit camera first, capture that pose, clear any transition-only particles, lock camera input, and then enable the transition cover before the scene swap."
	)
	assert_false(hud.visible, "Jump departure visuals should hide the HUD immediately before the FoV shift begins.")


func test_jump_transition_rig_exposes_overlay_and_clears_transition_visual_scaffold():
	var rig = JumpTransitionRigScene.instance()
	add_child_autofree(rig)

	var transition_overlay = rig.get_node("TransitionOverlayLayer/TransitionOverlay")
	var transition_particles = rig.get_node("TransitionCamera/JumpTransitionParticles")

	assert_true(transition_overlay is ColorRect, "The jump rig should expose a CanvasItem-based TransitionOverlay for swap masking.")
	assert_true(transition_particles is Spatial, "The jump rig should expose a dedicated JumpTransitionParticles container for jump-only emitters.")
	assert_eq(transition_particles.get_child_count(), 4, "The jump rig should scaffold the duplicated transition particle emitters inside the dedicated container.")

	rig._set_transition_overlay_active(true)
	rig.set_transition_particles_active(true, true)

	assert_true(transition_overlay.visible, "The transition cover should become visible when the rig enables the swap mask.")
	assert_true(transition_particles.visible, "The dedicated jump-transition particle container should become visible when activated.")
	for emitter in transition_particles.get_children():
		assert_true(emitter is CPUParticles, "Jump-transition particle scaffolding must stay on CPUParticles for GLES2 compatibility.")
		assert_true(emitter.emitting, "Each jump-transition particle emitter should start emitting when the dedicated transition particle group is activated.")

	rig.reset_transition_state()

	assert_false(transition_overlay.visible, "Resetting the rig should clear the transition cover back to its idle hidden state.")
	assert_false(transition_particles.visible, "Resetting the rig should hide the dedicated jump-transition particle container.")
	for emitter in transition_particles.get_children():
		assert_false(emitter.emitting, "Resetting the rig should leave every jump-transition particle emitter fully cleared and idle.")


func test_jump_transition_gameplay_pause_and_restore_toggle_local_scene_particles():
	var world_manager = WorldManagerScript.new()
	add_child_autofree(world_manager)
	var initial_paused_state = get_tree().paused

	var camera_script = GDScript.new()
	camera_script.source_code = "extends Node\nvar particle_calls = []\nfunc set_local_scene_particles_active(is_active, clear_existing=false):\n\tparticle_calls.append([is_active, clear_existing])\n"
	camera_script.reload()
	var camera = Node.new()
	camera.set_script(camera_script)
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	world_manager._pause_jump_transition_gameplay()
	world_manager._restore_jump_transition_gameplay()

	assert_eq(
		camera.particle_calls,
		[[false, true], [true, true]],
		"Jump transition gameplay pause/restore should explicitly clear local-scene particles before despawn and resume them only after the transition ends."
	)
	assert_eq(get_tree().paused, initial_paused_state, "Jump transition gameplay restore should return the scene tree to its prior pause state.")


func test_jump_transition_rig_preserves_camera_pose_and_keeps_nebula_anchor_static():
	var rig = JumpTransitionRigScene.instance()
	add_child_autofree(rig)

	var source_camera = Camera.new()
	add_child_autofree(source_camera)
	var source_basis = Basis()
	source_basis = source_basis.rotated(Vector3.UP, deg2rad(45.0))
	source_basis = source_basis.rotated(Vector3.RIGHT, deg2rad(-15.0))
	source_camera.global_transform = Transform(source_basis, Vector3(75, 20, -40))

	rig.capture_from_camera(source_camera)
	rig.begin_departure(Constants.INITIAL_SECTOR_ID, "station_beta", Vector3(1, 0, 0))

	var transition_camera = rig.get_node("TransitionCamera")
	var nebula_holder = rig.get_node("NebulaHolder")
	var expected_anchor = Constants.get_reference_origin_offset(
		TemplateDatabase.locations[Constants.INITIAL_SECTOR_ID]["global_position"]
	)

	assert_eq(
		transition_camera.fov,
		source_camera.fov,
		"The transition camera should inherit the live gameplay camera FoV before the widened transition handoff."
	)
	assert_eq(
		transition_camera.global_transform.origin,
		Vector3.ZERO,
		"The transition camera should start at the current-sector-local origin so the transition starsphere matches the local-scene and map alignment frame."
	)
	assert_true(
		(-transition_camera.global_transform.basis.z).normalized().is_equal_approx(Vector3(1, 0, 0)),
		"The transition camera should lock its orientation to face the destination travel direction."
	)
	assert_eq(
		nebula_holder.transform.origin,
		expected_anchor,
		"The transition rig should anchor its starsphere to the source-sector reference offset instead of recentering it on the camera."
	)

	rig.set_transition_fov(Constants.JUMP_TRANSITION_TARGET_FOV_DEG)
	rig.begin_cruise(1000.0)
	rig._process(1.0)

	assert_eq(
		transition_camera.fov,
		Constants.JUMP_TRANSITION_TARGET_FOV_DEG,
		"The visible jump-scene camera should keep the widened transition FoV instead of snapping back to its normal authored FoV during cruise."
	)

	assert_true(
		transition_camera.global_transform.origin.distance_to(source_camera.global_transform.origin) > 0.1,
		"Cruise should move the transition camera through the jump scene."
	)
	assert_eq(
		transition_camera.global_transform.origin,
		rig.get_route_world_position() - TemplateDatabase.locations[Constants.INITIAL_SECTOR_ID]["global_position"],
		"Transition-camera travel should be expressed in current-sector-local coordinates so star sprites stay aligned during jump cruise."
	)
	assert_eq(
		nebula_holder.transform.origin,
		expected_anchor,
		"The transition starsphere anchor should remain static while the transition camera moves through it."
	)
	assert_true(
		rig.get_route_world_position().x > TemplateDatabase.locations[Constants.INITIAL_SECTOR_ID]["global_position"].x,
		"Jump cruise should advance the internal route position toward the destination instead of idling on a fixed hold timer."
	)


func test_restore_gameplay_camera_at_transition_fov_deactivates_transition_view():
	var container = Node.new()
	add_child_autofree(container)
	var world_manager = WorldManagerScript.new()
	container.add_child(world_manager)

	var rig_script = GDScript.new()
	rig_script.source_code = "extends Node\nvar deactivate_calls = 0\nvar overlay_calls = []\nvar particle_calls = []\nfunc deactivate_transition_view():\n\tdeactivate_calls += 1\nfunc get_transition_camera_forward_direction():\n\treturn Vector3(1, 0, 0)\nfunc set_transition_particles_active(is_active, clear_existing=false):\n\tparticle_calls.append([is_active, clear_existing])\nfunc _set_transition_overlay_active(is_active):\n\toverlay_calls.append(is_active)\n"
	rig_script.reload()
	var rig = Node.new()
	rig.name = Constants.JUMP_TRANSITION_RIG_NODE_NAME
	rig.set_script(rig_script)
	container.add_child(rig)

	var camera_script = GDScript.new()
	camera_script.source_code = "extends Node\nvar target_calls = []\nvar restore_calls = []\nvar fov_calls = []\nvar current = false\nfunc restore_orbit_from_transition_view(target, direction):\n\trestore_calls.append([target, direction])\nfunc set_target_node(target):\n\ttarget_calls.append(target)\nfunc set_temporary_fov_override(value):\n\tfov_calls.append(value)\n"
	camera_script.reload()
	var camera = Node.new()
	camera.set_script(camera_script)
	add_child_autofree(camera)
	GlobalRefs.main_camera = camera

	var player = Spatial.new()
	add_child_autofree(player)
	GlobalRefs.player_agent_body = player

	world_manager._restore_gameplay_camera_at_transition_fov()

	assert_eq(
		rig.deactivate_calls,
		1,
		"Restoring the gameplay camera should first deactivate the transition rig view so its starsphere is no longer visible on arrival."
	)
	assert_eq(
		camera.restore_calls.size(),
		1,
		"Gameplay camera restore should hand the orbit camera the transition rig's final pose instead of only rebinding the target."
	)
	assert_true(
		camera.restore_calls[0][0] == player,
		"Gameplay camera restore should target the live player agent body."
	)
	assert_true(
		camera.restore_calls[0][1].is_equal_approx(Vector3(1, 0, 0)),
		"Gameplay camera restore should reuse the jump rig's final forward direction so arrival does not flip back to stale orbit coordinates."
	)
	assert_eq(
		camera.target_calls.size(),
		0,
		"Gameplay camera restore should defer target rebinding to the synced orbit restore path when that API is available."
	)
	assert_eq(
		camera.fov_calls,
		[Constants.JUMP_TRANSITION_TARGET_FOV_DEG],
		"Gameplay camera restore should hand over at the widened transition FoV before animating back to the zoom-controller FoV."
	)
	assert_eq(
		rig.overlay_calls,
		[false],
		"Gameplay camera restore should clear the transition cover once the destination scene is ready to be revealed."
	)
	assert_eq(
		rig.particle_calls,
		[[false, true]],
		"Gameplay camera restore should explicitly clear transition-only particles before handing control back to the gameplay camera."
	)
	assert_true(camera.current, "Gameplay camera restore should hand current-camera ownership back to the main camera.")


func test_jump_transition_fov_progress_eases_in_toward_the_wide_fov():
	var world_manager = WorldManagerScript.new()
	add_child_autofree(world_manager)

	assert_eq(
		world_manager._get_jump_transition_fov_progress(0.0),
		0.0,
		"FoV easing should start at the unmodified progress value."
	)
	assert_true(
		world_manager._get_jump_transition_fov_progress(0.5) < 0.25,
		"FoV easing should now stay behind the old quadratic midpoint so the widened jump FoV accelerates more gradually at the start."
	)
	assert_eq(
		world_manager._get_jump_transition_fov_progress(1.0),
		1.0,
		"FoV easing should still reach the full target FoV at the end of the animation."
	)


func test_jump_transition_rig_cruise_accelerates_more_gradually_before_reaching_target_speed():
	var rig = JumpTransitionRigScene.instance()
	add_child_autofree(rig)

	var source_camera = Camera.new()
	add_child_autofree(source_camera)
	source_camera.global_transform = Transform(Basis(), Vector3.ZERO)

	rig.capture_from_camera(source_camera)
	rig.begin_departure(Constants.INITIAL_SECTOR_ID, "station_beta", Vector3(1, 0, 0))
	rig.begin_cruise(1000.0)
	rig._process(0.5)

	assert_true(
		rig.get_current_velocity() > 0.0,
		"Jump cruise should still accelerate forward during the transition."
	)
	assert_true(
		rig.get_current_velocity() < 700.0,
		"Jump cruise should ramp up more gradually than the prior near-instant acceleration so the transition has a softer takeoff."
	)
	rig.reset_transition_state()


func test_jump_transition_rig_completes_route_when_destination_is_reached():
	var rig = JumpTransitionRigScene.instance()
	add_child_autofree(rig)

	var source_camera = Camera.new()
	add_child_autofree(source_camera)
	source_camera.global_transform = Transform(Basis(), Vector3.ZERO)

	rig.capture_from_camera(source_camera)
	rig.begin_departure(Constants.INITIAL_SECTOR_ID, "station_beta", Vector3(1, 0, 0))
	rig.begin_cruise(4000.0)

	for _step in range(60):
		rig._process(0.1)
		if rig.is_route_complete():
			break

	assert_true(
		rig.is_route_complete(),
		"Jump transition should finish based on reaching the destination route position instead of waiting on a fixed cruise timer."
	)
	assert_eq(
		rig.get_route_world_position(),
		TemplateDatabase.locations["station_beta"]["global_position"],
		"Completed jump transitions should clamp the internal route position to the destination coordinate for deterministic arrival handoff."
	)
	assert_eq(
		rig.get_node("TransitionCamera").global_transform.origin,
		TemplateDatabase.locations["station_beta"]["global_position"] - TemplateDatabase.locations[Constants.INITIAL_SECTOR_ID]["global_position"],
		"Completed jump transitions should end at the destination in current-sector-local space so the starsphere matches local-scene and map coordinates."
	)