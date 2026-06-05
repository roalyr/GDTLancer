<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; GDD-REVISION-LEDGER.md REV_004; commodity_classification_architecture.md §6
LOG_REF: 2026-06-06 01:10:40
-->

## CURRENT GOAL: Lawful / Unlawful Market Simulation

- TARGET_SCOPE: Implement Phase 4 of the Commodity Classification architecture (Commodity Expansion). Introduce `commodity_specie`, `commodity_scrap`, and `commodity_contraband`. Define an `ILLEGAL_COMMODITIES` registry. Gate player market UI rows so contraband requires the `black_market` service and lawful goods require the `trade` service. Gate NPC market trade so illicit agents (e.g., pirates) can trade contraband at black markets, while lawful agents ignore contraband.
- TARGET_FILES:
  - database/registry/assets/commodities/commodity_specie.tres — New currency commodity.
  - database/registry/assets/commodities/commodity_scrap.tres — New raw commodity.
  - database/registry/assets/commodities/commodity_contraband.tres — New manufactured illegal commodity.
  - src/autoload/Constants.gd — Update classification registry and add ILLEGAL_COMMODITIES list.
  - src/core/ui/station_menu/station_menu.gd — Update `_update_market_ui` to filter rows by service (`trade` vs `black_market`) and legality.
  - src/core/simulation/agent_layer.gd — Update `_attempt_npc_market_buy` and `_attempt_npc_market_sell` to respect commodity legality against the agent's illicit status and the station's services.
  - src/tests/core/simulation/test_agent_layer.gd — Test NPC legality trade gating.
  - src/tests/core/ui/test_station_menu.gd — Test UI legality gating.
- TRUTH_RELIANCE: ["GDD-REVISION-LEDGER.md REV_004", "commodity_classification_architecture.md §6"]
- TECHNICAL_CONSTRAINTS: ["Platform (primary): Godot3 (3.6 stable)", "Graphics: GLES2", "Forbidden GDScript syntax in this repo: `@export`, `@onready`, and `await`."]
- OUT_OF_SCOPE: Faction reputation changes from trading contraband, contraband cargo scanning, and topology changes.
- PREAPPROVED_ADJACENT_OWNERS:
  - SESSION-LOG.md — required state log.
- VALIDATION_PLAN: Run `godot -s addons/gut/gut_cmdln.gd` to confirm all assertions pass cleanly. Add focused assertions for the legality gating.
- MANUAL_VALIDATION: None required beyond tests.
- ATOMIC_TASKS:
  - [x] TASK_1: Create the three new commodity `.tres` files: `commodity_specie` (base_value: 500), `commodity_scrap` (base_value: 5), and `commodity_contraband` (base_value: 150) based on `commodity_default.tres`.
  - [x] TASK_2: Update `Constants.gd`. Add the new commodities to `COMMODITY_CLASSIFICATION` (specie = CURRENCY, scrap = RAW, contraband = MANUFACTURED). Add a new `const ILLEGAL_COMMODITIES: Array = ["commodity_contraband"]`.
  - [x] TASK_3: Update `station_menu.gd`. In `_update_market_ui`, filter the commodity list. If `comm_id` is in `ILLEGAL_COMMODITIES`, it should only be shown if `has_black` is true. If `comm_id` is not in `ILLEGAL_COMMODITIES`, it should only be shown if `has_lawful` is true. 
  - [x] TASK_4: Update `agent_layer.gd`. In `_attempt_npc_market_buy` and `_attempt_npc_market_sell`, determine if the agent is illicit (e.g., `agent_tags` contains "ILLICIT_CARGO" or role is "pirate" or `legality_stance` < 0). Only illicit agents at stations with `black_market` can trade illegal commodities. Lawful agents at stations with `trade` can trade lawful commodities.
  - [x] TASK_5: Update `test_agent_layer.gd` and `test_station_menu.gd` to assert that lawful/unlawful goods are properly gated by services and agent legality.
  - [x] VERIFICATION: Execute the GUT test suite and verify that all tests pass.
