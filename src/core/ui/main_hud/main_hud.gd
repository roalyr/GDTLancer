extends Control

## MainHUD: Primary gameplay HUD displaying player resources, target info, and combat status.
## Manages sub-screens (Station Menu) and docking prompts.

const FrameProfiler = preload("res://src/core/utils/frame_profiler.gd")
const FrameGovernor = preload("res://src/core/utils/frame_governor.gd")
const MainTheme = preload("res://assets/themes/main_theme.tres")
const Wages = preload("res://src/core/systems/wages.gd")
const Announcements = preload("res://src/core/ui/main_hud/announcements.gd")
const RouteTargetProviderScript = preload("res://src/core/targeting/route_target_provider.gd")
const ProjectedTargetBracketScene = preload("res://scenes/ui/hud/projected_target_bracket.tscn")
const BUTTON_ACTIVE_MODULATE = Constants.UI_SWITCH_ON_MODULATE
const BUTTON_INACTIVE_MODULATE = Color8(255, 255, 255, 255)
const PROJECTED_TARGET_EDGE_ALPHA = 0.1
const PROJECTED_TARGET_EDGE_POW = 0.75
const CAMERA_MODE_TARGET_TRACKING = 1
const NAV_COMMAND_IDLE = 0
const NAV_COMMAND_APPROACH = 4
const NAV_COMMAND_ORBIT = 5
const NAV_COMMAND_FLEE = 6
const NAV_COMMAND_CHARGE = 9
const OVERLAY_KIND_STRUCTURES = "structures"
const OVERLAY_KIND_STELLAR = "stellar"
const OVERLAY_KIND_JUMP = "jump"
const PointerRouterClass = preload("res://src/core/ui/pointer_router.gd")
const FittingWindowScene = preload("res://scenes/ui/menus/fitting_window.tscn")
const InteractionWindowScene = preload("res://scenes/ui/menus/interaction_window.tscn")
const ShipWindowScene = preload("res://scenes/ui/menus/ship_window.tscn")
const PilotWindowScene = preload("res://scenes/ui/menus/pilot_window.tscn")
const Interactions = preload("res://src/core/systems/interactions.gd")
const FittingWindowScript = preload("res://src/core/ui/fitting_window/fitting_window.gd")
const DebugMapScene = preload("res://scenes/ui/menus/debug_map.tscn")
const MapWindowScene = preload("res://scenes/ui/menus/map_window.tscn")
const HudDot = preload("res://src/core/ui/main_hud/hud_dot.gd")
const DebugTools = preload("res://src/core/ui/debug_tools/debug_tools.gd")
const RadioScript = preload("res://src/core/systems/radio.gd")
const ThreatRing = preload("res://src/core/ui/main_hud/threat_ring.gd")
const ThreatWatch = preload("res://src/core/systems/threat_watch.gd")
const AwarenessZoneScene = preload("res://scenes/ui/hud/awareness_zone.tscn")
const HudBarScript = preload("res://src/core/ui/main_hud/hud_bar.gd")
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
onready var label_button_approach: Label = $ScreenControls/BottomCenterZone/ButtonApproach/LabelButtonApproach
onready var debug_overlay: Control = $ScreenControls/DebugOverlay
onready var _debug_label_ship: Label = $ScreenControls/DebugOverlay/LeftColumn/LabelShip
onready var _debug_label_tools: Label = $ScreenControls/DebugOverlay/LeftColumn/LabelTools
onready var _debug_label_target: Label = $ScreenControls/DebugOverlay/RightColumn/LabelTarget
onready var _debug_label_world: Label = $ScreenControls/DebugOverlay/RightColumn/LabelWorld
onready var _debug_label_render: Label = $ScreenControls/DebugOverlay/LabelRender
onready var _debug_label_frame: Label = $ScreenControls/DebugOverlay/LabelFrame
onready var _debug_label_radio: Label = $ScreenControls/DebugOverlay/LabelRadio
onready var button_hud_look: TextureButton = $ScreenControls/CenterRightZone/ButtonHudLook
onready var label_hud_look: Label = $ScreenControls/CenterRightZone/ButtonHudLook/LabelButtonHudLook
onready var tool_buttons: Array = _tool_button_nodes()
onready var button_lance: TextureButton = $ScreenControls/TemporaryToolZone/ButtonLance
onready var button_afterburner: TextureButton = $ScreenControls/TemporaryToolZone/ButtonAfterburner
onready var button_safety: TextureButton = $ScreenControls/TemporaryToolZone/ButtonSafety
var fitting_window: Control = null
var interaction_window: Control = null  # INTERACT: what the selected ship may be asked (InteractionWindow)
var ship_window: Control = null  # SHIP: the ship flown, its fit and stats (ShipWindow)
var pilot_window: Control = null  # PILOT: bank, standing, bounties, work (PilotWindow)
var debug_map: Control = null
var map_window: Control = null  # MAP: the sector and the sectors from above (MapWindow)
var debug_tools: Control = null
var radio_lines: Array = []  # The radio lines heard last (Radio), oldest first, with their time: the debug overlay's (the top strip keeps its own, fading)
var threat_ring: Control = null
var awareness_zone: Control = null  # The top strip (AwarenessZone)
var _tool_rows: Array = []  # Rows of tool buttons above TemporaryToolZone (_layout_tool_rows)
var _tool_rows_key: String = ""

# --- Game Over UI ---

# --- State ---
var _current_target = null
var _escort_ward = null  # The worker the player escorts (player_escort_changed)
var _partners: Array = []  # Ships in an interaction with the player (Interactions.partners), refreshed on change and on the controls cadence
var _partner_ids: Dictionary = {}  # Their instance ids, for the brackets
var _partners_left: float = 0.0
var _main_camera: Camera = null
var _announcements: Control = null  # Fading feedback labels (Announcements)
var hud_hidden: bool = false  # The eye button: every HUD element hidden (for screenshots), a dot left to bring it back
var _hud_dot: TextureButton = null
var _dock_location_id: String = ""  # Currently available dock location
var _jump_target_id: String = ""  # Currently available jump route target
var _route_target_provider: Reference = RouteTargetProviderScript.new()
var _route_target_buttons: Dictionary = {}
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
var _frame_governor: Node = null
var _hud_last_usec: int = 0
var _fps_label: Label = null  # Settings "show_fps": frames a second in the top left corner
var _fps_left: float = 0.0
var _controls_left: float = 0.0  # s to the next HUD controls refresh (HUD_CONTROLS_INTERVAL)
var _debug_left: float = Constants.HUD_DEBUG_INTERVAL * 0.5  # s to the next debug readout refresh, out of step with it


