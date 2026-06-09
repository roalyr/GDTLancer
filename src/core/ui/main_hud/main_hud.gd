#
# PROJECT: GDTLancer
# MODULE: main_hud.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_005; universe_topology_architecture.md; TACTICAL_TODO.md TASK_2
# LOG_REF: 2026-06-09 20:56:00
#

extends Control

## MainHUD: Primary gameplay HUD displaying player resources, target info, and combat status.
## Manages sub-screens (Station Menu) and docking prompts.

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
const OVERLAY_KIND_STRUCTURES = "structures"
const OVERLAY_KIND_STELLAR = "stellar"
const OVERLAY_KIND_JUMP = "jump"
const INVENTORY_DEFERRED_MESSAGE = "Inventory management is deferred. Use the debug window for current resource inspection until the inventory screen is rebuilt."
const INFLIGHT_DRAG_CONTROL_PATHS = [
	"ScreenControls/CenterLeftZone/ButtonMenu",
	"ScreenControls/CenterLeftZone/ButtonDebug",
	"ScreenControls/CenterLeftZone/ButtonInfo",
	"ScreenControls/CenterLeftZone/ButtonOverlayStructures",
	"ScreenControls/CenterLeftZone/ButtonOverlayStellar",
	"ScreenControls/CenterLeftZone/ButtonOverlayJump",
	"ScreenControls/CenterLeftZone/SliderControlLeft",
	"ScreenControls/BottomCenterZone/ButtonOrbit",
	"ScreenControls/BottomCenterZone/ButtonStop",
	"ScreenControls/BottomCenterZone/ButtonManualFlight",
	"ScreenControls/BottomCenterZone/ButtonApproach",
	"ScreenControls/BottomCenterZone/ButtonFlee",
	"ScreenControls/BottomCenterZone/ButtonDock",
	"ScreenControls/BottomCenterZone/ButtonAttack",
	"ScreenControls/CenterRightZone/ButtonUIOpacity",
	"ScreenControls/CenterRightZone/ButtonCamera",
	"ScreenControls/CenterRightZone/SliderControlRight"
]

# --- Sub-Screens ---
const StationMenuScene = preload("res://scenes/ui/menus/station_menu/StationMenu.tscn")
var _station_menu_instance = null

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

# --- Game Over UI ---
onready var game_over_overlay: Control = $"GameOverOverlay (to be made into a dedicated window like main menu)"
onready var button_return_to_menu: Button = $"GameOverOverlay (to be made into a dedicated window like main menu)/CenterContainer/PanelContainer/VBoxContainer/ButtonReturnToMenu"

# --- State ---
var _current_target = null
var _main_camera: Camera = null
var _player_uid: int = -1
var _is_game_over: bool = false
var _action_feedback_popup: AcceptDialog = null  # Popup for dock/attack feedback
var _hud_alpha = 1.0
var _dock_location_id: String = ""  # Currently available dock location
var _jump_target_id: String = ""  # Currently available jump route target
var _route_target_provider: Reference = RouteTargetProviderScript.new()
var _route_target_buttons: Dictionary = {}
var _route_target_overlay_sector_id: String = ""
var _route_target_overlay_signature: String = ""
var _world_target_buttons: Dictionary = {}
var _tracked_inflight_drag_controls: Array = []
var _tracked_inflight_drag_filters: Dictionary = {}
var _inflight_drag_passthrough_active: bool = false
var _inflight_drag_passthrough_sync_pending: bool = false
var _projected_target_drag_passthrough_active: bool = false
var _projected_target_drag_source: Control = null
var _overlay_structures_enabled: bool = true
var _overlay_stellar_enabled: bool = true
var _overlay_jump_enabled: bool = true

