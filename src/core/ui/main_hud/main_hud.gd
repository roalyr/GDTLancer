#
# PROJECT: GDTLancer
# MODULE: main_hud.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md Section 1.2
# LOG_REF: 2026-01-30
#

extends Control

## MainHUD: Primary gameplay HUD displaying player resources, target info, and combat status.
## Manages sub-screens (Station Menu, Action Check, Narrative Status, Contacts Panel) and docking prompts.

# --- Nodes ---
onready var targeting_indicator: Control = $TargetingIndicator
onready var label_credits: Label = $ScreenControls/TopLeftZone/LabelCredits
onready var label_fp: Label = $ScreenControls/TopLeftZone/LabelFP
onready var label_time: Label = $ScreenControls/TopLeftZone/LabelTime
onready var label_player_hull: Label = $ScreenControls/TopLeftZone/LabelPlayerHull
onready var player_hull_bar: ProgressBar = $ScreenControls/TopLeftZone/PlayerHullBar
onready var button_character: Button = $ScreenControls/TopLeftZone/ButtonCharacter
onready var button_narrative_status: Button = $ScreenControls/TopLeftZone/ButtonNarrativeStatus
onready var button_contacts: Button = $ScreenControls/TopLeftZone/ButtonContacts # New button
onready var button_menu: TextureButton = $ScreenControls/CenterLeftZone/ButtonMenu
onready var button_camera: TextureButton = $ScreenControls/CenterRightZone/ButtonCamera
onready var docking_prompt: Control = $ScreenControls/TopCenterZone/DockingPrompt
onready var docking_label: Label = $ScreenControls/TopCenterZone/DockingPrompt/Label

# --- Game Over UI ---
onready var game_over_overlay: Control = $GameOverOverlay
onready var button_return_to_menu: Button = $GameOverOverlay/CenterContainer/PanelContainer/VBoxContainer/ButtonReturnToMenu

# --- Combat HUD Nodes ---
onready var target_info_panel: PanelContainer = $ScreenControls/TopCenterZone/TargetInfoPanel
onready var label_target_name: Label = $ScreenControls/TopCenterZone/TargetInfoPanel/VBoxContainer/LabelTargetName
onready var target_hull_bar: ProgressBar = $ScreenControls/TopCenterZone/TargetInfoPanel/VBoxContainer/TargetHullBar

const StationMenuScene = preload("res://scenes/ui/menus/station_menu/StationMenu.tscn")
var station_menu_instance = null

const ActionCheckScene = preload("res://scenes/ui/screens/action_check.tscn")
var action_check_instance = null

const NarrativeStatusScene = preload("res://scenes/ui/screens/narrative_status_panel.tscn")
var narrative_status_instance = null

const ContactsPanelScene = preload("res://src/core/ui/contacts_panel/contacts_panel.tscn")
var contacts_panel_instance = null

# --- State ---
var _current_target: Spatial = null
var _main_camera: Camera = null
var _current_target_uid: int = -1  # UID of current combat target for hull tracking
var _player_uid: int = -1
var _is_game_over: bool = false
var _action_feedback_popup: AcceptDialog = null  # Popup for dock/attack feedback
var _hud_alpha = 1.0

