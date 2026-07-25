<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_EXPLORATION-PILLARS.md § 4, § 5
LOG_REF: 2026-07-26 03:35:00
-->

## CURRENT GOAL: M29 Playable Board Game MVP

- TARGET_SCOPE: Integrate all milestones (M20-M28) into a playable MVP session. The player must be able to fly in Mode A, dock to transition to Mode B, interact with NPCs via Asset Cards, perform 3d6 action checks, and witness board mutations. The World Clock should apply sector pressure, and an outer-margin node should be visible in Mode A but mechanically locked in Mode B to act as a long-term objective.
- TARGET_FILES:
  - `src/core/systems/game_state.gd` — State transitions between Mode A and Mode B.
  - `src/main.tscn` (or equivalent root scene) — The fully wired MVP scene.
  - `src/core/ui/board/mode_b_board.tscn` — Integration of board UI components.
  - `src/core/systems/sector_manager.gd` / `src/core/systems/world_clock.gd` — Tying sector pressure and clock ticks together.
- TRUTH_RELIANCE: TRUTH_EXPLORATION-PILLARS.md (§4: Dangling Carrot, §5: Graduated Spatial Radius)
- TECHNICAL_CONSTRAINTS:
  - Must use only the default Godot theme primitives and inline `StyleBoxFlat` (no custom Theme files).
  - Mode A ↔ Mode B transition must work end-to-end.
  - Must pass 100% GUT tests and show zero runtime errors upon launch.
- OUT_OF_SCOPE:
  - Adding new mechanics beyond what M20-M28 provides.
  - Extensive content beyond the initial 1-hour core sector.
- ATOMIC_TASKS:
  - [x] TASK_1: System Integration & Wiring
    - Hook up `GlobalRefs` and `GameState` to correctly manage transitions between Mode A (flight) and Mode B (board).
    - Ensure `AssetSystem`, `SectorManager`, `WorldClock`, and NPC tokens are initialized correctly together in the root scene.
  - [x] TASK_2: Playable Scene Assembly (`main.tscn`)
    - Combine Mode A and Mode B components into a single launchable game scene (or scene transition setup).
    - Ensure the player can "dock" from Mode A to trigger Mode B.
  - [x] TASK_3: World Clock & Sector Pressure Setup
    - Connect the `WorldClock` ticks to resource drain or track degradation.
    - Connect board action loop (Target Node -> Asset Card -> 3d6 -> Impact Card) fully from UI to state.
  - [x] TASK_4: Outer-Margin Node Implementation
    - Place a visually striking "Dangling Carrot" outer-margin node in the Mode A 3D environment.
    - Mechanically lock this node in Mode B, requiring specific conditions/cards to unlock.
  - [x] TASK_5: Stability, GUT Tests, and Manual Playtest
    - Confirmed 100% GUT test pass rate (275/275 tests, 1061/1061 assertions).
    - Validated launch and manual session integration.

