#
# PROJECT: GDTLancer
# MODULE: debug_window.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
# LOG_REF: 2026-06-14 01:00:09
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
onready var debug_button_contract_board: Button = $Panel/VBoxContainer/debug_ButtonContractBoard

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
	if is_instance_valid(debug_button_contract_board) and not debug_button_contract_board.is_connected("pressed", self, "_on_debug_button_contract_board_pressed"):
		debug_button_contract_board.connect("pressed", self, "_on_debug_button_contract_board_pressed")
	if is_instance_valid(debug_label_fp):
		debug_label_fp.visible = false
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
		debug_label_credits.text = "Wealth: --"
		debug_label_fp.text = ""
		return
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		debug_label_credits.text = "Wealth: --"
		debug_label_fp.text = ""
		return
	debug_label_credits.text = "Wealth: " + str(player_char.wealth_tier) + " (" + str(player_char.wealth_progress) + "/10)"
	debug_label_fp.text = ""


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


func _on_debug_button_contract_board_pressed() -> void:
	_toggle_named_panel("ContractBoard", "_toggle")


func _toggle_named_panel(panel_name: String, toggle_method: String) -> void:
	var panel = _find_named_panel(panel_name)
	if not is_instance_valid(panel):
		printerr("DebugWindow: Missing panel: %s" % panel_name)
		return
	if panel.has_method(toggle_method):
		panel.call(toggle_method)


func _find_named_panel(panel_name: String) -> Node:
	var scene_root = get_tree().current_scene
	if is_instance_valid(scene_root):
		var scene_panel = scene_root.find_node(panel_name, true, false)
		if is_instance_valid(scene_panel):
			return scene_panel

	var ancestor_root: Node = self
	while is_instance_valid(ancestor_root.get_parent()):
		ancestor_root = ancestor_root.get_parent()
	if is_instance_valid(ancestor_root):
		var ancestor_panel = ancestor_root.find_node(panel_name, true, false)
		if is_instance_valid(ancestor_panel):
			return ancestor_panel

	var tree_root = get_tree().root
	if is_instance_valid(tree_root):
		var tree_panel = tree_root.find_node(panel_name, true, false)
		if is_instance_valid(tree_panel):
			return tree_panel

	return null
