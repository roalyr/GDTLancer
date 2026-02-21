## CURRENT GOAL: Qualitative Simulation Rewrite — Strip Numeric, Go Tag-Driven

### EXECUTIVE SUMMARY

Replace all numeric simulation fields (hull floats, stockpile quantities, price deltas,
CA formulas) with 3-level qualitative tags (HIGH/MID/LOW or domain-specific equivalents).
Sector state evolves through tag-transition CA rules stratified into 3 layers (Economy,
Security, Environment). Agent behavior stays affinity-driven but loses all numeric
formulas — interactions produce tag transitions instead of arithmetic. Conservation
becomes structural: balanced transition rules prevent runaway states instead of tracking
a numeric budget. ~60% of current code deleted outright. Target: <2000 total lines
across all simulation files, down from ~6843.

### PREVIOUS MILESTONE STATUS: Tag-Affinity Injection — Complete ✅

All implementation tasks completed and verified. See SESSION-LOG.md (2026-02-21 entries).
Source concept: `python_sandbox/Concept_injection.md` (STATUS: IMPLEMENTED).

### PREVIOUS MILESTONE STATUS: Python Sandbox Restructuring — Complete ✅

Python sandbox restructured to mirror Godot layout. Specie injection implemented.
58+9=67 unit tests pass. 10-tick simulation verified. See SESSION-LOG.md.

### PREVIOUS MILESTONE STATUS: Simulation Engine Foundation — Complete ✅

All 15 TASK items completed and verified. See SESSION-LOG.md for full history.

---

- TARGET_FILES:

  **DELETE (Phase 1):**
  - `python_sandbox/core/simulation/ca_rules.py` — DELETE entirely (563 lines, 95% quantitative formulas)
  - `python_sandbox/tests/test_ca_rules.py` — DELETE entirely (742 lines, tests deleted module)
  - `python_sandbox/autoload/constants.py` — GUT from ~289 lines to ~80 lines
  - `python_sandbox/autoload/game_state.py` — GUT numeric fields, replace with tag dicts

  **REDESIGN (Phase 2):**
  - `python_sandbox/core/simulation/affinity_matrix.py` — REWRITE as single source of truth for ALL tags
  - `python_sandbox/database/registry/template_data.py` — REWRITE templates as tag lists

  **REWRITE (Phase 3):**
  - `python_sandbox/core/simulation/world_layer.py` — SIMPLIFY to ~50 lines (read templates → write initial tags)
  - `python_sandbox/core/simulation/grid_layer.py` — REWRITE as tag-transition CA (~250 lines from ~675)
  - `python_sandbox/core/simulation/bridge_systems.py` — STRIP to tag derivation only (~60 lines from ~161)
  - `python_sandbox/core/simulation/agent_layer.py` — REWRITE affinity handlers to tag-based (~600 lines from ~1731)
  - `python_sandbox/core/simulation/simulation_engine.py` — SIMPLIFY (~120 lines from ~422)
  - `python_sandbox/core/simulation/chronicle_layer.py` — TRIM (~120 lines from ~205)

  **REPORT + TESTS (Phase 4):**
  - `python_sandbox/main.py` — REWRITE report as tag dashboard (~300 lines from ~829)
  - `python_sandbox/tests/test_affinity.py` — REWRITE for new tag vocabulary + CA rules (~80 lines)
  - `python_sandbox/Concept_injection.md` — UPDATE with qualitative pivot note

- TRUTH_RELIANCE:
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §1 "The Core Philosophy: The Closed Loop" — Conservation axioms being **replaced** by structural tag-transition balance
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §2 "The Entity Graph" — Node model being **simplified** from 5 matter states to tag-labeled sectors/agents
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §3 "The Flow Graph" — All numeric flow edges being **deleted**; replaced by tag-transition rules
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §5 "The Information Graph" — Chronicle/rumor system **kept** (already qualitative)
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §6 "Architectural Implementation Map" — Layer structure **kept** (World→Grid→Bridge→Agent→Chronicle)
  - `python_sandbox/Concept_injection.md` — Original affinity concept; tag-driven philosophy extended to entire simulation
  - **NOTE:** This rewrite **supersedes** the numeric conservation model in TRUTH_SIMULATION-GRAPH.md. The 5-layer tick pipeline architecture is preserved, but all numeric matter-tracking edges are removed. TRUTH_SIMULATION-GRAPH.md should be updated AFTER this rewrite is verified.

