<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Compatibility Constraints; TRUTH_PROJECT.md § Automated Testing Boundary; TRUTH_PROJECT.md § Workflow And Scope Boundary; commodity_classification_architecture.md §3; commodity_classification_architecture.md §4
LOG_REF: 2026-06-05 01:15:33
-->

## CURRENT GOAL: Commodity Classification Registry & Tag-Governed Market Seeding

- TARGET_SCOPE: Establish the Commodity Classification Registry as the authoritative one-way bridge between qualitative tag simulation and quantitative station markets. Replace the hardcoded procedural station market seeding with a tag-governed projection that maps commodities to categories, looks up sector economy tags, and derives quantity and buy/sell prices dynamically based on CommodityTemplate base_value, level multipliers, and a standard sell price fraction. Exclude the default template fallback commodity from registry and seeding. Add focused unit tests verifying registry completeness, level resolution helper correctness, price/quantity bounds, and sell price derivation.
- TARGET_FILES:
  - src/autoload/Constants.gd — holds the COMMODITY_CLASSIFICATION mapping, level parameters dictionary, sell price fraction, and static helper get_economy_level_for_category.
  - src/core/simulation/agent_layer.gd — updates _generate_procedural_station_for_sector to dynamically seed the station market inventory based on sector economy tags and classification rules.
  - src/tests/core/simulation/test_agent_layer.gd — provides comprehensive test coverage for classification, helper parsing, and tag-aware seeding price/quantity ranges.
- TRUTH_RELIANCE: ["commodity_classification_architecture.md §3", "commodity_classification_architecture.md §4", "TRUTH_PROJECT.md § Project Stack And Context", "TRUTH_PROJECT.md § Compatibility Constraints", "TRUTH_PROJECT.md § Automated Testing Boundary", "TRUTH_PROJECT.md § Workflow And Scope Boundary"]
- TECHNICAL_CONSTRAINTS: ["Platform (primary): Godot3 (3.6 stable)", "Graphics: GLES2", "Forbidden GDScript syntax in this repo: `@export`, `@onready`, and `await`.", "The procedural seeding must retrieve the base_value from TemplateDatabase.assets_commodities[commodity_id] resource.", "The seeded market dictionary structure must remain exactly as {commodity_id: {buy_price: int, sell_price: int, quantity: int}}.", "commodity_default must be excluded from classification and seeding.", "If the required change widens behavior outside TARGET_SCOPE or requires non-narrow owners outside TARGET_FILES, return control to the Architect instead of improvising scope."]
- OUT_OF_SCOPE: NPC trade category intelligence, contract-cargo item resolution, dynamic pricing, station restock baseline alignment, modifications to authored station .tres files on disk (restocking applies to live runtime state, and authored station inventories remain untouched).
- PREAPPROVED_ADJACENT_OWNERS:
  - SESSION-LOG.md — required state log.
  - database/definitions/asset_commodity_template.gd — read-only template schema.
  - database/registry/assets/commodities/ — read-only templates.
  - database/definitions/location_template.gd — read-only locations schema.
- VALIDATION_PLAN: Run `godot -s addons/gut/gut_cmdln.gd` to confirm all assertions pass cleanly. Add focused unit assertions in `test_agent_layer.gd`.
- MANUAL_VALIDATION: none required for Phase 1 beyond tests.
- ATOMIC_TASKS:
  - [x] TASK_1: Update Constants.gd. Add COMMODITY_CLASSIFICATION mapping commodity IDs to their respective categories (RAW, MANUFACTURED, CURRENCY). Add ECONOMY_LEVEL_PARAMS dictionary defining min_quantity, max_quantity, and price_multiplier for POOR, ADEQUATE, and RICH. Add COMMODITY_SELL_PRICE_FRACTION = 0.8. Add helper get_economy_level_for_category(sector_tags: Array, category: String) -> String that scans sector_tags for "category_LEVEL" and returns the matched LEVEL string (POOR/ADEQUATE/RICH) or "ADEQUATE" as fallback. Required signature: func get_economy_level_for_category(sector_tags: Array, category: String) -> String.
  - [x] TASK_2: Update agent_layer.gd:_generate_procedural_station_for_sector. Replace the hardcoded seeded_market dictionary with a dynamic generation loop. For each commodity_id in Constants.COMMODITY_CLASSIFICATION: look up its category; retrieve the sector's level for that category; look up the min/max quantity and price multiplier for that level; load the CommodityTemplate from TemplateDatabase.assets_commodities[commodity_id]; generate quantity as a random integer within the level's range using market_rng; calculate buy_price = int(round(base_value * multiplier)); calculate sell_price = int(round(buy_price * Constants.COMMODITY_SELL_PRICE_FRACTION)). Ensure commodity_default is explicitly skipped. Guard against missing templates or invalid keys.
  - [x] TASK_3: Add unit tests in test_agent_layer.gd. Verify: (a) COMMODITY_CLASSIFICATION has exactly the 5 tradeable commodities and excludes commodity_default, (b) get_economy_level_for_category parses sector tags correctly for POOR, ADEQUATE, and RICH, (c) _generate_procedural_station_for_sector generates quantities and prices within the correct bounds for different sector tags (e.g. RAW_RICH, MANUFACTURED_POOR, CURRENCY_ADEQUATE), (d) sell prices are calculated correctly using the sell price fraction.
  - [x] VERIFICATION: Execute the GUT test suite and verify that all tests pass. Output the command line and verify the results.