# --- Initialization ---
func _ready():
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

		if not EventBus.is_connected("player_credits_changed", self, "_on_player_credits_changed"):
			EventBus.connect("player_credits_changed", self, "_on_player_credits_changed")

		if not EventBus.is_connected("player_fp_changed", self, "_on_player_fp_changed"):
			EventBus.connect("player_fp_changed", self, "_on_player_fp_changed")

		if not EventBus.is_connected("sim_tick_completed", self, "_on_sim_tick_completed"):
			EventBus.connect("sim_tick_completed", self, "_on_sim_tick_completed")

		if EventBus.has_signal("game_time_advanced") and not EventBus.is_connected("game_time_advanced", self, "_on_game_time_advanced"):
			EventBus.connect("game_time_advanced", self, "_on_game_time_advanced")
			
		EventBus.connect("dock_available", self, "_on_dock_available")
		EventBus.connect("dock_unavailable", self, "_on_dock_unavailable")
		EventBus.connect("player_docked", self, "_on_player_docked")
		EventBus.connect("jump_available", self, "_on_jump_available")
		EventBus.connect("jump_unavailable", self, "_on_jump_unavailable")
		
		# Dock/Attack feedback signals
		EventBus.connect("dock_action_feedback", self, "_on_dock_action_feedback")
		EventBus.connect("attack_action_feedback", self, "_on_attack_action_feedback")

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
		if not EventBus.is_connected("new_game_requested", self, "_on_new_game_requested"):
			EventBus.connect("new_game_requested", self, "_on_new_game_requested")
		if not EventBus.is_connected("game_state_loaded", self, "_on_game_state_loaded"):
			EventBus.connect("game_state_loaded", self, "_on_game_state_loaded")
		if not EventBus.is_connected("zone_unloading", self, "_on_zone_unloading"):
			EventBus.connect("zone_unloading", self, "_on_zone_unloading")
		if not EventBus.is_connected("zone_loaded", self, "_on_zone_loaded"):
			EventBus.connect("zone_loaded", self, "_on_zone_loaded")
		if not EventBus.is_connected("sector_changed", self, "_on_sector_changed"):
			EventBus.connect("sector_changed", self, "_on_sector_changed")

	else:
		printerr("MainHUD Error: EventBus not available!")

	# Connect to CombatSystem signals — DEFERRED (removed: CombatSystem deleted)
	call_deferred("_refresh_player_resources")
	call_deferred("_deferred_refresh_player_hull")
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

	_connect_overlay_toggle_button(button_overlay_structures, "_on_ButtonOverlayStructures_pressed")
	_connect_overlay_toggle_button(button_overlay_stellar, "_on_ButtonOverlayStellar_pressed")
	_connect_overlay_toggle_button(button_overlay_jump, "_on_ButtonOverlayJump_pressed")

	_register_inflight_drag_controls()
	_refresh_toggle_button_states()

	# Initialize TU display
	_refresh_time_display()

	# --- Instance Station Menu sub-screen ---
	_station_menu_instance = StationMenuScene.instance()
	add_child(_station_menu_instance)
	_refresh_process_state()
	_update_dock_button_label()
	call_deferred("_rebuild_projected_target_overlays")


# --- Process Update ---
func _process(_delta):
	# If the selected target is gone, clear the UI state.
	if _current_target != null and not _is_target_valid(_current_target):
		_on_Player_Target_Deselected()
		return

	_update_route_target_overlay()
	_update_world_target_overlay()
	_refresh_toggle_button_states()
	if _inflight_drag_passthrough_active:
		_sync_inflight_drag_passthrough()


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
	_refresh_player_hull()
	_update_dock_button_label()
	
	# If camera is in target tracking mode, switch back to orbit mode
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and camera.get_camera_mode() == 1:  # TARGET_TRACKING
		camera.set_camera_mode(0)  # ORBIT
	_refresh_toggle_button_states()


func _on_agent_despawning(agent_body) -> void:
	# If our selected target is being removed, clear target UI.
	if _current_target is Spatial and is_instance_valid(_current_target) and agent_body == _current_target:
		_on_Player_Target_Deselected()
	call_deferred("_rebuild_world_target_overlay")


func _on_agent_spawned(_agent_body, _init_data) -> void:
	call_deferred("_rebuild_world_target_overlay")


func _on_new_game_requested() -> void:
	# World is about to be reset; clear any stale targeting UI.
	_on_Player_Target_Deselected()
	call_deferred("_deferred_refresh_player_hull")


func _on_game_state_loaded() -> void:
	# After load, clear stale UI and refresh player hull label/bar.
	_on_Player_Target_Deselected()
	call_deferred("_deferred_refresh_player_hull")


func _on_player_credits_changed(_new_credits_value = null):
	_refresh_player_resources()


func _on_player_fp_changed(_new_fp_value = null):
	_refresh_player_resources()


func _refresh_player_resources() -> void:
	var debug_window = _get_debug_window()
	if is_instance_valid(debug_window) and debug_window.has_method("refresh_debug_window_resources"):
		debug_window.call("refresh_debug_window_resources")


func _refresh_time_display() -> void:
	var debug_window = _get_debug_window()
	if is_instance_valid(debug_window) and debug_window.has_method("refresh_debug_window_time_display"):
		debug_window.call("refresh_debug_window_time_display")


func _on_sim_tick_completed(_tick_count: int = 0) -> void:
	_refresh_time_display()
	_refresh_player_resources()
	_sync_route_target_overlay_with_topology()


func _on_game_time_advanced(_seconds_added: int = 0) -> void:
	_refresh_time_display()


