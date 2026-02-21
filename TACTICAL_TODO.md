## CURRENT GOAL: Economy Diversity & Population Equilibrium — Kill Homogeneous Inflation

### EXECUTIVE SUMMARY

The friction mechanics (progress counters, combat cooldown, wealth drain) work:
combat is paced (42 attacks / 90 ticks), security transitions are gradual, and
hostile infestation builds over time. However, the **economy converges to a flat
homogeneous state** and **population grows monotonically**. Verified data:

  t 30 [PROSPERITY]: 7/8 sectors RICH  | 0 POOR  | agents=17 | wealthy=5
  t150 [DISRUPTION]: 18/19 sectors RICH | 0 POOR  | agents=20 | wealthy=7
  t225 [DISRUPTION]: 0/20 sectors RICH  | 20 POOR  | agents=24 | wealthy=0
  t300 [RECOVERY]:   20/20 sectors RICH | 0 POOR  | agents=26 | wealthy=12

Root causes identified:
1. **World-age economy modifier is blanket** — DISRUPTION applies -1 uniformly to
   every sector every tick, RECOVERY applies +2 uniformly. With only 3 levels and
   3-tick thresholds, ALL sectors simultaneously hit POOR/RICH.
2. **No colony maintenance cost** — advanced colonies (hub/colony) don't drain economy.
   TRUTH_SIMULATION-GRAPH.md §3.4 requires "continuous matter investment to maintain."
3. **No population-density pressure** — a sector with 8 agents has the same economy
   delta as one with 0 agents. No consumption concept.
4. **Economy thresholds are identical** — all sectors use flat 3-tick thresholds,
   causing synchronized transitions (checkerboard pattern, like security before fix).
5. **Mortal lifecycle too generous** — survivors get COMFORTABLE, spawn in any security,
   no economy requirements, no attrition during DISRUPTION.

Fix: Add per-sector economy inertia (desync), conditional world-age modifiers (not
blanket), colony maintenance drain, population-density pressure, and tighter mortal
lifecycle. Target: at any tick snapshot, the economy should show a **mix** of RICH /
ADEQUATE / POOR sectors — never all the same.

### PREVIOUS MILESTONE STATUS: Friction & Pacing — Complete ✅

All 8 TASK items verified. Economy progress counters, combat cooldown (5 ticks),
wealth drain (5% upkeep + 8% wealthy drain), hostile infestation pacing (3 ticks).
42 attacks / 90 ticks (47%, under 50% cap). See SESSION-LOG.md.

### PREVIOUS MILESTONE STATUS: Session Dynamics Tuning (Round 1) — Complete ✅

Security progress counters (per-sector 3–6 tick thresholds), exploration cooldown +
diminishing returns, mortal spawn diminishing returns, catastrophe mortal kills,
90-tick session scale (330-tick world age cycle). Validated at 30 and 90 ticks.

### PREVIOUS MILESTONE STATUS: Qualitative Simulation Rewrite — Complete ✅

All 15 TASK items + 8 VERIFICATIONs completed. Tag-driven CA engine operational.

---

- TARGET_FILES:

  **PHASE 1 — ECONOMY DESYNC & DRAIN:**
  - `python_sandbox/autoload/constants.py` — Per-sector economy inertia ranges, colony maintenance flags, population density threshold
  - `python_sandbox/autoload/game_state.py` — Per-sector economy thresholds dict
  - `python_sandbox/core/simulation/grid_layer.py` — Desync economy thresholds, conditional world-age modifiers, colony maintenance drain, population pressure

  **PHASE 2 — POPULATION EQUILIBRIUM:**
  - `python_sandbox/autoload/constants.py` — Mortal spawn economy requirement, disruption attrition chance
  - `python_sandbox/core/simulation/agent_layer.py` — Economy-gated mortal spawn, survivor penalty, disruption attrition

  **PHASE 3 — TESTS & VALIDATION:**
  - `python_sandbox/tests/test_affinity.py` — Add tests for economy desync, colony maintenance, mortal spawn gating
  - `python_sandbox/main.py` — Validate with 90-tick and 300-tick runs

