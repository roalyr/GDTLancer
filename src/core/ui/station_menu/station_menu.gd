#
# PROJECT: GDTLancer
# MODULE: station_menu.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
# LOG_REF: 2026-06-04 11:28:00
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

onready var _market_section: VBoxContainer = $Panel/VBoxContainer/MarketSection
onready var _label_market_header: Label = $Panel/VBoxContainer/MarketSection/LabelMarketHeader
onready var _market_list: VBoxContainer = $Panel/VBoxContainer/MarketSection/ScrollContainer/MarketList


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
	if is_instance_valid(_market_section):
		_market_section.visible = false
	_update_info_label()
	visible = true
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("StationMenu: Opened for location '", location_id, "'")


func _on_player_undocked() -> void:
	visible = false
	_current_location_id = ""
	_service_status_message = ""
	if is_instance_valid(_market_section):
		_market_section.visible = false
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("StationMenu: Closed")


func open_for_current_dock() -> void:
	if GameState.player_docked_at == "":
		visible = false
		_current_location_id = ""
		_service_status_message = ""
		if is_instance_valid(_market_section):
			_market_section.visible = false
		_update_info_label()
		return
	_current_location_id = GameState.player_docked_at
	_service_status_message = ""
	_update_station_label(_current_location_id)
	if is_instance_valid(_market_section):
		_market_section.visible = false
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
	var has_lawful = _location_offers_service(_current_location_id, "trade")
	var has_black = _location_offers_service(_current_location_id, "black_market")
	if not has_lawful and not has_black:
		_show_deferred_service_feedback(
			"Trade",
			"trade",
			"Trade is not offered at this dock."
		)
		if is_instance_valid(_market_section):
			_market_section.visible = false
		return

	if is_instance_valid(_market_section):
		_market_section.visible = not _market_section.visible
		if _market_section.visible:
			_service_status_message = ""
			_update_market_ui()
		else:
			_service_status_message = ""
		_update_info_label()


func _on_contracts_pressed() -> void:
	_open_contract_board()


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
	var lines: Array = []
	var dock_sector_id: String = _current_dock_sector_id()
	if dock_sector_id != "":
		lines.append("Current Sector: %s" % _sector_display_name(dock_sector_id))
	lines.append("Contracts are handled from the global Contract Board.")

	var player_uid: int = int(GameState.player_character_uid)
	if player_uid >= 0 and GameState.characters.has(player_uid):
		var pc = GameState.characters[player_uid]
		lines.append("Credits: %d    FP: %d" % [pc.credits, pc.focus_points])
	var active_occurrence_id: String = str(GameState.player_claimed_occurrence_id)
	if active_occurrence_id != "":
		lines.append("Active Contract: %s" % active_occurrence_id)

	if _service_status_message != "":
		lines.append(_service_status_message)

	_refresh_contract_button_text()
	_update_trade_button_text()
	_label_info.text = "\n".join(lines)


func _update_trade_button_text() -> void:
	var has_lawful = _location_offers_service(_current_location_id, "trade")
	var has_black = _location_offers_service(_current_location_id, "black_market")
	if has_black and not has_lawful:
		_btn_trade.text = "Access Black Market"
	else:
		_btn_trade.text = "Trade"


func _refresh_contract_button_text() -> void:
	_btn_contracts.text = "Open Contract Board"
	_btn_contracts.disabled = false


func _open_contract_board() -> void:
	var contract_board = _find_contract_board()
	if not is_instance_valid(contract_board):
		_service_status_message = "Contract Board is unavailable."
		_update_info_label()
		return

	if contract_board.has_method("show_board"):
		contract_board.call("show_board")
		_service_status_message = "Opened the global Contract Board."
	else:
		_service_status_message = "Contract Board is unavailable."
	_update_info_label()


func _find_contract_board() -> Node:
	var scene_root = get_tree().current_scene
	if is_instance_valid(scene_root):
		var scene_board = scene_root.find_node("ContractBoard", true, false)
		if is_instance_valid(scene_board):
			return scene_board

	var ancestor_root: Node = self
	while is_instance_valid(ancestor_root.get_parent()):
		ancestor_root = ancestor_root.get_parent()
	if is_instance_valid(ancestor_root):
		var ancestor_board = ancestor_root.find_node("ContractBoard", true, false)
		if is_instance_valid(ancestor_board):
			return ancestor_board

	var tree_root = get_tree().root
	if is_instance_valid(tree_root):
		var tree_board = tree_root.find_node("ContractBoard", true, false)
		if is_instance_valid(tree_board):
			return tree_board

	return null


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


