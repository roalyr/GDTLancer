#
# PROJECT: GDTLancer
# MODULE: debug_window.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_CONSTRAINTS.md §1; TRUTH_CONTENT-CREATION-MANUAL.md §1, §2, §6; TACTICAL_TODO.md TASK_1
# LOG_REF: 2026-05-14 01:01:21
#

extends Control

onready var debug_button_close: BaseButton = $Panel/VBoxContainer/debug_HeaderRow/debug_ButtonClose
onready var debug_label_credits: Label = $Panel/VBoxContainer/debug_LabelCredits
onready var debug_label_fp: Label = $Panel/VBoxContainer/debug_LabelFP
onready var debug_label_time: Label = $Panel/VBoxContainer/debug_LabelTime
onready var debug_label_player_hull: Label = $Panel/VBoxContainer/debug_LabelPlayerHull
onready var debug_player_hull_bar: ProgressBar = $Panel/VBoxContainer/debug_PlayerHullBar
onready var debug_button_sim_panel: Button = $Panel/VBoxContainer/debug_ButtonSimPanel
onready var debug_button_map_panel: Button = $Panel/VBoxContainer/debug_ButtonMapPanel
onready var debug_button_inventory: Button = $Panel/VBoxContainer/debug_ButtonInventory

var _is_visible: bool = false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	visible = false
	if is_instance_valid(debug_button_close) and not debug_button_close.is_connected("pressed", self, "_on_debug_button_close_pressed"):
		debug_button_close.connect("pressed", self, "_on_debug_button_close_pressed")
	if is_instance_valid(debug_button_sim_panel) and not debug_button_sim_panel.is_connected("pressed", self, "_on_debug_button_sim_panel_pressed"):
		debug_button_sim_panel.connect("pressed", self, "_on_debug_button_sim_panel_pressed")
	if is_instance_valid(debug_button_map_panel) and not debug_button_map_panel.is_connected("pressed", self, "_on_debug_button_map_panel_pressed"):
		debug_button_map_panel.connect("pressed", self, "_on_debug_button_map_panel_pressed")
	if is_instance_valid(debug_button_inventory) and not debug_button_inventory.is_connected("pressed", self, "_on_debug_button_inventory_pressed"):
		debug_button_inventory.connect("pressed", self, "_on_debug_button_inventory_pressed")
	call_deferred("refresh_debug_window_state")


func toggle_debug_window() -> void:
	_is_visible = not _is_visible
	visible = _is_visible
	if _is_visible:
		refresh_debug_window_state()


func hide_debug_window() -> void:
	_is_visible = false
	visible = false


func refresh_debug_window_state() -> void:
	refresh_debug_window_resources()
	refresh_debug_window_time_display()
	refresh_debug_window_player_hull()


func refresh_debug_window_resources() -> void:
	if not is_instance_valid(debug_label_credits) or not is_instance_valid(debug_label_fp):
		return
	if not is_instance_valid(GlobalRefs.character_system):
		debug_label_credits.text = "Credits: --"
		debug_label_fp.text = "Current FP: --"
		return
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		debug_label_credits.text = "Credits: --"
		debug_label_fp.text = "Current FP: --"
		return
	debug_label_credits.text = "Credits: " + str(player_char.credits)
	debug_label_fp.text = "Current FP: " + str(player_char.focus_points)


func refresh_debug_window_time_display() -> void:
	if not is_instance_valid(debug_label_time):
		return
	var time_str = "%02d:%02d" % [GameState.game_time_seconds / 60, GameState.game_time_seconds % 60]
	debug_label_time.text = "Time: " + time_str


func refresh_debug_window_player_hull() -> void:
	if not is_instance_valid(debug_label_player_hull) or not is_instance_valid(debug_player_hull_bar):
		return
	var player_agent: Dictionary = GameState.agents.get("player", {})
	var hull_pct: float = player_agent.get("hull_integrity", 1.0)
	debug_player_hull_bar.value = hull_pct * 100.0
	debug_label_player_hull.text = "Hull: " + str(int(round(hull_pct * 100.0))) + "%"


func _on_debug_button_close_pressed() -> void:
	hide_debug_window()


func _on_debug_button_sim_panel_pressed() -> void:
	_toggle_named_panel("SimDebugPanel", "_toggle")


func _on_debug_button_map_panel_pressed() -> void:
	_toggle_named_panel("DebugMapPanel", "_toggle_panel")


func _on_debug_button_inventory_pressed() -> void:
	pass


func _toggle_named_panel(panel_name: String, toggle_method: String) -> void:
	var scene_root = get_tree().current_scene
	if not is_instance_valid(scene_root):
		return
	var panel = scene_root.find_node(panel_name, true, false)
	if not is_instance_valid(panel):
		printerr("DebugWindow: Missing panel: %s" % panel_name)
		return
	if panel.has_method(toggle_method):
		panel.call(toggle_method)