func _input(event: InputEvent) -> void:
	if _projected_target_drag_passthrough_active:
		if event is InputEventMouseMotion:
			_forward_inflight_drag_motion(event)
			get_tree().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
			_end_projected_target_drag_passthrough(event)
			get_tree().set_input_as_handled()
			return
	if event is InputEventMouseMotion and not _inflight_drag_passthrough_active:
		if _is_external_camera_drag_active() and _is_pointer_over_tracked_inflight_control(event.position):
			_set_inflight_drag_passthrough(true)
			_forward_inflight_drag_motion(event)
			get_tree().set_input_as_handled()
			return
	if not _inflight_drag_passthrough_active:
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		_forward_inflight_drag_release(event)
		_set_inflight_drag_passthrough(false)
		get_tree().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if EventBus:
			EventBus.emit_signal("main_menu_requested")
			get_tree().set_input_as_handled()


func _on_ButtonMenu_pressed() -> void:
	"""Handle menu button press - opens main menu."""
	if EventBus:
		EventBus.emit_signal("main_menu_requested")


func _on_ButtonDebug_pressed() -> void:
	var debug_window = _get_debug_window()
	if is_instance_valid(debug_window) and debug_window.has_method("toggle_debug_window"):
		debug_window.call("toggle_debug_window")


func _on_ButtonCamera_pressed() -> void:
	"""Handle camera button press - toggles between orbit and target-tracking mode."""
	var camera = GlobalRefs.main_camera
	if not is_instance_valid(camera):
		return
	
	# Toggle camera mode
	camera.toggle_camera_mode()
	
	# If switching to target tracking mode, set the look_at_target
	if camera.get_camera_mode() == CAMERA_MODE_TARGET_TRACKING:
		if _current_target is Spatial and is_instance_valid(_current_target):
			camera.set_look_at_target(_current_target)
		else:
			# No target selected, switch back to orbit mode
			camera.set_camera_mode(0)  # ORBIT = 0
			print("Camera: No target selected for tracking mode.")
	_refresh_toggle_button_states()


func _connect_overlay_toggle_button(button: TextureButton, method_name: String) -> void:
	if not is_instance_valid(button):
		return
	if not button.is_connected("pressed", self, method_name):
		button.connect("pressed", self, method_name)


func _register_inflight_drag_controls() -> void:
	for control_path in INFLIGHT_DRAG_CONTROL_PATHS:
		var control = get_node_or_null(control_path)
		if control is Control:
			_track_inflight_drag_control(control)


func _track_inflight_drag_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if _tracked_inflight_drag_controls.has(control):
		return
	_tracked_inflight_drag_controls.append(control)
	_tracked_inflight_drag_filters[control.get_instance_id()] = control.mouse_filter
	if not control.is_connected("gui_input", self, "_on_inflight_drag_control_gui_input"):
		control.connect("gui_input", self, "_on_inflight_drag_control_gui_input", [control])


func _untrack_inflight_drag_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	_tracked_inflight_drag_controls.erase(control)
	_tracked_inflight_drag_filters.erase(control.get_instance_id())
	if control.is_connected("gui_input", self, "_on_inflight_drag_control_gui_input"):
		control.disconnect("gui_input", self, "_on_inflight_drag_control_gui_input")


func _on_inflight_drag_control_gui_input(event: InputEvent, control: Control) -> void:
	if not is_instance_valid(control):
		return
	if not (event is InputEventMouseMotion):
		return
	if not _is_external_camera_drag_active():
		return
	_set_inflight_drag_passthrough(true)
	_forward_inflight_drag_motion(event)
	get_tree().set_input_as_handled()


func begin_projected_target_drag_passthrough(source_control: Control, initial_motion_event: InputEventMouseMotion = null) -> void:
	_projected_target_drag_source = source_control if is_instance_valid(source_control) else null
	_projected_target_drag_passthrough_active = true
	_set_inflight_drag_passthrough(true)
	if initial_motion_event != null:
		_forward_inflight_drag_motion(initial_motion_event)


func is_projected_target_drag_passthrough_active() -> bool:
	return _projected_target_drag_passthrough_active


func _end_projected_target_drag_passthrough(release_event: InputEventMouseButton = null) -> void:
	if is_instance_valid(_projected_target_drag_source) and _projected_target_drag_source.has_method("reset_pointer_tracking_from_main_hud"):
		_projected_target_drag_source.call("reset_pointer_tracking_from_main_hud")
	_projected_target_drag_source = null
	_projected_target_drag_passthrough_active = false
	if release_event != null:
		_forward_inflight_drag_release(release_event)
	else:
		var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _main_camera
		if is_instance_valid(camera) and camera.has_method("set_is_rotating"):
			camera.set_is_rotating(false)
	_set_inflight_drag_passthrough(false)


