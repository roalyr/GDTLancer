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
const PointerRouterClass = preload("res://src/core/ui/pointer_router.gd")
const FittingWindowScene = preload("res://scenes/ui/menus/fitting_window.tscn")
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
onready var label_combat_readout: Label = $ScreenControls/TopLeftZone/LabelCombatReadout
onready var label_docked_banner: Label = $ScreenControls/LabelDockedBanner
onready var button_ship: TextureButton = $ScreenControls/CenterRightZone/ButtonShip
onready var button_render_scale: TextureButton = $ScreenControls/CenterRightZone/ButtonRenderScale
onready var label_render_scale: Label = $ScreenControls/CenterRightZone/ButtonRenderScale/LabelButtonScale
onready var tool_buttons: Array = $ScreenControls/TemporaryToolZone.get_children()
var fitting_window: Control = null
var _banner_location_id: String = ""

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
var _overlay_structures_enabled: bool = true
var _overlay_stellar_enabled: bool = true
var _overlay_jump_enabled: bool = true

# --- Delegates ---
var _target_projector: Reference
var _pointer_router: Node

func _init() -> void:
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

		EventBus.connect("dock_available", self, "_on_dock_available")
		EventBus.connect("dock_unavailable", self, "_on_dock_unavailable")
		EventBus.connect("player_docked", self, "_on_player_docked")
		EventBus.connect("player_undocked", self, "_on_player_undocked")
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
		if not EventBus.is_connected("player_spawned", self, "_on_player_spawned"):
			EventBus.connect("player_spawned", self, "_on_player_spawned")
		if not EventBus.is_connected("sector_changed", self, "_on_sector_changed"):
			EventBus.connect("sector_changed", self, "_on_sector_changed")

	else:
		printerr("MainHUD Error: EventBus not available!")

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

	_pointer_router = PointerRouterClass.new(self)
	add_child(_pointer_router)
	for index in range(tool_buttons.size()):
		tool_buttons[index].connect("pressed", self, "_on_tool_button_pressed", [index])
	button_render_scale.connect("pressed", self, "_on_ButtonRenderScale_pressed")
	_update_render_scale_label()
	fitting_window = FittingWindowScene.instance()
	add_child(fitting_window)
	if is_instance_valid(button_ship):
		button_ship.connect("pressed", fitting_window, "open")
	_refresh_toggle_button_states()

	pause_mode = PAUSE_MODE_PROCESS

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
	_update_combat_readout()
	_update_tool_buttons()
	_update_docked_banner()
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
	_refresh_player_hull()
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
	call_deferred("_rebuild_world_target_overlay")


func _on_player_spawned(_player_body) -> void:
	_refresh_process_state()


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


# One button per fitted tool (placeholders in TemporaryToolZone), two states each: the tool's
# action while off (FIRE, LAUNCH), CEASE / RELEASE while on, highlighted then. Buttons past the
# fitted tools are hidden.
const TOOL_ACTIONS = {"laser": ["FIRE", "CEASE"], "harpoon": ["LAUNCH", "RELEASE"]}


func _update_tool_buttons() -> void:
	var player = GlobalRefs.player_agent_body
	var tools = player.get_node_or_null("ToolController") if is_instance_valid(player) else null
	var count: int = tools.get_tool_count() if is_instance_valid(tools) else 0
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
		button.get_node("Label").text = "%s\n%s" % [name, action]
		_apply_button_toggle_state(button, active)


func _on_tool_button_pressed(index: int) -> void:
	EventBus.emit_signal("player_tool_pressed", index)


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
	_banner_location_id = ""
	_update_docked_banner()


# Deferred: the player controller clears GameState.player_docked_at in its own handler.
func _on_player_undocked():
	call_deferred("_update_dock_button_label")
	call_deferred("_update_docked_banner")


# "DOCKED AT <station>" while docked; follows GameState, so it can never disagree with it.
func _update_docked_banner() -> void:
	if not is_instance_valid(label_docked_banner):
		return
	var location_id: String = GameState.player_docked_at
	label_docked_banner.visible = location_id != ""
	if location_id == "" or location_id == _banner_location_id:
		return
	_banner_location_id = location_id
	var station_name: String = location_id
	for station in get_tree().get_nodes_in_group("dockable_station"):
		if station.get("location_id") == location_id:
			station_name = station.station_name
	label_docked_banner.text = "DOCKED AT %s" % station_name.to_upper()


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
	return is_instance_valid(look_at_target) and look_at_target is Spatial


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