- TRUTH_RELIANCE:
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §3.4 "The Maintenance Cycle" — Colony levels require continuous matter investment; higher levels demand more. Failure to maintain → colony degrades.
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §3.2 "The Consumption Cycle" — Station population burns matter to survive. Higher population = higher consumption.
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §6.3 "The LifecycleSystem" — Mortal spawn requires MIN_STOCKPILE and MIN_SECURITY; permanent death on destruction.
  - External analysis: Gemini dynamic review (2026-02-21) — Economy/population inflation identified as persisting systemic issue.

- TECHNICAL_CONSTRAINTS:
  - Python 3, no external dependencies
  - Reuse existing progress-counter pattern (per-sector random thresholds, like security)
  - No new numeric simulation fields — qualitative tags and tick counters only
  - At any 90-tick snapshot: economy distribution must show ≥2 of 3 levels present (not all RICH or all POOR)
  - At 300 ticks: population count should plateau (not monotonic growth beyond ~20–25 agents)
  - Wealth distribution at any snapshot: no single wealth tier should exceed 60% of population
  - Colony maintenance concept must be present (per TRUTH_SIMULATION-GRAPH.md §3.4)

- DESIGN_DECISIONS:
  - **Per-sector economy inertia**: Same pattern as security thresholds. Each sector × category gets a random upgrade/downgrade tick threshold drawn from [MIN, MAX]. Breaks synchronization.
  - **Conditional world-age modifiers**: PROSPERITY bonus requires evidence of active commerce (LOADED agent or colony≥colony). DISRUPTION penalty targets specific categories based on conditions. RECOVERY bonus reduced from +2 to +1. This prevents blanket economy shifts.
  - **Colony maintenance drain**: hub=-1 all categories, colony=-1 RAW only, outpost/frontier=0. Maps to TRUTH §3.4 "higher colony levels demand more maintenance matter per tick."
  - **Population density pressure**: >3 agents in sector = -1 economy delta. Maps to TRUTH §3.2 metabolism (population consumes resources).
  - **Mortal spawn economy gate**: Require ≥1 economy axis at ADEQUATE+. Economically dead sectors don't produce new pilots. Maps to TRUTH §6.3 "requires MORTAL_SPAWN_MIN_STOCKPILE."
  - **Mortal survivors start BROKE** (currently COMFORTABLE). Barely-survived destruction should leave agents destitute.
  - **Disruption mortal attrition**: During DISRUPTION, mortals in HARSH/EXTREME sectors have per-tick death chance. Represents supply line collapse and exposure.

---