func _is_external_camera_drag_active() -> bool:
	var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _main_camera
	return is_instance_valid(camera) and camera.has_method("is_externally_rotating") and camera.is_externally_rotating()


func _set_inflight_drag_passthrough(is_active: bool) -> void:
	_inflight_drag_passthrough_active = is_active
	_compact_tracked_inflight_drag_controls()
	for control in _tracked_inflight_drag_controls:
		if not is_instance_valid(control):
			continue
		var control_id = control.get_instance_id()
		if is_active:
			if not _tracked_inflight_drag_filters.has(control_id):
				_tracked_inflight_drag_filters[control_id] = control.mouse_filter
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			control.mouse_filter = _tracked_inflight_drag_filters.get(
				control_id,
				Control.MOUSE_FILTER_STOP
			)
	_refresh_process_state()


func _compact_tracked_inflight_drag_controls() -> void:
	var valid_controls: Array = []
	for control in _tracked_inflight_drag_controls:
		if is_instance_valid(control):
			valid_controls.append(control)
	_tracked_inflight_drag_controls = valid_controls


func _is_pointer_over_tracked_inflight_control(pointer_position: Vector2) -> bool:
	_compact_tracked_inflight_drag_controls()
	for control in _tracked_inflight_drag_controls:
		if not is_instance_valid(control):
			continue
		if not control.visible:
			continue
		if control.get_global_rect().has_point(pointer_position):
			return true
	return false


func _forward_inflight_drag_motion(motion_event: InputEventMouseMotion) -> void:
	var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _main_camera
	if is_instance_valid(camera) and camera.has_method("_unhandled_input"):
		camera.call("_unhandled_input", motion_event)


func _forward_inflight_drag_release(release_event: InputEventMouseButton) -> void:
	var player_agent = GlobalRefs.player_agent_body
	if is_instance_valid(player_agent):
		var player_controller = player_agent.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME)
		if is_instance_valid(player_controller) and player_controller.has_method("_unhandled_input"):
			player_controller.call("_unhandled_input", release_event)
	var camera = GlobalRefs.main_camera if is_instance_valid(GlobalRefs.main_camera) else _main_camera
	if is_instance_valid(camera) and camera.has_method("set_is_rotating"):
		camera.set_is_rotating(false)


func _sync_inflight_drag_passthrough() -> void:
	if _projected_target_drag_passthrough_active and not _is_external_camera_drag_active():
		_end_projected_target_drag_passthrough()
		return
	if _inflight_drag_passthrough_active and not _is_external_camera_drag_active():
		_set_inflight_drag_passthrough(false)

# --- Target Name Resolution ---
func _resolve_target_display_name(target_node) -> String:
	if _is_route_target(target_node):
		if target_node.display_name != "":
			return target_node.display_name
		return target_node.target_sector_id
	# Jump points: show destination name
	if target_node.is_in_group("jump_point"):
		if "target_sector_name" in target_node and target_node.target_sector_name != "":
			return target_node.target_sector_name
		if "target_sector_id" in target_node:
			return target_node.target_sector_id
		return "Jump Point"
	# Dockable stations: show station_name
	if target_node.is_in_group("dockable_station"):
		if "station_name" in target_node and target_node.station_name != "":
			return target_node.station_name
		return "Station"
	# Agents (NPCs/player ships): resolve character name
	if "character_uid" in target_node:
		var char_uid = target_node.character_uid
		# GameState.characters keyed by uid, values are CharacterTemplate
		if GameState.characters.has(char_uid):
			var char_res = GameState.characters[char_uid]
			if char_res and "character_name" in char_res:
				return char_res.character_name
		# Try string/int key mismatch
		var alt_key = int(char_uid) if typeof(char_uid) == TYPE_STRING else str(char_uid)
		if GameState.characters.has(alt_key):
			var char_res = GameState.characters[alt_key]
			if char_res and "character_name" in char_res:
				return char_res.character_name
		return target_node.name
	# Fallback: prettify node name (remove underscores, capitalize)
	return target_node.name.replace("_", " ")

# --- Cleanup ---
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
		_refresh_player_hull()


func _on_agent_disabled(agent_body) -> void:
	if _is_game_over:
		return
	if not is_instance_valid(agent_body):
		return
	if not is_instance_valid(GlobalRefs.player_agent_body):
		return
	if agent_body != GlobalRefs.player_agent_body:
		return
	_show_game_over_overlay()


func _show_game_over_overlay() -> void:
	_is_game_over = true
	if is_instance_valid(game_over_overlay):
		game_over_overlay.visible = true
		game_over_overlay.raise()
		if is_instance_valid(button_return_to_menu):
			button_return_to_menu.grab_focus()
	# Pause gameplay while the overlay is visible.
	get_tree().paused = true


