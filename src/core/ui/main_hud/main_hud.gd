extends Control

## MainHUD: Primary gameplay HUD displaying player resources, target info, and combat status.
## Manages sub-screens (Station Menu) and docking prompts.

const FrameProfiler = preload("res://src/core/utils/frame_profiler.gd")
const Announcements = preload("res://src/core/ui/main_hud/announcements.gd")
const RouteTargetProviderScript = preload("res://src/core/targeting/route_target_provider.gd")
const ProjectedTargetBracketScene = preload("res://scenes/ui/hud/projected_target_bracket.tscn")
const BUTTON_ACTIVE_MODULATE = Color8(255, 230, 89, 255)
const BUTTON_INACTIVE_MODULATE = Color8(255, 255, 255, 255)
const PROJECTED_TARGET_EDGE_ALPHA = 0.1
const PROJECTED_TARGET_EDGE_POW = 0.75
const CAMERA_MODE_TARGET_TRACKING = 1
const NAV_COMMAND_IDLE = 0
const NAV_COMMAND_APPROACH = 4
const NAV_COMMAND_ORBIT = 5
const NAV_COMMAND_FLEE = 6
const NAV_COMMAND_RAM = 9
const OVERLAY_KIND_STRUCTURES = "structures"
const OVERLAY_KIND_STELLAR = "stellar"
const OVERLAY_KIND_JUMP = "jump"
const PointerRouterClass = preload("res://src/core/ui/pointer_router.gd")
const FittingWindowScene = preload("res://scenes/ui/menus/fitting_window.tscn")
const DebugMapScene = preload("res://scenes/ui/menus/debug_map.tscn")
const DebugTools = preload("res://src/core/ui/debug_tools/debug_tools.gd")
const ThreatRing = preload("res://src/core/ui/main_hud/threat_ring.gd")
const HUDTargetProjectorClass = preload("res://src/core/ui/main_hud/hud_target_projector.gd")


# --- Nodes ---
onready var projected_target_overlay: Control = $ProjectedTargetOverlay
onready var button_menu: TextureButton = $ScreenControls/CenterLeftZone/ButtonMenu
onready var button_debug: TextureButton = $ScreenControls/CenterLeftZone/ButtonDebug
onready var button_overlay_structures: TextureButton = $ScreenControls/CenterLeftZone/ButtonOverlayStructures
onready var button_overlay_stellar: TextureButton = $ScreenControls/CenterLeftZone/ButtonOverlayStellar
onready var button_overlay_jump: TextureButton = $ScreenControls/CenterLeftZone/ButtonOverlayJump
onready var button_orbit: TextureButton = $ScreenControls/BottomCenterZone/ButtonOrbit
onready var button_manual_flight: TextureButton = $ScreenControls/BottomCenterZone/ButtonManualFlight
onready var button_approach: TextureButton = $ScreenControls/BottomCenterZone/ButtonApproach
onready var button_flee: TextureButton = $ScreenControls/BottomCenterZone/ButtonFlee
onready var button_camera: TextureButton = $ScreenControls/CenterRightZone/ButtonCamera
onready var button_dock: TextureButton = $ScreenControls/BottomCenterZone/ButtonDock
onready var label_button_dock: Label = $ScreenControls/BottomCenterZone/ButtonDock/LabelButtonDock
onready var button_interact: TextureButton = $ScreenControls/BottomCenterZone/ButtonInteract
onready var label_button_interact: Label = $ScreenControls/BottomCenterZone/ButtonInteract/LabelButtonInteract
onready var debug_overlay: Control = $ScreenControls/DebugOverlay
onready var _debug_label_ship: Label = $ScreenControls/DebugOverlay/LeftColumn/LabelShip
onready var _debug_label_tools: Label = $ScreenControls/DebugOverlay/LeftColumn/LabelTools
onready var _debug_label_target: Label = $ScreenControls/DebugOverlay/RightColumn/LabelTarget
onready var _debug_label_world: Label = $ScreenControls/DebugOverlay/RightColumn/LabelWorld
onready var _debug_label_render: Label = $ScreenControls/DebugOverlay/LabelRender
onready var _debug_label_frame: Label = $ScreenControls/DebugOverlay/LabelFrame
onready var button_render_scale: TextureButton = $ScreenControls/CenterRightZone/ButtonRenderScale
onready var label_render_scale: Label = $ScreenControls/CenterRightZone/ButtonRenderScale/LabelButtonScale
onready var button_particles: TextureButton = $ScreenControls/CenterLeftZone/ButtonParticlesToggle
onready var label_particles: Label = $ScreenControls/CenterLeftZone/ButtonParticlesToggle/LabelButtonParticles
onready var tool_buttons: Array = _tool_button_nodes()
onready var button_lance: TextureButton = $ScreenControls/TemporaryToolZone/ButtonLance
onready var button_afterburner: TextureButton = $ScreenControls/TemporaryToolZone/ButtonAfterburner
var fitting_window: Control = null
var debug_map: Control = null
var debug_tools: Control = null
var threat_ring: Control = null
var _tool_rows: Array = []  # Rows of tool buttons above TemporaryToolZone (_layout_tool_rows)
var _tool_rows_key: String = ""
var _world_rebuild_queued: bool = false  # A bracket rebuild is due at the end of the frame

# --- Game Over UI ---

# --- State ---
var _current_target = null
var _main_camera: Camera = null
var _player_uid: int = -1
var _announcements: Control = null  # Fading feedback labels (Announcements)
var _hud_alpha = 1.0
var _dock_location_id: String = ""  # Currently available dock location
var _jump_target_id: String = ""  # Currently available jump route target
var _route_target_provider: Reference = RouteTargetProviderScript.new()
var _route_target_buttons: Dictionary = {}
var _route_target_overlay_sector_id: String = ""
var _route_target_overlay_signature: String = ""
var _world_target_buttons: Dictionary = {}
var _overlay_structures_enabled: bool = true
var _overlay_stellar_enabled: bool = true
var _overlay_jump_enabled: bool = true

# --- Delegates ---
var _target_projector: Reference
var _pointer_router: Node

func _init() -> void:
	_target_projector = HUDTargetProjectorClass.new(self)

# --- Initialization ---
var _frame_profiler: Node = null


