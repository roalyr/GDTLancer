## CURRENT GOAL: Implement Action Stakes & Neutral Approach for Digital Platform

- TARGET_FILES:
  - `src/autoload/Constants.gd`
  - `database/definitions/action_template.gd`
  - `database/registry/actions/action_default.tres`
  - `src/autoload/CoreMechanicsAPI.gd`
  - `src/core/systems/narrative_action_system.gd`
  - `tests/autoload/test_core_mechanics_api.gd`

- TRUTH_RELIANCE:
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md` Section 7.1 (Action Stakes Classification)
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md` Section 7.2 (Action Check Thresholds)
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md` Section 0.1 Glossary (Action Stakes, Action Approach)

- TECHNICAL_CONSTRAINTS:
  - Godot 3.x, GLES2
  - Maintain backward compatibility with existing CAUTIOUS/RISKY usages
  - Stateless system architecture pattern (systems read/write GameState)
  - EventBus for cross-system communication
  - All persistent enums must be in Constants.gd autoload

- ATOMIC_TASKS:
  - [x] TASK_1: Add `ActionStakes` enum to Constants.gd
    - Signature: `enum ActionStakes { HIGH_STAKES, NARRATIVE, MUNDANE }`
    - Add after existing `ActionApproach` enum

  - [x] TASK_2: Add `NEUTRAL` to `ActionApproach` enum in Constants.gd
    - Signature: `enum ActionApproach { CAUTIOUS, NEUTRAL, RISKY }`
    - Value order: CAUTIOUS=0, NEUTRAL=1, RISKY=2

  - [x] TASK_3: Add Neutral threshold constants to Constants.gd
    - Signature: `const ACTION_CHECK_CRIT_THRESHOLD_NEUTRAL = 15`
    - Signature: `const ACTION_CHECK_SWC_THRESHOLD_NEUTRAL = 11`
    - Add after CAUTIOUS thresholds, before RISKY thresholds

  - [x] TASK_4: Update `action_template.gd` with `stakes` property
    - Signature: `export(int, "HIGH_STAKES", "NARRATIVE", "MUNDANE") var stakes: int = 1`
    - Default to NARRATIVE (1) for backward compatibility
    - Add descriptive comment referencing GDD Section 7.1

  - [x] TASK_5: Update `action_default.tres` with stakes property
    - Add `stakes = 1` (NARRATIVE default)

  - [x] TASK_6: Update `CoreMechanicsAPI.perform_action_check()` to handle NEUTRAL approach
    - Add `elif action_approach == Constants.ActionApproach.NEUTRAL:` branch
    - Use `ACTION_CHECK_CRIT_THRESHOLD_NEUTRAL` and `ACTION_CHECK_SWC_THRESHOLD_NEUTRAL`

  - [x] TASK_7: Update `narrative_action_system.gd` to use stakes-based approach
    - Modify `resolve_action()` to accept optional ActionTemplate
    - If stakes != HIGH_STAKES, force approach to NEUTRAL
    - Add helper `_get_effective_approach(stakes: int, player_approach: int) -> int`

  - [x] TASK_8: Create/Update unit tests for new mechanics
    - Test NEUTRAL approach thresholds in CoreMechanicsAPI
    - Test stakes-based approach override in NarrativeActionSystem
    - Location: `tests/autoload/test_core_mechanics_api.gd`

  - [x] VERIFICATION:
    - Run GUT tests: `res://tests/src/autoload/test_core_mechanics_api.gd`
    - Run GUT tests: `res://tests/src/core/systems/test_narrative_action_system.gd`
    - Manual test: Verify action_default.tres loads without errors
    - Confirm Constants.ActionApproach.NEUTRAL == 1
    - Confirm Constants.ActionStakes.HIGH_STAKES == 0
    - Confirm perform_action_check with NEUTRAL approach uses thresholds 11/15
