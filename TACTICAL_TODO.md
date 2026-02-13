## CURRENT GOAL: Simulation Engine Foundation — Radical Architecture Rework

### EXECUTIVE SUMMARY

Strip the codebase to its simulation core. The current architecture has accumulated
systems that are over-coupled, redundant, or prematurely tied to UI/scenes. This
rework establishes the four-layer simulation engine (World → Grid → Agents → Chronicle)
as a pure data-processing pipeline that runs independently of any visual representation.

**What stays:** Flight mechanics, camera, ship physics, player input, agent local-space
movement, basic scene infrastructure, TemplateDatabase, base template definitions.

**What gets gutted:** All narrative/combat/trading/contract/quirk/progression systems
are removed or reduced to stubs. They will be rebuilt on top of the simulation engine
once the CA layers are proven.

**New core:** A CA-driven simulation engine inspired by the GDD's four-layer model
and the ecosystem automaton pattern — double-buffered grids, tick-driven processing,
faction dominion, resource flow, entropy.

---

- TARGET_FILES:

  **KEEP AS-IS (no changes):**
  - `src/modules/piloting/` (all files — flight mechanics)
  - `src/scenes/camera/` (all files — camera system)
  - `src/scenes/game_world/world_rendering.gd`
  - `src/scenes/game_world/station/dockable_station.gd`
  - `assets/` (all art assets)
  - `scenes/prefabs/` (all prefab scenes)
  - `addons/` (GUT, gdformat)

  **KEEP + SIMPLIFY:**
  - `src/autoload/Constants.gd` (keep, extend with simulation constants)
  - `src/autoload/EventBus.gd` (keep, prune dead signals, add sim signals)
  - `src/autoload/GlobalRefs.gd` (keep, prune dead refs, add sim refs)
  - `src/autoload/GameState.gd` (gut and rebuild around 4-layer model)
  - `src/autoload/GameStateManager.gd` (keep, update serialization for new state)
  - `src/autoload/TemplateDatabase.gd` (keep as-is)
  - `src/autoload/CoreMechanicsAPI.gd` (keep as-is — dice engine is fine)
  - `src/core/systems/time_system.gd` (keep, simplify to drive tick sequence)
  - `src/core/systems/agent_system.gd` (keep spawning, gut persistent agent complexity)
  - `src/scenes/game_world/world_manager.gd` (keep, rewire init to use sim engine)
  - `src/scenes/game_world/world_manager/world_generator.gd` (keep, update)
  - `src/scenes/game_world/world_manager/template_indexer.gd` (keep as-is)

  **DELETE (rebuild later on sim foundation):**
  - `src/autoload/NarrativeOutcomes.gd` (premature — rebuild on Chronicle layer)
  - `src/core/systems/action_system.gd` (broken, redundant with narrative_action_system)
  - `src/core/systems/combat_system.gd` (premature — rebuild on Agent layer)
  - `src/core/systems/trading_system.gd` (premature — rebuild on Grid layer)
  - `src/core/systems/narrative_action_system.gd` (premature — rebuild on Chronicle)
  - `src/core/systems/contract_system.gd` (premature — rebuild on Agent goals)
  - `src/core/systems/quirk_system.gd` (premature — rebuild on Entropy system)
  - `src/core/systems/progression_system.gd` (empty stub)
  - `src/core/systems/traffic_system.gd` (empty stub)
  - `src/core/systems/world_map_system.gd` (empty stub)
  - `src/core/systems/goal_system.gd` (empty stub)
  - `src/core/systems/chronicle_system.gd` (empty stub — replaced by real impl)
  - `src/core/ui/action_check/` (premature)
  - `src/core/ui/inventory_screen/` (premature)
  - `src/core/ui/narrative_status/` (premature)
  - `src/core/ui/contacts_panel/` (premature)
  - `src/core/ui/character_status/` (premature)
  - `src/scenes/ui/station_menu/` (premature)
  - `database/registry/contacts/` (deprecated)
  - `database/registry/quirks/` (deferred per GDD Section 4.3)
  - `database/definitions/contact_template.gd` (deprecated)
  - `database/definitions/quirk_template.gd` (deferred)

  **CREATE (new simulation engine):**
  - `src/core/simulation/simulation_engine.gd` (tick orchestrator)
  - `src/core/simulation/world_layer.gd` (Layer 1: static world data)
  - `src/core/simulation/grid_layer.gd` (Layer 2: CA-driven dynamic state)
  - `src/core/simulation/agent_layer.gd` (Layer 3: agent data processing)
  - `src/core/simulation/chronicle_layer.gd` (Layer 4: event capture)
  - `src/core/simulation/bridge_systems.gd` (Heat/Entropy/Knowledge cross-layer)
  - `src/core/simulation/ca_rules.gd` (CA rule definitions — pure functions)
  - `src/core/ui/sim_debug_panel/sim_debug_panel.gd` (debug view of sim state)
  - `src/core/ui/sim_debug_panel/sim_debug_panel.tscn`
  - `src/tests/core/simulation/test_world_layer.gd`
  - `src/tests/core/simulation/test_grid_layer.gd`
  - `src/tests/core/simulation/test_agent_layer.gd`
  - `src/tests/core/simulation/test_chronicle_layer.gd`
  - `src/tests/core/simulation/test_simulation_tick.gd`
  - `src/tests/core/simulation/test_ca_rules.gd`

