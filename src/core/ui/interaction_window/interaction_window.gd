# PROJECT: GDTLancer
# MODULE: interaction_window.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-MASTER-DESIGN-DIRECTIVE.md §2.2, §7.4; TRUTH_GAME-LOOP-VISION.md §5.2
# LOG_REF: 2026-06-20 20:31:00

extends Control

signal closed

# --- Internal State ---
var _current_agent_id: String = ""
var _current_target = null

# --- Node References (resolved in _ready) ---
var _label_target_name: Label = null
var _label_context_info: Label = null
var _btn_trigger_action: Button = null
var _action_tray: Control = null

func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	visible = false
	_label_target_name = get_node_or_null("Panel/VBoxContainer/HeaderRow/LabelTargetName")
	_label_context_info = get_node_or_null("Panel/VBoxContainer/TabContainer/Chronicle Log/LabelContextInfo")
	_btn_trigger_action = get_node_or_null("Panel/VBoxContainer/TabContainer/Chronicle Log/BtnTriggerAction")
	_action_tray = get_node_or_null("ActionTray")
	
	if is_instance_valid(_btn_trigger_action) and not _btn_trigger_action.is_connected("pressed", self, "_on_BtnTriggerAction_pressed"):
		_btn_trigger_action.connect("pressed", self, "_on_BtnTriggerAction_pressed")
		
	if is_instance_valid(_action_tray) and not _action_tray.is_connected("action_resolved", self, "_on_action_resolved"):
		_action_tray.connect("action_resolved", self, "_on_action_resolved")


# --- Public API ---

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
	emit_signal("closed")


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

	var sector_id = GameState.current_sector_id
	var title = display_name + " — " + role.capitalize()
	var body = "This agent is present in the sector."
	
	if is_instance_valid(GlobalRefs.simulation_engine):
		var chronicle = GlobalRefs.simulation_engine.get_chronicle()
		if chronicle != null and chronicle.has_method("resolve_narrative_template"):
			var template = chronicle.resolve_narrative_template(sector_id, "ambient")
			if template != null:
				title = display_name + " (" + template.get("title") + ")"
				body = template.get("body_text")

	if is_instance_valid(_label_target_name):
		_label_target_name.text = title

	if is_instance_valid(_label_context_info):
		_label_context_info.text = body

	_update_trigger_button()




func _populate_for_celestial(target_name: String) -> void:
	var sector_id = GameState.current_sector_id
	var title = target_name
	var body = "No interactions available yet."
	
	if is_instance_valid(GlobalRefs.simulation_engine):
		var chronicle = GlobalRefs.simulation_engine.get_chronicle()
		if chronicle != null and chronicle.has_method("resolve_narrative_template"):
			var template = chronicle.resolve_narrative_template(sector_id, "ambient")
			if template != null:
				title = target_name + " — " + template.get("title")
				body = template.get("body_text")

	if is_instance_valid(_label_target_name):
		_label_target_name.text = title

	if is_instance_valid(_label_context_info):
		_label_context_info.text = body

	_update_trigger_button()




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


# --- Button Handlers ---

func _on_BtnClose_pressed() -> void:
	close()

func _update_trigger_button() -> void:
	if is_instance_valid(_btn_trigger_action):
		if GameState.agents.has("player") and GameState.agents["player"].get("is_mutiny_active", false):
			_btn_trigger_action.text = "Resolve Mutiny"
		else:
			_btn_trigger_action.text = "Take Action"

func _on_BtnTriggerAction_pressed() -> void:
	if is_instance_valid(_action_tray):
		var wealth_mod = 0
		var health_mod = 0
		var morale_mod = 0
		if GameState.agents.has("player"):
			var p_state = GameState.agents["player"]
			var w_tier = p_state.get("wealth_tier", 0)
			if "WEALTH_MODIFIERS" in Constants and Constants.WEALTH_MODIFIERS.has(w_tier):
				wealth_mod = Constants.WEALTH_MODIFIERS[w_tier]
			var h_tag = p_state.get("condition_tag", "NOMINAL")
			if "CONDITION_MODIFIERS" in Constants and Constants.CONDITION_MODIFIERS.has(h_tag):
				health_mod = Constants.CONDITION_MODIFIERS[h_tag]
				
		if is_instance_valid(GlobalRefs.simulation_engine) and GlobalRefs.simulation_engine.has_node("AgentLayer"):
			morale_mod = GlobalRefs.simulation_engine.get_node("AgentLayer").get_crew_morale_modifier("player")
			
		_action_tray.open_tray(wealth_mod, health_mod, morale_mod)

func _on_action_resolved(result: Dictionary) -> void:
	# result is from CoreMechanicsAPI, e.g. {"success": true, "result_tier": "Success", ...}
	var success = result.get("success", false)
	var tier = result.get("result_tier", "Failure")
	
	if GameState.agents.has("player") and GameState.agents["player"].get("is_mutiny_active", false):
		if tier in ["Success", "CritSuccess"]:
			# Resolve Mutiny
			GameState.agents["player"]["is_mutiny_active"] = false
			# Restore morale to baseline
			var state = GameState.agents["player"]
			if state.has("sub_agents"):
				for sub_id in state["sub_agents"]:
					if state["sub_agents"][sub_id].has("morale"):
						state["sub_agents"][sub_id]["morale"] = max(30.0, state["sub_agents"][sub_id]["morale"])
			
			if is_instance_valid(_label_target_name):
				_label_target_name.text = "Mutiny Averted"
			if is_instance_valid(_label_context_info):
				_label_context_info.text = "The crew has backed down and returned to their posts. Morale stabilized."
		else:
			if is_instance_valid(_label_target_name):
				_label_target_name.text = "Mutiny Escalates"
			if is_instance_valid(_label_context_info):
				_label_context_info.text = "The crew is unsatisfied. Mutiny continues..."
	else:
		# Standard action resolution
		if tier in ["Success", "CritSuccess"]:
			if is_instance_valid(_label_target_name):
				_label_target_name.text = "Action Succeeded"
			if is_instance_valid(_label_context_info):
				_label_context_info.text = "You handled the situation gracefully. Gained valuable insights."
		elif tier == "SuccessWithComplication":
			if is_instance_valid(_label_target_name):
				_label_target_name.text = "Complication Arose"
			if is_instance_valid(_label_context_info):
				_label_context_info.text = "You succeeded, but at a cost. The crew is stressed."
		else:
			if is_instance_valid(_label_target_name):
				_label_target_name.text = "Action Failed"
			if is_instance_valid(_label_context_info):
				_label_context_info.text = "The situation worsened. You suffered setbacks."
				
	_update_trigger_button()
