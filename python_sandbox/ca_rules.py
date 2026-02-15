"""
GDTLancer CA Rules — pure-function cellular automata transition rules.
Mirror of src/core/simulation/ca_rules.gd.

Every function is PURE:
  - No GameState access, no side effects.
  - Inputs are plain dicts/values; outputs are new dicts.
  - Never mutates input arguments.
  - Fully deterministic.
"""

import copy
import math


# =========================================================================
# === STRATEGIC MAP CA ====================================================
# =========================================================================

def strategic_map_step(
    sector_id: str,
    sector_state: dict,
    neighbor_states: list,
    config: dict,
) -> dict:
    """Compute next dominion state for a single sector.

    Faction influence propagates from neighbors.
    Controlling faction gets an anchor bonus that resists blending.
    Pirate activity grows where security is low, decays where high.
    """
    propagation_rate = config.get("influence_propagation_rate", 0.1)
    pirate_decay = config.get("pirate_activity_decay", 0.02)
    pirate_growth = config.get("pirate_activity_growth", 0.05)
    anchor_strength = config.get("faction_anchor_strength", 0.3)

    # --- Faction Influence Propagation ---
    current_influence = dict(sector_state.get("faction_influence", {}))
    controlling_faction = sector_state.get("controlling_faction_id", "")
    neighbor_count = len(neighbor_states)

    if neighbor_count > 0:
        neighbor_avg: dict = {}
        for n_state in neighbor_states:
            n_influence = n_state.get("faction_influence", {})
            for faction_id, val in n_influence.items():
                neighbor_avg[faction_id] = neighbor_avg.get(faction_id, 0.0) + val

        for faction_id in neighbor_avg:
            neighbor_avg[faction_id] /= neighbor_count
            current_val = current_influence.get(faction_id, 0.0)
            current_influence[faction_id] = current_val + propagation_rate * (
                neighbor_avg[faction_id] - current_val
            )

    # --- Faction Anchor: controlling faction gets a boost each tick ---
    if controlling_faction and controlling_faction in current_influence:
        current_influence[controlling_faction] += anchor_strength
    elif controlling_faction:
        current_influence[controlling_faction] = anchor_strength

    # Normalize so sum = 1.0
    for fid in current_influence:
        current_influence[fid] = max(0.0, current_influence[fid])
    influence_sum = sum(current_influence.values())
    if influence_sum > 0.0:
        for fid in current_influence:
            current_influence[fid] /= influence_sum

    # --- Security Level ---
    max_faction_influence = max(current_influence.values()) if current_influence else 0.0
    new_security = max(0.0, min(1.0, max_faction_influence))

    # --- Pirate Activity ---
    current_piracy = sector_state.get("pirate_activity", 0.0)
    security_gap = 1.0 - new_security
    piracy_delta = (pirate_growth * security_gap) - (pirate_decay * new_security)
    new_piracy = max(0.0, min(1.0, current_piracy + piracy_delta))

    return {
        "faction_influence": current_influence,
        "security_level": new_security,
        "pirate_activity": new_piracy,
    }


# =========================================================================
# === SUPPLY & DEMAND CA ==================================================
# =========================================================================

