#
# PROJECT: GDTLancer
# MODULE: station_menu.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TRUTH_CONTENT-CREATION-MANUAL.md §3.4, §6, §7; TACTICAL_TODO.md TASK_6
# LOG_REF: 2026-05-26 18:46:00
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
onready var _contract_board: VBoxContainer = $Panel/VBoxContainer/ContractBoard
onready var _station_list_label: Label = $Panel/VBoxContainer/ContractBoard/StationListLabel
onready var _contract_list: VBoxContainer = $Panel/VBoxContainer/ContractBoard/ContractScroll/ContractList
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
	_accept_selected_contract()


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
	# Show concise dock/player state here; the contract board renders the detailed contract list.
	var info_text: String = ""
	var player_uid: int = int(GameState.player_character_uid)
	if player_uid >= 0 and GameState.characters.has(player_uid):
		var pc = GameState.characters[player_uid]
		info_text += "Credits: %d" % pc.credits
		info_text += "    FP: %d" % pc.focus_points
	var active_occurrence_id: String = str(GameState.player_claimed_occurrence_id)
	if active_occurrence_id != "":
		if info_text != "":
			info_text += "\n"
		info_text += "Active Contract: %s" % active_occurrence_id

	if _service_status_message != "":
		if info_text != "":
			info_text += "\n"
		info_text += _service_status_message

	_refresh_contract_board()
	_refresh_contract_button_text()
	_label_info.text = info_text


func _refresh_contract_board() -> void:
	for child in _contract_list.get_children():
		child.queue_free()

	if GameState.player_docked_at == "":
		_station_list_label.text = "Stations: None"
		_add_contract_board_status_row("Dock sector unavailable.")
		return

	var dock_sector_id: String = _current_dock_sector_id()
	if dock_sector_id == "":
		_station_list_label.text = "Stations: None"
		_add_contract_board_status_row("Dock sector unavailable.")
		return

	_station_list_label.text = _station_listing_text(dock_sector_id)

	var entries: Array = _contracts_for_sector_source(dock_sector_id)
	if entries.empty():
		_add_contract_board_status_row("No contracts available at this dock.")
		return

	for occurrence in entries:
		_add_contract_board_row(occurrence)