# --- Initialization ---
func _ready():
	GlobalRefs.set_main_hud(self)
	
	# Instantiate Station Menu
	station_menu_instance = StationMenuScene.instance()
	add_child(station_menu_instance)
	# It starts hidden by default in its own _ready

	# Instantiate Action Check UI (hidden by default; shown via EventBus)
	action_check_instance = ActionCheckScene.instance()
	action_check_instance = ActionCheckScene.instance()
	add_child(action_check_instance)

	# Instantiate Narrative Status Panel (hidden by default)
	narrative_status_instance = NarrativeStatusScene.instance()
	add_child(narrative_status_instance)
	
	# Instantiate Contacts Panel (Task 10)
	contacts_panel_instance = ContactsPanelScene.instance()
	add_child(contacts_panel_instance)
	
	# Initial button wiring - reusing existing button if possible, but adding specific connection
	if is_instance_valid(button_contacts):
		button_contacts.connect("pressed", self, "_on_ButtonContacts_pressed")
	elif is_instance_valid(button_narrative_status):
		# Fallback: if HUD scene isn't updated with a new button, we can wire the character button or similar
		# For now, we assume the user will update the scene or we use existing Narrative Status button as entry
		pass

	# Ensure indicator starts hidden
	targeting_indicator.visible = false

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

		if not EventBus.is_connected("world_event_tick_triggered", self, "_on_world_event_tick_triggered"):
			EventBus.connect("world_event_tick_triggered", self, "_on_world_event_tick_triggered")

		if EventBus.has_signal("game_time_advanced") and not EventBus.is_connected("game_time_advanced", self, "_on_game_time_advanced"):
			EventBus.connect("game_time_advanced", self, "_on_game_time_advanced")
			
		EventBus.connect("dock_available", self, "_on_dock_available")
		EventBus.connect("dock_unavailable", self, "_on_dock_unavailable")
		EventBus.connect("player_docked", self, "_on_player_docked")
		
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
		if not EventBus.is_connected("new_game_requested", self, "_on_new_game_requested"):
			EventBus.connect("new_game_requested", self, "_on_new_game_requested")
		if not EventBus.is_connected("game_state_loaded", self, "_on_game_state_loaded"):
			EventBus.connect("game_state_loaded", self, "_on_game_state_loaded")

	else:
		printerr("MainHUD Error: EventBus not available!")

	# Connect to CombatSystem signals for hull updates (deferred to allow system init)
	call_deferred("_connect_combat_signals")
	call_deferred("_refresh_player_resources")
	call_deferred("_deferred_refresh_player_hull")
	
	# Ensure target info panel starts hidden
	if target_info_panel:
		target_info_panel.visible = false

	# Connect draw signal for custom drawing (optional, but good for style)
	targeting_indicator.connect("draw", self, "_draw_targeting_indicator")

	# Connect ButtonMenu to open main menu
	if is_instance_valid(button_menu):
		if not button_menu.is_connected("pressed", self, "_on_ButtonMenu_pressed"):
			button_menu.connect("pressed", self, "_on_ButtonMenu_pressed")

	if is_instance_valid(button_narrative_status):
		button_narrative_status.connect("pressed", self, "_on_ButtonNarrativeStatus_pressed")

	# Connect ButtonCamera to toggle camera mode
	if is_instance_valid(button_camera):
		if not button_camera.is_connected("pressed", self, "_on_ButtonCamera_pressed"):
			button_camera.connect("pressed", self, "_on_ButtonCamera_pressed")

	# Initialize TU display
	_refresh_time_display()


# --- Process Update ---
func _process(_delta):
	# If the selected target is gone, clear the UI state.
	if _current_target != null and not is_instance_valid(_current_target):
		_on_Player_Target_Deselected()
		return

	# Only update position if a target is selected and valid
	if is_instance_valid(_current_target) and is_instance_valid(_main_camera):
		# Project the target's 3D origin position to 2D screen coordinates
		var screen_pos: Vector2 = _main_camera.unproject_position(
			_current_target.global_transform.origin
		)

		# Check if the target is behind the camera
		var target_dir = (_current_target.global_transform.origin - _main_camera.global_transform.origin).normalized()
		var camera_fwd = -_main_camera.global_transform.basis.z.normalized()
		var is_in_front = target_dir.dot(camera_fwd) >= 0  # Use >= 0 to include exactly perpendicular

		# --- MODIFIED Visibility Logic ---
		# Set visibility based on whether the target is in front
		targeting_indicator.visible = is_in_front

		# Only update position and redraw if it's actually visible
		if targeting_indicator.visible:
			# Update the indicator's position
			targeting_indicator.rect_position = screen_pos - (targeting_indicator.rect_size / 2.0)
			targeting_indicator.update()  # Trigger redraw if using _draw
	else:
		# Ensure indicator is hidden if target becomes invalid or camera is invalid
		if targeting_indicator.visible:
			targeting_indicator.visible = false
		if target_info_panel and target_info_panel.visible:
			target_info_panel.visible = false


# --- Signal Handlers ---
func _on_Player_Target_Selected(target_node: Spatial):
	print(target_node)
	if is_instance_valid(target_node):
		_current_target = target_node
		# Visibility is now primarily handled in _process,
		# but we still need to ensure _process runs.
		# targeting_indicator.visible = true # This line can be removed or kept, _process will override
		set_process(true)  # Ensure _process runs
		
		# Update combat target info panel
		_update_target_info_panel(target_node)
		
		# Update camera look_at_target if in target tracking mode
		var camera = GlobalRefs.main_camera
		if is_instance_valid(camera) and camera.get_camera_mode() == 1:  # TARGET_TRACKING
			camera.set_look_at_target(target_node)
	else:
		_on_Player_Target_Deselected()


func _on_Player_Target_Deselected():
	_current_target = null
	_current_target_uid = -1
	targeting_indicator.visible = false
	if target_info_panel:
		target_info_panel.visible = false
	set_process(false)  # Can disable processing if target is deselected
	_refresh_player_hull()
	
	# If camera is in target tracking mode, switch back to orbit mode
	var camera = GlobalRefs.main_camera
	if is_instance_valid(camera) and camera.get_camera_mode() == 1:  # TARGET_TRACKING
		camera.set_camera_mode(0)  # ORBIT


