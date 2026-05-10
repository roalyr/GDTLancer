extends Button

const NORMAL_COLOR = Color(0.35, 0.95, 1.0, 0.95)
const SELECTED_COLOR = Color(1.0, 0.9, 0.35, 1.0)
const BACKGROUND_COLOR = Color(0.02, 0.05, 0.08, 0.35)

var target_ref = null
var _is_selected: bool = false
var _label: Label = null
var _target_label: String = ""


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	rect_min_size = Vector2(180, 56)
	if _label == null:
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
	_sync_label()
	update()


func configure_target(new_target_ref, new_target_label: String = "") -> void:
	target_ref = new_target_ref
	_target_label = new_target_label
	_sync_label()
	update()


func set_selected_state(is_selected: bool) -> void:
	if _is_selected == is_selected:
		return
	_is_selected = is_selected
	update()


func _draw() -> void:
	var color = SELECTED_COLOR if _is_selected else NORMAL_COLOR
	var rect = Rect2(Vector2.ZERO, rect_size)
	draw_rect(rect, BACKGROUND_COLOR, true)
	var corner_length = min(rect_size.x, rect_size.y) * 0.28
	var line_width = 2.0

	draw_line(Vector2(0, 0), Vector2(corner_length, 0), color, line_width)
	draw_line(Vector2(0, 0), Vector2(0, corner_length), color, line_width)
	draw_line(Vector2(rect_size.x, 0), Vector2(rect_size.x - corner_length, 0), color, line_width)
	draw_line(Vector2(rect_size.x, 0), Vector2(rect_size.x, corner_length), color, line_width)
	draw_line(Vector2(0, rect_size.y), Vector2(corner_length, rect_size.y), color, line_width)
	draw_line(Vector2(0, rect_size.y), Vector2(0, rect_size.y - corner_length), color, line_width)
	draw_line(Vector2(rect_size.x, rect_size.y), Vector2(rect_size.x - corner_length, rect_size.y), color, line_width)
	draw_line(Vector2(rect_size.x, rect_size.y), Vector2(rect_size.x, rect_size.y - corner_length), color, line_width)


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