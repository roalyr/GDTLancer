<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 2; TRUTH_EXPLORATION-PILLARS.md § 3
LOG_REF: 2026-07-26 02:30:00
-->

## CURRENT GOAL: M23 Impact Card Tables (Data-Driven Outcomes)

- TARGET_SCOPE: Implement data-driven outcome tables for board mutation. Impact Card outcome pools will be defined as data-driven `.tres` resources. These pools will contain Advantage, Disadvantage, Complication, and Opportunity entries keyed by context tags (such as sector tags, NPC relationship tags, or track states). Entries will strictly map to concrete board mutations (track deltas, tag changes, node state changes) with no oracle free-text generation.
- TARGET_FILES:
  - `src/core/resources/impact_card_entry.gd` — Custom Resource defining a single impact outcome (required tags, track deltas, tag changes).
  - `src/core/resources/impact_card_pool.gd` — Custom Resource containing an array of `ImpactCardEntry` resources.
  - `src/core/systems/impact_table_manager.gd` — System responsible for evaluating current context tags and querying pools to return valid impact cards/mutations.
  - `src/tests/core/resources/test_impact_resources.gd` — GUT unit tests for verifying resource structure and data mapping.
  - `src/tests/core/systems/test_impact_table_manager.gd` — GUT unit tests for the tag evaluation and impact retrieval logic.
- TRUTH_RELIANCE: TRUTH_GAME-LOOP-VISION.md § 2 (The Board Action Loop)
- TECHNICAL_CONSTRAINTS:
  - Godot 3.6 custom resources require explicit `class_name` or `load()` paths to be used effectively. Will use `tool` and `class_name` if they don't break dependencies, or stick to explicit loads.
  - Tables must only produce mechanical tags and state deltas, no unstructured text generation.
- OUT_OF_SCOPE:
  - Visual presentation of these cards (UI is already handled, specific rendering of impact card data will rely on existing components).
- PREAPPROVED_ADJACENT_OWNERS:
  - `src/autoload/GameState.gd`
  - `src/core/systems/board_action_loop.gd`
- VALIDATION_PLAN:
  - Create dummy `.tres` pools with various required/prohibited tags.
  - Evaluate pools through `ImpactTableManager` given mock context tags and ensure only the correct entries are returned.
  - Apply an impact entry and ensure track deltas and tag changes are correctly dispatched to `GameState`.
- MANUAL_VALIDATION:
  - Run tests. Verify `.tres` files can be easily edited in Godot 3.6 Inspector.

- ATOMIC_TASKS:
  - [x] TASK_1: Create Custom Resources
    - Implemented `ImpactCardEntry` (`src/core/resources/impact_card_entry.gd`) for context tag matching and mutation definitions.
    - Implemented `ImpactCardPool` (`src/core/resources/impact_card_pool.gd`) for grouping entries.
  - [x] TASK_2: Impact Table Manager Core
    - Implemented `ImpactTableManager` (`src/core/systems/impact_table_manager.gd`) for evaluating context tags across pools.
  - [x] TASK_3: Context and State Mutation
    - Integrated `ImpactTableManager` state mutation logic with `GameState` (player tracks, sector tracks, and sector/world tags).
  - [x] TASK_4: Unit and Integration Tests
    - Created unit tests `src/tests/core/resources/test_impact_resources.gd` and `src/tests/core/systems/test_impact_table_manager.gd`.
  - [x] VERIFICATION: Tested resource structure, tag filtering, and GameState mutations via GUT (1013/1013 assertions passed, 0 failures). Verified clean scene instantiation for `main_game_scene.tscn` and `board_ui.tscn`.
