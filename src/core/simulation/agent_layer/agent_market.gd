# PROJECT: GDTLancer
# MODULE: agent_market.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-REVISION-LEDGER.md REV_007; GDD-REVISION-LEDGER.md REV_008; TRUTH_SIMULATION-GRAPH.md §2.2.1; TRUTH_PROJECT.md § Agent Parity Principle
# LOG_REF: 2026-06-12 23:12:22

extends Reference

var _agent_layer: Reference

func initialize(agent_layer_ref: Reference) -> void:
	_agent_layer = agent_layer_ref

func _can_agent_trade_at_location(agent: Dictionary, location_id: String) -> bool:
	var tags: Array = agent.get("sentiment_tags", [])
	var legality: String = _agent_layer._agent_legality_tag(tags)

	var can_use_lawful: bool = _agent_layer._location_offers_service(location_id, "trade") and legality != "LEGAL_ILLICIT"
	var can_use_black_market: bool = _agent_layer._location_offers_service(location_id, "black_market") and legality != "LEGAL_LAWFUL"

	return can_use_lawful or can_use_black_market

func _can_agent_trade_commodity(agent: Dictionary, commodity_id: String, location_id: String) -> bool:
	var is_illegal: bool = commodity_id in Constants.ILLEGAL_COMMODITIES
	var tags: Array = agent.get("sentiment_tags", [])
	var legality: String = _agent_layer._agent_legality_tag(tags)
	var is_pirate: bool = agent.get("agent_role") == "pirate" or "PIRATE" in tags
	var has_illicit_cargo: bool = "ILLICIT_CARGO" in agent.get("agent_tags", []) or "ILLICIT_CARGO" in tags
	var is_stance_illicit: bool = int(agent.get("legality_stance", 0)) < 0

	var can_use_lawful = _agent_layer._location_offers_service(location_id, "trade")
	var can_use_black_market = _agent_layer._location_offers_service(location_id, "black_market")

	if is_illegal:
		var agent_allows_black = (legality != "LEGAL_LAWFUL" or is_pirate or has_illicit_cargo or is_stance_illicit)
		return can_use_black_market and agent_allows_black
	else:
		var ok_lawful = can_use_lawful and (legality != "LEGAL_ILLICIT" and not is_pirate and not is_stance_illicit)
		var ok_black = can_use_black_market and (legality != "LEGAL_LAWFUL" or is_pirate or has_illicit_cargo or is_stance_illicit)
		return ok_lawful or ok_black

func _attempt_npc_market_sell(agent_id: String, agent: Dictionary, sector_id: String) -> bool:
	var location_id := sector_id
	if not GameState.locations.has(location_id) and GameState.locations.has("station_" + sector_id):
		location_id = "station_" + sector_id

	if not _can_agent_trade_at_location(agent, location_id):
		return false
	if agent.get("cargo_tag", "EMPTY") != "LOADED":
		return false
	if _agent_layer._has_protected_contract_cargo(agent, agent.get("sentiment_tags", [])):
		return false

	var location_record = GameState.locations.get(location_id, null)
	if location_record == null:
		return false

	var market_inventory: Dictionary = {}
	if location_record is Dictionary:
		market_inventory = location_record.get("market_inventory", {})
	elif location_record is Object and "market_inventory" in location_record:
		market_inventory = location_record.market_inventory

	if market_inventory.empty():
		return false

	var commodity_id = ""
	if agent.has("cargo_commodity_id") and str(agent["cargo_commodity_id"]) != "":
		commodity_id = str(agent["cargo_commodity_id"])
	else:
		var potential_commodities: Array = []
		for key in Constants.COMMODITY_CLASSIFICATION:
			if key != "commodity_default" and _can_agent_trade_commodity(agent, key, location_id):
				potential_commodities.append(key)
		potential_commodities.sort()
		if not potential_commodities.empty():
			var idx: int = _agent_layer._rng.randi() % potential_commodities.size()
			commodity_id = potential_commodities[idx]

	if commodity_id == "" or not _can_agent_trade_commodity(agent, commodity_id, location_id):
		return false

	if not market_inventory.has(commodity_id):
		market_inventory[commodity_id] = {
			"quantity": 0,
			"buy_price": 50,
			"sell_price": 40
		}

	# Mutate market quantity
	market_inventory[commodity_id]["quantity"] += 1

	# Mutate agent cargo and wealth
	agent["cargo_tag"] = "EMPTY"
	if agent.has("cargo_commodity_id"):
		agent.erase("cargo_commodity_id")
	_agent_layer._wealth_step_up(agent)

	# Log NPC dock-trade event
	_agent_layer._log_event(agent_id, "npc_dock_trade", sector_id, {
		"commodity_id": commodity_id,
		"price": 0, # NOTE: GDD REVISION - Numeric price is now dummy/abstract
		"quantity": market_inventory[commodity_id]["quantity"],
		"action_type": "sell"
	})

	return true

