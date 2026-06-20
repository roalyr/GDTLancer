# PROJECT: GDTLancer
# MODULE: projected_target_bracket.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: projected_target_bracket.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_SIMULATION-GRAPH.md §6.4; TACTICAL_TODO.md TASK_4
# LOG_REF: 2026-06-09 20:56:00
#

extends Button

const BRACKET_TEXTURE_RECT_SIZE = Vector2(150, 150)
const DISTANCE_KILOUNIT_SCALE = 1000.0
const DISTANCE_PLAIN_THRESHOLD = 2000.0
const DISTANCE_DECIMAL_K_THRESHOLD = 10000.0
const DISTANCE_SINGLE_DECIMAL_K_THRESHOLD = 100000.0
const DISTANCE_FAR_THRESHOLD = 1000000.0
const DRAG_THRESHOLD_PX_SQ = 10 * 10

var target_ref = null
var _is_selected: bool = false
var _normal_bracket: TextureRect = null
var _selected_bracket: TextureRect = null
var _distance_panel: Control = null
var _distance_label: Label = null
var _info_panel: Control = null
var _info_label: Label = null
var _target_label: String = ""
var _context_hint: String = ""
var _press_position: Vector2 = Vector2.ZERO
var _is_pointer_pressed: bool = false
var _is_dragging_pointer: bool = false
var _distance_fade_alpha: float = 1.0


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	keep_pressed_outside = false
	rect_min_size = BRACKET_TEXTURE_RECT_SIZE
	_cache_scene_nodes()
	_apply_bracket_style()
	_apply_distance_fade_alpha()
	_sync_label()
	_sync_distance_label()
	set_process(true)


func _process(_delta: float) -> void:
	if _is_selected:
		_sync_distance_label()
		
	if _is_free_flight_active():
		if mouse_filter != Control.MOUSE_FILTER_IGNORE:
			mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		if mouse_filter != Control.MOUSE_FILTER_STOP:
			mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(_event: InputEvent) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _is_pointer_pressed and not _is_dragging_pointer:
		if _is_free_flight_active():
			var player_agent = GlobalRefs.player_agent_body
			if is_instance_valid(player_agent):
				var player_controller = player_agent.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)
				if is_instance_valid(player_controller) and player_controller.has_method("_unhandled_input"):
					player_controller._unhandled_input(event)

	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN):
			if _is_pointer_hover_position(event.position):
				_forward_camera_input(event)
			return
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				if not disabled and _is_pointer_hover_position(event.position):
					_begin_pointer_tracking(event.position)
			else:
				if _is_pointer_pressed or _is_dragging_pointer:
					_finish_pointer_tracking_at(event.position)
			return

	if event is InputEventMouseMotion and _is_pointer_pressed and not _is_dragging_pointer:
		if event.position.distance_squared_to(_press_position) > DRAG_THRESHOLD_PX_SQ:
			_cancel_pending_click_for_drag(event)

	if not (_is_pointer_pressed or _is_dragging_pointer or disabled):
		return
	if event is InputEventMouseMotion and _is_dragging_pointer:
		if _is_main_hud_drag_passthrough_active():
			return
		_forward_camera_drag_motion(event)
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		_finish_pointer_tracking_at(event.position)


func configure_target(new_target_ref, new_target_label: String = "") -> void:
	target_ref = new_target_ref
	_target_label = new_target_label
	_apply_bracket_style()
	_sync_label()
	_sync_distance_label()
	_refresh_distance_process_state()


func set_selected_state(is_selected: bool) -> void:
	if _is_selected == is_selected:
		return
	_is_selected = is_selected
	_apply_bracket_style()
	_sync_label()
	_sync_distance_label()
	_refresh_distance_process_state()


func set_context_hint(new_context_hint: String = "") -> void:
	if _context_hint == new_context_hint:
		return
	_context_hint = new_context_hint
	_sync_label()


func set_distance_fade_alpha(distance_fade_alpha: float) -> void:
	var safe_alpha = clamp(distance_fade_alpha, 0.0, 1.0)
	if is_equal_approx(_distance_fade_alpha, safe_alpha):
		return
	_distance_fade_alpha = safe_alpha
	_apply_distance_fade_alpha()


func _begin_pointer_tracking(pointer_position: Vector2) -> void:
	_press_position = pointer_position
	_is_pointer_pressed = true
	_is_dragging_pointer = false
	if disabled:
		disabled = false


func _cancel_pending_click_for_drag(motion_event: InputEventMouseMotion) -> void:
	_is_dragging_pointer = true
	disabled = true
	_set_camera_drag_state(true)
	if not _begin_main_hud_drag_passthrough(motion_event):
		_forward_camera_drag_motion(motion_event)


