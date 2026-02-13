#
# PROJECT: GDTLancer
# MODULE: world_layer.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 2 (World Layer), Section 9 (Phase 1 Scope)
# LOG_REF: 2026-02-13
#

extends Reference

## WorldLayer: Initializes Layer 1 (World) data in GameState from LocationTemplate resources.
##
## The World Layer is STATIC after initialization — it is read-only at runtime.
## It defines the physical foundation: topology (sector graph), hazards, and
## finite resource potential (matter budget for Conservation Axiom 1).
##
## Called once at game start by the SimulationEngine. After init, the Grid Layer
## seeds its dynamic state from these static values.


# =============================================================================
# === PUBLIC API ==============================================================
# =============================================================================

## Initializes all World Layer data in GameState from TemplateDatabase.locations.
##
## @param seed_string  String — world generation seed (stored in GameState.world_seed).
func initialize_world(seed_string: String) -> void:
	GameState.world_seed = seed_string

	# Seed the RNG deterministically so resource values are reproducible.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_string)

	_build_topology()
	_build_hazards()
	_build_resource_potential(rng)
	_calculate_total_matter()

	print("WorldLayer: Initialized %d sectors. Total matter budget: %.2f" % [
		GameState.world_topology.size(),
		GameState.world_total_matter
	])


# =============================================================================
# === PRIVATE — TOPOLOGY ======================================================
# =============================================================================

## Builds GameState.world_topology from LocationTemplate data.
## Each sector entry: {connections: Array, station_ids: Array, sector_type: String}
func _build_topology() -> void:
	GameState.world_topology.clear()

	for location_id in TemplateDatabase.locations:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		var connections: Array = []
		# PoolStringArray → regular Array for simulation use
		if loc.get("connections") != null:
			for conn_id in loc.connections:
				connections.append(conn_id)

		# Station IDs: for now, each location IS its own station
		var station_ids: Array = [location_id]

		var sector_type: String = loc.get("sector_type") if loc.get("sector_type") else "frontier"

		GameState.world_topology[location_id] = {
			"connections": connections,
			"station_ids": station_ids,
			"sector_type": sector_type
		}


# =============================================================================
# === PRIVATE — HAZARDS =======================================================
# =============================================================================

## Builds GameState.world_hazards from LocationTemplate environmental data.
## Each sector entry: {radiation_level: float, thermal_background_k: float, gravity_well_penalty: float}
func _build_hazards() -> void:
	GameState.world_hazards.clear()

	for location_id in TemplateDatabase.locations:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		GameState.world_hazards[location_id] = {
			"radiation_level": float(loc.get("radiation_level")) if loc.get("radiation_level") != null else 0.0,
			"thermal_background_k": float(loc.get("thermal_background_k")) if loc.get("thermal_background_k") != null else 300.0,
			"gravity_well_penalty": float(loc.get("gravity_well_penalty")) if loc.get("gravity_well_penalty") != null else 1.0
		}


# =============================================================================
# === PRIVATE — RESOURCE POTENTIAL ============================================
# =============================================================================

## Builds GameState.world_resource_potential from LocationTemplate deposits.
## These are FINITE values that get depleted by Grid Layer extraction over ticks.
## A small random variance (±10%) is applied deterministically via the seeded RNG.
##
## @param rng  RandomNumberGenerator — seeded deterministically from world_seed.
func _build_resource_potential(rng: RandomNumberGenerator) -> void:
	GameState.world_resource_potential.clear()

	for location_id in TemplateDatabase.locations:
		var loc: Resource = TemplateDatabase.locations[location_id]
		if not is_instance_valid(loc):
			continue

		# Base values from template, with ±10% seeded variance
		var base_mineral: float = float(loc.get("mineral_density")) if loc.get("mineral_density") != null else 0.5
		var base_propellant: float = float(loc.get("propellant_sources")) if loc.get("propellant_sources") != null else 0.5

		var mineral_variance: float = base_mineral * (rng.randf_range(-0.1, 0.1))
		var propellant_variance: float = base_propellant * (rng.randf_range(-0.1, 0.1))

		# Scale up to simulation-meaningful quantities
		# Base density 1.0 → 100.0 resource units (Phase 1 scale factor)
		var scale_factor: float = 100.0

		GameState.world_resource_potential[location_id] = {
			"mineral_density": max(0.0, (base_mineral + mineral_variance) * scale_factor),
			"energy_potential": 50.0,  # Phase 1 stub: flat energy potential per sector
			"propellant_sources": max(0.0, (base_propellant + propellant_variance) * scale_factor)
		}


# =============================================================================
# === PRIVATE — MATTER CONSERVATION CHECKSUM ==================================
# =============================================================================

## Calculates and stores the total matter budget for Conservation Axiom 1.
##
## Total matter = sum of all resource potential (mineral + propellant)
##              + any initial commodity stockpiles (from Grid Layer, added later)
##              + any agent cargo (from Agent Layer, added later)
##
## At this stage, only World Layer resource potential exists.
## The SimulationEngine will call update_total_matter() after Grid and Agent
## layers are initialized to capture the full budget.
func _calculate_total_matter() -> void:
	var total: float = 0.0

	for sector_id in GameState.world_resource_potential:
		var potential: Dictionary = GameState.world_resource_potential[sector_id]
		total += potential.get("mineral_density", 0.0)
		total += potential.get("propellant_sources", 0.0)
		# energy_potential is not "matter" — it's renewable (solar, etc.)
		# so it's excluded from the matter conservation budget

	GameState.world_total_matter = total


# =============================================================================
# === PUBLIC UTILITY ==========================================================
# =============================================================================

## Returns the list of connected sector IDs for a given sector.
## Used by Grid Layer to find CA neighbors.
##
## @param sector_id  String — the sector to query.
## @return           Array of String — connected sector IDs.
func get_neighbors(sector_id: String) -> Array:
	if GameState.world_topology.has(sector_id):
		return GameState.world_topology[sector_id].get("connections", [])
	return []


## Returns the hazard data for a given sector.
##
## @param sector_id  String — the sector to query.
## @return           Dictionary — {radiation_level, thermal_background_k, gravity_well_penalty}
func get_hazards(sector_id: String) -> Dictionary:
	if GameState.world_hazards.has(sector_id):
		return GameState.world_hazards[sector_id]
	return {"radiation_level": 0.0, "thermal_background_k": 300.0, "gravity_well_penalty": 1.0}


## Returns the resource potential for a given sector.
##
## @param sector_id  String — the sector to query.
## @return           Dictionary — {mineral_density, energy_potential, propellant_sources}
func get_resource_potential(sector_id: String) -> Dictionary:
	if GameState.world_resource_potential.has(sector_id):
		return GameState.world_resource_potential[sector_id]
	return {"mineral_density": 0.0, "energy_potential": 0.0, "propellant_sources": 0.0}


## Recalculates world_total_matter from ALL matter sources across all layers.
## Should be called after Grid and Agent layers are initialized.
## This sets the definitive Axiom 1 checksum for all future tick verification.
func recalculate_total_matter() -> void:
	var total: float = 0.0

	# Layer 1: Resource potential (finite deposits)
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
		# Commodities are the matter-bearing inventory type
		# InventoryType.COMMODITY = 2
		if inv.has(2):
			var commodities: Dictionary = inv[2]
			for commodity_id in commodities:
				total += float(commodities[commodity_id])

	GameState.world_total_matter = total
	print("WorldLayer: Total matter recalculated: %.2f" % total)
