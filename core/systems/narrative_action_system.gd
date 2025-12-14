# File: core/systems/narrative_action_system.gd
# Purpose: Request/resolve Narrative Actions using CoreMechanicsAPI + NarrativeOutcomes.
# Version: 1.0

extends Node

signal action_ui_requested(action_data)  # Internal: tells UI to show
signal action_resolved(result_data)  # Internal: tells UI result is ready

var _pending_action: Dictionary = {}  # Stores context while waiting for player input


func _ready():
	# This setter is added in a later task; guard for incremental integration.
	if GlobalRefs and GlobalRefs.has_method("set_narrative_action_system"):
		GlobalRefs.set_narrative_action_system(self)
	print("NarrativeActionSystem Ready.")


# Called by game systems (ContractSystem, TradingSystem) to initiate.
# Emits EventBus.narrative_action_requested to trigger UI display.
# context: {char_uid, action_type, description, related_ids...}
func request_action(action_type: String, context: Dictionary) -> void:
	var char_uid = int(context.get("char_uid", GameState.player_character_uid))
	_pending_action = {
		"action_type": action_type,
		"context": context,
		"char_uid": char_uid
	}

	# Determine which skill/attribute applies.
	var skill_info = _get_skill_for_action(action_type)
	_pending_action.merge(skill_info)

	# Internal/UI signal (local).
	emit_signal("action_ui_requested", _pending_action)

	# Cross-system/UI signal (global).
	# EventBus declares: signal narrative_action_requested(action_type, context)
	if EventBus:
		EventBus.emit_signal("narrative_action_requested", action_type, _pending_action)


# Called by ActionCheckUI when player confirms selection.
# approach: Constants.ActionApproach (RISKY or CAUTIOUS)
# fp_spent: int (0-3 typically)
func resolve_action(approach: int, fp_spent: int) -> Dictionary:
	if _pending_action.empty():
		return {"success": false, "reason": "No pending action"}

	var char_uid = int(_pending_action.get("char_uid", GameState.player_character_uid))
	if not is_instance_valid(GlobalRefs.character_system):
		return {"success": false, "reason": "CharacterSystem unavailable"}

	var attribute_name = str(_pending_action.get("attribute_name", "cunning"))
	var skill_name = str(_pending_action.get("skill_name", "general"))
	var attr_value = _get_attribute_value(char_uid, attribute_name)
	var skill_value = int(GlobalRefs.character_system.get_skill_level(char_uid, skill_name))

	# Clamp FP spent to available FP; CoreMechanicsAPI will clamp to max.
	var available_fp = int(GlobalRefs.character_system.get_fp(char_uid))
	fp_spent = int(fp_spent)
	if fp_spent < 0:
		fp_spent = 0
	if fp_spent > available_fp:
		fp_spent = available_fp

	# Perform the roll via CoreMechanicsAPI.
	var roll_result = CoreMechanicsAPI.perform_action_check(attr_value, skill_value, fp_spent, approach)

	# Get narrative outcome from tier.
	# CoreMechanicsAPI returns both result_tier ("CritSuccess"/"SwC"/"Failure") and tier_name.
	var tier_key = str(roll_result.get("result_tier", roll_result.get("tier_name", "Failure")))
	var action_type = str(_pending_action.get("action_type", ""))
	var outcome = _get_narrative_outcome(action_type, tier_key)

	# Apply effects.
	var applied = _apply_effects(char_uid, outcome.get("effects", {}))

	# Deduct FP spent.
	if fp_spent > 0:
		GlobalRefs.character_system.subtract_fp(char_uid, fp_spent)

	# Handle FP gain/loss from result.
	var focus_gain = int(roll_result.get("focus_gain", 0))
	if focus_gain > 0:
		GlobalRefs.character_system.add_fp(char_uid, focus_gain)
	if bool(roll_result.get("focus_loss_reset", false)):
		_reset_focus_points(char_uid)

	var result = {
		"success": true,
		"roll_result": roll_result,
		"outcome": outcome,
		"effects_applied": applied,
		"action_type": action_type,
		"char_uid": char_uid
	}

	# Internal/UI signal (local).
	emit_signal("action_resolved", result)

	# Cross-system/UI signal (global).
	if EventBus:
		EventBus.emit_signal("narrative_action_resolved", result)

	_pending_action = {}
	return result


