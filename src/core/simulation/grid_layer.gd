#
# PROJECT: GDTLancer
# MODULE: grid_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 3 (Grid Layer), Section 7 (Tick Sequence steps 2a–2g)
# LOG_REF: 2026-02-13
#

extends Reference

## GridLayer: Processes all Grid-layer CA steps for one simulation tick.
##
## The Grid Layer holds DYNAMIC per-sector state that evolves every tick:
##   - Stockpiles (commodity quantities, extraction from World deposits)
##   - Dominion (faction influence, security, piracy)
##   - Market (price deltas, service costs)
##   - Power (station load ratios)
##   - Maintenance (entropy rates, wear)
##   - Wrecks (degrading debris → matter return)
##
## Processing is DOUBLE-BUFFERED: all reads come from GameState, all writes
## go to local buffers, then buffers are swapped atomically at the end.
## This prevents order-dependent artifacts when iterating sectors.
##
## Conservation Axiom 1 is asserted after every tick — total matter must not change.


# Reference to the CA rules module (injected by SimulationEngine).
var ca_rules: Reference = null


# =============================================================================
# === INITIALIZATION ==========================================================
# =============================================================================

## Seeds all Grid Layer state in GameState from World Layer data and templates.
## Called once at game start, after WorldLayer.initialize_world().
func initialize_grid() -> void:
	_seed_stockpiles()
	_seed_dominion()
	_seed_market()
	_seed_power()
	_seed_maintenance()
	_seed_resource_availability()
	# grid_wrecks starts empty — wrecks are created by combat/events
	GameState.grid_wrecks.clear()

	print("GridLayer: Initialized grid state for %d sectors." % GameState.world_topology.size())


# =============================================================================
# === TICK PROCESSING =========================================================
# =============================================================================

