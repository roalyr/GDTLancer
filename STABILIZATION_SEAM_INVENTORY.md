<!--
PROJECT: GDTLancer
MODULE: STABILIZATION_SEAM_INVENTORY.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TRUTH_PROJECT.md § Compatibility Constraints; TRUTH_PROJECT.md § Workflow And Scope Boundary; TRUTH_CONTENT-CREATION-MANUAL.md §2, §6, §7; TRUTH_SIMULATION-GRAPH.md §6.4
LOG_REF: 2026-05-23 17:19:55
-->

# Stabilization Seam Inventory

Purpose: Historical TASK_0 baseline for the completed pre-feature stabilization milestone. This file no longer acts as the active task queue; it records what the sweep resolved, what was intentionally retained as a stable boundary or stub, and what small cleanup items remain for later milestones.

- `graceful_stub`: preserved public surface with safe placeholder behavior that should remain until the replacement system exists.
- `explicit_compatibility_boundary`: intentional adapter or dynamic boundary retained to isolate dependencies during refactor.
- `redundant_drift`: stale placeholder, outdated fixture, or leftover comment/path that should be removed or normalized in a later stabilization task.

No runtime behavior changes are introduced by this artifact. Keep it as a planning/reference document when scoping later cleanup or replacement work.

## Final Disposition

Disposition meanings after the completed sweep:

- `resolved`: the stabilization sweep normalized or closed the seam.
- `retained`: the seam remains intentionally as a stable stub or compatibility boundary.
- `carry_forward`: the seam is small, known, and should be lifted into a future milestone only if that area is reopened.

| ID | File | Original Classification | Final Disposition | What happened in the sweep | Next owner |
| :--- | :--- | :--- | :--- | :--- | :--- |
| S1 | TRUTH_CONTENT-CREATION-MANUAL.md | `redundant_drift` | `resolved` | The sector contract was normalized in TASK_1, and the final loop-back synced the remaining ship/tool/contract/character/agent examples and tuning references to the live schema. | Future manual edits should continue to validate against `/database/definitions/`. |
| S2 | src/autoload/GameState.gd + src/autoload/GameStateManager.gd | `explicit_compatibility_boundary` | `resolved` | Scene-state persistence/bootstrap was hardened in TASK_2 and verified in the final sweep. | Future scene-state changes should continue to route through `GameStateManager.gd`. |
| S3 | src/core/ui/station_menu/station_menu.gd | `graceful_stub` | `retained` | The deferred trading/contracts entry points now fail explicitly and safely instead of drifting silently. | Future trading/contracts milestone. |
| S4 | src/core/ui/main_hud/main_hud.gd | `graceful_stub` | `retained` | Deferred inventory/combat HUD entry points now expose explicit placeholder behavior. | Future inventory/combat milestone. |
| S5 | src/core/ui/main_hud/projected_target_bracket.gd | `explicit_compatibility_boundary` | `retained` | TASK_5 consolidated the projected-target bridge into one clearer compatibility boundary. | Future HUD/input refactor if this boundary is replaced. |
| S6 | src/scenes/game_world/world_manager.gd | `explicit_compatibility_boundary` | `retained` | TASK_5 centralized jump-transition rig calls behind local compatibility helpers. | Future jump-transition interface cleanup if the rig contract is formalized further. |
| S7 | src/core/agents/components/tool_controller.gd | `graceful_stub` | `retained` | The tool controller now returns the canonical `combat_unavailable` boundary instead of pretending combat exists. | Future combat rebuild milestone. |
| S8 | src/modules/piloting/player_controller_ship.gd | `explicit_compatibility_boundary` | `retained` | TASK_5 stabilized the typed input-state boundary without widening feature scope. | Future piloting architecture milestone if this state-machine boundary is reworked. |
| S9 | src/scenes/game_world/starsphere_slot.gd | `redundant_drift` | `carry_forward` | The placeholder `_ready()` body and unused `main_camera` field remain as a small standalone cleanup. | Later rendering/scene cleanup pass. |
| S10 | database/definitions/character_template.gd | `graceful_stub` | `retained` | The narrative/personality exports remain legitimate future-facing data surface, not dead drift. | Later narrative/social-system milestone. |
| S11 | src/tests/autoload/test_game_state_manager.gd | `redundant_drift` | `resolved` | TASK_4 normalized the persistence/bootstrap fixtures to the canonical sector ids. | None. |
| S12 | src/tests/core/ui/test_debug_window.gd | `redundant_drift` | `resolved` | Docked UI fixtures now follow the live docking/location contract. | None. |
| S13 | src/tests/core/systems/test_persistent_agents.gd | `redundant_drift` | `resolved` | Persistent-agent fixtures now use canonical sector/location assumptions. | None. |
| S14 | src/tests/core/systems/test_contact_manager.gd | `redundant_drift` | `resolved` | Contact-manager fixtures were normalized to canonical sectors. | None. |
| S15 | src/tests/scenes/game_world/world_manager/test_world_manager.gd + src/tests/scenes/jump_transition/test_jump_transition_regressions.gd | `redundant_drift` | `resolved` | World-manager and jump-transition suites now validate against live canonical sector ids. | None. |
| S16 | src/scenes/game_world/world_manager/world_generator.gd | `redundant_drift` | `carry_forward` | The `_load_contacts()` removed-system note remains as a minor documentation cleanup. | Later world-generator cleanup pass. |

## How To Use This Artifact Now

- Keep this file in the repo as the historical baseline for the completed stabilization sweep.
- Do not treat the rows above as the active task list; that role belongs to `TACTICAL_TODO.md`.
- When a future milestone touches a `retained` or `carry_forward` seam, lift the relevant row into the new contract instead of reopening the full sweep.

## Reviewed Canonical Anchors

The following in-scope owners were reviewed during TASK_0 and are treated as current source-of-truth anchors rather than active seam inventory items:

- `database/definitions/location_template.gd`
- `src/scenes/game_world/world_manager/world_generator.gd::_load_locations()`
- `src/core/systems/sector_loader.gd`

These anchors remained stable through the completed sweep and should stay the preferred starting points for later content/bootstrap work.