func _ready():
	_frame_profiler = FrameProfiler.new()
	_frame_profiler.name = "FrameProfiler"
	add_child(_frame_profiler)
	_frame_governor = FrameGovernor.new()
	_frame_governor.name = "FrameGovernor"
	add_child(_frame_governor)
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
		EventBus.connect("player_escort_changed", self, "_on_player_escort_changed")
		EventBus.connect("player_interactions_changed", self, "refresh_partners")
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
		# No drop shadow on its long texts: the theme's shadow is a second pass of every line, which
		# about doubled the overlay's 2D draw calls.
		for label in [_debug_label_ship, _debug_label_tools, _debug_label_target, _debug_label_world, _debug_label_render, _debug_label_frame, _debug_label_radio]:
			if is_instance_valid(label):
				label.add_color_override("font_color_shadow", Color(0, 0, 0, 0))
	_make_fps_label()
	if not EventBus.is_connected("radio_message", self, "_on_radio_message"):
		EventBus.connect("radio_message", self, "_on_radio_message")

	_connect_overlay_toggle_button(button_overlay_structures, "_on_ButtonOverlayStructures_pressed")
	_connect_overlay_toggle_button(button_overlay_stellar, "_on_ButtonOverlayStellar_pressed")
	_connect_overlay_toggle_button(button_overlay_jump, "_on_ButtonOverlayJump_pressed")
	button_overlay_jump.visible = Constants.jumps_enabled  # No routes to show while jumps are off

	_pointer_router = PointerRouterClass.new(self)
	add_child(_pointer_router)
	for index in range(tool_buttons.size()):
		tool_buttons[index].connect("pressed", self, "_on_tool_button_pressed", [index])
	button_lance.connect("pressed", self, "_on_lance_button_pressed")
	button_afterburner.connect("pressed", self, "_on_afterburner_button_pressed")
	button_safety.connect("pressed", self, "_on_safety_button_pressed")
	button_hud_look.connect("pressed", self, "_on_ButtonHudLook_pressed")
	Settings.connect("changed", self, "_on_settings_changed")
	Strings.connect("changed", self, "_on_language_changed")
	fitting_window = FittingWindowScene.instance()
	add_child(fitting_window)
	interaction_window = InteractionWindowScene.instance()
	add_child(interaction_window)
	ship_window = ShipWindowScene.instance()
	add_child(ship_window)
	$ScreenControls/CenterRightZone/ButtonShip.connect("pressed", ship_window, "toggle")
	pilot_window = PilotWindowScene.instance()
	add_child(pilot_window)
	$ScreenControls/CenterRightZone/ButtonCharacter.connect("pressed", pilot_window, "toggle")
	map_window = MapWindowScene.instance()
	add_child(map_window)
	$ScreenControls/CenterRightZone/ButtonMap.connect("pressed", map_window, "toggle")
	debug_map = DebugMapScene.instance()
	add_child(debug_map)
	$ScreenControls/DebugOverlay/RightColumn/ButtonDebugMap.connect("pressed", debug_map, "open")
	awareness_zone = AwarenessZoneScene.instance()
	awareness_zone.name_source = funcref(self, "_resolve_target_display_name")
	$ScreenControls.add_child(awareness_zone)
	UiScale.connect("changed", self, "_on_ui_scale_changed")
	$ScreenControls.connect("resized", self, "fit_flight_row")
	call_deferred("fit_flight_row")  # After UiScale scaled the HUD as it came in
	call_deferred("_scale_slider_icons")
	var threat_watch = ThreatWatch.new()
	threat_watch.name = "ThreatWatch"
	add_child(threat_watch)
	threat_ring = ThreatRing.new()
	threat_ring.name = "ThreatRing"
	add_child(threat_ring)
	move_child(threat_ring, $ScreenControls.get_index() + 1)  # Over the HUD buttons (it takes no input), under the windows
	apply_hud_preset()  # Once the threat ring is in: the look tints it with the rest of the HUD
	debug_tools = DebugTools.new()
	debug_tools.name = "DebugTools"
	add_child(debug_tools)
	$ScreenControls/DebugOverlay/RightColumn/ButtonDebugJump.connect("pressed", debug_tools, "open_jump")
	$ScreenControls/DebugOverlay/RightColumn/ButtonDebugGoTo.connect("pressed", debug_tools, "open_go_to")
	$ScreenControls/DebugOverlay/RightColumn/ButtonDebugToTarget.connect("pressed", debug_tools, "go_to_target")
	$ScreenControls/DebugOverlay/LeftColumn/ButtonDebugRefit.connect("pressed", debug_tools, "open_refit")
	$ScreenControls/DebugOverlay/LeftColumn/ButtonDebugEvolution.connect("pressed", debug_tools, "open_evolution")
	$ScreenControls/DebugOverlay/LeftColumn/ButtonDebugDev.connect("pressed", debug_tools, "open_dev")
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

	var now: int = OS.get_ticks_usec()
	var dt: float = clamp((now - _hud_last_usec) / 1000000.0, 0.0, 1.0) if _hud_last_usec > 0 else 0.0
	_hud_last_usec = now
	# Every frame: what moves with the view (positions) and button highlights (a tap answers at once).
	_update_route_target_overlay()
	_update_world_target_overlay(false)
	_refresh_toggle_button_states()
	# On their cadences (Constants UPDATE CADENCES), out of step with the bracket slices and each other.
	_controls_left -= dt
	if _controls_left <= 0.0:
		_controls_left = Constants.HUD_CONTROLS_INTERVAL
		_update_tool_buttons()
		_update_lance_button()
		_update_afterburner_button()
		_update_safety_button()
		_layout_tool_rows()
		_update_dock_button_label()
		_partners_left -= Constants.HUD_CONTROLS_INTERVAL
		if _partners_left <= 0.0:
			refresh_partners()
		_update_interact_button_label()
		_update_approach_button_label()
	_debug_left -= dt
	if _debug_left <= 0.0:
		_debug_left = Constants.HUD_DEBUG_INTERVAL
		_update_debug_overlay()
	_fps_left -= dt
	if _fps_left <= 0.0:
		_fps_left = Constants.HUD_FPS_INTERVAL
		_update_fps_label()


