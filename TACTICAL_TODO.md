<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 3 - Verification]
TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1; TRUTH_PROJECT.md § Automated Testing Boundary
LOG_REF: 2026-06-14 02:24:48
-->

## CURRENT GOAL: Health Tier Action Check Modifier Integration

- TARGET_SCOPE: Wire a health/condition modifier into `CoreMechanicsAPI.perform_action_check()` so that a caller can supply an optional `health_modifier` integer. Add `CONDITION_MODIFIERS` to `Constants.gd`. Add a helper `get_health_modifier(agent_uid)` to `AgentLayer` that reads the agent's `condition_tag` and returns the corresponding integer from `Constants.CONDITION_MODIFIERS`. Add focused GUT tests asserting that the modifier shifts roll totals correctly.

- TARGET_FILES:
  - `src/autoload/Constants.gd` — Add `CONDITION_MODIFIERS` dictionary mapping "HEALTHY" to 0, "DAMAGED" to -2, "DESTROYED" to -4.
  - `src/autoload/CoreMechanicsAPI.gd` — Add optional `health_modifier: int = 0` parameter to `perform_action_check()`; include it in `total_roll` and expose it in the returned dictionary.
  - `src/core/simulation/agent_layer.gd` — Add `get_health_modifier(agent_uid) -> int` mapping `condition_tag` -> `Constants.CONDITION_MODIFIERS`.
  - `src/tests/autoload/test_core_mechanics_api.gd` — Add assertions testing `health_modifier` shifting rolls.
  - `src/tests/core/simulation/test_agent_layer.gd` — Add assertions testing `get_health_modifier`.

- TRUTH_RELIANCE:
  - `1-GDD-Core-Mechanics.md` § 6.1 — Qualitative modifiers.

- TECHNICAL_CONSTRAINTS:
  - Forbidden GDScript syntax: `@export`, `@onready`, `await`.
  - Godot 3.6 stable compatibility.
  - Backward-compatible `perform_action_check`.

- OPTIONAL SUPPORT FIELDS WHEN THEY REDUCE AMBIGUITY:
  - PREAPPROVED_ADJACENT_OWNERS: None
  - VALIDATION_PLAN: Run test_core_mechanics_api.gd, test_agent_layer.gd, and full suite.

- ATOMIC_TASKS:
  - [x] TASK_1: **`Constants` extension.** Add `CONDITION_MODIFIERS` dictionary to `Constants.gd` mapping `HEALTHY` (0), `DAMAGED` (-2), `DESTROYED` (-4).
  - [x] TASK_2: **`CoreMechanicsAPI` signature extension.** Add `health_modifier: int = 0` as the fifth parameter of `perform_action_check()`. Include it in `total_roll` computation. Expose as `"health_modifier"` in returned dictionary.
  - [x] TASK_3: **`AgentLayer` helper.** Add `get_health_modifier(agent_uid) -> int` to `agent_layer.gd` that reads `condition_tag` and maps via `CONDITION_MODIFIERS` (defaults to 0 / HEALTHY if not found).
  - [x] TASK_4: **GUT tests — `CoreMechanicsAPI`.** In `test_core_mechanics_api.gd`, add `test_health_modifier_shifts_roll`.
  - [x] TASK_5: **GUT tests — `AgentLayer`.** In `test_agent_layer.gd`, add `test_get_health_modifier`.
  - [x] VERIFICATION: Run the full headless GUT suite.


