# PROJECT: GDTLancer
# MODULE: asset_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TRUTH_EXPLORATION-PILLARS.md § 3, § 9
# LOG_REF: 2026-07-26 03:30:00

extends Node
class_name AssetSystem


var AssetCardClass = load("res://src/core/cards/asset_card.gd")
var registered_cards: Dictionary = {}

func _ready():
	GlobalRefs.set_asset_system(self)
	load_card_corpus()
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("AssetSystem Ready. Registered cards: ", registered_cards.size())

# --- Public Card API ---

func register_card(card: Resource) -> void:
	if card == null:
		return
	var c_id = card.get("card_id") if "card_id" in card else ""
	if c_id.empty():
		c_id = card.resource_name
	if not c_id.empty():
		registered_cards[c_id] = card

func get_card(card_id: String) -> Resource:
	return registered_cards.get(card_id, null)

func get_cards_by_tag(tag: String) -> Array:
	var result: Array = []
	for card in registered_cards.values():
		if card.has_method("has_tag") and card.has_tag(tag):
			result.append(card)
		elif "tags" in card and card.tags is Array and tag.to_lower() in card.tags:
			result.append(card)
	return result

func get_cards_by_verb(verb: String) -> Array:
	var result: Array = []
	for card in registered_cards.values():
		if "unlocked_verbs" in card and card.unlocked_verbs is Array:
			for v in card.unlocked_verbs:
				if String(v).to_lower() == verb.to_lower():
					result.append(card)
					break
	return result

func load_card_corpus(dir_path: String = "res://database/registry/cards/assets") -> int:
	var dir = Directory.new()
	if dir.open(dir_path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = dir_path + "/" + file_name
				var card_res = load(full_path)
				if card_res != null:
					register_card(card_res)
			file_name = dir.get_next()
		dir.list_dir_end()
	return registered_cards.size()

func validate_all_cards() -> Array:
	var errors: Array = []
	for card_id in registered_cards:
		var card = registered_cards[card_id]
		if card.has_method("validate_trade_offs"):
			if not card.validate_trade_offs():
				errors.append("Card " + card_id + " failed trade-off validation (missing gained/surrendered tags).")
	return errors

# --- Legacy Ship / Asset API ---

func get_ship(ship_uid: int) -> ShipTemplate:
	return GameState.assets_ships.get(ship_uid)

func get_player_ship() -> ShipTemplate:
	var player_char = GlobalRefs.character_system.get_player_character()
	if not is_instance_valid(player_char):
		return null
	if player_char.active_ship_uid != -1:
		return get_ship(player_char.active_ship_uid)
	return null

func get_ship_for_character(character_uid) -> ShipTemplate:
	if not GameState.characters.has(character_uid):
		return null
	var character = GameState.characters[character_uid]
	if not is_instance_valid(character):
		return null
	var ship_uid = character.get("active_ship_uid") if character is Dictionary else character.active_ship_uid
	if ship_uid != null and ship_uid != -1:
		return get_ship(ship_uid)
	return null

func get_ships_for_character(character_uid: int) -> Array:
	var ships = []
	if not is_instance_valid(GlobalRefs.inventory_system):
		return ships
	var ship_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		character_uid, 
		GlobalRefs.inventory_system.InventoryType.SHIP
	)
	for ship_uid in ship_inventory.keys():
		var ship = get_ship(ship_uid)
		if is_instance_valid(ship):
			ships.append(ship)
	return ships