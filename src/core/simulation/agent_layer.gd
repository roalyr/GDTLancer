#
# PROJECT: GDTLancer
# MODULE: agent_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 4 (Agent Layer), Section 7 (Tick Sequence steps 4a–4c)
# LOG_REF: 2026-02-13
#

extends Reference

## AgentLayer: Processes all Agent-layer logic for one simulation tick.
##
## The Agent Layer holds COGNITIVE entities — NPCs and the player — each with
## their own knowledge snapshot, goal queue, and resource state. NPCs make
## autonomous decisions based on their (possibly stale) view of the grid.
##
## Processing (GDD Section 7, steps 4a–4c):
##   4a. NPC Goal Evaluation — re-evaluate goals from known_grid_state
##   4b. NPC Action Selection — execute highest-priority feasible action
##   4c. Player — skip (player acts in real-time)
##
## Also handles persistent agent respawn and hostile population tracking.


# UID counter for generating unique identifiers
var _next_uid: int = 1000


# =============================================================================
# === INITIALIZATION ==========================================================
# =============================================================================

## Seeds all Agent Layer state in GameState from AgentTemplate and CharacterTemplate .tres files.
## Called once at game start, after GridLayer.initialize_grid().
func initialize_agents() -> void:
	GameState.agents.clear()
	GameState.characters.clear()
	GameState.inventories.clear()
	GameState.assets_ships.clear()
	GameState.hostile_population_integral.clear()

	# --- Player Agent ---
	_initialize_player()

	# --- Persistent NPC Agents ---
	for agent_id in TemplateDatabase.agents:
		var agent_template: Resource = TemplateDatabase.agents[agent_id]
		if not is_instance_valid(agent_template):
			continue
		# Skip the player template — already handled
		if agent_template.agent_type == "player":
			continue
		# Only initialize persistent agents at game start
		# Non-persistent NPCs are spawned dynamically by scene systems
		if agent_template.is_persistent:
			_initialize_persistent_agent(agent_id, agent_template)

	# --- Hostile Population Integral ---
	_initialize_hostile_population()

	print("AgentLayer: Initialized %d agents (%d persistent NPCs + player)." % [
		GameState.agents.size(),
		GameState.agents.size() - 1  # Minus the player
	])


## Initializes the player agent from player_default template + character_default.
func _initialize_player() -> void:
	var char_uid: int = _generate_uid()
	GameState.player_character_uid = char_uid

	# Load character template
	var char_template: Resource = null
	if TemplateDatabase.characters.has("character_default"):
		char_template = TemplateDatabase.characters["character_default"]

	# Store character instance reference
	if char_template != null:
		GameState.characters[char_uid] = char_template

	# Determine starting location — default to first location in topology
	var start_sector: String = ""
	for sector_id in GameState.world_topology:
		var topology: Dictionary = GameState.world_topology[sector_id]
		if topology.get("sector_type", "") == "hub":
			start_sector = sector_id
			break
	if start_sector == "" and not GameState.world_topology.empty():
		start_sector = GameState.world_topology.keys()[0]

	var starting_credits: int = 10000
	if char_template != null:
		starting_credits = char_template.credits

	# Build agent state dictionary (matches GameState.agents schema)
	GameState.agents["player"] = _create_agent_state(
		char_uid,
		start_sector,
		starting_credits,
		false,  # is_persistent — player is special
		"",     # home_location_id — player has no home
		"idle"  # goal_archetype
	)

	# Initialize empty inventory for player
	GameState.inventories[char_uid] = {}


## Initializes a persistent NPC agent from its AgentTemplate + linked CharacterTemplate.
func _initialize_persistent_agent(agent_id: String, agent_template: Resource) -> void:
	var char_uid: int = _generate_uid()

	# Load linked character template
	var char_template_id: String = agent_template.character_template_id
	var char_template: Resource = null
	if TemplateDatabase.characters.has(char_template_id):
		char_template = TemplateDatabase.characters[char_template_id]

	if char_template != null:
		GameState.characters[char_uid] = char_template

	# Determine starting sector from home_location_id
	var home_location: String = agent_template.home_location_id
	var start_sector: String = home_location if GameState.world_topology.has(home_location) else ""
	if start_sector == "" and not GameState.world_topology.empty():
		start_sector = GameState.world_topology.keys()[0]

	var starting_credits: int = 5000
	if char_template != null:
		starting_credits = char_template.credits

	# Determine initial goal archetype from personality
	var goal_archetype: String = _derive_initial_goal(char_template)

	# Build agent state
	GameState.agents[agent_id] = _create_agent_state(
		char_uid,
		start_sector,
		starting_credits,
		true,           # is_persistent
		home_location,  # home_location_id
		goal_archetype
	)

	# Initialize empty inventory
	GameState.inventories[char_uid] = {}

	# Legacy compatibility — keep persistent_agents alias populated
	GameState.persistent_agents[agent_id] = GameState.agents[agent_id]