func _add_contract_board_status_row(message: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ContractStatusRow"

	var label: Label = Label.new()
	label.name = "EntryLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap = true
	label.text = message
	row.add_child(label)

	_contract_list.add_child(row)


func _add_contract_board_row(occurrence: Dictionary) -> void:
	var occurrence_id: String = str(occurrence.get("occurrence_id", ""))
	var destination_sector_id: String = str(occurrence.get("target_sector_id", ""))
	var destination_label: String = _sector_display_name(destination_sector_id)
	var required_cargo_tag: String = str(occurrence.get("required_cargo_tag", "UNKNOWN_COMMODITY"))
	var reward_credits: int = int(occurrence.get("reward_credits", 0))
	var status_label: String = str(occurrence.get("status", "open"))
	var status_display: String = status_label.capitalize().replace("_", " ")

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ContractRow_%s" % occurrence_id.replace(":", "_")
	row.add_constant_override("separation", 12)

	var label: Label = Label.new()
	label.name = "EntryLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap = true
	label.text = _contract_entry_text(destination_label, required_cargo_tag, reward_credits, status_display, occurrence_id)
	row.add_child(label)

	var accept_button: Button = Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = "Accept"
	accept_button.rect_min_size = Vector2(90, 36)
	accept_button.disabled = not _can_accept_occurrence(occurrence)
	accept_button.connect("pressed", self, "_on_contract_row_accept_pressed", [occurrence_id])
	row.add_child(accept_button)

	_contract_list.add_child(row)


func _contract_entry_text(destination_label: String, required_cargo_tag: String, reward_credits: int, status_display: String, occurrence_id: String) -> String:
	return "Deliver to %s\nCargo: %s    Reward: %d credits    Status: %s\nRef: %s" % [
		destination_label,
		required_cargo_tag,
		reward_credits,
		status_display,
		occurrence_id,
	]


func _can_accept_occurrence(occurrence: Dictionary) -> bool:
	if str(GameState.player_claimed_occurrence_id) != "":
		return false
	var claimant_agent_id: String = str(occurrence.get("claimant_agent_id", ""))
	if claimant_agent_id != "" and claimant_agent_id != "player":
		return false
	return true


func _on_contract_row_accept_pressed(occurrence_id: String) -> void:
	_accept_contract_by_id(occurrence_id)


func _contracts_for_sector_source(sector_id: String) -> Array:
	var entries: Array = []
	if sector_id == "":
		return entries

	var occurrence_ids: Array = Array(GameState.runtime_contract_occurrences_by_source_sector.get(sector_id, []))
	occurrence_ids.sort()
	for occurrence_id in occurrence_ids:
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			continue
		if not bool(occurrence.get("player_displayable", true)):
			continue
		entries.append(occurrence)
	return entries


func _accept_selected_contract() -> void:
	if GameState.player_docked_at == "":
		visible = false
		_current_location_id = ""
		_service_status_message = ""
		_update_info_label()
		return

	if str(GameState.player_claimed_occurrence_id) != "":
		_service_status_message = "You already hold an active contract."
		_update_info_label()
		return

	var dock_sector_id: String = _current_dock_sector_id()
	var entries: Array = _contracts_for_sector_source(dock_sector_id)
	if entries.empty():
		_service_status_message = "No contracts available at this dock."
		_update_info_label()
		return

	var selected_occurrence: Dictionary = entries[0]
	var selected_occurrence_id: String = str(selected_occurrence.get("occurrence_id", ""))
	_accept_contract_by_id(selected_occurrence_id)


func _accept_contract_by_id(occurrence_id: String) -> void:
	var selected_occurrence_id: String = str(occurrence_id)
	if selected_occurrence_id == "":
		_service_status_message = "Selected contract is invalid."
		_update_info_label()
		return

	var selected_occurrence: Dictionary = GameState.runtime_contract_occurrences.get(selected_occurrence_id, {})
	if selected_occurrence.empty():
		_service_status_message = "Selected contract is no longer available."
		_update_info_label()
		return

	var dock_sector_id: String = _current_dock_sector_id()
	if str(selected_occurrence.get("source_sector_id", "")) != dock_sector_id:
		_service_status_message = "Selected contract is not offered at this dock."
		_update_info_label()
		return

	var claimant_agent_id: String = str(selected_occurrence.get("claimant_agent_id", ""))
	if claimant_agent_id != "" and claimant_agent_id != "player":
		_service_status_message = "Selected contract is no longer available."
		_update_info_label()
		return

	var required_cargo_tag: String = str(selected_occurrence.get("required_cargo_tag", "UNKNOWN_COMMODITY"))
	GameState.player_claimed_occurrence_id = selected_occurrence_id
	GameState.player_cargo_tag = "LOADED"
	if GameState.agents.has("player"):
		var player_agent: Dictionary = GameState.agents.get("player", {})
		if not player_agent.empty():
			player_agent["cargo_tag"] = "LOADED"
			player_agent["contract_cargo_tag"] = required_cargo_tag
			GameState.agents["player"] = player_agent

	selected_occurrence["claimant_agent_id"] = "player"
	selected_occurrence["status"] = "in_transit"
	selected_occurrence["claimed_at_tick"] = GameState.sim_tick_count
	selected_occurrence["last_refreshed_tick"] = GameState.sim_tick_count
	GameState.runtime_contract_occurrences[selected_occurrence_id] = selected_occurrence

	_service_status_message = "Accepted contract %s. Cargo tag: %s." % [selected_occurrence_id, required_cargo_tag]
	_update_info_label()


func _refresh_contract_button_text() -> void:
	if str(GameState.player_claimed_occurrence_id) != "":
		_btn_contracts.text = "Contract Active"
		_btn_contracts.disabled = true
		return

	var dock_sector_id: String = _current_dock_sector_id()
	var entries: Array = _contracts_for_sector_source(dock_sector_id)
	_btn_contracts.text = "Accept Contract"
	_btn_contracts.disabled = entries.empty()


func _current_dock_sector_id() -> String:
	# Dock location ids can differ from sector ids; prefer explicit scene/agent sector state.
	if str(GameState.current_sector_id) != "":
		return str(GameState.current_sector_id)
	if GameState.agents.has("player"):
		var player_agent: Dictionary = GameState.agents.get("player", {})
		if not player_agent.empty() and str(player_agent.get("current_sector_id", "")) != "":
			return str(player_agent.get("current_sector_id", ""))
	return str(_current_location_id)


func _sector_display_name(sector_id: String) -> String:
	if sector_id == "":
		return "Unknown"
	return str(GameState.sector_names.get(sector_id, sector_id))


func _station_listing_text(sector_id: String) -> String:
	if sector_id == "":
		return "Stations: None"

	var topology_record: Dictionary = GameState.world_topology.get(sector_id, {})
	var station_ids: Array = Array(topology_record.get("station_ids", []))
	if station_ids.empty():
		return "Stations: None"

	var station_names: Array = []
	for station_id in station_ids:
		var station_label: String = _station_display_name(str(station_id))
		if station_label != "":
			station_names.append(station_label)

	if station_names.empty():
		return "Stations: None"
	return "Stations: %s" % ", ".join(station_names)


func _station_display_name(station_id: String) -> String:
	if station_id == "":
		return ""
	if GameState.station_by_id.has(station_id):
		var station_record: Dictionary = GameState.station_by_id.get(station_id, {})
		var station_name: String = str(station_record.get("display_name", ""))
		if station_name != "":
			return station_name
	if GameState.locations.has(station_id):
		var location_record = GameState.locations[station_id]
		if location_record is Dictionary and str(location_record.get("location_name", "")) != "":
			return str(location_record.get("location_name", ""))
		if location_record is Object and "location_name" in location_record and str(location_record.location_name) != "":
			return str(location_record.location_name)
	return station_id


# =============================================================================
# === CLEANUP =================================================================
# =============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if EventBus and EventBus.is_connected("player_docked", self, "_on_player_docked"):
			EventBus.disconnect("player_docked", self, "_on_player_docked")
		if EventBus and EventBus.is_connected("player_undocked", self, "_on_player_undocked"):
			EventBus.disconnect("player_undocked", self, "_on_player_undocked")