## Processes all Grid-layer CA steps for one tick (GDD Section 7, steps 2a–2g).
## Double-buffered: reads from GameState, writes to buffers, then swaps.
##
## @param config  Dictionary — tuning constants from Constants.gd / SimulationEngine.
func process_tick(config: Dictionary) -> void:
	# Snapshot the pre-tick matter total for Axiom 1 check
	var matter_before: float = _calculate_current_matter()

	# --- Allocate write buffers ---
	var buf_stockpiles: Dictionary = {}
	var buf_dominion: Dictionary = {}
	var buf_market: Dictionary = {}
	var buf_power: Dictionary = {}
	var buf_maintenance: Dictionary = {}
	var buf_resource_availability: Dictionary = {}
	var buf_resource_potential: Dictionary = {}

	# Deep-copy resource potential (extraction depletes it)
	for sector_id in GameState.world_resource_potential:
		buf_resource_potential[sector_id] = GameState.world_resource_potential[sector_id].duplicate(true)

	# --- Process each sector ---
	for sector_id in GameState.world_topology:
		var topology: Dictionary = GameState.world_topology[sector_id]
		var connections: Array = topology.get("connections", [])
		var hazards: Dictionary = GameState.world_hazards.get(sector_id, {})

		# ====================================================
		# 2a. Extraction + 2b. Supply & Demand CA
		# ====================================================
		var current_stockpiles: Dictionary = GameState.grid_stockpiles.get(sector_id, {}).duplicate(true)
		var current_potential: Dictionary = buf_resource_potential.get(sector_id, {}).duplicate(true)

		# Gather neighbor stockpiles for diffusion
		var neighbor_stockpiles: Array = []
		for conn_id in connections:
			if GameState.grid_stockpiles.has(conn_id):
				neighbor_stockpiles.append(GameState.grid_stockpiles[conn_id])

		var supply_result: Dictionary = ca_rules.supply_demand_step(
			sector_id, current_stockpiles, current_potential,
			neighbor_stockpiles, config
		)
		buf_stockpiles[sector_id] = supply_result["new_stockpiles"]
		buf_resource_potential[sector_id] = supply_result["new_resource_potential"]

		# ====================================================
		# 2c. Strategic Map CA (dominion)
		# ====================================================
		var current_dominion: Dictionary = GameState.grid_dominion.get(sector_id, {}).duplicate(true)

		var neighbor_dominion_states: Array = []
		for conn_id in connections:
			if GameState.grid_dominion.has(conn_id):
				neighbor_dominion_states.append(GameState.grid_dominion[conn_id])

		buf_dominion[sector_id] = ca_rules.strategic_map_step(
			sector_id, current_dominion, neighbor_dominion_states, config
		)

		# ====================================================
		# 2d. Power Load
		# ====================================================
		var current_power: Dictionary = GameState.grid_power.get(sector_id, {})
		var power_output: float = current_power.get("station_power_output", 100.0)
		var power_draw: float = current_power.get("station_power_draw", 0.0)

		# Count docked agents as power consumers (Phase 1: flat draw per agent)
		var docked_agent_count: int = _count_docked_agents(sector_id)
		var agent_power_draw: float = config.get("power_draw_per_agent", 5.0)
		var service_power_draw: float = config.get("power_draw_per_service", 10.0)
		var num_services: int = _count_services(sector_id)
		power_draw = (float(docked_agent_count) * agent_power_draw) + (float(num_services) * service_power_draw)

		var power_result: Dictionary = ca_rules.power_load_step(power_output, power_draw)
		buf_power[sector_id] = {
			"station_power_output": power_output,
			"station_power_draw": power_draw,
			"power_load_ratio": power_result["power_load_ratio"]
		}

		# ====================================================
		# 2e. Market Pressure
		# ====================================================
		var current_market: Dictionary = GameState.grid_market.get(sector_id, {})
		var population_density: float = current_market.get("population_density", 1.0)

		# Use the buffer stockpiles (post-extraction) for price calculation
		var market_result: Dictionary = ca_rules.market_pressure_step(
			sector_id, buf_stockpiles[sector_id], population_density, config
		)
		buf_market[sector_id] = {
			"commodity_price_deltas": market_result["commodity_price_deltas"],
			"population_density": population_density,
			"service_cost_modifier": market_result["service_cost_modifier"]
		}

		# ====================================================
		# 2g. Maintenance Pressure
		# ====================================================
		buf_maintenance[sector_id] = ca_rules.maintenance_pressure_step(hazards, config)

		# ====================================================
		# Update resource availability from post-extraction potential
		# ====================================================
		var potential: Dictionary = buf_resource_potential.get(sector_id, {})
		buf_resource_availability[sector_id] = {
			"propellant_supply": potential.get("propellant_sources", 0.0),
			"consumables_supply": buf_stockpiles[sector_id].get("commodity_stockpiles", {}).get("food", 0.0),
			"energy_supply": potential.get("energy_potential", 0.0)
		}

	# ====================================================
	# 2b-post. Stockpile Diffusion (separate pass for matter conservation)
	# ====================================================
	# Two-pass approach: first collect all flows, then apply symmetrically.
	# Flow from sector A to neighbor B is subtracted from A and added to B.
	var diffusion_rate: float = config.get("stockpile_diffusion_rate", 0.05)
	var diffusion_deltas: Dictionary = {}  # sector_id → {commodity_id → delta}
	for sector_id in buf_stockpiles:
		diffusion_deltas[sector_id] = {}

	for sector_id in GameState.world_topology:
		var topology: Dictionary = GameState.world_topology[sector_id]
		var connections: Array = topology.get("connections", [])
		if connections.empty():
			continue

		var local_commodities: Dictionary = buf_stockpiles[sector_id].get("commodity_stockpiles", {})
		for conn_id in connections:
			# Only process pairs once: sector_id < conn_id avoids double-counting
			if conn_id <= sector_id:
				continue
			if not buf_stockpiles.has(conn_id):
				continue

			var neighbor_commodities: Dictionary = buf_stockpiles[conn_id].get("commodity_stockpiles", {})

			# Collect all commodity IDs present in either sector
			var all_commodities: Dictionary = {}
			for c in local_commodities:
				all_commodities[c] = true
			for c in neighbor_commodities:
				all_commodities[c] = true

			for commodity_id in all_commodities:
				var local_amount: float = local_commodities.get(commodity_id, 0.0)
				var neighbor_amount: float = neighbor_commodities.get(commodity_id, 0.0)
				var diff: float = local_amount - neighbor_amount
				if abs(diff) < 0.001:
					continue

				# Flow from high to low, proportional to difference
				var flow: float = diff * diffusion_rate * 0.5  # 0.5 = per-edge rate
				# Subtract from source, add to destination
				diffusion_deltas[sector_id][commodity_id] = diffusion_deltas[sector_id].get(commodity_id, 0.0) - flow
				if not diffusion_deltas.has(conn_id):
					diffusion_deltas[conn_id] = {}
				diffusion_deltas[conn_id][commodity_id] = diffusion_deltas[conn_id].get(commodity_id, 0.0) + flow

	# Apply diffusion deltas to buffer stockpiles
	for sector_id in diffusion_deltas:
		var deltas: Dictionary = diffusion_deltas[sector_id]
		if deltas.empty():
			continue
		var commodities: Dictionary = buf_stockpiles[sector_id].get("commodity_stockpiles", {})
		for commodity_id in deltas:
			var new_val: float = commodities.get(commodity_id, 0.0) + deltas[commodity_id]
			commodities[commodity_id] = max(0.0, new_val)

	# ====================================================
	# 2f. Wreck & Debris (global, not per-sector iteration)
	# ====================================================
	_process_wrecks(config, buf_resource_potential)

	# --- Atomic swap: copy buffers into GameState ---
	GameState.grid_stockpiles = buf_stockpiles
	GameState.grid_dominion = buf_dominion
	GameState.grid_market = buf_market
	GameState.grid_power = buf_power
	GameState.grid_maintenance = buf_maintenance
	GameState.grid_resource_availability = buf_resource_availability

	# Write back depleted resource potential to World Layer
	for sector_id in buf_resource_potential:
		GameState.world_resource_potential[sector_id] = buf_resource_potential[sector_id]

	# --- Axiom 1 assertion ---
	var matter_after: float = _calculate_current_matter()
	var drift: float = abs(matter_after - matter_before)
	var tolerance: float = config.get("axiom1_tolerance", 0.01)
	if drift > tolerance:
		push_warning("GridLayer: AXIOM 1 VIOLATION! Matter drift: %.4f (before: %.2f, after: %.2f)" % [
			drift, matter_before, matter_after
		])