func _finish_pointer_tracking() -> void:
	if _is_dragging_pointer and not _is_main_hud_drag_passthrough_active():
		_set_camera_drag_state(false)
	_reset_pointer_tracking_state()


func _finish_pointer_tracking_at(pointer_position: Vector2) -> void:
	var should_emit_pressed: bool = _is_pointer_pressed and not _is_dragging_pointer and _is_pointer_hover_position(pointer_position)
	_finish_pointer_tracking()
	if should_emit_pressed:
		emit_signal("pressed")


func reset_pointer_tracking_from_main_hud() -> void:
	_reset_pointer_tracking_state()


func _reset_pointer_tracking_state() -> void:
	_is_pointer_pressed = false
	_is_dragging_pointer = false
	if disabled:
		disabled = false


func _set_camera_drag_state(is_rotating: bool) -> void:
	_call_camera_bridge_method("set_is_rotating", [is_rotating])


func _forward_camera_drag_motion(motion_event: InputEventMouseMotion) -> void:
	_forward_camera_input(motion_event)


func _forward_camera_input(event: InputEvent) -> void:
	_call_camera_bridge_method("_unhandled_input", [event])


func _cache_scene_nodes() -> void:
	_normal_bracket = get_node_or_null("BracketNormal")
	_selected_bracket = get_node_or_null("BracketSelected")
	_distance_panel = get_node_or_null("BracketSelected/DistancePanel")
	_distance_label = get_node_or_null("BracketSelected/DistancePanel/DistanceLabel")
	_info_panel = get_node_or_null("InfoPanel")
	_info_label = get_node_or_null("InfoPanel/InfoLabel")

	if is_instance_valid(_normal_bracket):
		_normal_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_normal_bracket.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_selected_bracket):
		_selected_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_selected_bracket.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_distance_panel):
		_distance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_distance_panel.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_distance_label):
		_distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_distance_label.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_info_panel):
		_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_panel.focus_mode = Control.FOCUS_NONE

	if is_instance_valid(_info_label):
		_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_label.focus_mode = Control.FOCUS_NONE


func _apply_bracket_style() -> void:
	if is_instance_valid(_normal_bracket):
		_normal_bracket.visible = not _is_selected
		if _is_route_target(target_ref) or _is_jump_point_target(target_ref):
			_normal_bracket.modulate = _get_jump_route_color()
		else:
			_normal_bracket.modulate = Color(0.35, 0.95, 1, 0.95)
	if is_instance_valid(_selected_bracket):
		_selected_bracket.visible = _is_selected


func _apply_distance_fade_alpha() -> void:
	modulate = Color(1, 1, 1, _distance_fade_alpha)


func _sync_label() -> void:
	if not is_instance_valid(_info_label):
		return
	var label_text = _build_label_text()
	_info_label.text = label_text
	if _is_route_target(target_ref) or _is_jump_point_target(target_ref):
		_info_label.add_color_override("font_color", _get_jump_route_color())
	else:
		_info_label.remove_color_override("font_color")
	if is_instance_valid(_info_panel):
		_info_panel.visible = label_text != ""


func _sync_distance_label() -> void:
	if not is_instance_valid(_distance_label):
		return
	_distance_label.text = _build_distance_label_text()


func _build_distance_label_text() -> String:
	if not _is_selected:
		return ""
	if _is_route_target(target_ref):
		return "FAR"
	if not (target_ref is Spatial and is_instance_valid(target_ref)):
		return ""
	if target_ref.is_in_group("jump_point"):
		return "FAR"
	if not target_ref.is_inside_tree():
		return ""
	var player_agent = GlobalRefs.player_agent_body
	if not (player_agent is Spatial and is_instance_valid(player_agent)):
		return ""
	var distance_units = player_agent.global_transform.origin.distance_to(target_ref.global_transform.origin)
	return _format_distance_label(distance_units)


func _format_distance_label(distance_units: float) -> String:
	var safe_distance_units = max(0.0, distance_units)
	if safe_distance_units >= DISTANCE_FAR_THRESHOLD:
		return "FAR"
	if safe_distance_units < DISTANCE_PLAIN_THRESHOLD:
		return str(int(round(safe_distance_units)))

	var distance_kilounits = safe_distance_units / DISTANCE_KILOUNIT_SCALE
	if safe_distance_units < DISTANCE_DECIMAL_K_THRESHOLD:
		return "%sk" % _trim_trailing_decimal_zeros("%.2f" % distance_kilounits)
	if safe_distance_units < DISTANCE_SINGLE_DECIMAL_K_THRESHOLD:
		return "%sk" % _trim_trailing_decimal_zeros("%.1f" % distance_kilounits)
	return "%dk" % int(floor(distance_kilounits))


