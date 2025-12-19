# File: core/ui/action_check/action_check.gd
# Purpose: Modal UI for resolving Narrative Actions (Risky/Cautious + FP spend).
# Version: 1.0

extends Control

onready var label_title = $Panel/VBoxContainer/LabelTitle
onready var label_description = $Panel/VBoxContainer/LabelDescription
onready var btn_cautious = $Panel/VBoxContainer/HBoxApproach/BtnCautious
onready var btn_risky = $Panel/VBoxContainer/HBoxApproach/BtnRisky
onready var spinbox_fp = $Panel/VBoxContainer/HBoxFP/SpinBoxFP
onready var label_current_fp = $Panel/VBoxContainer/LabelCurrentFP
onready var btn_confirm = $Panel/VBoxContainer/BtnConfirm
onready var vbox_result = $Panel/VBoxContainer/VBoxResult
onready var label_roll_result = $Panel/VBoxContainer/VBoxResult/LabelRollResult
onready var label_outcome_desc = $Panel/VBoxContainer/VBoxResult/LabelOutcomeDesc
onready var label_effects = $Panel/VBoxContainer/VBoxResult/LabelEffects
onready var btn_continue = $Panel/VBoxContainer/VBoxResult/BtnContinue

var _selected_approach: int = Constants.ActionApproach.CAUTIOUS
var _action_data: Dictionary = {}


func _ready():
	visible = false
	vbox_result.visible = false

	# Ensure approach buttons behave like a selection.
	btn_cautious.toggle_mode = true
	btn_risky.toggle_mode = true

	btn_cautious.connect("pressed", self, "_on_cautious_pressed")
	btn_risky.connect("pressed", self, "_on_risky_pressed")
	btn_confirm.connect("pressed", self, "_on_confirm_pressed")
	btn_continue.connect("pressed", self, "_on_continue_pressed")

	# EventBus signature is (action_type, context). We accept both args.
	EventBus.connect("narrative_action_requested", self, "_on_action_requested")


func _on_action_requested(action_type, action_data: Dictionary):
	# action_type is provided by EventBus; action_data should include full context.
	_action_data = action_data
	# Ensure action_type exists for UI title mapping.
	if not _action_data.has("action_type"):
		_action_data["action_type"] = str(action_type)
	_show_selection_ui()


func _show_selection_ui():
	visible = true
	vbox_result.visible = false
	btn_confirm.visible = true

	label_title.text = _get_action_title(str(_action_data.get("action_type", "")))
	var ctx: Dictionary = _action_data.get("context", {})
	label_description.text = str(ctx.get("description", "Resolve this action."))

	var char_uid = int(_action_data.get("char_uid", GameState.player_character_uid))
	var current_fp = 0
	if is_instance_valid(GlobalRefs.character_system):
		current_fp = int(GlobalRefs.character_system.get_fp(char_uid))

	label_current_fp.text = "Available: %d FP" % current_fp

	# SpinBox uses floats.
	var max_fp = min(Constants.FOCUS_MAX_DEFAULT, current_fp)
	spinbox_fp.max_value = float(max_fp)
	spinbox_fp.value = 0.0

	_select_approach(Constants.ActionApproach.CAUTIOUS)


func _select_approach(approach: int):
	_selected_approach = approach
	btn_cautious.pressed = (approach == Constants.ActionApproach.CAUTIOUS)
	btn_risky.pressed = (approach == Constants.ActionApproach.RISKY)


func _on_cautious_pressed():
	_select_approach(Constants.ActionApproach.CAUTIOUS)


func _on_risky_pressed():
	_select_approach(Constants.ActionApproach.RISKY)


func _on_confirm_pressed():
	var fp_spent = int(spinbox_fp.value)
	var narrative_system = _get_narrative_action_system()
	if narrative_system == null or not narrative_system.has_method("resolve_action"):
		_show_result({
			"success": false,
			"roll_result": {"roll_total": 0, "tier_name": "Failure"},
			"outcome": {"description": "NarrativeActionSystem unavailable.", "effects": {}},
			"effects_applied": {},
			"action_type": str(_action_data.get("action_type", ""))
		})
		return

	var result = narrative_system.resolve_action(_selected_approach, fp_spent)
	_show_result(result)


func _show_result(result: Dictionary):
	btn_confirm.visible = false
	vbox_result.visible = true

	if not result.get("success", true):
		label_roll_result.text = "Roll: 0 → Failure"
		label_outcome_desc.bbcode_text = "[i]%s[/i]" % str(result.get("reason", "Failed to resolve action."))
		label_effects.text = "No additional effects."
		return

	var roll = result.get("roll_result", {})
	label_roll_result.text = "Roll: %d → %s" % [int(roll.get("roll_total", 0)), str(roll.get("tier_name", ""))]

	var outcome = result.get("outcome", {})
	label_outcome_desc.bbcode_text = "[i]%s[/i]" % str(outcome.get("description", ""))

	var effects_text = _format_effects(result.get("effects_applied", {}))
	label_effects.text = effects_text if effects_text != "" else "No additional effects."


func _format_effects(effects: Dictionary) -> String:
	var parts = []
	if effects.has("wp_lost"):
		parts.append("-%d WP" % int(effects.get("wp_lost", 0)))
	if effects.has("wp_gained"):
		parts.append("+%d WP" % int(effects.get("wp_gained", 0)))
	if effects.has("fp_gained"):
		parts.append("+%d FP" % int(effects.get("fp_gained", 0)))
	if effects.has("quirk_added"):
		parts.append("Quirk: %s" % str(effects.get("quirk_added")))
	if effects.has("reputation_changed"):
		var rep = int(effects.get("reputation_changed", 0))
		parts.append("%+d Reputation" % rep)
	return PoolStringArray(parts).join(", ")


func _on_continue_pressed():
	visible = false
	_action_data = {}


func _get_action_title(action_type: String) -> String:
	match action_type:
		"contract_complete":
			return "Finalize Delivery"
		"dock_arrival":
			return "Execute Approach"
		"trade_finalize":
			return "Seal the Deal"
		_:
			return "Resolve Action"


func _get_narrative_action_system():
	# Task 7 will add GlobalRefs.narrative_action_system; until then use Object.get().
	var sys = null
	if GlobalRefs:
		sys = GlobalRefs.get("narrative_action_system")
	if is_instance_valid(sys):
		return sys
	return get_node_or_null("/root/NarrativeActionSystem")