func _attempt_npc_market_buy(agent_id: String, agent: Dictionary, sector_id: String) -> bool:
	var location_id := sector_id
	if not GameState.locations.has(location_id) and GameState.locations.has("station_" + sector_id):
		location_id = "station_" + sector_id

	if not _can_agent_trade_at_location(agent, location_id):
		return false
	if agent.get("cargo_tag", "EMPTY") != "EMPTY":
		return false
	if agent.get("wealth_tag", "COMFORTABLE") == "BROKE":
		return false

	var location_record = GameState.locations.get(location_id, null)
	if location_record == null:
		return false

	var market_inventory: Dictionary = {}
	if location_record is Dictionary:
		market_inventory = location_record.get("market_inventory", {})
	elif location_record is Object and "market_inventory" in location_record:
		market_inventory = location_record.market_inventory

	if market_inventory.empty():
		return false

	var available_commodities: Array = []
	for comm_id in market_inventory:
		if int(market_inventory[comm_id].get("quantity", 0)) > 0 and _can_agent_trade_commodity(agent, comm_id, location_id):
			available_commodities.append(comm_id)
	available_commodities.sort()

	var bought_commodity_id = ""
	if not available_commodities.empty():
		var idx: int = _agent_layer._rng.randi() % available_commodities.size()
		bought_commodity_id = available_commodities[idx]

	if bought_commodity_id == "" or not _can_agent_trade_commodity(agent, bought_commodity_id, location_id):
		return false

	# Mutate market quantity
	market_inventory[bought_commodity_id]["quantity"] -= 1

	# Mutate agent cargo and wealth
	agent["cargo_tag"] = "LOADED"
	agent["cargo_commodity_id"] = bought_commodity_id
	_agent_layer._wealth_step_down(agent)

	# Log NPC dock-trade event
	_agent_layer._log_event(agent_id, "npc_dock_trade", sector_id, {
		"commodity_id": bought_commodity_id,
		"price": 0, # NOTE: GDD REVISION - Numeric price is now dummy/abstract
		"quantity": market_inventory[bought_commodity_id]["quantity"],
		"action_type": "buy"
	})

	return true

func _process_market_restock() -> void:
	for location_id in GameState.locations:
		var entry = GameState.locations[location_id]
		if entry is Dictionary:
			var market_inv = entry.get("market_inventory")
			if market_inv is Dictionary:
				var sector_id: String = str(entry.get("sector_id", ""))
				if sector_id == "" and location_id.begins_with("station_"):
					sector_id = location_id.replace("station_", "")
				if sector_id == "":
					sector_id = location_id
				var sector_tags: Array = GameState.sector_tags.get(sector_id, [])
				
				for commodity_id in market_inv:
					var comm_data = market_inv[commodity_id]
					if comm_data is Dictionary:
						var quantity = int(comm_data.get("quantity", 0))
						var category: String = Constants.COMMODITY_CLASSIFICATION.get(commodity_id, "RAW")
						var level: String = Constants.get_economy_level_for_category(sector_tags, category)
						var baseline: int = Constants.get_tag_aware_baseline_quantity(category, level)
						
						if quantity < baseline:
							comm_data["quantity"] = int(min(quantity + Constants.MARKET_RESTOCK_RATE_PER_TICK, baseline))
		elif entry is Object:
			# Guard: do not crash. Access .market_inventory safely if present but do not mutate.
			if "market_inventory" in entry:
				var _unused_market_inv = entry.market_inventory