- TECHNICAL_CONSTRAINTS:
  - Python 3, no external dependencies (no pytest — use `python3 -m unittest`)
  - 3-level tags globally: HIGH/MID/LOW pattern adapted per domain
  - 3 resource categories only: RAW_MATERIALS, MANUFACTURED, CURRENCY (replaces 6+ commodities)
  - Tag-transition CA rules stratified into 3 layers: Economy, Security, Environment
  - Hostiles as sector tags only (INFESTED/THREATENED/clear) — no entity tracking
  - Wrecks as sector tag (HAS_SALVAGE) — no entity tracking
  - No explicit numeric conservation — balanced transition rules prevent runaway
  - Heat system, power system, market prices, propellant/energy/consumables tracking: ALL DELETED
  - Knowledge refresh, event_memory agent reads, faction_standings: ALL DELETED
  - No numeric fields remain in agent state, sector state, or report output (except: tick counts, world age timer, colony upgrade counters)
  - Total codebase target: <2000 lines across all simulation files

- DESIGN_DECISIONS:
  - 3-level tags globally (HIGH/MID/LOW pattern adapted per domain)
  - 3 resource categories (RAW_MATERIALS, MANUFACTURED, CURRENCY) instead of 6 commodities
  - Tag-transition CA rules stratified into 3 layers (Economy, Security, Environment)
  - Hostiles as sector tags only (INFESTED/THREATENED/clear), no entity tracking
  - Wrecks as sector tag (HAS_SALVAGE), no entity tracking
  - No explicit numeric conservation — balanced transition rules prevent runaway
  - Heat system, power system, market prices, propellant/energy/consumables: all deleted
  - Knowledge refresh, event_memory agent reads, faction_standings: all deleted

---