func _on_agent_despawning(agent_body) -> void:
	# If our selected target is being removed, clear target UI.
	if is_instance_valid(_current_target) and agent_body == _current_target:
		_on_Player_Target_Deselected()


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
	if not is_instance_valid(label_credits) or not is_instance_valid(label_fp):
		return
	if not is_instance_valid(GlobalRefs.character_system):
		return
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		return
	label_credits.text = "Credits: " + str(player_char.credits)
	label_fp.text = "Current FP: " + str(player_char.focus_points)


func _refresh_time_display() -> void:
	if not is_instance_valid(label_time):
		return
	var time_str = "%02d:%02d" % [GameState.game_time_seconds / 60, GameState.game_time_seconds % 60]
	label_time.text = "Time: " + time_str


func _on_world_event_tick_triggered(_seconds_amount: int = 0) -> void:
	_refresh_time_display()
	_refresh_player_resources()


func _on_game_time_advanced(_seconds_added: int = 0) -> void:
	_refresh_time_display()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if EventBus:
			EventBus.emit_signal("main_menu_requested")
			EventBus.emit_signal("main_menu_requested")
			get_tree().set_input_as_handled()


func _on_ButtonMenu_pressed() -> void:
	"""Handle menu button press - opens main menu."""
	if EventBus:
		EventBus.emit_signal("main_menu_requested")


func _on_ButtonCamera_pressed() -> void:
	"""Handle camera button press - toggles between orbit and target-tracking mode."""
	var camera = GlobalRefs.main_camera
	if not is_instance_valid(camera):
		return
	
	# Toggle camera mode
	camera.toggle_camera_mode()
	
	# If switching to target tracking mode, set the look_at_target
	if camera.get_camera_mode() == 1:  # TARGET_TRACKING = 1
		if is_instance_valid(_current_target):
			camera.set_look_at_target(_current_target)
		else:
			# No target selected, switch back to orbit mode
			camera.set_camera_mode(0)  # ORBIT = 0
			print("Camera: No target selected for tracking mode.")


# --- Custom Drawing (Optional but Recommended) ---
func _draw_targeting_indicator():
	# Example: Draw a simple white rectangle outline
	var _rect = Rect2(Vector2.ZERO, targeting_indicator.rect_size)
	var _line_color = Color.white
	var _line_width = 1.0  # Adjust thickness as needed
	#targeting_indicator.draw_rect(rect, line_color, false, line_width)

	# Example: Draw simple corner brackets
	var size = targeting_indicator.rect_size
	var corner_len = size.x * 0.25  # Length of corner lines
	var color = Color.cyan
	var width = 2.0
	# # Top-left
	targeting_indicator.draw_line(Vector2(0, 0), Vector2(corner_len, 0), color, width)
	targeting_indicator.draw_line(Vector2(0, 0), Vector2(0, corner_len), color, width)
	# # Top-right
	targeting_indicator.draw_line(Vector2(size.x, 0), Vector2(size.x - corner_len, 0), color, width)
	targeting_indicator.draw_line(Vector2(size.x, 0), Vector2(size.x, corner_len), color, width)
	# # Bottom-left
	targeting_indicator.draw_line(Vector2(0, size.y), Vector2(corner_len, size.y), color, width)
	targeting_indicator.draw_line(Vector2(0, size.y), Vector2(0, size.y - corner_len), color, width)
	# # Bottom-right
	targeting_indicator.draw_line(
		Vector2(size.x, size.y), Vector2(size.x - corner_len, size.y), color, width
	)
	targeting_indicator.draw_line(
		Vector2(size.x, size.y), Vector2(size.x, size.y - corner_len), color, width
	)


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


func _on_ButtonStop_pressed():
	if EventBus:
		EventBus.emit_signal("player_stop_pressed")


func _on_ButtonOrbit_pressed():
	if EventBus:
		EventBus.emit_signal("player_orbit_pressed")


func _on_ButtonApproach_pressed():
	if EventBus:
		EventBus.emit_signal("player_approach_pressed")


func _on_ButtonFlee_pressed():
	if EventBus:
		EventBus.emit_signal("player_flee_pressed")

func _on_ButtonInteract_pressed():
	if EventBus:
		EventBus.emit_signal("player_interact_pressed")


func _on_ButtonDock_pressed():
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
	print("MainHUD: Dock available signal received for ", location_id)
	if docking_prompt:
		docking_prompt.visible = true
		if docking_label:
			docking_label.text = "Docking Available - Press Interact"

func _on_dock_unavailable():
	print("MainHUD: Dock unavailable signal received")
	if docking_prompt:
		docking_prompt.visible = false

func _on_player_docked(_location_id):
	if docking_prompt:
		docking_prompt.visible = false


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
	GlobalRefs.character_status.open_screen()


func _on_ButtonInventory_pressed():
	GlobalRefs.inventory_screen.open_screen()


func _on_ButtonNarrativeStatus_pressed():
	if is_instance_valid(narrative_status_instance):
		narrative_status_instance.open_screen()


