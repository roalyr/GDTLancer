#
# PROJECT: GDTLancer
# MODULE: test_contract_system.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-28-QA-Intern
#
extends "res://addons/gut/test.gd"

## Unit tests for ContractSystem: contract acceptance, completion, and reward distribution.

const ContractSystem = preload("res://src/core/systems/contract_system.gd")
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")
const CharacterSystem = preload("res://src/core/systems/character_system.gd")

var _contract_system: Node
var _inventory_system: Node
var _character_system: Node
var _test_character_uid: int = 0
var _test_contract_id: String = "test_delivery_contract"


func before_each():
	# Clear GameState
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.contracts.clear()
	GameState.active_contracts.clear()
	GameState.game_time_seconds = 0
	GameState.player_character_uid = _test_character_uid
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"contact_relationships": {},
		"chronicle_entries": []
	}
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_credits_earned": 0,
		"total_credits_spent": 0,
		"enemies_disabled": 0,
		"time_played_seconds": 0
	}
	
	# Create systems
	_contract_system = ContractSystem.new()
	_inventory_system = InventorySystem.new()
	_character_system = CharacterSystem.new()
	add_child(_contract_system)
	add_child(_inventory_system)
	add_child(_character_system)
	
	# Register in GlobalRefs
	GlobalRefs.contract_system = _contract_system
	GlobalRefs.inventory_system = _inventory_system
	GlobalRefs.character_system = _character_system
	
	# Create test character with credits
	var char_template = CharacterTemplate.new()
	char_template.template_id = "test_character"
	char_template.credits = 500
	GameState.characters[_test_character_uid] = char_template
	
	# Create inventory for character
	_inventory_system.create_inventory_for_character(_test_character_uid)
	
	# Create test contract
	var contract = _create_test_contract()
	GameState.contracts[_test_contract_id] = contract


func after_each():
	_contract_system.queue_free()
	_inventory_system.queue_free()
	_character_system.queue_free()
	GlobalRefs.contract_system = null
	GlobalRefs.inventory_system = null
	GlobalRefs.character_system = null
	
	# Reset session stats with defaults (avoid "Invalid get index" errors)
	GameState.session_stats = {
		"contracts_completed": 0,
		"total_credits_earned": 0,
		"total_credits_spent": 0,
		"enemies_disabled": 0,
		"time_played_seconds": 0
	}
	GameState.narrative_state = {
		"reputation": 0,
		"faction_standings": {},
		"known_contacts": [],
		"contact_relationships": {},
		"chronicle_entries": []
	}
	GameState.player_docked_at = ""


func _create_test_contract() -> ContractTemplate:
	var contract = ContractTemplate.new()
	contract.template_id = _test_contract_id
	contract.contract_type = "delivery"
	contract.title = "Test Delivery"
	contract.description = "Deliver ore for testing"
	contract.origin_location_id = "station_alpha"
	contract.destination_location_id = "station_beta"
	contract.required_commodity_id = "commodity_ore"
	contract.required_quantity = 10
	contract.reward_credits = 100
	contract.reward_reputation = 5
	contract.faction_id = "test_faction"
	contract.time_limit_seconds = -1  # No time limit
	contract.difficulty = 1
	return contract


# --- Test: Get Available Contracts ---

func test_get_available_contracts_at_location():
	var available = _contract_system.get_available_contracts("station_alpha")
	assert_eq(available.size(), 1, "Should find 1 contract at station_alpha")
	assert_eq(available[0].template_id, _test_contract_id, "Should find our test contract")


func test_get_available_contracts_wrong_location():
	var available = _contract_system.get_available_contracts("station_gamma")
	assert_eq(available.size(), 0, "Should find no contracts at wrong location")


func test_get_available_contracts_excludes_active():
	# Accept the contract first
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	var available = _contract_system.get_available_contracts("station_alpha")
	assert_eq(available.size(), 0, "Should not show already active contracts")


# --- Test: Accept Contract ---

func test_accept_contract_success():
	var result = _contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	assert_true(result.success, "Accept should succeed")
	assert_true(GameState.active_contracts.has(_test_contract_id), "Contract should be in active_contracts")
	assert_eq(GameState.active_contracts[_test_contract_id].accepted_at_seconds, 0, "Should record accepted time")


func test_accept_contract_not_found():
	var result = _contract_system.accept_contract(_test_character_uid, "nonexistent_contract")
	
	assert_false(result.success, "Accept should fail")
	assert_true("not found" in result.reason.to_lower(), "Reason should mention not found")


func test_accept_contract_already_active():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	var result = _contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	assert_false(result.success, "Should not accept twice")
	assert_true("already active" in result.reason.to_lower(), "Reason should mention already active")


func test_accept_contract_max_limit():
	# Create and accept 3 contracts
	for i in range(3):
		var contract = _create_test_contract()
		contract.template_id = "contract_" + str(i)
		GameState.contracts[contract.template_id] = contract
		_contract_system.accept_contract(_test_character_uid, contract.template_id)
	
	# Try to accept 4th
	var result = _contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	assert_false(result.success, "Should not accept 4th contract")
	assert_true("maximum" in result.reason.to_lower(), "Reason should mention maximum")


# --- Test: Get Active Contracts ---

func test_get_active_contracts():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	var active = _contract_system.get_active_contracts(_test_character_uid)
	assert_eq(active.size(), 1, "Should have 1 active contract")
	assert_eq(active[0].template_id, _test_contract_id, "Should be our test contract")


func test_get_active_contracts_empty():
	var active = _contract_system.get_active_contracts(_test_character_uid)
	assert_eq(active.size(), 0, "Should have no active contracts initially")


