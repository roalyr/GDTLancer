<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: STRATEGICAL-TODO.md §3, §8; TRUTH_SIMULATION-GRAPH.md §6
LOG_REF: 2026-06-20 20:40:00
-->

## CURRENT GOAL: Manual Space Graph & In-Sector POI System

- TARGET_SCOPE: Implement the Manual Space Graph doctrine and the In-Sector POI (Point of Interest) spawning and discovery system. Ensure the inter-sector connection graph is strictly manual and static after initialization. Scaffold in-sector POIs (derelicts, deposits, anomalies, outposts) as local simulation objects in GameState. Modify agent exploration to discover and register in-sector POIs instead of dynamically sprouting new sectors on the global graph.

- TARGET_FILES:
  - `src/autoload/GameState.gd` — Add `in_sector_pois` state dictionary and update `reset_state()`.
  - `src/core/simulation/world_layer.gd` — Generate initial POIs deterministically per sector on world initialize.
  - `src/core/simulation/agent_layer/agent_explorer.gd` — Replace dynamic graph sprouting in `_try_exploration` with in-sector POI discovery.
  - `src/tests/core/simulation/test_world_layer.gd` — Test initial POI generation.
  - `src/tests/core/simulation/test_agent_layer.gd` — Update exploration tests to verify POI discovery instead of sprouting.

- TRUTH_RELIANCE:
  - `STRATEGICAL-TODO.md` §3, §8
  - `TRUTH_GAME-LOOP-VISION.md` §1.3

- TECHNICAL_CONSTRAINTS:
  - Forbidden GDScript syntax: `@export`, `@onready`, `await`.
  - Godot 3.6 stable compatibility.
  - Keep GUT authoritative for state shape and signatures.

- ATOMIC_TASKS:
  - [x] TASK_1: **GameState POI Tracking.** In `GameState.gd`, add `in_sector_pois` (Dictionary) to track in-sector POIs (keyed by `sector_id`, mapping to an Array of POI Dictionaries). Update `reset_state()` to clear this dictionary.
  - [x] TASK_2: **Deterministic Initial POI Generation.** In `world_layer.gd`, inside `initialize_world()`, populate `GameState.in_sector_pois` for each sector. Generate 1 to 4 POIs per sector using a RandomNumberGenerator seeded with the world seed + sector ID.
    - POI dictionary format: `{ "id": String, "display_name": String, "poi_type": String, "sector_id": String, "position_in_sector": Vector3, "metadata": Dictionary }`.
    - Randomize `poi_type` among: `"derelict"`, `"deposit"`, `"anomaly"`, `"outpost"`.
    - Randomize `position_in_sector` within a Vector3 range (e.g. coordinates between -4000 and 4000).
  - [x] TASK_3: **Explorer POI Discovery.** Modify `agent_explorer.gd` to change exploration behavior. In `_try_exploration`, instead of generating and appending a new sector to `GameState.world_topology` (sprouting), the explorer should attempt to discover/spawn a new in-sector POI in the current sector (up to a max of 6 POIs per sector).
    - If successful, append the new POI to the sector's list in `GameState.in_sector_pois`.
    - Append an entry to `GameState.discovery_log` and log the event.
  - [x] TASK_4: **Unit Tests Update.**
    - In `test_world_layer.gd`, add a test verifying that `initialize_world` populates deterministic POIs for each sector.
    - In `test_agent_layer.gd`, update `test_try_exploration_registers_runtime_location_template` (or replace/refactor it) to assert that successful exploration generates a new in-sector POI, logs it correctly in `GameState.discovery_log`, and does not add new sectors to `GameState.world_topology`.
  - [x] VERIFICATION: Run the full headless GUT suite to verify all tests pass with zero regressions.
