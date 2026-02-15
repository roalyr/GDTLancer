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
"""

from game_state import GameState
from world_layer import WorldLayer
from grid_layer import GridLayer
from agent_layer import AgentLayer
from bridge_systems import BridgeSystems
from chronicle_layer import ChronicleLayer
import constants


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
        """Verify total matter equals the initial checksum."""
        expected = self.state.world_total_matter
        actual = self._calculate_total_matter()
        tolerance = self._tick_config.get("axiom1_tolerance", 0.01)
        drift = abs(actual - expected)

        if drift > tolerance:
            breakdown = self._matter_breakdown()
            print(
                f"AXIOM 1 DRIFT: {drift:.4f} (expected: {expected:.2f}, actual: {actual:.2f})\n"
                f"  Resource potential: {breakdown['resource_potential']:.2f}\n"
                f"  Hidden resources: {breakdown['hidden_resources']:.2f}\n"
                f"  Grid stockpiles: {breakdown['grid_stockpiles']:.2f}\n"
                f"  Wrecks: {breakdown['wrecks']:.2f}\n"
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
            total += 1.0

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
            wrecks += 1.0

        agent_inventories = 0.0
        for char_uid, inv in self.state.inventories.items():
            if 2 in inv:
                commodities = inv[2]
                for commodity_id, qty in commodities.items():
                    agent_inventories += float(qty)

        return {
            "resource_potential": resource_potential,
            "hidden_resources": hidden_resources,
            "grid_stockpiles": grid_stockpiles,
            "wrecks": wrecks,
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
            "hostile_growth_rate": constants.HOSTILE_GROWTH_RATE,
            # Hostile encounters
            "piracy_encounter_chance": constants.PIRACY_ENCOUNTER_CHANCE,
            "piracy_damage_min": constants.PIRACY_DAMAGE_MIN,
            "piracy_damage_max": constants.PIRACY_DAMAGE_MAX,
            "piracy_cargo_loss_fraction": constants.PIRACY_CARGO_LOSS_FRACTION,
            # Cash sinks
            "repair_cost_per_point": constants.REPAIR_COST_PER_POINT,
            "docking_fee_base": constants.DOCKING_FEE_BASE,
            "fuel_cost_per_unit": constants.FUEL_COST_PER_UNIT,
            # Faction anchoring
            "faction_anchor_strength": constants.CA_FACTION_ANCHOR_STRENGTH,
            # Axiom 1
            "axiom1_tolerance": constants.AXIOM1_TOLERANCE,
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
