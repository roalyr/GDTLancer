<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 2; TRUTH_EXPLORATION-PILLARS.md § 3
LOG_REF: 2026-07-26 00:57:15
-->

## CURRENT GOAL: M21 Board Mechanics Core (The Kernel)

- TARGET_SCOPE: Implement the 4-step board action loop (Target Node -> Asset Cards -> 3d6 Check -> Board Mutation via Impact Cards), 4 progress tracks (0-10 with tier shifts), and World Clock tick triggering.
- TARGET_FILES:
  - `src/core/cards/asset_card.gd` — Asset Card resource schema (lateral capability expanders)
  - `src/core/cards/impact_card.gd` — Impact Card resource schema (Advantage/Disadvantage outcomes)
  - `src/core/systems/action_check_engine.gd` — 3d6 roll engine and modifier calculator
  - `src/core/systems/board_action_loop.gd` — Orchestrator for Target -> Assemble -> Check -> Mutate flow
  - `src/autoload/GameState.gd` — Player tracks storage and state integration
  - `src/tests/core/systems/test_board_action_loop.gd` — GUT unit tests for board kernel
- TRUTH_RELIANCE: TRUTH_GAME-LOOP-VISION.md § 2 (The Board Action Loop), TRUTH_EXPLORATION-PILLARS.md § 3 (Lateral Progression)
- TECHNICAL_CONSTRAINTS:
  - Primary runtime: Godot 3.6 stable, GLES2.
  - Forbidden GDScript syntax: `@export`, `@onready`, `await`.
  - Typed GDScript patterns compatible with Godot 3.6.
- OUT_OF_SCOPE:
  - UI visual layout polish, Mode B depth mats / paper dolls, trading spreadsheets, 3D on-foot navigation.
- PREAPPROVED_ADJACENT_OWNERS:
  - `src/autoload/EventBus.gd` — for action resolution and board mutation signals.
- VALIDATION_PLAN:
  - Run GUT unit test `src/tests/core/systems/test_board_action_loop.gd`.
- MANUAL_VALIDATION:
  - None required for M21 core contracts.

- ATOMIC_TASKS:
  - [x] TASK_1: Player Progress Tracks Tier & Threshold System
    - Implement 4 player progress tracks (Health, Wealth, Morale, Supplies) on 0-10 scale in `GameState.gd` with tier mapping functions (e.g. CRITICAL 0-2, LOW 3-4, STABLE 5-7, PROSPEROUS 8-10).
  - [x] TASK_2: Asset Card & Impact Card Resource Schemas
    - Create `src/core/cards/asset_card.gd` (inherits `Resource`) defining `card_id`, `display_name`, `tags`, `unlocked_verbs`, `trade_offs`.
    - Create `src/core/cards/impact_card.gd` (inherits `Resource`) defining `card_id`, `type` ("ADVANTAGE"/"DISADVANTAGE"), `track_deltas`, `applied_tags`.
  - [x] TASK_3: 3d6 Action Check Engine
    - Create `src/core/systems/action_check_engine.gd`.
    - Implement `resolve_check(target_difficulty: int, applied_asset_cards: Array, player_track_states: Dictionary) -> Dictionary` returning `{dice_rolls: Array, total: int, success: bool, margin: int}`.
  - [x] TASK_4: Board Action Loop Orchestrator & World Clock Integration
    - Create `src/core/systems/board_action_loop.gd`.
    - Implement the 4-step sequence: `select_target(node)`, `assemble_action(asset_cards)`, `execute_check()`, `apply_mutation(impact_card)`.
    - Advance `WorldClock` by 1 tick upon completing `apply_mutation`.
  - [x] TASK_5: Automated Testing (GUT)
    - Create `src/tests/core/systems/test_board_action_loop.gd` and verify 3d6 resolution, Asset Card verb expansion, Impact Card track mutations, and World Clock tick advancement.
  - [x] VERIFICATION: All GUT tests in `test_board_action_loop.gd` pass cleanly.
