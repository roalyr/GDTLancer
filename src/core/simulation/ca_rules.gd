#
# PROJECT: GDTLancer
# MODULE: ca_rules.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 1.2 (CA Catalogue), Section 3 (Grid Layer), Section 7 (Tick Sequence)
# LOG_REF: 2026-02-13
#

extends Reference

## CARules: Pure-function cellular automata transition rules for the simulation engine.
##
## Every function in this module is PURE:
##   - No GameState access, no GlobalRefs, no side effects.
##   - Inputs are plain Dictionaries/values; outputs are new Dictionaries.
##   - Never mutates input arguments.
##   - Fully deterministic: same inputs always produce same outputs.
##
## All CA rules follow the signature pattern:
##   func rule_step(local_state, neighbor_states, config) -> Dictionary
##
## The `config` Dictionary carries tuning constants (from Constants.gd)
## so that rules remain decoupled from any autoload.


# =============================================================================
# === STRATEGIC MAP CA ========================================================
# =============================================================================

## Computes the next dominion state for a single sector.
##
## Faction influence propagates from neighbors weighted by connection count.
## Pirate activity grows where security is low and decays where it is high.
##
## @param sector_id        String — the sector being processed (for debug context only).
## @param sector_state     Dictionary — current {faction_influence: Dict, security_level: float, pirate_activity: float}.
## @param neighbor_states  Array of Dictionaries — each neighbor's dominion state (same schema as sector_state).
## @param config           Dictionary — tuning params:
##                           influence_propagation_rate: float (0–1),
##                           pirate_activity_decay: float,
##                           pirate_activity_growth: float.
## @return                 Dictionary — new {faction_influence, security_level, pirate_activity}.
func strategic_map_step(sector_id: String, sector_state: Dictionary, neighbor_states: Array, config: Dictionary) -> Dictionary:
	var propagation_rate: float = config.get("influence_propagation_rate", 0.1)
	var pirate_decay: float = config.get("pirate_activity_decay", 0.02)
	var pirate_growth: float = config.get("pirate_activity_growth", 0.05)

	# --- Faction Influence Propagation ---
	# Start from current influence, then blend in neighbors.
	var current_influence: Dictionary = sector_state.get("faction_influence", {}).duplicate()
	var neighbor_count: int = neighbor_states.size()

	if neighbor_count > 0:
		# Accumulate neighbor influence
		var neighbor_avg: Dictionary = {}
		for n_state in neighbor_states:
			var n_influence: Dictionary = n_state.get("faction_influence", {})
			for faction_id in n_influence:
				if not neighbor_avg.has(faction_id):
					neighbor_avg[faction_id] = 0.0
				neighbor_avg[faction_id] += n_influence[faction_id]

		# Average neighbor influence and blend into current
		for faction_id in neighbor_avg:
			neighbor_avg[faction_id] /= float(neighbor_count)
			var current_val: float = current_influence.get(faction_id, 0.0)
			current_influence[faction_id] = current_val + propagation_rate * (neighbor_avg[faction_id] - current_val)

	# Normalize influence values to [0, 1] range
	var influence_sum: float = 0.0
	for faction_id in current_influence:
		current_influence[faction_id] = max(0.0, current_influence[faction_id])
		influence_sum += current_influence[faction_id]
	if influence_sum > 1.0:
		for faction_id in current_influence:
			current_influence[faction_id] /= influence_sum

	# --- Security Level ---
	# Security correlates with dominant faction influence presence.
	var max_faction_influence: float = 0.0
	for faction_id in current_influence:
		if current_influence[faction_id] > max_faction_influence:
			max_faction_influence = current_influence[faction_id]
	var new_security: float = clamp(max_faction_influence, 0.0, 1.0)

	# --- Pirate Activity ---
	# Grows where security is low, decays where it is high.
	var current_piracy: float = sector_state.get("pirate_activity", 0.0)
	var security_gap: float = 1.0 - new_security  # How "unprotected" the sector is
	var piracy_delta: float = (pirate_growth * security_gap) - (pirate_decay * new_security)
	var new_piracy: float = clamp(current_piracy + piracy_delta, 0.0, 1.0)

	return {
		"faction_influence": current_influence,
		"security_level": new_security,
		"pirate_activity": new_piracy
	}


# =============================================================================
# === SUPPLY & DEMAND CA ======================================================
# =============================================================================

