<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 2; TRUTH_EXPLORATION-PILLARS.md § 3
LOG_REF: 2026-07-26 02:50:00
-->

## CURRENT GOAL: M25 Community & Sector Interaction

- TARGET_SCOPE: Integrate community presence and sector-level interactions. Adds sector arrival/departure sequences with logistical weight (resource costs, World Clock Ticks). Generates dynamic interaction hooks based on board state and track degradation rather than hand-authored quests. Implements environmental events driven by sector track thresholds. Implements the "Dangling Carrot" gating system for outer-margin nodes (mechanically locked until specific conditions/Asset Cards are met).
- TARGET_FILES:
  - `src/core/systems/sector_manager.gd` — New or updated system handling sector arrival/departure logic, logistical costs, and threshold events.
  - `src/core/systems/hook_generator.gd` — System for generating interaction hooks from sector tags and track states.
  - `src/core/systems/node_gate_system.gd` — System governing outer-margin node locking (the Dangling Carrot).
  - `src/tests/core/systems/test_sector_manager.gd` — GUT unit tests for sector logistics.
  - `src/tests/core/systems/test_hook_generator.gd` — GUT unit tests for hook generation.
  - `src/tests/core/systems/test_node_gate_system.gd` — GUT unit tests for node access rules.
- TRUTH_RELIANCE: TRUTH_GAME-LOOP-VISION.md, TRUTH_EXPLORATION-PILLARS.md (Pillar 4: Dangling Carrot)
- TECHNICAL_CONSTRAINTS:
  - Integration with existing `WorldClock` and `GameState`.
  - Hook generation must rely purely on existing track data and tags—no strings or raw quest text generation.
  - Node gating logic must be deterministic and based on `AssetCard` possession or sector tags.
- OUT_OF_SCOPE:
  - Visual 3D assets for outer-margin nodes (this is handled in M26).
  - Narrative dialogue trees (this game uses mechanical hooks and tags, not scripted dialogue).
- PREAPPROVED_ADJACENT_OWNERS:
  - `src/autoload/GameState.gd` (Sector states, tags, track thresholds)
- VALIDATION_PLAN:
  - Test sector arrival/departure applies correct resource drain and tick advances.
  - Test hooks are generated when sector tracks degrade below specific thresholds.
  - Test outer-margin nodes block access unless the required criteria (e.g. specific Asset Card) are met.
- MANUAL_VALIDATION:
  - Run the board UI, attempt to traverse to a locked node, verify rejection. Traverse to a normal node, verify logistics apply.

- ATOMIC_TASKS:
  - [x] TASK_1: Sector Travel Logistics
    - Created `src/core/systems/sector_manager.gd` handling arrival/departure travel costs (Supplies) and World Clock tick advancement.
  - [x] TASK_2: Dynamic Hook Generation
    - Created `src/core/systems/hook_generator.gd` generating dynamic community interaction hooks from sector tracks and tags.
  - [x] TASK_3: Environmental Events
    - Implemented sector track threshold evaluation in `sector_manager.gd` to trigger environmental events (unrest, resource collapse, piracy).
  - [x] TASK_4: Dangling Carrot Gating
    - Created `src/core/systems/node_gate_system.gd` defining gating access rules for outer-margin nodes requiring specific Asset Cards or sector conditions.
  - [x] TASK_5: Unit and Integration Tests
    - Created unit tests `test_sector_manager.gd`, `test_hook_generator.gd`, and `test_node_gate_system.gd`.
  - [x] VERIFICATION: Tested travel logistics, environmental events, dynamic hook generation, and node access gating via GUT (1013/1013 assertions passed, 0 failures). Verified clean scene instantiation for `main_game_scene.tscn` and `board_ui.tscn`.