## Initializes hostile population tracking from grid pirate_activity values.
func _initialize_hostile_population() -> void:
	# Phase 1: Single hostile type — "pirates"
	var total_piracy: float = 0.0
	var sector_counts: Dictionary = {}

	for sector_id in GameState.grid_dominion:
		var dominion: Dictionary = GameState.grid_dominion[sector_id]
		var piracy: float = dominion.get("pirate_activity", 0.0)
		total_piracy += piracy
		sector_counts[sector_id] = int(piracy * 10.0)  # Scale to count

	# Carrying capacity = function of total piracy across all sectors
	var carrying_capacity: int = int(total_piracy * 20.0)
	carrying_capacity = max(carrying_capacity, 5)  # Minimum viable population

	GameState.hostile_population_integral["pirates"] = {
		"current_count": int(total_piracy * 10.0),
		"carrying_capacity": carrying_capacity,
		"sector_counts": sector_counts
	}


# =============================================================================
# === TICK PROCESSING =========================================================
# =============================================================================

## Processes all Agent-layer logic for one tick (GDD Section 7, steps 4a–4c).
##
## @param config  Dictionary — tuning constants.
func process_tick(config: Dictionary) -> void:
	# --- Step 4a + 4b: NPC Goal Evaluation & Action Selection ---
	for agent_id in GameState.agents:
		if agent_id == "player":
			continue  # Step 4c: Player acts in real-time, skip

		var agent: Dictionary = GameState.agents[agent_id]

		# Skip disabled agents (awaiting respawn)
		if agent.get("is_disabled", false):
			_check_respawn(agent_id, agent, config)
			continue

		# 4a. Re-evaluate goals based on known_grid_state
		_evaluate_goals(agent_id, agent, config)

		# 4b. Execute highest-priority feasible action
		_execute_action(agent_id, agent, config)

	# --- Persistent Agent Respawn (already checked inline above) ---

	# --- Hostile Population Tracking ---
	_update_hostile_population(config)


# =============================================================================
# === PRIVATE — GOAL EVALUATION (Step 4a) =====================================
# =============================================================================

## Re-evaluates an NPC's goal queue based on their known grid state.
## Phase 1: Simple heuristic — if cash low, trade. If damaged, repair. Else idle.
func _evaluate_goals(agent_id: String, agent: Dictionary, config: Dictionary) -> void:
	var goal_queue: Array = agent.get("goal_queue", [])
	var cash: float = agent.get("cash_reserves", 0.0)
	var hull: float = agent.get("hull_integrity", 1.0)

	var cash_threshold: float = config.get("npc_cash_low_threshold", 2000.0)
	var hull_threshold: float = config.get("npc_hull_repair_threshold", 0.5)

	# Priority order: repair > trade > idle
	var new_goals: Array = []

	if hull < hull_threshold:
		new_goals.append({"type": "repair", "priority": 3})
		agent["goal_archetype"] = "repair"
	elif cash < cash_threshold:
		new_goals.append({"type": "trade", "priority": 2})
		agent["goal_archetype"] = "trade"
	else:
		new_goals.append({"type": "idle", "priority": 1})
		agent["goal_archetype"] = "idle"

	agent["goal_queue"] = new_goals


# =============================================================================
# === PRIVATE — ACTION EXECUTION (Step 4b) ====================================
# =============================================================================

## Executes the highest-priority feasible action for an NPC.
## Phase 1: Abstract state changes only — no scene-tree interaction.
func _execute_action(agent_id: String, agent: Dictionary, config: Dictionary) -> void:
	var goal_queue: Array = agent.get("goal_queue", [])
	if goal_queue.empty():
		return

	# Sort by priority (highest first)
	# Phase 1: only one goal at a time, so just use [0]
	var current_goal: Dictionary = goal_queue[0]
	var goal_type: String = current_goal.get("type", "idle")

	match goal_type:
		"trade":
			_action_trade(agent_id, agent, config)
		"repair":
			_action_repair(agent_id, agent, config)
		"idle":
			pass  # Do nothing — agent stays put