- ATOMIC_TASKS:

  ### PHASE 1: Delete Dead Weight

  - [ ] TASK_1: Delete `ca_rules.py` entirely
    - File: `python_sandbox/core/simulation/ca_rules.py` (563 lines)
    - Action: Remove file. 95% quantitative formulas — all replaced by tag-transition rules in TASK_8.
    - Signature: File no longer exists on disk.

  - [ ] TASK_2: Delete `test_ca_rules.py` entirely
    - File: `python_sandbox/tests/test_ca_rules.py` (742 lines)
    - Action: Remove file. Tests for deleted module.
    - Signature: File no longer exists on disk.

  - [ ] TASK_3: Gut `constants.py` — remove all numeric simulation constants
    - File: `python_sandbox/autoload/constants.py` (289→~80 lines)
    - Remove: All CA rate constants (extraction rates, diffusion rates, market pressure, faction propagation). All agent numeric thresholds (cash_low, hull_repair, desperation, trade hull risk). All hostile numeric params (pool pressures, spawn costs, encounter chances, damage ranges). All role-specific config keys (pirate_raid_chance, hauler_cargo_capacity, military_patrol_interval). All power/maintenance/hazard drift params. All commodity base prices and IDs. All AFFINITY_* numeric tuning knobs (ATTACK_DAMAGE_FACTOR, LOOT_FRACTION, TRADE amounts, etc.).
    - Keep: World age cycle definition (PROSPERITY/DISRUPTION/RECOVERY durations), colony level names, AFFINITY thresholds (ATTACK_THRESHOLD, TRADE_THRESHOLD, FLEE_THRESHOLD), mortal spawn conditions (rewritten as tag conditions), catastrophe probability, structural constants (caps, timeouts), tag-transition tick counts for colony upgrade/downgrade.
    - Signature: `constants.py` ≤80 lines. No float rate constants. No commodity IDs. No AFFINITY_* numeric params.

  - [ ] TASK_4: Gut `game_state.py` — remove all float-quantity fields, replace with tag dicts
    - File: `python_sandbox/autoload/game_state.py` (94→~60 lines)
    - Remove: `world_resource_potential`, `world_hidden_resources`, `grid_stockpiles`, `grid_market`, `grid_power`, `grid_maintenance`, `hostile_pools`, `grid_wrecks`, `world_total_matter`, `slag_total`, `undiscovered_matter_pool`, `universe_constant`, `inventories`, `assets_ships`, `game_time_seconds`
    - Replace with: `sector_tags: dict[str, list[str]]` (per-sector tag sets), `agent_tags: dict[str, list[str]]` (per-agent, absorbs sentiment_tags), `world_tags: list[str]` (global tags from world age)
    - Keep: `world_topology`, `world_hazards` (re-typed as qualitative tags), `world_age`/`world_age_timer`/`world_age_cycle_count`, `grid_dominion` (simplified to faction + security tag), `colony_levels`, `agents`, `characters`, `chronicle_events`, `chronicle_rumors`, `player_*` fields, `discovered_sector_count`, `mortal_*` counters, `catastrophe_log`, `grid_sector_tags` (renamed to `sector_tags`)
    - Signature: No float fields except tick/timer counters. `sector_tags`, `agent_tags`, `world_tags` present.

  ### PHASE 2: Redesign Core Data Model

  - [ ] TASK_5: Define the tag vocabulary — rewrite `affinity_matrix.py` as single source of truth
    - File: `python_sandbox/core/simulation/affinity_matrix.py` (~369→~400 lines)
    - Add three new tag vocabulary sections:
      - `SECTOR_ECONOMY_TAGS`: {RICH, ADEQUATE, POOR} per resource category (RAW_MATERIALS, MANUFACTURED, CURRENCY → 3 categories × 3 levels = 9 economy tags)
      - `SECTOR_SECURITY_TAGS`: {SECURE, CONTESTED, LAWLESS}
      - `SECTOR_ENVIRONMENT_TAGS`: {MILD, HARSH, EXTREME}  (collapse radiation/thermal/gravity into one composite)
      - `SECTOR_SPECIAL_TAGS`: {STATION, FRONTIER, HAS_SALVAGE, DISABLED, HOSTILE_INFESTED, HOSTILE_THREATENED}
      - `AGENT_CONDITION_TAGS`: {HEALTHY, DAMAGED, DESTROYED} (replaces hull float)
      - `AGENT_WEALTH_TAGS`: {WEALTHY, COMFORTABLE, BROKE} (replaces cash float)
      - `AGENT_CARGO_TAGS`: {LOADED, EMPTY} (replaces inventory float)
    - Keep existing: role tags, personality tags, dynamic tags (DESPERATE etc.)
    - Rewrite AFFINITY_MATRIX to reference new vocabulary (many existing pairs stay, some rename: WEAK→DAMAGED etc.)
    - Signature: All tag enums defined as module-level dicts/sets. `compute_affinity()`, `derive_agent_tags()`, `derive_sector_tags()` updated for new vocabulary.

  - [ ] TASK_6: Redefine sector/agent state in `template_data.py` — tag-based templates
    - File: `python_sandbox/database/registry/template_data.py` (~443→~300 lines)
    - Replace numeric location fields: `mineral_density: 24000` → tag `RAW_RICH`. `danger_level: 2` → tag `CONTESTED`. `radiation_level: 0.05` → tag `MILD`. `market_inventory{...}` → initial economy tags per resource category.
    - Keep: connections, sector_type, location_name, controlling_faction_id, available_services
    - Character templates: Remove credits, skills, age, reputation numeric fields. Keep personality_traits. Add initial condition/wealth tags.
    - Agent templates: Remove hull, fuel, cargo numeric fields. Add initial tag sets.
    - Signature: No numeric fields in location/character/agent templates (except connection lists). All entities described by tag lists.

  ### PHASE 3: Rewrite Simulation Layers

  - [ ] TASK_7: Rewrite `world_layer.py` — read templates, write initial sector tags
    - File: `python_sandbox/core/simulation/world_layer.py` (~193→~50 lines)
    - Simplify to: read location templates → write initial sector tags + topology to GameState.
    - Remove: all numeric resource scaling, matter checksum, `recalculate_total_matter()`.
    - Signature: `initialize_world()` populates `state.sector_tags` and `state.world_topology` from template_data. No float math. ≤50 lines.

  - [ ] TASK_8: Rewrite `grid_layer.py` as tag-transition CA engine
    - File: `python_sandbox/core/simulation/grid_layer.py` (~675→~250 lines)
    - This replaces BOTH old grid_layer AND deleted ca_rules. Three stratified CA sub-layers:
      - **Economy layer:** Each sector has 3 resource-category tags (RAW/MANUFACTURED/CURRENCY × RICH/ADEQUATE/POOR). Transitions driven by: colony level (hub extracts more), neighbor influence (trade route diffusion as tag propagation), agent actions (traders/haulers shift levels), world age (DISRUPTION → decay bias, PROSPERITY → growth bias). ~15–20 transition rules.
      - **Security layer:** Each sector has one security tag (SECURE/CONTESTED/LAWLESS). Transitions driven by: military presence, pirate presence, hostile infestation, neighbor propagation. ~10 rules.
      - **Environment layer:** Each sector has one environment tag (MILD/HARSH/EXTREME). Transitions driven by: world age (DISRUPTION→drift toward HARSH), catastrophe events (→EXTREME), passive recovery. ~8 rules.
      - **Colony level transitions:** Keep frontier→outpost→colony→hub. Upgrade: SECURE + economy tags above threshold for N ticks. Downgrade: LAWLESS or economy below threshold for N ticks.
      - **Hostile presence:** Sector tag HOSTILE_INFESTED/HOSTILE_THREATENED/(absent=clear). Grows in LAWLESS+neglected sectors, shrinks with military presence. ~5 rules.
    - Total: ~40–50 transition rules, each a simple `if sector_has(tags) and condition → replace_tag(old, new)`. No floats.
    - Signature: `process_tick()` iterates over sectors, applies tag-transition rules per layer, writes updated `sector_tags`. No numeric CA imports. ≤250 lines.

  - [ ] TASK_9: Rewrite `bridge_systems.py` — strip to tag derivation only
    - File: `python_sandbox/core/simulation/bridge_systems.py` (~161→~60 lines)
    - Remove: heat sink (entirely unused in qualitative), entropy hull drain, propellant/energy drain, knowledge refresh (event_memory never read)
    - Keep: `_refresh_agent_tags()` (already qualitative), `_refresh_sector_tags()` (rewrite to read new sector state)
    - Add: `_refresh_world_tags()` — derive global tags from world age (PROSPERITY→[ABUNDANT, STABLE], DISRUPTION→[SCARCE, VOLATILE], RECOVERY→[RECOVERING])
    - Signature: `process_tick()` calls 3 refresh fns. No float math. ≤60 lines.

  - [ ] TASK_10: Rewrite `agent_layer.py` — all handlers produce tag transitions
    - File: `python_sandbox/core/simulation/agent_layer.py` (~1731→~600 lines)
    - The affinity dispatch skeleton stays (`_action_affinity_scan`, `_resolve_agent_interaction`, `_resolve_sector_interaction`) but ALL handlers lose numeric formulas:
      - **ATTACK:** actor ATTACKS target → target gains DAMAGED (or DAMAGED→DESTROYED). If DESTROYED → target disabled, sector gains HAS_SALVAGE, attacker gains LOADED.
      - **TRADE:** actor TRADES at STATION → actor LOADED↔EMPTY swap, sector economy tag shifts one step.
      - **DOCK:** actor DOCKS → DAMAGED→HEALTHY, BROKE gains wealth step, LOADED sells (economy shift).
      - **FLEE:** actor moves away (existing movement logic stays).
      - **HARVEST:** if sector HAS_SALVAGE → actor gains LOADED, sector loses HAS_SALVAGE.
    - Remove: all float math (damage formulas, cash transfers, price lookups, cargo quantity management), hostile encounter check (replaced by hostile sector tags + affinity), `_action_buy`/`_action_sell` (replaced by tag-based trade at dock).
    - Keep: movement logic (`_action_move_toward`, `_action_move_random`), mortal spawn/cleanup (rewrite spawn conditions to tag-based), catastrophe logic (rewrite effects to tag applications), respawn logic (simplify — fixed cooldown, restore to HEALTHY+COMFORTABLE), sector discovery (simplify — tag-condition check instead of cash/fuel cost).
    - Signature: No float math in any handler. Actions produce tag changes only. ≤600 lines.

  - [ ] TASK_11: Rewrite `simulation_engine.py` — simplify tick orchestrator
    - File: `python_sandbox/core/simulation/simulation_engine.py` (~422→~120 lines)
    - Remove: `verify_matter_conservation`, `_calculate_total_matter`, `_matter_breakdown` (no numeric matter to track)
    - Remove: ~80% of `_build_tick_config` (most constants gone)
    - Keep: tick orchestration (world age timer, layer processing order), world age transitions, `_apply_age_config` (now sets world tags instead of numeric overrides)
    - Signature: `process_tick()` runs: Grid(tag CA) → Bridge(tag refresh) → Agent(affinity dispatch) → Chronicle. No Axiom 1 check. ≤120 lines.

  - [ ] TASK_12: Rewrite `chronicle_layer.py` — trim unused stubs
    - File: `python_sandbox/core/simulation/chronicle_layer.py` (~205→~120 lines)
    - Remove: significance scoring stub, causality stub (never used).
    - Keep: event capture + rumor generation + distribution.
    - Possibly extend: report tag transitions as events.
    - Signature: `process_tick()` captures events, generates rumors, distributes. ≤120 lines.

  ### PHASE 4: Report and Tests

  - [ ] TASK_13: Rewrite `main.py` report — compact tag dashboard
    - File: `python_sandbox/main.py` (~829→~300 lines)
    - Replace 20+ numeric report sections with compact tag dashboard:
      - **WORLD:** age + world tags + cycle count (1 line)
      - **SECTORS:** table with columns = sector name | colony level | economy tags | security | environment | special tags
      - **AGENTS:** table with columns = name | role | sector | condition | wealth | cargo | personality tags | current goal
      - **CHRONICLE:** last N rumors (already qualitative)
      - **LIFECYCLE:** agent enable/disable/spawn events (already qualitative)
      - **TRANSIENT:** head/tail tick windows showing sector tags + agent tags per tick (compact, no floats)
    - Remove: AXIOM_1, MATTER_BREAKDOWN, RESOURCE_FLOW_TIMELINE, DEPLETION_MILESTONES, STOCKPILE_DYNAMICS, STOCKPILE_COMMODITIES, HAZARD_DRIFT, MARKET_PRICES, AGENT_STATS, HOSTILE_POP_TIMELINE, WRECKS_MATTER
    - Signature: Report output contains zero float values (except tick counts/timers). Human-scannable, LLM-parseable. ≤300 lines.

  - [ ] TASK_14: Rewrite `tests/test_affinity.py` — update for new tag vocabulary + CA rules
    - File: `python_sandbox/tests/test_affinity.py` (~116→~80 lines)
    - Update for new tag vocabulary.
    - Add tests for tag-transition CA rules (economy transitions, security transitions, environment transitions).
    - Signature: All tests pass with `python3 -m unittest tests.test_affinity -v`. ≥10 test cases.

  - [ ] TASK_15: Update `Concept_injection.md` — note qualitative pivot
    - File: `python_sandbox/Concept_injection.md`
    - Add note: qualitative pivot builds on the original affinity concept. Tag-driven simulation replaces all numeric formulas. Conservation is structural (balanced transition rules), not arithmetic (matter sums).
    - Signature: Document updated with pivot description.

  ### VERIFICATION

  - [ ] VERIFICATION_1: `python3 main.py --ticks 50` runs without crashes
  - [ ] VERIFICATION_2: Report shows all sectors and agents with meaningful tag evolution over 50 ticks
  - [ ] VERIFICATION_3: Emergent behaviors observable — pirates gravitate to LAWLESS+RICH sectors, military to HOSTILE_INFESTED, traders to SECURE+STATION, explorers to FRONTIER
  - [ ] VERIFICATION_4: Colony level transitions occur within ~100 ticks given favorable conditions
  - [ ] VERIFICATION_5: World age cycle affects tag transition biases (DISRUPTION → sectors trend toward POOR/HARSH)
  - [ ] VERIFICATION_6: No numeric fields remain in agent state, sector state, or report output (except: tick counts, world age timer, colony upgrade counters)
  - [ ] VERIFICATION_7: Total codebase <2000 lines across all simulation files
  - [ ] VERIFICATION_8: `python3 -m unittest tests.test_affinity -v` — all tests pass

