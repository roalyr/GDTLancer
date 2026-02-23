## CURRENT GOAL: Port Qualitative Tag Simulation from Python to Godot GDScript

### EXECUTIVE SUMMARY

The Python qualitative tag simulation is fully validated (filament topology,
economy diversity, friction pacing, session dynamics — all milestones complete).
The Godot GDScript simulation code is **100% stale numeric** — every file
(`ca_rules.gd`, `grid_layer.gd`, `agent_layer.gd`, `bridge_systems.gd`,
`chronicle_layer.gd`, `world_layer.gd`, `simulation_engine.gd`) operates on
float-valued stockpiles, price deltas, matter conservation, and numeric utility
scoring. None of this matches the validated qualitative model.

**This is the critical foundation blocker.** The next planned features — Radar
Model (screen-space dots with disposition-color from tags), Global Starsphere,
ContactManager (reading `GameState.agents` for sector/tags), scene transitions
with `advance_sub_ticks()`, and per-session world evolution — ALL require the
qualitative tag simulation running natively in Godot. Without this port, no 3D
integration can use tag-based disposition, economy, security, or colony state.

**Scope:** 1:1 port of `python_sandbox/` qualitative architecture into
`src/core/simulation/` + `src/autoload/` GDScript, adapted for Godot 3.6
patterns (extends Reference, Signal wiring, TemplateDatabase loading). The
Python sandbox files are the **canonical reference** — match behavior exactly.

### PREVIOUS MILESTONE STATUS: Filament Topology — Complete ✅

All 5 TASK items + 6 VERIFICATIONs. Max degree ≤ 4, avg degree ≤ 2.5,
bottleneck chains, filament web structure. 20/20 tests passing.

### PREVIOUS MILESTONE STATUS: Economy Diversity & Population Equilibrium — Complete ✅
### PREVIOUS MILESTONE STATUS: Friction & Pacing — Complete ✅
### PREVIOUS MILESTONE STATUS: Session Dynamics Tuning — Complete ✅
### PREVIOUS MILESTONE STATUS: Qualitative Simulation Rewrite — Complete ✅

---

- TARGET_FILES:

  **PHASE 1 — FOUNDATION (Constants + State + Tag Vocabulary):**
  - `src/core/simulation/ca_rules.gd` — DELETE (superseded by tag-transition methods in GridLayer)
  - `src/core/simulation/affinity_matrix.gd` — CREATE (tag vocabulary + affinity scoring + tag derivation)
  - `src/autoload/Constants.gd` — UPDATE (add qualitative simulation constants section; keep existing physics/PID/UI constants)
  - `src/autoload/GameState.gd` — REWRITE (replace numeric sim layers with qualitative tag containers; keep scene state + legacy compat)

  **PHASE 2 — TEMPLATE INFRASTRUCTURE:**
  - `database/definitions/location_template.gd` — UPDATE (add `initial_sector_tags` export)
  - `database/definitions/agent_template.gd` — UPDATE (add `agent_role`, `initial_tags` exports)
  - `database/registry/locations/*.tres` — UPDATE existing + CREATE missing (delta, epsilon) to match `template_data.py`
  - `database/registry/characters/*.tres` — CREATE missing (siv, zara, nyx, orin, crow, vex, nova)
  - `database/registry/agents/*.tres` — CREATE missing persistent agents to match `template_data.py` (13 NPCs total)

  **PHASE 3 — SIMULATION LAYERS:**
  - `src/core/simulation/world_layer.gd` — REWRITE (tag-based init from TemplateDatabase)
  - `src/core/simulation/grid_layer.gd` — REWRITE (tag-transition CA engine: economy/security/environment/hostile/colony)
  - `src/core/simulation/bridge_systems.gd` — REWRITE (tag refresh: agent, sector, world)
  - `src/core/simulation/agent_layer.gd` — REWRITE (affinity-driven tag transitions, exploration, mortal lifecycle)
  - `src/core/simulation/chronicle_layer.gd` — REWRITE (simplified event/rumor system)

  **PHASE 4 — ORCHESTRATION & INTEGRATION:**
  - `src/core/simulation/simulation_engine.gd` — REWRITE (world-age cycle, sub-tick accumulator, qualitative orchestration)
  - `src/scenes/ui/hud/sim_debug_panel.gd` — UPDATE (read qualitative tags instead of numeric fields)

  **PHASE 5 — VALIDATION:**
  - `src/tests/core/simulation/*.gd` — REWRITE all 6 test files for qualitative system

- TRUTH_RELIANCE:
  - `TRUTH_PROJECT.md` — Godot 3.6 stable, GLES2, Python 3 sandbox
  - `TRUTH_CONSTRAINTS.md` — No @export, @onready, await (Godot 3 syntax)
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §2 (Entity Graph Nodes) — Sector/Station/Agent/Hostile/Wreck node types
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §3 (Flow Graph Edges) — Production/Consumption/Lifecycle/Maintenance/Prospecting cycles
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §5 (Information Graph) — Heatmap signals, gossip, Gold Rush emergence
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §6 (Architectural Implementation Map) — Layer assignments for MarketSystem, HostileManager, LifecycleSystem
  - `TRUTH_CONTENT-CREATION-MANUAL.md` §2 (Directory Structure) — Template/Registry/Scene organization
  - Python sandbox source code (`python_sandbox/`) — canonical reference implementation for all tag logic

