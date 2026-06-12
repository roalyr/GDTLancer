#
# PROJECT: GDTLancer
# MODULE: npc_trade_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_009
# LOG_REF: 2026-06-12 01:00:00
#

extends Control

onready var label_npc_name: Label = $Panel/VBoxContainer/HeaderRow/LabelNpcName
onready var label_npc_cargo: Label = $Panel/VBoxContainer/SectionNpcSide/LabelNpcCargo
onready var label_npc_credits: Label = $Panel/VBoxContainer/SectionNpcSide/LabelNpcCredits
onready var label_player_cargo: Label = $Panel/VBoxContainer/SectionPlayerSide/LabelPlayerCargo
onready var label_player_credits: Label = $Panel/VBoxContainer/SectionPlayerSide/LabelPlayerCredits

onready var label_payment_instrument: Label = $Panel/VBoxContainer/LabelPaymentInstrument
onready var label_trade_price: Label = $Panel/VBoxContainer/LabelTradePrice
onready var btn_buy_cargo: Button = $Panel/VBoxContainer/HBoxButtons/BtnBuyCargo
onready var btn_sell_cargo: Button = $Panel/VBoxContainer/HBoxButtons/BtnSellCargo

var _current_agent_id: String = ""
var _current_target: Spatial = null

var _payment_instrument: String = "specie"
var _trade_price: int = 0
var _npc_commodity_id: String = ""
var _player_commodity_id: String = ""
var _npc_char_uid: int = -1

func _ready() -> void:
	visible = false
	# Note: This panel is no longer self-triggered via EventBus.
	# It is opened exclusively via open_for_agent() called by InteractionWindow.


# --- Public API ---

func open_for_agent(agent_id: String, target_node: Spatial) -> void:
	_current_agent_id = agent_id
	_current_target = target_node
	_refresh_ui()
	visible = true

func _on_BtnClose_pressed() -> void:
	visible = false

func _process(_delta: float) -> void:
	if visible and not is_instance_valid(_current_target):
		visible = false

func _refresh_ui() -> void:
	if not GameState.agents.has(_current_agent_id):
		return
	
	var agent_state = GameState.agents[_current_agent_id]
	# character_uid lives in persistent_agents, not in the agents simulation dict.
	var char_uid_raw = -1
	if GameState.persistent_agents.has(_current_agent_id):
		char_uid_raw = GameState.persistent_agents[_current_agent_id].get("character_uid", -1)
	_npc_char_uid = int(char_uid_raw) if char_uid_raw != -1 else -1
	var role = agent_state.get("agent_role", "unknown")
	var char_name = "NPC"
	
	if _npc_char_uid != -1 and GameState.characters.has(_npc_char_uid):
		var cd = GameState.characters[_npc_char_uid]
		if cd is Resource:
			char_name = str(cd.character_name)
		elif cd is Dictionary:
			char_name = str(cd.get("character_name", "NPC"))
		
	label_npc_name.text = char_name + " — " + role.capitalize()
	
	var npc_credits = 0
	_npc_commodity_id = agent_state.get("cargo_commodity_id", "")
	var npc_cargo_text = "Cargo: Empty"
	if _npc_commodity_id != "":
		npc_cargo_text = "Cargo: " + _npc_commodity_id + " x1"
	
	var char_sys = GlobalRefs.character_system
	var inv_sys = GlobalRefs.inventory_system
	var player_uid = int(GameState.player_character_uid)
	
	if _npc_char_uid != -1 and is_instance_valid(char_sys):
		npc_credits = char_sys.get_credits(_npc_char_uid)
		
	label_npc_cargo.text = npc_cargo_text
	label_npc_credits.text = "Credits: %d cr" % npc_credits
	
	var player_credits = 0
	if is_instance_valid(char_sys):
		player_credits = char_sys.get_credits(player_uid)
	label_player_credits.text = "Your Credits: %d cr" % player_credits
	
	_player_commodity_id = ""
	if is_instance_valid(inv_sys):
		var player_inv = inv_sys.get_inventory_by_type(player_uid, 2)
		for comm_id in player_inv.keys():
			if comm_id != "commodity_specie":
				_player_commodity_id = comm_id
				break
	
	if _player_commodity_id != "":
		label_player_cargo.text = "Your Cargo: " + _player_commodity_id + " x1"
	else:
		label_player_cargo.text = "Your Cargo: Empty"
		
	# Simulation agents use "dynamic_tags" not "tags".
	var player_tags = GameState.agents.get("player", {}).get("dynamic_tags", [])
	var npc_tags = agent_state.get("dynamic_tags", [])
	
	_payment_instrument = "specie"
	if GlobalRefs.simulation_engine and GlobalRefs.simulation_engine.agent_layer:
		_payment_instrument = GlobalRefs.simulation_engine.agent_layer._resolve_payment_instrument(player_tags, npc_tags)
		
	_trade_price = 0
	var price_commodity = _npc_commodity_id if _npc_commodity_id != "" else _player_commodity_id
	if price_commodity != "":
		if TemplateDatabase.assets_commodities.has(price_commodity):
			var t = TemplateDatabase.assets_commodities[price_commodity]
			if t and "base_value" in t:
				_trade_price = t.base_value
		else:
			_trade_price = 10
			
	var price_display = str(_trade_price) + " cr" if _payment_instrument == "credits" else "1 specie"
	label_payment_instrument.text = "Payment: " + _payment_instrument.capitalize()
	label_trade_price.text = "Price: ~" + price_display
	
	btn_buy_cargo.disabled = (_npc_commodity_id == "")
	btn_sell_cargo.disabled = (_player_commodity_id == "" or _npc_commodity_id != "")


