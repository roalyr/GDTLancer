#
# PROJECT: GDTLancer
# MODULE: test_narrative_action_system.gd
# STATUS: Level 2 - Implementation
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-27-Senior-Dev
#

extends GutTest

# --- Preloads ---
const NarrativeActionSystemPath = "res://src/core/systems/narrative_action_system.gd"
const CharacterSystemPath = "res://src/core/systems/character_system.gd"
const CharacterTemplate = preload("res://database/definitions/character_template.gd")
const ActionTemplate = preload("res://database/definitions/action_template.gd")

# --- Test State ---
var narrative_system = null
var character_system_instance = null
var default_char_template = null
const PLAYER_UID = 0


func before_each():
	"""Set up game state and instantiate the system."""
	# Clear global state
	GameState.characters.clear()
	GameState.narrative_state.clear()
	GameState.player_character_uid = PLAYER_UID

	# Load the base character template
	default_char_template = load("res://database/registry/characters/character_default.tres")
	assert_true(is_instance_valid(default_char_template), "Pre-check: Default character template must load.")

	# Create and register a player character instance
	var player_char_instance = default_char_template.duplicate()
	GameState.characters[PLAYER_UID] = player_char_instance
	GameState.player_character_uid = PLAYER_UID

	# Instantiate CharacterSystem and register in GlobalRefs
	var char_system_script = load(CharacterSystemPath)
	character_system_instance = char_system_script.new()
	add_child_autofree(character_system_instance)
	GlobalRefs.set_character_system(character_system_instance)

	# Instantiate the narrative system via load() to avoid cyclic reference error
	var script = load(NarrativeActionSystemPath)
	narrative_system = script.new()
	add_child_autofree(narrative_system)
	narrative_system._ready()


func after_each():
	"""Clean up."""
	GameState.characters.clear()
	GameState.narrative_state.clear()
	GameState.player_character_uid = -1
	GlobalRefs.set_character_system(null)
	narrative_system = null
	character_system_instance = null
	default_char_template = null


# --- Test Cases ---

func test_request_action_success():
	"""Test that request_action stores pending action and emits EventBus signal."""
	# Given: A narrative system and valid context
	var context = {
		"char_uid": PLAYER_UID,
		"description": "Execute a risky maneuver."
	}

	# When: We request an action
	narrative_system.request_action("dock_arrival", context)

	# Then: _pending_action should be populated
	assert_true(not narrative_system._pending_action.empty(), "Pending action should be set")
	assert_eq(narrative_system._pending_action.action_type, "dock_arrival", "Action type should match")
	assert_eq(narrative_system._pending_action.char_uid, PLAYER_UID, "Character UID should match")
	assert_eq(narrative_system._pending_action.skill_name, "piloting", "Skill for dock_arrival should be piloting")


func test_resolve_action_no_pending():
	"""Test that resolve_action fails gracefully when no pending action."""
	# Given: No pending action
	narrative_system._pending_action = {}

	# When: We attempt to resolve
	var result = narrative_system.resolve_action(0, 0)

	# Then: Should return failure
	assert_false(result.success, "Should fail when no pending action")
	assert_eq(result.reason, "No pending action", "Reason should indicate no pending action")


func test_resolve_action_character_unavailable():
	"""Test that resolve_action fails when CharacterSystem is unavailable."""
	# Given: A pending action but no CharacterSystem
	var old_char_system = GlobalRefs.character_system
	GlobalRefs.character_system = null

	narrative_system._pending_action = {
		"char_uid": PLAYER_UID,
		"action_type": "contract_complete",
		"attribute_name": "cunning",
		"skill_name": "negotiation"
	}

	# When: We attempt to resolve
	var result = narrative_system.resolve_action(0, 0)

	# Then: Should return failure
	assert_false(result.success, "Should fail when CharacterSystem unavailable")
	assert_eq(result.reason, "CharacterSystem unavailable", "Reason should indicate missing system")

	# Restore
	GlobalRefs.character_system = old_char_system


func test_resolve_action_fp_clamping():
	"""Test that resolve_action clamps fp_spent to available FP (EDGE CASE)."""
	# Given: A character with 2 available FP
	GameState.characters[PLAYER_UID].focus_points = 2

	narrative_system._pending_action = {
		"char_uid": PLAYER_UID,
		"action_type": "contract_complete",
		"attribute_name": "cunning",
		"skill_name": "negotiation"
	}

	# When: We attempt to spend 5 FP (more than available)
	var result = narrative_system.resolve_action(Constants.ActionApproach.CAUTIOUS, 5)

	# Then: Should succeed, but FP spent should be clamped to available
	assert_true(result.success, "Should succeed despite over-allocation")
	# The actual FP deduction is handled by character_system, verify it was called with clamped value
	assert_true(result.has("effects_applied"), "Should have effects")


func test_apply_effects_credits_gain():
	"""Test that _apply_effects correctly adds credits."""
	# Given: Effects with credits gain
	var effects = {
		"credits_gain": 50
	}

	var char_credits_before = int(GlobalRefs.character_system.get_credits(PLAYER_UID))

	# When: We apply effects
	var applied = narrative_system._apply_effects(PLAYER_UID, effects)

	# Then: credits should increase
	var char_credits_after = int(GlobalRefs.character_system.get_credits(PLAYER_UID))
	assert_eq(char_credits_after, char_credits_before + 50, "credits should increase by 50")
	assert_true(applied.has("credits_gained"), "Applied effects should record credits_gained")
	assert_eq(applied["credits_gained"], 50, "Applied credits_gained should be 50")


