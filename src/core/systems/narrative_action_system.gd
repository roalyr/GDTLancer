# File: core/systems/narrative_action_system.gd
# Purpose: Orchestrates Narrative Actions: request → resolve → apply effects.
#          Bridges game events (contract completion, docking, trading) with
#          CoreMechanicsAPI (dice rolls) and NarrativeOutcomes (effect lookup).
# Version: 2.0 - Strict types, comprehensive docstrings, safe null checks.

extends Node

## Stores pending action state while awaiting UI player input.
var _pending_action: Dictionary = {}


func _ready() -> void:
	"""Register this system in GlobalRefs (if setter available)."""
	if GlobalRefs and GlobalRefs.has_method("set_narrative_action_system"):
		GlobalRefs.set_narrative_action_system(self)


func request_action(action_type: String, context: Dictionary) -> void:
	"""Request a narrative action (e.g., "contract_complete").
	
	Args:
		action_type: "contract_complete", "dock_arrival", or "trade_finalize".
		context: {char_uid, description, ...} passed through to UI.
	
	Behavior:
		Stores action data in _pending_action.
		Looks up skill/attribute for this action type.
		Emits EventBus.narrative_action_requested to show UI.
	"""
	var char_uid: int = int(context.get("char_uid", GameState.player_character_uid))
	_pending_action = {
		"action_type": action_type,
		"context": context,
		"char_uid": char_uid
	}

	# Determine which skill/attribute applies.
	var skill_info: Dictionary = _get_skill_for_action(action_type)
	_pending_action.merge(skill_info)

	# Cross-system/UI signal (global).
	# EventBus declares: signal narrative_action_requested(action_type, context)
	if EventBus:
		EventBus.emit_signal("narrative_action_requested", action_type, _pending_action)


func resolve_action(approach: int, fp_spent: int) -> Dictionary:
	"""Resolve pending action: roll, lookup outcome, apply effects.
	
	Args:
		approach: Constants.ActionApproach (CAUTIOUS=0 or RISKY=1).
		fp_spent: Focus Points player allocated (0-3 typically).
	
	Returns:
		{success: bool, roll_result: Dictionary, outcome: Dictionary, effects_applied: Dictionary}
		
	Behavior:
		1. Validates pending action exists.
		2. Gets character attribute & skill.
		3. Clamps fp_spent to available FP.
		4. Calls CoreMechanicsAPI.perform_action_check().
		5. Looks up narrative outcome by action_type + tier.
		6. Applies all effects (WP, FP, quirks, reputation).
		7. Emits EventBus.narrative_action_resolved.
		8. Clears _pending_action.
	"""
	if _pending_action.empty():
		return {"success": false, "reason": "No pending action"}

	var char_uid: int = int(_pending_action.get("char_uid", GameState.player_character_uid))
	if not is_instance_valid(GlobalRefs.character_system):
		return {"success": false, "reason": "CharacterSystem unavailable"}

	var attribute_name: String = str(_pending_action.get("attribute_name", "cunning"))
	var skill_name: String = str(_pending_action.get("skill_name", "general"))
	var attr_value: int = _get_attribute_value(char_uid, attribute_name)
	var skill_value: int = int(GlobalRefs.character_system.get_skill_level(char_uid, skill_name))

	# Clamp FP spent to available FP; CoreMechanicsAPI will clamp to max.
	var available_fp: int = int(GlobalRefs.character_system.get_fp(char_uid))
	fp_spent = int(fp_spent)
	if fp_spent < 0:
		fp_spent = 0
	if fp_spent > available_fp:
		fp_spent = available_fp

	# Perform the roll via CoreMechanicsAPI.
	var roll_result: Dictionary = CoreMechanicsAPI.perform_action_check(attr_value, skill_value, fp_spent, approach)

	# Get narrative outcome from tier.
	# CoreMechanicsAPI returns both result_tier ("CritSuccess"/"SwC"/"Failure") and tier_name.
	var tier_key: String = str(roll_result.get("result_tier", roll_result.get("tier_name", "Failure")))
	var action_type: String = str(_pending_action.get("action_type", ""))
	var outcome: Dictionary = _get_narrative_outcome(action_type, tier_key)

	# Apply effects.
	var applied: Dictionary = _apply_effects(char_uid, outcome.get("effects", {}))

	# Deduct FP spent.
	if fp_spent > 0:
		GlobalRefs.character_system.subtract_fp(char_uid, fp_spent)

	# Handle FP gain/loss from roll result.
	var focus_gain: int = int(roll_result.get("focus_gain", 0))
	if focus_gain > 0:
		GlobalRefs.character_system.add_fp(char_uid, focus_gain)
	if bool(roll_result.get("focus_loss_reset", false)):
		_reset_focus_points(char_uid)

	var result: Dictionary = {
		"success": true,
		"roll_result": roll_result,
		"outcome": outcome,
		"effects_applied": applied,
		"action_type": action_type,
		"char_uid": char_uid
	}

	# Cross-system/UI signal (global).
	if EventBus:
		EventBus.emit_signal("narrative_action_resolved", result)

	_pending_action = {}
	return result


