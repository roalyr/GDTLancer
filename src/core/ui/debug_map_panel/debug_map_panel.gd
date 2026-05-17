#
# PROJECT: GDTLancer
# MODULE: debug_map_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §3.3, §6.4; TACTICAL_TODO.md §TASK_2
# LOG_REF: 2026-05-17 15:43:57
#

extends CanvasLayer

# --- Camera defaults ---
const DEFAULT_ORBIT_DISTANCE = 500000.0
const MIN_ZOOM = 1000.0
const MAX_ZOOM = 800000.0
const ORBIT_STEP = 0.15  # radians per button press
const ZOOM_FACTOR = 1.3
const PAN_STEP_RATIO = 0.1  # fraction of current zoom distance
const MOUSE_ORBIT_SENSITIVITY = ORBIT_STEP / 50.0
const MOUSE_WHEEL_ZOOM_BLEND = 0.35
const AXIS_LENGTH = 500000.0
const AXIS_ARROW_SIZE = 15000.0
const AXIS_ARROW_SPREAD = 9000.0
const AXIS_NOTCH_SIZE = 5000.0
const AXIS_LABEL_WORLD_OFFSET = 14000.0
const AXIS_TRUNK_OFFSET = 1200.0
const MAP_LABEL_BASE_FONT_SIZE = 18
const SECTOR_LABEL_FONT_SCALE = 1.5
const SECTOR_LABEL_FONT_SIZE = int(MAP_LABEL_BASE_FONT_SIZE * SECTOR_LABEL_FONT_SCALE)
const SECTOR_LABEL_MAX_WIDTH = 260.0
const SECTOR_LABEL_BOX_HEIGHT = 96.0
const SECTOR_LABEL_GAP = 10.0
const SECTOR_LABEL_FONT_PATH = "res://assets/fonts/Roboto_Condensed/static/RobotoCondensed-Regular.ttf"
const GLOBAL_NEBULAS_SCENE = preload("res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn")
const AUTHORED_SECTOR_COLOR = Color(0.3, 0.8, 1.0, 1.0)
const AUTHORED_ROUTE_COLOR = Color(0.5, 0.8, 0.5, 0.6)
const DISCOVERED_SECTOR_FALLBACK_COLOR = Color(0.95, 0.72, 0.34, 1.0)

# --- Node references ---
onready var _panel = $Panel
onready var _viewport_container = $Panel/VBoxContainer/MapArea/ViewportContainer
onready var _viewport = $Panel/VBoxContainer/MapArea/ViewportContainer/Viewport
onready var _camera = $Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapCamera
onready var _map_content = $Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent
onready var _label_overlay = $Panel/VBoxContainer/MapArea/LabelOverlay
onready var _btn_axes = $Panel/VBoxContainer/HeaderRow/BtnAxes

# --- Camera state ---
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.5  # ~30 degrees
var _zoom_distance: float = DEFAULT_ORBIT_DISTANCE
var _pivot: Vector3 = Vector3.ZERO
var _map_world_anchor: Vector3 = Vector3.ZERO

# --- Label tracking ---
var _sector_labels: Dictionary = {}  # sector_id -> {marker: Spatial, label: Label}
var _reference_labels: Array = []  # [{label: Label, pos_3d: Vector3, screen_offset: Vector2}]
var _is_visible: bool = false
var _show_sector_coordinates: bool = false
var _show_reference_axes: bool = true
var _was_paused: bool = false
var _hidden_particles: Array = []
var _hidden_scene_nodes: Array = []
var _map_world_env: WorldEnvironment = null
var _map_nebula_holder: Spatial = null
var _is_drag_orbiting: bool = false
var _sector_label_font: DynamicFont = null


func _ready():
	_panel.visible = false
	_is_visible = false
	_sector_label_font = _build_sector_label_font()
	_configure_map_viewport_world()
	set_process(false)
	_connect_buttons()
	_refresh_axes_button_text()
	if EventBus.has_signal("sim_tick_completed"):
		if not EventBus.is_connected("sim_tick_completed", self, "_on_sim_tick_completed"):
			EventBus.connect("sim_tick_completed", self, "_on_sim_tick_completed")


