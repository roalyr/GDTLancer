<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; MODEL-CASCADE-PROTOCOL.md § Role: Lead Systems Architect
LOG_REF: 2026-06-09 15:01:36
-->

## CURRENT GOAL: Cob System Topology Consolidation

- TARGET_SCOPE: Convert the nested `sector_system_cob` into a flat 2-tier hierarchy (Star -> Planet) to align with REV_005 (Hierarchical Universe Topology). Separate `Planet Cob a` and its child station out of the root `sector_system_cob.tscn` into a new `sector_planet_cob_a.tscn` utilizing the standard sector node structure (AgentContainer, StarsphereSlot, SceneAssets, EntryPoint). Create the corresponding `sector_planet_cob_a.tres` registry template and wire the `connections` array bilaterally between the star and the planet. Update `sector_system_cob.tres` to correctly point to its scene.
- TARGET_FILES:
  - database/registry/locations/sector_system_cob.tres — Add planet to connections, populate `sector_scene_path`.
  - database/registry/locations/sector_planet_cob_a.tres — New definition for the planet sector.
  - scenes/levels/sectors/sector_system_cob/sector_system_cob.tscn — Remove nested planet and station.
  - scenes/levels/sectors/sector_system_cob/sector_planet_cob_a.tscn — New standard sector scene for the planet and station.
- TRUTH_RELIANCE: GDD-REVISION-LEDGER.md (REV_005), TRUTH_CONTENT-CREATION-MANUAL.md §3.4
- TECHNICAL_CONSTRAINTS: "Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"
- ATOMIC_TASKS:
  - [x] TASK_1: Create `sector_planet_cob_a.tres` in `database/registry/locations/` (inheriting from `location_template.gd`). Set its sector_type to 'planet', set its sector_scene_path to `res://scenes/levels/sectors/sector_system_cob/sector_planet_cob_a.tscn`, set jump_in_distance to 5000.0, and add `sector_system_cob` to its connections. 
  - [x] TASK_2: Update `sector_system_cob.tres` to add `sector_planet_cob_a` to its connections and set its `sector_scene_path` to `res://scenes/levels/sectors/sector_system_cob/sector_system_cob.tscn`.
  - [x] TASK_3: Create `sector_planet_cob_a.tscn` in `scenes/levels/sectors/sector_system_cob/` using the standard sector structure (`AgentContainer`, `StarsphereSlot` with global nebulas, `SceneAssets`, `EntryPoint`).
  - [x] TASK_4: Move `Planet Cob a` and `Station Cob a1` from `sector_system_cob.tscn` into `sector_planet_cob_a.tscn` (under `SceneAssets`). Retain only `Star Cob` and standard structure in `sector_system_cob.tscn`.
  - [x] VERIFICATION: Run headless Godot to ensure scenes load without errors, and run relevant sector unit tests if any exist to verify connections and scene structure.