func _on_ButtonReturnToMenu_pressed() -> void:
	# Unpause first so the menu and world manager can react normally.
	get_tree().paused = false
	_is_game_over = false
	if is_instance_valid(game_over_overlay):
		game_over_overlay.visible = false
	if EventBus:
		EventBus.emit_signal("main_menu_requested")


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

func _on_ButtonInteract_pressed():
	if EventBus:
		EventBus.emit_signal("player_interact_pressed")


func _on_ButtonDock_pressed():
	if GameState.player_docked_at != "":
		if is_instance_valid(_station_menu_instance) and _station_menu_instance.has_method("open_for_current_dock"):
			_station_menu_instance.call("open_for_current_dock")
		return
	if EventBus:
		EventBus.emit_signal("player_dock_pressed")


func _on_ButtonAttack_pressed():
	if EventBus:
		EventBus.emit_signal("player_attack_pressed")

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


# --- Dock/Attack Feedback Handlers ---
func _on_dock_action_feedback(success: bool, message: String) -> void:
	_show_action_feedback_popup("Dock", success, message)


func _on_attack_action_feedback(success: bool, message: String) -> void:
	_show_action_feedback_popup("Attack", success, message)


func _show_action_feedback_popup(action_type: String, success: bool, message: String) -> void:
	if not is_instance_valid(_action_feedback_popup):
		_action_feedback_popup = AcceptDialog.new()
		_action_feedback_popup.pause_mode = Node.PAUSE_MODE_PROCESS
		add_child(_action_feedback_popup)
	
	if success:
		_action_feedback_popup.window_title = action_type
	else:
		_action_feedback_popup.window_title = action_type + " Failed"
	
	_action_feedback_popup.dialog_text = message
	_action_feedback_popup.popup_centered()


func _on_SliderControlRight_value_changed(value):
	# SPEED (maximum) limiter.
	# This slider is inverted (rotated by 180) for the sake of appearance.
	if EventBus:
		EventBus.emit_signal("player_ship_speed_changed", value)


func _on_ButtonCharacter_pressed():
	_toggle_debug_panel("SimDebugPanel", "_toggle")


func _on_ButtonNarrativeStatus_pressed():
	_toggle_debug_panel("DebugMapPanel", "_toggle_panel")


func _on_ButtonInventory_pressed():
	_show_action_feedback_popup("Inventory", false, INVENTORY_DEFERRED_MESSAGE)


func _toggle_debug_panel(panel_name: String, toggle_method: String) -> void:
	var scene_root = get_tree().current_scene
	if not is_instance_valid(scene_root):
		return
	var panel = scene_root.find_node(panel_name, true, false)
	if not is_instance_valid(panel):
		printerr("MainHUD: Missing debug panel: %s" % panel_name)
		return
	if panel.has_method(toggle_method):
		panel.call(toggle_method)


func _get_debug_window() -> Node:
	var parent_node = get_parent()
	if not is_instance_valid(parent_node):
		return null
	return parent_node.get_node_or_null("DebugWindow")


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
	return look_at_target is Spatial and is_instance_valid(look_at_target)


func _refresh_toggle_button_states() -> void:
	_apply_button_toggle_state(button_overlay_structures, _overlay_structures_enabled)
	_apply_button_toggle_state(button_overlay_stellar, _overlay_stellar_enabled)
	_apply_button_toggle_state(button_overlay_jump, _overlay_jump_enabled)

	var is_free_flight_active = _is_player_free_flight_active()
	var active_navigation_command_type = _get_player_navigation_command_type()
	_apply_button_toggle_state(button_manual_flight, is_free_flight_active)
	_apply_button_toggle_state(button_orbit, not is_free_flight_active and active_navigation_command_type == NAV_COMMAND_ORBIT)
	_apply_button_toggle_state(button_approach, not is_free_flight_active and active_navigation_command_type == NAV_COMMAND_APPROACH)
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


func _get_projected_target_distance_fade_alpha(screen_pos: Vector2, viewport_rect: Rect2) -> float:
	if not _is_projected_target_center_fade_enabled():
		return 1.0
	var viewport_center = viewport_rect.position + (viewport_rect.size / 2.0)
	var max_distance = max((viewport_rect.size / 2.0).length(), 1.0)
	var normalized_distance = clamp(screen_pos.distance_to(viewport_center) / max_distance, 0.0, 1.0)
	return _compute_projected_target_distance_fade_alpha(normalized_distance)


func _compute_projected_target_distance_fade_alpha(normalized_distance: float) -> float:
	var safe_normalized_distance = clamp(normalized_distance, 0.0, 1.0)
	return lerp(1.0, PROJECTED_TARGET_EDGE_ALPHA, pow(safe_normalized_distance, PROJECTED_TARGET_EDGE_POW))


