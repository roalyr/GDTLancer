# PROJECT: GDTLancer
# MODULE: debug_map_panel.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: debug_map_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_CONTENT-CREATION-MANUAL.md §5.4, §6.3; TRUTH_SIMULATION-GRAPH.md §3.3, §6.4; TACTICAL_TODO.md TASK_2
# LOG_REF: 2026-05-26 18:46:00
#

extends CanvasLayer

const MainHUDScript = preload("res://src/core/ui/main_hud/main_hud.gd")

# --- Camera defaults ---
const DEFAULT_ORBIT_DISTANCE = 500000.0
const MIN_ZOOM = 1000.0
const MAX_ZOOM = 800000.0
const DEFAULT_MAP_CAMERA_FOV = 60.0
const MIN_MAP_CAMERA_FOV = 35.0
const MAX_MAP_CAMERA_FOV = 95.0
const MAP_CAMERA_FOV_STEP = 5.0
const ORBIT_STEP = 0.15  # radians per button press
const ZOOM_FACTOR = 1.3
const PAN_STEP_RATIO = 0.1  # fraction of current zoom distance
const MOUSE_ORBIT_SENSITIVITY = ORBIT_STEP / 50.0
const MOUSE_PAN_SENSITIVITY = 1.0 / 80.0
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
const MAP_LABEL_CAMERA_DISTANCE_FADE_START = 1e5
const MAP_LABEL_CAMERA_DISTANCE_FADE_RANGE = 1e6
const MAP_LABEL_NORMALIZED_DISTANCE_POW = 2.5
const SECTOR_LABEL_MAX_WIDTH = 260.0
const SECTOR_LABEL_BOX_HEIGHT = 96.0
const SECTOR_LABEL_GAP = 10.0
const CONTRACT_COUNT_LABEL_FONT_SIZE = MAP_LABEL_BASE_FONT_SIZE
const CONTRACT_COUNT_LABEL_MAX_WIDTH = 132.0
const CONTRACT_COUNT_LABEL_BOX_HEIGHT = 30.0
const CONTRACT_COUNT_LABEL_COLOR = Color(1.0, 0.78, 0.24, 0.94)
const CONTRACT_TOGGLE_BUTTON_MIN_WIDTH = 126.0
const SECTOR_LABEL_FONT_PATH = "res://assets/fonts/Roboto_Condensed/static/RobotoCondensed-Regular.ttf"
const GLOBAL_NEBULAS_SCENE = preload("res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn")
const AUTHORED_SECTOR_COLOR = Color(0.3, 0.8, 1.0, 1.0)
const AUTHORED_ROUTE_COLOR = Color(0.5, 0.8, 0.5, 0.6)
const DISCOVERED_SECTOR_FALLBACK_COLOR = Color(0.95, 0.72, 0.34, 1.0)
const READABILITY_BUTTON_MIN_WIDTH = 96.0
const TASK2_BUTTON_MIN_WIDTH = 78.0
const BTN_LABELS = "BtnLabels"
const BTN_CONTRACT_COUNTS = "BtnContractCounts"
const BTN_LINES = "BtnLines"
const BTN_ICONS = "BtnIcons"
const BTN_FOV_IN = "BtnFovIn"
const BTN_FOV_OUT = "BtnFovOut"
const BTN_AA = "BtnAA"

# --- Node references ---
onready var _panel = $Panel
onready var _header_row: HBoxContainer = $Panel/VBoxContainer/HeaderRow
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
var _is_drag_panning: bool = false
var _sector_label_font: DynamicFont = null
var _contract_count_label_font: DynamicFont = null
var _show_sector_labels: bool = true
var _show_contract_counts: bool = true
var _show_connection_lines: bool = true
var _show_sector_icons: bool = true


