<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: gameplay_milestone_audit.md
LOG_REF: 2026-06-13 03:55:00
-->

## CURRENT GOAL: Agent Layer Monolith Refactoring (Part 2 - Contract System)

- TARGET_SCOPE: Extract the monolithic contract/quest handling logic, bilateral trade action resolution, and related event/resource mapping from `agent_layer.gd` into a new delegate class `agent_contract.gd` to improve modularity, maintainability, and prepare for simulation/narrative expansion. Retain backwards-compatible forwarding wrappers in `agent_layer.gd` and ensure the GUT test suite continues to pass cleanly.

- TARGET_FILES:
  - `src/core/simulation/agent_layer.gd` — Instantiate `agent_contract.gd` and expose wrappers forwarding all contract and bilateral trade queries.
  - `src/core/simulation/agent_layer/agent_contract.gd` — Implement the extracted contract claim, pickup, delivery, accounting, demand-tag refresh, and player interface hooks.

- TRUTH_RELIANCE: `gameplay_milestone_audit.md` §3.2, §6.3

- TECHNICAL_CONSTRAINTS: "Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"

- OUT_OF_SCOPE: Rewriting/re-enabling combat or altering core CA progression rules outside the `AgentLayer` contract mapping.

- VALIDATION_PLAN:
  - Existing GUT tests (especially `test_agent_layer.gd`, `test_simulation_tick.gd`, `test_simulation_report.gd`) must pass cleanly. All forwarding method signatures must match exactly.

- MANUAL_VALIDATION: The game must boot and tick without crash or warning about invalid contract routing.

- ATOMIC_TASKS:
  - [x] TASK_1: **Create Agent Contract Delegate.** Create the delegate script `src/core/simulation/agent_layer/agent_contract.gd` subclassing `Reference`. Implement the initialization method `initialize(agent_layer_ref)`.
  - [x] TASK_2: **Extract Contract Resolution Methods.** Move `_best_runtime_contract_occurrence_id`, `_action_service_contract`, `_claim_runtime_contract_occurrence`, `_can_npc_claim_open_runtime_contract`, `_release_runtime_contract_claim`, `_clear_runtime_contract_claims_for_agent`, `_load_runtime_contract_cargo`, `_complete_runtime_contract_occurrence`, `_complete_player_contract_delivery`, `_reserve_runtime_contract_resources`, `_reserve_contract_accounting_unit`, `_release_contract_accounting_unit`, `_consume_reserved_contract_unit`, `_apply_contract_completion_sector_impact`, `_refresh_contract_demand_tags_for_sector`, `_contract_demand_tag`, `_player_can_service_contract`, and `_remove_runtime_contract_occurrence` from `agent_layer.gd` to the new delegate.
  - [x] TASK_3: **Extract Player Hook Methods.** Move `player_accept_runtime_contract`, `player_pick_up_runtime_contract`, and `player_complete_runtime_contract` to the delegate.
  - [x] TASK_4: **Wire and Forward in AgentLayer.** Update `agent_layer.gd` to preload and instantiate `agent_contract.gd` as a `contracts` component. Hook up backwards-compatible forwarding wrappers for all extracted methods.
  - [x] VERIFICATION: Run all GUT tests to verify total API compliance and zero regression in agent contract evaluation/completion. Update `SESSION-LOG.md`.
