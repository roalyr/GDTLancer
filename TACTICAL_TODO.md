## CURRENT GOAL: Simulation Friction & Pacing — Kill Hyperactivity, Add Momentum

### EXECUTIVE SUMMARY

The tag-driven qualitative simulation produces emergent behavior, but runs too hot:
agents attack every tick, sector tags flip instantly, wealth inflates monotonically,
and the universe reads as a constant deathmatch rather than a functioning society.

Root cause (per external Gemini analysis of 30/300/3000-tick chronicles): the system
is **binary and frictionless**. Fix by adding **threshold pools** (economy transitions
need accumulated pressure, not a single delta tick), **agent cooldowns/satiation**
(after combat, agents need recovery time), and **wealth sinks** (active drain so not
everyone ends up wealthy). Target: 90-tick session should read as a narrative with
momentum — trends that build, crises that develop, lulls between action.

### PREVIOUS MILESTONE STATUS: Qualitative Simulation Rewrite — Complete ✅

All 15 TASK items + 8 VERIFICATIONs completed. Tag-driven CA engine operational.
1916 lines total (under 2000 budget). 11 tests passing. See SESSION-LOG.md.

### PREVIOUS MILESTONE STATUS: Session Dynamics Tuning (Round 1) — Complete ✅

Security progress counters (per-sector 3–6 tick thresholds), exploration cooldown +
diminishing returns, mortal spawn diminishing returns, catastrophe mortal kills,
90-tick session scale (330-tick world age cycle). Validated at 30 and 90 ticks.

---

- TARGET_FILES:

  **FRICTION LAYER (Phase 1):**
  - `python_sandbox/autoload/constants.py` — Add economy threshold, combat cooldown, wealth drain constants
  - `python_sandbox/autoload/game_state.py` — Add economy progress counters, agent combat cooldown state
  - `python_sandbox/core/simulation/grid_layer.py` — Economy transitions via progress counter (like security)
  - `python_sandbox/core/simulation/agent_layer.py` — Combat cooldown/satiation, wealth drain, hostile infestation transition pacing

  **BALANCE PASS (Phase 2):**
  - `python_sandbox/core/simulation/agent_layer.py` — Tune affinity dispatch to reduce attack rate
  - `python_sandbox/core/simulation/affinity_matrix.py` — Review ATTACK_THRESHOLD, add SATIATED tag interactions

  **TESTS + VALIDATION (Phase 3):**
  - `python_sandbox/tests/test_affinity.py` — Add tests for economy progress counter, combat cooldown
  - `python_sandbox/main.py` — Validate with 90-tick and 300-tick chronicles

- TRUTH_RELIANCE:
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §6 "Architectural Implementation Map" — Layer pipeline preserved
  - External analysis: Gemini dynamic review (2026-02-21) — 4 systemic issues identified
  - Design principle: Tag transitions should require **accumulated pressure**, not single-tick deltas

- TECHNICAL_CONSTRAINTS:
  - Python 3, no external dependencies
  - Existing progress-counter pattern (colony upgrade/downgrade, security) must be reused for consistency
  - Total agent attacks per 100 ticks should be <50% of tick count (currently ~98%)
  - Economy tag transitions should take 3+ ticks of sustained pressure (currently instant)
  - Wealth distribution at tick 90 should NOT be >80% WEALTHY (currently inflates monotonically)
  - No new numeric simulation fields — use qualitative tags and tick counters only

- DESIGN_DECISIONS:
  - Economy progress counter: Same pattern as security — accumulate pressure ticks, only transition when threshold reached
  - Combat satiation: After attacking, agent gains internal cooldown (N ticks). During cooldown, affinity scan skips combat targets. Simple, no new tags needed externally — just an agent dict field.
  - Wealth drain: Per-tick passive drain chance (like AGENT_UPKEEP_CHANCE but specifically WEALTHY→COMFORTABLE). Current AGENT_UPKEEP_CHANCE=0.02 is too low to counteract wealth generation.
  - Hostile infestation pacing: HOSTILE_INFESTED should not appear/disappear in 1 tick. Gate behind the security progress counter (infested only when sector has been LAWLESS for N ticks).

---