# Settings "show_fps": a small FPS readout in the screen's top left corner (no need of the debug
# overlay), with the game speed while SLOW DOWN ON LAG holds it below full.
func _make_fps_label() -> void:
	var holder = get_node_or_null("ScreenControls")
	if holder == null or is_instance_valid(_fps_label):
		return
	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.theme = MainTheme  # A plain Label of it: the HUD's lettering, as on its buttons
	_fps_label.rect_position = Constants.HUD_FPS_OFFSET
	holder.add_child(_fps_label)
	_fps_label.visible = bool(Settings.get_option("show_fps"))
	if not Settings.is_connected("changed", self, "_on_fps_setting_changed"):
		Settings.connect("changed", self, "_on_fps_setting_changed")


func _on_fps_setting_changed(key, value) -> void:
	if key == "show_fps" and is_instance_valid(_fps_label):
		_fps_label.visible = bool(value)
		_update_fps_label()


func _update_fps_label() -> void:
	if not (is_instance_valid(_fps_label) and _fps_label.visible):
		return
	var text: String = Strings.t("hud.fps", [Performance.get_monitor(Performance.TIME_FPS)])
	var speed: float = _frame_governor.speed if is_instance_valid(_frame_governor) else 1.0
	if speed < 1.0:
		text += "  " + Strings.t("hud.game_speed", [speed])
	if _fps_label.text != text:
		_fps_label.text = text


# APPROACH reads where it would stop: HOLD and the range with weapons on the selected target
# (ToolController.fighting_range: it holds there, as NPCs fight), CHARGE with the lance armed.
func _update_approach_button_label() -> void:
	if not is_instance_valid(label_button_approach):
		return
	var text := Strings.t("hud.button.approach")
	var player = GlobalRefs.player_agent_body
	var controller = _get_player_controller()
	if _current_target != null and is_instance_valid(player):
		var tools = player.get_node_or_null("ToolController")
		if is_instance_valid(controller) and controller.has_method("is_charge_ready") and controller.is_charge_ready(_current_target):
			text = Strings.t("hud.button.charge")
		elif tools != null and tools.has_method("fighting_range"):
			var hold: float = tools.fighting_range(_current_target) * Constants.NAV_APPROACH_WEAPON_SHARE
			if hold > 0.0:
				text = Strings.t("hud.button.hold", [_short_distance(hold)])
	if label_button_approach.text != text:
		label_button_approach.text = text


static func _short_distance(metres: float) -> String:
	return "%.1fk" % (metres / 1000.0) if metres >= 1000.0 else "%d" % int(round(metres))


# INTERACT opens the interaction window on the selected ship (Interactions); it reads INTERACTING
# while that ship is in an interaction with the player.
func _update_interact_button_label() -> void:
	if not is_instance_valid(label_button_interact):
		return
	var text := Strings.t("hud.button.interacting") if _current_target != null and is_partner(_current_target) else Strings.t("hud.button.interact")
	if label_button_interact.text != text:
		label_button_interact.text = text


func open_interactions(ship) -> void:
	if is_instance_valid(interaction_window):
		interaction_window.open(ship)


# The ships in an interaction with the player now (Interactions.partners), their brackets restyled
# when the list changes (filled marks).
func refresh_partners() -> void:
	_partners_left = Constants.HUD_PARTNERS_INTERVAL
	var found: Array = Interactions.partners(GlobalRefs.player_agent_body)
	var ids := {}
	for ship in found:
		ids[ship.get_instance_id()] = true
	if ids.hash() == _partner_ids.hash():
		return
	var changed: Dictionary = _partner_ids.duplicate()
	for id in ids:
		changed[id] = true
	_partners = found
	_partner_ids = ids
	for button in get_tree().get_nodes_in_group("projected_target_bracket"):
		var ref = button.get("target_ref")
		if is_instance_valid(ref) and ref is Object and changed.has(ref.get_instance_id()):
			button.refresh_style()


func is_partner(ship) -> bool:
	return is_instance_valid(ship) and ship is Object and _partner_ids.has(ship.get_instance_id())


func get_partners() -> Array:
	return _partners


func _on_player_escort_changed(ward) -> void:
	_escort_ward = ward


# --- Signal Handlers ---
func _on_Player_Target_Selected(target_node):
	if _is_target_valid(target_node):
		_current_target = target_node
		if is_instance_valid(awareness_zone):
			awareness_zone.target = target_node
			awareness_zone.target_name = _resolve_target_display_name(target_node)
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
	if is_instance_valid(awareness_zone):
		awareness_zone.target = null
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
	_target_projector.remove_world_target(agent_body)  # Its bracket alone: the rest stay as they are


func _on_player_spawned(_player_body) -> void:
	_refresh_process_state()


# A ship, chunk, loose lance or mayday's beacon come into the world gets its own bracket; the others are untouched
# (a rebuild of them all made every bracket blink and cost a frame spike).
func _on_agent_spawned(agent_body, _init_data) -> void:
	if is_instance_valid(agent_body) and _target_projector.is_world_projectable_target(agent_body):
		_target_projector.add_world_target(agent_body)


func _on_debris_spawned(body) -> void:
	if is_instance_valid(body) and _target_projector.is_world_projectable_target(body):
		_target_projector.add_world_target(body)


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
		return
	if get_tree().paused or not event is InputEventKey or event.is_echo():
		return
	var button: BaseButton = key_button(event)
	if button != null:
		if not button.disabled:
			button.emit_signal("pressed")
		get_tree().set_input_as_handled()