def supply_demand_step(
    sector_id: str,
    stockpiles: dict,
    resource_potential: dict,
    neighbor_stockpiles: list,
    config: dict,
) -> dict:
    """Compute next stockpile state after extraction.

    Extraction pulls matter from resource_potential into stockpiles.
    Diffusion is handled separately by GridLayer (two-pass).
    """
    extraction_rate = config.get("extraction_rate_default", 0.01)

    new_stockpiles = copy.deepcopy(stockpiles)
    new_potential = copy.deepcopy(resource_potential)
    total_matter_extracted = 0.0

    commodity_map = dict(new_stockpiles.get("commodity_stockpiles", {}))
    capacity = new_stockpiles.get("stockpile_capacity", 1000)

    # --- Extract minerals → "commodity_ore" ---
    # Note: GDScript uses "ore" but templates use "commodity_ore".
    # Use "commodity_ore" to match template commodity IDs.
    mineral = new_potential.get("mineral_density", 0.0)
    mineral_extract = min(mineral, extraction_rate * mineral)
    if mineral_extract > 0.0:
        ore_key = "commodity_ore"
        current_ore = commodity_map.get(ore_key, 0.0)
        space_available = max(0.0, float(capacity) - _sum_commodity_values(commodity_map))
        mineral_extract = min(mineral_extract, space_available)
        commodity_map[ore_key] = current_ore + mineral_extract
        new_potential["mineral_density"] = mineral - mineral_extract
        total_matter_extracted += mineral_extract

    # --- Extract propellant_sources → "commodity_fuel" ---
    propellant_src = new_potential.get("propellant_sources", 0.0)
    propellant_extract = min(propellant_src, extraction_rate * propellant_src)
    if propellant_extract > 0.0:
        fuel_key = "commodity_fuel"
        current_prop = commodity_map.get(fuel_key, 0.0)
        space_available = max(0.0, float(capacity) - _sum_commodity_values(commodity_map))
        propellant_extract = min(propellant_extract, space_available)
        commodity_map[fuel_key] = current_prop + propellant_extract
        new_potential["propellant_sources"] = propellant_src - propellant_extract
        total_matter_extracted += propellant_extract

    new_stockpiles["commodity_stockpiles"] = commodity_map
    new_stockpiles["extraction_rate"] = dict(new_stockpiles.get("extraction_rate", {}))

    return {
        "new_stockpiles": new_stockpiles,
        "new_resource_potential": new_potential,
        "matter_extracted": total_matter_extracted,
    }


# =========================================================================
# === MARKET PRESSURE CA ==================================================
# =========================================================================

def market_pressure_step(
    sector_id: str,
    stockpiles: dict,
    population_density: float,
    config: dict,
) -> dict:
    """Compute commodity price deltas and service cost modifier."""
    price_sensitivity = config.get("price_sensitivity", 0.5)
    demand_base = config.get("demand_base", 0.1)

    commodities = stockpiles.get("commodity_stockpiles", {})
    capacity = stockpiles.get("stockpile_capacity", 1000)
    price_deltas = {}

    for commodity_id, supply in commodities.items():
        demand = demand_base * population_density
        normalization = max(float(capacity) * 0.5, 1.0)
        delta = price_sensitivity * (demand - supply) / normalization
        price_deltas[commodity_id] = delta

    total_supply = _sum_commodity_values(commodities)
    supply_ratio = total_supply / max(float(capacity), 1.0)
    service_modifier = 1.0 + (population_density * 0.1) - (supply_ratio * 0.2)
    service_modifier = max(0.5, min(2.0, service_modifier))

    return {
        "commodity_price_deltas": price_deltas,
        "service_cost_modifier": service_modifier,
    }


# =========================================================================
# === ENTROPY / WRECK DEGRADATION CA ======================================
# =========================================================================

def entropy_step(
    sector_id: str,
    wrecks: list,
    hazards: dict,
    config: dict,
) -> dict:
    """Compute wreck degradation and matter redistribution for a sector.

    Wrecks degrade based on environmental hazards.  All matter is conserved
    (Axiom 1) via two output channels:
      * matter_salvaged  – recoverable debris from destroyed wrecks.
                           Returned to resource_potential (accessible ore).
      * matter_to_dust   – hull erosion each tick + non-salvageable fraction
                           of destroyed wreck inventory.  Returned to
                           hidden_resources (needs prospecting to rediscover).

    salvaged + dust always equals 100 % of lost wreck mass.
    """
    base_degradation = config.get("wreck_degradation_per_tick", 0.05)
    return_fraction = config.get("wreck_debris_return_fraction", 0.8)
    radiation_mult = config.get("entropy_radiation_multiplier", 2.0)

    radiation = hazards.get("radiation_level", 0.0)
    degradation_rate = base_degradation * (1.0 + radiation * radiation_mult)

    surviving_wrecks = []
    total_matter_salvaged = 0.0
    total_matter_to_dust = 0.0

    for wreck in wrecks:
        new_wreck = copy.deepcopy(wreck)
        old_integrity = max(0.0, new_wreck.get("wreck_integrity", 0.0))
        new_integrity = old_integrity - degradation_rate
        # Hull mass lost this tick (clamped: can't lose more than existed).
        hull_lost = old_integrity - max(0.0, new_integrity)
        total_matter_to_dust += hull_lost  # eroded hull → hidden resources
        new_wreck["wreck_integrity"] = max(0.0, new_integrity)

        if new_integrity <= 0.0:
            # Wreck destroyed — split remaining inventory.
            wreck_matter = _calculate_wreck_matter(new_wreck)  # hull is 0 here
            total_matter_salvaged += wreck_matter * return_fraction
            total_matter_to_dust += wreck_matter * (1.0 - return_fraction)
        else:
            surviving_wrecks.append(new_wreck)

    return {
        "surviving_wrecks": surviving_wrecks,
        "matter_salvaged": total_matter_salvaged,
        "matter_to_dust": total_matter_to_dust,
    }