- TECHNICAL_CONSTRAINTS:
  - Godot 3.6 stable, GDScript 3.x syntax (NO @export, @onready, await)
  - Use `export var` for template properties, `extends Reference` for non-scene layer processors
  - All simulation layers must be pure `Reference` objects (no scene tree dependency), instantiated by `SimulationEngine` node
  - `SimulationEngine` is the only simulation `Node` — lives in scene tree, connects `EventBus.world_event_tick_triggered`, registers in `GlobalRefs`
  - `GameState` autoload is the single data store — all layers read/write through it
  - `TemplateDatabase` autoload scans `database/registry/` — templates must be valid `.tres` Resources
  - All RNG must be seeded deterministically from `world_seed` — same seed = same simulation
  - Qualitative tag system — NO float-valued simulation fields (stockpiles, prices, matter sums); tags are Strings in Arrays
  - Keep existing non-simulation systems functional: TimeSystem, InventorySystem, WorldGenerator, GameStateManager, EventBus signals, HUD, docking, flight
  - Keep `GameState` scene-state fields (`current_zone_instance`, `player_docked_at`, `player_position`, `player_rotation`, `game_time_seconds`) intact
  - GLES2 compatible (no visual changes in this milestone)
  - Python sandbox remains untouched — it is read-only reference

- DESIGN_DECISIONS:

  - **1:1 behavioral port, Godot patterns.** Every Python class → GDScript `extends Reference` (except `SimulationEngine` → `extends Node`). Every Python `state.field` → `GameState.field`. Every Python constant → `Constants.CONSTANT_NAME`. Method signatures match Python exactly, adapted to GDScript types (`Array` for `list`, `Dictionary` for `dict`, `String` for `str`).

  - **AffinityMatrix as Reference, not autoload.** `affinity_matrix.gd` is a `Reference` class loaded by `SimulationEngine` and injected into layers that need it. Tag vocabulary constants are class-level `const` declarations.

  - **Template data via TemplateDatabase, not hardcoded dicts.** Python uses `template_data.py` flat dicts. Godot uses `.tres` files scanned by `TemplateDatabase`. Location/Character/Agent templates get new qualitative `export` fields. The `WorldLayer.initialize_world()` reads from `TemplateDatabase.locations` (same as current but uses new tag fields). `AgentLayer.initialize_agents()` reads from `TemplateDatabase.agents` + `TemplateDatabase.characters`.

  - **Sub-tick system exposed to scene-level code.** `SimulationEngine.advance_sub_ticks(cost: int) -> int` is callable from `WorldManager` (scene transitions), station menu (docking costs), and future ContactManager. Returns number of full ticks fired, so caller can refresh state.

  - **Preserve EventBus contract.** Keep `sim_initialized` and `sim_tick_completed` signals. Add `world_age_changed(new_age: String)` signal for UI to react to world-age shifts. Keep `world_event_tick_triggered` as the external clock input.

  - **GameState backward compat.** Keep `locations`, `factions`, `assets_commodities` as legacy dicts (still read by WorldGenerator, InventorySystem). Add new qualitative fields alongside. Remove only fields that are exclusively consumed by the now-dead numeric sim layers: `world_resource_potential`, `grid_resource_availability`, `grid_market`, `grid_stockpiles`, `grid_maintenance`, `grid_power`, `grid_wrecks`, `hostile_population_integral`, `world_total_matter`.

  - **Missing template .tres files.** Python has 5 locations (alpha–epsilon), 14 characters, 14 agents. Godot currently has 3 locations, 7 characters, 9 agents. Missing templates must be created to match `template_data.py` exactly. This ensures the Godot sim initializes the same world as the Python sandbox.

---