# =============================================================================
# === PRIVATE — SEEDING =======================================================
# =============================================================================

## Seeds grid_stockpiles from LocationTemplate market_inventory and stockpile_capacity.
func _seed_stockpiles() -> void:
	GameState.grid_stockpiles.clear()

	for location_id in TemplateDatabase.locations:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		# Convert market_inventory → commodity_stockpiles
		var commodity_stockpiles: Dictionary = {}
		var market_inv: Dictionary = loc.get("market_inventory") if loc.get("market_inventory") != null else {}
		for commodity_id in market_inv:
			var entry: Dictionary = market_inv[commodity_id]
			# Use the initial quantity as starting stockpile
			commodity_stockpiles[commodity_id] = float(entry.get("quantity", 0))

		var capacity: int = int(loc.get("stockpile_capacity")) if loc.get("stockpile_capacity") != null else 1000

		GameState.grid_stockpiles[location_id] = {
			"commodity_stockpiles": commodity_stockpiles,
			"stockpile_capacity": capacity,
			"extraction_rate": {}  # Phase 1: use config defaults
		}


## Seeds grid_dominion from LocationTemplate controlling_faction_id.
func _seed_dominion() -> void:
	GameState.grid_dominion.clear()

	for location_id in TemplateDatabase.locations:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		var controlling_faction: String = loc.get("controlling_faction_id") if loc.get("controlling_faction_id") != null else ""

		# Build initial faction influence: controlling faction gets 0.8, others get small shares
		var faction_influence: Dictionary = {}
		for faction_id in TemplateDatabase.factions:
			if faction_id == controlling_faction:
				faction_influence[faction_id] = 0.8
			else:
				faction_influence[faction_id] = 0.1

		# Security derives from dominant faction influence
		var security: float = 0.8 if controlling_faction != "" else 0.2

		# Piracy inversely from danger_level template field (legacy bridge)
		var danger: int = int(loc.get("danger_level")) if loc.get("danger_level") != null else 0
		var pirate_activity: float = clamp(float(danger) * 0.1, 0.0, 1.0)

		GameState.grid_dominion[location_id] = {
			"faction_influence": faction_influence,
			"security_level": security,
			"pirate_activity": pirate_activity
		}


