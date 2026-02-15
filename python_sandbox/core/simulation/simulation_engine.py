"""
GDTLancer Simulation Engine — tick orchestrator.
Mirror of src/core/simulation/simulation_engine.gd.

Manages the full tick sequence:
  Step 1: World Layer — static, no per-tick processing
  Step 2: Grid Layer — CA-driven resource/dominion/market evolution
  Step 3: Bridge Systems — cross-layer heat/entropy/knowledge
  Step 4: Agent Layer — NPC goal evaluation and action execution
  Step 5: Chronicle Layer — event capture and rumor generation
  ASSERT: Conservation Axiom 1 — total matter unchanged

PROJECT: GDTLancer
MODULE: core/simulation/simulation_engine.py
STATUS: Level 2 - Implementation
TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md (Section 1: Tick Orchestration)
"""

from autoload.game_state import GameState
from core.simulation.world_layer import WorldLayer
from core.simulation.grid_layer import GridLayer
from core.simulation.agent_layer import AgentLayer
from core.simulation.bridge_systems import BridgeSystems
from core.simulation.chronicle_layer import ChronicleLayer
from autoload import constants


class SimulationEngine:
    """Tick orchestrator for the four-layer simulation."""

    def __init__(self):
        self.state = GameState()
        self.world_layer = WorldLayer()
        self.grid_layer = GridLayer()
        self.agent_layer = AgentLayer()
        self.bridge_systems = BridgeSystems()
        self.chronicle_layer = ChronicleLayer()

        self._initialized: bool = False
        self._tick_config: dict = {}

        self._build_tick_config()

    # -----------------------------------------------------------------
    # Initialization
    # -----------------------------------------------------------------
    def initialize_simulation(self, seed_string: str) -> None:
        """Initialize the full simulation from a seed string."""
        print(f"SimulationEngine: Initializing simulation with seed '{seed_string}'...")

        # Step 1: World Layer
        self.world_layer.initialize_world(self.state, seed_string)

        # Step 2: Grid Layer
        self.grid_layer.initialize_grid(self.state)

        # Step 3: Agent Layer
        self.agent_layer.initialize_agents(self.state)

        # Give agent layer a reference to chronicle for event logging
        self.agent_layer.set_chronicle(self.chronicle_layer)

        # Initialize World Age Cycle
        self.state.world_age = constants.WORLD_AGE_CYCLE[0]
        self.state.world_age_timer = constants.WORLD_AGE_DURATIONS[
            self.state.world_age
        ]
        self.state.world_age_cycle_count = 0
        self._apply_age_config()  # Apply initial age overrides

        # Dynamic sector count for hazard phase calculation
        self._tick_config["num_sectors"] = len(self.state.world_topology)

        # Recalculate total matter for definitive Axiom 1 checksum
        self.world_layer.recalculate_total_matter(self.state)

        self._initialized = True

        print(
            f"SimulationEngine: Initialization complete. "
            f"Matter budget: {self.state.world_total_matter:.2f}, "
            f"Tick: {self.state.sim_tick_count}"
        )

    # -----------------------------------------------------------------
    # Tick Processing
    # -----------------------------------------------------------------
    def process_tick(self) -> None:
        """Process one full simulation tick through all layers."""
        self.state.sim_tick_count += 1
        tick = self.state.sim_tick_count

        # World Age Cycle — advance age timer, transition on expiry
        self._advance_world_age()

        # Step 1: World Layer (static — no processing)
        # Step 2: Grid Layer
        self.grid_layer.process_tick(self.state, self._tick_config)

        # Step 3: Bridge Systems
        self.bridge_systems.process_tick(self.state, self._tick_config)

        # Step 4: Agent Layer
        self.agent_layer.process_tick(self.state, self._tick_config)

        # Step 5: Chronicle Layer
        self.chronicle_layer.process_tick(self.state)

        # ASSERT: Conservation Axiom 1
        is_conserved = self.verify_matter_conservation()
        if not is_conserved:
            print(f"SimulationEngine: AXIOM 1 VIOLATION at tick {tick}!")

    # -----------------------------------------------------------------
    # Conservation Axiom 1
    # -----------------------------------------------------------------
    def verify_matter_conservation(self) -> bool:
        """Verify total matter stays within relative tolerance of initial budget."""
        expected = self.state.world_total_matter
        actual = self._calculate_total_matter()
        rel_tolerance = self._tick_config.get("axiom1_relative_tolerance", 0.005)
        abs_drift = abs(actual - expected)
        rel_drift = abs_drift / max(expected, 1.0)

        if rel_drift > rel_tolerance:
            breakdown = self._matter_breakdown()
            print(
                f"AXIOM 1 DRIFT: {abs_drift:.4f} ({rel_drift*100:.4f}% of budget, "
                f"limit={rel_tolerance*100:.2f}%)\n"
                f"  expected: {expected:.2f}, actual: {actual:.2f}\n"
                f"  Resource potential: {breakdown['resource_potential']:.2f}\n"
                f"  Hidden resources: {breakdown['hidden_resources']:.2f}\n"
                f"  Grid stockpiles: {breakdown['grid_stockpiles']:.2f}\n"
                f"  Wrecks: {breakdown['wrecks']:.2f}\n"
                f"  Hostile pool: {breakdown['hostile_pool']:.2f}\n"
                f"  Hostile bodies: {breakdown['hostile_bodies']:.2f}\n"
                f"  Agent inventories: {breakdown['agent_inventories']:.2f}"
            )
            return False
        return True

    def _calculate_total_matter(self) -> float:
        total = 0.0

        # Layer 1: Resource potential
        for sector_id, potential in self.state.world_resource_potential.items():
            total += potential.get("mineral_density", 0.0)
            total += potential.get("propellant_sources", 0.0)

        # Layer 1: Hidden resources
        for sector_id, hidden in self.state.world_hidden_resources.items():
            total += hidden.get("mineral_density", 0.0)
            total += hidden.get("propellant_sources", 0.0)

        # Layer 2: Grid stockpiles
        for sector_id, stockpile in self.state.grid_stockpiles.items():
            commodities = stockpile.get("commodity_stockpiles", {})
            for commodity_id, qty in commodities.items():
                total += float(qty)

        # Layer 2: Wrecks
        for wreck_uid, wreck in self.state.grid_wrecks.items():
            inventory = wreck.get("wreck_inventory", {})
            for item_id, qty in inventory.items():
                total += float(qty)
            total += wreck.get("wreck_integrity", 0.0)  # hull mass = integrity

        # Hostile matter pools (per-type: reserve + body_mass)
        for htype_pool in self.state.hostile_pools.values():
            total += htype_pool.get("reserve", 0.0)
            total += htype_pool.get("body_mass", 0.0)

        # Layer 3: Agent inventories
        for char_uid, inv in self.state.inventories.items():
            if 2 in inv:
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    total += float(qty)

        return total

    def _matter_breakdown(self) -> dict:
        resource_potential = 0.0
        for sector_id, potential in self.state.world_resource_potential.items():
            resource_potential += potential.get("mineral_density", 0.0)
            resource_potential += potential.get("propellant_sources", 0.0)

        hidden_resources = 0.0
        for sector_id, hidden in self.state.world_hidden_resources.items():
            hidden_resources += hidden.get("mineral_density", 0.0)
            hidden_resources += hidden.get("propellant_sources", 0.0)

        grid_stockpiles = 0.0
        for sector_id, stockpile in self.state.grid_stockpiles.items():
            commodities = stockpile.get("commodity_stockpiles", {})
            for commodity_id, qty in commodities.items():
                grid_stockpiles += float(qty)

        wrecks = 0.0
        for wreck_uid, wreck in self.state.grid_wrecks.items():
            inventory = wreck.get("wreck_inventory", {})
            for item_id, qty in inventory.items():
                wrecks += float(qty)
            wrecks += wreck.get("wreck_integrity", 0.0)  # hull mass = integrity

        hostile_pool = sum(p.get("reserve", 0.0) for p in self.state.hostile_pools.values())

        agent_inventories = 0.0
        for char_uid, inv in self.state.inventories.items():
            if 2 in inv:
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    agent_inventories += float(qty)

        hostile_bodies = sum(p.get("body_mass", 0.0) for p in self.state.hostile_pools.values())

        return {
            "resource_potential": resource_potential,
            "hidden_resources": hidden_resources,
            "grid_stockpiles": grid_stockpiles,
            "wrecks": wrecks,
            "hostile_pool": hostile_pool,
            "hostile_bodies": hostile_bodies,
            "agent_inventories": agent_inventories,
        }

    # -----------------------------------------------------------------
    # World Age Cycle
    # -----------------------------------------------------------------
    def _advance_world_age(self) -> None:
        """Cycle through world ages: PROSPERITY → DISRUPTION → RECOVERY → ..."""
        self.state.world_age_timer -= 1
        if self.state.world_age_timer <= 0:
            cycle = constants.WORLD_AGE_CYCLE
            current_idx = cycle.index(self.state.world_age)
            next_idx = (current_idx + 1) % len(cycle)

            if next_idx == 0:
                self.state.world_age_cycle_count += 1

            self.state.world_age = cycle[next_idx]
            self.state.world_age_timer = constants.WORLD_AGE_DURATIONS[
                self.state.world_age
            ]
            self._apply_age_config()

            # Log the transition as a chronicle event
            if self.chronicle_layer:
                event = {
                    "actor_uid": "world",
                    "action_id": "age_change",
                    "target_uid": "",
                    "target_sector_id": "",
                    "tick_count": self.state.sim_tick_count,
                    "outcome": "success",
                    "metadata": {"new_age": self.state.world_age},
                }
                self.chronicle_layer.log_event(self.state, event)

    def _apply_age_config(self) -> None:
        """Rebuild tick config with base values, then overlay current age overrides."""
        self._build_tick_config()  # Reset to base
        age_overrides = constants.WORLD_AGE_CONFIGS.get(self.state.world_age, {})
        self._tick_config.update(age_overrides)

    # -----------------------------------------------------------------
    # Config
    # -----------------------------------------------------------------
    def _build_tick_config(self) -> None:
        self._tick_config = {
            # Grid CA
            "influence_propagation_rate": constants.CA_INFLUENCE_PROPAGATION_RATE,
            "pirate_activity_decay": constants.CA_PIRATE_ACTIVITY_DECAY,
            "pirate_activity_growth": constants.CA_PIRATE_ACTIVITY_GROWTH,
            "stockpile_diffusion_rate": constants.CA_STOCKPILE_DIFFUSION_RATE,
            "extraction_rate_default": constants.CA_EXTRACTION_RATE_DEFAULT,
            "price_sensitivity": constants.CA_PRICE_SENSITIVITY,
            "demand_base": constants.CA_DEMAND_BASE,
            # Wreck / Entropy
            "wreck_degradation_per_tick": constants.WRECK_DEGRADATION_PER_TICK,
            "wreck_debris_return_fraction": constants.WRECK_DEBRIS_RETURN_FRACTION,
            "entropy_radiation_multiplier": constants.ENTROPY_RADIATION_MULTIPLIER,
            "entropy_base_rate": constants.ENTROPY_BASE_RATE,
            # Power
            "power_draw_per_agent": constants.POWER_DRAW_PER_AGENT,
            "power_draw_per_service": constants.POWER_DRAW_PER_SERVICE,
            # Bridge Systems
            "heat_generation_in_space": constants.HEAT_GENERATION_IN_SPACE,
            "heat_dissipation_base": constants.HEAT_DISSIPATION_DOCKED,
            "heat_overheat_threshold": constants.HEAT_OVERHEAT_THRESHOLD,
            "entropy_hull_multiplier": constants.ENTROPY_HULL_MULTIPLIER,
            "fleet_entropy_reduction": constants.ENTROPY_FLEET_RATE_FRACTION,
            "propellant_drain_per_tick": constants.PROPELLANT_DRAIN_PER_TICK,
            "energy_drain_per_tick": constants.ENERGY_DRAIN_PER_TICK,
            "knowledge_noise_factor": constants.AGENT_KNOWLEDGE_NOISE_FACTOR,
            # Agent
            "npc_cash_low_threshold": constants.NPC_CASH_LOW_THRESHOLD,
            "npc_hull_repair_threshold": constants.NPC_HULL_REPAIR_THRESHOLD,
            "commodity_base_price": constants.COMMODITY_BASE_PRICE,
            "world_tick_interval_seconds": float(constants.WORLD_TICK_INTERVAL_SECONDS),
            "respawn_timeout_seconds": constants.RESPAWN_TIMEOUT_SECONDS,
            # Hostile encounters (drones & aliens)
            "hostile_encounter_chance": constants.HOSTILE_ENCOUNTER_CHANCE,
            "hostile_damage_min": constants.HOSTILE_DAMAGE_MIN,
            "hostile_damage_max": constants.HOSTILE_DAMAGE_MAX,
            "hostile_cargo_loss_fraction": constants.HOSTILE_CARGO_LOSS_FRACTION,
            # Hostile spawning ecology
            "hostile_wreck_salvage_rate": constants.HOSTILE_WRECK_SALVAGE_RATE,
            "hostile_spawn_cost": constants.HOSTILE_SPAWN_COST,
            "hostile_low_security_threshold": constants.HOSTILE_LOW_SECURITY_THRESHOLD,
            "hostile_kill_per_military": constants.HOSTILE_KILL_PER_MILITARY,
            # Pirate role
            "pirate_raid_chance": constants.PIRATE_RAID_CHANCE,
            "pirate_raid_cargo_steal": constants.PIRATE_RAID_CARGO_STEAL,
            "pirate_move_interval": constants.PIRATE_MOVE_INTERVAL,
            "pirate_home_advantage": constants.PIRATE_HOME_ADVANTAGE,
            # Catastrophic events
            "catastrophe_chance_per_tick": constants.CATASTROPHE_CHANCE_PER_TICK,
            "catastrophe_disable_duration": constants.CATASTROPHE_DISABLE_DURATION,
            "catastrophe_stockpile_to_wreck": constants.CATASTROPHE_STOCKPILE_TO_WRECK,
            "catastrophe_hazard_boost": constants.CATASTROPHE_HAZARD_BOOST,
            "catastrophe_security_drop": constants.CATASTROPHE_SECURITY_DROP,
            # Prospector wreck salvage
            "prospector_wreck_salvage_rate": constants.PROSPECTOR_WRECK_SALVAGE_RATE,
            "prospector_wreck_security_threshold": constants.PROSPECTOR_WRECK_SECURITY_THRESHOLD,
            # Cash sinks
            "repair_cost_per_point": constants.REPAIR_COST_PER_POINT,
            "docking_fee_base": constants.DOCKING_FEE_BASE,
            "fuel_cost_per_unit": constants.FUEL_COST_PER_UNIT,
            # Faction anchoring
            "faction_anchor_strength": constants.CA_FACTION_ANCHOR_STRENGTH,
            # Axiom 1 (relative: fraction of total matter budget)
            "axiom1_relative_tolerance": constants.AXIOM1_RELATIVE_TOLERANCE,
            # Prospecting
            "prospecting_base_rate": constants.PROSPECTING_BASE_RATE,
            "prospecting_scarcity_boost": constants.PROSPECTING_SCARCITY_BOOST,
            "prospecting_security_factor": constants.PROSPECTING_SECURITY_FACTOR,
            "prospecting_hazard_penalty": constants.PROSPECTING_HAZARD_PENALTY,
            "prospecting_randomness": constants.PROSPECTING_RANDOMNESS,
            # Hazard drift (space weather)
            "hazard_drift_period": constants.HAZARD_DRIFT_PERIOD,
            "hazard_radiation_amplitude": constants.HAZARD_RADIATION_AMPLITUDE,
            "hazard_thermal_amplitude": constants.HAZARD_THERMAL_AMPLITUDE,
            # Roles
            "prospector_discovery_multiplier": constants.PROSPECTOR_DISCOVERY_MULTIPLIER,
            "prospector_move_interval": constants.PROSPECTOR_MOVE_INTERVAL,
            "military_security_boost": constants.MILITARY_SECURITY_BOOST,
            "military_piracy_suppress": constants.MILITARY_PIRACY_SUPPRESS,
            "military_patrol_interval": constants.MILITARY_PATROL_INTERVAL,
            "hauler_cargo_capacity": constants.HAULER_CARGO_CAPACITY,
            "hauler_surplus_threshold": constants.HAULER_SURPLUS_THRESHOLD,
            "hauler_deficit_threshold": constants.HAULER_DEFICIT_THRESHOLD,
            # Agent desperation / debt
            "desperation_hull_threshold": constants.DESPERATION_HULL_THRESHOLD,
            "desperation_trade_hull_risk": constants.DESPERATION_TRADE_HULL_RISK,
            "debt_interest_rate": constants.DEBT_INTEREST_RATE,
            "debt_cap": constants.DEBT_CAP,
            "respawn_debt_penalty": constants.RESPAWN_DEBT_PENALTY,
            # Entropy death
            "entropy_death_hull_threshold": constants.ENTROPY_DEATH_HULL_THRESHOLD,
            "entropy_death_tick_grace": constants.ENTROPY_DEATH_TICK_GRACE,
            # Hostile global threat (decoupled from piracy)
            "hostile_global_cap": constants.HOSTILE_GLOBAL_CAP,
            # Hostile pool spawning (pool → body_mass → wrecks → salvage cycle)
            "hostile_spawn_cost": constants.HOSTILE_SPAWN_COST,
            "hostile_pool_pressure_threshold": constants.HOSTILE_POOL_PRESSURE_THRESHOLD,
            "hostile_pool_spawn_rate": constants.HOSTILE_POOL_SPAWN_RATE,
            "hostile_pool_max_spawns_per_tick": constants.HOSTILE_POOL_MAX_SPAWNS_PER_TICK,
            # Hostile raids on stockpiles
            "hostile_raid_threshold": constants.HOSTILE_RAID_THRESHOLD,
            "hostile_raid_chance": constants.HOSTILE_RAID_CHANCE,
            "hostile_raid_stockpile_fraction": constants.HOSTILE_RAID_STOCKPILE_FRACTION,
            "hostile_raid_casualties": constants.HOSTILE_RAID_CASUALTIES,
            # Resource layers (prospecting depth gating)
            "resource_layer_fractions": constants.RESOURCE_LAYER_FRACTIONS,
            "resource_layer_rate_multipliers": constants.RESOURCE_LAYER_RATE_MULTIPLIERS,
            "resource_layer_depletion_threshold": constants.RESOURCE_LAYER_DEPLETION_THRESHOLD,
            # Stockpile consumption (population sink)
            "consumption_rate_per_tick": constants.CONSUMPTION_RATE_PER_TICK,
            "consumption_entropy_tax": constants.CONSUMPTION_ENTROPY_TAX,
            # Respawn cooldown
            "respawn_cooldown_max_debt": constants.RESPAWN_COOLDOWN_MAX_DEBT,
            "respawn_cooldown_normal": constants.RESPAWN_COOLDOWN_NORMAL,
            # Colony levels
            "colony_upgrade_stockpile_fraction": constants.COLONY_UPGRADE_STOCKPILE_FRACTION,
            "colony_upgrade_security_min": constants.COLONY_UPGRADE_SECURITY_MIN,
            "colony_upgrade_ticks_required": constants.COLONY_UPGRADE_TICKS_REQUIRED,
            "colony_downgrade_stockpile_fraction": constants.COLONY_DOWNGRADE_STOCKPILE_FRACTION,
            "colony_downgrade_security_min": constants.COLONY_DOWNGRADE_SECURITY_MIN,
            "colony_downgrade_ticks_required": constants.COLONY_DOWNGRADE_TICKS_REQUIRED,
            # Mortal agents
            "mortal_spawn_chance_per_tick": constants.MORTAL_SPAWN_CHANCE_PER_TICK,
            "mortal_spawn_min_stockpile": constants.MORTAL_SPAWN_MIN_STOCKPILE,
            "mortal_spawn_min_security": constants.MORTAL_SPAWN_MIN_SECURITY,
            "mortal_spawn_cash": constants.MORTAL_SPAWN_CASH,
            "mortal_global_cap": constants.MORTAL_GLOBAL_CAP,
            # Explorer role
            "explorer_expedition_cost": constants.EXPLORER_EXPEDITION_COST,
            "explorer_expedition_fuel": constants.EXPLORER_EXPEDITION_FUEL,
            "explorer_discovery_chance": constants.EXPLORER_DISCOVERY_CHANCE,
            "explorer_move_interval": constants.EXPLORER_MOVE_INTERVAL,
            "explorer_wage": constants.EXPLORER_WAGE,
            "explorer_max_discovered_sectors": constants.EXPLORER_MAX_DISCOVERED_SECTORS,
            "new_sector_base_capacity": constants.NEW_SECTOR_BASE_CAPACITY,
            "new_sector_base_power": constants.NEW_SECTOR_BASE_POWER,
            "explorer_discovery_multiplier": constants.EXPLORER_DISCOVERY_MULTIPLIER,
        }

    # -----------------------------------------------------------------
    # Public utility
    # -----------------------------------------------------------------
    def get_chronicle(self) -> ChronicleLayer:
        return self.chronicle_layer

    def is_initialized(self) -> bool:
        return self._initialized

    def set_config(self, key: str, value) -> None:
        self._tick_config[key] = value

    def get_config(self) -> dict:
        return self._tick_config