func _configure_map_viewport_world():
	if not is_instance_valid(_viewport):
		return
	_viewport.own_world = true
	_viewport.render_target_clear_mode = Viewport.CLEAR_MODE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.update_worlds()


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_F4:
			_toggle_panel()
			get_tree().set_input_as_handled()
	if not _is_visible:
		return
	if event is InputEventMouse:
		_handle_map_mouse_input(event)


func _toggle_panel():
	_is_visible = not _is_visible
	_panel.visible = _is_visible
	if _is_visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		pause_mode = Node.PAUSE_MODE_PROCESS
		_hide_camera_particles()
		_hide_scene_models()
		_setup_map_environment()
		_reset_camera()
		_populate_map()
		set_process(true)
	else:
		_is_drag_orbiting = false
		_clear_map()
		_cleanup_map_environment()
		_restore_scene_models()
		_restore_camera_particles()
		set_process(false)
		if not _was_paused:
			get_tree().paused = false


func _process(_delta):
	if not _is_visible:
		return
	_update_label_positions()


func _on_sim_tick_completed(_tick_count):
	if _is_visible:
		_populate_map()


func _handle_map_mouse_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed and _is_mouse_over_map_viewport(event.position):
				_is_drag_orbiting = true
				get_tree().set_input_as_handled()
			else:
				_is_drag_orbiting = false
		elif event.pressed and _is_mouse_over_map_viewport(event.position):
			var wheel_factor = _get_mouse_wheel_zoom_factor()
			if event.button_index == BUTTON_WHEEL_UP:
				_zoom(1.0 / wheel_factor)
				get_tree().set_input_as_handled()
			elif event.button_index == BUTTON_WHEEL_DOWN:
				_zoom(wheel_factor)
				get_tree().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if not _is_drag_orbiting:
			return
		if not _is_mouse_over_map_viewport(event.position):
			_is_drag_orbiting = false
			return
		_orbit_rotate(
			event.relative.x * MOUSE_ORBIT_SENSITIVITY,
			-event.relative.y * MOUSE_ORBIT_SENSITIVITY
		)
		get_tree().set_input_as_handled()


func _is_mouse_over_map_viewport(mouse_pos: Vector2) -> bool:
	return _viewport_container.get_global_rect().has_point(mouse_pos)


func _get_mouse_wheel_zoom_factor() -> float:
	return 1.0 + ((ZOOM_FACTOR - 1.0) * MOUSE_WHEEL_ZOOM_BLEND)


# =========================================================================
# === MAP ENVIRONMENT (nebula + background) ===============================
# =========================================================================

func _setup_map_environment():
	_configure_map_viewport_world()
	# Add WorldEnvironment so the map viewport has the same background as the game
	if not is_instance_valid(_map_world_env):
		var env_res = load("res://assets/art/environments/global_environment.tres")
		if env_res:
			_map_world_env = WorldEnvironment.new()
			_map_world_env.environment = env_res
			_viewport.add_child(_map_world_env)
	if not is_instance_valid(_map_nebula_holder):
		_map_nebula_holder = Spatial.new()
		_map_nebula_holder.name = "MapNebulaHolder"
		_map_nebula_holder.add_child(GLOBAL_NEBULAS_SCENE.instance())
		_viewport.add_child(_map_nebula_holder)
	_sync_map_nebula_holder()


func _cleanup_map_environment():
	if is_instance_valid(_map_world_env):
		_map_world_env.queue_free()
		_map_world_env = null
	if is_instance_valid(_map_nebula_holder):
		_map_nebula_holder.queue_free()
		_map_nebula_holder = null


# =========================================================================
# === CAMERA PARTICLE HIDE/RESTORE =======================================
# =========================================================================

func _hide_camera_particles():
	_hidden_particles.clear()
	var cam = GlobalRefs.main_camera
	if not cam:
		return
	for child in cam.get_children():
		if child is CPUParticles and child.visible:
			child.visible = false
			_hidden_particles.append(child)


func _restore_camera_particles():
	for p in _hidden_particles:
		if is_instance_valid(p):
			p.visible = true
	_hidden_particles.clear()


