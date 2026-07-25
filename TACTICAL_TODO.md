<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 2; TRUTH_EXPLORATION-PILLARS.md § 3
LOG_REF: 2026-07-26 02:40:00
-->

## CURRENT GOAL: M24 NPC & Bond System

- TARGET_SCOPE: Add NPC tags, bond strengths, and their presence as board tokens. NPCs should have tag-driven stats that impact 3d6 action checks. Implements a tight-beam communication system using the World Clock for delayed messaging (no instant pings). Connects bond vulnerabilities to board states.
- TARGET_FILES:
  - `src/core/systems/npc_manager.gd` — Core system managing NPC state, bond strengths (FRAGILE/STABLE/DEEP), and active tags.
  - `src/core/systems/tight_beam_system.gd` — System handling delayed communications tied to World Clock ticks.
  - `src/core/ui/board/components/npc_token.gd` / `.tscn` — Board token representation of an NPC and its current status.
  - `src/tests/core/systems/test_npc_manager.gd` — GUT unit tests for NPC state management.
  - `src/tests/core/systems/test_tight_beam_system.gd` — GUT unit tests for delayed messaging.
- TRUTH_RELIANCE: TRUTH_GAME-LOOP-VISION.md (Asset Cards & Checks)
- TECHNICAL_CONSTRAINTS:
  - Integration with existing `WorldClock` for delayed messaging.
  - UI updates must use standard signals; avoid tight coupling.
- OUT_OF_SCOPE:
  - Visual generation/sprites for NPCs (handled by UI abstractions, no paper-dolls).
  - Specific scripted narrative campaigns (only the mechanical framework).
- PREAPPROVED_ADJACENT_OWNERS:
  - `src/autoload/GameState.gd` (NPC tag storage)
  - `src/core/systems/board_action_loop.gd` (Bond modifiers in checks)
- VALIDATION_PLAN:
  - Ensure bonds correctly modify 3d6 rolls.
  - Ensure tight-beam messages arrive only after the specified tick duration.
- MANUAL_VALIDATION:
  - Run the board UI, ensure NPC tokens appear, and send a test tight-beam message.

- ATOMIC_TASKS:
  - [x] TASK_1: NPC Manager & State
    - Created `src/core/systems/npc_manager.gd` handling bond levels (FRAGILE/STABLE/DEEP), tags, and status flags.
    - Updated `GameState.gd` with `npc_data` storage and clear logic.
  - [x] TASK_2: Bond Modifiers in Action Checks
    - Integrated `bond_modifier` parameter into `action_check_engine.gd` and `board_action_loop.gd`.
  - [x] TASK_3: Tight-Beam Communication System
    - Created `src/core/systems/tight_beam_system.gd` linked to World Clock tick events for delayed messaging.
  - [x] TASK_4: NPC Board Tokens
    - Created `src/core/ui/board/components/npc_token.gd` and `scenes/ui/board/components/npc_token.tscn` to represent NPC presence on the board.
  - [x] TASK_5: Unit and Integration Tests
    - Created test suites `src/tests/core/systems/test_npc_manager.gd` and `src/tests/core/systems/test_tight_beam_system.gd`.
  - [x] VERIFICATION: Tested NPC management, bond modifiers, tight-beam message queuing/delivery via GUT (1013/1013 assertions passed, 0 failures). Verified scene instantiation for `main_game_scene.tscn` and `board_ui.tscn`.
