# DebugMap: the galaxy's sectors and jump routes in 3D, opened from the debug overlay. Sectors sit
# at their registry global_position, centred on the current one; routes are their connections.
# Drag to orbit, wheel to zoom; the header buttons do the same for touch.

extends Control

const DEFAULT_ZOOM = 1500000.0  # m from the pivot
const MIN_ZOOM = 50000.0
const MAX_ZOOM = 5000000.0
const ZOOM_STEP = 1.3
const ORBIT_STEP = 0.15  # rad per button press
const DRAG_ORBIT_PER_PX = 0.005  # rad
const PAN_STEP = 0.1  # Of the zoom distance
const DEFAULT_PITCH = 0.5
const MARKER_RADIUS = 12000.0  # m
const CURRENT_MARKER_SCALE = 1.6
const AXIS_LENGTH = 200000.0  # m, at the current sector
const COLOR_CURRENT = Color(1, 1, 1, 1)
const COLOR_ROUTE = Color(0.5, 0.8, 0.5, 0.6)
const GLOBAL_NEBULAS_SCENE = preload("res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn")

onready var _viewport_container: ViewportContainer = $Panel/Layout/MapArea/ViewportContainer
onready var _viewport: Viewport = $Panel/Layout/MapArea/ViewportContainer/Viewport
onready var _camera: Camera = $Panel/Layout/MapArea/ViewportContainer/Viewport/MapCamera
onready var _content: Spatial = $Panel/Layout/MapArea/ViewportContainer/Viewport/MapContent
onready var _labels: Control = $Panel/Layout/MapArea/LabelOverlay

var _yaw: float = 0.0
var _pitch: float = DEFAULT_PITCH
var _zoom: float = DEFAULT_ZOOM
var _pivot: Vector3 = Vector3.ZERO
var _anchor: Vector3 = Vector3.ZERO  # Current sector's global_position: the map's origin
var _sector_labels: Array = []  # [{label, position}]
var _dragging: bool = false


func _ready() -> void:
	_viewport.own_world = true
	var header = $Panel/Layout/Header
	header.get_node("ButtonClose").connect("pressed", self, "close")
	header.get_node("ButtonRotLeft").connect("pressed", self, "orbit", [-ORBIT_STEP, 0.0])
	header.get_node("ButtonRotRight").connect("pressed", self, "orbit", [ORBIT_STEP, 0.0])
	header.get_node("ButtonRotUp").connect("pressed", self, "orbit", [0.0, ORBIT_STEP])
	header.get_node("ButtonRotDown").connect("pressed", self, "orbit", [0.0, -ORBIT_STEP])
	header.get_node("ButtonZoomIn").connect("pressed", self, "zoom", [1.0 / ZOOM_STEP])
	header.get_node("ButtonZoomOut").connect("pressed", self, "zoom", [ZOOM_STEP])
	header.get_node("ButtonPanLeft").connect("pressed", self, "pan", [Vector2(-1, 0)])
	header.get_node("ButtonPanRight").connect("pressed", self, "pan", [Vector2(1, 0)])
	header.get_node("ButtonPanUp").connect("pressed", self, "pan", [Vector2(0, 1)])
	header.get_node("ButtonPanDown").connect("pressed", self, "pan", [Vector2(0, -1)])
	header.get_node("ButtonReset").connect("pressed", self, "reset_camera")
	_viewport_container.connect("gui_input", self, "_on_map_gui_input")
	set_process(false)


func open() -> void:
	visible = true
	populate()
	reset_camera()
	set_process(true)


func close() -> void:
	visible = false
	set_process(false)
	_clear()


func _process(_delta: float) -> void:
	_update_labels()


# =========================================================================
# === CONTENT =============================================================
# =========================================================================

func populate() -> void:
	_clear()
	var current = TemplateDatabase.locations.get(GameState.current_sector_id)
	_anchor = current.global_position if current != null else Vector3.ZERO
	var nebulas = Spatial.new()
	nebulas.name = "Nebulas"
	nebulas.translation = Constants.get_reference_origin_offset(_anchor)
	nebulas.add_child(GLOBAL_NEBULAS_SCENE.instance())
	_content.add_child(nebulas)
	for sector_id in TemplateDatabase.locations:
		_add_sector(sector_id, TemplateDatabase.locations[sector_id])
	_add_routes()
	_add_axes()


func _clear() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for child in _labels.get_children():
		_labels.remove_child(child)
		child.queue_free()
	_sector_labels.clear()


