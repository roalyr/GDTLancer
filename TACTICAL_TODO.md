## CURRENT GOAL: Python Sandbox → Godot Simulation Engine Port

### EXECUTIVE SUMMARY

The Python sandbox has been restructured into a Godot-mirroring package hierarchy and
extended with `commodity_specie` (physical currency) and Specie injection at tick 0.
The next milestone is porting the proven Python simulation into the Godot GDScript
simulation engine, replacing the current stub implementations with the battle-tested
Python logic.

**What was completed (previous milestone):**
- All 15 Godot architecture tasks (GameState rebuild, CA rules, 4-layer processors,
  sim engine, debug panel, dead system pruning, unit tests, cleanup)
- Python sandbox restructured from 12 flat files → package hierarchy mirroring Godot
- `commodity_specie` added as 11th commodity (physical currency, always price=1)
- Specie injection at tick 0: each station receives STATION_INITIAL_SPECIE (200.0)
  debited from hidden_resources (mineral_density → propellant_sources fallback)
- Conservation Axiom verified: max drift 0.1106% over 10 ticks (within tolerance)
- All 58 Python unit tests pass; 10-tick simulation verified end-to-end

**What's next:** Port Python sandbox logic into GDScript simulation files. The Python
code serves as the authoritative reference implementation for all CA rules, agent
behaviors, bridge systems, and chronicle processing.

### PREVIOUS MILESTONE STATUS: Simulation Engine Foundation — Complete ✅

All 15 TASK items completed and verified. See SESSION-LOG.md for full history.

### PREVIOUS MILESTONE STATUS: Python Sandbox Restructuring — Complete ✅

Python sandbox restructured to mirror Godot layout. Specie injection implemented.
58 unit tests pass. 10-tick simulation verified. See SESSION-LOG.md.

---

- TARGET_FILES:

  **PYTHON SANDBOX — RESTRUCTURED LAYOUT (reference implementation):**
  - `python_sandbox/autoload/constants.py` (simulation constants, COMMODITY_IDS incl. commodity_specie)
  - `python_sandbox/autoload/game_state.py` (central data store, slag_total, undiscovered_matter_pool)
  - `python_sandbox/core/simulation/ca_rules.py` (9 pure CA transition functions)
  - `python_sandbox/core/simulation/bridge_systems.py` (heat/entropy/knowledge cross-layer)
  - `python_sandbox/core/simulation/chronicle_layer.py` (event capture + rumor generation)
  - `python_sandbox/core/simulation/world_layer.py` (static topology + resource init)
  - `python_sandbox/core/simulation/grid_layer.py` (CA processing + Specie injection at tick 0)
  - `python_sandbox/core/simulation/agent_layer.py` (all agent roles, mortal system, hostiles)
  - `python_sandbox/core/simulation/simulation_engine.py` (tick orchestrator, Axiom 1 verification)
  - `python_sandbox/database/registry/template_data.py` (5 stations, 5 factions, 14 characters, 13 agents)
  - `python_sandbox/tests/test_ca_rules.py` (58 unit tests, all passing)
  - `python_sandbox/main.py` (CLI runner with reporting)

  **GODOT — PORT TARGETS (to be updated with Python-proven logic):**
  - `src/core/simulation/simulation_engine.gd` (align tick orchestrator with Python version)
  - `src/core/simulation/world_layer.gd` (align with Python world_layer.py)
  - `src/core/simulation/grid_layer.gd` (align with Python grid_layer.py, add Specie injection)
  - `src/core/simulation/agent_layer.gd` (align with Python agent_layer.py)
  - `src/core/simulation/chronicle_layer.gd` (align with Python chronicle_layer.py)
  - `src/core/simulation/bridge_systems.gd` (align with Python bridge_systems.py)
  - `src/core/simulation/ca_rules.gd` (align with Python ca_rules.py — 9 pure functions)
  - `src/autoload/Constants.gd` (add commodity_specie, STATION_INITIAL_SPECIE, WRECK_SLAG_FRACTION)
  - `src/autoload/GameState.gd` (add slag_total, undiscovered_matter_pool, universe_constant)
  - `database/registry/` (update .tres files with commodity_specie market data)

- TRUTH_RELIANCE:
  - `TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md` Section 8 (Simulation Architecture): Primary reference
  - `TRUTH_SIMULATION-GRAPH.md` v1.2: Authoritative simulation graph — four-layer model, tick sequence, conservation axioms
  - `TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md` Section 1.3: Conservation Axioms (Axiom 1: TOTAL_MATTER + UNDISCOVERED_MATTER_POOL + slag_total == UNIVERSE_CONSTANT)
  - `TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md` Section 1.2: CA Catalogue
  - Python sandbox: Serves as **reference implementation** for all simulation logic

- DESIGN_PHILOSOPHY:
  - **Python-First Validation.** All simulation logic is prototyped and verified in Python before porting to GDScript. The Python sandbox is the executable specification.
  - **Specie is Physical Currency.** `commodity_specie` is a stockpile commodity (price always 1.0). Agent `cash_reserves` remains abstract for now — converting to Specie transactions is a future milestone.
  - **Injection Prevents Deadlock.** At tick 0, each station receives STATION_INITIAL_SPECIE (200.0) debited from hidden_resources. Without this, the economy stalls because no Specie exists for initial trades.
  - **Conservation is Law.** `TOTAL_MATTER + UNDISCOVERED_MATTER_POOL + slag_total == UNIVERSE_CONSTANT`. Verified every tick.
  - **Double-Buffered Grids.** Read from one grid, write to another, swap. No mid-tick mutation.
  - **Pure Function CA Rules.** All CA rules: `(cell_state, neighbor_states, config) -> new_cell_state`. No side effects.
  - **Keep Flight Untouched.** The RigidBody flight model is working and will be connected later.

- TECHNICAL_CONSTRAINTS:
  - Godot 3.x, GLES2 — `export var`, `onready`, NO `await`, NO `@export`
  - Python 3 for sandbox (no pytest — use `python3 -m unittest`)
  - GameState remains the single source of truth
  - All simulation processing is synchronous within a single `_process_tick()` call
  - CA neighbors = sectors connected via topology, NOT 2D adjacency
  - Deterministic given same seed + tick sequence

---

- ATOMIC_TASKS:

  Tasks for the Godot port milestone are TBD — will be defined when this milestone
  is actively started. The Python sandbox restructuring milestone is now complete.

  **Completed tasks from previous milestones are archived in SESSION-LOG.md.**

  - [ ] VERIFICATION:
    - Python sandbox: `python3 main.py --ticks 10 --quiet` runs clean ✅ (verified)
    - Python sandbox: `python3 -m unittest tests.test_ca_rules -v` — 58/58 pass ✅ (verified)
    - Godot simulation engine: all 15 Godot tasks completed ✅ (see SESSION-LOG.md)
    - Godot port of Python-proven logic: NOT YET STARTED (next milestone)