func _hide_scene_models():
	_hidden_scene_nodes.clear()
	var zone = GameState.current_zone_instance
	if not is_instance_valid(zone):
		return
	var scene_assets = zone.find_node("SceneAssets", true, false)
	if is_instance_valid(scene_assets) and scene_assets.visible:
		scene_assets.visible = false
		_hidden_scene_nodes.append(scene_assets)
	var playable_area = zone.find_node("_PlayableArea", true, false)
	if is_instance_valid(playable_area) and playable_area.visible:
		playable_area.visible = false
		_hidden_scene_nodes.append(playable_area)


func _restore_scene_models():
	for node in _hidden_scene_nodes:
		if is_instance_valid(node):
			node.visible = true
	_hidden_scene_nodes.clear()


# =========================================================================
# === MAP POPULATION =====================================================
# =========================================================================

func _populate_map():
	_map_world_anchor = _get_current_sector_world_anchor()
	_sync_map_nebula_holder()
	_clear_map()
	_create_sector_markers()
	_create_connection_lines()
	_set_reference_axes_visible(_show_reference_axes)
	_update_camera()


func _clear_map():
	for child in _map_content.get_children():
		child.queue_free()
	for child in _label_overlay.get_children():
		child.queue_free()
	_sector_labels.clear()
	_reference_labels.clear()


func _create_sector_markers():
	for sector_id in TemplateDatabase.locations:
		var template = TemplateDatabase.locations[sector_id]
		var global_position: Vector3 = _get_template_global_position(template)
		if template == null or global_position == null:
			continue
		var pos: Vector3 = _to_map_space_position(global_position)
		var marker_color: Color = _get_sector_marker_color(sector_id, template)
		var label_color: Color = _get_sector_label_color(sector_id, template)
		var marker_radius: float = _get_sector_marker_radius(sector_id, template)

		# Sector marker sphere
		var mesh_instance = MeshInstance.new()
		var sphere = SphereMesh.new()
		sphere.radius = marker_radius
		sphere.height = marker_radius * 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		mesh_instance.mesh = sphere

		var mat = SpatialMaterial.new()
		mat.flags_unshaded = true
		mat.albedo_color = marker_color
		mesh_instance.material_override = mat

		mesh_instance.transform.origin = pos
		mesh_instance.name = "Sector_%s" % sector_id
		_map_content.add_child(mesh_instance)

		# Create label in overlay
		var label = Label.new()
		_configure_sector_label(label)
		var loc_name: String = _get_template_location_name(template, sector_id)
		label.text = loc_name
		label.add_color_override("font_color", label_color)
		label.add_constant_override("shadow_offset_x", 1)
		label.add_constant_override("shadow_offset_y", 1)
		label.add_color_override("font_color_shadow", Color(0, 0, 0, 0.8))
		_label_overlay.add_child(label)

		_sector_labels[sector_id] = {
			"marker": mesh_instance,
			"label": label,
			"base_name": loc_name,
			"pos_3d": pos,
			"screen_offset": _get_sector_label_screen_offset(),
		}
	_refresh_sector_label_texts()


func _configure_sector_label(label: Label):
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap = true
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.rect_min_size = Vector2(SECTOR_LABEL_MAX_WIDTH, SECTOR_LABEL_BOX_HEIGHT)
	label.rect_size = label.rect_min_size
	if is_instance_valid(_sector_label_font):
		label.add_font_override("font", _sector_label_font)


func _build_sector_label_font() -> DynamicFont:
	var font_data = load(SECTOR_LABEL_FONT_PATH)
	if not font_data:
		return null
	var font = DynamicFont.new()
	font.font_data = font_data
	font.size = SECTOR_LABEL_FONT_SIZE
	return font


func _get_sector_label_screen_offset() -> Vector2:
	return Vector2(-SECTOR_LABEL_MAX_WIDTH * 0.5, -(SECTOR_LABEL_BOX_HEIGHT + SECTOR_LABEL_GAP))


func _refresh_sector_label_texts():
	for sector_id in _sector_labels:
		var data = _sector_labels[sector_id]
		var label: Label = data["label"]
		label.text = _build_sector_label_text(sector_id, data)


