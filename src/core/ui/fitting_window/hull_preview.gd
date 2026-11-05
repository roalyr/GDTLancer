# HullPreview: the store's look at a hull (scenes/ui/menus/fitting/hull_preview.tscn): the ship's
# model in a little world of its own, framed to fit, turning slowly; drag it (mouse or touch) to
# turn it by hand. The fitting window shows the ship tapped in the ships tab (show_ship).

extends ViewportContainer

const TURN_RATE = 0.35  # rad/s it turns by itself
const DRAG_RATE = 0.01  # rad per px dragged
const RESUME_AFTER = 3.0  # s after a drag it turns by itself again

onready var _pivot: Spatial = $Viewport/Pivot
onready var _camera: Camera = $Viewport/Camera
onready var _name: Label = $Name

var ship_id: String = ""
var _idle: float = RESUME_AFTER


func _ready() -> void:
	connect("gui_input", self, "_on_gui_input")


func show_ship(template_id: String) -> void:
	ship_id = template_id
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.queue_free()
	var ship = TemplateDatabase.get_template(template_id)
	_name.text = ship.ship_model_name.to_upper() if ship != null and "ship_model_name" in ship else ""
	if ship == null or ship.ship_scene == null:
		return
	var model: Spatial = ship.ship_scene.instance()
	_pivot.add_child(model)
	_pivot.rotation = Vector3(0.0, 0.6, 0.0)
	var radius: float = max(_radius(model), 1.0)
	_camera.look_at_from_position(Vector3(0.0, radius * 0.75, radius * 1.7), Vector3.ZERO, Vector3.UP)


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