# The button a key presses, as a tap would (the keys drawn on the buttons): D docks, I interacts
# (APPROACH, FLEE, ORBIT, MANUAL and STOP are the PlayerController's, the same commands), and 1 to 9
# then 0 the tool rows' buttons in their numbered order (tools, LANCE, AFTERBURN, SAFETY: whichever
# are shown, as many as there are). Null when the key is none of these.
func key_button(event: InputEvent) -> BaseButton:
	if event.is_action_pressed("command_dock"):
		return button_dock
	if event.is_action_pressed("command_interact"):
		return button_interact
	var numbered: Array = _numbered_tool_items()
	for index in range(min(numbered.size(), TOOL_KEYS)):
		if event.is_action_pressed("tool_%d" % (index + 1)):
			return numbered[index]
	return null


func _on_ButtonMenu_pressed() -> void:
	"""Handle menu button press - opens main menu."""
	if EventBus:
		EventBus.emit_signal("main_menu_requested")


# Shows or hides the debug overlay (ship, tools, target, world, render, frame time): off by default.
func _on_ButtonDebug_pressed() -> void:
	if not is_instance_valid(debug_overlay):
		return
	debug_overlay.visible = not debug_overlay.visible
	if is_instance_valid(awareness_zone):
		awareness_zone.suppressed = debug_overlay.visible  # The overlay's top rows sit where the strip does
		awareness_zone.refresh()
		get_tree().call_group("projected_target_bracket", "_sync_label")  # The name moves back under the bracket
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
	if is_instance_valid(label_button_dock) and label_button_dock.text == Strings.t("hud.button.travel"):
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


# One button per fitted tool (TemporaryToolZone; more are made as a ship needs them): its short
# name, highlighted while on, and a bar along its foot: rounds left of a full magazine (cannons,
# racks), else the cycle while on. A word only when pressing it would not do the usual: EMPTY,
# WINCHING. (TOOL_ACTIONS: the words the debug overlay and the old labels used.)
# Buttons past the fitted tools are hidden. The buttons (tools, then LANCE and AFTERBURNER) sit in
# centred rows of at most TOOL_ROW_MAX, the last row lowest; the rows above are made as needed.
const TOOL_ROW_MAX = 8
const TOOL_ROW_STEP = 120.0  # px at UI scale 1.0 between rows: a button and the gap
const TOOL_ROW_HEIGHT = 100.0  # px at UI scale 1.0
var _flight_row_width: float = 0.0  # BottomCenterZone's width at UI scale 1.0, as in the scene
var _flight_row_fit: float = 1.0  # Its scale (fit_flight_row)
const TOOL_ACTIONS = {"laser": ["FIRE", "CEASE"], "missile": ["LAUNCH", "HOLD"], "cannon": ["FIRE", "CEASE"], "harpoon": ["LAUNCH", "RELEASE"]}


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
		var name: String = Strings.name_of(tool_template.hud_label) if tool_template.hud_label != "" else Strings.name_of(tool_template.tool_name).to_upper()
		var action: String = ""
		var fill: float = tools.get_cycle_progress(index) if active else 0.0
		if tools.has_method("is_retracting") and tools.is_retracting(index):
			action = Strings.t("hud.tool.winching")
		if tools.has_method("has_magazine") and tools.has_magazine(index):
			fill = float(tools.get_ammo(index)) / max(1.0, float(tools.get_capacity(index)))
			if tools.get_ammo(index) <= 0:
				action = Strings.t("hud.tool.empty")
		if action == "" and active and tool_template.tool_type == "cannon":
			action = cannon_word(player, tools, index)
		var text: String = name if action == "" else "%s\n%s" % [name, action]
		var label: Label = button.get_node("Label")
		if label.text != text:
			label.text = text
		_tool_bar(button).set_value(fill)
		_apply_button_toggle_state(button, active)


# An active cannon's word when it would not fire now (ToolController.cannon_aim, the rule it fires
# by): FAR beyond its reach with the range opening, CLOSING beyond it with the range shrinking (the
# drift towards or away), TURNING while the nose comes onto the lead, BLOCKED while a rock or a friend
# is in the line; nothing when it fires.
static func cannon_word(player, tools, index: int) -> String:
	var target = tools.get_target(index)
	if not is_instance_valid(target):
		return ""
	match tools.cannon_aim(index, target):
		"far":
			var to_target: Vector3 = target.global_transform.origin - player.global_transform.origin
			var target_velocity = target.get("linear_velocity")
			var relative: Vector3 = (target_velocity if target_velocity is Vector3 else Vector3.ZERO) - player.linear_velocity
			return Strings.t("hud.cannon.closing") if relative.dot(to_target) < 0.0 else Strings.t("hud.cannon.far")
		"turning":
			return Strings.t("hud.cannon.turning")
	return Strings.t("hud.cannon.blocked") if tools.is_holding(index) else ""


# The bar along a tool button's foot (HudBar), made the first time.
func _tool_bar(button: Control) -> Control:
	var bar = button.get_node_or_null("Bar")
	if bar == null:
		bar = HudBarScript.new()
		bar.name = "Bar"
		bar.bar_height = 4.0
		bar.anchor_right = 1.0
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.margin_left = 10.0
		bar.margin_right = -34.0  # Clear of the key's number in the corner
		bar.margin_top = -16.0
		bar.margin_bottom = -8.0
		bar.low_share = 0.25
		button.add_child(bar)
	return bar


# The tool rows' shown buttons in order, each with its key's number in the corner where the flight
# buttons have their letters (1 to 9, then 0; none past TOOL_KEYS).
const TOOL_KEYS = 10


func _numbered_tool_items() -> Array:
	var shown: Array = []
	for item in tool_buttons + [button_lance, button_afterburner, button_safety]:
		if item.visible:
			shown.append(item)
	return shown