func _build_sector_label_text(sector_id: String, data: Dictionary) -> String:
	var name_text = data.get("base_name", sector_id)
	var template = TemplateDatabase.locations.get(sector_id)
	if _is_discovered_sector(sector_id, template):
		name_text = "DISC %s" % name_text
	if sector_id == GameState.current_sector_id:
		name_text = ">> %s <<" % name_text
	if not _show_sector_coordinates:
		return name_text
	return "%s\n[%s]" % [name_text, _format_sector_coordinates(data.get("pos_3d", Vector3.ZERO))]


func _format_sector_coordinates(pos: Vector3) -> String:
	return "%d, %d, %d" % [int(round(pos.x)), int(round(pos.y)), int(round(pos.z))]


func _create_connection_lines():
	var drawn_pairs = {}
	var ig = ImmediateGeometry.new()
	ig.name = "ConnectionLines"

	var mat = SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.vertex_color_use_as_albedo = true
	ig.material_override = mat

	ig.begin(Mesh.PRIMITIVE_LINES)
	for sector_id in GameState.world_topology:
		var topo = GameState.world_topology[sector_id]
		var connections = topo.get("connections", [])
		for target_id in connections:
			# Deduplicate: only draw A→B if A < B alphabetically
			var pair_key = sector_id if sector_id < target_id else target_id
			var pair_val = target_id if sector_id < target_id else sector_id
			var key = pair_key + ":" + pair_val
			if drawn_pairs.has(key):
				continue
			drawn_pairs[key] = true

			var from_pos = _get_sector_position(sector_id)
			var to_pos = _get_sector_position(target_id)
			if from_pos == null or to_pos == null:
				continue
			ig.set_color(_get_connection_line_color(sector_id, target_id))
			ig.add_vertex(from_pos)
			ig.add_vertex(to_pos)
	ig.end()
	_map_content.add_child(ig)


func _create_reference_axes():
	var ig = ImmediateGeometry.new()
	ig.name = "ReferenceAxes"

	var mat = SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.vertex_color_use_as_albedo = true
	ig.material_override = mat

	var axis_configs = [
		{
			"id": "X",
			"dir": Vector3(1, 0, 0),
			"color": Color(1.0, 0.25, 0.25, 1.0),
			"notch_dir": Vector3(0, 1, 0),
			"line_offset_dir": Vector3(0, 0, 1),
			"arrow_dirs": [Vector3(0, 1, 0), Vector3(0, 0, 1)],
		},
		{
			"id": "Y",
			"dir": Vector3(0, 1, 0),
			"color": Color(0.25, 1.0, 0.25, 1.0),
			"notch_dir": Vector3(1, 0, 0),
			"line_offset_dir": Vector3(0, 0, 1),
			"arrow_dirs": [Vector3(1, 0, 0), Vector3(0, 0, 1)],
		},
		{
			"id": "Z",
			"dir": Vector3(0, 0, 1),
			"color": Color(0.25, 0.55, 1.0, 1.0),
			"notch_dir": Vector3(0, 1, 0),
			"line_offset_dir": Vector3(1, 0, 0),
			"arrow_dirs": [Vector3(1, 0, 0), Vector3(0, 1, 0)],
		},
	]
	var axis_origin = Constants.get_reference_origin_offset(_map_world_anchor)
	var notch_specs = [
		{"distance": 100000.0, "text": "1e5"},
		{"distance": 200000.0, "text": "2e5"},
		{"distance": 300000.0, "text": "3e5"},
		{"distance": 400000.0, "text": "4e5"},
		{"distance": 500000.0, "text": "5e5"},
	]

	ig.begin(Mesh.PRIMITIVE_LINES)
	for axis_data in axis_configs:
		var axis_id = axis_data["id"]
		var axis_dir: Vector3 = axis_data["dir"]
		var axis_color: Color = axis_data["color"]
		var notch_dir: Vector3 = axis_data["notch_dir"]
		var line_offset_dir: Vector3 = axis_data["line_offset_dir"]
		var axis_end = axis_origin + axis_dir * AXIS_LENGTH

		ig.set_color(axis_color)
		_add_axis_trunk_lines(ig, axis_origin, axis_end, line_offset_dir)

		for arrow_dir in axis_data["arrow_dirs"]:
			var arrow_base = axis_end - axis_dir * AXIS_ARROW_SIZE
			ig.add_vertex(axis_end)
			ig.add_vertex(arrow_base + arrow_dir * AXIS_ARROW_SPREAD)
			ig.add_vertex(axis_end)
			ig.add_vertex(arrow_base - arrow_dir * AXIS_ARROW_SPREAD)

		_create_projected_overlay_label(
			"AxisLabel_%s" % axis_id,
			axis_id,
			axis_end + axis_dir * AXIS_LABEL_WORLD_OFFSET,
			axis_color,
			Vector2(4, -12)
		)

		for notch_spec in notch_specs:
			var notch_distance = notch_spec["distance"]
			var notch_center = axis_origin + axis_dir * notch_distance
			ig.add_vertex(notch_center - notch_dir * AXIS_NOTCH_SIZE)
			ig.add_vertex(notch_center + notch_dir * AXIS_NOTCH_SIZE)
			_create_projected_overlay_label(
				"AxisNotch_%s_%s" % [axis_id, notch_spec["text"]],
				notch_spec["text"],
				notch_center + notch_dir * AXIS_LABEL_WORLD_OFFSET,
				Color(axis_color.r, axis_color.g, axis_color.b, 0.9),
				Vector2(4, -10)
			)
	ig.end()
	_map_content.add_child(ig)


