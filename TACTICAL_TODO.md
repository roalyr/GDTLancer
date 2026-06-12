<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: gameplay_milestone_audit.md
LOG_REF: 2026-06-12 23:00:00
-->

## CURRENT GOAL: Codebase Refactoring, Pruning, and Cleanup for GDD Revision

- TARGET_SCOPE: Strip the codebase of deprecated "Freelancer-clone" mechanics (dual currency, focus points, real-time combat remnants, standalone trade markets) to cleanly expose the qualitative simulation and TTRPG narrative core. The end goal is to remove as much mechanical clutter as possible, organize the remaining logic neatly, and prepare the codebase as a clean reference point for the upcoming GDD revision. **CRITICAL:** The code itself must contain extensive guiding comments (e.g., `# NOTE: GDD REVISION - ...`) outlining the new design intent.

- TARGET_FILES:
  - `src/core/systems/character_system.gd` — Remove focus points and dual-currency (specie vs credits) logic.
  - `src/core/simulation/agent_layer.gd` — Prune credit/specie math; add structural guiding comments for the upcoming monolithic script split.
  - `src/autoload/Constants.gd` — Clean up obsolete economy, combat, and module constants.
  - `src/core/simulation/simulation_engine.gd` — Annotate the future pivot to delay-based ticks instead of dock/undock triggers.
  - `src/core/ui/npc_trade_panel/npc_trade_panel.gd` — Deprecate standalone trade features; annotate pivot to contract-driven quests.
  - `src/core/ui/station_menu/station_menu.gd` — Remove standalone commodity market UI code/references; annotate focus on contracts.
  - `src/modules/piloting/ship_controller_ai.gd` — Add guiding comments deprecating dogfighting/combat AI states.
  - `src/core/agents/agent.gd` — Remove or heavily annotate disabled combat hooks.
  - `src/scenes/game_world/station/dockable_station.gd` — Annotate the shift to sectors-as-dockables.

- TRUTH_RELIANCE: `gameplay_milestone_audit.md` (Revised 2026-06-12)

- TECHNICAL_CONSTRAINTS: "Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"

- OUT_OF_SCOPE: Actually splitting `agent_layer.gd` into separate files (we are only annotating boundaries now), writing the new GDD (this is preparation for it).

- VALIDATION_PLAN:
  - Existing GUT tests must pass. Tests specifically testing removed mechanics (like credit clamping or specie routing) must be safely pruned or adapted to qualitative tags.

- MANUAL_VALIDATION: The game must boot. Docking and interacting must not crash. The removed sub-screens (standalone trade) should no longer be accessible.

- ATOMIC_TASKS:
  - [x] TASK_1: **Prune Focus Points & Dual Currency.** In `character_system.gd` and `Constants.gd`, remove all references to `focus_points`. Strip out the dual-currency routing logic (credits vs specie, `CREDIT_TRUST_THRESHOLD`). Revert character wealth to a simple qualitative or unified abstract metric. Update related GUT tests in `test_character_system.gd` to remove numeric assertions. Add guiding comments about inheriting from Ironsworn TTRPG mechanics.
  - [x] TASK_2: **Clean Simulation Economy Logic.** In `agent_layer.gd`, strip out the complex credit-gated purchasing math (`_attempt_npc_market_buy` / `_attempt_npc_market_sell`). Revert or simplify to pure qualitative tag flips without strict credit subtraction. Add massive guiding comments defining the future refactor boundaries (e.g., `# --- GDD REVISION: TRADER LOGIC BLOCK (To be extracted) ---`).
  - [x] TASK_3: **Deprecate Combat & Module Remnants.** In `ship_controller_ai.gd` and `agent.gd`, add prominent `DEPRECATED` comments to combat states, weapon firing, and module system references. Comment out or remove structural dead code that implies real-time dogfighting. Note that combat is disabled until re-imagined from the ground up.
  - [x] TASK_4: **Re-route Trade & Deprecate Standalone Markets.** In `station_menu.gd` and `npc_trade_panel.gd`, comment out or prune the standalone free-market UI logic. Add guiding comments stating that standalone trading is being dropped in favor of a unified contract/quest interface (Interaction Window). Update UI layouts to hide the broken/deprecated panels.
  - [x] TASK_5: **Annotate Simulation Ticks & Topology.** In `simulation_engine.gd`, add guiding comments to the tick triggers noting that dock/undock will no longer produce ticks, and that a delay-based tick (e.g., 10 minutes) is planned. In `dockable_station.gd`, add comments noting that "sectors are treated as dockables themselves" and we are moving away from stations as dockables within sectors.
  - [x] VERIFICATION: Run all GUT tests and safely prune/fix any that fail due to the removed mechanical clutter (especially in `test_agent_layer.gd` and `test_simulation_report.gd`). Verify the game boots without script errors. Ensure the codebase is saturated with `GDD REVISION` guiding comments explaining *why* things were pruned and where the design is heading.