func _apply_projected_target_distance_fade(button: Control, fade_alpha: float) -> void:
	if is_instance_valid(button) and button.has_method("set_distance_fade_alpha"):
		button.call("set_distance_fade_alpha", fade_alpha)


func _get_projected_target_overlay_kind(target_ref) -> String:
	if _is_route_target(target_ref):
		var dest_id = target_ref.get("target_sector_id")
		var sector_type = "star"
		if dest_id != null and dest_id != "":
			if GameState.world_topology.has(dest_id) and GameState.world_topology[dest_id].has("sector_type"):
				sector_type = GameState.world_topology[dest_id].sector_type
			elif TemplateDatabase.locations.has(dest_id):
				var loc = TemplateDatabase.locations[dest_id]
				if loc != null and loc.get("sector_type") != null:
					sector_type = loc.sector_type
		if sector_type == "star":
			return OVERLAY_KIND_JUMP
		else:
			return OVERLAY_KIND_STELLAR
	if not (target_ref is Node and is_instance_valid(target_ref)):
		return ""
	if target_ref.is_in_group("jump_point"):
		return OVERLAY_KIND_JUMP
	if _is_stellar_target(target_ref):
		return OVERLAY_KIND_STELLAR
	return OVERLAY_KIND_STRUCTURES


func _is_projected_target_overlay_enabled(overlay_kind: String) -> bool:
	match overlay_kind:
		OVERLAY_KIND_STRUCTURES:
			return _overlay_structures_enabled
		OVERLAY_KIND_STELLAR:
			return _overlay_stellar_enabled
		OVERLAY_KIND_JUMP:
			return _overlay_jump_enabled
		_:
			return true


func _is_stellar_target(target_node: Node) -> bool:
	if not (target_node is StaticBody):
		return false
	if target_node.is_in_group("dockable_station") or target_node.is_in_group("jump_point"):
		return false
	var lower_name = str(target_node.name).to_lower()
	for token in ["star", "planet", "moon", "sun"]:
		if lower_name.find(token) != -1:
			return true
	return false


# --- Combat HUD Functions (stubs — CombatSystem removed, rebuild later) ---

func _connect_combat_signals() -> void:
	# CombatSystem removed — rebuild later on Agent layer
	pass


func _refresh_player_hull() -> void:
	var debug_window = _get_debug_window()
	if is_instance_valid(debug_window) and debug_window.has_method("refresh_debug_window_player_hull"):
		debug_window.call("refresh_debug_window_player_hull")


func _deferred_refresh_player_hull() -> void:
	# Simple deferred call — simulation state is always available
	_refresh_player_hull()


func _on_any_damage_dealt_refresh_player(_target_uid: int, _amount: float, _source_uid: int) -> void:
	# Keep player hull display current even if damage events come through CombatSystem only.
	_refresh_player_hull()


func _on_ButtonUIOpacity_pressed() -> void:
	"""Handle main HUD transparency (cycle)."""
	_hud_alpha -= 0.25
	self.set_modulate(Color(1, 1, 1, _hud_alpha))
	if _hud_alpha <= 0.0:
		_hud_alpha = 1.0

func _on_zone_unloading(_zone_node) -> void:
	_clear_route_target_overlay()
	_clear_world_target_overlay()


func _on_zone_loaded(_zone_node, _zone_path, _agent_container_node) -> void:
	_rebuild_projected_target_overlays()


func _on_sector_changed(_new_sector_id, _old_sector_id) -> void:
	_rebuild_projected_target_overlays()


func _is_route_target(target_ref) -> bool:
	return target_ref != null and target_ref.get("target_kind") == "jump_route"


func _is_target_valid(target_ref) -> bool:
	if target_ref == null:
		return false
	if _is_route_target(target_ref):
		return true
	return is_instance_valid(target_ref)


func _refresh_process_state() -> void:
	set_process(
		is_instance_valid(_main_camera)
		and (
			_is_target_valid(_current_target)
			or _route_target_buttons.size() > 0
			or _world_target_buttons.size() > 0
			or _inflight_drag_passthrough_active
		)
	)


func _get_projection_origin() -> Vector3:
	if is_instance_valid(GlobalRefs.player_agent_body):
		return GlobalRefs.player_agent_body.global_transform.origin
	if is_instance_valid(_main_camera):
		return _main_camera.global_transform.origin
	return Vector3.ZERO


func _get_target_world_position(target_ref) -> Vector3:
	if _is_route_target(target_ref):
		return target_ref.get_projection_world_position(
			_get_projection_origin(),
			Constants.SECTOR_JUMP_ARRIVAL_RADIUS
		)
	if target_ref is Spatial and is_instance_valid(target_ref):
		return target_ref.global_transform.origin
	return Vector3.ZERO