# --- Test: Check Contract Completion ---

func test_check_completion_not_active():
	var result = _contract_system.check_contract_completion(_test_character_uid, _test_contract_id)
	
	assert_false(result.can_complete, "Should not complete inactive contract")
	assert_true("not active" in result.reason.to_lower(), "Reason should mention not active")


func test_check_completion_missing_cargo():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	GameState.player_docked_at = "station_beta"
	
	var result = _contract_system.check_contract_completion(_test_character_uid, _test_contract_id)
	
	assert_false(result.can_complete, "Should not complete without cargo")
	assert_true("insufficient" in result.reason.to_lower(), "Reason should mention insufficient cargo")


func test_check_completion_with_cargo():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	GameState.player_docked_at = "station_beta"
	
	# Add required cargo
	_inventory_system.add_asset(
		_test_character_uid,
		InventorySystem.InventoryType.COMMODITY,
		"commodity_ore",
		10
	)
	
	var result = _contract_system.check_contract_completion(_test_character_uid, _test_contract_id)
	
	assert_true(result.can_complete, "Should be able to complete with cargo")


func test_check_completion_partial_cargo():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	GameState.player_docked_at = "station_beta"
	
	# Add less than required
	_inventory_system.add_asset(
		_test_character_uid,
		InventorySystem.InventoryType.COMMODITY,
		"commodity_ore",
		5
	)
	
	var result = _contract_system.check_contract_completion(_test_character_uid, _test_contract_id)
	
	assert_false(result.can_complete, "Should not complete with partial cargo")


# --- Test: Complete Contract ---

func test_complete_contract_success():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	_inventory_system.add_asset(
		_test_character_uid,
		InventorySystem.InventoryType.COMMODITY,
		"commodity_ore",
		10
	)
	
	# Set player at destination
	GameState.player_docked_at = "station_beta"
	
	var initial_credits = _character_system.get_credits(_test_character_uid)
	var result = _contract_system.complete_contract(_test_character_uid, _test_contract_id)
	
	assert_true(result.success, "Complete should succeed")
	assert_eq(result.rewards.credits, 100, "Should report correct reward")
	
	# Check credits increased
	var final_credits = _character_system.get_credits(_test_character_uid)
	assert_eq(final_credits, initial_credits + 100, "Credits should increase by reward amount")
	
	# Check cargo removed
	var cargo = _inventory_system.get_inventory_by_type(_test_character_uid, InventorySystem.InventoryType.COMMODITY)
	assert_eq(cargo.get("commodity_ore", 0), 0, "Cargo should be removed")
	
	# Check contract removed from active
	assert_false(GameState.active_contracts.has(_test_contract_id), "Contract should be removed from active")
	
	# Check stats updated
	assert_eq(GameState.session_stats.contracts_completed, 1, "Contracts completed should increment")


func test_complete_contract_applies_reputation():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	_inventory_system.add_asset(
		_test_character_uid,
		InventorySystem.InventoryType.COMMODITY,
		"commodity_ore",
		10
	)
	
	# Must be at destination for delivery completion
	GameState.player_docked_at = "station_beta"
	_contract_system.complete_contract(_test_character_uid, _test_contract_id)
	
	assert_eq(GameState.narrative_state.reputation, 5, "Reputation should increase")
	assert_eq(GameState.narrative_state.faction_standings.get("test_faction", 0), 5, "Faction standing should increase")


func test_complete_contract_fails_without_cargo():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	var result = _contract_system.complete_contract(_test_character_uid, _test_contract_id)
	
	assert_false(result.success, "Complete should fail without cargo")


# --- Test: Abandon Contract ---

func test_abandon_contract_success():
	_contract_system.accept_contract(_test_character_uid, _test_contract_id)
	
	var result = _contract_system.abandon_contract(_test_character_uid, _test_contract_id)
	
	assert_true(result.success, "Abandon should succeed")
	assert_false(GameState.active_contracts.has(_test_contract_id), "Contract should be removed")


func test_abandon_contract_not_active():
	var result = _contract_system.abandon_contract(_test_character_uid, _test_contract_id)
	
	assert_false(result.success, "Abandon should fail for inactive contract")
	assert_true("not active" in result.reason.to_lower(), "Reason should mention not active")


# --- Test: Contract Expiration ---

func test_contract_expiration_check():
	# Create time-limited contract
	var limited_contract = _create_test_contract()
	limited_contract.template_id = "limited_contract"
	limited_contract.time_limit_seconds = 50
	GameState.contracts["limited_contract"] = limited_contract
	
	_contract_system.accept_contract(_test_character_uid, "limited_contract")
	
	# Advance time past limit
	GameState.game_time_seconds = 60
	
	var expired = _contract_system.check_expired_contracts(_test_character_uid)
	
	assert_eq(expired.size(), 1, "Should find 1 expired contract")
	assert_false(GameState.active_contracts.has("limited_contract"), "Expired contract should be removed")


func test_contract_not_expired_within_limit():
	var limited_contract = _create_test_contract()
	limited_contract.template_id = "limited_contract"
	limited_contract.time_limit_seconds = 50
	GameState.contracts["limited_contract"] = limited_contract
	
	_contract_system.accept_contract(_test_character_uid, "limited_contract")
	
	# Advance time but within limit
	GameState.game_time_seconds = 30
	
	var check = _contract_system.check_contract_completion(_test_character_uid, "limited_contract")
	
	# Should not be expired (though still can't complete without cargo)
	assert_false("expired" in check.reason.to_lower(), "Should not be expired yet")