- ATOMIC_TASKS:

  ### PHASE 1: Economy Desync & Drain

  - [ ] TASK_1: Per-sector economy inertia thresholds
    - Files: `constants.py`, `game_state.py`, `grid_layer.py`, `agent_layer.py`
    - Add to constants.py: `ECONOMY_CHANGE_TICKS_MIN = 2`, `ECONOMY_CHANGE_TICKS_MAX = 5`
    - Add to game_state.py: `economy_change_threshold: dict = {}` (sector_id → {category → int})
    - In grid_layer.py `initialize_grid()`: seed per-sector per-category thresholds using `random.Random(f"{state.world_seed}:econ_thresh:{sector_id}:{category}")`
    - In grid_layer.py `_step_economy()`: replace flat `ECONOMY_UPGRADE_TICKS_REQUIRED` / `ECONOMY_DOWNGRADE_TICKS_REQUIRED` with per-sector per-category thresholds from `state.economy_change_threshold`
    - In agent_layer.py `_try_exploration()`: initialize `economy_change_threshold` for newly discovered sectors
    - Signature: Economy transitions desynchronize across sectors. Different sectors have 2–5 tick thresholds per category.

  - [ ] TASK_2: Conditional world-age economy modifiers
    - File: `grid_layer.py`
    - Rewrite world-age block in `_step_economy()`:
      - PROSPERITY: +1 only if (`_loaded_trade_count_for_sector() > 0` OR `colony_level in ("colony", "hub")`); else 0
      - DISRUPTION: -1 to RAW always; -1 to MANUFACTURED only if (pirate present OR HOSTILE_INFESTED in tags); 0 to CURRENCY
      - RECOVERY: +1 (was +2)
    - Signature: World age no longer blanket-shifts all sectors identically. Economy responds to local conditions.

  - [ ] TASK_3: Colony maintenance economy drain
    - File: `grid_layer.py`
    - In `_step_economy()`, after world-age block, add colony-level maintenance pressure:
      - `hub`: delta -= 1 for ALL categories (RAW, MANUFACTURED, CURRENCY)
      - `colony`: delta -= 1 for RAW only
      - `outpost` / `frontier`: no additional drain
    - Signature: Advanced colonies require active resupply to stay RICH. A hub without trade trends toward ADEQUATE/POOR.

  - [ ] TASK_4: Population density economy pressure
    - File: `grid_layer.py`
    - In `_step_economy()`, after colony maintenance, add population density pressure:
      - Count non-disabled, non-player agents in sector
      - if agent_count > 3: delta -= 1 (crowded sector consumes more than it produces)
    - Add `_active_agent_count_in_sector()` helper method to GridLayer
    - Signature: Crowded sectors face economic strain. Agents must disperse for the economy to thrive.

  ### PHASE 2: Population Equilibrium

  - [ ] TASK_5: Economy-gated mortal spawn
    - Files: `constants.py`, `agent_layer.py`
    - Add to constants.py: `MORTAL_SPAWN_MIN_ECONOMY_TAGS = ["RAW_ADEQUATE", "RAW_RICH", "MANUFACTURED_ADEQUATE", "MANUFACTURED_RICH", "CURRENCY_ADEQUATE", "CURRENCY_RICH"]`
    - In `_spawn_mortal_agents()`: add economy filter — eligible sectors must have at least 1 tag from MORTAL_SPAWN_MIN_ECONOMY_TAGS
    - Signature: Mortal agents only spawn in economically viable sectors. All-POOR sectors produce no newcomers.

  - [ ] TASK_6: Mortal survivor penalty and disruption attrition
    - Files: `constants.py`, `agent_layer.py`
    - In `_cleanup_dead_mortals()`: change survivor wealth from "COMFORTABLE" to "BROKE"
    - Add to constants.py: `DISRUPTION_MORTAL_ATTRITION_CHANCE = 0.03` (3% per tick for exposed mortals)
    - In `_apply_upkeep()`: if `state.world_age == "DISRUPTION"` and agent is non-persistent and sector has HARSH or EXTREME environment tag, roll `DISRUPTION_MORTAL_ATTRITION_CHANCE` for destruction (mark disabled, route through `_cleanup_dead_mortals` path)
    - Signature: Disruption is genuinely dangerous. Mortals in harsh sectors die. Survivors are destitute.

  ### PHASE 3: Tests & Validation

  - [ ] TASK_7: Update tests for economy diversity and population mechanics
    - File: `tests/test_affinity.py`
    - Add: `test_economy_thresholds_vary_per_sector` — verify different sectors get different thresholds after init
    - Add: `test_colony_maintenance_drains_economy` — verify hub sector with no trade trends downward over 10 ticks
    - Add: `test_mortal_spawn_blocked_in_poor_sector` — verify no mortal spawns when all economy axes are POOR
    - Add: `test_mortal_survivor_starts_broke` — verify survived mortal gets BROKE wealth
    - Update `setUp()` to include `economy_change_threshold` field
    - Signature: All tests pass with `python3 -m unittest tests.test_affinity -v`.

  - [ ] VERIFICATION_1: 90-tick run (seed 123) — economy shows ≥2 levels at t30, t60, t90 (not all RICH)
  - [ ] VERIFICATION_2: 300-tick run (seed 123) — during DISRUPTION, economy is mixed (not blanket POOR); during RECOVERY, not blanket RICH
  - [ ] VERIFICATION_3: 300-tick run (seed 123) — population count at t300 ≤ 25 (currently 26; target: plateau near 20)
  - [ ] VERIFICATION_4: 300-tick run (seed 123) — wealth distribution at any snapshot: no tier > 60% of agents
  - [ ] VERIFICATION_5: 90-tick run — colony maintenance visible: hub sectors without active trade degrade economy
  - [ ] VERIFICATION_6: `python3 -m unittest tests.test_affinity -v` — all tests pass
