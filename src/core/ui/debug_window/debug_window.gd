# Debug window: tuning readouts toggled from the HUD debug button.

extends Control

onready var debug_button_close: BaseButton = $Panel/VBoxContainer/debug_HeaderRow/debug_ButtonClose
onready var debug_label_player_hull: Label = $Panel/VBoxContainer/debug_LabelPlayerHull
onready var debug_player_hull_bar: ProgressBar = $Panel/VBoxContainer/debug_PlayerHullBar

var _is_visible: bool = false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	visible = false
	if is_instance_valid(debug_button_close) and not debug_button_close.is_connected("pressed", self, "_on_debug_button_close_pressed"):
		debug_button_close.connect("pressed", self, "_on_debug_button_close_pressed")
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
	refresh_debug_window_player_hull()


func refresh_debug_window_player_hull() -> void:
	if not is_instance_valid(debug_label_player_hull) or not is_instance_valid(debug_player_hull_bar):
		return
	var player = GlobalRefs.player_agent_body
	if not is_instance_valid(player) or not player.get("hull_max"):
		debug_player_hull_bar.value = 100.0
		debug_label_player_hull.text = "Hull: --"
		return
	debug_player_hull_bar.value = player.get_hull_fraction() * 100.0
	debug_label_player_hull.text = "Hull: %d / %d" % [ceil(player.hull), player.hull_max]


func _on_debug_button_close_pressed() -> void:
	hide_debug_window()