func _clear_route_target_overlay() -> void:
	for selection_key in _route_target_buttons:
		var button = _route_target_buttons[selection_key]
		if is_instance_valid(button):
			_untrack_inflight_drag_control(button)
			button.queue_free()
	_route_target_buttons.clear()
	_route_target_overlay_sector_id = ""
	_route_target_overlay_signature = ""
	_refresh_process_state()


func _clear_world_target_overlay() -> void:
	for instance_id in _world_target_buttons:
		var button = _world_target_buttons[instance_id]
		if is_instance_valid(button):
			_untrack_inflight_drag_control(button)
			button.queue_free()
	_world_target_buttons.clear()
	_refresh_process_state()


func _rebuild_projected_target_overlays() -> void:
	_rebuild_route_target_overlay()
	_rebuild_world_target_overlay()


func _rebuild_route_target_overlay() -> void:
	_clear_route_target_overlay()
	if not is_instance_valid(projected_target_overlay):
		return
	var current_sector_id: String = GameState.current_sector_id
	if current_sector_id == "":
		return
	_route_target_overlay_sector_id = current_sector_id
	_route_target_overlay_signature = _get_route_target_overlay_signature(current_sector_id)
	var route_targets: Array = _route_target_provider.build_targets_for_sector(current_sector_id)
	for route_target in route_targets:
		var button = _instance_projected_target_bracket()
		if button == null:
			continue
		button.name = "Route_%s" % route_target.target_sector_id
		button.configure_target(route_target)
		button.connect("pressed", self, "_on_route_target_button_pressed", [route_target])
		projected_target_overlay.add_child(button)
		_track_inflight_drag_control(button)
		_route_target_buttons[route_target.selection_key] = button
	_update_route_target_selection_state()
	_refresh_process_state()


func _sync_route_target_overlay_with_topology() -> void:
	var current_sector_id: String = GameState.current_sector_id
	var route_signature: String = _get_route_target_overlay_signature(current_sector_id)
	if current_sector_id != _route_target_overlay_sector_id or route_signature != _route_target_overlay_signature:
		_rebuild_route_target_overlay()


func _get_route_target_overlay_signature(sector_id: String) -> String:
	if sector_id == "":
		return ""
	var connections: Array = GameState.world_topology.get(sector_id, {}).get("connections", [])
	var normalized_connections: Array = []
	for target_sector_id in connections:
		normalized_connections.append(str(target_sector_id))
	normalized_connections.sort()
	return "%s|%s" % [sector_id, str(normalized_connections)]


func _rebuild_world_target_overlay() -> void:
	_clear_world_target_overlay()
	if not is_instance_valid(projected_target_overlay):
		return
	var world_targets: Array = _collect_world_projected_targets()
	for target_node in world_targets:
		var button = _instance_projected_target_bracket()
		if button == null:
			continue
		button.name = "World_%s" % target_node.get_instance_id()
		button.configure_target(target_node, _resolve_target_display_name(target_node))
		button.connect("pressed", self, "_on_world_target_button_pressed", [target_node])
		projected_target_overlay.add_child(button)
		_track_inflight_drag_control(button)
		_world_target_buttons[target_node.get_instance_id()] = button
	_update_world_target_selection_state()
	_refresh_process_state()


func _instance_projected_target_bracket():
	if ProjectedTargetBracketScene == null:
		return null
	return ProjectedTargetBracketScene.instance()


func _update_route_target_overlay() -> void:
	if not is_instance_valid(_main_camera):
		return
	var camera_fwd = -_main_camera.global_transform.basis.z.normalized()
	var viewport_rect = get_viewport_rect()
	for selection_key in _route_target_buttons:
		var button = _route_target_buttons[selection_key]
		if not is_instance_valid(button):
			continue
		var route_target = button.target_ref
		if not _is_route_target(route_target):
			button.visible = false
			_apply_projected_target_distance_fade(button, 1.0)
			continue
		var overlay_kind = _get_projected_target_overlay_kind(route_target)
		if not _is_projected_target_overlay_enabled(overlay_kind):
			button.visible = false
			_apply_projected_target_distance_fade(button, 1.0)
			continue
		var target_world_position: Vector3 = _get_target_world_position(route_target)
		var target_dir = (target_world_position - _main_camera.global_transform.origin).normalized()
		var is_in_front = target_dir.dot(camera_fwd) >= 0
		var screen_pos = _main_camera.unproject_position(target_world_position)
		var is_on_screen = viewport_rect.has_point(screen_pos)
		button.visible = is_in_front and is_on_screen
		if button.visible:
			button.rect_position = screen_pos - (button.rect_size / 2.0)
			_apply_projected_target_distance_fade(button, _get_projected_target_distance_fade_alpha(screen_pos, viewport_rect))
		else:
			_apply_projected_target_distance_fade(button, 1.0)


