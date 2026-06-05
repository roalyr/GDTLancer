<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Compatibility Constraints; TRUTH_PROJECT.md § Automated Testing Boundary; TRUTH_PROJECT.md § Workflow And Scope Boundary; commodity_classification_architecture.md §6
LOG_REF: 2026-06-06 01:04:11
-->

## CURRENT GOAL: Dynamic Market Pricing & Tag-Aware Restock Baselines (Phase 3)

- TARGET_SCOPE: Implement Phase 3 of the Commodity Classification architecture. Replace the flat `MARKET_RESTOCK_MAX_QUANTITY` with a dynamic, tag-aware restock baseline derived from the sector's economy tag (`POOR`/`ADEQUATE`/`RICH` ranges in `Constants.ECONOMY_LEVEL_PARAMS`). Update market restocking to pull quantities toward this baseline. Implement dynamic pricing so that as stock drops below the baseline, prices increase, and as stock exceeds the baseline, prices decrease. 
- TARGET_FILES:
  - src/autoload/Constants.gd — Add dynamic pricing tuning constants and baseline helper.
  - src/core/simulation/agent_layer.gd — Update `_process_market_restock` to use tag-aware baselines and integrate dynamic pricing into buy/sell logic.
  - src/tests/core/simulation/test_agent_layer.gd — Add assertions for dynamic pricing and tag-aware restock baselines.
- TRUTH_RELIANCE: ["commodity_classification_architecture.md §6", "TRUTH_PROJECT.md § Project Stack And Context", "TRUTH_PROJECT.md § Compatibility Constraints", "TRUTH_PROJECT.md § Automated Testing Boundary"]
- TECHNICAL_CONSTRAINTS: ["Platform (primary): Godot3 (3.6 stable)", "Graphics: GLES2", "Forbidden GDScript syntax in this repo: `@export`, `@onready`, and `await`."]
- OUT_OF_SCOPE: Lawful / Unlawful Market Simulation, Faction trade gating, new commodities (Phase 4).
- PREAPPROVED_ADJACENT_OWNERS:
  - SESSION-LOG.md — required state log.
- VALIDATION_PLAN: Run `godot -s addons/gut/gut_cmdln.gd` to confirm all assertions pass cleanly. Add focused unit assertions.
- MANUAL_VALIDATION: none required for Phase 3 beyond tests.
- ATOMIC_TASKS:
  - [x] TASK_1: Update Constants.gd. Add a dynamic pricing elasticity constant (e.g., `DYNAMIC_PRICE_ELASTICITY = 0.5`) and define a helper function `get_tag_aware_baseline_quantity(category: String, level: String) -> int` to return the median of the quantity range for a given economy level.
  - [x] TASK_2: Update agent_layer.gd restocking logic. In `_process_market_restock`, resolve the sector's economy tags to determine the baseline quantity for each commodity in the station's inventory. Restock up to the baseline quantity instead of the flat `MARKET_RESTOCK_MAX_QUANTITY`.
  - [x] TASK_3: Update agent_layer.gd pricing logic. Whenever calculating a buy or sell price for a commodity transaction, apply a dynamic pricing modifier based on the ratio of current quantity to the tag-aware baseline quantity. Update player and NPC transaction functions to use this dynamically calculated price instead of the stored static price.
  - [x] TASK_4: Update test_agent_layer.gd to assert that restocking respects tag-aware baselines and that prices scale dynamically based on stock levels.
  - [x] VERIFICATION: Execute the GUT test suite and verify that all tests pass. Output the command line and verify the results.
