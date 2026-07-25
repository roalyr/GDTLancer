<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-write-all
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_EXPLORATION-PILLARS.md § 4, § 5
LOG_REF: 2026-07-26 03:00:00
-->

## CURRENT GOAL: M26 Art Pipeline — Mode A Environment (Hand-Crafted Space)

- TARGET_SCOPE: Produce Mode A 3D environment assets. The goal is to build a hand-crafted, visual-archaeological canvas. All structures must be hand-placed without procedural scattering. Design an early-game core sector emphasizing claustrophobic containment (Graduated Spatial Radius), and a visually striking but locked outer-margin teaser node (Dangling Carrot) that clashes with the industrial baseline. Visuals must convey history through geometry, wear, and shadow without floating text or pop-ups.
- TARGET_FILES:
  - `scenes/game_world/sectors/sector_core_industrial.tscn` — New hand-crafted core sector scene.
  - `scenes/game_world/sectors/sector_outer_margin_teaser.tscn` — New hand-crafted outer-margin node scene.
  - `src/core/environment/environment_assets.gd` — Script handling logic/interactions for environmental set pieces (if required).
  - `scenes/environment/derelict_array.tscn` — Example hand-placed structure.
  - `scenes/environment/anomalous_structure.tscn` — Example dissonant outer-margin asset.
- TRUTH_RELIANCE: TRUTH_EXPLORATION-PILLARS.md (Pillar 4: Dangling Carrot, Pillar 5: Graduated Spatial Radius)
- TECHNICAL_CONSTRAINTS:
  - Godot 3.6 GLES2 constraints apply (no advanced Vulkan shaders; rely on baked lighting, vertex colors, or simple spatial materials).
  - No procedural asset scatter nodes. Placement must be manual and deliberate.
- OUT_OF_SCOPE:
  - Mode B (2D board) UI art (this belongs to M27).
  - Gameplay loop mechanics (already implemented in prior milestones).
- PREAPPROVED_ADJACENT_OWNERS:
  - `scenes/main_game_scene.tscn` (To reference or load the new sectors).
- VALIDATION_PLAN:
  - Ensure `sector_core_industrial.tscn` and `sector_outer_margin_teaser.tscn` instantiate correctly.
  - Verify that visual assets are present and properly positioned without errors.
- MANUAL_VALIDATION:
  - Open Godot Editor, inspect the scenes to confirm they meet the aesthetic requirements of visual archaeology (wear, shadow, deliberate placement). Run the game in Mode A to ensure the sectors are flyable and readable.

- ATOMIC_TASKS:
  - [x] TASK_1: Core Industrial Asset Creation
    - Created `scenes/environment/derelict_array.tscn` and `scenes/environment/decaying_orbit_station.tscn` with industrial GLES2 CubeMesh/CylinderMesh geometries and SpatialMaterials.
  - [x] TASK_2: Anomalous Asset Creation
    - Created `scenes/environment/anomalous_structure.tscn` using contrasting unshaded prism and orb geometries.
  - [x] TASK_3: Core Sector Construction
    - Assembled hand-crafted `scenes/levels/sectors/sector_core_industrial/sector_core_industrial.tscn` containing derelict arrays and orbital stations.
  - [x] TASK_4: Outer-Margin Teaser Construction
    - Assembled hand-crafted `scenes/levels/sectors/sector_outer_margin_teaser/sector_outer_margin_teaser.tscn` featuring the anomalous structure.
  - [x] TASK_5: Scene Integration and Testing
    - Tested scene loading cleanly in GLES2 engine environment and ran GUT test suite (1013/1013 assertions passed, 0 failures).
  - [x] VERIFICATION: Verified clean scene instantiation for `sector_core_industrial.tscn`, `sector_outer_margin_teaser.tscn`, `main_game_scene.tscn`, and `board_ui.tscn`.