func _on_BtnBuyCargo_pressed() -> void:
	if _npc_commodity_id == "": return
	
	var player_uid = int(GameState.player_character_uid)
	var char_sys = GlobalRefs.character_system
	var inv_sys = GlobalRefs.inventory_system
	if not is_instance_valid(char_sys) or not is_instance_valid(inv_sys): return
	
	if _payment_instrument == "credits":
		var p_creds = char_sys.get_credits(player_uid)
		if p_creds < _trade_price:
			EventBus.emit_signal("interact_action_feedback", false, "Insufficient credits.")
			return
		char_sys.subtract_credits(player_uid, _trade_price)
		if _npc_char_uid != -1:
			char_sys.add_credits(_npc_char_uid, _trade_price)
	else:
		var p_spec = inv_sys.get_asset_count(player_uid, 2, "commodity_specie")
		if p_spec < 1:
			EventBus.emit_signal("interact_action_feedback", false, "Insufficient specie.")
			return
		inv_sys.remove_asset(player_uid, 2, "commodity_specie", 1)
		if _npc_char_uid != -1:
			inv_sys.add_asset(_npc_char_uid, 2, "commodity_specie", 1)
			
	inv_sys.add_asset(player_uid, 2, _npc_commodity_id, 1)
	if _npc_char_uid != -1:
		inv_sys.remove_asset(_npc_char_uid, 2, _npc_commodity_id, 1)
		
	GameState.pending_sim_mutations.append({
		"type": "player_npc_trade",
		"agent_id": _current_agent_id,
		"new_cargo_tag": "EMPTY",
		"new_cargo_commodity_id": "",
		"wealth_delta": 1,
		"tick_logged": GameState.sim_tick_count
	})
	
	EventBus.emit_signal("interact_action_feedback", true, "Bought " + _npc_commodity_id + ".")
	_refresh_ui()


func _on_BtnSellCargo_pressed() -> void:
	if _player_commodity_id == "": return
	
	var player_uid = int(GameState.player_character_uid)
	var char_sys = GlobalRefs.character_system
	var inv_sys = GlobalRefs.inventory_system
	if not is_instance_valid(char_sys) or not is_instance_valid(inv_sys): return
	
	if _payment_instrument == "credits":
		var npc_creds = char_sys.get_credits(_npc_char_uid) if _npc_char_uid != -1 else 0
		if npc_creds < _trade_price and _npc_char_uid != -1:
			EventBus.emit_signal("interact_action_feedback", false, "NPC cannot afford this.")
			return
		if _npc_char_uid != -1:
			char_sys.subtract_credits(_npc_char_uid, _trade_price)
		char_sys.add_credits(player_uid, _trade_price)
	else:
		var npc_spec = inv_sys.get_asset_count(_npc_char_uid, 2, "commodity_specie") if _npc_char_uid != -1 else 0
		if npc_spec < 1 and _npc_char_uid != -1:
			EventBus.emit_signal("interact_action_feedback", false, "NPC has no specie.")
			return
		if _npc_char_uid != -1:
			inv_sys.remove_asset(_npc_char_uid, 2, "commodity_specie", 1)
		inv_sys.add_asset(player_uid, 2, "commodity_specie", 1)
		
	inv_sys.remove_asset(player_uid, 2, _player_commodity_id, 1)
	if _npc_char_uid != -1:
		inv_sys.add_asset(_npc_char_uid, 2, _player_commodity_id, 1)
		
	GameState.pending_sim_mutations.append({
		"type": "player_npc_trade",
		"agent_id": _current_agent_id,
		"new_cargo_tag": "LOADED",
		"new_cargo_commodity_id": _player_commodity_id,
		"wealth_delta": -1,
		"tick_logged": GameState.sim_tick_count
	})
	
	EventBus.emit_signal("interact_action_feedback", true, "Sold " + _player_commodity_id + ".")
	_refresh_ui()