func _ready():
	_frame_profiler = FrameProfiler.new()
	_frame_profiler.name = "FrameProfiler"
	add_child(_frame_profiler)
	_announcements = Announcements.new()
	_announcements.name = "Announcements"
	add_child(_announcements)
	GlobalRefs.set_main_hud(self)

	# Get camera reference once
	_main_camera = get_viewport().get_camera()  # Initial attempt
	if not is_instance_valid(_main_camera) and is_instance_valid(GlobalRefs.main_camera):
		_main_camera = GlobalRefs.main_camera  # Fallback via GlobalRefs

	if not is_instance_valid(_main_camera):
		printerr("MainHUD Error: Could not get a valid camera reference!")
		set_process(false)  # Disable processing if no camera

	# Connect to EventBus signals
	if EventBus:
		if not EventBus.is_connected("player_target_selected", self, "_on_Player_Target_Selected"):
			EventBus.connect("player_target_selected", self, "_on_Player_Target_Selected")

		if not EventBus.is_connected(
			"player_target_deselected", self, "_on_Player_Target_Deselected"
		):
			EventBus.connect("player_target_deselected", self, "_on_Player_Target_Deselected")

		EventBus.connect("dock_available", self, "_on_dock_available")
		EventBus.connect("dock_unavailable", self, "_on_dock_unavailable")
		EventBus.connect("player_docked", self, "_on_player_docked")
		EventBus.connect("player_undocked", self, "_on_player_undocked")
		EventBus.connect("jump_available", self, "_on_jump_available")
		EventBus.connect("jump_unavailable", self, "_on_jump_unavailable")
		
		# Dock/Attack feedback signals
		EventBus.connect("dock_action_feedback", self, "_on_dock_action_feedback")
		EventBus.connect("attack_action_feedback", self, "_on_attack_action_feedback")
		EventBus.connect("announcement", self, "announce")

		# Combat flow (Phase 1: debug feedback)
		if not EventBus.is_connected("combat_initiated", self, "_on_combat_initiated"):
			EventBus.connect("combat_initiated", self, "_on_combat_initiated")
		if not EventBus.is_connected("combat_ended", self, "_on_combat_ended"):
			EventBus.connect("combat_ended", self, "_on_combat_ended")
		if not EventBus.is_connected("agent_damaged", self, "_on_agent_damaged"):
			EventBus.connect("agent_damaged", self, "_on_agent_damaged")
		if not EventBus.is_connected("agent_disabled", self, "_on_agent_disabled"):
			EventBus.connect("agent_disabled", self, "_on_agent_disabled")
		if not EventBus.is_connected("agent_despawning", self, "_on_agent_despawning"):
			EventBus.connect("agent_despawning", self, "_on_agent_despawning")
		if not EventBus.is_connected("agent_spawned", self, "_on_agent_spawned"):
			EventBus.connect("agent_spawned", self, "_on_agent_spawned")
		if not EventBus.is_connected("debris_spawned", self, "_on_debris_spawned"):
			EventBus.connect("debris_spawned", self, "_on_debris_spawned")
		if not EventBus.is_connected("new_game_requested", self, "_on_new_game_requested"):
			EventBus.connect("new_game_requested", self, "_on_new_game_requested")
		if not EventBus.is_connected("game_state_loaded", self, "_on_game_state_loaded"):
			EventBus.connect("game_state_loaded", self, "_on_game_state_loaded")
		if not EventBus.is_connected("zone_unloading", self, "_on_zone_unloading"):
			EventBus.connect("zone_unloading", self, "_on_zone_unloading")
		if not EventBus.is_connected("zone_loaded", self, "_on_zone_loaded"):
			EventBus.connect("zone_loaded", self, "_on_zone_loaded")
		if not EventBus.is_connected("player_spawned", self, "_on_player_spawned"):
			EventBus.connect("player_spawned", self, "_on_player_spawned")
		if not EventBus.is_connected("sector_changed", self, "_on_sector_changed"):
			EventBus.connect("sector_changed", self, "_on_sector_changed")

	else:
		printerr("MainHUD Error: EventBus not available!")

	set_process_input(true)

	# Connect ButtonMenu to open main menu
	if is_instance_valid(button_menu):
		if not button_menu.is_connected("pressed", self, "_on_ButtonMenu_pressed"):
			button_menu.connect("pressed", self, "_on_ButtonMenu_pressed")

	# Connect ButtonCamera to toggle camera mode
	if is_instance_valid(button_camera):
		if not button_camera.is_connected("pressed", self, "_on_ButtonCamera_pressed"):
			button_camera.connect("pressed", self, "_on_ButtonCamera_pressed")

	if is_instance_valid(button_debug):
		if not button_debug.is_connected("pressed", self, "_on_ButtonDebug_pressed"):
			button_debug.connect("pressed", self, "_on_ButtonDebug_pressed")
	if is_instance_valid(debug_overlay):
		debug_overlay.visible = false  # Until the debug button shows it

	_connect_overlay_toggle_button(button_overlay_structures, "_on_ButtonOverlayStructures_pressed")
	_connect_overlay_toggle_button(button_overlay_stellar, "_on_ButtonOverlayStellar_pressed")
	_connect_overlay_toggle_button(button_overlay_jump, "_on_ButtonOverlayJump_pressed")

	_pointer_router = PointerRouterClass.new(self)
	add_child(_pointer_router)
	for index in range(tool_buttons.size()):
		tool_buttons[index].connect("pressed", self, "_on_tool_button_pressed", [index])
	button_lance.connect("pressed", self, "_on_lance_button_pressed")
	button_afterburner.connect("pressed", self, "_on_afterburner_button_pressed")
	button_render_scale.connect("pressed", self, "_on_ButtonRenderScale_pressed")
	_update_render_scale_label()
	button_particles.connect("pressed", self, "_on_ButtonParticlesToggle_pressed")
	_update_particles_label()
	fitting_window = FittingWindowScene.instance()
	add_child(fitting_window)
	debug_map = DebugMapScene.instance()
	add_child(debug_map)
	$ScreenControls/DebugOverlay/RightColumn/ButtonDebugMap.connect("pressed", debug_map, "open")
	threat_ring = ThreatRing.new()
	threat_ring.name = "ThreatRing"
	add_child(threat_ring)
	move_child(threat_ring, $ScreenControls.get_index() + 1)  # Over the HUD buttons (it takes no input), under the windows
	debug_tools = DebugTools.new()
	debug_tools.name = "DebugTools"
	add_child(debug_tools)
	$ScreenControls/DebugOverlay/RightColumn/ButtonDebugJump.connect("pressed", debug_tools, "open_jump")
	$ScreenControls/DebugOverlay/RightColumn/ButtonDebugGoTo.connect("pressed", debug_tools, "open_go_to")
	$ScreenControls/DebugOverlay/RightColumn/ButtonDebugToTarget.connect("pressed", debug_tools, "go_to_target")
	$ScreenControls/DebugOverlay/LeftColumn/ButtonDebugRefit.connect("pressed", debug_tools, "open_refit")
	_refresh_toggle_button_states()

	pause_mode = PAUSE_MODE_PROCESS

	_refresh_process_state()
	_update_dock_button_label()

	call_deferred("_rebuild_projected_target_overlays")


# --- Process Update ---
func _process(_delta):
	FrameProfiler.begin(get_tree(), "hud")
	_update_hud()
	FrameProfiler.end(get_tree(), "hud")


func _update_hud() -> void:
	# If the selected target is gone, clear the UI state.
	if _current_target != null and not _is_target_valid(_current_target):
		_on_Player_Target_Deselected()
		return

	_update_route_target_overlay()
	_update_world_target_overlay(false)
	_refresh_toggle_button_states()
	_update_debug_overlay()
	_update_tool_buttons()
	_update_lance_button()
	_update_afterburner_button()
	_layout_tool_rows()
	_update_dock_button_label()


# --- Signal Handlers ---
func _on_Player_Target_Selected(target_node):
	if _is_target_valid(target_node):
		_current_target = target_node
		_refresh_process_state()
		_update_route_target_selection_state()
		_update_world_target_selection_state()
		_update_dock_button_label()

		# Update camera look_at_target if in target tracking mode
		var camera = GlobalRefs.main_camera
		if is_instance_valid(camera) and camera.get_camera_mode() == 1 and target_node is Spatial:  # TARGET_TRACKING
			camera.set_look_at_target(target_node)
		_refresh_toggle_button_states()
	else:
		_on_Player_Target_Deselected()


