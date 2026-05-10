 #
 # PROJECT: GDTLancer
 # MODULE: projected_target_bracket.gd
 # STATUS: [Level 2 - Implementation]
 # TRUTH_LINK: TRUTH_CONTENT-CREATION-MANUAL.md §5.3, §5.4, §6.1; TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md §2, §6
 # LOG_REF: 2026-05-10 21:07:00
 #

extends Button

const BRACKET_BACKGROUND_STYLE = preload("res://assets/art/ui/controls/projected_targets/projected_target_bracket_background.tres")
const BRACKET_NORMAL_STYLE = preload("res://assets/art/ui/controls/projected_targets/projected_target_bracket_normal.tres")
const BRACKET_SELECTED_STYLE = preload("res://assets/art/ui/controls/projected_targets/projected_target_bracket_selected.tres")

var target_ref = null
var _is_selected: bool = false
var _background_panel: Panel = null
var _frame_panel: Panel = null
var _label: Label = null
var _target_label: String = ""


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	rect_min_size = Vector2(180, 56)
	_ensure_background_panel()
	_ensure_frame_panel()
	_ensure_label()
	_apply_bracket_style()
	_sync_label()


func configure_target(new_target_ref, new_target_label: String = "") -> void:
	target_ref = new_target_ref
	_target_label = new_target_label
	_sync_label()


func set_selected_state(is_selected: bool) -> void:
	if _is_selected == is_selected:
		return
	_is_selected = is_selected
	_apply_bracket_style()


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
