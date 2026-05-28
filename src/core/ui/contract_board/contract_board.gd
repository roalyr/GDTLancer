#
# PROJECT: GDTLancer
# MODULE: contract_board.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_PROJECT.md § Agent Parity Principle; TRUTH_SIMULATION-GRAPH.md §3.3, §3.4, §6.3; TACTICAL_TODO.md TASK_3
# LOG_REF: 2026-05-27 18:18:00
#

extends CanvasLayer

onready var _panel: Panel = $Panel
onready var _summary_label: Label = $Panel/VBoxContainer/SummaryLabel
onready var _contract_list: VBoxContainer = $Panel/VBoxContainer/ContractScroll/ContractList
onready var _btn_close: BaseButton = $Panel/VBoxContainer/HeaderRow/BtnClose

var _visible: bool = false
var _feedback_message: String = ""


func _ready() -> void:
	layer = 100
	pause_mode = Node.PAUSE_MODE_PROCESS
	_panel.visible = false
	if not _btn_close.is_connected("pressed", self, "_on_close_pressed"):
		_btn_close.connect("pressed", self, "_on_close_pressed")
	if not EventBus.is_connected("sim_tick_completed", self, "_on_sim_tick_completed"):
		EventBus.connect("sim_tick_completed", self, "_on_sim_tick_completed")
	call_deferred("_refresh")


func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_refresh()


func show_board() -> void:
	_visible = true
	_panel.visible = true
	_refresh()


func _on_close_pressed() -> void:
	_visible = false
	_panel.visible = false


func _on_sim_tick_completed(_tick_count: int = 0) -> void:
	if _visible:
		_refresh()


func _refresh() -> void:
	if not is_instance_valid(_summary_label) or not is_instance_valid(_contract_list):
		return

	for child in _contract_list.get_children():
		child.queue_free()

	_summary_label.text = _build_summary_text()

	var entries: Array = _visible_occurrences()
	if entries.empty():
		_add_status_row("No runtime contracts available.")
		return

	for occurrence in entries:
		_add_occurrence_row(occurrence)


func _build_summary_text() -> String:
	var lines: Array = []
	lines.append("Current Sector: %s" % _sector_display_name(_player_current_sector_id()))
	lines.append("Player Cargo: %s" % _display_contract_value(str(GameState.player_cargo_tag), "Empty"))
	var claim_id: String = str(GameState.player_claimed_occurrence_id)
	lines.append("Selected Contract: %s" % (claim_id if claim_id != "" else "None"))
	lines.append("Workflow: Accept reserves only. Pick Up at FROM. Complete at TO.")
	if _feedback_message != "":
		lines.append(_feedback_message)
	return "\n".join(lines)


func _visible_occurrences() -> Array:
	var occurrence_ids: Array = GameState.runtime_contract_occurrences.keys()
	occurrence_ids.sort()
	var entries: Array = []
	for occurrence_id in occurrence_ids:
		var occurrence: Dictionary = GameState.runtime_contract_occurrences.get(occurrence_id, {})
		if occurrence.empty():
			continue
		if not bool(occurrence.get("player_displayable", true)):
			continue
		entries.append(occurrence)
	return entries