# =========================================================================
# === POWER LOAD ==========================================================
# =========================================================================

def power_load_step(station_power_output: float, station_power_draw: float) -> dict:
    """Compute power load ratio for a sector."""
    ratio = 0.0
    if station_power_output > 0.0:
        ratio = station_power_draw / station_power_output
    return {
        "power_load_ratio": max(0.0, min(2.0, ratio)),
    }


# =========================================================================
# === MAINTENANCE PRESSURE ================================================
# =========================================================================

def maintenance_pressure_step(hazards: dict, config: dict) -> dict:
    """Compute local entropy rate and maintenance cost modifier."""
    base_rate = config.get("entropy_base_rate", 0.001)
    radiation = hazards.get("radiation_level", 0.0)
    thermal = hazards.get("thermal_background_k", 300.0)
    gravity = hazards.get("gravity_well_penalty", 1.0)

    thermal_deviation = abs(thermal - 300.0) / 300.0
    entropy_rate = base_rate * (1.0 + radiation * 2.0 + thermal_deviation) * gravity

    maintenance_modifier = 1.0 + entropy_rate * 100.0
    maintenance_modifier = max(1.0, min(3.0, maintenance_modifier))

    return {
        "local_entropy_rate": entropy_rate,
        "maintenance_cost_modifier": maintenance_modifier,
    }


# =========================================================================
# === PROSPECTING (hidden → discovered resource transfer) =================
# =========================================================================

