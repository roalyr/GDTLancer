<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; MODEL-CASCADE-PROTOCOL.md ROLE: Lead QA & Code Verificator
LOG_REF: 2026-05-23 23:24:49
-->

## CURRENT GOAL: Qualitative Demand-Driven Contract Foundations
- TARGET_SCOPE: Implement the first runtime slice of demand-driven contracts without numeric stockpiles, prices, or authored per-location contract lists. Scope covers sector demand pressure, demand tags, runtime occurrence scaffolding, and tick-order/test coverage.
- TARGET_FILES:
  - src/autoload/Constants.gd — bounded qualitative pressure thresholds and caps.
  - src/autoload/GameState.gd — per-sector demand pressure, thresholds, and future runtime occurrence state.
  - src/core/simulation/affinity_matrix.gd — shared demand-tag vocabulary.
  - src/core/simulation/grid_layer.gd — demand-pressure CA and relief-oriented sector tags.
  - src/core/simulation/simulation_engine.gd — future contract-generation hook between BridgeSystems and AgentLayer.
  - src/tests/core/simulation/test_grid_layer.gd — demand-pressure and relief-tag coverage.
  - src/tests/core/simulation/test_simulation_tick.gd — future tick-order lock once the generator lands.
  - TRUTH_SIMULATION-GRAPH.md — later qualitative-truth realignment.
  - TRUTH_CONTENT-CREATION-MANUAL.md — later authored-contract/manual cleanup.
- TRUTH_RELIANCE: ["SESSION-LOG.md 2026-02-21 qualitative rewrite entries", "TRUTH_PROJECT.md § Project Stack and Context", "TRUTH_SIMULATION-GRAPH.md §3.2", "TRUTH_SIMULATION-GRAPH.md §6.4", "TRUTH_CONSTRAINTS.md §1"]
- TECHNICAL_CONSTRAINTS: ["Platform (primary): Godot3 (3.6 stable)", "Graphics: GLES2 (for performance and compatibility)", "Simulation must remain qualitative/tag-driven", "Do not introduce numeric stockpiles, prices, or matter accounting", "Bounded counters, cooldowns, and thresholds are allowed as qualitative support state"]
- ATOMIC_TASKS:
  - [x] TASK_1: Introduce qualitative demand tag vocabulary plus per-sector pressure/threshold state in GameState/GridLayer/AffinityMatrix, and surface relief-oriented tags from sustained `*_POOR` conditions. Required signatures: preserve `GridLayer.initialize_grid()` and `GridLayer.process_tick(config)`; do not add numeric economy fields.
  - [x] TASK_2: Add a dedicated runtime contract occurrence store and generator that turns active demand tags into bounded contract dictionaries sourced from nearby qualifying sectors. Required signatures: preserve GameState qualitative storage patterns and avoid authored contract templates for the normal path.
  - [x] TASK_3: Insert the runtime contract generator into SimulationEngine tick order after BridgeSystems and before AgentLayer, then lock that ordering with focused tests.
  - [x] TASK_4: Extend AgentLayer so traders and haulers can notice, claim, and satisfy runtime qualitative contract occurrences using existing tag and affinity behavior.
  - [x] TASK_5: Realign docs and authoring boundaries so location and contract templates become optional curated overrides instead of the default runtime contract path.
  - [x] VERIFICATION: Success criteria/tests to run: touched-file diagnostics stay clean; demand tags only appear after sustained poor pressure and clear under relief; relief routing surfaces via tags rather than numbers; future generator step is tick-order tested; defer full GUT and manual verification to the user's final pass.