func _ready():
	_panel.visible = false
	_is_visible = false
	_sector_label_font = _build_sector_label_font()
	_contract_count_label_font = _build_contract_count_label_font()
	_ensure_task2_buttons()
	_ensure_readability_buttons()
	_configure_map_viewport_world()
	set_process(false)
	_connect_buttons()
	_refresh_axes_button_text()
	_refresh_readability_button_texts()
	_refresh_task2_button_texts()
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
		_refresh_task2_button_texts()
		set_process(true)
	else:
		_is_drag_orbiting = false
		_is_drag_panning = false
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
				_is_drag_panning = false
				get_tree().set_input_as_handled()
			else:
				_is_drag_orbiting = false
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed and _is_mouse_over_map_viewport(event.position):
				_is_drag_panning = true
				_is_drag_orbiting = false
				get_tree().set_input_as_handled()
			else:
				_is_drag_panning = false
		elif event.pressed and _is_mouse_over_map_viewport(event.position):
			var wheel_factor = _get_mouse_wheel_zoom_factor()
			if event.button_index == BUTTON_WHEEL_UP:
				_zoom(1.0 / wheel_factor)
				get_tree().set_input_as_handled()
			elif event.button_index == BUTTON_WHEEL_DOWN:
				_zoom(wheel_factor)
				get_tree().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _is_drag_orbiting:
			if not _is_mouse_over_map_viewport(event.position):
				_is_drag_orbiting = false
				return
			_orbit_rotate(
				event.relative.x * MOUSE_ORBIT_SENSITIVITY,
				-event.relative.y * MOUSE_ORBIT_SENSITIVITY
			)
			get_tree().set_input_as_handled()
			return
		if not _is_drag_panning:
			return
		if not _is_mouse_over_map_viewport(event.position):
			_is_drag_panning = false
			return
		_pan_from_mouse_delta(event.relative)
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
	_apply_readability_visibility_state()


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
		mesh_instance.visible = _show_sector_icons
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
		label.visible = _show_sector_labels
		_label_overlay.add_child(label)

		var contract_label = Label.new()
		_configure_contract_count_label(contract_label)
		contract_label.visible = _show_contract_counts
		_label_overlay.add_child(contract_label)

		_sector_labels[sector_id] = {
			"marker": mesh_instance,
			"label": label,
			"contract_label": contract_label,
			"base_name": loc_name,
			"pos_3d": pos,
			"screen_offset": _get_sector_label_screen_offset(),
			"contract_screen_offset": _get_contract_count_label_screen_offset(),
		}
	_refresh_sector_label_texts()
	_refresh_sector_contract_count_texts()


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
	return _build_label_font(SECTOR_LABEL_FONT_SIZE)


func _build_contract_count_label_font() -> DynamicFont:
	return _build_label_font(CONTRACT_COUNT_LABEL_FONT_SIZE)


func _build_label_font(font_size: int) -> DynamicFont:
	var font_data = load(SECTOR_LABEL_FONT_PATH)
	if not font_data:
		return null
	var font = DynamicFont.new()
	font.font_data = font_data
	font.size = font_size
	return font