## Computes the next stockpile state for a single sector after extraction and diffusion.
##
## Extraction: pulls matter from resource_potential into stockpiles (depletes potential).
## Diffusion: surplus flows from this sector to deficit neighbors (conserves total matter).
##
## @param sector_id           String — the sector being processed.
## @param stockpiles          Dictionary — current {commodity_stockpiles: Dict, stockpile_capacity: int, extraction_rate: Dict}.
## @param resource_potential  Dictionary — current {mineral_density: float, energy_potential: float, propellant_sources: float}.
## @param neighbor_stockpiles Array of Dictionaries — each neighbor's stockpiles dict (same schema).
## @param config              Dictionary — tuning params:
##                              extraction_rate_default: float,
##                              stockpile_diffusion_rate: float (0–1).
## @return                    Dictionary — {
##                              new_stockpiles: Dictionary (same schema as input stockpiles),
##                              new_resource_potential: Dictionary (depleted values),
##                              matter_extracted: float (total matter moved from potential to stockpiles)
##                            }.
func supply_demand_step(sector_id: String, stockpiles: Dictionary, resource_potential: Dictionary, _neighbor_stockpiles: Array, config: Dictionary) -> Dictionary:
	var extraction_rate: float = config.get("extraction_rate_default", 0.01)

	var new_stockpiles: Dictionary = stockpiles.duplicate(true)
	var new_potential: Dictionary = resource_potential.duplicate(true)
	var total_matter_extracted: float = 0.0

	var commodity_map: Dictionary = new_stockpiles.get("commodity_stockpiles", {}).duplicate()
	var capacity: int = new_stockpiles.get("stockpile_capacity", 1000)
	var local_extraction: Dictionary = new_stockpiles.get("extraction_rate", {}).duplicate()

	# --- Extraction Phase ---
	# Extract minerals → "ore" commodity
	var mineral: float = new_potential.get("mineral_density", 0.0)
	var mineral_extract: float = min(mineral, extraction_rate * mineral)
	if mineral_extract > 0.0:
		var current_ore: float = commodity_map.get("ore", 0.0)
		var space_available: float = max(0.0, float(capacity) - _sum_commodity_values(commodity_map))
		mineral_extract = min(mineral_extract, space_available)
		commodity_map["ore"] = current_ore + mineral_extract
		new_potential["mineral_density"] = mineral - mineral_extract
		total_matter_extracted += mineral_extract

	# Extract propellant_sources → "propellant" commodity
	var propellant_src: float = new_potential.get("propellant_sources", 0.0)
	var propellant_extract: float = min(propellant_src, extraction_rate * propellant_src)
	if propellant_extract > 0.0:
		var current_prop: float = commodity_map.get("propellant", 0.0)
		var space_available: float = max(0.0, float(capacity) - _sum_commodity_values(commodity_map))
		propellant_extract = min(propellant_extract, space_available)
		commodity_map["propellant"] = current_prop + propellant_extract
		new_potential["propellant_sources"] = propellant_src - propellant_extract
		total_matter_extracted += propellant_extract

	# --- Diffusion is handled separately by GridLayer as a two-pass operation ---
	# Removed from here because a per-sector function cannot distribute outflow
	# to neighbors without violating matter conservation (Axiom 1).

	new_stockpiles["commodity_stockpiles"] = commodity_map
	new_stockpiles["extraction_rate"] = local_extraction

	return {
		"new_stockpiles": new_stockpiles,
		"new_resource_potential": new_potential,
		"matter_extracted": total_matter_extracted
	}


# =============================================================================
# === MARKET PRESSURE CA ======================================================
# =============================================================================