func _set_reference_axes_visible(visible: bool):
	var axes = _map_content.get_node_or_null("ReferenceAxes")
	if visible:
		if not is_instance_valid(axes) or _reference_labels.empty():
			_create_reference_axes()
			axes = _map_content.get_node_or_null("ReferenceAxes")
	if is_instance_valid(axes):
		axes.visible = visible
	for data in _reference_labels:
		var label: Label = data["label"]
		if is_instance_valid(label):
			label.visible = visible
	_refresh_axes_button_text()


func _refresh_axes_button_text():
	if is_instance_valid(_btn_axes):
		_btn_axes.text = "Axes On" if _show_reference_axes else "Axes Off"


func _add_axis_trunk_lines(ig: ImmediateGeometry, from_pos: Vector3, to_pos: Vector3, offset_dir: Vector3):
	ig.add_vertex(from_pos)
	ig.add_vertex(to_pos)

	var offset = offset_dir * AXIS_TRUNK_OFFSET
	ig.add_vertex(from_pos + offset)
	ig.add_vertex(to_pos + offset)
	ig.add_vertex(from_pos - offset)
	ig.add_vertex(to_pos - offset)


func _create_projected_overlay_label(node_name: String, text: String, pos_3d: Vector3, color: Color, screen_offset: Vector2):
	var label = Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_color_override("font_color", color)
	label.add_constant_override("shadow_offset_x", 1)
	label.add_constant_override("shadow_offset_y", 1)
	label.add_color_override("font_color_shadow", Color(0, 0, 0, 0.8))
	_label_overlay.add_child(label)
	_reference_labels.append({
		"label": label,
		"pos_3d": pos_3d,
		"screen_offset": screen_offset,
	})


func _get_template_value(template, key: String, default_value = null):
	if template == null:
		return default_value
	if template is Dictionary:
		return template.get(key, default_value)
	var value = template.get(key)
	return value if value != null else default_value


func _get_template_global_position(template):
	var global_position = _get_template_value(template, "global_position", null)
	return global_position if global_position is Vector3 else null


func _get_template_location_name(template, fallback_sector_id: String) -> String:
	var location_name = _get_template_value(template, "location_name", fallback_sector_id)
	return str(location_name) if str(location_name) != "" else fallback_sector_id


func _is_discovered_sector(sector_id: String, template = null) -> bool:
	var resolved_template = template if template != null else TemplateDatabase.locations.get(sector_id)
	var hints = _get_template_value(resolved_template, "procedural_hints", {})
	if hints is Dictionary and bool(hints.get("low_visibility", false)):
		return true
	return sector_id.begins_with("discovered_")


func _get_discovery_sector_color(sector_id: String, template = null) -> Color:
	var resolved_template = template if template != null else TemplateDatabase.locations.get(sector_id)
	var procedural_type: String = str(_get_template_value(resolved_template, "procedural_type", "deep_space"))
	match procedural_type:
		"asteroid_field":
			return Color(0.95, 0.72, 0.34, 1.0)
		"comet_shoal":
			return Color(0.66, 0.9, 1.0, 1.0)
		"rogue_planet":
			return Color(0.62, 0.72, 0.86, 1.0)
		"dark_nebula":
			return Color(0.44, 0.74, 0.69, 1.0)
		"remnant_field":
			return Color(0.82, 0.62, 0.54, 1.0)
		_:
			return DISCOVERED_SECTOR_FALLBACK_COLOR


