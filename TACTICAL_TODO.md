<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: 1-GDD-Core-Mechanics.md § 6.1; TRUTH_PROJECT.md § Automated Testing Boundary
LOG_REF: 2026-06-14 02:11:58
-->

## CURRENT GOAL: Wealth Tier Action Check Modifier Integration

- TARGET_SCOPE: Wire the already-defined `WEALTH_MODIFIERS` constant into `CoreMechanicsAPI.perform_action_check()` so that a caller can supply an optional `wealth_modifier` integer. Add a `get_wealth_modifier(character_uid)` helper to `CharacterSystem` that reads the character's `wealth_tier` and returns the corresponding integer from `Constants.WEALTH_MODIFIERS`. Add focused GUT tests asserting that the modifier shifts roll totals correctly for all three tiers. No changes to action threshold values, approach logic, simulation layer, or UI are in scope.

- TARGET_FILES:
  - `src/autoload/CoreMechanicsAPI.gd` — Add optional `wealth_modifier: int = 0` parameter to `perform_action_check()`; include it in `total_roll` and expose it in the returned dictionary.
  - `src/core/systems/character_system.gd` — Add `get_wealth_modifier(character_uid) -> int` that maps `wealth_tier` → `Constants.WEALTH_MODIFIERS` value (defaults to 0 / COMFORTABLE if tier is unknown).
  - `src/tests/autoload/test_core_mechanics_api.gd` — Add assertions: BROKE (-2) shifts totals down, WEALTHY (+2) shifts totals up, COMFORTABLE (+0) is neutral, absent modifier defaults to 0.
  - `src/tests/core/systems/test_character_system.gd` — Add assertions: `get_wealth_modifier` returns -2 for BROKE, 0 for COMFORTABLE, +2 for WEALTHY, and 0 for unknown tier.

- TRUTH_RELIANCE:
  - `1-GDD-Core-Mechanics.md` § 6.1 — "Action Check Modifiers: Broke: -2 / Comfortable: +0 / Wealthy: +2".
  - `TRUTH_PROJECT.md` § Automated Testing Boundary — "Public signatures, initialization contracts … must stay in GUT."

- TECHNICAL_CONSTRAINTS:
  - Forbidden GDScript syntax: `@export`, `@onready`, `await`.
  - Godot 3.6 stable compatibility (no Godot 4 APIs).
  - `perform_action_check` must remain backward-compatible: existing callers that omit the new parameter must receive identical results (default `wealth_modifier = 0`).
  - `WEALTH_MODIFIERS` in `Constants.gd` is already defined and must not be redefined or duplicated.
  - Do not alter action approach thresholds (`ACTION_CHECK_CRIT_THRESHOLD_*`, `ACTION_CHECK_SWC_THRESHOLD_*`).

- OPTIONAL SUPPORT FIELDS WHEN THEY REDUCE AMBIGUITY:
  - OUT_OF_SCOPE: Any UI change to display the modifier, any simulation-layer wiring (NPC wealth tags to action checks), any change to `WEALTH_MODIFIERS` values, any new approach type, any contract board change, any reporting change.
  - PREAPPROVED_ADJACENT_OWNERS: None — all changes are within TARGET_FILES.
  - VALIDATION_PLAN: Run `src/tests/autoload/test_core_mechanics_api.gd` and `src/tests/core/systems/test_character_system.gd` in isolation; then run the full GUT suite. All assertions must pass with zero regressions.
  - MANUAL_VALIDATION: None required — all claims are deterministic and locally seeded.

- ATOMIC_TASKS:
  - [x] TASK_1: **`CoreMechanicsAPI` signature extension.** Add `wealth_modifier: int = 0` as the fourth parameter of `perform_action_check()`. Add it to `total_roll` computation (`var total_roll = dice_sum + module_modifier + wealth_modifier`). Expose it in the returned results dictionary as `"wealth_modifier": wealth_modifier`. Update the docstring to document the new parameter.
  - [x] TASK_2: **`CharacterSystem` helper.** Add `get_wealth_modifier(character_uid) -> int` to `character_system.gd`. Implementation: look up `wealth_tier` via `get_wealth_tier(character_uid)` and return `Constants.WEALTH_MODIFIERS.get(wealth_tier, 0)`.
  - [x] TASK_3: **GUT tests — `CoreMechanicsAPI`.** In `test_core_mechanics_api.gd`, add a new test group (e.g. `test_wealth_modifier_shifts_roll`). Seed deterministic attribute/skill values and assert:
    - Calling with `wealth_modifier = -2` (BROKE) produces `roll_total` exactly 2 lower than the same call with `wealth_modifier = 0`.
    - Calling with `wealth_modifier = 2` (WEALTHY) produces `roll_total` exactly 2 higher than the same call with `wealth_modifier = 0`.
    - Calling with `wealth_modifier = 0` (COMFORTABLE) is identical to omitting the parameter entirely.
    - The returned dictionary contains the `"wealth_modifier"` key with the correct value.
    Use a fixed seed (`_rng.seed = <constant>`) via a seeded helper or mock to make dice deterministic in the test fixture.
  - [x] TASK_4: **GUT tests — `CharacterSystem`.** In `test_character_system.gd`, add `test_get_wealth_modifier`:
    - `get_wealth_modifier` returns -2 when `wealth_tier == "BROKE"`.
    - `get_wealth_modifier" returns 0 when `wealth_tier == "COMFORTABLE"`.
    - `get_wealth_modifier` returns 2 when `wealth_tier == "WEALTHY"`.
    - `get_wealth_modifier` returns 0 (default) when called with an unknown or missing character uid.
  - [x] VERIFICATION: Run the full headless GUT suite. All assertions must pass with zero regressions. Update `SESSION-LOG.md`.