func _add_status_row(message: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "StatusRow"

	var label: Label = Label.new()
	label.name = "EntryLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap = true
	label.text = message
	row.add_child(label)

	_contract_list.add_child(row)


func _add_occurrence_row(occurrence: Dictionary) -> void:
	var occurrence_id: String = str(occurrence.get("occurrence_id", ""))
	var row: VBoxContainer = VBoxContainer.new()
	row.name = "ContractRow_%s" % occurrence_id.replace(":", "_")
	row.add_constant_override("separation", 8)

	var label: Label = Label.new()
	label.name = "EntryLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap = true
	label.text = _occurrence_entry_text(occurrence)
	row.add_child(label)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.add_constant_override("separation", 8)

	var accept_button: Button = Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = "Accept"
	accept_button.disabled = not _can_accept_occurrence(occurrence)
	accept_button.connect("pressed", self, "_on_accept_pressed", [occurrence_id])
	button_row.add_child(accept_button)

	var pickup_button: Button = Button.new()
	pickup_button.name = "PickupButton"
	pickup_button.text = "Pick Up"
	pickup_button.disabled = not _can_pick_up_occurrence(occurrence)
	pickup_button.connect("pressed", self, "_on_pickup_pressed", [occurrence_id])
	button_row.add_child(pickup_button)

	var complete_button: Button = Button.new()
	complete_button.name = "CompleteButton"
	complete_button.text = "Complete"
	complete_button.disabled = not _can_complete_occurrence(occurrence)
	complete_button.connect("pressed", self, "_on_complete_pressed", [occurrence_id])
	button_row.add_child(complete_button)

	row.add_child(button_row)
	_contract_list.add_child(row)


func _occurrence_entry_text(occurrence: Dictionary) -> String:
	var occurrence_id: String = str(occurrence.get("occurrence_id", ""))
	var source_sector_id: String = str(occurrence.get("source_sector_id", ""))
	var target_sector_id: String = str(occurrence.get("target_sector_id", ""))
	var claimant_agent_id: String = str(occurrence.get("claimant_agent_id", ""))
	var claimant_display: String = _display_claimant_name(claimant_agent_id)
	var status_display: String = str(occurrence.get("status", "open")).capitalize().replace("_", " ")
	var reward_credits: int = int(occurrence.get("reward_credits", 0))
	var cargo_tag: String = _display_contract_value(str(occurrence.get("required_cargo_tag", "UNKNOWN_COMMODITY")), "Unknown commodity")
	var lines: Array = []
	lines.append("Ref: %s" % occurrence_id)
	lines.append("TAKE: %s" % cargo_tag)
	lines.append("FROM: %s" % _sector_display_name(source_sector_id))
	lines.append("TO: %s" % _sector_display_name(target_sector_id))
	lines.append("REWARD: %d credits" % reward_credits)
	lines.append("Status: %s | Claimant: %s" % [status_display, claimant_display])
	lines.append("Backing: %s" % _occurrence_backing_text(occurrence))
	lines.append("Next: %s" % _occurrence_next_action_text(occurrence))
	return "\n".join(lines)


func _occurrence_backing_text(occurrence: Dictionary) -> String:
	var source_state: String = "source reserved" if bool(occurrence.get("source_reserved", false)) else "source open"
	var payment_state: String = "payment reserved" if bool(occurrence.get("payment_reserved", false)) else "payment open"
	var cargo_state: String = "cargo picked up" if bool(occurrence.get("cargo_picked_up", false)) else "cargo not picked up"
	var blocked_state: String = _occurrence_blocked_state_text(occurrence)
	if blocked_state != "":
		return "%s, %s, %s, %s" % [source_state, payment_state, cargo_state, blocked_state]
	return "%s, %s, %s" % [source_state, payment_state, cargo_state]


func _occurrence_next_action_text(occurrence: Dictionary) -> String:
	var source_name: String = _sector_display_name(str(occurrence.get("source_sector_id", "")))
	var target_name: String = _sector_display_name(str(occurrence.get("target_sector_id", "")))
	if _is_occurrence_waiting_for_source_recovery(occurrence):
		return "Waiting for source recovery at %s" % source_name
	if _is_occurrence_waiting_for_target_recovery(occurrence):
		return "Waiting for target recovery at %s" % target_name
	if _can_complete_occurrence(occurrence):
		return "Complete delivery here at %s" % target_name
	if _can_pick_up_occurrence(occurrence):
		return "Pick up cargo here at %s" % source_name
	if str(occurrence.get("claimant_agent_id", "")) == "player":
		if str(GameState.player_cargo_tag) == "LOADED":
			return "Travel to %s and complete delivery" % target_name
		return "Travel to %s and pick up cargo" % source_name
	if _can_accept_occurrence(occurrence):
		return "Accept to reserve cargo and payout"
	return "Awaiting another actor or state change"


func _display_contract_value(raw_value: String, fallback: String) -> String:
	if raw_value == "":
		return fallback
	return raw_value.to_lower().replace("_", " ").capitalize()


func _display_claimant_name(claimant_agent_id: String) -> String:
	if claimant_agent_id == "":
		return "Unclaimed"
	if claimant_agent_id == "player":
		return "Player"
	return claimant_agent_id


func _can_accept_occurrence(occurrence: Dictionary) -> bool:
	var occurrence_id: String = str(occurrence.get("occurrence_id", ""))
	var claimant_agent_id: String = str(occurrence.get("claimant_agent_id", ""))
	var active_claim_id: String = str(GameState.player_claimed_occurrence_id)
	if claimant_agent_id != "" and claimant_agent_id != "player":
		return false
	if active_claim_id != "" and active_claim_id != occurrence_id:
		return false
	return str(occurrence.get("status", "open")) in ["open", "claimed"]


func _can_pick_up_occurrence(occurrence: Dictionary) -> bool:
	if str(GameState.player_cargo_tag) != "EMPTY":
		return false
	if str(GameState.player_claimed_occurrence_id) != str(occurrence.get("occurrence_id", "")):
		return false
	if str(occurrence.get("claimant_agent_id", "")) != "player":
		return false
	if str(occurrence.get("status", "open")) != "claimed":
		return false
	if not bool(occurrence.get("source_reserved", false)):
		return false
	if _is_occurrence_waiting_for_source_recovery(occurrence):
		return false
	return _player_current_sector_id() == str(occurrence.get("source_sector_id", ""))


func _can_complete_occurrence(occurrence: Dictionary) -> bool:
	if str(GameState.player_cargo_tag) != "LOADED":
		return false
	if str(GameState.player_claimed_occurrence_id) != str(occurrence.get("occurrence_id", "")):
		return false
	if str(occurrence.get("claimant_agent_id", "")) != "player":
		return false
	if str(occurrence.get("status", "open")) != "in_transit":
		return false
	if _is_occurrence_waiting_for_target_recovery(occurrence):
		return false
	return _player_current_sector_id() == str(occurrence.get("target_sector_id", ""))


func _on_accept_pressed(occurrence_id: String) -> void:
	_feedback_message = "Unable to reserve contract."
	if is_instance_valid(GlobalRefs.simulation_engine) and GlobalRefs.simulation_engine.has_method("player_accept_runtime_contract"):
		if GlobalRefs.simulation_engine.player_accept_runtime_contract(occurrence_id):
			_feedback_message = "Reserved contract %s." % occurrence_id
	_refresh()


func _on_pickup_pressed(occurrence_id: String) -> void:
	_feedback_message = "Unable to pick up cargo."
	if is_instance_valid(GlobalRefs.simulation_engine) and GlobalRefs.simulation_engine.has_method("player_pick_up_runtime_contract"):
		if GlobalRefs.simulation_engine.player_pick_up_runtime_contract(occurrence_id):
			_feedback_message = "Picked up contract cargo for %s." % occurrence_id
	_refresh()


func _on_complete_pressed(occurrence_id: String) -> void:
	_feedback_message = "Unable to complete contract."
	if is_instance_valid(GlobalRefs.simulation_engine) and GlobalRefs.simulation_engine.has_method("player_complete_runtime_contract"):
		if GlobalRefs.simulation_engine.player_complete_runtime_contract(occurrence_id):
			_feedback_message = "Completed contract %s." % occurrence_id
	_refresh()


func _player_current_sector_id() -> String:
	if GameState.agents.has("player"):
		var player_agent: Dictionary = GameState.agents.get("player", {})
		if not player_agent.empty() and str(player_agent.get("current_sector_id", "")) != "":
			return str(player_agent.get("current_sector_id", ""))
	return str(GameState.current_sector_id)


func _sector_display_name(sector_id: String) -> String:
	if sector_id == "":
		return "Unknown"
	return str(GameState.sector_names.get(sector_id, sector_id))


func _occurrence_blocked_state_text(occurrence: Dictionary) -> String:
	if _is_occurrence_waiting_for_source_recovery(occurrence):
		return "waiting for source recovery"
	if _is_occurrence_waiting_for_target_recovery(occurrence):
		return "waiting for target recovery"
	return ""


func _is_occurrence_waiting_for_source_recovery(occurrence: Dictionary) -> bool:
	if bool(occurrence.get("cargo_picked_up", false)):
		return false
	if str(occurrence.get("status", "open")) != "claimed":
		return false
	if not bool(occurrence.get("source_reserved", false)):
		return false
	return _is_sector_disabled_for_contracts(str(occurrence.get("source_sector_id", "")))


func _is_occurrence_waiting_for_target_recovery(occurrence: Dictionary) -> bool:
	if not bool(occurrence.get("cargo_picked_up", false)):
		return false
	if str(occurrence.get("status", "open")) != "in_transit":
		return false
	return _is_sector_disabled_for_contracts(str(occurrence.get("target_sector_id", "")))


func _is_sector_disabled_for_contracts(sector_id: String) -> bool:
	if sector_id == "":
		return false
	var tags: Array = Array(GameState.sector_tags.get(sector_id, []))
	if "DISABLED" in tags:
		return true
	return int(GameState.sector_disabled_until.get(sector_id, -1)) >= GameState.sim_tick_count