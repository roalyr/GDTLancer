# File: core/systems/inventory_system.gd
# Purpose: Provides a logical API for manipulating character inventories in GameState.
# This system is STATELESS.
# Version: 3.0 - Refactored for new asset types.

extends Node

func _ready():
	GlobalRefs.set_inventory_system(self)
	print("InventorySystem Ready.")

# --- Public API for Commodities ---

func add_commodity(character_uid: int, commodity_template_id: String, quantity: int):
	if not GameState.characters.has(character_uid):
		printerr("InventorySystem: Character UID not found: ", character_uid)
		return

	var character = GameState.characters[character_uid]
	if character.inventory_commodities.has(commodity_template_id):
		character.inventory_commodities[commodity_template_id] += quantity
	else:
		character.inventory_commodities[commodity_template_id] = quantity

func remove_commodity(character_uid: int, commodity_template_id: String, quantity: int) -> bool:
	if not GameState.characters.has(character_uid):
		return false

	var character = GameState.characters[character_uid]
	if character.inventory_commodities.has(commodity_template_id):
		var current_amount = character.inventory_commodities[commodity_template_id]
		if quantity > current_amount:
			return false # Cannot remove more than they have

		character.inventory_commodities[commodity_template_id] -= quantity
		if character.inventory_commodities[commodity_template_id] <= 0:
			character.inventory_commodities.erase(commodity_template_id)
		return true
	return false # Did not have any of that commodity

func get_commodity_count(character_uid: int, commodity_template_id: String) -> int:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].inventory_commodities.get(commodity_template_id, 0)
	return 0

# --- Public API for Modules ---

func add_module(character_uid: int, module_uid: int):
	if not GameState.characters.has(character_uid) or not GameState.assets_modules.has(module_uid):
		return

	var character = GameState.characters[character_uid]
	var module_instance = GameState.assets_modules[module_uid]
	character.inventory_modules[module_uid] = module_instance

func remove_module(character_uid: int, module_uid: int):
	if GameState.characters.has(character_uid):
		GameState.characters[character_uid].inventory_modules.erase(module_uid)

func get_character_modules(character_uid: int) -> Dictionary:
	if GameState.characters.has(character_uid):
		return GameState.characters[character_uid].inventory_modules.duplicate(true)
	return {}
