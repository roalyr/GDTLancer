# contract_system.gd
# Stateless API for contract management - accept, track, complete, abandon
extends Node

const InventorySystem = preload("res://core/systems/inventory_system.gd")
const MAX_ACTIVE_CONTRACTS = 3  # Phase 1 limit


# Get all contracts available at a specific location
func get_available_contracts(location_id: String) -> Array:
	var available = []
	for contract_id in GameState.contracts:
		var contract = GameState.contracts[contract_id]
		if contract and contract.origin_location_id == location_id:
			# Check not already active
			if not GameState.active_contracts.has(contract_id):
				available.append(contract)
	return available


# Get all contracts available at a location, filtered by player's active contracts
func get_available_contracts_for_character(char_uid: int, location_id: String) -> Array:
	var available = get_available_contracts(location_id)
	# Filter out any that player already has active
	var result = []
	for contract in available:
		if not GameState.active_contracts.has(contract.template_id):
			result.append(contract)
	return result


# Accept a contract for a character
func accept_contract(char_uid: int, contract_id: String) -> Dictionary:
	# Validate contract exists
	if not GameState.contracts.has(contract_id):
		return {
			"success": false,
			"reason": "Contract not found: " + contract_id
		}
	
	# Check not already active
	if GameState.active_contracts.has(contract_id):
		return {
			"success": false,
			"reason": "Contract already active"
		}
	
	# Check active contract limit
	var active_count = _count_active_contracts_for_character(char_uid)
	if active_count >= MAX_ACTIVE_CONTRACTS:
		return {
			"success": false,
			"reason": "Maximum active contracts reached (" + str(MAX_ACTIVE_CONTRACTS) + ")"
		}
	
	# Get contract and mark as accepted
	var contract = GameState.contracts[contract_id]
	var contract_copy = contract.duplicate(true)
	contract_copy.accepted_at_tu = GameState.current_tu
	contract_copy.progress = {"character_uid": char_uid}
	
	# Add to active contracts
	GameState.active_contracts[contract_id] = contract_copy
	
	# Emit signal
	EventBus.emit_signal("contract_accepted", char_uid, contract_copy)
	
	return {
		"success": true,
		"contract": contract_copy
	}


# Get all active contracts for a character
func get_active_contracts(char_uid: int) -> Array:
	var active = []
	for contract_id in GameState.active_contracts:
		var contract = GameState.active_contracts[contract_id]
		if contract and contract.progress.get("character_uid", -1) == char_uid:
			active.append(contract)
	return active


# Check if a contract can be completed (player has requirements)
func check_contract_completion(char_uid: int, contract_id: String) -> Dictionary:
	# Validate contract is active
	if not GameState.active_contracts.has(contract_id):
		return {
			"can_complete": false,
			"reason": "Contract not active"
		}
	
	var contract = GameState.active_contracts[contract_id]
	
	# Check ownership
	if contract.progress.get("character_uid", -1) != char_uid:
		return {
			"can_complete": false,
			"reason": "Contract belongs to different character"
		}
	
	# Check expiration
	if contract.is_expired(GameState.current_tu):
		return {
			"can_complete": false,
			"reason": "Contract has expired"
		}
	
	# Type-specific completion checks
	match contract.contract_type:
		"delivery":
			return _check_delivery_completion(char_uid, contract)
		"combat":
			return _check_combat_completion(char_uid, contract)
		_:
			return {
				"can_complete": false,
				"reason": "Unknown contract type: " + contract.contract_type
			}


# Complete a contract and apply rewards
func complete_contract(char_uid: int, contract_id: String) -> Dictionary:
	# First check if completable
	var check = check_contract_completion(char_uid, contract_id)
	if not check.can_complete:
		return {
			"success": false,
			"reason": check.reason
		}
	
	var contract = GameState.active_contracts[contract_id]
	
	# Apply completion based on type
	var completion_result = {}
	match contract.contract_type:
		"delivery":
			completion_result = _complete_delivery(char_uid, contract)
		"combat":
			completion_result = _complete_combat(char_uid, contract)
		_:
			return {
				"success": false,
				"reason": "Cannot complete unknown contract type"
			}
	
	if not completion_result.get("success", false):
		return completion_result
	
	# Apply rewards
	_apply_rewards(char_uid, contract)
	
	# Remove from active contracts
	GameState.active_contracts.erase(contract_id)
	
	# Update session stats
	GameState.session_stats.contracts_completed += 1
	
	# Emit signal
	EventBus.emit_signal("contract_completed", char_uid, contract)
	
	return {
		"success": true,
		"contract": contract,
		"rewards": {
			"wp": contract.reward_wp,
			"reputation": contract.reward_reputation,
			"items": contract.reward_items
		}
	}


