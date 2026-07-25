<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_EXPLORATION-PILLARS.md § 3, § 9
LOG_REF: 2026-07-26 03:30:00
-->

## CURRENT GOAL: M28 Asset Card Library (Lateral Progression Corpus)

- TARGET_SCOPE: Define and implement the base set of Asset Cards as lateral expanders. Asset Cards expand mechanical verbs (traversal, anchoring, survival, interaction) rather than numerical stats. Modification cards (Transhumanism, Pillar 9) must carry explicit trade-off tags. Early-game cards constrain operational radius; late-game cards expand the Graduated Spatial Radius.
- TARGET_FILES:
  - `src/core/cards/asset_card.gd` — AssetCard resource definition (ensure trade_offs support and validation helpers).
  - `src/core/systems/asset_system.gd` — AssetSystem registry/loader for asset cards.
  - `database/registry/cards/assets/` — Directory containing `.tres` card resources.
  - `src/tests/core/systems/test_asset_card_corpus.gd` — Unit tests for the asset card corpus and trade-off validation.
- TRUTH_RELIANCE: TRUTH_EXPLORATION-PILLARS.md (§3: Lateral Expansion, §9: Transhumanism Trade-offs)
- TECHNICAL_CONSTRAINTS:
  - No pure-bonus modification cards. All modification cards MUST have explicit trade-off entries.
  - Cards are stored as `.tres` resources.
  - Must pass 100% GUT tests.
- OUT_OF_SCOPE:
  - 3D Model asset pipelines (M26 complete).
  - Full game session integration (M29).
- ATOMIC_TASKS:
  - [x] TASK_1: Update `AssetCard` Resource Model
    - Enhanced `asset_card.gd` with constructor support, `is_modification_card()`, and `validate_trade_offs()`.
  - [x] TASK_2: Implement `AssetSystem` Registry
    - Enhanced `asset_system.gd` to index, query (by verb/tag), load, and validate asset cards.
  - [x] TASK_3: Build Asset Card Corpus (.tres resources)
    - Built 12 `.tres` card resources under `database/registry/cards/assets/` covering Traversal, Anchoring, Survival, Interaction, and Transhuman Modifications (with explicit Pillar 9 trade-offs).
  - [x] TASK_4: Unit Testing
    - Created `src/tests/core/systems/test_asset_card_corpus.gd` and confirmed 100% test pass rate (272/272 tests, 1051/1051 assertions).