## Computes commodity price deltas and service cost modifier for a single sector.
##
## Simple supply/demand curve: price_delta = (demand - supply) / normalization.
## High supply → negative delta (cheaper). Low supply → positive delta (expensive).
##
## @param sector_id          String — the sector being processed.
## @param stockpiles         Dictionary — {commodity_stockpiles: Dict, stockpile_capacity: int, ...}.
## @param population_density float — how many consumers are in this sector.
## @param config             Dictionary — tuning params:
##                             price_sensitivity: float,
##                             demand_base: float (base demand per unit population).
## @return                   Dictionary — {commodity_price_deltas: Dict, service_cost_modifier: float}.
func market_pressure_step(sector_id: String, stockpiles: Dictionary, population_density: float, config: Dictionary) -> Dictionary:
	var price_sensitivity: float = config.get("price_sensitivity", 0.5)
	var demand_base: float = config.get("demand_base", 0.1)

	var commodities: Dictionary = stockpiles.get("commodity_stockpiles", {})
	var capacity: int = stockpiles.get("stockpile_capacity", 1000)
	var price_deltas: Dictionary = {}

	# For each commodity, compute price delta from supply vs demand
	for commodity_id in commodities:
		var supply: float = commodities[commodity_id]
		var demand: float = demand_base * population_density
		var normalization: float = max(float(capacity) * 0.5, 1.0)  # Prevent div by zero
		var delta: float = price_sensitivity * (demand - supply) / normalization
		price_deltas[commodity_id] = delta

	# Service cost modifier: higher population + lower supply = more expensive services
	var total_supply: float = _sum_commodity_values(commodities)
	var supply_ratio: float = total_supply / max(float(capacity), 1.0)
	var service_modifier: float = 1.0 + (population_density * 0.1) - (supply_ratio * 0.2)
	service_modifier = clamp(service_modifier, 0.5, 2.0)

	return {
		"commodity_price_deltas": price_deltas,
		"service_cost_modifier": service_modifier
	}


# =============================================================================
# === ENTROPY / WRECK DEGRADATION CA ==========================================
# =============================================================================

## Computes wreck degradation and matter return for a single sector.
##
## Wrecks degrade based on environmental hazards. When integrity reaches 0,
## their matter is returned to the sector's resource potential (mineral_density).
## This enforces Conservation Axiom 1.
##
## @param sector_id          String — the sector being processed.
## @param wrecks             Array of Dictionaries — each wreck: {wreck_uid: int, wreck_integrity: float,
##                             wreck_inventory: Dict, ship_template_id: String, created_at_tick: int}.
## @param hazards            Dictionary — {radiation_level: float, thermal_background_k: float, gravity_well_penalty: float}.
## @param config             Dictionary — tuning params:
##                             wreck_degradation_per_tick: float,
##                             wreck_debris_return_fraction: float (0–1),
##                             entropy_radiation_multiplier: float.
## @return                   Dictionary — {
##                             surviving_wrecks: Array (wrecks still above 0 integrity),
##                             matter_returned: float (total matter recycled back to resource potential)
##                           }.
func entropy_step(sector_id: String, wrecks: Array, hazards: Dictionary, config: Dictionary) -> Dictionary:
	var base_degradation: float = config.get("wreck_degradation_per_tick", 0.05)
	var return_fraction: float = config.get("wreck_debris_return_fraction", 0.8)
	var radiation_mult: float = config.get("entropy_radiation_multiplier", 2.0)

	var radiation: float = hazards.get("radiation_level", 0.0)
	var degradation_rate: float = base_degradation * (1.0 + radiation * radiation_mult)

	var surviving_wrecks: Array = []
	var total_matter_returned: float = 0.0

	for wreck in wrecks:
		var new_wreck: Dictionary = wreck.duplicate(true)
		var integrity: float = new_wreck.get("wreck_integrity", 1.0)
		integrity -= degradation_rate
		new_wreck["wreck_integrity"] = integrity

		if integrity <= 0.0:
			# Wreck fully degraded — return matter to resource potential
			var wreck_matter: float = _calculate_wreck_matter(new_wreck)
			total_matter_returned += wreck_matter * return_fraction
			# Wreck is destroyed — do NOT add to surviving list
		else:
			surviving_wrecks.append(new_wreck)

	return {
		"surviving_wrecks": surviving_wrecks,
		"matter_returned": total_matter_returned
	}


# =============================================================================
# === INFLUENCE NETWORK CA (Agent-level) ======================================
# =============================================================================