## Seeds grid_market from LocationTemplate market_inventory base prices.
func _seed_market() -> void:
	GameState.grid_market.clear()

	for location_id in TemplateDatabase.locations:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		# Initial price deltas are 0 (prices at base value)
		var price_deltas: Dictionary = {}
		var market_inv: Dictionary = loc.get("market_inventory") if loc.get("market_inventory") != null else {}
		for commodity_id in market_inv:
			price_deltas[commodity_id] = 0.0

		# Population density: hubs are denser
		var sector_type: String = loc.get("sector_type") if loc.get("sector_type") else "frontier"
		var population: float = 2.0 if sector_type == "hub" else 1.0

		GameState.grid_market[location_id] = {
			"commodity_price_deltas": price_deltas,
			"population_density": population,
			"service_cost_modifier": 1.0
		}


## Seeds grid_power from LocationTemplate station_power_output.
func _seed_power() -> void:
	GameState.grid_power.clear()

	for location_id in TemplateDatabase.locations:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		var power_output: float = float(loc.get("station_power_output")) if loc.get("station_power_output") != null else 100.0

		GameState.grid_power[location_id] = {
			"station_power_output": power_output,
			"station_power_draw": 0.0,  # No agents docked yet
			"power_load_ratio": 0.0
		}


## Seeds grid_maintenance from World Layer hazard data.
func _seed_maintenance() -> void:
	GameState.grid_maintenance.clear()

	for location_id in GameState.world_hazards:
		var hazards: Dictionary = GameState.world_hazards[location_id]

		# Calculate initial entropy rate from hazards (same formula as CA rule)
		var base_rate: float = 0.001
		var radiation: float = hazards.get("radiation_level", 0.0)
		var thermal: float = hazards.get("thermal_background_k", 300.0)
		var gravity: float = hazards.get("gravity_well_penalty", 1.0)
		var thermal_deviation: float = abs(thermal - 300.0) / 300.0
		var entropy_rate: float = base_rate * (1.0 + radiation * 2.0 + thermal_deviation) * gravity

		GameState.grid_maintenance[location_id] = {
			"local_entropy_rate": entropy_rate,
			"maintenance_cost_modifier": clamp(1.0 + entropy_rate * 100.0, 1.0, 3.0)
		}


## Seeds grid_resource_availability from World Layer resource potential.
func _seed_resource_availability() -> void:
	GameState.grid_resource_availability.clear()

	for location_id in GameState.world_resource_potential:
		var potential: Dictionary = GameState.world_resource_potential[location_id]

		GameState.grid_resource_availability[location_id] = {
			"propellant_supply": potential.get("propellant_sources", 0.0),
			"consumables_supply": 0.0,  # No food extracted yet; comes from stockpiles
			"energy_supply": potential.get("energy_potential", 0.0)
		}


# =============================================================================
# === PRIVATE — WRECK PROCESSING ==============================================
# =============================================================================