func _trim_trailing_decimal_zeros(value_text: String) -> String:
	var trimmed_text = value_text
	while trimmed_text.find(".") != -1 and trimmed_text.ends_with("0"):
		trimmed_text = trimmed_text.substr(0, trimmed_text.length() - 1)
	if trimmed_text.ends_with("."):
		trimmed_text = trimmed_text.substr(0, trimmed_text.length() - 1)
	return trimmed_text


func _refresh_distance_process_state() -> void:
	pass


func _build_label_text() -> String:
	var primary_text = _resolve_primary_label()
	var secondary_text = _resolve_secondary_label()
	if primary_text == "":
		return secondary_text
	if secondary_text == "":
		return primary_text
	return "%s\n%s" % [primary_text, secondary_text]


func _resolve_primary_label() -> String:
	if _target_label != "":
		return _target_label
	if target_ref == null:
		return ""
	if target_ref.get("display_name") != null and str(target_ref.get("display_name")) != "":
		return str(target_ref.get("display_name"))
	if target_ref.get("station_name") != null and str(target_ref.get("station_name")) != "":
		return str(target_ref.get("station_name"))
	if target_ref.get("agent_name") != null and str(target_ref.get("agent_name")) != "":
		return str(target_ref.get("agent_name"))
	if target_ref.get("name") != null and str(target_ref.get("name")) != "":
		return str(target_ref.get("name")).replace("_", " ")
	if target_ref.get("target_sector_id") != null and str(target_ref.get("target_sector_id")) != "":
		return str(target_ref.get("target_sector_id"))
	return ""


func _resolve_secondary_label() -> String:
	if _context_hint != "":
		return _context_hint
	if _is_route_target(target_ref):
		return ""
	if _is_dockable_target(target_ref):
		return "Dock Target"
	if _is_selected:
		return "Target Locked"
	return ""


func _is_route_target(target_candidate) -> bool:
	return target_candidate != null and target_candidate.get("target_kind") == "jump_route"


func _is_dockable_target(target_candidate) -> bool:
	return target_candidate is Node and is_instance_valid(target_candidate) and target_candidate.is_in_group("dockable_station")


func _is_jump_point_target(target_candidate) -> bool:
	return target_candidate is Node and is_instance_valid(target_candidate) and target_candidate.is_in_group("jump_point")


func _is_free_flight_active() -> bool:
	var player_agent = GlobalRefs.player_agent_body
	if not is_instance_valid(player_agent):
		return false
	var player_controller = player_agent.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)
	return is_instance_valid(player_controller) and player_controller.has_method("is_free_flight_active") and player_controller.is_free_flight_active()


func _get_jump_route_color() -> Color:
	var sector_type = ""
	if target_ref != null:
		var dest_id = ""
		if target_ref.get("target_sector_id") != null:
			dest_id = str(target_ref.get("target_sector_id"))
		elif "target_sector_id" in target_ref:
			dest_id = str(target_ref.target_sector_id)
			
		if dest_id != "":
			if GameState.world_topology.has(dest_id) and GameState.world_topology[dest_id].has("sector_type"):
				sector_type = GameState.world_topology[dest_id].sector_type
			elif TemplateDatabase.locations.has(dest_id):
				var loc = TemplateDatabase.locations[dest_id]
				if loc != null and loc.get("sector_type") != null:
					sector_type = loc.sector_type
	return Constants.get_jump_type_color(sector_type)


func _begin_main_hud_drag_passthrough(initial_motion_event: InputEventMouseMotion) -> bool:
	var main_hud = _get_main_hud_drag_passthrough_bridge()
	if not is_instance_valid(main_hud):
		return false
	main_hud.begin_projected_target_drag_passthrough(self, initial_motion_event)
	return true


func _is_main_hud_drag_passthrough_active() -> bool:
	var main_hud = _get_main_hud_drag_passthrough_bridge()
	return is_instance_valid(main_hud) and main_hud.is_projected_target_drag_passthrough_active()


func _get_main_hud_drag_passthrough_bridge() -> Node:
	var main_hud = GlobalRefs.main_hud
	if not is_instance_valid(main_hud):
		return null
	if not main_hud.has_method("begin_projected_target_drag_passthrough"):
		return null
	if not main_hud.has_method("is_projected_target_drag_passthrough_active"):
		return null
	return main_hud


func _call_camera_bridge_method(method_name: String, args: Array = [], default_value = null):
	var camera = GlobalRefs.main_camera
	if not is_instance_valid(camera) or not camera.has_method(method_name):
		return default_value
	if args.empty():
		return camera.call(method_name)
	return camera.callv(method_name, args)


func _is_pointer_hover_position(pointer_position: Vector2) -> bool:
	return visible and get_global_rect().has_point(pointer_position)