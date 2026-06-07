<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; GDD-REVISION-LEDGER.md REV_005
LOG_REF: 2026-06-07 16:30:00
-->

## CURRENT GOAL: Virtual Docking & Topology Schema Consolidation

- TARGET_SCOPE: Consolidate sector classification schemas and implement "virtual docking", allowing the player to dock to the current sector from anywhere within it. Remove legacy `location_type` fields from templates and scrub outdated procedural station and jumpgate injection from `sector_loader.gd`. Ensure simulation relies solely on `sector_type` set to `"star"`.
- TARGET_FILES:
  - database/definitions/location_template.gd — Remove `location_type`, keep `sector_type`.
  - database/registry/locations/*.tres — Update all sector templates to remove `location_type` and set `sector_type` to `"star"`.
  - src/core/systems/sector_loader.gd — Remove `_inject_generated_station` and `_inject_jump_points` logic.
  - src/core/simulation/agent_layer.gd — Adapt NPC dock logic to virtual docking (no need to locate a station node).
  - src/modules/piloting/player_controller_ship.gd — Adapt player proximity docking rules to allow docking anywhere in the sector.
  - src/core/ui/main_hud/main_hud.gd — Adapt HUD docking rules/buttons to support virtual docking.
  - (Any relevant tests to maintain GUT suite parity).
- TRUTH_RELIANCE: ["GDD-REVISION-LEDGER.md REV_005", "universe_topology_architecture.md"]
- TECHNICAL_CONSTRAINTS: ["Keep GUT authoritative for stable contracts", "Do not introduce structural code changes for hierarchy yet."]
- ATOMIC_TASKS:
  - [x] TASK_1: Update `location_template.gd` and all sector `.tres` templates. Remove `location_type` entirely and ensure `sector_type` defaults and is set to `"star"` across all registry entries. Adjust simulation layers (`agent_layer.gd`, `world_layer.gd`, etc) that relied on `location_type` to use `sector_type`.
  - [x] TASK_2: Clean up `sector_loader.gd` by completely removing the logic for injecting JumpPoints and procedural dockable stations.
  - [x] TASK_3: Update `player_controller_ship.gd` and `main_hud.gd` to implement "virtual docking": pressing dock connects the player to the current sector's market/services from any location in the sector without requiring a physical station target or proximity (preserve targeted jumping to other sectors).
  - [x] TASK_4: Update `agent_layer.gd` to ensure NPCs can execute dock-market trade or contracts from anywhere in the sector, bypassing previous physical station distance/location checks.
  - [x] VERIFICATION: Ensure all unit tests pass and that both the player and NPCs can successfully dock and interact with the sector from any coordinate.