func _configure_contract_count_label(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.rect_min_size = Vector2(CONTRACT_COUNT_LABEL_MAX_WIDTH, CONTRACT_COUNT_LABEL_BOX_HEIGHT)
	label.rect_size = label.rect_min_size
	if is_instance_valid(_contract_count_label_font):
		label.add_font_override("font", _contract_count_label_font)
	label.add_color_override("font_color", CONTRACT_COUNT_LABEL_COLOR)
	label.add_constant_override("shadow_offset_x", 1)
	label.add_constant_override("shadow_offset_y", 1)
	label.add_color_override("font_color_shadow", Color(0, 0, 0, 0.8))


func _get_sector_label_screen_offset() -> Vector2:
	return Vector2(-SECTOR_LABEL_MAX_WIDTH * 0.5, -(SECTOR_LABEL_BOX_HEIGHT + SECTOR_LABEL_GAP))


func _get_contract_count_label_screen_offset() -> Vector2:
	return Vector2((SECTOR_LABEL_MAX_WIDTH * 0.5) + 8.0, -(SECTOR_LABEL_BOX_HEIGHT + SECTOR_LABEL_GAP) + 8.0)


func _refresh_sector_label_texts():
	for sector_id in _sector_labels:
		var data = _sector_labels[sector_id]
		var label: Label = data["label"]
		label.text = _build_sector_label_text(sector_id, data)


func _refresh_sector_contract_count_texts() -> void:
	for sector_id in _sector_labels:
		var data = _sector_labels[sector_id]
		var contract_label: Label = data.get("contract_label", null)
		if not is_instance_valid(contract_label):
			continue
		contract_label.text = _build_contract_count_label_text(_contract_count_for_sector(sector_id))


func _build_contract_count_label_text(contract_count: int) -> String:
	return "Contracts: %d" % contract_count


func _contract_count_for_sector(sector_id: String) -> int:
	if sector_id == "":
		return 0

	var contract_count: int = 0
	var seen_occurrence_ids: Dictionary = {}
	var occurrence_ids: Array = Array(GameState.runtime_contract_occurrences_by_source_sector.get(sector_id, []))
	for occurrence_id in occurrence_ids:
		if seen_occurrence_ids.has(occurrence_id):
			continue
		seen_occurrence_ids[occurrence_id] = true
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			continue
		if not bool(occurrence.get("player_displayable", true)):
			continue
		contract_count += 1
	return contract_count


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
	ig.visible = _show_connection_lines

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


func _apply_readability_visibility_state() -> void:
	_set_connection_lines_visible(_show_connection_lines)
	_set_sector_markers_visible(_show_sector_icons)
	if _show_sector_labels or _show_contract_counts:
		_update_label_positions()
	else:
		_set_sector_labels_visible(false)
		_set_contract_count_labels_visible(false)
	_refresh_readability_button_texts()


func _set_connection_lines_visible(visible: bool) -> void:
	var connection_lines = _map_content.get_node_or_null("ConnectionLines")
	if is_instance_valid(connection_lines):
		connection_lines.visible = visible


func _set_sector_markers_visible(visible: bool) -> void:
	for sector_id in _sector_labels:
		var marker = _sector_labels[sector_id].get("marker", null)
		if is_instance_valid(marker):
			marker.visible = visible


func _set_sector_labels_visible(visible: bool) -> void:
	for sector_id in _sector_labels:
		var label = _sector_labels[sector_id].get("label", null)
		if is_instance_valid(label):
			label.visible = visible


func _set_contract_count_labels_visible(visible: bool) -> void:
	for sector_id in _sector_labels:
		var contract_label = _sector_labels[sector_id].get("contract_label", null)
		if is_instance_valid(contract_label):
			contract_label.visible = visible


func _refresh_readability_button_texts() -> void:
	var labels_button = _get_readability_button(BTN_LABELS)
	if is_instance_valid(labels_button):
		labels_button.text = "Labels On" if _show_sector_labels else "Labels Off"
	var contract_counts_button = _get_readability_button(BTN_CONTRACT_COUNTS)
	if is_instance_valid(contract_counts_button):
		contract_counts_button.text = "Contracts On" if _show_contract_counts else "Contracts Off"
	var lines_button = _get_readability_button(BTN_LINES)
	if is_instance_valid(lines_button):
		lines_button.text = "Lines On" if _show_connection_lines else "Lines Off"
	var icons_button = _get_readability_button(BTN_ICONS)
	if is_instance_valid(icons_button):
		icons_button.text = "Icons On" if _show_sector_icons else "Icons Off"


func _refresh_task2_button_texts() -> void:
	var aa_button = _header_row.get_node_or_null(BTN_AA)
	if is_instance_valid(aa_button):
		aa_button.text = _get_viewport_msaa_button_text()


func _get_viewport_msaa_button_text() -> String:
	match _viewport.msaa:
		Viewport.MSAA_2X:
			return "AA 2x"
		Viewport.MSAA_4X:
			return "AA 4x"
		_:
			return "AA Off"


func _get_readability_button(button_name: String) -> Button:
	var button = _header_row.get_node_or_null(button_name)
	return button if button is Button else null


func _ensure_readability_buttons() -> void:
	_ensure_header_toggle_button(BTN_LABELS, "Labels On")
	_ensure_header_action_button(BTN_CONTRACT_COUNTS, "Contracts On", CONTRACT_TOGGLE_BUTTON_MIN_WIDTH)
	_ensure_header_toggle_button(BTN_LINES, "Lines On")
	_ensure_header_toggle_button(BTN_ICONS, "Icons On")


func _ensure_task2_buttons() -> void:
	_ensure_header_action_button(BTN_FOV_IN, "FoV+", TASK2_BUTTON_MIN_WIDTH)
	_ensure_header_action_button(BTN_FOV_OUT, "FoV-", TASK2_BUTTON_MIN_WIDTH)
	_ensure_header_action_button(BTN_AA, "AA Off", TASK2_BUTTON_MIN_WIDTH)


func _ensure_header_toggle_button(button_name: String, button_text: String) -> Button:
	return _ensure_header_action_button(button_name, button_text, READABILITY_BUTTON_MIN_WIDTH)


func _ensure_header_action_button(button_name: String, button_text: String, button_width: float) -> Button:
	var existing_button = _get_readability_button(button_name)
	if is_instance_valid(existing_button):
		return existing_button
	var button = Button.new()
	button.name = button_name
	button.text = button_text
	button.rect_min_size = Vector2(button_width, 0)
	var theme_source = _header_row.get_node_or_null("BtnCoords")
	if is_instance_valid(theme_source):
		button.theme = theme_source.theme
	_header_row.add_child(button)
	var insert_before = _header_row.get_node_or_null("BtnCoords")
	if is_instance_valid(insert_before):
		_header_row.move_child(button, insert_before.get_index())
	return button


func _connect_header_button(button_name: String, method_name: String) -> void:
	var button = _header_row.get_node_or_null(button_name)
	if is_instance_valid(button) and not button.is_connected("pressed", self, method_name):
		button.connect("pressed", self, method_name)


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
		var sector_label: Label = data["label"]
		var contract_label: Label = data.get("contract_label", null)
		var distance_fade_alpha = _get_map_label_camera_distance_fade_alpha(data["pos_3d"])
		if not _show_sector_labels:
			if is_instance_valid(sector_label):
				sector_label.visible = false
		else:
			_update_projected_label(
				sector_label,
				data["pos_3d"],
				data["screen_offset"],
				vp_size,
				50.0,
				distance_fade_alpha
			)

		if not _show_contract_counts:
			if is_instance_valid(contract_label):
				contract_label.visible = false
		else:
			_update_projected_label(
				contract_label,
				data["pos_3d"],
				data.get("contract_screen_offset", Vector2.ZERO),
				vp_size,
				50.0,
				distance_fade_alpha
			)

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


func _update_projected_label(label: Label, pos_3d: Vector3, screen_offset: Vector2, vp_size: Vector2, padding: float, distance_fade_alpha: float = 1.0):
	var cam_transform = _camera.global_transform
	var to_point = pos_3d - cam_transform.origin
	if cam_transform.basis.z.dot(to_point) > 0:
		label.visible = false
		return

	var screen_pos = _camera.unproject_position(pos_3d)
	label.rect_position = screen_pos + screen_offset
	label.visible = (screen_pos.x >= -padding and screen_pos.x <= vp_size.x + padding
		and screen_pos.y >= -padding and screen_pos.y <= vp_size.y + padding)
	if label.visible:
		var screen_fade_alpha = _get_map_label_distance_fade_alpha(screen_pos, Rect2(Vector2.ZERO, vp_size))
		label.modulate = Color(
			1,
			1,
			1,
			screen_fade_alpha * distance_fade_alpha
		)
	else:
		label.modulate = Color(1, 1, 1, 1)


func _get_map_label_distance_fade_alpha(screen_pos: Vector2, viewport_rect: Rect2) -> float:
	var viewport_center = viewport_rect.position + (viewport_rect.size / 2.0)
	var max_distance = max((viewport_rect.size / 2.0).length(), 1.0)
	var normalized_distance = clamp(screen_pos.distance_to(viewport_center) / max_distance, 0.0, 1.0)
	return _compute_map_label_distance_fade_alpha(normalized_distance)


func _compute_map_label_distance_fade_alpha(normalized_distance: float) -> float:
	var safe_normalized_distance = clamp(normalized_distance, 0.0, 1.0)
	var shaped_normalized_distance = pow(safe_normalized_distance, MAP_LABEL_NORMALIZED_DISTANCE_POW)
	return lerp(1.0, MainHUDScript.PROJECTED_TARGET_EDGE_ALPHA, shaped_normalized_distance)


func _get_map_label_camera_distance_fade_alpha(pos_3d: Vector3) -> float:
	if not is_instance_valid(_camera):
		return 1.0
	var camera_distance = _camera.global_transform.origin.distance_to(pos_3d)
	return _compute_map_label_camera_distance_fade_alpha(camera_distance)


func _compute_map_label_camera_distance_fade_alpha(camera_distance: float) -> float:
	if camera_distance <= MAP_LABEL_CAMERA_DISTANCE_FADE_START:
		return 1.0
	var normalized_distance = clamp(
		(camera_distance - MAP_LABEL_CAMERA_DISTANCE_FADE_START) / MAP_LABEL_CAMERA_DISTANCE_FADE_RANGE,
		0.0,
		1.0
	)
	return _compute_map_label_distance_fade_alpha(normalized_distance)


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


func _pan_from_mouse_delta(relative: Vector2) -> void:
	_pan(Vector3(
		-relative.x * MOUSE_PAN_SENSITIVITY,
		relative.y * MOUSE_PAN_SENSITIVITY,
		0.0
	))


func _step_camera_fov(delta_degrees: float) -> void:
	if not is_instance_valid(_camera):
		return
	_camera.fov = clamp(_camera.fov + delta_degrees, MIN_MAP_CAMERA_FOV, MAX_MAP_CAMERA_FOV)
	_refresh_task2_button_texts()


func _cycle_viewport_msaa() -> void:
	var cycle_modes = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
	var current_index = cycle_modes.find(_viewport.msaa)
	if current_index == -1:
		current_index = 0
	_viewport.msaa = cycle_modes[(current_index + 1) % cycle_modes.size()]
	_refresh_task2_button_texts()


func _reset_camera():
	_orbit_yaw = 0.0
	_orbit_pitch = 0.5
	_zoom_distance = DEFAULT_ORBIT_DISTANCE
	_camera.fov = DEFAULT_MAP_CAMERA_FOV
	_pivot = Vector3.ZERO
	_update_camera()
	_refresh_task2_button_texts()


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
	_ensure_task2_buttons()
	_ensure_readability_buttons()
	_connect_header_button("BtnRotL", "_on_rot_l")
	_connect_header_button("BtnRotR", "_on_rot_r")
	_connect_header_button("BtnRotU", "_on_rot_u")
	_connect_header_button("BtnRotD", "_on_rot_d")
	_connect_header_button("BtnZoomIn", "_on_zoom_in")
	_connect_header_button("BtnZoomOut", "_on_zoom_out")
	_connect_header_button(BTN_FOV_IN, "_on_fov_in")
	_connect_header_button(BTN_FOV_OUT, "_on_fov_out")
	_connect_header_button(BTN_AA, "_on_cycle_aa")
	_connect_header_button(BTN_LABELS, "_on_toggle_labels")
	_connect_header_button(BTN_CONTRACT_COUNTS, "_on_toggle_contract_counts")
	_connect_header_button(BTN_LINES, "_on_toggle_lines")
	_connect_header_button(BTN_ICONS, "_on_toggle_icons")
	_connect_header_button("BtnAxes", "_on_toggle_axes")
	_connect_header_button("BtnCoords", "_on_toggle_coords")
	_connect_header_button("BtnPanL", "_on_pan_l")
	_connect_header_button("BtnPanR", "_on_pan_r")
	_connect_header_button("BtnPanU", "_on_pan_u")
	_connect_header_button("BtnPanD", "_on_pan_d")
	_connect_header_button("BtnReset", "_on_reset")
	_connect_header_button("BtnClose", "_on_close")


func _on_rot_l(): _orbit_rotate(-ORBIT_STEP, 0.0)
func _on_rot_r(): _orbit_rotate(ORBIT_STEP, 0.0)
func _on_rot_u(): _orbit_rotate(0.0, ORBIT_STEP)
func _on_rot_d(): _orbit_rotate(0.0, -ORBIT_STEP)
func _on_zoom_in(): _zoom(1.0 / ZOOM_FACTOR)
func _on_zoom_out(): _zoom(ZOOM_FACTOR)
func _on_fov_in(): _step_camera_fov(-MAP_CAMERA_FOV_STEP)
func _on_fov_out(): _step_camera_fov(MAP_CAMERA_FOV_STEP)
func _on_cycle_aa(): _cycle_viewport_msaa()
func _on_toggle_labels():
	_show_sector_labels = not _show_sector_labels
	_apply_readability_visibility_state()
func _on_toggle_contract_counts():
	_show_contract_counts = not _show_contract_counts
	_apply_readability_visibility_state()
func _on_toggle_lines():
	_show_connection_lines = not _show_connection_lines
	_apply_readability_visibility_state()
func _on_toggle_icons():
	_show_sector_icons = not _show_sector_icons
	_apply_readability_visibility_state()
func _on_toggle_axes():
	_show_reference_axes = not _show_reference_axes
	_set_reference_axes_visible(_show_reference_axes)
func _on_toggle_coords():
	_show_sector_coordinates = not _show_sector_coordinates
	_refresh_sector_label_texts()
	if _show_sector_labels:
		_update_label_positions()
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