## Computes updated character standings for a single agent via reputation propagation.
##
## An agent's opinion of others is influenced by the opinions of agents they interact with.
## Phase 1: simple averaging toward connected agents' views.
##
## @param agent_id                  String — the agent being processed.
## @param agent_standings           Dictionary — this agent's {character_id: standing_value} map.
## @param neighbor_agent_standings  Array of Dictionaries — each connected agent's standings (same schema).
## @param config                    Dictionary — tuning params:
##                                    influence_propagation_rate: float (0–1, reused from strategic map).
## @return                          Dictionary — updated standings for this agent.
func influence_network_step(agent_id: String, agent_standings: Dictionary, neighbor_agent_standings: Array, config: Dictionary) -> Dictionary:
	var propagation_rate: float = config.get("influence_propagation_rate", 0.1)
	var new_standings: Dictionary = agent_standings.duplicate()
	var neighbor_count: int = neighbor_agent_standings.size()

	if neighbor_count == 0:
		return new_standings

	# For each character this agent has an opinion about,
	# blend toward the average neighbor opinion.
	var all_character_ids: Dictionary = {}
	for char_id in new_standings:
		all_character_ids[char_id] = true
	for n_standings in neighbor_agent_standings:
		for char_id in n_standings:
			all_character_ids[char_id] = true

	for char_id in all_character_ids:
		# Skip self-reference
		if char_id == agent_id:
			continue

		var current_val: float = new_standings.get(char_id, 0.0)

		# Average neighbor opinion of this character
		var neighbor_sum: float = 0.0
		var neighbor_has_count: int = 0
		for n_standings in neighbor_agent_standings:
			if n_standings.has(char_id):
				neighbor_sum += n_standings[char_id]
				neighbor_has_count += 1

		if neighbor_has_count > 0:
			var neighbor_avg: float = neighbor_sum / float(neighbor_has_count)
			new_standings[char_id] = current_val + propagation_rate * (neighbor_avg - current_val)

	return new_standings


# =============================================================================
# === POWER LOAD CALCULATION ==================================================
# =============================================================================

## Computes the power load ratio for a single sector.
##
## @param station_power_output float — total power the station can produce.
## @param station_power_draw   float — total power being consumed (agents docked + services).
## @return                     Dictionary — {power_load_ratio: float} where 1.0 = at capacity.
func power_load_step(station_power_output: float, station_power_draw: float) -> Dictionary:
	var ratio: float = 0.0
	if station_power_output > 0.0:
		ratio = station_power_draw / station_power_output
	return {
		"power_load_ratio": clamp(ratio, 0.0, 2.0)  # Can exceed 1.0 = overloaded
	}


# =============================================================================
# === MAINTENANCE PRESSURE CALCULATION ========================================
# =============================================================================

## Computes the local entropy rate and maintenance cost modifier for a sector.
##
## Higher radiation and thermal extremes increase entropy.
##
## @param hazards  Dictionary — {radiation_level: float, thermal_background_k: float, gravity_well_penalty: float}.
## @param config   Dictionary — tuning params:
##                   entropy_base_rate: float.
## @return         Dictionary — {local_entropy_rate: float, maintenance_cost_modifier: float}.
func maintenance_pressure_step(hazards: Dictionary, config: Dictionary) -> Dictionary:
	var base_rate: float = config.get("entropy_base_rate", 0.001)
	var radiation: float = hazards.get("radiation_level", 0.0)
	var thermal: float = hazards.get("thermal_background_k", 300.0)
	var gravity: float = hazards.get("gravity_well_penalty", 1.0)

	# Entropy increases with radiation and extreme temperatures
	# 300K is "normal" — deviation in either direction increases entropy
	var thermal_deviation: float = abs(thermal - 300.0) / 300.0
	var entropy_rate: float = base_rate * (1.0 + radiation * 2.0 + thermal_deviation) * gravity

	# Maintenance cost scales with entropy
	var maintenance_modifier: float = 1.0 + entropy_rate * 100.0
	maintenance_modifier = clamp(maintenance_modifier, 1.0, 3.0)

	return {
		"local_entropy_rate": entropy_rate,
		"maintenance_cost_modifier": maintenance_modifier
	}


# =============================================================================
# === PRIVATE HELPERS (pure, no side effects) =================================
# =============================================================================

## Sums all values in a commodity dictionary.
func _sum_commodity_values(commodities: Dictionary) -> float:
	var total: float = 0.0
	for key in commodities:
		total += float(commodities[key])
	return total


## Estimates the matter content of a wreck from its inventory.
## Used for Conservation Axiom 1 accounting when a wreck degrades to nothing.
func _calculate_wreck_matter(wreck: Dictionary) -> float:
	var matter: float = 0.0
	var inventory: Dictionary = wreck.get("wreck_inventory", {})
	for item_id in inventory:
		matter += float(inventory[item_id])
	# Add a base hull mass estimate (1.0 unit per wreck as baseline)
	matter += 1.0
	return matter