func _on_Player_Target_Deselected():
	_current_target = null
	_update_route_target_selection_state()
	_update_world_target_selection_state()
	_refresh_process_state()
	_update_dock_button_label()

	# If camera is in target tracking mode, switch back to orbit mode
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and camera.get_camera_mode() == 1:  # TARGET_TRACKING
		camera.set_camera_mode(0)  # ORBIT
	_refresh_toggle_button_states()


func _on_agent_despawning(agent_body) -> void:
	# If our selected target is being removed, clear target UI.
	if is_instance_valid(_current_target) and _current_target is Spatial and agent_body == _current_target:
		_on_Player_Target_Deselected()
	_queue_world_target_rebuild()


func _on_player_spawned(_player_body) -> void:
	_refresh_process_state()


func _on_agent_spawned(_agent_body, _init_data) -> void:
	_queue_world_target_rebuild()


# Chunks and loose lances come often (every lance throw): each gets its own bracket, not a rebuild.
func _on_debris_spawned(body) -> void:
	if is_instance_valid(body) and _target_projector.is_world_projectable_target(body):
		_target_projector.add_world_target(body)
		_target_projector.update_world_target_overlay(true)


# One rebuild of the brackets however many ships come or go at once (a sector's population spawns
# together: a rebuild each cost seconds).
func _queue_world_target_rebuild() -> void:
	if not _world_rebuild_queued:
		_world_rebuild_queued = true
		call_deferred("_rebuild_world_target_overlay")


func _on_new_game_requested() -> void:
	# World is about to be reset; clear any stale targeting UI.
	_on_Player_Target_Deselected()


func _on_game_state_loaded() -> void:
	# After load, clear stale targeting UI.
	_on_Player_Target_Deselected()



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if EventBus:
			EventBus.emit_signal("main_menu_requested")
			get_tree().set_input_as_handled()


func _on_ButtonMenu_pressed() -> void:
	"""Handle menu button press - opens main menu."""
	if EventBus:
		EventBus.emit_signal("main_menu_requested")


# Shows or hides the debug overlay (ship, tools, target, world, render, frame time): off by default.
func _on_ButtonDebug_pressed() -> void:
	if not is_instance_valid(debug_overlay):
		return
	debug_overlay.visible = not debug_overlay.visible
	_update_debug_overlay()


func _on_ButtonCamera_pressed() -> void:
	"""Handle camera button press - toggles between orbit and target-tracking mode."""
	var camera = GlobalRefs.main_camera
	if not is_instance_valid(camera):
		return
	
	if camera.get_camera_mode() == CAMERA_MODE_TARGET_TRACKING:
		camera.set_camera_mode(0)  # ORBIT; resets the zoom
	elif is_instance_valid(_current_target) and _current_target is Spatial:
		camera.set_camera_mode(CAMERA_MODE_TARGET_TRACKING)
		camera.set_look_at_target(_current_target)
	_refresh_toggle_button_states()


func _connect_overlay_toggle_button(button: TextureButton, method_name: String) -> void:
	if not is_instance_valid(button):
		return
	if not button.is_connected("pressed", self, method_name):
		button.connect("pressed", self, method_name)


func _on_ButtonFreeFlight_pressed():
	if EventBus:
		EventBus.emit_signal("player_free_flight_toggled")
	_refresh_toggle_button_states()


func _on_ButtonStop_pressed():
	if EventBus:
		EventBus.emit_signal("player_stop_pressed")


func _on_ButtonOrbit_pressed():
	if EventBus:
		EventBus.emit_signal("player_orbit_pressed")
	_refresh_toggle_button_states()


func _on_ButtonApproach_pressed():
	if EventBus:
		EventBus.emit_signal("player_approach_pressed")
	_refresh_toggle_button_states()


func _on_ButtonFlee_pressed():
	if EventBus:
		EventBus.emit_signal("player_flee_pressed")
	_refresh_toggle_button_states()


func _on_ButtonOverlayStructures_pressed() -> void:
	_overlay_structures_enabled = not _overlay_structures_enabled
	_refresh_toggle_button_states()
	_update_world_target_overlay()


func _on_ButtonOverlayStellar_pressed() -> void:
	_overlay_stellar_enabled = not _overlay_stellar_enabled
	_refresh_toggle_button_states()
	_update_world_target_overlay()


func _on_ButtonOverlayJump_pressed() -> void:
	_overlay_jump_enabled = not _overlay_jump_enabled
	_refresh_toggle_button_states()
	_update_route_target_overlay()


func _on_ButtonDock_pressed():
	if GameState.player_docked_at != "":
		EventBus.emit_signal("player_undocked")
		_update_dock_button_label()
		return
	if is_instance_valid(label_button_dock) and label_button_dock.text == "TRAVEL":
		if _jump_target_id != "":
			EventBus.emit_signal("player_jump_requested", _jump_target_id)
		else:
			EventBus.emit_signal("player_dock_pressed")
		return

	if _current_target != null and is_instance_valid(_current_target) and (_is_route_target(_current_target) or _current_target.is_in_group("jump_point")):
		if _jump_target_id != "":
			EventBus.emit_signal("player_jump_requested", _jump_target_id)
		else:
			EventBus.emit_signal("player_dock_pressed")
		return

	EventBus.emit_signal("player_dock_pressed")


func _on_ButtonInteract_pressed():
	if EventBus:
		EventBus.emit_signal("player_interact_pressed")


# One button per fitted tool (TemporaryToolZone; more are made as a ship needs them), two states
# each: the tool's action while off (FIRE, LAUNCH), CEASE / RELEASE while on, highlighted then.
# Buttons past the fitted tools are hidden. The buttons (tools, then LANCE and AFTERBURNER) sit in
# centred rows of at most TOOL_ROW_MAX, the last row lowest; the rows above are made as needed.
const TOOL_ROW_MAX = 8
const TOOL_ROW_STEP = 120.0  # px between rows: a button and the gap
const TOOL_ACTIONS = {"laser": ["FIRE", "CEASE"], "missile": ["LAUNCH", "HOLD"], "cannon": ["AIM+FIRE", "CEASE"], "harpoon": ["LAUNCH", "RELEASE"]}