---

- LINE_BUDGET:

  | File | Before | Target |
  |------|--------|--------|
  | `ca_rules.py` | 563 | **DELETED** |
  | `test_ca_rules.py` | 742 | **DELETED** |
  | `constants.py` | 289 | ~80 |
  | `game_state.py` | 94 | ~60 |
  | `affinity_matrix.py` | 369 | ~400 |
  | `template_data.py` | 443 | ~300 |
  | `world_layer.py` | 193 | ~50 |
  | `grid_layer.py` | 675 | ~250 |
  | `bridge_systems.py` | 161 | ~60 |
  | `agent_layer.py` | 1731 | ~600 |
  | `simulation_engine.py` | 422 | ~120 |
  | `chronicle_layer.py` | 205 | ~120 |
  | `main.py` | 829 | ~300 |
  | `test_affinity.py` | 116 | ~80 |
  | **TOTAL** | **~6843** | **~2420** |

- EXECUTION_ORDER:
  - Phase 1 (TASK_1–4) must complete before Phase 2
  - Phase 2 (TASK_5–6) must complete before Phase 3
  - Phase 3 tasks are partially parallelizable: TASK_7 first, then TASK_8+9 (no interdependency), then TASK_10 (depends on TASK_8 tag-transition API), then TASK_11+12
  - Phase 4 (TASK_13–15) depends on all Phase 3 tasks
  - VERIFICATION depends on all tasks