## Trade action: find best buy/sell opportunity, move if needed, execute trade.
## Phase 1: simplified — buy cheapest commodity at current location, move to
## best sell location, sell there next tick.
func _action_trade(agent_id: String, agent: Dictionary, config: Dictionary) -> void:
	var current_sector: String = agent.get("current_sector_id", "")
	var known_grid: Dictionary = agent.get("known_grid_state", {})
	var cash: float = agent.get("cash_reserves", 0.0)

	# Check if we have cargo to sell
	var char_uid: int = agent.get("char_uid", -1)
	var has_cargo: bool = _agent_has_cargo(char_uid)

	if has_cargo:
		# Try to sell at current location
		_action_sell(agent_id, agent, current_sector)
	elif cash > 0.0:
		# Try to buy at current location
		var bought: bool = _action_buy(agent_id, agent, current_sector, config)
		if not bought:
			# No good deals here — move to a connected sector
			_action_move_random(agent_id, agent)
	else:
		# No cash, no cargo — idle until something changes
		pass


## Repair action: move toward home sector if not there, then repair.
func _action_repair(agent_id: String, agent: Dictionary, _config: Dictionary) -> void:
	var current_sector: String = agent.get("current_sector_id", "")
	var home_sector: String = agent.get("home_location_id", "")

	if current_sector == home_sector or home_sector == "":
		# At home (or no home) — repair hull
		var repair_amount: float = 0.1  # 10% per tick
		agent["hull_integrity"] = min(1.0, agent.get("hull_integrity", 1.0) + repair_amount)
	else:
		# Move toward home
		_action_move_toward(agent_id, agent, home_sector)


## Buy cheapest commodity available at sector.
func _action_buy(agent_id: String, agent: Dictionary, sector_id: String, config: Dictionary) -> bool:
	if not GameState.grid_stockpiles.has(sector_id):
		return false

	var stockpiles: Dictionary = GameState.grid_stockpiles[sector_id]
	var commodities: Dictionary = stockpiles.get("commodity_stockpiles", {})
	var market: Dictionary = GameState.grid_market.get(sector_id, {})
	var price_deltas: Dictionary = market.get("commodity_price_deltas", {})

	# Find cheapest commodity (lowest price delta = best buy)
	var best_commodity: String = ""
	var best_delta: float = INF
	for commodity_id in commodities:
		if commodities[commodity_id] <= 0.0:
			continue  # No stock
		var delta: float = price_deltas.get(commodity_id, 0.0)
		if delta < best_delta:
			best_delta = delta
			best_commodity = commodity_id

	if best_commodity == "":
		return false

	# Buy up to affordable amount (Phase 1: buy 10 units or what we can afford)
	var base_price: float = config.get("commodity_base_price", 10.0)
	var actual_price: float = max(1.0, base_price + best_delta)
	var affordable: int = int(agent.get("cash_reserves", 0.0) / actual_price)
	var available: int = int(commodities[best_commodity])
	var buy_amount: int = min(min(affordable, available), 10)

	if buy_amount <= 0:
		return false

	# Execute purchase: deduct cash, add to inventory, deduct from stockpile
	var total_cost: float = float(buy_amount) * actual_price
	agent["cash_reserves"] = agent.get("cash_reserves", 0.0) - total_cost
	commodities[best_commodity] -= float(buy_amount)

	# Add to agent inventory (InventoryType.COMMODITY = 2)
	var char_uid: int = agent.get("char_uid", -1)
	if not GameState.inventories.has(char_uid):
		GameState.inventories[char_uid] = {}
	if not GameState.inventories[char_uid].has(2):
		GameState.inventories[char_uid][2] = {}
	var inv: Dictionary = GameState.inventories[char_uid][2]
	inv[best_commodity] = inv.get(best_commodity, 0.0) + float(buy_amount)

	return true