- TRUTH_RELIANCE:
  - `TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md` Section 8 (Simulation Architecture): ALL of it. This is the primary reference for this entire rework. Specifically:
    - Section 1.3: Conservation Axioms (5 axioms constrain ALL systems)
    - Section 2: World Layer (topology, hazards, resource potential map)
    - Section 3: Grid Layer (resource availability, power load, dominion, market pressure, maintenance pressure, inventory flow, wreck lifecycle)
    - Section 4: Agent Layer (spatial state, skills, knowledge snapshot, social graph, goal queue, narrative inventory)
    - Section 5: Chronicle Layer (event buffer, causality chains, rumor engine)
    - Section 6: Bridge Systems (heat sink, entropy, knowledge refresh)
    - Section 7: Simulation Tick Sequence (the exact processing order)
    - Section 9: Phase 1 Implementation Scope (what is stub vs real)
  - `TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md` Section 1.2 (Cellular Automata): CA catalogue — 7 CAs that drive the Grid
  - `TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md` Section 3 (Architecture Coding): Stateless systems, GameState as truth, EventBus signals

- DESIGN_PHILOSOPHY:
  - **Simulation First, Presentation Later.** The sim engine must produce correct, observable outputs via a debug panel ONLY. No gameplay UI, no scene wiring, no player interaction with the simulation — yet. Like the Python ecosystem demo: pure data processing with a text readout.
  - **Double-Buffered Grids.** Read from one grid, write to another, swap. No mid-tick mutation of read state. Exactly like the Python demo's `read_grid` / `write_grid` pattern.
  - **Pure Function CA Rules.** All CA transition rules are pure functions: `(cell_state, neighbor_states, config) -> new_cell_state`. No side effects. Testable in isolation.
  - **Conservation Axioms are Assertions.** Every tick ends with Axiom 1 (matter conservation) verified via assertion. Total matter before tick == total matter after tick.
  - **Tick Sequence is Law.** World → Grid CAs → Bridge → Agents → Chronicle. Always this order. No shortcuts.
  - **Keep Flight Untouched.** The RigidBody flight model, PID controllers, camera, and local-space agent movement are working and will be connected to the sim engine later. Don't break them.

