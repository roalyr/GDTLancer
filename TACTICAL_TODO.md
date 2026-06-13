<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1
LOG_REF: 2026-06-14 01:16:00
-->

## CURRENT GOAL: Qualitative Wealth System Integration (Replace Credits)

- TARGET_SCOPE: Implement the Qualitative Wealth System defined in the GDD, replacing the legacy numeric `credits` system. Introduce `wealth_tier` (Broke, Comfortable, Wealthy) and `wealth_progress` (0-10) for characters. Implement track advancement and demotion logic. Update contracts to use `contract_value_class` instead of `reward_credits`. Align all UI elements, templates, and tests to the new system.

- TARGET_FILES:
  - `src/autoload/Constants.gd` — Add `WEALTH_TIERS`, `WEALTH_TRACK_MAX`, and `CONTRACT_VALUE_CLASSES`.
  - `src/autoload/EventBus.gd` — Rename `player_credits_changed` to `player_wealth_changed`.
  - `database/definitions/character_template.gd` — Replace `credits` with `wealth_tier` and `wealth_progress`.
  - `database/definitions/contract_template.gd` — Replace `reward_credits` with `contract_value_class`.
  - `database/registry/characters/*.tres` — Update all character template seeds.
  - `database/registry/contracts/*.tres` — Update all contract template seeds.
  - `src/core/systems/character_system.gd` — Implement tier/progress logic (add/subtract progress, handle promotion/demotion).
  - `src/core/simulation/contract_generation_system.gd` — Generate `contract_value_class` instead of `reward_credits`.
  - `src/core/simulation/agent_layer/agent_contract.gd` — Award `wealth_progress` on contract completion based on value class.
  - `src/core/ui/main_hud/main_hud.gd` — Listen for `player_wealth_changed` and update UI.
  - `src/core/ui/contract_board/contract_board.gd` — Display Value Class instead of numeric credits.
  - `src/core/ui/debug_window/debug_window.gd` & `src/core/ui/npc_trade_panel/npc_trade_panel.gd` — Update labels.
  - `src/core/simulation/simulation_report/report_summarizer.gd` — Update report generation to output wealth tiers instead of credits.
  - `src/tests/...` — Update all relevant unit tests (`test_character_system.gd`, `test_agent_layer.gd`, `test_simulation_report.gd`, etc.).

- TRUTH_RELIANCE: `1-GDD-Core-Mechanics.md` Section 6.1 (Wealth Tiers & Tracks), `8-GDD-Simulation-Architecture.md` Axiom 3 (Material Basis of Value).

- TECHNICAL_CONSTRAINTS: 
  - Forbidden GDScript syntax: `@export`, `@onready`, and `await`.
  - Godot 3.6 stable compatibility.
  - Adhere strictly to the "Automated Testing Boundary" (All API and data-shape invariants must remain under GUT).

- OPTIONAL SUPPORT FIELDS WHEN THEY REDUCE AMBIGUITY:
  - OUT_OF_SCOPE: Actual NPC trade logic mutation (NPCs use abstract status tags rather than tracking precise wealth tracks; however, they still use `CharacterTemplate`, so default them to appropriate tiers).
  - VALIDATION_PLAN: Entire GUT test suite must pass cleanly without references to `credits`.

- ATOMIC_TASKS:
  - [x] TASK_1: **Core Constants & EventBus.** Update `Constants.gd` with new qualitative enums/constants and update `EventBus.gd` signals.
  - [x] TASK_2: **Templates & Registry.** Refactor `character_template.gd` and `contract_template.gd`. Use a Python script or manual edits to migrate all `.tres` files to the new qualitative properties.
  - [x] TASK_3: **Character System API.** Implement `wealth_tier` and `wealth_progress` mutation logic in `character_system.gd`, handling 0-10 track wrap-arounds for promotion and demotion.
  - [x] TASK_4: **Simulation Systems.** Update `contract_generation_system.gd` to yield `contract_value_class` (Low/Mid/High). Update `agent_contract.gd` to grant the correct progress amount on delivery (+1, +2, +3).
  - [x] TASK_5: **UI & Reporting.** Update all UI scripts (`main_hud.gd`, `contract_board.gd`, etc.) and `report_summarizer.gd` to display qualitative data.
  - [x] VERIFICATION: Run the full headless GUT suite. Ensure zero regressions and total API compliance. Update `SESSION-LOG.md`.