func _update_tool_buttons() -> void:
	var player = GlobalRefs.player_agent_body
	var tools = player.get_node_or_null("ToolController") if is_instance_valid(player) else null
	var count: int = tools.get_tool_count() if is_instance_valid(tools) else 0
	while tool_buttons.size() < count:
		var button: TextureButton = tool_buttons[0].duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)  # Not its signals: it gets its own index
		button.name = "ButtonTool%d" % (tool_buttons.size() + 1)
		button.connect("pressed", self, "_on_tool_button_pressed", [tool_buttons.size()])
		tool_buttons.back().get_parent().add_child_below_node(tool_buttons.back(), button)
		tool_buttons.append(button)
	for index in range(tool_buttons.size()):
		var button: TextureButton = tool_buttons[index]
		button.visible = index < count
		if index >= count:
			continue
		var tool_template = tools.get_tool(index)
		var active: bool = tools.is_active(index)
		var actions: Array = TOOL_ACTIONS.get(tool_template.tool_type, ["USE", "STOP"])
		var name: String = tool_template.hud_label if tool_template.hud_label != "" else tool_template.tool_name.to_upper()
		var action: String = actions[1] if active else actions[0]
		if tools.has_method("is_retracting") and tools.is_retracting(index):
			action = "WINCHING"
		if tools.has_method("has_magazine") and tools.has_magazine(index):
			name += " %d" % tools.get_ammo(index)  # Rounds left
			if tools.get_ammo(index) <= 0:
				action = "EMPTY"
		button.get_node("Label").text = "%s\n%s" % [name, action]
		_apply_button_toggle_state(button, active)


# Spreads the shown buttons over rows of at most TOOL_ROW_MAX, the first ones highest; only when
# what is shown changes.
func _layout_tool_rows() -> void:
	var items: Array = tool_buttons + [button_lance, button_afterburner]
	var shown: Array = []
	for item in items:
		if item.visible:
			shown.append(item)
	var key := ""
	for item in items:
		key += "1" if item.visible else "0"
	if key == _tool_rows_key:
		return
	_tool_rows_key = key
	var rows: int = int(max(1, ceil(float(shown.size()) / TOOL_ROW_MAX)))
	var zone: Control = $ScreenControls/TemporaryToolZone
	while _tool_rows.size() < rows - 1:  # Rows above the zone, the nearest first
		var row := HBoxContainer.new()
		row.name = "TemporaryToolRow%d" % (_tool_rows.size() + 2)
		for property in ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "margin_left", "margin_right", "mouse_filter", "alignment"]:
			row.set(property, zone.get(property))
		row.add_constant_override("separation", zone.get_constant("separation"))
		row.margin_top = zone.margin_top - TOOL_ROW_STEP * (_tool_rows.size() + 1)
		row.margin_bottom = zone.margin_bottom - TOOL_ROW_STEP * (_tool_rows.size() + 1)
		zone.get_parent().add_child(row)
		_tool_rows.append(row)
	var last_row_size: int = shown.size() - (rows - 1) * TOOL_ROW_MAX
	var position := 0
	for item in items:  # Hidden ones go with the next shown one, keeping the order
		var row_index: int = 0
		if position < shown.size() - last_row_size:
			row_index = rows - 1 - int(position / TOOL_ROW_MAX)
		var parent: Control = zone if row_index == 0 else _tool_rows[row_index - 1]
		if item.get_parent() != parent:
			item.get_parent().remove_child(item)
			parent.add_child(item)
		else:
			parent.move_child(item, parent.get_child_count() - 1)
		if item.visible:
			position += 1


func _on_tool_button_pressed(index: int) -> void:
	EventBus.emit_signal("player_tool_pressed", index)


func _tool_button_nodes() -> Array:
	var buttons: Array = []
	for child in get_node("ScreenControls/TemporaryToolZone").get_children():
		if child.name.begins_with("ButtonTool"):
			buttons.append(child)
	return buttons


# The LANCE button, after the tools (only with a lance fitted): lances left and ARM while safe;
# ARMED (highlighted) and the speed a throw would strike the selected target at against the speed a
# strike needs, or TOO SLOW (it runs faster than the ship can gain on it) or TOO HOT (its side's guns
# would take the whole hull on the way in: what NPCs weigh); LOADING while the next lance slides in.
# Armed, APPROACH flies the throwing pass at a ship or a rock; one throw (a volley from launchers
# side by side) and it disarms.
func _update_lance_button() -> void:
	var player = GlobalRefs.player_agent_body
	var lance = player.get_lance() if is_instance_valid(player) and player.has_method("get_lance") else null
	button_lance.visible = lance != null
	var controller = _get_player_controller()
	var selected = controller.get("_selected_target") if is_instance_valid(controller) else null
	var ram: bool = is_instance_valid(controller) and controller.has_method("is_ram_ready") and controller.is_ram_ready(selected if is_instance_valid(selected) else null)  # As APPROACH will act
	var ram_target = selected if ram and is_instance_valid(selected) else null
	if lance == null:
		return
	var state: String = "ARM"
	var seated = null  # A launcher with a lance ready
	for each in player.get_lances():
		if each.is_seated():
			seated = each
			break
	if player.get_lance_nails() <= 0:
		state = "EMPTY"
	elif seated == null:
		state = "LOADING"
	elif lance.armed:
		state = "ARMED"
		var target = _current_target
		if ram_target != null and player.outruns_ram(ram_target):
			state = "TOO SLOW"
		elif ram_target is RigidBody and ram_target.get("is_wreck") == false and player.ram_outlook(ram_target).cost >= player.hull:
			state = "TOO HOT"
		elif is_instance_valid(target) and target is RigidBody:
			state = "%d / %d" % [int(seated.strike_speed_on(target)), int(Constants.LAW_LANCE_MIN_SPEED)]
	button_lance.get_node("Label").text = "LANCE %d\n%s" % [player.get_lance_nails(), state]
	_apply_button_toggle_state(button_lance, lance.armed)


func _on_lance_button_pressed() -> void:
	EventBus.emit_signal("player_lance_pressed")


# The AFTERBURN button, after the lance (only with an afterburner fitted): ON (highlighted) and the
# top speed it gives, or OFF; with a decoy launcher, the decoys left under it.
func _update_afterburner_button() -> void:
	var player = GlobalRefs.player_agent_body
	var fitted: bool = is_instance_valid(player) and player.has_method("has_afterburner") and player.has_afterburner()
	var decoys: bool = is_instance_valid(player) and player.has_method("get_decoy_capacity") and player.get_decoy_capacity() > 0
	button_afterburner.visible = fitted or decoys
	if not button_afterburner.visible:
		return
	var text: String = "BURN %s\n%d m/s" % ["ON" if player.afterburner_lit else "OFF", int(player.get_burst_top_speed())] if fitted else "NO BURNER"
	if decoys:
		text += "\nDECOYS %d" % player.decoys
	button_afterburner.get_node("Label").text = text
	_apply_button_toggle_state(button_afterburner, fitted and player.afterburner_lit)


func _on_afterburner_button_pressed() -> void:
	EventBus.emit_signal("player_afterburner_pressed")


func _on_SliderControlLeft_value_changed(value):
	# ZOOM camera slider
	if EventBus:
		EventBus.emit_signal("player_camera_zoom_changed", value)


# --- Docking UI Handlers ---
func _on_dock_available(location_id):
	_dock_location_id = location_id
	_refresh_projected_target_info_hints()


func _on_dock_unavailable():
	_dock_location_id = ""
	_refresh_projected_target_info_hints()


func _on_player_docked(_location_id):
	_dock_location_id = ""
	_jump_target_id = ""
	_refresh_projected_target_info_hints()
	_update_dock_button_label()


# Deferred: the player controller clears GameState.player_docked_at in its own handler.
func _on_player_undocked():
	call_deferred("_update_dock_button_label")


# --- Jump UI Handlers ---
func _on_jump_available(target_id, _target_name) -> void:
	_jump_target_id = str(target_id)
	_refresh_projected_target_info_hints()