- TECHNICAL_CONSTRAINTS:
  - Godot 3.x, GLES2 — `export var`, `onready`, NO `await`, NO `@export`
  - GameState remains the single source of truth — but its shape changes radically
  - All simulation processing is synchronous within a single `_process_tick()` call
  - Grid dimensions: use sector count as grid size (6-9 for Phase 1 — NOT a 2D pixel grid. Each cell IS a sector/location)
  - CA neighbors = sectors connected via `connections` topology, NOT 2D adjacency
  - The simulation must be deterministic given the same seed + tick sequence
  - No scene-tree dependencies in simulation code — pure data processing
  - Debug panel reads GameState and renders text. That's it.

---

- ATOMIC_TASKS:

  - [x] TASK_1: Gut GameState — Rebuild as Four-Layer Data Store
    - Location: `src/autoload/GameState.gd`
    - REMOVE: `active_actions`, `assets_modules`, `contacts` (deprecated), `narrative_state.known_contacts`, `narrative_state.contact_relationships`, `contracts`, `active_contracts`, `session_stats`
    - RESTRUCTURE into four clear sections:
    ```
    # === LAYER 1: WORLD (static, set at init, read-only at runtime) ===
    var world_topology: Dictionary = {}
      # Key: sector_id, Value: {connections: Array, station_ids: Array, sector_type: String}
    var world_hazards: Dictionary = {}
      # Key: sector_id, Value: {radiation_level: float, thermal_background_k: float, gravity_well_penalty: float}
    var world_resource_potential: Dictionary = {}
      # Key: sector_id, Value: {mineral_density: float, energy_potential: float, propellant_sources: float}
    var world_total_matter: float = 0.0  # Axiom 1 checksum — set at init, verified each tick

    # === LAYER 2: GRID (dynamic, CA-driven, updated each tick) ===
    var grid_resource_availability: Dictionary = {}
      # Key: sector_id, Value: {propellant_supply: float, consumables_supply: float, energy_supply: float}
    var grid_dominion: Dictionary = {}
      # Key: sector_id, Value: {faction_influence: Dictionary, security_level: float, pirate_activity: float}
    var grid_market: Dictionary = {}
      # Key: sector_id, Value: {commodity_price_deltas: Dictionary, population_density: float, service_cost_modifier: float}
    var grid_stockpiles: Dictionary = {}
      # Key: sector_id, Value: {commodity_stockpiles: Dictionary, stockpile_capacity: int, extraction_rate: Dictionary}
    var grid_maintenance: Dictionary = {}
      # Key: sector_id, Value: {local_entropy_rate: float, maintenance_cost_modifier: float}
    var grid_power: Dictionary = {}
      # Key: sector_id, Value: {station_power_output: float, station_power_draw: float, power_load_ratio: float}
    var grid_wrecks: Dictionary = {}
      # Key: wreck_uid (int), Value: {sector_id, wreck_integrity, wreck_inventory, ship_template_id, created_at_tick}

    # === LAYER 3: AGENTS (cognitive entities) ===
    var characters: Dictionary = {}       # Key: char_uid, Value: CharacterTemplate instance
    var agents: Dictionary = {}           # Key: agent_id (String), Value: agent state dict
      # State: {char_uid, current_sector_id, hull_integrity, propellant_reserves, energy_reserves,
      #         consumables_reserves, cash_reserves, fleet_ships, current_heat_level,
      #         is_persistent, home_location_id, is_disabled, disabled_at_tick,
      #         known_grid_state, knowledge_timestamps, goal_queue, goal_archetype,
      #         event_memory, faction_standings, character_standings, sentiment_tags}
    var inventories: Dictionary = {}      # Key: char_uid, Value: inventory dict
    var assets_ships: Dictionary = {}     # Key: ship_uid, Value: ShipTemplate instance
    var player_character_uid: int = -1
    var hostile_population_integral: Dictionary = {}
      # Key: hostile_type_id, Value: {current_count: int, carrying_capacity: int, sector_counts: Dictionary}

    # === LAYER 4: CHRONICLE (event capture) ===
    var chronicle_event_buffer: Array = []  # Array of Event Packet dicts
    var chronicle_rumors: Array = []        # Array of generated rumor dicts

    # === SIMULATION META ===
    var sim_tick_count: int = 0
    var game_time_seconds: int = 0
    var world_seed: String = ""

    # === SCENE STATE (kept separate from simulation) ===
    var current_zone_instance: Node = null
    var player_docked_at: String = ""
    var player_position: Vector3 = Vector3.ZERO
    var player_rotation: Vector3 = Vector3.ZERO
    ```

  - [x] TASK_2: Create CA Rules Module — Pure Functions
    - Location: `src/core/simulation/ca_rules.gd` (new file)
    - Extends: Reference (pure static utility, no Node, no state)
    - Contains ALL CA transition logic as static-style functions:
    - `func strategic_map_step(sector_id, sector_state, neighbor_states, config) -> Dictionary`
      - Inputs: current {faction_influence, security_level, pirate_activity}, neighbor values, config params
      - Outputs: new {faction_influence, security_level, pirate_activity}
      - Rule: Faction influence propagates from neighbors weighted by connection count. Pirate activity inversely correlates with security. Player combat actions reduce pirate_activity.
    - `func supply_demand_step(sector_id, stockpiles, resource_potential, extraction_rate, neighbor_stockpiles, config) -> Dictionary`
      - Inputs: local stockpiles, resource potential map values, extraction rate, neighbor stockpiles
      - Outputs: new stockpiles, updated resource potential (depleted by extraction)
      - Rule: Extract from resource potential → add to stockpiles. Surplus flows to deficit neighbors (diffusion). Axiom 1: sum conserved.
    - `func market_pressure_step(sector_id, stockpiles, population_density, config) -> Dictionary`
      - Inputs: local commodity_stockpiles, population_density
      - Outputs: {commodity_price_deltas, service_cost_modifier}
      - Rule: price_delta = (demand - supply) / normalization_factor. Simple supply/demand curve.
    - `func entropy_step(sector_id, wrecks, hazards, config) -> Dictionary`
      - Inputs: local wrecks, hazard values (radiation, thermal)
      - Outputs: degraded wreck states, matter returned to resource potential
      - Rule: wreck_integrity -= degradation_rate * (1 + radiation_level). If <= 0: return matter to mineral_density.
    - `func influence_network_step(agent_id, agent_standings, neighbor_agent_standings, config) -> Dictionary`
      - Inputs: agent's character_standings, connected agents' standings
      - Outputs: updated standings (reputation propagation)
    - Each function is PURE: no GameState access, no GlobalRefs, no side effects.
    - All functions return new state — never mutate inputs.
    - Reference: GDD Section 1.2 (CA Catalogue), Section 3 (Grid Layer), Section 7 (Tick Sequence)

  - [x] TASK_3: Create World Layer Initializer
    - Location: `src/core/simulation/world_layer.gd` (new file)
    - Extends: Reference
    - Purpose: Initialize Layer 1 data in GameState from LocationTemplate .tres files and seed values.
    - `func initialize_world(seed: String) -> void`
      - Loads all LocationTemplate resources from TemplateDatabase
      - Builds `world_topology` from location data (sector_id, connections, station_ids, sector_type)
      - Builds `world_hazards` from location environmental data (or sensible defaults)
      - Builds `world_resource_potential` with finite values seeded deterministically
      - Calculates `world_total_matter` = sum of all mineral_density + propellant_sources + all commodity stockpiles + all agent cargo. Stores as Axiom 1 checksum.
    - LocationTemplate needs extension:
      - Add `connections: Array` (connected sector_ids — PoolStringArray export)
      - Add `sector_type: String` (hub/frontier/deep_space/hazard_zone)
      - Add `radiation_level: float`, `thermal_background_k: float`, `gravity_well_penalty: float`
      - Add `mineral_density: float`, `propellant_sources: float`
      - Add `station_power_output: float`, `stockpile_capacity: int`
    - Reference: GDD Section 2 (World Layer), Section 9 (Phase 1 scope)

  - [x] TASK_4: Create Grid Layer Processor
    - Location: `src/core/simulation/grid_layer.gd` (new file)
    - Extends: Reference
    - Purpose: Process all Grid-layer CA steps for one tick. Double-buffered.
    - `func initialize_grid() -> void`
      - Seeds initial grid state from world data (stockpiles from extraction, dominion from faction template data, market from base commodity values)
    - `func process_tick(config: Dictionary) -> void`
      - Implements GDD Section 7, steps 2a–2g:
      - 2a. Extraction: for each sector, extract from resource_potential → add to stockpiles (call ca_rules.supply_demand_step). Deplete world_resource_potential.
      - 2b. Supply & Demand CA: propagate stockpile surpluses to connected neighbors
      - 2c. Strategic Map CA: propagate faction influence, update security/piracy
      - 2d. Power Load: calculate power_load_ratio from docked agents + services
      - 2e. Market Pressure: derive price_deltas from stockpiles vs demand
      - 2f. Wreck & Debris: degrade wrecks, return matter (call ca_rules.entropy_step)
      - 2g. Maintenance Pressure: derive local_entropy_rate from hazards
    - Double-buffering: read from `GameState.grid_*`, write to local buffer, then copy buffer to GameState atomically at end of process_tick.
    - After processing: assert Axiom 1 (total matter unchanged).

  - [x] TASK_5: Create Agent Layer Processor
    - Location: `src/core/simulation/agent_layer.gd` (new file)
    - Extends: Reference
    - Purpose: Process all Agent-layer logic for one tick.
    - `func initialize_agents() -> void`
      - Seeds agent state from AgentTemplate/CharacterTemplate .tres files
      - Player agent from player_default.tres
      - 6 persistent agents from persistent_*.tres
      - Initialize knowledge_snapshots as copies of actual grid state (Phase 1 stub)
      - Initialize goal_queues with 1-2 simple goals per agent
    - `func process_tick(config: Dictionary) -> void`
      - Implements GDD Section 7, steps 4a–4c:
      - 4a. NPC Goal Evaluation: each NPC reads known_grid_state, re-evaluates goals
        - Phase 1: Simple heuristic — if cash low, goal = trade. If at home, goal = idle. If damaged, goal = repair.
      - 4b. NPC Action Selection: each NPC selects highest-priority feasible action
        - Phase 1: Actions are abstract state changes (move to sector, buy commodity, sell commodity, idle) — NO scene-tree interaction
      - 4c. Player actions: skip (player acts in real-time, sim just reads results)
    - Persistent agent respawn: if disabled and enough ticks elapsed, set is_disabled = false, move to home sector
    - Hostile population: track global integral, adjust based on carrying capacity derived from pirate_activity grid values

  - [x] TASK_6: Create Bridge Systems Processor
    - Location: `src/core/simulation/bridge_systems.gd` (new file)
    - Extends: Reference
    - Purpose: Cross-layer processing (GDD Section 7, steps 3a–3c).
    - `func process_tick(config: Dictionary) -> void`
      - 3a. Heat Sink (Phase 1 stub): for each agent, binary overheating check
        - heat_generated from activity level (stub: 0 if docked, small constant if in space)
        - max_dissipation from thermal_background_k of current sector
        - Update current_heat_level. Flag if over threshold.
      - 3b. Entropy System (Phase 1 stub): for each agent's active ship:
        - Apply minimal hull degradation from sector's local_entropy_rate
        - Fleet ships: apply reduced rate
        - Phase 1: degradation is very small, combat is primary damage source
      - 3c. Knowledge Refresh:
        - Each agent: refresh known_grid_state for current_sector_id with actual grid data
        - Other sectors: apply small noise factor (Phase 1 stub for knowledge decay)

  - [x] TASK_7: Create Chronicle Layer Processor
    - Location: `src/core/simulation/chronicle_layer.gd` (new file)
    - Extends: Reference
    - Purpose: Event capture and rumor generation (GDD Section 7, steps 5a–5e).
    - `func process_tick() -> void`
      - 5a. Collect: move any pending events from a staging area to chronicle_event_buffer
      - 5b. Tag Causality: Phase 1 stub — events are independent
      - 5c. Significance Scores: Phase 1 stub — all events get score 0.5
      - 5d. Rumor Engine: generate simple templated text strings from event packets
        - Template: "[Actor] [action] at [location]." e.g., "Vera sold Ore at Station Alpha."
      - 5e. Distribute: add relevant events to nearby agents' event_memory arrays
    - `func log_event(event_packet: Dictionary) -> void`
      - Called by other systems when something notable happens
      - Adds to staging buffer for next tick's processing
    - Event Packet schema (per GDD Section 5.1):
      - {actor_uid, action_id, target_uid, target_sector_id, tick_count, outcome, metadata}

  - [x] TASK_8: Create Simulation Engine — Tick Orchestrator
    - Location: `src/core/simulation/simulation_engine.gd` (new file)
    - Extends: Node (added to scene tree under WorldManager)
    - Purpose: Orchestrate the full tick sequence (GDD Section 7).
    - Holds references to all layer processors (instantiated as Reference objects, not Nodes)
    - `func _ready() -> void`
      - Instantiate: world_layer, grid_layer, agent_layer, bridge_systems, chronicle_layer, ca_rules
      - Register self in GlobalRefs
    - `func initialize_simulation(seed: String) -> void`
      - Call world_layer.initialize_world(seed)
      - Call grid_layer.initialize_grid()
      - Call agent_layer.initialize_agents()
      - Store initial matter checksum
    - `func process_tick() -> void`
      - Increment GameState.sim_tick_count
      - Step 1: World Layer — no processing (static)
      - Step 2: grid_layer.process_tick(config)
      - Step 3: bridge_systems.process_tick(config)
      - Step 4: agent_layer.process_tick(config)
      - Step 5: chronicle_layer.process_tick()
      - ASSERT: verify_matter_conservation() — total matter == world_total_matter
    - `func verify_matter_conservation() -> bool`
      - Sum: all world_resource_potential + all grid_stockpiles + all agent inventories + all wreck inventories
      - Compare to GameState.world_total_matter
      - If mismatch: push_error with detailed breakdown
    - Connect to EventBus.world_event_tick_triggered (from TimeSystem)

  - [x] TASK_9: Rewire TimeSystem to Drive SimulationEngine
    - Location: `src/core/systems/time_system.gd`
    - Simplify to ONLY:
      - Track real-time accumulation
      - When TIME_TICK_INTERVAL_SECONDS elapses: emit `world_event_tick_triggered`
      - SimulationEngine listens to this signal and runs `process_tick()`
    - Remove any upkeep cost logic (moved to bridge_systems entropy)
    - Remove any direct system calls — TimeSystem is just a clock

  - [x] TASK_10: Add Simulation Constants
    - Location: `src/autoload/Constants.gd`
    - Add new section `# === SIMULATION ENGINE ===`:
    ```
    # --- Tick Timing ---
    # TIME_TICK_INTERVAL_SECONDS already exists, keep it

    # --- Grid CA Parameters (Phase 1 stubs) ---
    const CA_INFLUENCE_PROPAGATION_RATE: float = 0.1
    const CA_PIRATE_ACTIVITY_DECAY: float = 0.02
    const CA_PIRATE_ACTIVITY_GROWTH: float = 0.05
    const CA_STOCKPILE_DIFFUSION_RATE: float = 0.05
    const CA_EXTRACTION_RATE_DEFAULT: float = 0.01
    const CA_PRICE_SENSITIVITY: float = 0.5
    const CA_DEMAND_BASE: float = 0.1

    # --- Wreck & Entropy ---
    const WRECK_DEGRADATION_PER_TICK: float = 0.05
    const WRECK_DEBRIS_RETURN_FRACTION: float = 0.8
    const ENTROPY_BASE_RATE: float = 0.001
    const ENTROPY_RADIATION_MULTIPLIER: float = 2.0
    const ENTROPY_FLEET_RATE_FRACTION: float = 0.5

    # --- Agent ---
    const AGENT_KNOWLEDGE_NOISE_FACTOR: float = 0.1
    const AGENT_RESPAWN_TICKS: int = 10
    const HOSTILE_BASE_CARRYING_CAPACITY: int = 5

    # --- Heat (Phase 1 stub) ---
    const HEAT_GENERATION_IN_SPACE: float = 0.01
    const HEAT_DISSIPATION_DOCKED: float = 1.0
    const HEAT_OVERHEAT_THRESHOLD: float = 0.8
    ```

  - [x] TASK_11: Extend LocationTemplate for World Layer Data
    - Location: `database/definitions/location_template.gd`
    - Add exports (these are the World Layer's physical foundation data):
    ```
    export var connections: PoolStringArray = PoolStringArray()
    export var sector_type: String = "frontier"  # hub/frontier/deep_space/hazard_zone
    export var radiation_level: float = 0.0
    export var thermal_background_k: float = 300.0
    export var gravity_well_penalty: float = 1.0
    export var mineral_density: float = 0.5
    export var propellant_sources: float = 0.5
    export var station_power_output: float = 100.0
    export var stockpile_capacity: int = 1000
    ```
    - Update existing location .tres files (station_alpha, station_beta, station_gamma) with:
      - Connections to each other (defining the sector graph)
      - Sensible hazard values (low radiation, moderate thermal, low gravity penalty)
      - Resource potential values (varied per location — mining stations have high mineral_density)
      - Station infrastructure values
    - Create 3-6 additional location .tres files to reach the GDD's 6-9 sector target:
      - 2-3 per faction, each with distinct resource profiles

  - [x] TASK_12: Create Sim Debug Panel
    - Location: `src/core/ui/sim_debug_panel/sim_debug_panel.gd` + `.tscn` (new)
    - Purpose: Text-only readout of ALL simulation state. The Python demo's `display()` method, but in Godot.
    - Scene structure: Control → Panel → VBoxContainer → [HeaderLabel, RichTextLabel (scrollable, monospace)]
    - Reads directly from GameState each frame (or on tick signal)
    - Display sections (all text, BBCode for color):
      - `[TICK {n}] Seed: {seed}`
      - `--- WORLD LAYER ---`
        - Per sector: id, type, connections, radiation, thermal, gravity, mineral_density, propellant_sources
      - `--- GRID LAYER ---`
        - Per sector: stockpiles, prices, faction_influence, security, piracy, power_load, entropy_rate
        - Wrecks: count and integrity levels
      - `--- AGENT LAYER ---`
        - Per agent: name, sector, hull, cash, goal, is_disabled
        - Hostile population integral: counts per type
      - `--- CHRONICLE ---`
        - Last 10 events (one-line summaries)
        - Last 5 rumors
      - `--- AXIOM 1 CHECK ---`
        - Total matter expected: X
        - Total matter actual: Y
        - Status: PASS / FAIL
    - Toggle with a single key (F3 or similar) — debug only, not gameplay UI
    - Wire into MainHUD or as a separate CanvasLayer

  - [x] TASK_13: Prune Dead Systems and Signals
    - Location: Multiple files
    - EventBus: Remove signals that no longer have consumers/emitters after pruning:
      - `contract_accepted`, `contract_completed`, `contract_abandoned`, `contract_failed` (contract system removed)
      - `narrative_action_requested`, `narrative_action_resolved` (narrative system removed)
      - `ship_quirk_added`, `ship_quirk_removed` (quirk system removed)
      - `trade_transaction_completed` (trading system removed — will be rebuilt on grid)
    - EventBus: ADD new simulation signals:
      - `signal sim_tick_completed(tick_count)` — emitted after full tick sequence
      - `signal sim_initialized(seed)` — emitted after simulation is seeded
    - GlobalRefs: Remove setters/vars for deleted systems:
      - `action_system`, `trading_system`, `contract_system`, `narrative_action_system`, `combat_system`, `quirk_system`, `progression_system`, `traffic_system`, `world_map_system`, `goal_system`
    - GlobalRefs: ADD:
      - `var simulation_engine` + setter
    - Update `main_game_scene.tscn`: remove deleted system nodes, add SimulationEngine node
    - DO NOT remove signals/refs used by kept systems (event_system, agent_system, time_system, character_system, inventory_system, asset_system)

  - [x] TASK_14: Create Unit Tests for Simulation Engine
    - Location: `src/tests/core/simulation/`
    - `test_ca_rules.gd`:
      - test_strategic_map_influence_propagation — influence flows to neighbors
      - test_supply_demand_extraction — extraction depletes resource potential, fills stockpiles
      - test_supply_demand_diffusion — surplus flows to deficit neighbor
      - test_market_pressure_pricing — high supply = negative delta, low supply = positive delta
      - test_entropy_wreck_degradation — wreck integrity decreases
      - test_entropy_matter_return — degraded wreck returns matter to resource potential
      - test_all_ca_rules_are_pure — verify no GameState mutation (call with mock data)
    - `test_world_layer.gd`:
      - test_world_initialization — all sectors have topology, hazards, resources
      - test_total_matter_calculated — world_total_matter > 0 and equals sum
      - test_deterministic_init — same seed produces same world
    - `test_grid_layer.gd`:
      - test_grid_initialization — all sectors have initial grid state
      - test_extraction_depletes_potential — after tick, mineral_density decreased
      - test_stockpile_increases_from_extraction — after tick, commodity_stockpiles increased
      - test_price_reacts_to_supply — after changing stockpile, price_delta changes
    - `test_agent_layer.gd`:
      - test_agents_initialized — all 6 persistent + player exist with correct sectors
      - test_npc_goal_evaluation — NPC with low cash gets trade goal
      - test_npc_action_execution — NPC trade action modifies stockpiles
      - test_persistent_agent_respawn — disabled agent respawns after N ticks
      - test_knowledge_snapshot_updated — agent at sector has fresh knowledge
    - `test_chronicle_layer.gd`:
      - test_event_logged — log_event adds to buffer
      - test_rumor_generated — after tick, rumor text exists
      - test_event_distributed — nearby agent gets event in memory
    - `test_simulation_tick.gd`:
      - test_full_tick_sequence — run one tick, all layers processed in order
      - test_matter_conservation_axiom — after 10 ticks, total matter unchanged
      - test_deterministic_simulation — same seed + same ticks = same state
      - test_tick_count_increments — sim_tick_count increases

  - [x] TASK_15: Cleanup and Verify
    - Delete all files listed in the DELETE section above
    - Ensure project loads without errors (no missing references)
    - Update `project.godot` autoload list if any autoloads were removed
    - Run surviving tests — those for kept systems (character_system, inventory_system, asset_system, time_system) should still pass
    - Run all new simulation tests
    - Verify sim debug panel displays correct state
    - Verify flight mechanics still work (fly around, dock, undock)
    - Verify agents still spawn and move in local space

  - [ ] VERIFICATION:
    - All new simulation tests pass (target: 30+ new tests)
    - Surviving old tests pass (character, inventory, asset, time — target: ~100)
    - `godot -s addons/gut/gut_cmdln.gd -gdir=res://src/tests` — 0 failures
    - Sim debug panel shows all 4 layers updating each tick
    - Axiom 1 assertion passes for 100 consecutive ticks
    - Matter conservation: sum(world_resource_potential) + sum(grid_stockpiles) + sum(agent_inventories) + sum(wreck_inventories) == constant
    - Flight and camera controls work as before
    - Agents spawn in zones as before
    - No orphaned signals, no missing GlobalRefs, no broken scene references
    - Project compiles and runs clean