func _collect_world_projected_targets() -> Array:
	var targets: Array = []
	if not is_instance_valid(GlobalRefs.current_zone):
		return targets
	_append_world_projected_targets(GlobalRefs.current_zone, targets)
	return targets


func _append_world_projected_targets(node: Node, targets: Array) -> void:
	if _is_world_projectable_target(node):
		targets.append(node)
	for child in node.get_children():
		_append_world_projected_targets(child, targets)


func _is_world_projectable_target(node: Node) -> bool:
	if not (node is Spatial):
		return false
	if node == GlobalRefs.player_agent_body:
		return false
	if node.is_in_group("jump_point"):
		return false
	if node is RigidBody:
		if node.has_method("is_player") and node.is_player():
			return false
		return true
	if node is StaticBody:
		return true
	return false


func _update_world_target_overlay() -> void:
	if not is_instance_valid(_main_camera):
		return
	var camera_fwd = -_main_camera.global_transform.basis.z.normalized()
	var viewport_rect = get_viewport_rect()
	for instance_id in _world_target_buttons:
		var button = _world_target_buttons[instance_id]
		if not is_instance_valid(button):
			continue
		var target_node = button.target_ref
		if not (target_node is Spatial and is_instance_valid(target_node)):
			button.visible = false
			_apply_projected_target_distance_fade(button, 1.0)
			continue
		var overlay_kind = _get_projected_target_overlay_kind(target_node)
		if not _is_projected_target_overlay_enabled(overlay_kind):
			button.visible = false
			_apply_projected_target_distance_fade(button, 1.0)
			continue
		var target_world_position: Vector3 = _get_target_world_position(target_node)
		var target_dir = (target_world_position - _main_camera.global_transform.origin).normalized()
		var is_in_front = target_dir.dot(camera_fwd) >= 0
		var screen_pos = _main_camera.unproject_position(target_world_position)
		var is_on_screen = viewport_rect.has_point(screen_pos)
		button.visible = is_in_front and is_on_screen
		if button.visible:
			button.rect_position = screen_pos - (button.rect_size / 2.0)
			_apply_projected_target_distance_fade(button, _get_projected_target_distance_fade_alpha(screen_pos, viewport_rect))
		else:
			_apply_projected_target_distance_fade(button, 1.0)


func _get_route_target_selection_key() -> String:
	if _is_route_target(_current_target):
		return _current_target.selection_key
	return ""


func _update_route_target_selection_state() -> void:
	var selected_key = _get_route_target_selection_key()
	for selection_key in _route_target_buttons:
		var button = _route_target_buttons[selection_key]
		if is_instance_valid(button):
			button.set_selected_state(selection_key == selected_key)
			if button.has_method("set_context_hint"):
				button.call("set_context_hint", _get_projected_target_context_hint(button.target_ref))


func _get_world_target_instance_id() -> int:
	if _current_target is Spatial and is_instance_valid(_current_target) and not _is_route_target(_current_target):
		return _current_target.get_instance_id()
	return -1


func _update_dock_button_label() -> void:
	if not is_instance_valid(label_button_dock):
		return
	if _current_target != null and (_is_route_target(_current_target) or (is_instance_valid(_current_target) and _current_target.is_in_group("jump_point"))):
		label_button_dock.text = "TRAVEL"
	else:
		label_button_dock.text = "DOCK"


func _get_projected_target_context_hint(target_ref) -> String:
	if _is_route_target(target_ref):
		return ""
	if target_ref is Node and is_instance_valid(target_ref) and target_ref.is_in_group("dockable_station"):
		return "Dock Target"
	if target_ref == _current_target and _is_target_valid(target_ref):
		return "Target Locked"
	return ""


func _update_world_target_selection_state() -> void:
	var selected_instance_id = _get_world_target_instance_id()
	for instance_id in _world_target_buttons:
		var button = _world_target_buttons[instance_id]
		if is_instance_valid(button):
			button.set_selected_state(instance_id == selected_instance_id)
			if button.has_method("set_context_hint"):
				button.call("set_context_hint", _get_projected_target_context_hint(button.target_ref))


func _on_route_target_button_pressed(route_target) -> void:
	if EventBus:
		EventBus.emit_signal("player_target_selection_requested", route_target)


func _on_world_target_button_pressed(target_node) -> void:
	if EventBus:
		EventBus.emit_signal("player_target_selection_requested", target_node)