func _on_jump_unavailable() -> void:
	_jump_target_id = ""
	_refresh_projected_target_info_hints()


func _refresh_projected_target_info_hints() -> void:
	_update_route_target_selection_state()
	_update_world_target_selection_state()


# --- Dock/Attack Feedback: fading announcements (Announcements) ---
# Done: info; refused or failed: warning. Threats come through EventBus.announcement as danger.
func _on_dock_action_feedback(success: bool, message: String) -> void:
	announce(message, "info" if success else "warning")


func _on_attack_action_feedback(success: bool, message: String) -> void:
	announce(message, "info" if success else "warning")


func announce(message: String, level: String = "info") -> void:
	if is_instance_valid(_announcements):
		_announcements.announce(message, level)


func _on_SliderControlRight_value_changed(value):
	# SPEED (maximum) limiter.
	# This slider is inverted (rotated by 180) for the sake of appearance.
	if EventBus:
		EventBus.emit_signal("player_ship_speed_changed", value)


func _get_player_controller() -> Node:
	var player_agent = GlobalRefs.player_agent_body
	if not is_instance_valid(player_agent):
		return null
	return player_agent.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)


func _is_player_free_flight_active() -> bool:
	var player_controller = _get_player_controller()
	return is_instance_valid(player_controller) and player_controller.has_method("is_free_flight_active") and player_controller.is_free_flight_active()


func _get_player_navigation_command_type() -> int:
	var player_controller = _get_player_controller()
	if is_instance_valid(player_controller) and player_controller.has_method("get_active_navigation_command_type"):
		return int(player_controller.get_active_navigation_command_type())
	return NAV_COMMAND_IDLE


func _is_camera_target_follow_active() -> bool:
	var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _main_camera
	if not is_instance_valid(camera):
		return false
	if not camera.has_method("get_camera_mode") or camera.get_camera_mode() != CAMERA_MODE_TARGET_TRACKING:
		return false
	if not camera.has_method("get_look_at_target"):
		return true
	var look_at_target = camera.get_look_at_target()
	return is_instance_valid(look_at_target) and look_at_target is Spatial


func _refresh_toggle_button_states() -> void:
	_apply_button_toggle_state(button_overlay_structures, _overlay_structures_enabled)
	_apply_button_toggle_state(button_overlay_stellar, _overlay_stellar_enabled)
	_apply_button_toggle_state(button_overlay_jump, _overlay_jump_enabled)

	var is_free_flight_active = _is_player_free_flight_active()
	var active_navigation_command_type = _get_player_navigation_command_type()
	_apply_button_toggle_state(button_manual_flight, is_free_flight_active)
	_apply_button_toggle_state(button_orbit, not is_free_flight_active and active_navigation_command_type == NAV_COMMAND_ORBIT)
	_apply_button_toggle_state(button_approach, not is_free_flight_active and active_navigation_command_type in [NAV_COMMAND_APPROACH, NAV_COMMAND_RAM])
	_apply_button_toggle_state(button_flee, not is_free_flight_active and active_navigation_command_type == NAV_COMMAND_FLEE)
	_apply_button_toggle_state(button_camera, _is_camera_target_follow_active())


func _apply_button_toggle_state(button: TextureButton, is_active: bool) -> void:
	if not is_instance_valid(button):
		return
	button.modulate = BUTTON_ACTIVE_MODULATE if is_active else BUTTON_INACTIVE_MODULATE


func _get_world_rendering_node() -> Node:
	var scene_root = get_tree().current_scene
	if not is_instance_valid(scene_root):
		return null
	return scene_root.get_node_or_null("WorldRendering")


func _is_projected_target_center_fade_enabled() -> bool:
	var world_rendering = _get_world_rendering_node()
	if not is_instance_valid(world_rendering):
		return false
	return bool(world_rendering.get("projected_target_center_fade_enabled"))


# The debug overlay fills the gaps between the HUD's button rows, one block per category: ship and
# tools in the left column, target and world in the right, render and frame time along the top.
# Only worked out while shown (debug button).
func _update_debug_overlay() -> void:
	if not is_instance_valid(debug_overlay) or not debug_overlay.visible:
		return
	var player = GlobalRefs.player_agent_body
	var has_player: bool = is_instance_valid(player) and player.get("hull_max") != null
	_debug_label_ship.text = describe_ship_stats(player) if has_player else "SHIP\nno ship"
	_debug_label_tools.text = describe_tool_stats(player) if has_player else "TOOLS\nno ship"
	_debug_label_target.text = describe_target_stats(player) if has_player else "TARGET\nno ship"
	_debug_label_world.text = describe_world_stats(player) if has_player else "WORLD\nno ship"
	_debug_label_render.text = describe_render_stats()
	_debug_label_frame.text = describe_frame_stats()


static func describe_ship_stats(player) -> String:
	return PoolStringArray([
		"SHIP",
		"HULL  %d / %d" % [ceil(player.hull), player.hull_max],
		"POWER %d / %d" % [floor(player.power), player.power_max],
		describe_power_flow(player),
		"CARGO %d / %d  %d WP, %d%% of ship" % [player.get_cargo_units(), player.cargo_capacity, player.get_cargo_value(), round(100.0 * player.get_cargo_value() / max(1.0, player.get_value()))],  # NPCs take it home at their haul gene's share
		"BANK  %d WP" % GameState.player_bank,
		"SPEED %d / %d m/s" % [player.linear_velocity.length(), player.get_top_speed()],
		"MASS  %.1f t" % (player.mass / 1000.0),
		describe_signature(player),
		"SIG %s  SENSORS x%.2f" % [_format_distance(player.get_signature()), player.get_sensor_strength()],
	]).join("\n")


# Where the power goes, from the fit: the reactor's charge (less what sensor dampers run off it),
# the draw of every tool working at once (harpoons draw per launch, not counted), the afterburner's
# at full thrust, and the net with the tools on: what a long fight costs or leaves.
static func describe_power_flow(player) -> String:
	var stats: Dictionary = player.get("fit_stats") if player.get("fit_stats") != null else {}
	var damper: float = Constants.LAW_DAMPER_POWER_PER_KG * float(stats.get("damper_mass", 0.0))
	var parts: Array = ["  REACTOR +%.1f/s" % (player.power_regen + damper)]
	if damper > 0.0:
		parts.append("DAMPER -%.1f/s" % damper)
	var tools_draw := 0.0
	var tools = player.get_node_or_null("ToolController")
	if is_instance_valid(tools):
		for index in range(tools.get_tool_count()):
			var tool_template = tools.get_tool(index)
			if tool_template != null and tool_template.tool_type != "harpoon" and tool_template.cycle_time > 0.0:
				tools_draw += tool_template.power_per_cycle / tool_template.cycle_time
	var lines: Array = [PoolStringArray(parts).join("  ")]
	if tools_draw > 0.0:
		var net: float = player.power_regen - tools_draw
		lines.append("  TOOLS ON -%.1f/s  NET %s%.1f/s%s" % [tools_draw, "+" if net >= 0.0 else "-", abs(net),
			"" if net >= 0.0 else "  FULL TO EMPTY %ds" % int(player.power_max / -net)])
	var afterburner: float = float(stats.get("afterburner_thrust", 0.0)) / 1000.0 * Constants.LAW_AFTERBURNER_POWER_PER_KN
	if afterburner > 0.0:
		lines.append("  AFTERBURNER -%.1f/s at full thrust" % afterburner)
	return PoolStringArray(lines).join("\n")