func _number_tool_items() -> void:
	var number := 0
	for item in tool_buttons + [button_lance, button_afterburner, button_safety]:
		var label: Label = item.get_node_or_null("Key")
		if label == null:
			label = Label.new()
			label.name = "Key"
			label.theme = MainTheme  # The HUD has none: the plain Label, as large as the drawn letters
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.align = Label.ALIGN_RIGHT
			label.valign = Label.VALIGN_BOTTOM
			label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			label.grow_vertical = Control.GROW_DIRECTION_BEGIN
			for anchor in ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom"]:
				label.set(anchor, 1.0)
			label.margin_left = -40.0  # At UI scale 1.0: UiScale scales it as it enters
			label.margin_top = -36.0
			label.margin_right = -9.0
			label.margin_bottom = -4.0
			item.add_child(label)
		if item.visible:
			number += 1
		label.text = str(number % 10) if item.visible and number <= TOOL_KEYS else ""


# Spreads the shown buttons over rows of at most TOOL_ROW_MAX, the first ones highest; only when
# what is shown changes.
func _layout_tool_rows() -> void:
	var items: Array = tool_buttons + [button_lance, button_afterburner, button_safety]
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
	_number_tool_items()
	var rows: int = int(max(1, ceil(float(shown.size()) / TOOL_ROW_MAX)))
	var zone: Control = $ScreenControls/TemporaryToolZone
	while _tool_rows.size() < rows - 1:  # Rows above the zone, the nearest first
		var row := HBoxContainer.new()
		row.name = "TemporaryToolRow%d" % (_tool_rows.size() + 2)
		for property in ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "grow_horizontal", "mouse_filter", "alignment"]:
			row.set(property, zone.get(property))
		# Sizes at UI scale 1.0, as the zone's in the scene: UiScale scales the row as it enters
		for property in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			row.set(property, UiScale.base_of(zone, property))
		row.add_constant_override("separation", UiScale.base_of(zone, "separation"))
		zone.get_parent().add_child(row)
		_tool_rows.append(row)
		call_deferred("_place_tool_rows")  # Once UiScale took it in
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


# The flight row (BottomCenterZone) at the HUD's scale while it fits between the bottom corner
# groups (the menu and debug buttons, the HUD look, camera and eye); past that as large as the gap
# between them holds, and moved into the middle of that gap. Its words keep the UI scale. The tool
# rows sit on it. On every change of the UI scale or of the screen.
func fit_flight_row() -> void:
	var controls: Control = $ScreenControls
	var zone: Control = $ScreenControls/BottomCenterZone
	if not zone.has_meta(UiScale.BASE):
		return  # Not yet scaled: UiScale's "changed" comes after
	if _flight_row_width <= 0.0:
		_flight_row_width = UiScale.base_of(zone, "margin_right") - UiScale.base_of(zone, "margin_left")
	var scale: float = UiScale.layout_factor
	var width: float = controls.rect_size.x
	var left: float = UiScale.base_of(button_debug, "margin_right") * scale  # The left group's right edge
	var right: float = -UiScale.base_of(button_hud_look, "margin_left") * scale  # The right group's width
	var gap: float = Constants.HUD_CORNER_GAP * scale
	var fit: float = scale
	var shift: float = 0.0
	if _flight_row_width * scale > width - 2.0 * max(left, right) - 2.0 * gap:  # Centred, it would reach a group
		fit = clamp((width - left - right - 2.0 * gap) / _flight_row_width, 0.5, scale)
		shift = (left - right) * 0.5
	_flight_row_fit = fit
	UiScale.set_subtree_factor(zone, fit)
	UiScale.set_base(zone, {"margin_left": -_flight_row_width * 0.5 + shift / fit, "margin_right": _flight_row_width * 0.5 + shift / fit})
	_place_tool_rows()


# The tool rows stacked on the flight row, whatever its scale (sizes at UI scale 1.0: UiScale takes
# them to the HUD's).
func _place_tool_rows() -> void:
	var zone: Control = $ScreenControls/TemporaryToolZone
	var bottom: float = UiScale.base_of($ScreenControls/BottomCenterZone, "margin_top") * _flight_row_fit / UiScale.layout_factor
	var rows: Array = [zone] + _tool_rows
	for index in range(rows.size()):
		var row_bottom: float = bottom - TOOL_ROW_STEP * index
		UiScale.set_base(rows[index], {"margin_top": row_bottom - TOOL_ROW_HEIGHT, "margin_bottom": row_bottom})


func _on_ui_scale_changed(_factor: float) -> void:
	fit_flight_row()
	_scale_slider_icons()


# The sliders' grabber and ticks, theme pictures of a fixed size, drawn at the HUD's scale on these
# two sliders (their own copies, resized; the theme's stay as they are).
const SLIDER_ICONS = ["grabber", "grabber_highlight", "grabber_disabled", "tick"]
var _slider_icon_scale: float = 1.0


func _scale_slider_icons() -> void:
	var scale: float = UiScale.layout_factor
	if is_equal_approx(scale, _slider_icon_scale):
		return
	_slider_icon_scale = scale
	var sliders: Array = [$ScreenControls/CenterLeftZone/SliderControlLeft, $ScreenControls/CenterRightZone/SliderControlRight]
	for name in SLIDER_ICONS:
		var icon: Texture = MainTheme.get_icon(name, "VSlider")
		if icon != null and not is_equal_approx(scale, 1.0):
			var image: Image = icon.get_data()
			if image != null:
				if image.is_compressed():
					image.decompress()
				image.resize(int(max(1, round(image.get_width() * scale))), int(max(1, round(image.get_height() * scale))), Image.INTERPOLATE_BILINEAR)
				var resized := ImageTexture.new()
				resized.create_from_image(image, Texture.FLAG_FILTER)
				icon = resized
		for slider in sliders:
			if is_equal_approx(scale, 1.0):
				if slider.has_icon_override(name):
					slider.add_icon_override(name, null)  # Back to the theme's
			else:
				slider.add_icon_override(name, icon)


func _on_tool_button_pressed(index: int) -> void:
	EventBus.emit_signal("player_tool_pressed", index)


func _tool_button_nodes() -> Array:
	var buttons: Array = []
	for child in get_node("ScreenControls/TemporaryToolZone").get_children():
		if child.name.begins_with("ButtonTool"):
			buttons.append(child)
	return buttons