## Sell all cargo at current sector.
func _action_sell(agent_id: String, agent: Dictionary, sector_id: String) -> void:
	var char_uid: int = agent.get("char_uid", -1)
	if not GameState.inventories.has(char_uid):
		return
	if not GameState.inventories[char_uid].has(2):
		return

	var inv: Dictionary = GameState.inventories[char_uid][2]
	if inv.empty():
		return

	var market: Dictionary = GameState.grid_market.get(sector_id, {})
	var price_deltas: Dictionary = market.get("commodity_price_deltas", {})
	var stockpiles: Dictionary = GameState.grid_stockpiles.get(sector_id, {})
	var commodities: Dictionary = stockpiles.get("commodity_stockpiles", {})

	# Sell everything in cargo
	var total_revenue: float = 0.0
	for commodity_id in inv.keys():
		var quantity: float = inv[commodity_id]
		if quantity <= 0.0:
			continue

		var base_price: float = 10.0  # Phase 1 default
		var delta: float = price_deltas.get(commodity_id, 0.0)
		var sell_price: float = max(1.0, base_price + delta)
		total_revenue += quantity * sell_price

		# Return commodities to sector stockpile (matter conservation)
		commodities[commodity_id] = commodities.get(commodity_id, 0.0) + quantity
		inv[commodity_id] = 0.0

	agent["cash_reserves"] = agent.get("cash_reserves", 0.0) + total_revenue

	# Clean up zero entries
	for commodity_id in inv.keys():
		if inv[commodity_id] <= 0.0:
			inv.erase(commodity_id)


## Move agent to a random connected sector.
func _action_move_random(agent_id: String, agent: Dictionary) -> void:
	var current_sector: String = agent.get("current_sector_id", "")
	if not GameState.world_topology.has(current_sector):
		return

	var connections: Array = GameState.world_topology[current_sector].get("connections", [])
	if connections.empty():
		return

	# Pick a random connected sector
	var target: String = connections[randi() % connections.size()]
	agent["current_sector_id"] = target


## Move agent one hop toward a target sector (simple greedy pathfinding).
## Phase 1: if target is a direct neighbor, go there. Otherwise pick random neighbor.
func _action_move_toward(agent_id: String, agent: Dictionary, target_sector: String) -> void:
	var current_sector: String = agent.get("current_sector_id", "")
	if current_sector == target_sector:
		return

	if not GameState.world_topology.has(current_sector):
		return

	var connections: Array = GameState.world_topology[current_sector].get("connections", [])
	if connections.empty():
		return

	# Direct neighbor?
	if target_sector in connections:
		agent["current_sector_id"] = target_sector
		return

	# Not a direct neighbor — pick random connection (Phase 1: no real pathfinding)
	agent["current_sector_id"] = connections[randi() % connections.size()]


# =============================================================================
# === PRIVATE — RESPAWN =======================================================
# =============================================================================

## Checks if a disabled persistent agent should respawn.
## Respawn condition: enough ticks elapsed since disabled_at_tick.
func _check_respawn(agent_id: String, agent: Dictionary, config: Dictionary) -> void:
	if not agent.get("is_persistent", false):
		return

	var disabled_at: int = agent.get("disabled_at_tick", 0)
	var current_tick: int = GameState.sim_tick_count

	# Convert respawn_timeout_seconds to ticks
	var tick_interval: float = config.get("world_tick_interval_seconds", 60.0)
	var respawn_timeout: float = config.get("respawn_timeout_seconds", 300.0)
	var respawn_ticks: int = int(respawn_timeout / tick_interval) if tick_interval > 0.0 else 5

	if (current_tick - disabled_at) >= respawn_ticks:
		# Respawn at home sector
		agent["is_disabled"] = false
		agent["disabled_at_tick"] = 0
		agent["hull_integrity"] = 1.0
		agent["current_sector_id"] = agent.get("home_location_id", "")
		agent["propellant_reserves"] = 100.0
		agent["energy_reserves"] = 100.0
		agent["consumables_reserves"] = 100.0
		agent["goal_queue"] = [{"type": "idle", "priority": 1}]
		agent["goal_archetype"] = "idle"

		print("AgentLayer: %s respawned at %s (tick %d)" % [
			agent_id, agent["current_sector_id"], current_tick
		])


# =============================================================================
# === PRIVATE — HOSTILE POPULATION ============================================
# =============================================================================