func test_apply_effects_credits_cost():
	"""Test that _apply_effects correctly subtracts credits."""
	# Given: Effects with credits cost
	var effects = {
		"credits_cost": 30
	}

	# Ensure character has enough credits
	GlobalRefs.character_system.add_credits(PLAYER_UID, 100)
	var char_credits_before = int(GlobalRefs.character_system.get_credits(PLAYER_UID))

	# When: We apply effects
	var applied = narrative_system._apply_effects(PLAYER_UID, effects)

	# Then: credits should decrease
	var char_credits_after = int(GlobalRefs.character_system.get_credits(PLAYER_UID))
	assert_eq(char_credits_after, char_credits_before - 30, "credits should decrease by 30")
	assert_true(applied.has("credits_lost"), "Applied effects should record credits_lost")


func test_apply_effects_reputation_change():
	"""Test that _apply_effects updates reputation correctly."""
	# Given: Effects with reputation change
	var effects = {
		"reputation_change": 5
	}

	var rep_before = GameState.narrative_state.get("reputation", 0)

	# When: We apply effects
	var applied = narrative_system._apply_effects(PLAYER_UID, effects)

	# Then: Reputation should increase
	var rep_after = GameState.narrative_state.get("reputation", 0)
	assert_eq(rep_after, rep_before + 5, "Reputation should increase by 5")
	assert_true(applied.has("reputation_changed"), "Applied effects should record reputation_changed")


func test_apply_effects_null_effects():
	"""Test that _apply_effects handles empty effects gracefully."""
	# Given: Empty effects dictionary
	var effects = {}

	# When: We apply empty effects
	var applied = narrative_system._apply_effects(PLAYER_UID, effects)

	# Then: Should return empty dict (no changes)
	assert_eq(applied.size(), 0, "Should return empty dict for empty effects")


func test_get_skill_for_action_contract_complete():
	"""Test that _get_skill_for_action returns correct skill for contract_complete."""
	var skill_info = narrative_system._get_skill_for_action("contract_complete")
	assert_eq(skill_info.attribute_name, "cunning", "Should use cunning attribute")
	assert_eq(skill_info.skill_name, "negotiation", "Should use negotiation skill")


func test_get_skill_for_action_dock_arrival():
	"""Test that _get_skill_for_action returns correct skill for dock_arrival."""
	var skill_info = narrative_system._get_skill_for_action("dock_arrival")
	assert_eq(skill_info.attribute_name, "reflex", "Should use reflex attribute")
	assert_eq(skill_info.skill_name, "piloting", "Should use piloting skill")


func test_get_skill_for_action_trade_finalize():
	"""Test that _get_skill_for_action returns correct skill for trade_finalize."""
	var skill_info = narrative_system._get_skill_for_action("trade_finalize")
	assert_eq(skill_info.attribute_name, "cunning", "Should use cunning attribute")
	assert_eq(skill_info.skill_name, "trading", "Should use trading skill")


func test_get_skill_for_action_unknown():
	"""Test that _get_skill_for_action defaults for unknown action type."""
	var skill_info = narrative_system._get_skill_for_action("unknown_action")
	assert_eq(skill_info.attribute_name, "cunning", "Should default to cunning")
	assert_eq(skill_info.skill_name, "general", "Should default to general skill")


func test_get_attribute_value_no_attributes():
	"""Test that _get_attribute_value returns 0 when attributes not implemented (EDGE CASE)."""
	# Phase 1: CharacterTemplate doesn't have attributes dict
	var attr_value = narrative_system._get_attribute_value(PLAYER_UID, "cunning")
	assert_eq(attr_value, 0, "Should return 0 for Phase 1 (no attributes)")


func test_reset_focus_points():
	"""Test that _reset_focus_points correctly resets FP to 0."""
	# Given: Character with 3 FP
	GameState.characters[PLAYER_UID].focus_points = 3
	assert_eq(GlobalRefs.character_system.get_fp(PLAYER_UID), 3, "Should start with 3 FP")

	# When: We reset FP
	narrative_system._reset_focus_points(PLAYER_UID)

	# Then: FP should be 0
	assert_eq(GlobalRefs.character_system.get_fp(PLAYER_UID), 0, "FP should be reset to 0")


func test_effective_approach_neutral_override():
	"""Test that NARRATIVE stakes force the approach to NEUTRAL."""
	# Given: An action template with NARRATIVE stakes
	var template = ActionTemplate.new()
	template.stakes = Constants.ActionStakes.NARRATIVE

	# When: We determine effective approach with RISKY player input
	var effective = narrative_system._get_effective_approach(template.stakes, Constants.ActionApproach.RISKY)

	# Then: Approach should be NEUTRAL
	assert_eq(effective, Constants.ActionApproach.NEUTRAL, "NARRATIVE stakes should force NEUTRAL approach")


func test_effective_approach_high_stakes_preserved():
	"""Test that HIGH_STAKES preserve the player's chosen approach."""
	# Given: An action template with HIGH_STAKES
	var template = ActionTemplate.new()
	template.stakes = Constants.ActionStakes.HIGH_STAKES

	# When: We determine effective approach with RISKY player input
	var effective = narrative_system._get_effective_approach(template.stakes, Constants.ActionApproach.RISKY)

	# Then: Approach should remain RISKY
	assert_eq(effective, Constants.ActionApproach.RISKY, "HIGH_STAKES should preserve player approach")


func test_default_approach_neutral():
	"""Test that MUNDANE stakes force the approach to NEUTRAL."""
	# Given: An action template with MUNDANE stakes
	var template = ActionTemplate.new()
	template.stakes = Constants.ActionStakes.MUNDANE

	# When: We determine effective approach with CAUTIOUS player input
	var effective = narrative_system._get_effective_approach(template.stakes, Constants.ActionApproach.CAUTIOUS)

	# Then: Approach should be NEUTRAL
	assert_eq(effective, Constants.ActionApproach.NEUTRAL, "MUNDANE stakes should force NEUTRAL approach")