- ATOMIC_TASKS:

  ### PHASE 1: Foundation

  - [x] TASK_1: Delete `ca_rules.gd` — remove superseded numeric CA
    - File: `src/core/simulation/ca_rules.gd` — DELETE entirely
    - Rationale: All 7 numeric CA functions (`strategic_map_step`, `supply_demand_step`, `market_pressure_step`, `entropy_step`, `influence_network_step`, `power_load_step`, `maintenance_pressure_step`) are replaced by tag-transition `_step_*()` methods inside `GridLayer`. No other file should reference `ca_rules` after this milestone.
    - Also remove: any `ca_rules` references in `simulation_engine.gd` (will be fully rewritten in TASK_12), `grid_layer.gd` (rewritten in TASK_8).

  - [x] TASK_2: Create `affinity_matrix.gd` — tag vocabulary + affinity scoring
    - File: `src/core/simulation/affinity_matrix.gd` — CREATE
    - Reference: `python_sandbox/core/simulation/affinity_matrix.py` (223 lines)
    - Class: `extends Reference`, `class_name AffinityMatrix`
    - **Tag vocabulary constants (class-level `const`):**
      - `SECTOR_ECONOMY_TAGS: Dictionary` — 3 keys: `"RAW_MATERIALS"`, `"MANUFACTURED"`, `"CURRENCY"` → each maps to Array of 3 level tags (`*_RICH`, `*_ADEQUATE`, `*_POOR`)
      - `SECTOR_SECURITY_TAGS: Array` — `["SECURE", "CONTESTED", "LAWLESS"]`
      - `SECTOR_ENVIRONMENT_TAGS: Array` — `["MILD", "HARSH", "EXTREME"]`
      - `SECTOR_SPECIAL_TAGS: Array` — `["STATION", "FRONTIER", "HAS_SALVAGE", "DISABLED", "HOSTILE_INFESTED", "HOSTILE_THREATENED"]`
      - `AGENT_CONDITION_TAGS: Array` — `["HEALTHY", "DAMAGED", "DESTROYED"]`
      - `AGENT_WEALTH_TAGS: Array` — `["WEALTHY", "COMFORTABLE", "BROKE"]`
      - `AGENT_CARGO_TAGS: Array` — `["LOADED", "EMPTY"]`
      - `ROLE_TAGS: Dictionary` — `{"trader": "TRADER", "prospector": "PROSPECTOR", "military": "MILITARY", "hauler": "HAULER", "pirate": "PIRATE", "explorer": "EXPLORER", "idle": "IDLE"}`
      - `PERSONALITY_TAG_RULES: Array` — 5 rules: `[trait, operator, threshold, tag]` per Python
      - `DYNAMIC_AGENT_TAGS: Array` — `["DESPERATE", "SCAVENGER"]`
      - `AFFINITY_MATRIX: Dictionary` — 52 entries `[actor_tag, target_tag] → float score`, matching Python exactly
    - **Public methods:**
      - `func compute_affinity(actor_tags: Array, target_tags: Array) -> float` — sum all matching `(actor_tag, target_tag)` pair scores
      - `func derive_agent_tags(character_data: Dictionary, agent_state: Dictionary, has_cargo: bool = false) -> Array` — builds full tag list from role, personality traits, condition/wealth/cargo, dynamic tags (DESPERATE/SCAVENGER derivation)
      - `func derive_sector_tags(sector_id: String, state) -> Array` — rebuilds sector tags from topology, disabled state, security, environment, economy, hostile consistency. `state` is the GameState autoload reference.
    - **Private helpers:** `_pick_security_tag()`, `_pick_environment_tag()`, `_pick_economy_tags()`, `_unique()`
    - Signature: Pure read-only functions. No GameState mutation. No side effects.

  - [x] TASK_3: Update `Constants.gd` — add qualitative simulation constants
    - File: `src/autoload/Constants.gd` — UPDATE (append, do not remove existing physics/PID/UI constants)
    - Reference: `python_sandbox/autoload/constants.py` (188 lines)
    - Add new section `# ---- QUALITATIVE SIMULATION ----` containing ALL constants from Python `constants.py`:
      - World Age: `WORLD_AGE_CYCLE`, `WORLD_AGE_DURATIONS`, `WORLD_AGE_CONFIGS`
      - Colony: `COLONY_LEVELS`, `COLONY_UPGRADE_TICKS_REQUIRED`, `COLONY_DOWNGRADE_TICKS_REQUIRED`, `COLONY_UPGRADE_REQUIRED_SECURITY`, `COLONY_UPGRADE_REQUIRED_ECONOMY`, `COLONY_DOWNGRADE_SECURITY_TRIGGER`, `COLONY_DOWNGRADE_ECONOMY_TRIGGER`, `COLONY_MINIMUM_LEVEL`
      - Security: `SECURITY_CHANGE_TICKS_MIN`, `SECURITY_CHANGE_TICKS_MAX`
      - Economy: `ECONOMY_UPGRADE_TICKS_REQUIRED`, `ECONOMY_DOWNGRADE_TICKS_REQUIRED`, `ECONOMY_CHANGE_TICKS_MIN`, `ECONOMY_CHANGE_TICKS_MAX`
      - Hostile: `HOSTILE_INFESTATION_TICKS_REQUIRED`
      - Affinity: `ATTACK_THRESHOLD`, `TRADE_THRESHOLD`, `FLEE_THRESHOLD`, `COMBAT_COOLDOWN_TICKS`
      - Agent lifecycle: `AGENT_UPKEEP_CHANCE`, `WEALTHY_DRAIN_CHANCE`, `BROKE_RECOVERY_CHANCE`, `RESPAWN_COOLDOWN_TICKS`, `RESPAWN_COOLDOWN_MAX_DEBT`
      - Mortal: `MORTAL_GLOBAL_CAP`, `MORTAL_SPAWN_REQUIRED_SECURITY`, `MORTAL_SPAWN_BLOCKED_SECTOR_TAGS`, `MORTAL_SPAWN_MIN_ECONOMY_TAGS`, `MORTAL_SPAWN_CHANCE`, `MORTAL_ROLES`, `MORTAL_SURVIVAL_CHANCE`, `DISRUPTION_MORTAL_ATTRITION_CHANCE`
      - Chronicle: `EVENT_BUFFER_CAP`, `RUMOR_BUFFER_CAP`
      - Exploration: `MAX_SECTOR_COUNT`, `EXPLORATION_COOLDOWN_TICKS`, `EXPLORATION_SUCCESS_CHANCE`
      - Topology: `MAX_CONNECTIONS_PER_SECTOR`, `EXTRA_CONNECTION_1_CHANCE`, `EXTRA_CONNECTION_2_CHANCE`, `LOOP_MIN_HOPS`
      - Catastrophe: `CATASTROPHE_CHANCE_PER_TICK`, `CATASTROPHE_DISABLE_DURATION`, `CATASTROPHE_MORTAL_KILL_CHANCE`
      - Sub-tick: `SUB_TICKS_PER_TICK`, `SUBTICK_COST_SECTOR_TRAVEL`, `SUBTICK_COST_DOCK`, `SUBTICK_COST_UNDOCK`, `SUBTICK_COST_DEEP_SPACE_EVENT`
    - Remove the OLD numeric simulation constants section (`CA_*`, `ENTROPY_*`, `HEAT_*`, `POWER_*`, `NPC_CASH_LOW_THRESHOLD`, `COMMODITY_BASE_PRICE`, `AXIOM1_TOLERANCE`, etc.)
    - Values must match Python `constants.py` exactly.

  - [x] TASK_4: Rewrite `GameState.gd` — qualitative tag containers
    - File: `src/autoload/GameState.gd` — REWRITE
    - Reference: `python_sandbox/autoload/game_state.py` (80 lines)
    - **Remove** (dead numeric sim fields): `world_resource_potential`, `world_total_matter`, `grid_resource_availability`, `grid_dominion` (will be re-added as qualitative), `grid_market`, `grid_stockpiles`, `grid_maintenance`, `grid_power`, `grid_wrecks`, `hostile_population_integral`
    - **Add** qualitative fields matching Python `game_state.py`:
      - Layer 1 — World: `var world_topology := {}`, `var world_hazards := {}`, `var world_tags := []`, `var world_seed := ""`
      - Layer 2 — Grid: `var grid_dominion := {}`, `var sector_tags := {}`
      - Layer 3 — Agents: `var characters := {}`, `var agents := {}`, `var agent_tags := {}`, `var player_character_uid := ""`
      - Colony: `var colony_levels := {}`, `var colony_upgrade_progress := {}`, `var colony_downgrade_progress := {}`, `var colony_level_history := []`
      - Security: `var security_upgrade_progress := {}`, `var security_downgrade_progress := {}`, `var security_change_threshold := {}`
      - Economy: `var economy_upgrade_progress := {}`, `var economy_downgrade_progress := {}`, `var economy_change_threshold := {}`
      - Hostile: `var hostile_infestation_progress := {}`
      - Catastrophe: `var catastrophe_log := []`, `var sector_disabled_until := {}`
      - Mortal: `var mortal_agent_counter := 0`, `var mortal_agent_deaths := []`
      - Discovery: `var discovered_sector_count := 0`, `var discovery_log := []`, `var sector_names := {}`
      - Chronicle: `var chronicle_events := []`, `var chronicle_rumors := []`
      - Sim meta: `var sim_tick_count := 0`, `var sub_tick_accumulator := 0`, `var world_age := ""`, `var world_age_timer := 0`, `var world_age_cycle_count := 0`
    - **Keep** (scene + legacy): `current_zone_instance`, `player_docked_at`, `player_position`, `player_rotation`, `game_time_seconds`, `locations`, `factions`, `assets_commodities`, `persistent_agents` (legacy alias for `agents`)
    - Keep `reset_state()` method — clear all qualitative fields to defaults.
    - Signature: Pure data store. No logic. All fields default-initialized.

  ### PHASE 2: Template Infrastructure

  - [x] TASK_5: Update template definitions and create missing .tres files
    - **Definition updates:**
      - `database/definitions/location_template.gd`: Add `export var initial_sector_tags: PoolStringArray = PoolStringArray()`. Keep all existing exports (backward compat for scene-level systems).
      - `database/definitions/agent_template.gd`: Add `export var agent_role: String = "idle"` and `export var initial_tags: PoolStringArray = PoolStringArray()`.
    - **Update existing location .tres** (3 files):
      - `station_alpha.tres`: Set `initial_sector_tags = ["STATION", "SECURE", "MILD", "RAW_RICH", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]`, `connections = ["station_beta", "station_delta"]`, `sector_type = "colony"`, `controlling_faction_id = "faction_miners"`
      - `station_beta.tres`: Set `initial_sector_tags = ["STATION", "SECURE", "MILD", "RAW_POOR", "MANUFACTURED_RICH", "CURRENCY_RICH"]`, `connections = ["station_alpha", "station_delta"]`, `sector_type = "colony"`, `controlling_faction_id = "faction_traders"`
      - `station_gamma.tres`: Set `initial_sector_tags = ["FRONTIER", "LAWLESS", "HARSH", "RAW_ADEQUATE", "MANUFACTURED_POOR", "CURRENCY_ADEQUATE", "HOSTILE_THREATENED"]`, `connections = ["station_delta", "station_epsilon"]`, `sector_type = "frontier"`, `controlling_faction_id = "faction_independents"`
    - **Create 2 new location .tres** (reference: `template_data.py LOCATIONS`):
      - `station_delta.tres`: `location_name = "Outpost Delta - Military Garrison"`, `sector_type = "colony"`, `connections = ["station_beta", "station_gamma", "station_alpha"]`, `initial_sector_tags = ["STATION", "SECURE", "MILD", "RAW_ADEQUATE", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE"]`, `controlling_faction_id = "faction_military"`, `available_services = ["trade", "refuel", "repair", "contracts"]`
      - `station_epsilon.tres`: `location_name = "Epsilon Refinery Complex"`, `sector_type = "outpost"`, `connections = ["station_gamma"]`, `initial_sector_tags = ["STATION", "CONTESTED", "HARSH", "RAW_RICH", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]`, `controlling_faction_id = "faction_miners"`, `available_services = ["trade", "refuel", "repair"]`
    - **Create 7 new character .tres** matching `template_data.py CHARACTERS`:
      - `character_siv.tres`, `character_zara.tres`, `character_nyx.tres`, `character_orin.tres`, `character_crow.tres`, `character_vex.tres`, `character_nova.tres`
      - Each has: `character_name`, `faction_id`, `personality_traits` dict (risk_tolerance, greed, aggression, loyalty), `description`, `initial_condition_tag = "HEALTHY"`, `initial_wealth_tag = "COMFORTABLE"` (or as specified in template_data.py)
      - NOTE: `initial_condition_tag` and `initial_wealth_tag` are NEW exports to add to `character_template.gd`: `export var initial_condition_tag: String = "HEALTHY"` and `export var initial_wealth_tag: String = "COMFORTABLE"`
    - **Create missing persistent agent .tres** to reach 13 NPCs total, matching `template_data.py AGENTS`:
      - Missing: `persistent_siv.tres`, `persistent_zara.tres`, `persistent_nyx.tres`, `persistent_orin.tres`, `persistent_crow.tres`, `persistent_vex.tres`, `persistent_nova.tres`
      - Each has: `agent_type = "npc"`, `is_persistent = true`, `home_location_id` (per template_data.py), `character_template_id`, `agent_role` (per template_data.py), `initial_tags` = `["HEALTHY", "COMFORTABLE", "EMPTY"]` (or as specified)
    - **Update existing agent .tres** (6 persistent + player): Set `agent_role` and `initial_tags` fields.
    - Signature: All .tres files loadable by `TemplateDatabase`. All new exports are Godot 3 `export var` syntax.

  ### PHASE 3: Simulation Layers

  - [x] TASK_6: Rewrite `world_layer.gd` — tag-based initialization
    - File: `src/core/simulation/world_layer.gd` — REWRITE
    - Reference: `python_sandbox/core/simulation/world_layer.py` (47 lines)
    - Class: `extends Reference`
    - **Public methods:**
      - `func initialize_world(state, seed_string: String) -> void` — sets `state.world_seed`, clears `world_topology/world_hazards/sector_tags`, iterates `TemplateDatabase.locations`, builds `world_topology[sector_id] = {"connections": Array, "station_ids": Array, "sector_type": String}`, `world_hazards[sector_id] = {"environment": String}`, `state.sector_tags[sector_id] = initial_sector_tags Array`
      - `func get_neighbors(state, sector_id: String) -> Array` — returns connections
      - `func get_hazards(state, sector_id: String) -> Dictionary` — returns hazard dict
    - **Remove:** `_build_resource_potential()`, `_calculate_total_matter()`, `recalculate_total_matter()`, `get_resource_potential()` — all numeric matter budget code
    - **Private:** `_derive_environment(sector_tags: Array) -> String` — extracts EXTREME/HARSH/MILD from initial tags
    - Signature: Read from `TemplateDatabase.locations`, write to `GameState`. No numeric resource fields.

  - [x] TASK_7: Rewrite `grid_layer.gd` — tag-transition CA engine
    - File: `src/core/simulation/grid_layer.gd` — REWRITE
    - Reference: `python_sandbox/core/simulation/grid_layer.py` (297 lines)
    - Class: `extends Reference`
    - **Class-level constants:**
      - `const ECONOMY_LEVELS := ["POOR", "ADEQUATE", "RICH"]`
      - `const SECURITY_LEVELS := ["LAWLESS", "CONTESTED", "SECURE"]`
      - `const ENV_LEVELS := ["EXTREME", "HARSH", "MILD"]`
      - `const CATEGORIES := ["RAW", "MANUFACTURED", "CURRENCY"]`
    - **Public methods:**
      - `func initialize_grid(state) -> void` — for each sector: init `sector_tags` from `state.sector_tags`, init `colony_levels`, `grid_dominion`, security/economy progress counters, per-sector randomized thresholds (seeded from `state.world_seed + sector_id`)
      - `func process_tick(state, config: Dictionary) -> void` — for each sector: `_step_economy()` → `_step_security()` → `_step_environment()` → `_step_hostile_presence()` → `_step_colony_level()`. Writes back to `state.sector_tags` and `state.grid_dominion`.
    - **Private step methods** (match Python exactly):
      - `_step_economy(tags, neighbor_tags, state, sector_id) -> Array` — per-category (RAW/MANUFACTURED/CURRENCY) delta: homeostatic pressure, world-age influence, colony drain, population density, active commerce, pirate pressure. Progress-counter gated.
      - `_step_security(tags, neighbor_tags, state, sector_id) -> Array` — delta from homeostatic, world-age, military/pirate/hostile presence, neighbor average. Progress-counter gated.
      - `_step_environment(tags, state, sector_id) -> Array` — DISRUPTION degrades, RECOVERY heals. Catastrophe → EXTREME.
      - `_step_hostile_presence(tags, state, sector_id) -> Array` — LAWLESS + no military → infestation counter builds. Military clears.
      - `_step_colony_level(tags, state, sector_id) -> Array` — progress-counter gated, economy+security requirements, floor at COLONY_MINIMUM_LEVEL.
    - **Private helpers:** `_loaded_trade_count_for_sector()`, `_role_counts_for_sector()`, `_active_agent_count_in_sector()`, `_economy_level()`, `_security_tag()`, `_environment_tag()`, `_replace_prefix()`, `_replace_one_of()`, `_sector_recently_disabled()`, `_unique()`
    - Signature: No numeric stockpiles, no float CA rules, no matter conservation. Pure tag-level transitions.

  - [x] TASK_8: Rewrite `bridge_systems.gd` — tag refresh
    - File: `src/core/simulation/bridge_systems.gd` — REWRITE
    - Reference: `python_sandbox/core/simulation/bridge_systems.py` (47 lines)
    - Class: `extends Reference`
    - Requires: `AffinityMatrix` reference (injected by SimulationEngine)
    - **Public methods:**
      - `func process_tick(state, config: Dictionary) -> void` — calls `_refresh_sector_tags(state)`, `_refresh_agent_tags(state)`, `_refresh_world_tags(state)` in order
    - **Private methods:**
      - `_refresh_agent_tags(state) -> void` — for each non-disabled agent: calls `affinity_matrix.derive_agent_tags(character_data, agent_state, has_cargo)`, stores result in `state.agent_tags[agent_id]` and `agent["sentiment_tags"]`
      - `_refresh_sector_tags(state) -> void` — for each sector: calls `affinity_matrix.derive_sector_tags(sector_id, state)`
      - `_refresh_world_tags(state) -> void` — maps `state.world_age` → tag list: PROSPERITY→["ABUNDANT", "STABLE"], DISRUPTION→["SCARCE", "VOLATILE"], RECOVERY→["RECOVERING"]
    - **Injected dependency:** `var affinity_matrix` — set by SimulationEngine
    - Signature: ~50 lines. No heat, no entropy, no knowledge timestamps.

  - [x] TASK_9: Rewrite `chronicle_layer.gd` — simplified event/rumor system
    - File: `src/core/simulation/chronicle_layer.gd` — REWRITE
    - Reference: `python_sandbox/core/simulation/chronicle_layer.py` (107 lines)
    - Class: `extends Reference`
    - **Public methods:**
      - `func log_event(event_packet: Dictionary) -> void` — validates defaults (tick, actor_id, action, sector_id, metadata), appends to staging buffer
      - `func process_tick(state) -> void` — collect staged events → generate rumors → distribute to nearby agents
    - **Private methods:**
      - `_collect_events(state) -> Array` — drains staging buffer into `state.chronicle_events` (capped at EVENT_BUFFER_CAP)
      - `_generate_rumors(state, events: Array) -> Array` — calls `_format_rumor()` for each event
      - `_format_rumor(state, event: Dictionary) -> String` — `"{actor_name} {action} at {location_name}."`
      - `_distribute_events(state, events: Array) -> void` — pushes to agents' `event_memory` within 1 hop of event sector
      - `_resolve_actor_name(state, actor_id: String) -> String` — "You" for player, character_name for NPCs
      - `_resolve_location_name(sector_id: String, state) -> String` — checks TemplateDatabase then `state.sector_names`
      - `_humanize_action(action: String) -> String` — 15-entry label map matching Python (move→"moved", attack→"attacked", agent_trade→"traded", dock→"docked", harvest→"harvested salvage", etc.)
    - Signature: ~110 lines. No causality/significance stubs. No numeric narrative values.

  - [x] TASK_10: Rewrite `agent_layer.gd` — affinity-driven tag transitions
    - File: `src/core/simulation/agent_layer.gd` — REWRITE
    - Reference: `python_sandbox/core/simulation/agent_layer.py` (805 lines)
    - Class: `extends Reference`
    - Requires: `AffinityMatrix` reference, `ChronicleLayer` reference (both injected)
    - **Public methods:**
      - `func set_chronicle(chronicle) -> void`
      - `func initialize_agents(state) -> void` — clears agents/characters/agent_tags, inits player + all template agents from TemplateDatabase
      - `func process_tick(state, config: Dictionary) -> void` — seeds RNG per-tick; `_apply_upkeep()` → per-agent (skip player): respawn disabled / evaluate goals + execute action → `_check_catastrophe()` → `_spawn_mortal_agents()` → `_cleanup_dead_mortals()`
    - **Agent state Dictionary structure** (created per agent):
      ```
      {
        "character_id": String,
        "agent_role": String,           # trader/hauler/prospector/explorer/pirate/military/idle
        "current_sector_id": String,
        "home_location_id": String,
        "goal_archetype": String,       # "idle" / "affinity_scan" / "flee_to_safety"
        "goal_queue": Array,
        "is_disabled": bool,
        "disabled_at_tick": int or null,
        "is_persistent": bool,
        "condition_tag": String,        # HEALTHY / DAMAGED / DESTROYED
        "wealth_tag": String,           # WEALTHY / COMFORTABLE / BROKE
        "cargo_tag": String,            # LOADED / EMPTY
        "dynamic_tags": Array,
        "sentiment_tags": Array,
        "last_attack_tick": int,
        "last_discovery_tick": int,
        "event_memory": Array,
      }
      ```
    - **Core action methods:**
      - `_evaluate_goals(agent) -> void` — DESPERATE → flee_to_safety, else → affinity_scan
      - `_execute_action(state, agent_id, agent) -> void` — dispatches goal
      - `_action_flee_to_safety(state, agent_id, agent) -> void`
      - `_action_affinity_scan(state, agent_id, agent) -> void` — best agent target → resolve; fallback → sector interaction
      - `_resolve_agent_interaction(state, actor_id, target_id, score) -> bool` — ATTACK/TRADE/FLEE thresholds
      - `_resolve_sector_interaction(state, agent_id, score, sector_tags) -> void` — exploration/harvest/dock/move
    - **Exploration methods** (filament topology — match Python exactly):
      - `_try_exploration(state, agent_id, agent, sector_id) -> void`
      - `_generate_sector_name(state) -> String`
      - `_graph_degree(state, sector_id) -> int`
      - `_sectors_below_cap(state) -> Array`
      - `_nearby_candidates(state, source_id, exclude) -> Array`
      - `_distant_loop_candidate(state, source_id, exclude)` — BFS, return sector ≥ LOOP_MIN_HOPS
    - **Lifecycle methods:**
      - `_check_respawn(state, agent_id, agent) -> void`
      - `_check_catastrophe(state) -> void`
      - `_spawn_mortal_agents(state) -> void`
      - `_cleanup_dead_mortals(state) -> void`
      - `_apply_upkeep(state) -> void`
    - **Utility helpers:** `_try_dock()`, `_action_harvest()`, `_action_move_toward_tag()`, `_action_move_toward()`, `_action_move_random()`, `_try_load_cargo()`, `_action_move_toward_role_target()`, `_post_combat_dispersal()`, `_active_agent_count_in_sector()`, `_best_agent_target()`, `_is_combat_cooldown_active()`, `_bilateral_trade()`, `_wealth_step_up()`, `_wealth_step_down()`, `_replace_one()`, `_add_tag()`, `_log_event()`
    - Signature: Largest file (~800 lines). All agent decisions via affinity scores, all state changes via tag transitions.

  ### PHASE 4: Orchestration & Integration

  - [x] TASK_11: Rewrite `simulation_engine.gd` — world-age + sub-ticks
    - File: `src/core/simulation/simulation_engine.gd` — REWRITE
    - Reference: `python_sandbox/core/simulation/simulation_engine.py` (122 lines)
    - Class: `extends Node` (scene tree participant)
    - **_ready():** Load and instantiate all layer scripts as References (`WorldLayer`, `GridLayer`, `BridgeSystems`, `AgentLayer`, `ChronicleLayer`, `AffinityMatrix`). Inject `AffinityMatrix` into `BridgeSystems` and `AgentLayer`. Wire `ChronicleLayer` into `AgentLayer`. Connect `EventBus.world_event_tick_triggered`. Register self in `GlobalRefs.simulation_engine`.
    - **Public methods:**
      - `func initialize_simulation(seed_string: String) -> void` — calls `world_layer.initialize_world()` → `grid_layer.initialize_grid()` → `agent_layer.initialize_agents()`. Sets initial `world_age`, `world_age_timer`. Emits `EventBus.sim_initialized`.
      - `func process_tick() -> void` — increments `GameState.sim_tick_count`, calls `_advance_world_age()`, then: `grid_layer.process_tick()` → `bridge_systems.process_tick()` → `agent_layer.process_tick()` → `chronicle_layer.process_tick()`. Emits `EventBus.sim_tick_completed`.
      - `func advance_sub_ticks(cost: int) -> int` — adds `cost` to `GameState.sub_tick_accumulator`; fires `process_tick()` for each full `SUB_TICKS_PER_TICK` reached. Returns count of full ticks fired.
      - `func get_chronicle() -> Reference`
      - `func is_initialized() -> bool`
      - `func set_config(key: String, value) -> void`
      - `func get_config() -> Dictionary`
    - **Private methods:**
      - `_advance_world_age() -> void` — decrements timer, cycles through `WORLD_AGE_CYCLE`, increments `world_age_cycle_count` on wrap, logs `age_change` event, emits `EventBus.world_age_changed`
      - `_apply_age_config() -> void` — rebuilds tick_config + merges age overrides
      - `_build_tick_config() -> void` — reads all relevant constants from `Constants`
    - **Remove:** `verify_matter_conservation()`, `_calculate_total_matter()`, `_assert_conservation()` — no numeric conservation in qualitative model
    - Add `world_age_changed(new_age)` signal to `EventBus.gd`.
    - Signature: ~150 lines. Qualitative orchestration + sub-tick accumulator.

  - [x] TASK_12: Update `sim_debug_panel.gd` — read qualitative tags
    - File: `src/scenes/ui/hud/sim_debug_panel.gd` — UPDATE
    - Replace all numeric field reads with qualitative tag reads:
      - **World section:** Display `world_age`, `world_age_timer`, `world_tags`, `sim_tick_count`, `sub_tick_accumulator`, `world_age_cycle_count`
      - **Sectors section:** For each sector in `GameState.sector_tags`: display sector name, `sector_tags` array, `colony_levels[sector_id]`, `grid_dominion[sector_id]` (faction + security_tag), connections
      - **Agents section:** For each agent in `GameState.agents`: display character name, `current_sector_id`, `condition_tag`, `wealth_tag`, `cargo_tag`, `agent_role`, `goal_archetype`, `is_disabled`, `sentiment_tags` (from `GameState.agent_tags`)
      - **Chronicle section:** Last 10 events from `GameState.chronicle_events`, last 5 rumors from `GameState.chronicle_rumors`
      - **Remove:** Axiom 1 check, stockpile displays, price displays, matter totals, numeric heat/entropy/power
    - Keep: F3 toggle, BBCode RichTextLabel rendering, refresh on `world_event_tick_triggered` signal.
    - Signature: ~200 lines. Pure tag display.

  ### PHASE 5: Validation

  - [x] TASK_13: Rewrite simulation unit tests for qualitative system
    - Files: `src/tests/core/simulation/test_*.gd` — REWRITE all 6 test files
    - Reference: `python_sandbox/tests/test_affinity.py` (test patterns, adapted for GUT framework)
    - **test_affinity_matrix.gd** (NEW — replaces `test_ca_rules.gd`):
      - `test_compute_affinity_positive_pair` — verify known (PIRATE, LOADED) → positive score
      - `test_compute_affinity_negative_pair` — verify known (MILITARY, PIRATE) → negative score
      - `test_compute_affinity_empty_tags` — verify empty → 0.0
      - `test_derive_agent_tags_basic` — verify role + personality → correct tag list
      - `test_derive_agent_tags_desperate` — verify DAMAGED + BROKE → DESPERATE tag
      - `test_derive_sector_tags_basic` — verify station sector → correct tag list
      - `test_economy_transitions_require_sustained_pressure` — verify progress counter gating
      - `test_hostile_infestation_builds_gradually` — verify infestation counter
    - **test_world_layer.gd** (REWRITE):
      - `test_initialize_world_creates_topology` — verify sector count matches TemplateDatabase
      - `test_sector_tags_match_templates` — verify initial tags
      - `test_bidirectional_connections` — verify A→B implies B→A
    - **test_grid_layer.gd** (REWRITE):
      - `test_economy_step_changes_tags` — verify economy tag transitions under pressure
      - `test_security_step_with_military` — verify military presence improves security
      - `test_colony_upgrade_requires_economy_and_security` — verify gating
    - **test_agent_layer.gd** (REWRITE):
      - `test_agents_initialized_from_templates` — verify agent count and structure
      - `test_affinity_scan_finds_targets` — verify agent targeting
      - `test_exploration_creates_new_sector` — verify sector discovery
      - `test_mortal_spawn_respects_economy_gate` — verify mortal spawn blocking
    - **test_chronicle_layer.gd** (REWRITE):
      - `test_event_logged_and_distributed` — verify staging → chronicle → agent memory
      - `test_rumor_generated` — verify rumor string format
    - **test_simulation_tick.gd** (REWRITE):
      - `test_full_tick_sequence` — verify tick increments and all layers called
      - `test_world_age_advances` — verify age cycling after timer expiry
      - `test_sub_tick_accumulator` — verify `advance_sub_ticks()` fires correct number of ticks
    - All tests: GUT framework `extends GutTest`, `before_each/after_each` with full `GameState` reset.
    - Signature: All tests pass with `gut` test runner. 0 failures.

  - [x] VERIFICATION_1: Project loads in Godot 3.6 editor with 0 errors — run `get_errors()` across all modified files
  - [ ] VERIFICATION_2: GUT test suite — all simulation tests pass (0 failures, 0 errors)
  - [ ] VERIFICATION_3: Manual sim tick — launch game scene, verify F3 debug panel shows qualitative tags for all 5 sectors and 14 agents, world age displays correctly
  - [ ] VERIFICATION_4: Sub-tick system — verify `SimulationEngine.advance_sub_ticks(10)` fires exactly 1 full tick (SUB_TICKS_PER_TICK=10)
  - [ ] VERIFICATION_5: Determinism — run `initialize_simulation("test_seed")` twice, verify `GameState` is identical after 5 ticks
  - [ ] VERIFICATION_6: Non-simulation systems unbroken — verify TimeSystem ticks, docking works, HUD displays, main menu loads