# The LANCE button, after the tools (only with a lance fitted): lances left and ARM while safe (SAFE
# while the safety keeps it from arming at the selection: only an asteroid or a hostile);
# ARMED (highlighted) and the speed a throw would strike the selected target at against the speed a
# strike needs, or TOO SLOW (it runs faster than the ship can gain on it); LOADING while the next
# lance slides in. Armed, APPROACH flies the charge at a ship or a rock, pass after pass; outside a
# charge one throw (a volley from launchers side by side) disarms it.
func _update_lance_button() -> void:
	var player = GlobalRefs.player_agent_body
	var lance = player.get_lance() if is_instance_valid(player) and player.has_method("get_lance") else null
	button_lance.visible = lance != null
	var controller = _get_player_controller()
	var selected = controller.get("_selected_target") if is_instance_valid(controller) else null
	var charge: bool = is_instance_valid(controller) and controller.has_method("is_charge_ready") and controller.is_charge_ready(selected if is_instance_valid(selected) else null)  # As APPROACH will act
	var charge_target = selected if charge and is_instance_valid(selected) else null
	if lance == null:
		return
	var state: String = Strings.t("hud.lance.arm")
	var seated = null  # A launcher with a lance ready
	for each in player.get_lances():
		if each.is_seated():
			seated = each
			break
	if player.get_lance_nails() <= 0:
		state = Strings.t("hud.tool.empty")
	elif seated == null:
		state = Strings.t("hud.lance.loading")
	elif not lance.armed and is_instance_valid(controller) and controller.has_method("lance_block_reason") and controller.lance_block_reason(selected) != "":
		state = Strings.t("hud.lance.safe")  # The safety keeps it from arming at the selection (only at an asteroid or a hostile)
	elif lance.armed:
		state = Strings.t("hud.lance.armed")
		var target = _current_target
		if charge_target != null and player.outruns_charge(charge_target):
			state = Strings.t("hud.lance.too_slow")
		elif is_instance_valid(target) and target is RigidBody:
			state = "%d / %d" % [int(seated.strike_speed_on(target)), int(Constants.LAW_LANCE_MIN_SPEED)]
	button_lance.get_node("Label").text = Strings.t("hud.lance.label", [player.get_lance_nails(), state])
	_apply_button_toggle_state(button_lance, lance.armed, true)


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
	var text: String = Strings.t("hud.burner.label", [Strings.t("hud.on") if player.afterburner_lit else Strings.t("hud.off"), int(player.get_burst_top_speed())]) if fitted else Strings.t("hud.burner.none")
	if decoys:
		text += "\n" + Strings.t("hud.burner.decoys", [player.decoys])
	button_afterburner.get_node("Label").text = text
	_apply_button_toggle_state(button_afterburner, fitted and player.afterburner_lit, true)


func _on_afterburner_button_pressed() -> void:
	EventBus.emit_signal("player_afterburner_pressed")


# The SAFETY button, last in the tool rows (only with a weapon or a lance fitted): ON (highlighted)
# while allied and neutral ships are safe from the player's weapons and lance charges
# (GameState.weapons_safe, PlayerController.is_safe_from); OFF, they fire on any ship.
const SAFETY_WEAPONS = ["laser", "missile", "cannon"]


func _update_safety_button() -> void:
	var player = GlobalRefs.player_agent_body
	var armed: bool = is_instance_valid(player) and player.has_method("get_lance") and player.get_lance() != null
	var tools = player.get_node_or_null("ToolController") if is_instance_valid(player) else null
	if is_instance_valid(tools):
		for index in range(tools.get_tool_count()):
			armed = armed or tools.get_tool(index).tool_type in SAFETY_WEAPONS
	button_safety.visible = armed
	if not armed:
		return
	var text: String = Strings.t("hud.safety.label", [Strings.t("hud.on") if GameState.weapons_safe else Strings.t("hud.off")])
	var label: Label = button_safety.get_node("Label")
	if label.text != text:
		label.text = text
	_apply_button_toggle_state(button_safety, GameState.weapons_safe, true)


func _on_safety_button_pressed() -> void:
	EventBus.emit_signal("player_safety_pressed")


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
	if hud_hidden:
		set_hud_hidden(false)  # The station window is the HUD's: the dot would sit over it
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
	_apply_button_toggle_state(button_overlay_structures, _overlay_structures_enabled, true)
	_apply_button_toggle_state(button_overlay_stellar, _overlay_stellar_enabled, true)
	_apply_button_toggle_state(button_overlay_jump, _overlay_jump_enabled, true)

	var is_free_flight_active = _is_player_free_flight_active()
	var active_navigation_command_type = _get_player_navigation_command_type()
	_apply_button_toggle_state(button_manual_flight, is_free_flight_active)
	_apply_button_toggle_state(button_orbit, not is_free_flight_active and active_navigation_command_type == NAV_COMMAND_ORBIT)
	_apply_button_toggle_state(button_approach, not is_free_flight_active and active_navigation_command_type in [NAV_COMMAND_APPROACH, NAV_COMMAND_CHARGE])
	_apply_button_toggle_state(button_flee, not is_free_flight_active and active_navigation_command_type == NAV_COMMAND_FLEE)
	_apply_button_toggle_state(button_camera, _is_camera_target_follow_active())


# Yellow while active; else white, or grey for an ON/OFF `switch` (lance, burn, safety, overlays).
func _apply_button_toggle_state(button: TextureButton, is_active: bool, switch: bool = false) -> void:
	if not is_instance_valid(button):
		return
	button.modulate = BUTTON_ACTIVE_MODULATE if is_active else (Constants.UI_SWITCH_OFF_MODULATE if switch else BUTTON_INACTIVE_MODULATE)


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
# World-time seconds as the HUD says them: "40 S", "3 MIN".
static func _game_minutes(seconds: float) -> String:
	return "%d S" % int(ceil(seconds)) if seconds < 60.0 else "%d MIN" % int(ceil(seconds / 60.0))


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
	_debug_label_radio.text = PoolStringArray(["RADIO"] + radio_lines).join("\n")


