# PROJECT: GDTLancer
# MODULE: main_hud.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-MASTER-DESIGN-DIRECTIVE.md §2; TRUTH_GAME-LOOP-VISION.md §5
# LOG_REF: 2026-06-20 20:45:00

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
	"ScreenControls/BottomCenterZone/ButtonInteract",
	"ScreenControls/CenterRightZone/ButtonUIOpacity",
	"ScreenControls/CenterRightZone/ButtonCamera",
	"ScreenControls/CenterRightZone/SliderControlRight"
]

const HUDDragControllerClass = preload("res://src/core/ui/main_hud/hud_drag_controller.gd")
const HUDTargetProjectorClass = preload("res://src/core/ui/main_hud/hud_target_projector.gd")

# --- Sub-Screens ---
const StationMenuScene = preload("res://scenes/ui/menus/station_menu/StationMenu.tscn")
var _station_menu_instance = null
const InteractionWindowScene = preload("res://scenes/ui/menus/interaction_window/InteractionWindow.tscn")
var _interaction_window_instance = null

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

# --- Delegates ---
var _drag_controller: Reference
var _target_projector: Reference

func _init() -> void:
	_drag_controller = HUDDragControllerClass.new(self)
	_target_projector = HUDTargetProjectorClass.new(self)

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

		if not EventBus.is_connected("player_wealth_changed", self, "_on_player_wealth_changed"):
			EventBus.connect("player_wealth_changed", self, "_on_player_wealth_changed")

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
		EventBus.connect("interact_action_feedback", self, "_on_interact_action_feedback")

		# NPC interaction — open InteractionWindow as gatekeeper
		if not EventBus.is_connected("player_npc_interact_requested", self, "_on_player_npc_interact_requested"):
			EventBus.connect("player_npc_interact_requested", self, "_on_player_npc_interact_requested")

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

	pause_mode = PAUSE_MODE_PROCESS

	# --- Instance Station Menu sub-screen ---
	_station_menu_instance = StationMenuScene.instance()
	add_child(_station_menu_instance)

	# --- Instance Interaction Window sub-screen ---
	_interaction_window_instance = InteractionWindowScene.instance()
	add_child(_interaction_window_instance)
	if is_instance_valid(_interaction_window_instance):
		_interaction_window_instance.connect("closed", self, "_on_interaction_window_closed")
	
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


func _on_player_wealth_changed(_new_tier = null, _new_progress = null):
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
		if is_instance_valid(_station_menu_instance) and _station_menu_instance.has_method("open_for_current_dock"):
			_station_menu_instance.call("open_for_current_dock")
		return
	if EventBus:
		EventBus.emit_signal("player_dock_pressed")


func _on_ButtonInteract_pressed():
	if EventBus:
		EventBus.emit_signal("player_interact_pressed")


func _on_player_npc_interact_requested(agent_id: String, target_node: Spatial) -> void:
	set_ui_mode("MODE_B")
	if is_instance_valid(_interaction_window_instance):
		_interaction_window_instance.open_for_target(agent_id, target_node)


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


func _on_interact_action_feedback(success: bool, message: String) -> void:
	_show_action_feedback_popup("Interact", success, message)


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


func _refresh_player_hull() -> void:
	var debug_window = _get_debug_window()
	if is_instance_valid(debug_window) and debug_window.has_method("refresh_debug_window_player_hull"):
		debug_window.call("refresh_debug_window_player_hull")


func _deferred_refresh_player_hull() -> void:
	_refresh_player_hull()


func _on_any_damage_dealt_refresh_player(_target_uid: int, _amount: float, _source_uid: int) -> void:
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
	if "character_uid" in target_node:
		var char_uid = target_node.character_uid
		if GameState.characters.has(char_uid):
			var char_res = GameState.characters[char_uid]
			if char_res and "character_name" in char_res:
				return char_res.character_name
		var alt_key = int(char_uid) if typeof(char_uid) == TYPE_STRING else str(char_uid)
		if GameState.characters.has(alt_key):
			var char_res = GameState.characters[alt_key]
			if char_res and "character_name" in char_res:
				return char_res.character_name
		return target_node.name
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


