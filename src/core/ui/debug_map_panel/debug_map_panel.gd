#
# PROJECT: GDTLancer
# MODULE: debug_map_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md §TASK_4 — Debug Map Panel core logic
# LOG_REF: 2026-04-12
#

extends CanvasLayer

# --- Camera defaults ---
const DEFAULT_ORBIT_DISTANCE = 500000.0
const MIN_ZOOM = 1000.0
const MAX_ZOOM = 800000.0
const ORBIT_STEP = 0.15  # radians per button press
const ZOOM_FACTOR = 1.3
const PAN_STEP_RATIO = 0.1  # fraction of current zoom distance

# --- Node references ---
onready var _panel = $Panel
onready var _viewport_container = $Panel/VBoxContainer/MapArea/ViewportContainer
onready var _viewport = $Panel/VBoxContainer/MapArea/ViewportContainer/Viewport
onready var _camera = $Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapCamera
onready var _map_content = $Panel/VBoxContainer/MapArea/ViewportContainer/Viewport/MapContent
onready var _label_overlay = $Panel/VBoxContainer/MapArea/LabelOverlay

# --- Camera state ---
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.5  # ~30 degrees
var _zoom_distance: float = DEFAULT_ORBIT_DISTANCE
var _pivot: Vector3 = Vector3.ZERO

# --- Label tracking ---
var _sector_labels: Dictionary = {}  # sector_id -> {marker: Spatial, label: Label}
var _is_visible: bool = false
var _was_paused: bool = false
var _hidden_particles: Array = []
var _hidden_scene_nodes: Array = []
var _map_world_env: WorldEnvironment = null
var _map_nebula_holder: Spatial = null


func _ready():
	_panel.visible = false
	_is_visible = false
	set_process(false)
	_connect_buttons()
	if EventBus.has_signal("sim_tick_completed"):
		if not EventBus.is_connected("sim_tick_completed", self, "_on_sim_tick_completed"):
			EventBus.connect("sim_tick_completed", self, "_on_sim_tick_completed")


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_F4:
			_toggle_panel()
			get_tree().set_input_as_handled()


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
		_populate_map()
		set_process(true)
	else:
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
	if is_instance_valid(_map_nebula_holder) and is_instance_valid(_camera):
		_map_nebula_holder.global_transform.origin = _camera.global_transform.origin
	_update_label_positions()


func _on_sim_tick_completed(_tick_count):
	if _is_visible:
		_populate_map()


# =========================================================================
# === MAP ENVIRONMENT (nebula + background) ===============================
# =========================================================================

func _setup_map_environment():
	if is_instance_valid(_map_world_env):
		return  # already set up
	# Add WorldEnvironment so the map viewport has the same background as the game
	var env_res = load("res://assets/art/environments/global_environment.tres")
	if env_res:
		_map_world_env = WorldEnvironment.new()
		_map_world_env.environment = env_res
		_viewport.add_child(_map_world_env)
	# Instance the global nebula into the map viewport
	var nebula_scene = load("res://scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn")
	if nebula_scene:
		_map_nebula_holder = Spatial.new()
		_map_nebula_holder.name = "MapNebulaHolder"
		_map_nebula_holder.add_child(nebula_scene.instance())
		_viewport.add_child(_map_nebula_holder)


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
	_clear_map()
	_create_sector_markers()
	_create_connection_lines()
	_update_camera()


func _clear_map():
	for child in _map_content.get_children():
		child.queue_free()
	for child in _label_overlay.get_children():
		child.queue_free()
	_sector_labels.clear()


func _create_sector_markers():
	for sector_id in TemplateDatabase.locations:
		var template = TemplateDatabase.locations[sector_id]
		if not template or not ("global_position" in template):
			continue
		var pos: Vector3 = template.global_position

		# Sector marker sphere
		var mesh_instance = MeshInstance.new()
		var sphere = SphereMesh.new()
		sphere.radius = 2000.0
		sphere.height = 4000.0
		sphere.radial_segments = 12
		sphere.rings = 6
		mesh_instance.mesh = sphere

		var mat = SpatialMaterial.new()
		mat.flags_unshaded = true
		# Color by current sector highlight
		if sector_id == GameState.current_sector_id:
			mat.albedo_color = Color(1.0, 1.0, 0.2, 1.0)  # yellow for current
			sphere.radius = 3000.0
			sphere.height = 6000.0
		else:
			mat.albedo_color = Color(0.3, 0.8, 1.0, 1.0)  # cyan for others
		mesh_instance.material_override = mat

		mesh_instance.transform.origin = pos
		mesh_instance.name = "Sector_%s" % sector_id
		_map_content.add_child(mesh_instance)

		# Create label in overlay
		var label = Label.new()
		var loc_name = template.location_name if "location_name" in template else sector_id
		if sector_id == GameState.current_sector_id:
			loc_name = ">> " + loc_name + " <<"
		label.text = loc_name
		if sector_id == GameState.current_sector_id:
			label.add_color_override("font_color", Color(1, 1, 0.2, 1.0))
		else:
			label.add_color_override("font_color", Color(1, 1, 1, 0.9))
		label.add_constant_override("shadow_offset_x", 1)
		label.add_constant_override("shadow_offset_y", 1)
		label.add_color_override("font_color_shadow", Color(0, 0, 0, 0.8))
		_label_overlay.add_child(label)

		_sector_labels[sector_id] = {
			"marker": mesh_instance,
			"label": label,
			"pos_3d": pos,
		}


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
			ig.set_color(Color(0.5, 0.8, 0.5, 0.6))
			ig.add_vertex(from_pos)
			ig.add_vertex(to_pos)
	ig.end()
	_map_content.add_child(ig)


func _get_sector_position(sector_id: String):
	if TemplateDatabase.locations.has(sector_id):
		var template = TemplateDatabase.locations[sector_id]
		if "global_position" in template:
			return template.global_position
	return null


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
		var label: Label = data["label"]
		var pos_3d: Vector3 = data["pos_3d"]

		# Check if behind camera
		var cam_transform = _camera.global_transform
		var to_point = pos_3d - cam_transform.origin
		if cam_transform.basis.z.dot(to_point) > 0:
			label.visible = false
			continue

		var screen_pos = _camera.unproject_position(pos_3d)
		# Offset label slightly above marker
		label.rect_position = screen_pos + Vector2(-30, -25)
		label.visible = (screen_pos.x >= -50 and screen_pos.x <= vp_size.x + 50
			and screen_pos.y >= -50 and screen_pos.y <= vp_size.y + 50)


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