func describe_tool_stats(player) -> String:
	var lines: Array = ["TOOLS"]
	var tools = player.get_node_or_null("ToolController")
	if is_instance_valid(tools):
		for index in range(tools.get_tool_count()):
			lines.append(_describe_tool_state(tools, index))
	if lines.size() == 1:
		lines.append("none fitted")
	return PoolStringArray(lines).join("\n")


# The selected target: what it is, how far, its signature and who sees whom.
func describe_target_stats(player) -> String:
	var lines: Array = ["TARGET"]
	if _current_target == null or not _is_target_valid(_current_target):
		lines.append("none")
		return PoolStringArray(lines).join("\n")
	lines.append(_resolve_target_display_name(_current_target))
	if _is_route_target(_current_target):
		lines.append("JUMP ROUTE  %s" % TemplateDatabase.get_sector_type(_current_target.target_sector_id).to_upper())
		return PoolStringArray(lines).join("\n")
	if not (_current_target is Spatial):
		return PoolStringArray(lines).join("\n")
	if _current_target.is_in_group("loose_lance"):
		lines.append("LANCE: APPROACH OR HARPOON IT")
	elif _current_target.has_method("has_crust"):  # An ore chunk (Constants MINING)
		if _current_target.has_crust():
			lines.append("CRUST %d%%: BURN IT  ORE %d" % [int(ceil(100.0 * _current_target.crust / Constants.MINING_CRUST_HP)), _current_target.get_salvage_units()])
		elif _current_target.is_hot():
			lines.append("SLAG COOLING %ds  ORE %d" % [int(ceil(_current_target.heat)), _current_target.get_salvage_units()])
		else:
			lines.append("SLAG: HARPOON IT  ORE %d" % _current_target.get_salvage_units())
	elif _current_target.has_method("get_beacon_cues"):  # A beacon (SectorLayout): what goes on round it
		lines.append(PoolStringArray(_current_target.get_beacon_cues()).join("  "))
	elif _current_target.get("is_wreck"):
		lines.append("WRECK  SALVAGE %d" % _current_target.get_salvage_units())
	elif _current_target.has_method("get_deposit") and _current_target.mineable:  # A rock
		lines.append("WORKED OUT" if _current_target.get_deposit() <= 0 else "ORE %d: LANCE IT" % _current_target.get_deposit())
	elif _current_target.get("hull_max"):
		lines.append("HULL %d / %d" % [ceil(_current_target.hull), _current_target.hull_max])
		var cues: Array = _target_projector.get_ship_cues(_current_target)
		if not cues.empty():
			lines.append(PoolStringArray(cues).join("  "))
		var reach: float = player.weapon_reach_of(player)
		if reach > 0.0 and _current_target.has_method("get_jamming") and _current_target.get_jamming() > 0.0:
			lines.append("JAMMING: LOCK WITHIN %s" % _format_distance(_current_target.lock_range_for(player, reach)))
	if _current_target.has_method("get_apparent_radius"):
		lines.append("%s across" % _format_distance(_current_target.get_apparent_radius() * 2.0))
	lines.append("DIST %s" % _format_distance(player.global_transform.origin.distance_to(_current_target.global_transform.origin)))
	if _current_target.has_method("get_signature"):
		lines.append("SIG %s  %s" % [_format_distance(_current_target.get_signature()), "DETECTED" if player.detects(_current_target) else "LOST"])
	return PoolStringArray(lines).join("\n")


# Where the player is, what the autopilot is doing, and how much of the sector is on the sensors.
func describe_world_stats(player) -> String:
	var template = TemplateDatabase.locations.get(GameState.current_sector_id)
	var sector_name: String = template.location_name if template != null and template.location_name != "" else GameState.current_sector_id
	var position: Vector3 = player.global_transform.origin / 1000.0
	var lines: Array = [
		"WORLD",
		"SECTOR %s" % sector_name,
		"POS %.1f, %.1f, %.1f km" % [position.x, position.y, position.z],
		"FROM ORIGIN %.1f km" % position.length(),
	]
	var nav = player.get("navigation_system")
	if is_instance_valid(nav) and nav.has_method("get_current_command_type"):
		lines.append("AUTOPILOT %s" % nav.CommandType.keys()[nav.get_current_command_type()])
	var ships_seen := 0
	var ships := 0
	var npcs := {"active": 0, "docked": 0, "wrecks": 0, "awake": 0}  # Bodies in the scene, by what physics does with them
	for body in get_tree().get_nodes_in_group("agent_body"):
		if is_instance_valid(body) and body != player:
			ships += 1
			ships_seen += 1 if player.detects(body) else 0
			if body.get("is_wreck"):
				npcs.wrecks += 1
			elif body.get("is_docked"):
				npcs.docked += 1
			else:
				npcs.active += 1
			if body is RigidBody and not body.sleeping:
				npcs.awake += 1
	lines.append("SHIPS SEEN %d / %d" % [ships_seen, ships])
	var spawner = GlobalRefs.agent_spawner
	var offscreen: int = spawner.offscreen.count() if is_instance_valid(spawner) and is_instance_valid(spawner.get("offscreen")) else 0
	lines.append("NPCS ACTIVE %d  DOCKED %d" % [npcs.active - offscreen, npcs.docked])  # Active: flown, AI and physics every step
	lines.append("OFF-SCREEN %d (by rule, no physics)" % offscreen)
	lines.append("WRECKS %d  BODIES AWAKE %d" % [npcs.wrecks, npcs.awake])
	var brackets_shown := 0
	for instance_id in _world_target_buttons:
		var button = _world_target_buttons[instance_id]
		if is_instance_valid(button) and button.get_meta("shown", false):
			brackets_shown += 1
	lines.append("BRACKETS %d / %d" % [brackets_shown, _world_target_buttons.size()])
	return PoolStringArray(lines).join("\n")


static func _format_distance(metres: float) -> String:
	if is_inf(metres):
		return "INF"
	if metres >= 1000.0:
		return "%.1f km" % (metres / 1000.0)
	return "%.0f m" % metres


# Own signature as a cue, not a number: a bar from the hull's quiet base upward, and a word.
static func describe_signature(player) -> String:
	var base: float = float(player.fit_stats.get("signature", 1500.0)) if player.get("fit_stats") else 1500.0
	var ratio: float = player.get_signature() / max(base, 1.0)
	var word := "QUIET"
	if ratio > Constants.SIG_LEVEL_BLAZING:
		word = "BLAZING"
	elif ratio > Constants.SIG_LEVEL_LOUD:
		word = "LOUD"
	elif ratio > Constants.SIG_LEVEL_ACTIVE:
		word = "ACTIVE"
	var filled: int = int(round(clamp((ratio - 1.0) / (Constants.SIG_LEVEL_BLAZING - 1.0), 0.0, 1.0) * 10.0))
	var bar := ""
	for i in range(10):
		bar += "|" if i < filled else "."
	return "SIGNATURE [%s] %s" % [bar, word]