func _get_narrative_outcome(action_type: String, tier_key: String) -> Dictionary:
	"""Look up outcome data from NarrativeOutcomes autoload.
	
	Args:
		action_type: e.g., "contract_complete".
		tier_key: "CritSuccess", "SwC", or "Failure".
		
	Returns:
		{description: String, effects: Dictionary} or empty dict if not found.
	"""
	var outcomes_node: Node = get_node_or_null("/root/NarrativeOutcomes")
	if outcomes_node and outcomes_node.has_method("get_outcome"):
		return outcomes_node.get_outcome(action_type, tier_key)
	return {"description": "No outcome defined.", "effects": {}}


func _get_skill_for_action(action_type: String) -> Dictionary:
	"""Map action_type to attribute & skill used in the check.
	
	Args:
		action_type: e.g., "contract_complete".
		
	Returns:
		{attribute_name: String, skill_name: String}.
	"""
	match action_type:
		"contract_complete":
			return {"attribute_name": "cunning", "skill_name": "negotiation"}
		"dock_arrival":
			return {"attribute_name": "reflex", "skill_name": "piloting"}
		"trade_finalize":
			return {"attribute_name": "cunning", "skill_name": "trading"}
		_:
			return {"attribute_name": "cunning", "skill_name": "general"}


func _apply_effects(char_uid: int, effects: Dictionary) -> Dictionary:
	"""Apply all outcome effects (WP, FP, quirks, reputation) to game state.
	
	Args:
		char_uid: Character UID.
		effects: {"wp_cost": int, "wp_gain": int, "fp_gain": int, "add_quirk": str, "reputation_change": int}.
		
	Returns:
		{"wp_lost": int, "wp_gained": int, "quirk_added": str, "reputation_changed": int}.
		Only includes effects that were actually applied.
	"""
	var applied: Dictionary = {}
	if effects == null:
		return applied

	# Ship quirks (integrated with QuirkSystem).
	if effects.has("add_quirk") and is_instance_valid(GlobalRefs.quirk_system):
		var quirk_id: String = str(effects.get("add_quirk"))
		var ship_uid: int = -1
		
		# Resolve ship UID from character data
		if GameState.characters.has(char_uid):
			var character: Object = GameState.characters[char_uid]
			if is_instance_valid(character):
				# Assuming CharacterTemplate has active_ship_uid
				ship_uid = int(character.active_ship_uid)

		if ship_uid != -1:
			if GlobalRefs.quirk_system.add_quirk(ship_uid, quirk_id):
				applied["quirk_added"] = quirk_id

	# WP adjustments.
	if effects.has("wp_cost"):
		var wp_cost: int = int(effects.get("wp_cost", 0))
		if wp_cost != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.subtract_wp(char_uid, wp_cost)
			applied["wp_lost"] = wp_cost

	if effects.has("wp_gain"):
		var wp_gain: int = int(effects.get("wp_gain", 0))
		if wp_gain != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.add_wp(char_uid, wp_gain)
			applied["wp_gained"] = wp_gain

	# FP gains from outcomes (separate from CoreMechanicsAPI focus_gain).
	if effects.has("fp_gain"):
		var fp_gain: int = int(effects.get("fp_gain", 0))
		if fp_gain != 0 and is_instance_valid(GlobalRefs.character_system):
			GlobalRefs.character_system.add_fp(char_uid, fp_gain)
			applied["fp_gained"] = fp_gain

	# Reputation change (GameState container).
	if effects.has("reputation_change"):
		var rep_delta: int = int(effects.get("reputation_change", 0))
		if not GameState.narrative_state.has("reputation"):
			GameState.narrative_state["reputation"] = 0
		GameState.narrative_state["reputation"] = int(GameState.narrative_state["reputation"]) + rep_delta
		applied["reputation_changed"] = rep_delta

	return applied


func _reset_focus_points(char_uid: int) -> void:
	"""Reset character's FP to 0 (used when focus_loss_reset from roll)."""
	if not is_instance_valid(GlobalRefs.character_system):
		return
	var current_fp: int = int(GlobalRefs.character_system.get_fp(char_uid))
	if current_fp > 0:
		GlobalRefs.character_system.subtract_fp(char_uid, current_fp)


func _get_attribute_value(char_uid: int, attribute_name: String) -> int:
	"""Get attribute value for character (Phase 1: always 0, placeholder for future expansion).
	
	Args:
		char_uid: Character UID.
		attribute_name: e.g., "cunning", "reflex".
		
	Returns:
		Attribute value (0 if not implemented).
	"""
	var character: Object = GameState.characters.get(char_uid, null)
	if character == null:
		return 0
	if character.has_method("get") and character.get("attributes") is Dictionary:
		return int(character.attributes.get(attribute_name, 0))
	return 0