def prospecting_step(
    sector_id: str,
    hidden_resources: dict,
    resource_potential: dict,
    market_data: dict,
    dominion_data: dict,
    hazards: dict,
    config: dict,
    rng_value: float,
) -> dict:
    """Compute resource discovery from hidden pool into discovered potential.

    Resource Layers (gated accessibility):
      Hidden resources are conceptually divided into layers:
        Surface (15%) — fast extraction (3× rate)
        Deep    (35%) — moderate extraction (1× rate)
        Mantle  (50%) — slow extraction (0.3× rate)
      As the hidden pool depletes, prospecting naturally slows because
      the remaining resources are in harder-to-reach layers.

    Prospecting intensity also depends on:
      - Market scarcity: positive price deltas → higher demand → more prospecting
      - Security: high security → safer prospecting → more discovery
      - Hazards: high radiation → dangerous conditions → less prospecting

    Args:
        rng_value: A pre-generated random float in [0, 1] for deterministic
                   variance.  Passed in by the caller (seeded RNG).

    Returns dict with:
        new_hidden:      updated hidden resource dict
        new_potential:    updated discovered resource dict
        matter_discovered: total matter transferred (for bookkeeping)
    """
    base_rate = config.get("prospecting_base_rate", 0.002)
    scarcity_boost = config.get("prospecting_scarcity_boost", 2.0)
    security_factor_max = config.get("prospecting_security_factor", 1.0)
    hazard_penalty = config.get("prospecting_hazard_penalty", 0.5)
    randomness = config.get("prospecting_randomness", 0.3)

    # Resource layer definitions
    layer_fractions = config.get("resource_layer_fractions",
                                  {"surface": 0.15, "deep": 0.35, "mantle": 0.50})
    layer_rates = config.get("resource_layer_rate_multipliers",
                              {"surface": 3.0, "deep": 1.0, "mantle": 0.3})

    new_hidden = copy.deepcopy(hidden_resources)
    new_potential = copy.deepcopy(resource_potential)
    total_discovered = 0.0

    # --- Scarcity signal: average of positive price deltas ---
    price_deltas = market_data.get("commodity_price_deltas", {})
    positive_deltas = [d for d in price_deltas.values() if d > 0.0]
    scarcity_signal = 0.0
    if positive_deltas:
        scarcity_signal = sum(positive_deltas) / len(positive_deltas)
    scarcity_mult = 1.0 + min(scarcity_signal * 10.0, 1.0) * scarcity_boost

    # --- Security factor: [0.5, 1.0] based on security_level ---
    security = dominion_data.get("security_level", 0.5)
    sec_mult = 0.5 + 0.5 * security * security_factor_max

    # --- Hazard factor: [1 - penalty, 1.0] based on radiation ---
    radiation = hazards.get("radiation_level", 0.0)
    haz_mult = max(0.1, 1.0 - radiation * hazard_penalty)

    # --- Randomness ---
    rng_mult = 1.0 + (rng_value * 2.0 - 1.0) * randomness

    # --- Combined base prospecting rate ---
    rate_base = base_rate * scarcity_mult * sec_mult * haz_mult * rng_mult
    rate_base = max(0.0, rate_base)

    # --- Discover minerals (with depth layer penalty) ---
    hidden_mineral = new_hidden.get("mineral_density", 0.0)
    if hidden_mineral > 0.0:
        depth_mult = _resource_layer_multiplier(hidden_mineral, resource_potential.get("mineral_density", 0.0),
                                                 layer_fractions, layer_rates)
        effective_rate = rate_base * depth_mult
        discover_mineral = min(hidden_mineral, effective_rate * hidden_mineral)
        new_hidden["mineral_density"] = hidden_mineral - discover_mineral
        new_potential["mineral_density"] = new_potential.get("mineral_density", 0.0) + discover_mineral
        total_discovered += discover_mineral

    # --- Discover propellant (with depth layer penalty) ---
    hidden_propellant = new_hidden.get("propellant_sources", 0.0)
    if hidden_propellant > 0.0:
        depth_mult = _resource_layer_multiplier(hidden_propellant, resource_potential.get("propellant_sources", 0.0),
                                                 layer_fractions, layer_rates)
        effective_rate = rate_base * depth_mult
        discover_propellant = min(hidden_propellant, effective_rate * hidden_propellant)
        new_hidden["propellant_sources"] = hidden_propellant - discover_propellant
        new_potential["propellant_sources"] = new_potential.get("propellant_sources", 0.0) + discover_propellant
        total_discovered += discover_propellant

    return {
        "new_hidden": new_hidden,
        "new_potential": new_potential,
        "matter_discovered": total_discovered,
    }


def _resource_layer_multiplier(
    hidden_remaining: float,
    discovered_so_far: float,
    layer_fractions: dict,
    layer_rates: dict,
) -> float:
    """Compute depth-based rate multiplier for resource extraction.

    Determines which 'layer' is currently being mined based on how much
    of the original total has been extracted, and returns the corresponding
    rate multiplier.

    Layers (mined top-down):
      Surface (first 15% of original) — rate × 3.0
      Deep    (next 35%)              — rate × 1.0
      Mantle  (last 50%)              — rate × 0.3
    """
    original_total = hidden_remaining + discovered_so_far
    if original_total <= 0.0:
        return 1.0

    fraction_remaining = hidden_remaining / original_total

    # Layers are defined top-down: surface is mined first (highest fraction_remaining)
    surface_frac = layer_fractions.get("surface", 0.15)
    deep_frac = layer_fractions.get("deep", 0.35)
    # mantle = everything else

    # If more than (deep + mantle) fraction remains, we're in the surface layer
    if fraction_remaining > (1.0 - surface_frac):
        return layer_rates.get("surface", 3.0)
    # If more than mantle fraction remains, we're in the deep layer
    elif fraction_remaining > layer_fractions.get("mantle", 0.50):
        return layer_rates.get("deep", 1.0)
    else:
        return layer_rates.get("mantle", 0.3)


