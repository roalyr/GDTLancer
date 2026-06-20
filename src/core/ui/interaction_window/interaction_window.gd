# PROJECT: GDTLancer
# MODULE: interaction_window.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: interaction_window.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; GDD-REVISION-LEDGER.md REV_009
# LOG_REF: 2026-06-12 01:00:00
#

extends Control

# --- Internal State ---
var _current_agent_id: String = ""
var _current_target = null
var _npc_trade_panel_ref = null

# --- Node References (resolved in _ready) ---
var _label_target_name: Label = null
var _label_context_info: Label = null
var _btn_trade: Button = null
var _action_buttons: Control = null


func _ready() -> void:
	visible = false
	_label_target_name = get_node_or_null("Panel/VBoxContainer/HeaderRow/LabelTargetName")
	_label_context_info = get_node_or_null("Panel/VBoxContainer/LabelContextInfo")
	_btn_trade = get_node_or_null("Panel/VBoxContainer/ActionButtons/BtnTrade")
	_action_buttons = get_node_or_null("Panel/VBoxContainer/ActionButtons")


# --- Public API ---

func set_npc_trade_panel_ref(panel: Control) -> void:
	_npc_trade_panel_ref = panel


func open_for_target(agent_id: String, target_node: Spatial) -> void:
	_current_target = target_node
	# Celestial bodies are sent through the same signal with a "__celestial__" prefix.
	if agent_id.begins_with("__celestial__"):
		_current_agent_id = ""
		var body_name: String = agent_id.substr(len("__celestial__"))
		_populate_for_celestial(body_name)
		visible = true
		return
	_current_agent_id = agent_id
	_populate_for_npc(agent_id)
	visible = true



func open_for_celestial(target_name: String) -> void:
	_current_agent_id = ""
	_current_target = null
	_populate_for_celestial(target_name)
	visible = true


func close() -> void:
	visible = false
	_current_agent_id = ""
	_current_target = null


# --- Internal Population ---

func _populate_for_npc(agent_id: String) -> void:
	var display_name := "Unknown"
	var role := "unknown"

	if GameState.agents.has(agent_id):
		var agent_state: Dictionary = GameState.agents[agent_id]
		role = str(agent_state.get("agent_role", "unknown"))

		# Resolve character name via persistent_agents -> characters
		var char_name := _resolve_npc_name(agent_id)
		display_name = char_name

	if is_instance_valid(_label_target_name):
		_label_target_name.text = display_name + " — " + role.capitalize()

	var is_tradeable := _is_agent_tradeable(agent_id)
	if is_instance_valid(_label_context_info):
		if is_tradeable:
			_label_context_info.text = "This agent is available for trade."
		else:
			_label_context_info.text = "This agent is not interested in trade."

	if is_instance_valid(_btn_trade):
		_btn_trade.disabled = not is_tradeable

	if is_instance_valid(_action_buttons):
		_action_buttons.visible = true


func _populate_for_celestial(target_name: String) -> void:
	if is_instance_valid(_label_target_name):
		_label_target_name.text = target_name

	if is_instance_valid(_label_context_info):
		_label_context_info.text = "No interactions available yet."

	if is_instance_valid(_action_buttons):
		_action_buttons.visible = false


# --- Helpers ---

func _resolve_npc_name(agent_id: String) -> String:
	# Persistent agents store character_uid in GameState.persistent_agents
	if GameState.persistent_agents.has(agent_id):
		var p_state: Dictionary = GameState.persistent_agents[agent_id]
		var char_uid = p_state.get("character_uid", -1)
		if char_uid != -1 and GameState.characters.has(char_uid):
			var char_data = GameState.characters[char_uid]
			if char_data is Resource and char_data.get("character_name"):
				return str(char_data.character_name)
			elif char_data is Dictionary:
				return str(char_data.get("character_name", agent_id))
	# Fallback: non-persistent agents may store character data directly
	if GameState.characters.has(agent_id):
		var char_data = GameState.characters[agent_id]
		if char_data is Dictionary:
			return str(char_data.get("character_name", agent_id))
	return agent_id


func _is_agent_tradeable(agent_id: String) -> bool:
	if not GameState.agents.has(agent_id):
		return false
	var role: String = str(GameState.agents[agent_id].get("agent_role", ""))
	return role in ["trader", "hauler", "prospector"]


# --- Button Handlers ---

func _on_BtnTrade_pressed() -> void:
	if not _is_agent_tradeable(_current_agent_id):
		if EventBus:
			EventBus.emit_signal(
				"interact_action_feedback", false, "This agent is not interested in trade."
			)
		return

	if is_instance_valid(_npc_trade_panel_ref) and _npc_trade_panel_ref.has_method("open_for_agent"):
		_npc_trade_panel_ref.open_for_agent(_current_agent_id, _current_target)
		close()
	else:
		if EventBus:
			EventBus.emit_signal(
				"interact_action_feedback", false, "Trade panel unavailable."
			)


func _on_BtnClose_pressed() -> void:
	close()


# --- Process ---

func _process(_delta: float) -> void:
	if visible and _current_target != null and not is_instance_valid(_current_target):
		close()