# --- Combat HUD Functions ---

func _connect_combat_signals() -> void:
	"""Connect to CombatSystem signals for hull updates."""
	if is_instance_valid(GlobalRefs.combat_system):
		if not GlobalRefs.combat_system.is_connected("damage_dealt", self, "_on_damage_dealt"):
			GlobalRefs.combat_system.connect("damage_dealt", self, "_on_damage_dealt")
		if not GlobalRefs.combat_system.is_connected("ship_disabled", self, "_on_ship_disabled"):
			GlobalRefs.combat_system.connect("ship_disabled", self, "_on_ship_disabled")
		# If the player is involved, refresh the player hull display on damage events.
		if not GlobalRefs.combat_system.is_connected("damage_dealt", self, "_on_any_damage_dealt_refresh_player"):
			GlobalRefs.combat_system.connect("damage_dealt", self, "_on_any_damage_dealt_refresh_player")


func _refresh_player_hull() -> void:
	if not is_instance_valid(label_player_hull) or not is_instance_valid(player_hull_bar):
		return
	if not is_instance_valid(GlobalRefs.player_agent_body):
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return
	var raw_uid = GlobalRefs.player_agent_body.get("agent_uid")
	if raw_uid == null:
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return
	_player_uid = int(raw_uid)
	if _player_uid < 0:
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return
	if not is_instance_valid(GlobalRefs.combat_system):
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return

	# Avoid showing 0% when CombatSystem hasn't registered the player yet.
	var state: Dictionary = {}
	if GlobalRefs.combat_system.has_method("get_combat_state"):
		state = GlobalRefs.combat_system.get_combat_state(_player_uid)
	if state.empty():
		label_player_hull.text = "Hull: --"
		player_hull_bar.value = 100.0
		return

	var hull_pct: float = GlobalRefs.combat_system.get_hull_percent(_player_uid)
	player_hull_bar.value = hull_pct * 100.0
	label_player_hull.text = "Hull: " + str(int(round(hull_pct * 100.0))) + "%"


func _deferred_refresh_player_hull() -> void:
	# CombatSystem registration happens deferred from Agent initialization.
	# Retry briefly so we show player hull without requiring damage.
	for _i in range(20):
		_refresh_player_hull()
		yield(get_tree().create_timer(0.1), "timeout")


func _on_any_damage_dealt_refresh_player(_target_uid: int, _amount: float, _source_uid: int) -> void:
	# Keep player hull display current even if damage events come through CombatSystem only.
	_refresh_player_hull()


func _update_target_info_panel(target_node: Spatial) -> void:
	"""Update the target info panel with the selected target's info."""
	if not target_info_panel:
		return
	
	# Get target's agent_uid if available
	if target_node.get("agent_uid") != null:
		_current_target_uid = target_node.agent_uid
	else:
		_current_target_uid = -1
		target_info_panel.visible = false
		return
	
	# Set target name
	var target_name: String = "Unknown"
	if target_node.get("agent_name") != null:
		target_name = target_node.agent_name
	elif target_node.name:
		target_name = target_node.name
	
	if label_target_name:
		label_target_name.text = target_name
	
	# Update hull bar
	_update_target_hull_bar()
	
	target_info_panel.visible = true


func _update_target_hull_bar() -> void:
	"""Update the target hull progress bar from CombatSystem."""
	if not target_hull_bar or _current_target_uid < 0:
		return
	
	if is_instance_valid(GlobalRefs.combat_system):
		var hull_pct: float = GlobalRefs.combat_system.get_hull_percent(_current_target_uid)
		target_hull_bar.value = hull_pct * 100.0
	else:
		# CombatSystem not available, show full hull as fallback
		target_hull_bar.value = 100.0


func _on_damage_dealt(target_uid: int, _amount: float, _source_uid: int) -> void:
	"""Handle damage_dealt signal from CombatSystem to update hull bar."""
	if target_uid == _current_target_uid:
		_update_target_hull_bar()


func _on_ship_disabled(ship_uid: int) -> void:
	"""Handle ship_disabled signal - target destroyed."""
	if ship_uid == _current_target_uid:
		if target_hull_bar:
			target_hull_bar.value = 0.0
		# Optionally change display to show "DISABLED" or similar
		if label_target_name:
			label_target_name.text = label_target_name.text + " [DISABLED]"


func _on_ButtonUIOpacity_pressed() -> void:
	"""Handle main HUD transparency (cycle)."""
	_hud_alpha -= 0.25
	self.set_modulate(Color(1, 1, 1, _hud_alpha))
	if _hud_alpha <= 0.0:
		_hud_alpha = 1.0

# --- Contacts Panel ---
func _on_ButtonContacts_pressed() -> void:
    if is_instance_valid(contacts_panel_instance):
        contacts_panel_instance.open_screen()
