#
# PROJECT: GDTLancer
# MODULE: projected_target_bracket.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §4.2, §6.1, §6.3
# LOG_REF: 2026-05-10 23:51:42
#

extends Button

const BRACKET_BACKGROUND_STYLE = preload("res://assets/art/ui/controls/projected_targets/projected_target_bracket_background.tres")
const BRACKET_NORMAL_STYLE = preload("res://assets/art/ui/controls/projected_targets/projected_target_bracket_normal.tres")
const BRACKET_SELECTED_STYLE = preload("res://assets/art/ui/controls/projected_targets/projected_target_bracket_selected.tres")
const DRAG_THRESHOLD_PX_SQ = 10 * 10

var target_ref = null
var _is_selected: bool = false
var _background_panel: Panel = null
var _frame_panel: Panel = null
var _label: Label = null
var _target_label: String = ""
var _press_position: Vector2 = Vector2.ZERO
var _is_pointer_pressed: bool = false
var _is_dragging_pointer: bool = false


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	keep_pressed_outside = false
	rect_min_size = Vector2(200, 100)
	_ensure_background_panel()
	_ensure_frame_panel()
	_ensure_label()
	_apply_bracket_style()
	_sync_label()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			_begin_pointer_tracking(event.position)
		else:
			_finish_pointer_tracking()
		return

	if event is InputEventMouseMotion and _is_pointer_pressed and not _is_dragging_pointer:
		if event.position.distance_squared_to(_press_position) > DRAG_THRESHOLD_PX_SQ:
			_cancel_pending_click_for_drag(event)


func _input(event: InputEvent) -> void:
	if not (_is_pointer_pressed or _is_dragging_pointer or disabled):
		return
	if event is InputEventMouseMotion and _is_dragging_pointer:
		_forward_camera_drag_motion(event)
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		_finish_pointer_tracking()


func configure_target(new_target_ref, new_target_label: String = "") -> void:
	target_ref = new_target_ref
	_target_label = new_target_label
	_sync_label()


func set_selected_state(is_selected: bool) -> void:
	if _is_selected == is_selected:
		return
	_is_selected = is_selected
	_apply_bracket_style()


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
	_forward_camera_drag_motion(motion_event)


func _finish_pointer_tracking() -> void:
	if _is_dragging_pointer:
		_set_camera_drag_state(false)
	_is_pointer_pressed = false
	_is_dragging_pointer = false
	if disabled:
		disabled = false


func _set_camera_drag_state(is_rotating: bool) -> void:
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and camera.has_method("set_is_rotating"):
		camera.set_is_rotating(is_rotating)


func _forward_camera_drag_motion(motion_event: InputEventMouseMotion) -> void:
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and camera.has_method("_unhandled_input"):
		camera.call("_unhandled_input", motion_event)


func _ensure_background_panel() -> void:
	if _background_panel != null:
		return
	_background_panel = Panel.new()
	_background_panel.name = "Background"
	_configure_fill_control(_background_panel)
	_background_panel.add_stylebox_override("panel", BRACKET_BACKGROUND_STYLE)
	add_child(_background_panel)


func _ensure_frame_panel() -> void:
	if _frame_panel != null:
		return
	_frame_panel = Panel.new()
	_frame_panel.name = "Frame"
	_configure_fill_control(_frame_panel)
	add_child(_frame_panel)


func _ensure_label() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.name = "Label"
	_label.anchor_right = 1.0
	_label.anchor_bottom = 1.0
	_label.margin_left = 10.0
	_label.margin_top = 8.0
	_label.margin_right = -10.0
	_label.margin_bottom = -8.0
	_label.align = Label.ALIGN_CENTER
	_label.valign = Label.VALIGN_CENTER
	_label.autowrap = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _configure_fill_control(control: Control) -> void:
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE


func _apply_bracket_style() -> void:
	if _frame_panel == null:
		return
	var bracket_style = BRACKET_SELECTED_STYLE if _is_selected else BRACKET_NORMAL_STYLE
	_frame_panel.add_stylebox_override("panel", bracket_style)


func _sync_label() -> void:
	if _label == null:
		return
	if _target_label != "":
		_label.text = _target_label
	elif target_ref != null and target_ref.get("display_name") != null:
		_label.text = str(target_ref.display_name)
	elif target_ref != null and target_ref.get("name") != null:
		_label.text = str(target_ref.name).replace("_", " ")
	else:
		_label.text = ""
