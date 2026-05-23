#
# PROJECT: GDTLancer
# MODULE: station_menu.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TRUTH_CONTENT-CREATION-MANUAL.md §3.4, §6, §7; TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-05-23 17:10:12
#

extends Control

## StationMenu: Overlay that appears while the player is docked at a station.
##
## Shows the station name, a set of action buttons with explicit deferred-service
## feedback, and a prominent Undock button that emits `player_undocked` via
## EventBus so the PlayerController re-enables input processing.


# =============================================================================
# === NODE REFERENCES =========================================================
# =============================================================================

onready var _panel: Panel = $Panel
onready var _label_station_name: Label = $Panel/VBoxContainer/HeaderRow/LabelStationName
onready var _label_info: Label = $Panel/VBoxContainer/LabelInfo
onready var _btn_close: BaseButton = $Panel/VBoxContainer/HeaderRow/BtnClose
onready var _btn_trade: Button = $Panel/VBoxContainer/BtnTrade
onready var _btn_contracts: Button = $Panel/VBoxContainer/BtnContracts
onready var _btn_undock: Button = $Panel/VBoxContainer/BtnUndock


# =============================================================================
# === STATE ===================================================================
# =============================================================================

var _current_location_id: String = ""
var _service_status_message: String = ""


# =============================================================================
# === LIFECYCLE ===============================================================
# =============================================================================

func _ready() -> void:
	visible = false

	# --- EventBus connections ---
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")

	# --- Button connections ---
	_btn_close.connect("pressed", self, "_on_close_pressed")
	_btn_undock.connect("pressed", self, "_on_undock_pressed")
	_btn_trade.connect("pressed", self, "_on_trade_pressed")
	_btn_contracts.connect("pressed", self, "_on_contracts_pressed")


# =============================================================================
# === SIGNAL HANDLERS =========================================================
# =============================================================================

func _on_player_docked(location_id: String) -> void:
	_current_location_id = location_id
	_service_status_message = ""
	_update_station_label(location_id)
	_update_info_label()
	visible = true
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("StationMenu: Opened for location '", location_id, "'")


func _on_player_undocked() -> void:
	visible = false
	_current_location_id = ""
	_service_status_message = ""
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("StationMenu: Closed")


func open_for_current_dock() -> void:
	if GameState.player_docked_at == "":
		visible = false
		_current_location_id = ""
		_service_status_message = ""
		_update_info_label()
		return
	_current_location_id = GameState.player_docked_at
	_service_status_message = ""
	_update_station_label(_current_location_id)
	_update_info_label()
	visible = true


# =============================================================================
# === BUTTON CALLBACKS ========================================================
# =============================================================================

func _on_undock_pressed() -> void:
	EventBus.emit_signal("player_undocked")


func _on_close_pressed() -> void:
	visible = false


func _on_trade_pressed() -> void:
	_show_deferred_service_feedback(
		"Trade",
		"trade",
		"Trading remains unavailable while the trading layer is rebuilt."
	)


func _on_contracts_pressed() -> void:
	_show_deferred_service_feedback(
		"Contracts",
		"contracts",
		"Contracts remain unavailable while the contract layer is rebuilt."
	)


# =============================================================================
# === HELPERS =================================================================
# =============================================================================

func _show_deferred_service_feedback(service_label: String, service_id: String, deferred_message: String) -> void:
	if GameState.player_docked_at == "":
		visible = false
		_current_location_id = ""
		_service_status_message = ""
		_update_info_label()
		return

	if GameState.player_docked_at != _current_location_id:
		_current_location_id = GameState.player_docked_at
		_update_station_label(_current_location_id)

	if _location_offers_service(_current_location_id, service_id):
		_service_status_message = deferred_message
	else:
		_service_status_message = "%s is not offered at this dock." % service_label
	_update_info_label()


func _location_offers_service(location_id: String, service_id: String) -> bool:
	if location_id == "" or not GameState.locations.has(location_id):
		return true

	var location_record = GameState.locations[location_id]
	var available_services = null
	if location_record is Dictionary:
		available_services = location_record.get("available_services", null)
	elif location_record is Object and "available_services" in location_record:
		available_services = location_record.available_services

	return not (available_services is Array) or service_id in available_services

func _update_station_label(location_id: String) -> void:
	var display_name: String = location_id
	if GameState.locations.has(location_id):
		var loc = GameState.locations[location_id]
		if loc is Dictionary and str(loc.get("location_name", "")) != "":
			display_name = str(loc.get("location_name", ""))
		elif loc is Object and "location_name" in loc and loc.location_name != "":
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
	if _service_status_message != "":
		if info_text != "":
			info_text += "\n"
		info_text += _service_status_message
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