## Updates the hostile population integral based on grid pirate_activity values.
## Population grows toward carrying capacity, shrinks if over it.
func _update_hostile_population(config: Dictionary) -> void:
	var growth_rate: float = config.get("hostile_growth_rate", 0.05)

	for hostile_type in GameState.hostile_population_integral:
		var pop_data: Dictionary = GameState.hostile_population_integral[hostile_type]
		var current_count: int = pop_data.get("current_count", 0)
		var sector_counts: Dictionary = pop_data.get("sector_counts", {})

		# Recalculate carrying capacity from current pirate_activity
		var total_piracy: float = 0.0
		for sector_id in GameState.grid_dominion:
			var dominion: Dictionary = GameState.grid_dominion[sector_id]
			var piracy: float = dominion.get("pirate_activity", 0.0)
			total_piracy += piracy

		var carrying_capacity: int = max(5, int(total_piracy * 20.0))
		pop_data["carrying_capacity"] = carrying_capacity

		# Logistic growth: population grows toward carrying capacity
		var delta: float = growth_rate * float(current_count) * (1.0 - float(current_count) / float(max(carrying_capacity, 1)))
		var new_count: int = max(0, current_count + int(round(delta)))
		pop_data["current_count"] = new_count

		# Distribute population across sectors proportional to pirate_activity
		sector_counts.clear()
		if total_piracy > 0.0 and new_count > 0:
			for sector_id in GameState.grid_dominion:
				var dominion: Dictionary = GameState.grid_dominion[sector_id]
				var piracy: float = dominion.get("pirate_activity", 0.0)
				var sector_share: int = int(float(new_count) * (piracy / total_piracy))
				if sector_share > 0:
					sector_counts[sector_id] = sector_share
		pop_data["sector_counts"] = sector_counts


# =============================================================================
# === PRIVATE — HELPERS =======================================================
# =============================================================================

## Creates a standard agent state dictionary matching GameState.agents schema.
func _create_agent_state(
	char_uid: int,
	sector_id: String,
	cash: float,
	is_persistent: bool,
	home_location_id: String,
	goal_archetype: String
) -> Dictionary:
	return {
		"char_uid": char_uid,
		"current_sector_id": sector_id,
		"hull_integrity": 1.0,
		"propellant_reserves": 100.0,
		"energy_reserves": 100.0,
		"consumables_reserves": 100.0,
		"cash_reserves": cash,
		"fleet_ships": [],
		"current_heat_level": 0.0,
		"is_persistent": is_persistent,
		"home_location_id": home_location_id,
		"is_disabled": false,
		"disabled_at_tick": 0,
		"known_grid_state": _snapshot_grid_state(),
		"knowledge_timestamps": _create_knowledge_timestamps(),
		"goal_queue": [{"type": goal_archetype, "priority": 1}],
		"goal_archetype": goal_archetype,
		"event_memory": [],
		"faction_standings": {},
		"character_standings": {},
		"sentiment_tags": []
	}


## Creates a snapshot of the current grid state for agent knowledge.
## Phase 1: perfect knowledge — exact copy of all grid data.
func _snapshot_grid_state() -> Dictionary:
	var snapshot: Dictionary = {}
	for sector_id in GameState.grid_dominion:
		snapshot[sector_id] = {
			"dominion": GameState.grid_dominion.get(sector_id, {}).duplicate(true),
			"market": GameState.grid_market.get(sector_id, {}).duplicate(true),
			"stockpiles": GameState.grid_stockpiles.get(sector_id, {}).duplicate(true)
		}
	return snapshot


## Creates initial knowledge timestamps (tick of last observation per sector).
func _create_knowledge_timestamps() -> Dictionary:
	var timestamps: Dictionary = {}
	for sector_id in GameState.world_topology:
		timestamps[sector_id] = GameState.sim_tick_count
	return timestamps


## Derives initial goal archetype from character personality traits.
func _derive_initial_goal(char_template: Resource) -> String:
	if char_template == null:
		return "idle"

	var traits: Dictionary = char_template.get("personality_traits") if char_template.get("personality_traits") != null else {}
	var greed: float = traits.get("greed", 0.5)

	# Higher greed → start as trader
	if greed >= 0.5:
		return "trade"
	return "idle"


## Checks if an agent has any cargo in their commodity inventory.
func _agent_has_cargo(char_uid: int) -> bool:
	if not GameState.inventories.has(char_uid):
		return false
	if not GameState.inventories[char_uid].has(2):  # InventoryType.COMMODITY
		return false
	var inv: Dictionary = GameState.inventories[char_uid][2]
	for commodity_id in inv:
		if float(inv[commodity_id]) > 0.0:
			return true
	return false


## Generates a unique ID and increments the counter.
func _generate_uid() -> int:
	var uid: int = _next_uid
	_next_uid += 1
	return uid
