# PROJECT: GDTLancer
# MODULE: npc_trade_panel.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
# LOG_REF: 2026-06-14 01:00:09

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
	# NOTE: GDD REVISION - Standalone trading is deprecated/dropped in favor of unified contracts.
	# The trade panel remains permanently hidden.
	_current_agent_id = agent_id
	_current_target = target_node
	visible = false

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
	
	var npc_progress = 0
	var npc_tier = "BROKE"
	_npc_commodity_id = agent_state.get("cargo_commodity_id", "")
	var npc_cargo_text = "Cargo: Empty"
	if _npc_commodity_id != "":
		npc_cargo_text = "Cargo: " + _npc_commodity_id + " x1"
	
	var char_sys = GlobalRefs.character_system
	var inv_sys = GlobalRefs.inventory_system
	var player_uid = int(GameState.player_character_uid)
	
	if _npc_char_uid != -1 and is_instance_valid(char_sys):
		npc_progress = char_sys.get_wealth_progress(_npc_char_uid)
		npc_tier = char_sys.get_wealth_tier(_npc_char_uid)
		
	label_npc_cargo.text = npc_cargo_text
	label_npc_credits.text = "Wealth: " + str(npc_tier) + " (" + str(npc_progress) + "/10)"
	
	var player_progress = 0
	var player_tier = "COMFORTABLE"
	if is_instance_valid(char_sys):
		player_progress = char_sys.get_wealth_progress(player_uid)
		player_tier = char_sys.get_wealth_tier(player_uid)
	label_player_credits.text = "Your Wealth: " + str(player_tier) + " (" + str(player_progress) + "/10)"
	
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
			
	var price_display = str(_trade_price) + " progress" if _payment_instrument == "credits" else "1 specie"
	label_payment_instrument.text = "Payment: " + _payment_instrument.capitalize()
	label_trade_price.text = "Price: ~" + price_display
	
	btn_buy_cargo.disabled = (_npc_commodity_id == "")
	btn_sell_cargo.disabled = (_player_commodity_id == "" or _npc_commodity_id != "")


func _on_BtnBuyCargo_pressed() -> void:
	# NOTE: GDD REVISION - Standalone trading is deprecated/dropped.
	pass


func _on_BtnSellCargo_pressed() -> void:
	# NOTE: GDD REVISION - Standalone trading is deprecated/dropped.
	pass