func _describe_tool_state(tools: Node, index: int) -> String:
	var tool_template = tools.get_tool(index)
	var tool_name: String = tool_template.tool_name.to_upper()
	if tools.has_method("is_retracting") and tools.is_retracting(index):
		return "%s  WINCHING IN %.0f m" % [tool_name, tools.get_retracting_tether(index).get_paid_out_length()]
	if not tools.is_active(index):
		return "%s  OFF" % tool_name
	var tether = tools.get_tether(index)
	if is_instance_valid(tether) and tether.launching:
		return "%s  HOOK OUT %.0f m" % [tool_name, tether.get_hook_distance()]
	if is_instance_valid(tether):
		return "%s  %s %.0f m" % [tool_name, "STRIPPING" if tether.is_reeled_in() else "REELING", tether.get_distance()]
	if tool_template.tool_type == "harpoon":
		return "%s  ARMED" % tool_name
	return "%s  ON  %d%%" % [tool_name, int(tools.get_cycle_progress(index) * 100.0)]


# Frame rate and what the last frame drew (all viewports).
func describe_render_stats() -> String:
	return PoolStringArray([
		"RENDER",
		"FPS %d" % Performance.get_monitor(Performance.TIME_FPS),
		"OBJECTS %d  VERTICES %.1fk" % [Performance.get_monitor(Performance.RENDER_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME) / 1000.0],
		"DRAWS 3D %d  2D %d" % [Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME)],
	]).join("\n")


# Where frame time goes (FrameProfiler, per frame over the last second): physics steps (count and
# time), the rest of the frame (idle processing, rendering, swap), and the marked sections.
func describe_frame_stats() -> String:
	var report: Dictionary = _frame_profiler.report if is_instance_valid(_frame_profiler) else {}
	if report.empty():
		return "FRAME\nmeasuring"
	var sections: Array = []
	for name in ["nav", "ai", "hud", "brackets"]:
		sections.append("%s %.1f" % [name.to_upper(), report.sections.get(name, 0.0)])
	return PoolStringArray([
		"FRAME %.1f ms" % report.frame_ms,
		"PHYSICS %.1f (%.1f steps)  REST %.1f" % [report.physics_ms, report.steps, report.idle_ms],
		"of which ms: " + PoolStringArray(sections).join("  "),
	]).join("\n")


# Cycles the render resolution (WorldRendering.viewport_downscale_factor): x1.0, x0.5, x0.25.
func _on_ButtonRenderScale_pressed() -> void:
	var world_rendering = _get_world_rendering()
	if is_instance_valid(world_rendering):
		world_rendering.cycle_downscale_factor()
	_update_render_scale_label()


func _update_render_scale_label() -> void:
	var world_rendering = _get_world_rendering()
	var factor: float = float(world_rendering.viewport_downscale_factor) if is_instance_valid(world_rendering) else 1.0
	label_render_scale.text = "x%s" % str(factor) if str(factor).find(".") >= 0 else "x%s.0" % str(factor)


# Switches every particle effect on or off (WorldRendering.particles_enabled): they cost a slow CPU.
func _on_ButtonParticlesToggle_pressed() -> void:
	var world_rendering = _get_world_rendering()
	if is_instance_valid(world_rendering):
		world_rendering.toggle_particles()
	_update_particles_label()


func _update_particles_label() -> void:
	var world_rendering = _get_world_rendering()
	var enabled: bool = world_rendering.particles_enabled if is_instance_valid(world_rendering) else true
	label_particles.text = "PARTICLES\n%s" % ("ON" if enabled else "OFF")


func _get_world_rendering() -> Node:
	var scene = get_tree().current_scene if is_inside_tree() else null
	return scene.get_node_or_null("WorldRendering") if is_instance_valid(scene) else null


func _on_ButtonUIOpacity_pressed() -> void:
	"""Handle main HUD transparency (cycle)."""
	_hud_alpha -= 0.25
	self.set_modulate(Color(1, 1, 1, _hud_alpha))
	if _hud_alpha <= 0.0:
		_hud_alpha = 1.0


func _on_zone_unloading(_zone_node) -> void:
	_clear_route_target_overlay()
	_clear_world_target_overlay()


func _reset_travel_state_and_target() -> void:
	_jump_target_id = ""
	_on_Player_Target_Deselected()
	_update_dock_button_label()

func _on_zone_loaded(_zone_node, _zone_path, _agent_container_node) -> void:
	_rebuild_projected_target_overlays()
	_reset_travel_state_and_target()

func _on_sector_changed(_new_sector_id, _old_sector_id) -> void:
	_rebuild_projected_target_overlays()
	_reset_travel_state_and_target()


func _refresh_process_state() -> void:
	set_process(
		is_instance_valid(_main_camera)
		and (
			is_instance_valid(GlobalRefs.player_agent_body)
			or _is_target_valid(_current_target)
			or _route_target_buttons.size() > 0
			or _world_target_buttons.size() > 0
		)
	)


func _on_route_target_button_pressed(route_target) -> void:
	if EventBus:
		EventBus.emit_signal("player_target_selection_requested", route_target)


func _on_world_target_button_pressed(target_node) -> void:
	if EventBus:
		EventBus.emit_signal("player_target_selection_requested", target_node)


func _resolve_target_display_name(target_node) -> String:
	if _is_route_target(target_node):
		if target_node.display_name != "":
			return target_node.display_name
		return target_node.target_sector_id
	if target_node.is_in_group("jump_point"):
		if "target_sector_name" in target_node and target_node.target_sector_name != "":
			return target_node.target_sector_name
		if "target_sector_id" in target_node:
			return target_node.target_sector_id
		return "Jump Point"
	if target_node.is_in_group("dockable_station"):
		if "station_name" in target_node and target_node.station_name != "":
			return target_node.station_name
		return "Station"
	if target_node.has_method("get_display_name"):
		return target_node.get_display_name()
	if target_node.is_in_group("asteroid"):
		return "Asteroid"
	if target_node.is_in_group("agent_body"):
		var ship = target_node.get("ship_template")
		var ship_name: String = ship.ship_model_name if is_instance_valid(ship) else target_node.name
		return "Wreck of " + ship_name if target_node.get("is_wreck") else ship_name
	return target_node.name.replace("_", " ")


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if EventBus:
			if EventBus.is_connected("player_target_selected", self, "_on_Player_Target_Selected"):
				EventBus.disconnect("player_target_selected", self, "_on_Player_Target_Selected")
			if EventBus.is_connected(
				"player_target_deselected", self, "_on_Player_Target_Deselected"
			):
				EventBus.disconnect(
					"player_target_deselected", self, "_on_Player_Target_Deselected"
				)
			if EventBus.is_connected("combat_initiated", self, "_on_combat_initiated"):
				EventBus.disconnect("combat_initiated", self, "_on_combat_initiated")
			if EventBus.is_connected("combat_ended", self, "_on_combat_ended"):
				EventBus.disconnect("combat_ended", self, "_on_combat_ended")
			if EventBus.is_connected("agent_damaged", self, "_on_agent_damaged"):
				EventBus.disconnect("agent_damaged", self, "_on_agent_damaged")
			if EventBus.is_connected("agent_disabled", self, "_on_agent_disabled"):
				EventBus.disconnect("agent_disabled", self, "_on_agent_disabled")
				if EventBus.is_connected("agent_spawned", self, "_on_agent_spawned"):
					EventBus.disconnect("agent_spawned", self, "_on_agent_spawned")
			if EventBus.is_connected("jump_available", self, "_on_jump_available"):
				EventBus.disconnect("jump_available", self, "_on_jump_available")
			if EventBus.is_connected("jump_unavailable", self, "_on_jump_unavailable"):
				EventBus.disconnect("jump_unavailable", self, "_on_jump_unavailable")
				if EventBus.is_connected("zone_unloading", self, "_on_zone_unloading"):
					EventBus.disconnect("zone_unloading", self, "_on_zone_unloading")
			if EventBus.is_connected("zone_loaded", self, "_on_zone_loaded"):
				EventBus.disconnect("zone_loaded", self, "_on_zone_loaded")
			if EventBus.is_connected("sector_changed", self, "_on_sector_changed"):
				EventBus.disconnect("sector_changed", self, "_on_sector_changed")