# =========================================================================
# === HAZARD DRIFT (space weather) ========================================
# =========================================================================

def hazard_drift_step(
    sector_id: str,
    base_hazards: dict,
    tick: int,
    sector_index: int,
    config: dict,
) -> dict:
    """Compute drifted hazard values using slow sinusoidal modulation.

    Each sector has a phase offset (sector_index * 2π/4) so sectors
    experience space weather at different times.  Gravity is NOT drifted
    (structural, not weather).

    Returns new hazards dict (does not mutate base_hazards).
    """
    period = config.get("hazard_drift_period", 200)
    rad_amp = config.get("hazard_radiation_amplitude", 0.04)
    thermal_amp = config.get("hazard_thermal_amplitude", 15.0)

    # Phase offset per sector (spread evenly across cycle)
    num_sectors = config.get("num_sectors", 5)
    phase_offset = (2.0 * math.pi * sector_index) / max(num_sectors, 1)
    theta = (2.0 * math.pi * tick / max(period, 1)) + phase_offset

    sin_val = math.sin(theta)

    base_radiation = base_hazards.get("radiation_level", 0.0)
    base_thermal = base_hazards.get("thermal_background_k", 300.0)
    base_gravity = base_hazards.get("gravity_well_penalty", 1.0)

    new_radiation = max(0.0, base_radiation + rad_amp * sin_val)
    new_thermal = max(50.0, base_thermal + thermal_amp * sin_val)

    return {
        "radiation_level": new_radiation,
        "thermal_background_k": new_thermal,
        "gravity_well_penalty": base_gravity,  # unchanged
    }


# =========================================================================
# === STOCKPILE CONSUMPTION (population sink) =============================
# =========================================================================

def stockpile_consumption_step(
    sector_id: str,
    stockpiles: dict,
    population_density: float,
    config: dict,
) -> dict:
    """Simulate population consuming commodities from stockpiles.

    Every tick, the local population burns a fraction of each commodity.
    This prevents the "Full Warehouse" problem where stations fill up
    and prices crash to the floor.

    The consumed matter is split:
      * entropy_tax_fraction → hostile_matter_pool (funds hostile ecology)
      * remainder → hidden_resources (waste recycled into the ground)

    Axiom 1: total consumed = matter_to_hostile_pool + matter_to_hidden.
    """
    base_rate = config.get("consumption_rate_per_tick", 0.001)
    entropy_tax = config.get("consumption_entropy_tax", 0.10)

    new_stockpiles = copy.deepcopy(stockpiles)
    commodities = new_stockpiles.get("commodity_stockpiles", {})

    total_consumed = 0.0
    effective_rate = base_rate * population_density

    for commodity_id in list(commodities.keys()):
        qty = commodities[commodity_id]
        if qty <= 0.0:
            continue
        consumed = qty * effective_rate
        consumed = min(consumed, qty)  # Can't consume more than exists
        commodities[commodity_id] = qty - consumed
        total_consumed += consumed

    matter_to_hostile = total_consumed * entropy_tax
    matter_to_hidden = total_consumed * (1.0 - entropy_tax)

    return {
        "new_stockpiles": new_stockpiles,
        "total_consumed": total_consumed,
        "matter_to_hostile_pool": matter_to_hostile,
        "matter_to_hidden": matter_to_hidden,
    }


# =========================================================================
# === PRIVATE HELPERS =====================================================
# =========================================================================

def _sum_commodity_values(commodities: dict) -> float:
    """Sum all values in a commodity dictionary."""
    return sum(float(v) for v in commodities.values())


def _calculate_wreck_matter(wreck: dict) -> float:
    """Estimate matter content of a wreck from its inventory + hull."""
    matter = 0.0
    inventory = wreck.get("wreck_inventory", {})
    for val in inventory.values():
        matter += float(val)
    matter += max(0.0, wreck.get("wreck_integrity", 0.0))  # hull mass = integrity
    return matter