# A radio line said within RADIO_RANGE of the player: kept (the last RADIO_LOG_LINES), with the
# game time and the speaker's call sign.
func _on_radio_message(speaker, text: String) -> void:
	var player = GlobalRefs.player_agent_body
	if not (is_instance_valid(player) and is_instance_valid(speaker) and player.is_inside_tree()):
		return
	if speaker.global_transform.origin.distance_to(player.global_transform.origin) > Constants.RADIO_RANGE:
		return
	var seconds: int = int(Evolution.game_time)
	radio_lines.append("%02d:%02d %s: %s" % [(seconds / 60) % 60, seconds % 60, RadioScript.call_sign(speaker), text])
	if is_instance_valid(awareness_zone):
		awareness_zone.add_radio_line("%s: %s" % [RadioScript.call_sign(speaker), text])  # No clock: it fades instead
	while radio_lines.size() > Constants.RADIO_LOG_LINES:
		radio_lines.pop_front()
	if is_instance_valid(debug_overlay) and debug_overlay.visible:
		_debug_label_radio.text = PoolStringArray(["RADIO"] + radio_lines).join("\n")


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


# Where the power goes (FittingWindow.power_flow), a line each under POWER.
static func describe_power_flow(player) -> String:
	return "  " + PoolStringArray(FittingWindowScript.power_flow(player)).join("\n  ")


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
		if _current_target.get_deposit() <= 0:
			lines.append("WORKED OUT: ORE BACK IN %s" % _game_minutes(_current_target.ore_back_in()))
		else:
			lines.append("ORE %d: LANCE IT" % _current_target.get_deposit())
	elif _current_target.get("hull_max"):
		lines.append("HULL %d / %d" % [ceil(_current_target.hull), _current_target.hull_max])
		var cues: Array = _target_projector.get_ship_cues(_current_target)
		if not cues.empty():
			lines.append(PoolStringArray(cues).join("  "))
		var reach: float = player.weapon_reach_of(player)
		if reach > 0.0 and _current_target.has_method("get_jamming") and _current_target.get_jamming() > 0.0:
			lines.append("JAMMING: LOCK WITHIN %s" % _format_distance(_current_target.lock_range_for(player, reach)))
		var their_reach: float = player.weapon_reach_of(_current_target)
		if their_reach > 0.0 and player.has_method("get_jamming") and player.get_jamming() > 0.0:
			lines.append("YOUR JAMMING: THEY LOCK WITHIN %s" % _format_distance(player.lock_range_for(_current_target, their_reach)))
		if _current_target.has_method("get_sensor_strength"):  # How far off it spots the player, now and coasting cold
			var sensors: float = _current_target.get_sensor_strength()
			lines.append("SPOTS YOU WITHIN %s  COASTING %s" % [_format_distance(player.get_signature() * sensors), _format_distance(player.get_signature_coasting(0.0) * sensors)])
	var ai = _current_target.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME) if _current_target is Node else null
	if ai != null and ai.has_method("get_escorts"):  # Escorts (Wages): who guards it, and whom it guards
		var escorts: Array = ai.get_escorts()
		if player in escorts:
			lines.append("ESCORTED BY YOU: %d%% OF ITS SALES WITHIN %s" % [int(Constants.ESCORT_SHARE * 100), _format_distance(Constants.ESCORT_PAY_RANGE)])
		elif not escorts.empty():
			lines.append("ESCORTED")
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
		var movement = player.get("movement_system")
		if is_instance_valid(movement) and movement.facing != Vector3.ZERO:  # A cannon holds the nose on its lead
			lines.append("  NOSE ON THE LEAD, %d deg off" % int(round(rad2deg((-player.global_transform.basis.z).angle_to(movement.facing)))))
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
		if is_instance_valid(button) and button.world_shown:
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
	return PoolStringArray([
		"FRAME %.1f ms" % report.frame_ms,
		"PHYSICS %.1f (%.1f steps)  REST %.1f" % [report.physics_ms, report.steps, report.idle_ms],
		"in steps, ms: " + _section_list(report, ["ai", "nav", "tools", "offscreen", "rounds", "agent"]),
		"per frame, ms: " + _section_list(report, ["hud", "brackets", "sound", "exhaust", "view"]),
		"GAME SPEED X%.2f" % (_frame_governor.speed if is_instance_valid(_frame_governor) else 1.0),
	]).join("\n")


static func _section_list(report: Dictionary, names: Array) -> String:
	var out: Array = []
	for name in names:
		out.append("%s %.1f" % [name.to_upper(), report.sections.get(name, 0.0)])
	return PoolStringArray(out).join("  ")


# The HUD's look (Settings "hud_preset", Constants.HUD_PRESETS): the next preset, kept.
func _on_ButtonHudLook_pressed() -> void:
	var names: Array = Constants.HUD_PRESET_ORDER
	var index: int = names.find(Settings.get_option("hud_preset"))
	Settings.set_option("hud_preset", names[(index + 1) % names.size()])


func _on_settings_changed(key: String, _value) -> void:
	if key == "hud_preset":
		apply_hud_preset()


# Tints the HUD's own parts (_hud_parts: its controls, brackets, threat ring, announcements; not the
# windows and prompts over it) by its preset (with the opacity button's share) and re-colours the
# marks, whose colours the preset grades (TargetKinds.graded).
func apply_hud_preset() -> void:
	var preset: Dictionary = Constants.hud_preset(Settings.get_option("hud_preset"))
	var tint: Color = preset.tint
	var look := Color(tint.r, tint.g, tint.b, float(preset.get("alpha", 1.0)))
	for node in _hud_parts() + ([_hud_dot] if is_instance_valid(_hud_dot) else []):
		node.modulate = look  # The HUD's own parts only: windows and prompts keep their looks
	if is_instance_valid(label_hud_look):
		label_hud_look.text = Strings.t("hud.button.hud_look", [Strings.t("hud.look." + str(Settings.get_option("hud_preset")))])  # hud.look.standard reads NORMAL (it fits the button)
	for button in _world_target_buttons.values():
		if is_instance_valid(button) and button.has_method("refresh_style"):
			button.refresh_style()