func _on_combat_initiated(_player_agent, enemy_agents: Array) -> void:
	print("[HUD] Combat initiated with ", enemy_agents.size(), " hostiles")


func _on_combat_ended(result_dict: Dictionary) -> void:
	var outcome = result_dict.get("outcome", "unknown")
	print("[HUD] Combat ended: ", outcome)


func _on_agent_damaged(agent_body, damage_amount: float, _source_agent) -> void:
	if agent_body == GlobalRefs.player_agent_body:
		print("[HUD] Player took ", damage_amount, " damage")


func _on_agent_disabled(agent_body) -> void:
	_queue_world_target_rebuild()  # Relabel the bracket as a wreck.
	if not is_instance_valid(agent_body) or agent_body != GlobalRefs.player_agent_body:
		return
	_watch_own_wreck()


# The ship is lost: the camera orbits the wreck (not tracking a target) so the player can watch the
# scene play out until WorldManager fades to the respawn at home (Constants RESPAWN_DELAY).
func _watch_own_wreck() -> void:
	EventBus.emit_signal("announcement", "SHIP LOST", "danger")
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and is_instance_valid(GlobalRefs.player_agent_body):
		if camera.has_method("set_camera_mode"):
			camera.set_camera_mode(0)  # ORBIT
		camera.set_target_node(GlobalRefs.player_agent_body)
	_refresh_toggle_button_states()


func _update_dock_button_label() -> void:
	if not is_instance_valid(label_button_dock):
		return
	if GameState.player_docked_at != "":
		label_button_dock.text = "UNDOCK"
	elif _current_target != null and (_is_route_target(_current_target) or (is_instance_valid(_current_target) and _current_target.is_in_group("jump_point"))):
		label_button_dock.text = "TRAVEL"
	else:
		label_button_dock.text = "DOCK"


func _instance_projected_target_bracket():
	if ProjectedTargetBracketScene == null:
		return null
	return ProjectedTargetBracketScene.instance()


# --- DELEGATED METHOD WRAPPERS ---

# In-flight drag controller forwards:
# Visible target bracket whose centre is nearest the pointer, among those under it. Used by
# PointerRouter, since brackets themselves never take the mouse.
func find_target_bracket_at(pointer_position: Vector2) -> Control:
	var best: Control = null
	var best_distance: float = INF
	for bracket in _route_target_buttons.values() + _world_target_buttons.values():
		if not is_instance_valid(bracket) or not bracket.is_visible_in_tree():
			continue
		var rect: Rect2 = bracket.get_global_rect()
		if not rect.has_point(pointer_position):
			continue
		var distance: float = pointer_position.distance_squared_to(rect.position + rect.size * 0.5)
		if distance < best_distance:
			best = bracket
			best_distance = distance
	return best


# Projected target projector forwards:
func _get_projected_target_distance_fade_alpha(screen_pos: Vector2, viewport_rect: Rect2) -> float:
	return _target_projector.get_projected_target_distance_fade_alpha(screen_pos, viewport_rect)

func _compute_projected_target_distance_fade_alpha(normalized_distance: float) -> float:
	return _target_projector.compute_projected_target_distance_fade_alpha(normalized_distance)

func _apply_projected_target_distance_fade(button: Control, fade_alpha: float) -> void:
	_target_projector.apply_projected_target_distance_fade(button, fade_alpha)

func _get_projected_target_overlay_kind(target_ref) -> String:
	return _target_projector.get_projected_target_overlay_kind(target_ref)

func _is_projected_target_overlay_enabled(overlay_kind: String) -> bool:
	return _target_projector.is_projected_target_overlay_enabled(overlay_kind)

func _is_stellar_target(target_node: Node) -> bool:
	return _target_projector.is_stellar_target(target_node)

func _is_route_target(target_ref) -> bool:
	return _target_projector.is_route_target(target_ref)

func _is_target_valid(target_ref) -> bool:
	return _target_projector.is_target_valid(target_ref)

func _get_projection_origin() -> Vector3:
	return _target_projector.get_projection_origin()

func _get_target_world_position(target_ref) -> Vector3:
	return _target_projector.get_target_world_position(target_ref)

func _clear_route_target_overlay() -> void:
	_target_projector.clear_route_target_overlay()

func _clear_world_target_overlay() -> void:
	_target_projector.clear_world_target_overlay()

func _rebuild_projected_target_overlays() -> void:
	_target_projector.rebuild_projected_target_overlays()

func _rebuild_route_target_overlay() -> void:
	_target_projector.rebuild_route_target_overlay()

func _sync_route_target_overlay_with_topology() -> void:
	_target_projector.sync_route_target_overlay_with_topology()

func _get_route_target_overlay_signature(sector_id: String) -> String:
	return _target_projector.get_route_target_overlay_signature(sector_id)

func _rebuild_world_target_overlay() -> void:
	_world_rebuild_queued = false
	_target_projector.rebuild_world_target_overlay()

func _update_route_target_overlay() -> void:
	_target_projector.update_route_target_overlay()

func _collect_world_projected_targets() -> Array:
	return _target_projector.collect_world_projected_targets()

func _append_world_projected_targets(node: Node, targets: Array) -> void:
	_target_projector.append_world_projected_targets(node, targets)

func _is_world_projectable_target(node: Node) -> bool:
	return _target_projector.is_world_projectable_target(node)

# `full`: also re-check which brackets show and their cues (else only on the projector's interval).
func _update_world_target_overlay(full: bool = true) -> void:
	FrameProfiler.begin(get_tree(), "brackets")
	_target_projector.update_world_target_overlay(full)
	FrameProfiler.end(get_tree(), "brackets")

func _get_route_target_selection_key() -> String:
	return _target_projector.get_route_target_selection_key()

func _update_route_target_selection_state() -> void:
	_target_projector.update_route_target_selection_state()

func _get_world_target_instance_id() -> int:
	return _target_projector.get_world_target_instance_id()

func _get_projected_target_context_hint(target_ref) -> String:
	return _target_projector.get_projected_target_context_hint(target_ref)

func _update_world_target_selection_state() -> void:
	_target_projector.update_world_target_selection_state()