- ATOMIC_TASKS:

  ### PHASE 1: Add Friction

  - [ ] TASK_1: Economy progress counter — constants + state
    - Files: `constants.py`, `game_state.py`
    - Add: `ECONOMY_UPGRADE_TICKS_REQUIRED = 3` (ticks of positive delta to shift up one level)
    - Add: `ECONOMY_DOWNGRADE_TICKS_REQUIRED = 3` (ticks of negative delta to shift down)
    - Add to game_state: `economy_upgrade_progress: dict = {}` (sector_id → {category → tick_count})
    - Add to game_state: `economy_downgrade_progress: dict = {}` (sector_id → {category → tick_count})
    - Signature: Constants defined, state fields initialized in GameState.__init__().

  - [ ] TASK_2: Economy progress counter — grid_layer implementation
    - File: `grid_layer.py`
    - Rewrite `_step_economy()` to use progress-counter pattern (matching _step_security).
    - Delta still calculated same way, but only applies level change when counter reaches threshold.
    - Initialize progress counters in `initialize_grid()` for each sector × category.
    - Signature: Economy tags no longer flip every tick. Counter state persists in game_state.

  - [ ] TASK_3: Combat cooldown/satiation for agents
    - Files: `constants.py`, `agent_layer.py`
    - Add: `COMBAT_COOLDOWN_TICKS = 5` — after an attack, agent cannot initiate another for N ticks
    - In `_resolve_agent_interaction()`: after ATTACK, set `agent["last_attack_tick"] = state.sim_tick_count`
    - In `_action_affinity_scan()` / `_best_agent_target()`: skip combat-eligible targets if cooldown active
    - Signature: Agent attack rate drops to max 1 per 5 ticks. Agents that just attacked switch to movement/trade/docking.

  - [ ] TASK_4: Wealth drain — increase upkeep pressure
    - File: `constants.py`
    - Increase `AGENT_UPKEEP_CHANCE` from 0.02 to 0.05 (5% per tick per agent)
    - Add: `WEALTHY_DRAIN_CHANCE = 0.08` — additional per-tick chance for WEALTHY agents to drop to COMFORTABLE
    - In `_apply_upkeep()`: add separate WEALTHY→COMFORTABLE drain roll
    - Signature: Wealth distribution at tick 90 shows mix of WEALTHY/COMFORTABLE/BROKE, not all WEALTHY.

  - [ ] TASK_5: Hostile infestation pacing
    - Files: `constants.py`, `game_state.py`, `grid_layer.py`
    - Add: `HOSTILE_INFESTATION_TICKS_REQUIRED = 3` — sector must be LAWLESS for N ticks before becoming INFESTED
    - Add to game_state: `hostile_infestation_progress: dict = {}` (sector_id → consecutive lawless ticks)
    - Rewrite `_step_hostile_presence()` to use progress counter.
    - Also: HOSTILE_INFESTED should not clear instantly when security improves — require 2+ ticks of non-LAWLESS.
    - Signature: Hostile presence builds gradually and dissipates gradually.

  ### PHASE 2: Balance Pass

  - [ ] TASK_6: Raise ATTACK_THRESHOLD to reduce combat frequency
    - File: `affinity_matrix.py`, `constants.py`
    - Consider raising ATTACK_THRESHOLD from 1.2 to 1.5 (fewer affinity pairs reach threshold)
    - Add SATIATED interactions to AFFINITY_MATRIX: agent with recent combat has reduced aggression scores
    - OR: simpler — just rely on combat cooldown from TASK_3 + threshold raise
    - Signature: Total engagements per 100 ticks drops by ~40% from current levels.

  - [ ] TASK_7: Review agent movement — reduce clustering at Freeport Gamma
    - File: `agent_layer.py`
    - Current: Most agents congregate at Freeport Gamma (majority of combat happens there).
    - Fix: After combat, agent should prefer moving away from current sector (post-fight dispersal).
    - OR: `_action_move_toward_role_target()` should weigh uncrowded sectors higher.
    - Signature: Combat spread more evenly across sectors in 90-tick run.

  ### PHASE 3: Tests + Validation

  - [ ] TASK_8: Update tests for new mechanics
    - File: `tests/test_affinity.py`
    - Add: test_economy_transitions_require_sustained_pressure (3 ticks of delta before level change)
    - Add: test_hostile_infestation_builds_gradually
    - Update: setUp() to include new state fields
    - Signature: All tests pass with `python3 -m unittest tests.test_affinity -v`.

  - [ ] VERIFICATION_1: 90-tick chronicle (seed 123) — security changes ≤3 per epoch (epoch-size 3)
  - [ ] VERIFICATION_2: 90-tick chronicle — total engagements < 150 (currently 245)
  - [ ] VERIFICATION_3: 90-tick chronicle — economy transitions are gradual, not every-tick
  - [ ] VERIFICATION_4: 90-tick chronicle — hostile infestation builds/clears over 3+ ticks
  - [ ] VERIFICATION_5: 90-tick chronicle — wealth distribution at end is mixed (not all WEALTHY)
  - [ ] VERIFICATION_6: 300-tick chronicle (seed 123) — world age transitions occur, DISRUPTION is harsh, RECOVERY is visible
  - [ ] VERIFICATION_7: `python3 -m unittest tests.test_affinity -v` — all tests pass