# Hull, power, cargo, each fitted tool's state and the selected ship's hull or wreck's salvage.
func _update_combat_readout() -> void:
	if not is_instance_valid(label_combat_readout):
		return
	var player = GlobalRefs.player_agent_body
	if not is_instance_valid(player) or player.get("hull_max") == null:
		label_combat_readout.text = ""
		return
	var lines: Array = [
		"HULL  %d / %d" % [ceil(player.hull), player.hull_max],
		"POWER %d / %d" % [floor(player.power), player.power_max],
		"CARGO %d / %d" % [player.get_cargo_units(), player.cargo_capacity],
		"BANK  %d WP" % GameState.player_bank,
		describe_signature(player),
	]
	var tools = player.get_node_or_null("ToolController")
	if is_instance_valid(tools):
		for index in range(tools.get_tool_count()):
			lines.append(_describe_tool_state(tools, index))
	if is_instance_valid(_current_target) and _current_target is Spatial and (_current_target.get("hull_max") or _current_target.is_in_group("asteroid")):
		var distance: float = player.global_transform.origin.distance_to(_current_target.global_transform.origin)
		var condition: String
		if _current_target.is_in_group("asteroid"):
			condition = "%.0f m across" % (_current_target.get_apparent_radius() * 2.0)
		elif _current_target.get("is_wreck"):
			condition = "SALVAGE %d" % _current_target.get_salvage_units()
		else:
			condition = "%d / %d  %s" % [ceil(_current_target.hull), _current_target.hull_max, PoolStringArray(_target_projector.get_ship_cues(_current_target)).join("  ")]
		lines.append("TARGET %s  %s  %.0f m" % [_resolve_target_display_name(_current_target), condition, distance])
	label_combat_readout.text = PoolStringArray(lines).join("\n")


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


func _refresh_player_hull() -> void:
	var debug_window = _get_debug_window()
	if is_instance_valid(debug_window) and debug_window.has_method("refresh_debug_window_player_hull"):
		debug_window.call("refresh_debug_window_player_hull")


func _deferred_refresh_player_hull() -> void:
	_refresh_player_hull()


func _on_any_damage_dealt_refresh_player(_target_uid: int, _amount: float, _source_uid: int) -> void:
	_refresh_player_hull()


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
		_refresh_player_hull()


func _on_agent_disabled(agent_body) -> void:
	call_deferred("_rebuild_world_target_overlay")  # Relabel the bracket as a wreck.
	if _is_game_over:
		return
	if not is_instance_valid(agent_body):
		return
	if not is_instance_valid(GlobalRefs.player_agent_body):
		return
	if agent_body != GlobalRefs.player_agent_body:
		return
	_show_game_over_overlay()


# The run is over: the popup shows, but the game keeps running behind it, with the camera on the
# player's wreck (orbiting it, not tracking a target) so the player can watch the scene play out.
# The overlay only takes clicks on its panel; the rest of the screen still turns and zooms the camera.
func _show_game_over_overlay() -> void:
	_is_game_over = true
	var summary = game_over_overlay.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/LabelGameOver") if is_instance_valid(game_over_overlay) else null
	if is_instance_valid(summary):
		summary.text = "SHIP LOST\nThe run is over.\nBanked this run: %d WP" % GameState.player_bank
	if is_instance_valid(game_over_overlay):
		game_over_overlay.visible = true
		game_over_overlay.raise()
		if is_instance_valid(button_return_to_menu):
			button_return_to_menu.grab_focus()
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and is_instance_valid(GlobalRefs.player_agent_body):
		if camera.has_method("set_camera_mode"):
			camera.set_camera_mode(0)  # ORBIT
		camera.set_target_node(GlobalRefs.player_agent_body)
	_refresh_toggle_button_states()


# Starts the next run straight from the run-over screen.
func _on_ButtonNewRun_pressed() -> void:
	get_tree().paused = false
	_is_game_over = false
	if is_instance_valid(game_over_overlay):
		game_over_overlay.visible = false
	if EventBus:
		EventBus.emit_signal("new_game_requested")


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