# The eye button: hides every HUD element (its controls, brackets, threat ring, announcements),
# the button too, leaving a faint dot (HudDot) where it was; the dot brings it all back. The HUD's
# looks (HUD LOOK) are another button's. Docking shows the HUD again (the station window is the
# HUD's).
func toggle_hud() -> void:
	set_hud_hidden(not hud_hidden)


func set_hud_hidden(hidden: bool) -> void:
	hud_hidden = hidden
	for node in _hud_parts():
		node.visible = not hidden
	if hidden:
		var eye: Control = $ScreenControls/CenterRightZone/ButtonHideHud
		if not is_instance_valid(_hud_dot):
			_hud_dot = HudDot.new()
			_hud_dot.name = "HudDot"
			_hud_dot.set_meta(UiScale.SKIP, true)  # Sized as the eye, already scaled
			_hud_dot.connect("pressed", self, "toggle_hud")
			add_child(_hud_dot)
			_hud_dot.modulate = $ScreenControls.modulate  # The HUD look's tint
		_hud_dot.rect_global_position = eye.rect_global_position
		_hud_dot.rect_size = eye.rect_size
		_hud_dot.visible = true
	elif is_instance_valid(_hud_dot):
		_hud_dot.visible = false


func _hud_parts() -> Array:
	var parts: Array = [$ScreenControls, $ProjectedTargetOverlay]
	for node in [threat_ring, _announcements]:
		if is_instance_valid(node):
			parts.append(node)
	return parts


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
		return Strings.t("target.jump_point")
	if target_node.is_in_group("dockable_station"):
		if "station_name" in target_node and target_node.station_name != "":
			return target_node.station_name
		return Strings.t("target.station")
	if target_node.has_method("get_display_name"):
		return target_node.get_display_name()
	if target_node.is_in_group("asteroid"):
		return Strings.t("target.asteroid")
	if target_node.is_in_group("agent_body"):
		var ship = target_node.get("ship_template")
		var ship_name: String = Strings.name_of(ship.ship_model_name) if is_instance_valid(ship) else target_node.name
		return Strings.t("target.wreck_of", [ship_name]) if target_node.get("is_wreck") else ship_name
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


func _on_agent_damaged(agent_body, damage_amount: float, source_agent) -> void:
	var player = GlobalRefs.player_agent_body
	if agent_body == player:
		print("[HUD] Player took ", damage_amount, " damage")
	# Fire between the player and a ship may turn it hostile (a grudge): its bracket at once, not at
	# the next round of the slow re-check (pips, colour, its distance among the nearest hostiles).
	var other = source_agent if agent_body == player else (agent_body if source_agent == player else null)
	if is_instance_valid(other) and other is Object:
		var button = _world_target_buttons.get(other.get_instance_id())
		var marker = button.get("_marker") if is_instance_valid(button) else null
		if is_instance_valid(marker) and other.has_method("is_enemy_of") and marker.hostile != other.is_enemy_of(player):  # Only on a change
			button.refresh_style()
			_target_projector._limit_mark_distances()


func _on_agent_disabled(agent_body) -> void:
	_target_projector.restyle_world_target(agent_body)  # Its bracket relabelled as a wreck
	if not is_instance_valid(agent_body) or agent_body != GlobalRefs.player_agent_body:
		return
	_watch_own_wreck()


# The ship is lost: the camera orbits the wreck (not tracking a target) so the player can watch the
# scene play out until WorldManager fades to the respawn at home (Constants RESPAWN_DELAY).
func _watch_own_wreck() -> void:
	EventBus.emit_signal("announcement", Strings.t("hud.ship_lost"), "danger")
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and is_instance_valid(GlobalRefs.player_agent_body):
		if camera.has_method("set_camera_mode"):
			camera.set_camera_mode(0)  # ORBIT
		camera.set_target_node(GlobalRefs.player_agent_body)
	_refresh_toggle_button_states()


# Words code wrote (the scene's own follow their keys by themselves; most others are redone each frame).
func _on_language_changed(_language) -> void:
	apply_hud_preset()
	_update_dock_button_label()


func _update_dock_button_label() -> void:
	if not is_instance_valid(label_button_dock):
		return
	if GameState.player_docked_at != "":
		label_button_dock.text = Strings.t("hud.button.undock")
	elif _current_target != null and (_is_route_target(_current_target) or (is_instance_valid(_current_target) and _current_target.is_in_group("jump_point"))):
		label_button_dock.text = Strings.t("hud.button.travel")
	else:
		label_button_dock.text = Strings.t("hud.button.dock")


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
func _compute_projected_target_distance_fade_alpha(normalized_distance: float) -> float:
	return _target_projector.compute_projected_target_distance_fade_alpha(normalized_distance)

func _get_projected_target_overlay_kind(target_ref) -> String:
	return _target_projector.get_projected_target_overlay_kind(target_ref)

func _is_projected_target_overlay_enabled(overlay_kind: String) -> bool:
	return _target_projector.is_projected_target_overlay_enabled(overlay_kind)

func _is_route_target(target_ref) -> bool:
	return _target_projector.is_route_target(target_ref)

func _is_target_valid(target_ref) -> bool:
	return _target_projector.is_target_valid(target_ref)

func _clear_route_target_overlay() -> void:
	_target_projector.clear_route_target_overlay()

func _clear_world_target_overlay() -> void:
	_target_projector.clear_world_target_overlay()

func _rebuild_projected_target_overlays() -> void:
	_target_projector.rebuild_projected_target_overlays()

func _rebuild_world_target_overlay() -> void:
	_target_projector.rebuild_world_target_overlay()

func _update_route_target_overlay() -> void:
	_target_projector.update_route_target_overlay()

func _collect_world_projected_targets() -> Array:
	return _target_projector.collect_world_projected_targets()

# `full`: also re-check which brackets show and their cues (else only on the projector's interval).
func _update_world_target_overlay(full: bool = true) -> void:
	FrameProfiler.begin(get_tree(), "brackets")
	_target_projector.update_world_target_overlay(full)
	FrameProfiler.end(get_tree(), "brackets")

func _update_route_target_selection_state() -> void:
	_target_projector.update_route_target_selection_state()

func _update_world_target_selection_state() -> void:
	_target_projector.update_world_target_selection_state()
