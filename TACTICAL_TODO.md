<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Compatibility Constraints; TRUTH_PROJECT.md § Automated Testing Boundary; TRUTH_PROJECT.md § Workflow And Scope Boundary; commodity_classification_architecture.md §6
LOG_REF: 2026-06-05 21:00:00
-->

## CURRENT GOAL: NPC Category-Aware Trade & Contract Commodity Resolution

- TARGET_SCOPE: Implement Phase 2 of the Commodity Classification architecture. Add a helper to `Constants.gd` to fetch random commodities by category. Update `contract_generation_system.gd` to assign a specific `commodity_id` to generated contract occurrences. Update `agent_layer.gd` so NPC dock-trade remembers what specific commodity was bought by storing it in `agent["cargo_commodity_id"]`, and forces the agent to sell that exact commodity later. If an agent with a generic qualitative `LOADED` tag (no specific commodity) tries to sell, assign them a random or fallback commodity to sell. Update contract pickup to assign the contract's `commodity_id` to the agent.
- TARGET_FILES:
  - src/autoload/Constants.gd — Add helper functions for category-to-commodity mapping.
  - src/core/simulation/contract_generation_system.gd — Assign `commodity_id` to new occurrences.
  - src/core/simulation/agent_layer.gd — Update buy/sell and contract pickup/dropoff logic.
  - src/tests/core/simulation/test_contract_generation_system.gd — Add test for `commodity_id` resolution.
  - src/tests/core/simulation/test_agent_layer.gd — Update and add tests for quantitative cargo memory.
- TRUTH_RELIANCE: ["commodity_classification_architecture.md §6", "TRUTH_PROJECT.md § Project Stack And Context", "TRUTH_PROJECT.md § Compatibility Constraints", "TRUTH_PROJECT.md § Automated Testing Boundary"]
- TECHNICAL_CONSTRAINTS: ["Platform (primary): Godot3 (3.6 stable)", "Graphics: GLES2", "Forbidden GDScript syntax in this repo: `@export`, `@onready`, and `await`."]
- OUT_OF_SCOPE: Dynamic pricing from supply/demand (Phase 3), Tag-Aware Restock Baselines (Phase 3), Player UI inventory updates (Player currently uses a different inventory system in `station_menu.gd`).
- PREAPPROVED_ADJACENT_OWNERS:
  - SESSION-LOG.md — required state log.
- VALIDATION_PLAN: Run `godot -s addons/gut/gut_cmdln.gd` to confirm all assertions pass cleanly. Add focused unit assertions.
- MANUAL_VALIDATION: none required for Phase 2 beyond tests.
- ATOMIC_TASKS:
  - [x] TASK_1: Update Constants.gd. Add a helper function `get_random_commodity_for_category(category: String, rng: RandomNumberGenerator) -> String` that returns a random commodity ID from `COMMODITY_CLASSIFICATION` matching the given category. If none found, return empty string.
  - [x] TASK_2: Update contract_generation_system.gd. In `_build_occurrence()`, call the new helper using `category` and `_rng` to assign `"commodity_id"` to the occurrence. If it returns empty string, default to `"commodity_default"`.
  - [x] TASK_3: Update agent_layer.gd. In `_attempt_npc_market_buy()`, select a commodity to buy (e.g. randomly from those with quantity > 0) instead of alphabetically. Store the selected ID in `agent["cargo_commodity_id"]`. In `_attempt_npc_market_sell()`, check if `agent` has `"cargo_commodity_id"`. If so, sell that specific commodity. If not (generic qualitative load), pick a random commodity from `COMMODITY_CLASSIFICATION` (excluding `commodity_default`) to sell. Clear `agent["cargo_commodity_id"]` after selling.
  - [x] TASK_4: Update agent_layer.gd contract handling. In `_load_runtime_contract_cargo()`, set `agent["cargo_commodity_id"] = occurrence.get("commodity_id", "")`. In `_complete_runtime_contract_occurrence()`, clear `agent["cargo_commodity_id"]` and remove it from the dictionary.
  - [x] TASK_5: Update unit tests in `test_contract_generation_system.gd` and `test_agent_layer.gd` to assert the new `commodity_id` behavior and quantitative cargo memory.
  - [x] VERIFICATION: Execute the GUT test suite and verify that all tests pass. Output the command line and verify the results.