func _get_sector_marker_color(sector_id: String, template = null) -> Color:
	if sector_id == GameState.current_sector_id:
		return Color(1.0, 1.0, 0.2, 1.0)
	if _is_discovered_sector(sector_id, template):
		return _get_discovery_sector_color(sector_id, template)
	return AUTHORED_SECTOR_COLOR


func _get_sector_label_color(sector_id: String, template = null) -> Color:
	if sector_id == GameState.current_sector_id:
		return Color(1, 1, 0.2, 1.0)
	if _is_discovered_sector(sector_id, template):
		var discovery_color: Color = _get_discovery_sector_color(sector_id, template)
		return Color(discovery_color.r, discovery_color.g, discovery_color.b, 0.96)
	return Color(1, 1, 1, 0.9)


func _get_sector_marker_radius(sector_id: String, template = null) -> float:
	if sector_id == GameState.current_sector_id:
		return 3000.0
	if _is_discovered_sector(sector_id, template):
		return 2400.0
	return 2000.0


func _get_connection_line_color(source_sector_id: String, target_sector_id: String) -> Color:
	var source_template = TemplateDatabase.locations.get(source_sector_id)
	var target_template = TemplateDatabase.locations.get(target_sector_id)
	if _is_discovered_sector(source_sector_id, source_template):
		var source_color: Color = _get_discovery_sector_color(source_sector_id, source_template)
		return Color(source_color.r, source_color.g, source_color.b, 0.78)
	if _is_discovered_sector(target_sector_id, target_template):
		var target_color: Color = _get_discovery_sector_color(target_sector_id, target_template)
		return Color(target_color.r, target_color.g, target_color.b, 0.78)
	return AUTHORED_ROUTE_COLOR


func _get_sector_position(sector_id: String):
	if TemplateDatabase.locations.has(sector_id):
		var template = TemplateDatabase.locations[sector_id]
		var global_position: Vector3 = _get_template_global_position(template)
		if global_position != null:
			return _to_map_space_position(global_position)
	return null


func _sync_map_nebula_holder():
	if not is_instance_valid(_map_nebula_holder):
		return
	_map_nebula_holder.transform.origin = Constants.get_reference_origin_offset(_map_world_anchor)


func _to_map_space_position(world_position: Vector3) -> Vector3:
	return world_position - _map_world_anchor


# =========================================================================
# === LABEL PROJECTION ===================================================
# =========================================================================

func _update_label_positions():
	if not _camera or not _viewport:
		return
	var vp_size = _viewport.size
	if vp_size.x == 0 or vp_size.y == 0:
		return

	for sector_id in _sector_labels:
		var data = _sector_labels[sector_id]
		_update_projected_label(data["label"], data["pos_3d"], data["screen_offset"], vp_size, 50.0)

	for data in _reference_labels:
		if not _show_reference_axes:
			var hidden_label: Label = data["label"]
			if is_instance_valid(hidden_label):
				hidden_label.visible = false
			continue
		_update_projected_label(
			data["label"],
			data["pos_3d"],
			data["screen_offset"],
			vp_size,
			25.0
		)


func _update_projected_label(label: Label, pos_3d: Vector3, screen_offset: Vector2, vp_size: Vector2, padding: float):
	var cam_transform = _camera.global_transform
	var to_point = pos_3d - cam_transform.origin
	if cam_transform.basis.z.dot(to_point) > 0:
		label.visible = false
		return

	var screen_pos = _camera.unproject_position(pos_3d)
	label.rect_position = screen_pos + screen_offset
	label.visible = (screen_pos.x >= -padding and screen_pos.x <= vp_size.x + padding
		and screen_pos.y >= -padding and screen_pos.y <= vp_size.y + padding)


# =========================================================================
# === CAMERA CONTROLS ====================================================
# =========================================================================