func _get_narrative_outcome(action_type: String, tier_key: String) -> Dictionary:
	# Resolve NarrativeOutcomes via /root (autoload).
	var outcomes_node = get_node_or_null("/root/NarrativeOutcomes")
	if outcomes_node and outcomes_node.has_method("get_outcome"):
		return outcomes_node.get_outcome(action_type, tier_key)
	return {"description": "No outcome defined.", "effects": {}}


# Internal: maps action_type to skill/attribute used.
func _get_skill_for_action(action_type: String) -> Dictionary:
	match action_type:
		"contract_complete":
			return {"attribute_name": "cunning", "skill_name": "negotiation"}
		"dock_arrival":
			return {"attribute_name": "reflex", "skill_name": "piloting"}
		"trade_finalize":
			return {"attribute_name": "cunning", "skill_name": "trading"}
		_:
			return {"attribute_name": "cunning", "skill_name": "general"}


# Internal: applies effects from outcome.
func _apply_effects(char_uid: int, effects: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	if effects == null:
		return applied

	# Ship quirks (best-effort: char ship if available, else player ship).
	if effects.has("add_quirk") and is_instance_valid(GlobalRefs.asset_system):
		var quirk_id = str(effects.get("add_quirk"))
		var ship = null
		if GlobalRefs.asset_system.has_method("get_ship_for_character"):
			ship = GlobalRefs.asset_system.get_ship_for_character(char_uid)
		if ship == null and GlobalRefs.asset_system.has_method("get_player_ship"):
			ship = GlobalRefs.asset_system.get_player_ship()
		if is_instance_valid(ship):
			ship.ship_quirks.append(quirk_id)
			applied["quirk_added"] = quirk_id

	# WP adjustments.
	if effects.has("wp_cost"):
		var wp_cost = int(effects.get("wp_cost", 0))
		if wp_cost != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.subtract_wp(char_uid, wp_cost)
			applied["wp_lost"] = wp_cost

	if effects.has("wp_gain"):
		var wp_gain = int(effects.get("wp_gain", 0))
		if wp_gain != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.add_wp(char_uid, wp_gain)
			applied["wp_gained"] = wp_gain

	# FP gains from outcomes (separate from CoreMechanicsAPI focus_gain).
	if effects.has("fp_gain"):
		var fp_gain = int(effects.get("fp_gain", 0))
		if fp_gain != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.add_fp(char_uid, fp_gain)
			applied["fp_gained"] = fp_gain

	# Reputation change (GameState container).
	if effects.has("reputation_change"):
		var rep_delta = int(effects.get("reputation_change", 0))
		if not GameState.narrative_state.has("reputation"):
			GameState.narrative_state["reputation"] = 0
		GameState.narrative_state["reputation"] = int(GameState.narrative_state["reputation"]) + rep_delta
		applied["reputation_changed"] = rep_delta

	return applied


func _reset_focus_points(char_uid: int) -> void:
	if not is_instance_valid(GlobalRefs.character_system):
		return
	var current_fp = int(GlobalRefs.character_system.get_fp(char_uid))
	if current_fp > 0:
		GlobalRefs.character_system.subtract_fp(char_uid, current_fp)


func _get_attribute_value(char_uid: int, attribute_name: String) -> int:
	# Phase 1: CharacterTemplate currently has no attribute block.
	# If attributes are added later (e.g., character.attributes dict), this will start using them.
	var character = GameState.characters.get(char_uid, null)
	if character == null:
		return 0
	if character.has_method("get") and character.get("attributes") is Dictionary:
		return int(character.attributes.get(attribute_name, 0))
	return 0