func _add_sector(sector_id: String, template) -> void:
	var is_current: bool = sector_id == GameState.current_sector_id
	var sector_type: String = TemplateDatabase.get_sector_type(sector_id)
	var color: Color = COLOR_CURRENT if is_current else Constants.get_jump_type_color(sector_type)
	var position: Vector3 = template.global_position - _anchor

	var sphere = SphereMesh.new()
	sphere.radius = MARKER_RADIUS * (CURRENT_MARKER_SCALE if is_current else 1.0)
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var marker = MeshInstance.new()
	marker.name = "Sector_" + sector_id
	marker.mesh = sphere
	marker.material_override = _unshaded_material(color)
	marker.translation = position
	_content.add_child(marker)

	var label = Label.new()
	label.name = "Label_" + sector_id
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = describe_sector(sector_id, template, is_current)
	label.add_color_override("font_color", color)
	label.add_color_override("font_color_shadow", Color(0, 0, 0, 0.8))
	_labels.add_child(label)
	_sector_labels.append({"label": label, "position": position})


static func describe_sector(sector_id: String, template, is_current: bool) -> String:
	var pos: Vector3 = template.global_position / 1000.0
	return "%s%s\n%s  (%d, %d, %d) km\nROUTES %d" % [
		template.location_name, "  (HERE)" if is_current else "",
		TemplateDatabase.get_sector_type(sector_id).to_upper(), pos.x, pos.y, pos.z,
		template.connections.size(),
	]


func _add_routes() -> void:
	var lines = ImmediateGeometry.new()
	lines.name = "Routes"
	lines.material_override = _unshaded_material(COLOR_ROUTE)
	lines.begin(Mesh.PRIMITIVE_LINES)
	for sector_id in TemplateDatabase.locations:
		var template = TemplateDatabase.locations[sector_id]
		for target_id in template.connections:
			var target = TemplateDatabase.locations.get(target_id)
			# Routes run both ways: draw each pair once.
			if target == null or (sector_id > target_id and sector_id in target.connections):
				continue
			lines.add_vertex(template.global_position - _anchor)
			lines.add_vertex(target.global_position - _anchor)
	lines.end()
	_content.add_child(lines)


# Red, green, blue: +X, +Y, +Z at the current sector.
func _add_axes() -> void:
	var axes = ImmediateGeometry.new()
	axes.name = "Axes"
	var material = _unshaded_material(Color.white)
	material.vertex_color_use_as_albedo = true
	axes.material_override = material
	axes.begin(Mesh.PRIMITIVE_LINES)
	for axis in [[Vector3.RIGHT, Color.red], [Vector3.UP, Color.green], [Vector3.BACK, Color.blue]]:
		axes.set_color(axis[1])
		axes.add_vertex(Vector3.ZERO)
		axes.add_vertex(axis[0] * AXIS_LENGTH)
	axes.end()
	_content.add_child(axes)


func _unshaded_material(color: Color) -> SpatialMaterial:
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.flags_transparent = color.a < 1.0
	material.albedo_color = color
	return material


func _update_labels() -> void:
	for entry in _sector_labels:
		var label: Label = entry.label
		label.visible = not _camera.is_position_behind(entry.position)
		if label.visible:
			label.rect_position = _camera.unproject_position(entry.position) + Vector2(16, -16)


# =========================================================================
# === CAMERA ==============================================================
# =========================================================================

func reset_camera() -> void:
	_yaw = 0.0
	_pitch = DEFAULT_PITCH
	_zoom = DEFAULT_ZOOM
	_pivot = Vector3.ZERO
	_update_camera()


func orbit(delta_yaw: float, delta_pitch: float) -> void:
	_yaw += delta_yaw
	_pitch = clamp(_pitch + delta_pitch, -1.4, 1.4)
	_update_camera()


func zoom(factor: float) -> void:
	_zoom = clamp(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_update_camera()


# Moves the pivot across the view: x right, y up.
func pan(direction: Vector2) -> void:
	var basis: Basis = _camera.global_transform.basis
	_pivot += (basis.x * direction.x + basis.y * direction.y) * _zoom * PAN_STEP
	_update_camera()


func _update_camera() -> void:
	var offset = Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _zoom
	_camera.translation = _pivot + offset
	_camera.look_at(_pivot, Vector3.UP)
	_camera.far = _zoom + MAX_ZOOM


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == BUTTON_WHEEL_UP:
			zoom(1.0 / ZOOM_STEP)
		elif event.pressed and event.button_index == BUTTON_WHEEL_DOWN:
			zoom(ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		orbit(-event.relative.x * DRAG_ORBIT_PER_PX, event.relative.y * DRAG_ORBIT_PER_PX)