# Abandon a contract (no penalty in Phase 1)
func abandon_contract(char_uid: int, contract_id: String) -> Dictionary:
	if not GameState.active_contracts.has(contract_id):
		return {
			"success": false,
			"reason": "Contract not active"
		}
	
	var contract = GameState.active_contracts[contract_id]
	
	# Check ownership
	if contract.progress.get("character_uid", -1) != char_uid:
		return {
			"success": false,
			"reason": "Contract belongs to different character"
		}
	
	# Remove from active
	GameState.active_contracts.erase(contract_id)
	
	# Emit signal
	EventBus.emit_signal("contract_abandoned", char_uid, contract)
	
	return {
		"success": true,
		"contract": contract
	}


# Check for expired contracts and handle them
func check_expired_contracts(char_uid: int) -> Array:
	var expired = []
	var to_fail = []
	
	for contract_id in GameState.active_contracts:
		var contract = GameState.active_contracts[contract_id]
		if contract.progress.get("character_uid", -1) != char_uid:
			continue
		if contract.is_expired(GameState.current_tu):
			to_fail.append(contract_id)
			expired.append(contract)
	
	# Fail expired contracts
	for contract_id in to_fail:
		_fail_contract(char_uid, contract_id)
	
	return expired


# Get contract by ID from active contracts
func get_contract(contract_id: String):
	return GameState.active_contracts.get(contract_id, null)


# ---- Private helpers ----

func _count_active_contracts_for_character(char_uid: int) -> int:
	var count = 0
	for contract_id in GameState.active_contracts:
		var contract = GameState.active_contracts[contract_id]
		if contract.progress.get("character_uid", -1) == char_uid:
			count += 1
	return count


func _check_delivery_completion(char_uid: int, contract) -> Dictionary:
	# Check player is at destination
	# For now, we check via a player_location field in GameState or skip location check
	# TODO: Implement proper location tracking in Sprint 4
	
	# Check player has required cargo
	var inventory_system = GlobalRefs.inventory_system
	if not inventory_system:
		return {
			"can_complete": false,
			"reason": "Inventory system not available"
		}
	
	var cargo = inventory_system.get_inventory_by_type(char_uid, InventorySystem.InventoryType.COMMODITY)
	var owned_qty = cargo.get(contract.required_commodity_id, 0)
	
	if owned_qty < contract.required_quantity:
		return {
			"can_complete": false,
			"reason": "Insufficient cargo: need " + str(contract.required_quantity) + " " + contract.required_commodity_id + ", have " + str(owned_qty)
		}
	
	return {
		"can_complete": true,
		"reason": ""
	}


func _check_combat_completion(char_uid: int, contract) -> Dictionary:
	# Check kill count in progress
	var kills = contract.progress.get("kills", 0)
	if kills < contract.target_count:
		return {
			"can_complete": false,
			"reason": "Targets remaining: " + str(contract.target_count - kills)
		}
	
	return {
		"can_complete": true,
		"reason": ""
	}


func _complete_delivery(char_uid: int, contract) -> Dictionary:
	# Remove cargo from player inventory
	var inventory_system = GlobalRefs.inventory_system
	if not inventory_system:
		return {
			"success": false,
			"reason": "Inventory system not available"
		}
	
	var removed = inventory_system.remove_asset(
		char_uid,
		InventorySystem.InventoryType.COMMODITY,
		contract.required_commodity_id,
		contract.required_quantity
	)
	
	if not removed:
		return {
			"success": false,
			"reason": "Failed to remove cargo from inventory"
		}
	
	return {"success": true}


func _complete_combat(char_uid: int, contract) -> Dictionary:
	# Combat contracts just need kill count met, no additional action
	return {"success": true}


func _apply_rewards(char_uid: int, contract) -> void:
	# Apply WP reward
	var character_system = GlobalRefs.character_system
	if character_system and contract.reward_wp > 0:
		character_system.add_wp(char_uid, contract.reward_wp)
		GameState.session_stats.total_wp_earned += contract.reward_wp
	
	# Apply reputation
	if contract.reward_reputation != 0:
		var current_rep = GameState.narrative_state.get("reputation", 0)
		GameState.narrative_state.reputation = current_rep + contract.reward_reputation
		
		# Track faction standing if faction specified
		if contract.faction_id != "":
			var standings = GameState.narrative_state.get("faction_standings", {})
			var current_faction_rep = standings.get(contract.faction_id, 0)
			standings[contract.faction_id] = current_faction_rep + contract.reward_reputation
			GameState.narrative_state.faction_standings = standings
	
	# Apply item rewards
	var inventory_system = GlobalRefs.inventory_system
	if inventory_system:
		for item_id in contract.reward_items:
			var qty = contract.reward_items[item_id]
			# Determine item type from template
			var template = TemplateDatabase.get_template(item_id)
			if template:
				var asset_type = InventorySystem.InventoryType.COMMODITY  # Default
				if template.template_type == "module":
					asset_type = InventorySystem.InventoryType.MODULE
				inventory_system.add_asset(char_uid, asset_type, item_id, qty)


func _fail_contract(char_uid: int, contract_id: String) -> void:
	var contract = GameState.active_contracts.get(contract_id)
	if not contract:
		return
	
	# Remove from active
	GameState.active_contracts.erase(contract_id)
	
	# Emit failure signal
	EventBus.emit_signal("contract_failed", char_uid, contract)
