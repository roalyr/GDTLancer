#
# PROJECT: GDTLancer
# MODULE: hud_drag_controller.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Workflow And Scope Boundary
# LOG_REF: 2026-06-13 06:40:05
#

extends Reference

var _hud: Control

func _init(hud: Control) -> void:
	_hud = hud

func register_inflight_drag_controls() -> void:
	for control_path in _hud.INFLIGHT_DRAG_CONTROL_PATHS:
		var control = _hud.get_node_or_null(control_path)
		if control is Control:
			track_inflight_drag_control(control)

func track_inflight_drag_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if _hud._tracked_inflight_drag_controls.has(control):
		return
	_hud._tracked_inflight_drag_controls.append(control)
	_hud._tracked_inflight_drag_filters[control.get_instance_id()] = control.mouse_filter
	if not control.is_connected("gui_input", _hud, "_on_inflight_drag_control_gui_input"):
		control.connect("gui_input", _hud, "_on_inflight_drag_control_gui_input", [control])

func untrack_inflight_drag_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	_hud._tracked_inflight_drag_controls.erase(control)
	_hud._tracked_inflight_drag_filters.erase(control.get_instance_id())
	if control.is_connected("gui_input", _hud, "_on_inflight_drag_control_gui_input"):
		control.disconnect("gui_input", _hud, "_on_inflight_drag_control_gui_input")

func on_inflight_drag_control_gui_input(event: InputEvent, control: Control) -> void:
	if not is_instance_valid(control):
		return
	if not (event is InputEventMouseMotion):
		return
	if not _hud._is_external_camera_drag_active():
		return
	_hud._set_inflight_drag_passthrough(true)
	_hud._forward_inflight_drag_motion(event)
	_hud.get_tree().set_input_as_handled()

func begin_projected_target_drag_passthrough(source_control: Control, initial_motion_event: InputEventMouseMotion = null) -> void:
	_hud._projected_target_drag_source = source_control if is_instance_valid(source_control) else null
	_hud._projected_target_drag_passthrough_active = true
	_hud._set_inflight_drag_passthrough(true)
	if initial_motion_event != null:
		_hud._forward_inflight_drag_motion(initial_motion_event)

func is_projected_target_drag_passthrough_active() -> bool:
	return _hud._projected_target_drag_passthrough_active

func end_projected_target_drag_passthrough(release_event: InputEventMouseButton = null) -> void:
	if is_instance_valid(_hud._projected_target_drag_source) and _hud._projected_target_drag_source.has_method("reset_pointer_tracking_from_main_hud"):
		_hud._projected_target_drag_source.call("reset_pointer_tracking_from_main_hud")
	_hud._projected_target_drag_source = null
	_hud._projected_target_drag_passthrough_active = false
	if release_event != null:
		_hud._forward_inflight_drag_release(release_event)
	else:
		var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _hud._main_camera
		if is_instance_valid(camera) and camera.has_method("set_is_rotating"):
			camera.set_is_rotating(false)
	_hud._set_inflight_drag_passthrough(false)

func is_external_camera_drag_active() -> bool:
	var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _hud._main_camera
	return is_instance_valid(camera) and camera.has_method("is_externally_rotating") and camera.is_externally_rotating()

func set_inflight_drag_passthrough(is_active: bool) -> void:
	_hud._inflight_drag_passthrough_active = is_active
	compact_tracked_inflight_drag_controls()
	for control in _hud._tracked_inflight_drag_controls:
		if not is_instance_valid(control):
			continue
		var control_id = control.get_instance_id()
		if is_active:
			if not _hud._tracked_inflight_drag_filters.has(control_id):
				_hud._tracked_inflight_drag_filters[control_id] = control.mouse_filter
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			control.mouse_filter = _hud._tracked_inflight_drag_filters.get(
				control_id,
				Control.MOUSE_FILTER_STOP
			)
	_hud._refresh_process_state()

func compact_tracked_inflight_drag_controls() -> void:
	var valid_controls: Array = []
	for control in _hud._tracked_inflight_drag_controls:
		if is_instance_valid(control):
			valid_controls.append(control)
	_hud._tracked_inflight_drag_controls = valid_controls

func is_pointer_over_tracked_inflight_control(pointer_position: Vector2) -> bool:
	compact_tracked_inflight_drag_controls()
	for control in _hud._tracked_inflight_drag_controls:
		if not is_instance_valid(control):
			continue
		if not control.visible:
			continue
		if control.get_global_rect().has_point(pointer_position):
			return true
	return false

func forward_inflight_drag_motion(motion_event: InputEventMouseMotion) -> void:
	var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _hud._main_camera
	if is_instance_valid(camera) and camera.has_method("_unhandled_input"):
		camera.call("_unhandled_input", motion_event)

func forward_inflight_drag_release(release_event: InputEventMouseButton) -> void:
	var player_agent = GlobalRefs.player_agent_body
	if is_instance_valid(player_agent):
		var player_controller = player_agent.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)
		if is_instance_valid(player_controller) and player_controller.has_method("_unhandled_input"):
			player_controller.call("_unhandled_input", release_event)
	var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _hud._main_camera
	if is_instance_valid(camera) and camera.has_method("set_is_rotating"):
		camera.set_is_rotating(false)

func sync_inflight_drag_passthrough() -> void:
	if _hud._projected_target_drag_passthrough_active and not is_external_camera_drag_active():
		end_projected_target_drag_passthrough()
		return
	if _hud._inflight_drag_passthrough_active and not is_external_camera_drag_active():
		set_inflight_drag_passthrough(false)