func _update_dock_button_label() -> void:
	if not is_instance_valid(label_button_dock):
		return
	if _current_target != null and (_is_route_target(_current_target) or (is_instance_valid(_current_target) and _current_target.is_in_group("jump_point"))):
		label_button_dock.text = "TRAVEL"
	else:
		label_button_dock.text = "DOCK"


func _instance_projected_target_bracket():
	if ProjectedTargetBracketScene == null:
		return null
	return ProjectedTargetBracketScene.instance()


# --- DELEGATED METHOD WRAPPERS ---

# In-flight drag controller forwards:
func _register_inflight_drag_controls() -> void:
	_drag_controller.register_inflight_drag_controls()

func _track_inflight_drag_control(control: Control) -> void:
	_drag_controller.track_inflight_drag_control(control)

func _untrack_inflight_drag_control(control: Control) -> void:
	_drag_controller.untrack_inflight_drag_control(control)

func _on_inflight_drag_control_gui_input(event: InputEvent, control: Control) -> void:
	_drag_controller.on_inflight_drag_control_gui_input(event, control)

func begin_projected_target_drag_passthrough(source_control: Control, initial_motion_event: InputEventMouseMotion = null) -> void:
	_drag_controller.begin_projected_target_drag_passthrough(source_control, initial_motion_event)

func is_projected_target_drag_passthrough_active() -> bool:
	return _drag_controller.is_projected_target_drag_passthrough_active()

func _end_projected_target_drag_passthrough(release_event: InputEventMouseButton = null) -> void:
	_drag_controller.end_projected_target_drag_passthrough(release_event)

func _is_external_camera_drag_active() -> bool:
	return _drag_controller.is_external_camera_drag_active()

func _set_inflight_drag_passthrough(is_active: bool) -> void:
	_drag_controller.set_inflight_drag_passthrough(is_active)

func _compact_tracked_inflight_drag_controls() -> void:
	_drag_controller.compact_tracked_inflight_drag_controls()

func _is_pointer_over_tracked_inflight_control(pointer_position: Vector2) -> bool:
	return _drag_controller.is_pointer_over_tracked_inflight_control(pointer_position)

func _forward_inflight_drag_motion(motion_event: InputEventMouseMotion) -> void:
	_drag_controller.forward_inflight_drag_motion(motion_event)

func _forward_inflight_drag_release(release_event: InputEventMouseButton) -> void:
	_drag_controller.forward_inflight_drag_release(release_event)

func _sync_inflight_drag_passthrough() -> void:
	_drag_controller.sync_inflight_drag_passthrough()


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
	_target_projector.rebuild_world_target_overlay()

func _update_route_target_overlay() -> void:
	_target_projector.update_route_target_overlay()

func _collect_world_projected_targets() -> Array:
	return _target_projector.collect_world_projected_targets()

func _append_world_projected_targets(node: Node, targets: Array) -> void:
	_target_projector.append_world_projected_targets(node, targets)

func _is_world_projectable_target(node: Node) -> bool:
	return _target_projector.is_world_projectable_target(node)

func _update_world_target_overlay() -> void:
	_target_projector.update_world_target_overlay()

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


func set_ui_mode(new_mode: String) -> void:
	if new_mode == "MODE_B":
		GameState.current_ui_mode = "MODE_B"
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# Hide Mode A HUD elements
		if has_node("ScreenControls"):
			get_node("ScreenControls").visible = false
		if is_instance_valid(projected_target_overlay):
			projected_target_overlay.visible = false
			
		EventBus.emit_signal("ui_mode_changed", "MODE_B")
		
	elif new_mode == "MODE_A":
		GameState.current_ui_mode = "MODE_A"
		get_tree().paused = false
		
		# Restore appropriate mouse mode
		var is_free_flight = _is_player_free_flight_active()
		if is_free_flight:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
		# Show Mode A HUD elements
		if has_node("ScreenControls"):
			get_node("ScreenControls").visible = true
		if is_instance_valid(projected_target_overlay):
			projected_target_overlay.visible = true
			
		# Ensure Mode B panels are closed
		if is_instance_valid(_interaction_window_instance):
			_interaction_window_instance.visible = false
			
		EventBus.emit_signal("ui_mode_changed", "MODE_A")


func _on_interaction_window_closed() -> void:
	set_ui_mode("MODE_A")