## Processes all wrecks: degradation + matter return (GDD Section 7, step 2f).
## Groups wrecks by sector, runs entropy_step per sector, writes results back.
##
## @param config                  Dictionary — tuning constants.
## @param buf_resource_potential  Dictionary — mutable; matter returned to mineral_density.
func _process_wrecks(config: Dictionary, buf_resource_potential: Dictionary) -> void:
	if GameState.grid_wrecks.empty():
		return

	# Group wrecks by sector
	var wrecks_by_sector: Dictionary = {}
	for wreck_uid in GameState.grid_wrecks:
		var wreck: Dictionary = GameState.grid_wrecks[wreck_uid].duplicate(true)
		wreck["wreck_uid"] = wreck_uid
		var sector_id: String = wreck.get("sector_id", "")
		if not wrecks_by_sector.has(sector_id):
			wrecks_by_sector[sector_id] = []
		wrecks_by_sector[sector_id].append(wreck)

	# Process each sector's wrecks
	var new_wrecks: Dictionary = {}
	for sector_id in wrecks_by_sector:
		var sector_wrecks: Array = wrecks_by_sector[sector_id]
		var hazards: Dictionary = GameState.world_hazards.get(sector_id, {})

		var entropy_result: Dictionary = ca_rules.entropy_step(
			sector_id, sector_wrecks, hazards, config
		)

		# Return matter to resource potential (mineral_density)
		var matter_returned: float = entropy_result["matter_returned"]
		if matter_returned > 0.0 and buf_resource_potential.has(sector_id):
			buf_resource_potential[sector_id]["mineral_density"] += matter_returned

		# Keep surviving wrecks
		for surviving_wreck in entropy_result["surviving_wrecks"]:
			var uid = surviving_wreck.get("wreck_uid", 0)
			var clean_wreck: Dictionary = surviving_wreck.duplicate(true)
			clean_wreck.erase("wreck_uid")  # Remove the temp key
			new_wrecks[uid] = clean_wreck

	GameState.grid_wrecks = new_wrecks


# =============================================================================
# === PRIVATE — HELPERS =======================================================
# =============================================================================

## Counts agents currently docked at a sector (Phase 1: simple lookup).
func _count_docked_agents(sector_id: String) -> int:
	var count: int = 0
	for agent_id in GameState.agents:
		var agent: Dictionary = GameState.agents[agent_id]
		if agent.get("current_sector_id", "") == sector_id:
			count += 1
	# Player counts if docked at this station
	if GameState.player_docked_at == sector_id:
		count += 1
	return count


## Counts available services at a sector from the location template.
func _count_services(sector_id: String) -> int:
	if TemplateDatabase.locations.has(sector_id):
		var loc: Resource = TemplateDatabase.locations[sector_id]
		var services: Array = loc.get("available_services") if loc.get("available_services") != null else []
		return services.size()
	return 0


## Calculates current total matter across all layers for Axiom 1 checking.
## Must match the same accounting as WorldLayer.recalculate_total_matter().
func _calculate_current_matter() -> float:
	var total: float = 0.0

	# Layer 1: Resource potential (finite deposits, being depleted)
	for sector_id in GameState.world_resource_potential:
		var potential: Dictionary = GameState.world_resource_potential[sector_id]
		total += potential.get("mineral_density", 0.0)
		total += potential.get("propellant_sources", 0.0)

	# Layer 2: Grid stockpiles (extracted commodities)
	for sector_id in GameState.grid_stockpiles:
		var stockpile: Dictionary = GameState.grid_stockpiles[sector_id]
		var commodities: Dictionary = stockpile.get("commodity_stockpiles", {})
		for commodity_id in commodities:
			total += float(commodities[commodity_id])

	# Layer 2: Wrecks (matter locked in debris)
	for wreck_uid in GameState.grid_wrecks:
		var wreck: Dictionary = GameState.grid_wrecks[wreck_uid]
		var inventory: Dictionary = wreck.get("wreck_inventory", {})
		for item_id in inventory:
			total += float(inventory[item_id])
		total += 1.0  # Base hull mass per wreck

	# Layer 3: Agent inventories (cargo being carried)
	for char_uid in GameState.inventories:
		var inv: Dictionary = GameState.inventories[char_uid]
		if inv.has(2):  # InventoryType.COMMODITY
			var commodities: Dictionary = inv[2]
			for commodity_id in commodities:
				total += float(commodities[commodity_id])

	return total
