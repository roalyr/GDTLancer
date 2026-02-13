#
# PROJECT: GDTLancer
# MODULE: station_menu.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md
# LOG_REF: 2026-02-13
#
# Rebuilt after TASK 15 cleanup.  Old version was coupled to deleted systems
# (ContractSystem, TradingSystem, NarrativeActionSystem).  This version keeps
# the undock flow intact and provides placeholder hooks for future trade /
# contract UI once those systems are rebuilt on the simulation foundation.
#

extends Control

## StationMenu: Overlay that appears while the player is docked at a station.
##
## Shows the station name, a set of action buttons (Trade, Contracts — currently
## stubbed), and a prominent Undock button that emits `player_undocked` via
## EventBus so the PlayerController re-enables input processing.


# =============================================================================
# === NODE REFERENCES =========================================================
# =============================================================================

onready var _panel: Panel = $Panel
onready var _label_station_name: Label = $Panel/VBoxContainer/LabelStationName
onready var _label_info: Label = $Panel/VBoxContainer/LabelInfo
onready var _btn_trade: Button = $Panel/VBoxContainer/BtnTrade
onready var _btn_contracts: Button = $Panel/VBoxContainer/BtnContracts
onready var _btn_undock: Button = $Panel/VBoxContainer/BtnUndock


# =============================================================================
# === STATE ===================================================================
# =============================================================================

var _current_location_id: String = ""


# =============================================================================
# === LIFECYCLE ===============================================================
# =============================================================================

func _ready() -> void:
	visible = false

	# --- EventBus connections ---
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")

	# --- Button connections ---
	_btn_undock.connect("pressed", self, "_on_undock_pressed")
	_btn_trade.connect("pressed", self, "_on_trade_pressed")
	_btn_contracts.connect("pressed", self, "_on_contracts_pressed")


# =============================================================================
# === SIGNAL HANDLERS =========================================================
# =============================================================================

func _on_player_docked(location_id: String) -> void:
	_current_location_id = location_id
	_update_station_label(location_id)
	_update_info_label()
	visible = true
	print("StationMenu: Opened for location '", location_id, "'")


func _on_player_undocked() -> void:
	visible = false
	_current_location_id = ""
	print("StationMenu: Closed")


# =============================================================================
# === BUTTON CALLBACKS ========================================================
# =============================================================================

func _on_undock_pressed() -> void:
	EventBus.emit_signal("player_undocked")


func _on_trade_pressed() -> void:
	# TODO: Open trade interface once TradingSystem is rebuilt on simulation.
	print("StationMenu: Trade pressed (not yet implemented)")


func _on_contracts_pressed() -> void:
	# TODO: Open contract interface once ContractSystem is rebuilt on simulation.
	print("StationMenu: Contracts pressed (not yet implemented)")


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _update_station_label(location_id: String) -> void:
	var display_name: String = location_id
	if GameState.locations.has(location_id):
		var loc = GameState.locations[location_id]
		if loc is Object and "location_name" in loc and loc.location_name != "":
			display_name = loc.location_name
	_label_station_name.text = display_name


func _update_info_label() -> void:
	# Show basic player resource summary while docked.
	var info_text: String = ""
	var player_uid: int = int(GameState.player_character_uid)
	if player_uid >= 0 and GameState.characters.has(player_uid):
		var pc = GameState.characters[player_uid]
		info_text += "Credits: %d" % pc.credits
		info_text += "    FP: %d" % pc.focus_points
	_label_info.text = info_text


# =============================================================================
# === CLEANUP =================================================================
# =============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if EventBus and EventBus.is_connected("player_docked", self, "_on_player_docked"):
			EventBus.disconnect("player_docked", self, "_on_player_docked")
		if EventBus and EventBus.is_connected("player_undocked", self, "_on_player_undocked"):
			EventBus.disconnect("player_undocked", self, "_on_player_undocked")
