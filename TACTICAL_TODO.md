<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; MODEL-CASCADE-PROTOCOL.md § Role: Lead Systems Architect
LOG_REF: 2026-06-07 23:32:53
-->

## CURRENT GOAL: Spawning Offset by Celestial Type (jump_in_distance)

- TARGET_SCOPE: Replace the obsolete `position_in_zone` field in location templates with `jump_in_distance`. Link it to the code in `agent_system.gd` to dynamically calculate player/agent spawn and arrival offsets from origin or EntryPoint at `jump_in_distance` (+/- 10% variation). Update the python template generator, all location registry tres resources, and unit tests to mock and validate this new behavior.
- TARGET_FILES:
  - database/definitions/location_template.gd — Replace `position_in_zone` with `jump_in_distance`.
  - generate_registry.py — Update to output `jump_in_distance` (10k for stars, 5k for planets, 2k for moons).
  - database/registry/locations/*.tres — Replaced `position_in_zone` with `jump_in_distance`.
  - src/core/systems/agent_system.gd — Implement dynamic offset calculations and remove `position_in_zone` fallback.
  - src/tests/core/systems/test_persistent_agents.gd — Mock `jump_in_distance` and update spawn offset assertion.
  - src/tests/core/systems/test_agent_spawner.gd — Mock `jump_in_distance` and update spawn offset assertion.
- TRUTH_RELIANCE: ["MODEL-CASCADE-PROTOCOL.md", "TRUTH_CONTENT-CREATION-MANUAL.md"]
- TECHNICAL_CONSTRAINTS: ["Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"]
- OUT_OF_SCOPE: "Tuning other player/NPC stats, changing scene node hierarchies, altering world topologies."
- VALIDATION_PLAN: "Run Gut tests in test_persistent_agents.gd and test_agent_spawner.gd to ensure correct offset calculations and regression-free operation."
- ATOMIC_TASKS:
  - [x] TASK_1: Replace `position_in_zone` with `jump_in_distance` in `location_template.gd` and `generate_registry.py`.
  - [x] TASK_2: Update all registry `.tres` files to use `jump_in_distance` (10k for stars, 5k for planets, 2k for moons).
  - [x] TASK_3: Link `jump_in_distance` in `agent_system.gd` for dynamic player spawning and arrival offsets calculation (+/- 10% variation).
  - [x] TASK_4: Update unit tests in `test_persistent_agents.gd` and `test_agent_spawner.gd` to mock `jump_in_distance` and validate spawn offset thresholds.
  - [x] VERIFICATION: Run the full test suite and verify all tests pass cleanly.
