# HullPreview: the store's look at a hull (scenes/ui/menus/fitting/hull_preview.tscn): the ship's
# model in a little world of its own, framed to fit, turning slowly; drag it (mouse or touch) to
# turn it by hand. The fitting window shows the ship tapped in the ships tab (show_ship).
# Its viewport renders only while the preview is visible in the tree: a hidden ViewportContainer
# stops drawing the texture, not rendering it, and the fitting window stays open (other tabs) the
# whole time the player is docked.

extends ViewportContainer

const Interp = preload("res://src/core/utils/interp.gd")

const TURN_RATE = 0.35  # rad/s it turns by itself
const DRAG_RATE = 0.01  # rad per px dragged
const RESUME_AFTER = 3.0  # s after a drag it turns by itself again
const VIEW_FROM = Vector3(0.0, 0.75, 1.7)  # The camera's direction from the hull: above and ahead of it
const FRAME_MARGIN = 0.8  # Of the hull's reach framed: below 1, a long hull's ends may pass the frame as it turns, its body fills it

onready var _pivot: Spatial = $Viewport/Pivot
onready var _camera: Camera = $Viewport/Camera
onready var _name: Label = $Name

var ship_id: String = ""
var _idle: float = RESUME_AFTER
var _reach: float = 1.0  # The hull's radius (m), as framed


func _ready() -> void:
	Interp.keep_out(_pivot)  # Turned per frame (_process), so drawn as it is: no interpolation warnings
	connect("gui_input", self, "_on_gui_input")
	connect("resized", self, "_frame")
	_update_rendering()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_rendering()


func _update_rendering() -> void:
	var viewport: Viewport = get_node_or_null("Viewport")
	if viewport != null:
		viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS if is_visible_in_tree() else Viewport.UPDATE_DISABLED


func show_ship(template_id: String) -> void:
	ship_id = template_id
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.queue_free()
	var ship = TemplateDatabase.get_template(template_id)
	_name.text = Strings.name_of(ship.ship_model_name).to_upper() if ship != null and "ship_model_name" in ship else ""
	if ship == null or ship.ship_scene == null:
		return
	var model: Spatial = ship.ship_scene.instance()
	_pivot.add_child(model)
	_pivot.rotation = Vector3(0.0, 0.6, 0.0)
	_reach = max(_radius(model), 1.0)
	_frame()


# The camera far enough back that the hull's whole reach (any turn) fits the frame's narrower way:
# a tall frame (the FITTING view's) or a wide one (the store's).
func _frame() -> void:
	var size: Vector2 = rect_size if rect_size.x > 1.0 and rect_size.y > 1.0 else Vector2(400, 240)
	var half_tall: float = deg2rad(_camera.fov) * 0.5  # The fov is the height's (keep_height)
	var half_wide: float = atan(tan(half_tall) * size.x / size.y)
	var distance: float = _reach * FRAME_MARGIN / sin(min(half_tall, half_wide))
	_camera.look_at_from_position(VIEW_FROM.normalized() * distance, Vector3.ZERO, Vector3.UP)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_idle += delta
	if _idle >= RESUME_AFTER:
		_pivot.rotate_y(TURN_RATE * delta)


func _on_gui_input(event: InputEvent) -> void:
	var drag: float = 0.0
	if event is InputEventScreenDrag:
		drag = event.relative.x
	elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT:
		drag = event.relative.x
	if drag != 0.0:
		_pivot.rotate_y(drag * DRAG_RATE)
		_idle = 0.0
		accept_event()


# How far its meshes reach from its origin (any model: placeholder or hand-made, however nested).
func _radius(model: Spatial) -> float:
	var reach := 0.0
	var inverse: Transform = model.global_transform.affine_inverse()
	var stack: Array = [model]
	while not stack.empty():
		var node: Node = stack.pop_back()
		stack += node.get_children()
		if node is MeshInstance and node.mesh != null:
			var box: AABB = (inverse * node.global_transform).xform(node.get_aabb())
			for index in range(8):
				reach = max(reach, box.get_endpoint(index).length())
	return reach
