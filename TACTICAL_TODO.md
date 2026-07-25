<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 2; TRUTH_EXPLORATION-PILLARS.md § 3
LOG_REF: 2026-07-26 02:00:00
-->

## CURRENT GOAL: M22 Mode B UI — Board Interface

- TARGET_SCOPE: Implement the 2D board interface using simple board game conventions. The interface needs to handle tokens, grids, track displays, card areas, and dice roll feedback. We also need a Mode A ↔ Mode B transition system. No illustrated depth-mat scenes or paper-doll sprite systems.
- TARGET_FILES:
  - `scenes/ui/board/board_ui.tscn` — Main Mode B Board UI scene
  - `src/core/ui/board/board_ui.gd` — Board UI controller script
  - `scenes/ui/board/components/track_display.tscn` / `src/core/ui/board/components/track_display.gd` — UI for progress tracks
  - `scenes/ui/board/components/card_area.tscn` / `src/core/ui/board/components/card_area.gd` — UI for card hand displays
  - `scenes/ui/board/components/dice_roll_feedback.tscn` / `src/core/ui/board/components/dice_roll_feedback.gd` — Visual representation of 3d6 check results
  - `src/core/systems/mode_transition_manager.gd` — System handling switching between Mode A (3D Flight) and Mode B (2D Board)
  - `src/tests/core/systems/test_mode_transition_manager.gd` — GUT unit tests for ModeTransitionManager
  - `src/tests/core/ui/test_board_ui.gd` — GUT integration tests for BoardUI
- TRUTH_RELIANCE: TRUTH_GAME-LOOP-VISION.md § 2 (The Board Action Loop)
- TECHNICAL_CONSTRAINTS:
  - Primary runtime: Godot 3.6 stable, GLES2.
  - Forbidden GDScript syntax: `@export`, `@onready`, `await`.
  - Typed GDScript patterns compatible with Godot 3.6.
- OUT_OF_SCOPE:
  - Complex 3D environments, Mode A content (handled in later milestones), fully finished board layouts (Zone layout is TBD).
- PREAPPROVED_ADJACENT_OWNERS:
  - `src/autoload/GameState.gd`
  - `src/autoload/EventBus.gd`
- VALIDATION_PLAN:
  - Mode transition functions properly (no memory leaks or scene tree errors).
  - UI accurately reflects data from `GameState` and `BoardActionLoop`.
  - Input passes through Mode B to trigger actions.
- MANUAL_VALIDATION:
  - Run the game scene and trigger Mode B transition.

- ATOMIC_TASKS:
  - [x] TASK_1: Mode Transition Manager
    - Created `src/core/systems/mode_transition_manager.gd` handling Mode A ↔ Mode B scene state transitions.
  - [x] TASK_2: Track Display UI Component
    - Created `scenes/ui/board/components/track_display.tscn` and `src/core/ui/board/components/track_display.gd` to render 0-10 tracks and tier thresholds.
  - [x] TASK_3: Card Area UI Component
    - Created `scenes/ui/board/components/card_area.tscn` and `src/core/ui/board/components/card_area.gd` to display Asset and Impact card hands.
  - [x] TASK_4: Dice Roll Feedback UI Component
    - Created `scenes/ui/board/components/dice_roll_feedback.tscn` and `src/core/ui/board/components/dice_roll_feedback.gd` to visualize 3d6 check results.
  - [x] TASK_5: Main Board UI Assembly & File Location Audit
    - Assembled `scenes/ui/board/board_ui.tscn` and `src/core/ui/board/board_ui.gd` bringing together tracks, cards, dice feedback, and token grid.
    - Verified strict directory placement (GDScript logic in `src/`, Scenes in `scenes/`).
  - [x] VERIFICATION: Tested ModeTransitionManager (12/12 assertions) and BoardUI (5/5 assertions) via GUT unit/integration tests.