func _update_camera():
	var offset = Vector3(
		_zoom_distance * cos(_orbit_pitch) * sin(_orbit_yaw),
		_zoom_distance * sin(_orbit_pitch),
		_zoom_distance * cos(_orbit_pitch) * cos(_orbit_yaw)
	)
	_camera.transform.origin = _pivot + offset
	_camera.look_at(_pivot, Vector3.UP)


func _orbit_rotate(dyaw: float, dpitch: float):
	_orbit_yaw += dyaw
	_orbit_pitch = clamp(_orbit_pitch + dpitch, -1.4, 1.4)
	_update_camera()


func _zoom(factor: float):
	_zoom_distance = clamp(_zoom_distance * factor, MIN_ZOOM, MAX_ZOOM)
	_update_camera()


func _pan(direction: Vector3):
	var step = _zoom_distance * PAN_STEP_RATIO
	var cam_basis = _camera.global_transform.basis
	_pivot += cam_basis.x * direction.x * step
	_pivot += cam_basis.y * direction.y * step
	_update_camera()


func _reset_camera():
	_orbit_yaw = 0.0
	_orbit_pitch = 0.5
	_zoom_distance = DEFAULT_ORBIT_DISTANCE
	_pivot = Vector3.ZERO
	_update_camera()


func _get_current_sector_world_anchor() -> Vector3:
	var current_sector_id: String = GameState.current_sector_id
	if current_sector_id != "" and TemplateDatabase.locations.has(current_sector_id):
		var template = TemplateDatabase.locations[current_sector_id]
		var global_position: Vector3 = _get_template_global_position(template)
		if global_position != null:
			return global_position
	return Vector3.ZERO


# =========================================================================
# === BUTTON WIRING ======================================================
# =========================================================================

func _connect_buttons():
	var header = $Panel/VBoxContainer/HeaderRow
	header.get_node("BtnRotL").connect("pressed", self, "_on_rot_l")
	header.get_node("BtnRotR").connect("pressed", self, "_on_rot_r")
	header.get_node("BtnRotU").connect("pressed", self, "_on_rot_u")
	header.get_node("BtnRotD").connect("pressed", self, "_on_rot_d")
	header.get_node("BtnZoomIn").connect("pressed", self, "_on_zoom_in")
	header.get_node("BtnZoomOut").connect("pressed", self, "_on_zoom_out")
	header.get_node("BtnAxes").connect("pressed", self, "_on_toggle_axes")
	header.get_node("BtnCoords").connect("pressed", self, "_on_toggle_coords")
	header.get_node("BtnPanL").connect("pressed", self, "_on_pan_l")
	header.get_node("BtnPanR").connect("pressed", self, "_on_pan_r")
	header.get_node("BtnPanU").connect("pressed", self, "_on_pan_u")
	header.get_node("BtnPanD").connect("pressed", self, "_on_pan_d")
	header.get_node("BtnReset").connect("pressed", self, "_on_reset")
	header.get_node("BtnClose").connect("pressed", self, "_on_close")


func _on_rot_l(): _orbit_rotate(-ORBIT_STEP, 0.0)
func _on_rot_r(): _orbit_rotate(ORBIT_STEP, 0.0)
func _on_rot_u(): _orbit_rotate(0.0, ORBIT_STEP)
func _on_rot_d(): _orbit_rotate(0.0, -ORBIT_STEP)
func _on_zoom_in(): _zoom(1.0 / ZOOM_FACTOR)
func _on_zoom_out(): _zoom(ZOOM_FACTOR)
func _on_toggle_axes():
	_show_reference_axes = not _show_reference_axes
	_set_reference_axes_visible(_show_reference_axes)
func _on_toggle_coords():
	_show_sector_coordinates = not _show_sector_coordinates
	_refresh_sector_label_texts()
func _on_pan_l(): _pan(Vector3(-1, 0, 0))
func _on_pan_r(): _pan(Vector3(1, 0, 0))
func _on_pan_u(): _pan(Vector3(0, 1, 0))
func _on_pan_d(): _pan(Vector3(0, -1, 0))
func _on_reset(): _reset_camera()
func _on_close(): _toggle_panel()


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus and EventBus.is_connected("sim_tick_completed", self, "_on_sim_tick_completed"):
			EventBus.disconnect("sim_tick_completed", self, "_on_sim_tick_completed")