func _update_market_ui() -> void:
	for child in _market_list.get_children():
		child.queue_free()
		_market_list.remove_child(child)

	if _current_location_id == "" or not GameState.locations.has(_current_location_id):
		return

	var location_record = GameState.locations[_current_location_id]
	var market_inv = {}
	if location_record is Dictionary:
		market_inv = location_record.get("market_inventory", {})
	elif location_record is Object and "market_inventory" in location_record:
		market_inv = location_record.market_inventory

	var has_lawful = _location_offers_service(_current_location_id, "trade")
	var has_black = _location_offers_service(_current_location_id, "black_market")

	var title = "Market (Lawful)"
	if has_black:
		if not has_lawful:
			title = "Black Market (Illicit)"
		else:
			title = "Market & Black Market"
	_label_market_header.text = title

	var player_uid = int(GameState.player_character_uid)
	var char_sys = GlobalRefs.character_system
	var inv_sys = GlobalRefs.inventory_system

	var player_credits = 0
	if is_instance_valid(char_sys):
		player_credits = char_sys.get_credits(player_uid)

	var commodity_ids = market_inv.keys()
	commodity_ids.sort()

	for comm_id in commodity_ids:
		var data = market_inv[comm_id]
		var buy_price = int(data.get("buy_price", 0))
		var sell_price = int(data.get("sell_price", 0))
		var qty = int(data.get("quantity", 0))

		var player_qty = 0
		if is_instance_valid(inv_sys):
			player_qty = inv_sys.get_asset_count(player_uid, 2, comm_id) # 2 = COMMODITY

		var comm_name = comm_id
		var comm_res = TemplateDatabase.get_template(comm_id)
		if comm_res and "commodity_name" in comm_res:
			comm_name = comm_res.commodity_name

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_constant_override("separation", 12)

		var label_name = Label.new()
		label_name.text = comm_name
		label_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label_name)

		var label_qty = Label.new()
		label_qty.text = "Qty: %d" % qty
		label_qty.rect_min_size = Vector2(80, 0)
		row.add_child(label_qty)

		var label_prices = Label.new()
		label_prices.text = "Buy: %d cr | Sell: %d cr" % [buy_price, sell_price]
		label_prices.rect_min_size = Vector2(200, 0)
		row.add_child(label_prices)

		var label_player = Label.new()
		label_player.text = "Carried: %d" % player_qty
		label_player.rect_min_size = Vector2(100, 0)
		row.add_child(label_player)

		var btn_buy = Button.new()
		btn_buy.text = "Buy"
		btn_buy.rect_min_size = Vector2(60, 30)
		btn_buy.disabled = (qty <= 0) or (player_credits < buy_price)
		btn_buy.connect("pressed", self, "_on_buy_pressed", [comm_id, buy_price])
		row.add_child(btn_buy)

		var btn_sell = Button.new()
		btn_sell.text = "Sell"
		btn_sell.rect_min_size = Vector2(60, 30)
		btn_sell.disabled = (player_qty <= 0)
		btn_sell.connect("pressed", self, "_on_sell_pressed", [comm_id, sell_price])
		row.add_child(btn_sell)

		_market_list.add_child(row)


# NOTE: NPC dock-trade buy/sell mutations are not shared with this class because:
# 1. This class is part of the player UI, whereas NPC transactions are pure simulation backend in agent_layer.gd.
# 2. Player transactions mutate numeric character credits and actual inventory assets via GlobalRefs.
# 3. NPC transactions mutate qualitative wealth_tags (e.g. step_down) and cargo_tags (e.g. LOADED) rather than numeric values.
# 4. The only shared data mutation is the direct symmetric adjustment of market_inventory quantity, which is kept inline for simplicity.
func _on_buy_pressed(commodity_id: String, price: int) -> void:
	var player_uid = int(GameState.player_character_uid)
	var char_sys = GlobalRefs.character_system
	var inv_sys = GlobalRefs.inventory_system

	if is_instance_valid(char_sys) and is_instance_valid(inv_sys):
		char_sys.subtract_credits(player_uid, price)
		inv_sys.add_asset(player_uid, 2, commodity_id, 1)

		var location_record = GameState.locations.get(_current_location_id, null)
		if location_record:
			if location_record is Dictionary:
				location_record.market_inventory[commodity_id].quantity -= 1
			elif location_record is Object:
				location_record.market_inventory[commodity_id].quantity -= 1

		_update_market_ui()
		_update_info_label()


func _on_sell_pressed(commodity_id: String, price: int) -> void:
	var player_uid = int(GameState.player_character_uid)
	var char_sys = GlobalRefs.character_system
	var inv_sys = GlobalRefs.inventory_system

	if is_instance_valid(char_sys) and is_instance_valid(inv_sys):
		var player_qty = inv_sys.get_asset_count(player_uid, 2, commodity_id)
		if player_qty > 0:
			char_sys.add_credits(player_uid, price)
			inv_sys.remove_asset(player_uid, 2, commodity_id, 1)

			var location_record = GameState.locations.get(_current_location_id, null)
			if location_record:
				if location_record is Dictionary:
					location_record.market_inventory[commodity_id].quantity += 1
				elif location_record is Object:
					location_record.market_inventory[commodity_id].quantity += 1

			_update_market_ui()
			_update_info_label()


# =============================================================================
# === CLEANUP =================================================================
# =============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if EventBus and EventBus.is_connected("player_docked", self, "_on_player_docked"):
			EventBus.disconnect("player_docked", self, "_on_player_docked")
		if EventBus and EventBus.is_connected("player_undocked", self, "_on_player_undocked"):
			EventBus.disconnect("player_undocked", self, "_on_player_undocked")
