# File: res://core/ui/main_hud/main_hud.gd
# Script for the main HUD container. Handles displaying targeting info, etc.
# Version: 1.2 - Integrating systems.

extends Control

# --- Nodes ---
onready var targeting_indicator: Control = $TargetingIndicator
onready var label_wp: Label = $ScreenControls/TopLeftZone/LabelWP
onready var label_fp: Label = $ScreenControls/TopLeftZone/LabelFP
onready var button_character: Button = $ScreenControls/TopLeftZone/ButtonCharacter
onready var docking_prompt: Control = $ScreenControls/TopCenterZone/DockingPrompt
onready var docking_label: Label = $ScreenControls/TopCenterZone/DockingPrompt/Label

# --- Combat HUD Nodes ---
onready var target_info_panel: PanelContainer = $ScreenControls/TopCenterZone/TargetInfoPanel
onready var label_target_name: Label = $ScreenControls/TopCenterZone/TargetInfoPanel/VBoxContainer/LabelTargetName
onready var target_hull_bar: ProgressBar = $ScreenControls/TopCenterZone/TargetInfoPanel/VBoxContainer/TargetHullBar

const StationMenuScene = preload("res://scenes/ui/station_menu/StationMenu.tscn")
var station_menu_instance = null

const ActionCheckScene = preload("res://core/ui/action_check/action_check.tscn")
var action_check_instance = null

# --- State ---
var _current_target: Spatial = null
var _main_camera: Camera = null
var _current_target_uid: int = -1  # UID of current combat target for hull tracking


# --- Initialization ---
func _ready():
	GlobalRefs.set_main_hud(self)
	
	# Instantiate Station Menu
	station_menu_instance = StationMenuScene.instance()
	add_child(station_menu_instance)
	# It starts hidden by default in its own _ready

	# Instantiate Action Check UI (hidden by default; shown via EventBus)
	action_check_instance = ActionCheckScene.instance()
	add_child(action_check_instance)

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

		if not EventBus.is_connected("player_wp_changed", self, "_on_player_wp_changed"):
			EventBus.connect("player_wp_changed", self, "_on_player_wp_changed")

		if not EventBus.is_connected("player_fp_changed", self, "_on_player_fp_changed"):
			EventBus.connect("player_fp_changed", self, "_on_player_fp_changed")
			
		EventBus.connect("dock_available", self, "_on_dock_available")
		EventBus.connect("dock_unavailable", self, "_on_dock_unavailable")
		EventBus.connect("player_docked", self, "_on_player_docked")

		# Combat flow (Phase 1: debug feedback)
		if not EventBus.is_connected("combat_initiated", self, "_on_combat_initiated"):
			EventBus.connect("combat_initiated", self, "_on_combat_initiated")
		if not EventBus.is_connected("combat_ended", self, "_on_combat_ended"):
			EventBus.connect("combat_ended", self, "_on_combat_ended")
		if not EventBus.is_connected("agent_damaged", self, "_on_agent_damaged"):
			EventBus.connect("agent_damaged", self, "_on_agent_damaged")

	else:
		printerr("MainHUD Error: EventBus not available!")

	# Connect to CombatSystem signals for hull updates (deferred to allow system init)
	call_deferred("_connect_combat_signals")
	
	# Ensure target info panel starts hidden
	if target_info_panel:
		target_info_panel.visible = false

	# Connect draw signal for custom drawing (optional, but good for style)
	targeting_indicator.connect("draw", self, "_draw_targeting_indicator")


# --- Process Update ---
func _process(_delta):
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
	else:
		_on_Player_Target_Deselected()


func _on_Player_Target_Deselected():
	_current_target = null
	_current_target_uid = -1
	targeting_indicator.visible = false
	if target_info_panel:
		target_info_panel.visible = false
	set_process(false)  # Can disable processing if target is deselected


func _on_player_wp_changed():
	label_wp.text = (
		"Current WP: "
		+ str(GlobalRefs.character_system.get_player_character().wealth_points)
	)


func _on_player_fp_changed():
	label_fp.text = (
		"Current FP: "
		+ str(GlobalRefs.character_system.get_player_character().focus_points)
	)


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


func _on_combat_initiated(_player_agent, enemy_agents: Array) -> void:
	print("[HUD] Combat initiated with ", enemy_agents.size(), " hostiles")


func _on_combat_ended(result_dict: Dictionary) -> void:
	var outcome = result_dict.get("outcome", "unknown")
	print("[HUD] Combat ended: ", outcome)


func _on_agent_damaged(agent_body, damage_amount: float, _source_agent) -> void:
	if agent_body == GlobalRefs.player_agent_body:
		print("[HUD] Player took ", damage_amount, " damage")


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



func _on_SliderControlRight_value_changed(value):
	# SPEED (maximum) limiter.
	# This slider is inverted (rotated by 180) for the sake of appearance.
	if EventBus:
		EventBus.emit_signal("player_ship_speed_changed", value)


func _on_ButtonCharacter_pressed():
	GlobalRefs.character_status.open_screen()


func _on_ButtonInventory_pressed():
	GlobalRefs.inventory_screen.open_screen()


# --- Combat HUD Functions ---

func _connect_combat_signals() -> void:
	"""Connect to CombatSystem signals for hull updates."""
	if is_instance_valid(GlobalRefs.combat_system):
		if not GlobalRefs.combat_system.is_connected("damage_dealt", self, "_on_damage_dealt"):
			GlobalRefs.combat_system.connect("damage_dealt", self, "_on_damage_dealt")
		if not GlobalRefs.combat_system.is_connected("ship_disabled", self, "_on_ship_disabled"):
			GlobalRefs.combat_system.connect("ship_disabled", self, "_on_ship_disabled")


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
