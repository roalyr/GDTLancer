<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 2
LOG_REF: 2026-08-17 03:59:00
-->

## CURRENT GOAL: M30 Card System Refactor (Collection Model)

- TARGET_SCOPE: Replace the legacy 3d6 action loop with a card-based resolution system throughout Mode B. Implement the Collection model (scrollable inventory panel), enforce card types (Module, Field, Possession, Consumable), implement Junk cards as universal crafting fuel, and tag-pairing crafting. Add asset creation to the milestone.
- TARGET_FILES:
  - `src/core/systems/board_action_loop.gd` — Refactor to remove 3d6, use card-based resolution.
  - `src/core/systems/action_check_engine.gd` — Refactor for card resolution without dice.
  - `src/core/cards/asset_card.gd` — Add card type definitions (Module, Field, Possession, Consumable) and junk state.
  - `src/core/systems/crafting_system.gd` — New system for tag-pairing crafting and junk generation.
  - `src/core/ui/board/components/card_collection_panel.gd` / `.tscn` — New UI panel for the scrollable inventory.
  - `src/core/ui/board/components/dice_roll_feedback.gd` — Deprecate or repurpose for card resolution feedback.
- TRUTH_RELIANCE: TRUTH_GAME-LOOP-VISION.md (§2 The Card System)
- TECHNICAL_CONSTRAINTS:
  - No 3d6 rolls occur anywhere in Mode B.
  - Only target specific GUT tests if you need them. The full GUT suite will be run manually by the user. Do not run the full suite automatically.
  - When running terminal commands, ensure that ghost processes of Godot are not hanging around (e.g., kill orphaned instances after testing).
- ATOMIC_TASKS:
  - [x] TASK_1: Update Card Data Model. Modify `asset_card.gd` to include explicit Card Types (Module, Field, Possession, Consumable) and a Junk state/flag. Ensure modifiers are allowed.
  - [x] TASK_2: Refactor Action Resolution. Rip out 3d6 logic from `action_check_engine.gd` and `board_action_loop.gd`. Implement card-driven resolution. Update feedback UI to remove dice.
  - [x] TASK_3: Create Collection UI. Build `card_collection_panel.tscn` to display the player's card collection organized by type.
  - [x] TASK_4: Implement Crafting System. Create `crafting_system.gd` to handle tag-pairing crafting (failed attempts yield Junk; Junk acts as a universal fuel/cost).
  - [ ] TASK_5: Asset Creation. Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog (stubs or actual files in assets directory).
  - [ ] VERIFICATION: Write or update specific GUT tests for the new action engine and crafting system, ensuring they pass with no ghost processes.
