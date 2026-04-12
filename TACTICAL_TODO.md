## CURRENT GOAL: Global Map Debug Module + Sector Scene Renaming + Position Scatter

### EXECUTIVE SUMMARY

The previous milestone (Multi-Sector World) is verified and complete: 30 scripts,
167/167 GUT tests, 553/553 asserts. Five handcrafted sectors with JumpPoint travel,
nebula parallax, and sim-driven NPC population are functional. The user has
manually verified gameplay.

Three issues remain before the next gameplay milestone:

1. **Sector scene naming inconsistency.** Sector root scenes are named
   `sector_station_<name>.tscn` but their folders are `sector_<name>/`. This
   violates the modder convention established in TRUTH_CONTENT-CREATION-MANUAL.md
   (§3.4, §2). Rename to `sector_<name>.tscn` for folder/scene parity.

2. **Sector global positions are too clustered.** All five sectors sit within a
   ~5,000 unit cube (44500–49500 range). The global nebulas span 130K–451K from
   origin. At this proximity, nebula parallax between sectors is imperceptible.
   Scatter sectors across a ~200K diameter to produce visible starsphere shift
   when jumping between sectors.

3. **No global map visualization.** The sim_debug_panel (F3) shows per-sector
   text data but there is no spatial visualization of the universe. Designers
   and modders cannot verify sector placement, connection topology, or nebula
   coverage without manually reading coordinate values. A debug map sub-window
   is needed that renders the full galactic view: nebula representations, sector
   markers, connection lines, sector labels, and interactive camera controls.

**Why now:** Sector travel works, but the spatial relationships between sectors
are invisible. Before adding per-sector content (procedural generation, trade
routes, faction territory visuals), designers need a tool to see the universe
at galactic scale. The position scatter is needed to make nebula parallax
perceptible — a prerequisite for the starsphere to function as a navigation cue.
The renaming is a hygiene task that must happen before more sectors are added.

**Scope boundary:** This milestone does NOT include: in-game map editor, galaxy
generation algorithms, procedural sector content, UI-integrated (non-debug) map
panel, or modifications to simulation layers.

### PREVIOUS MILESTONE STATUS: Multi-Sector World — Complete ✅

All 9 TASKs + 2 automated VERIFICATIONs passed. 30 scripts, 167/167 tests,
553/553 asserts. SectorLoader, JumpPoints, nebula offset, agent sector filtering
all verified. Folder rename `station_*` → `sector_*` completed in prior session.

---

- TRUTH_RELIANCE:
  - `TRUTH_PROJECT.md` — Godot 3.6 / GLES2
  - `TRUTH_CONSTRAINTS.md` §1 — No @export, @onready, await (Godot 3 syntax)
  - `TRUTH_CONTENT-CREATION-MANUAL.md` §2 (Directory Structure), §3.4 (Adding a Location), §6 (Testing)
  - `TRUTH_SIMULATION-GRAPH.md` §2.1 (Sector Node topology), §5 (Information Graph — sector heatmap)

- TECHNICAL_CONSTRAINTS:
  - Godot 3.6 stable, GLES2 renderer
  - No `@export`, `@onready`, `await` — use `export var`, `onready var`, `yield`
  - Viewport z_far hard limit: 1,000,000 units (Godot 3 standard)
  - All nebula geometry must remain within 1M units from any sector viewpoint
  - Sector `global_position` scatter must stay within ~250K from galactic center
    so nebula parallax offset (REFERENCE_ORIGIN − global_position) keeps all
    nebula spheroids inside the 1M z_far
  - Map camera z_far ≤ 1,000,000 — all map content within that sphere
  - No new autoloads — debug map is a scene node (like SimDebugPanel)
  - TemplateDatabase auto-scans `database/registry/locations/` — no code changes
    needed for .tres field updates
  - GUT test framework: `extends GutTest`, `before_each`/`after_each` pattern

- TARGET_FILES:

  **PHASE 1 — SECTOR SCENE RENAMING:**
  - `scenes/levels/sectors/sector_alpha/sector_station_alpha.tscn` — RENAME → `sector_alpha.tscn`
  - `scenes/levels/sectors/sector_beta/sector_station_beta.tscn` — RENAME → `sector_beta.tscn`
  - `scenes/levels/sectors/sector_gamma/sector_station_gamma.tscn` — RENAME → `sector_gamma.tscn`
  - `scenes/levels/sectors/sector_delta/sector_station_delta.tscn` — RENAME → `sector_delta.tscn`
  - `scenes/levels/sectors/sector_epsilon/sector_station_epsilon.tscn` — RENAME → `sector_epsilon.tscn`
  - `database/registry/locations/station_alpha.tres` — UPDATE `sector_scene_path`
  - `database/registry/locations/station_beta.tres` — UPDATE `sector_scene_path`
  - `database/registry/locations/station_gamma.tres` — UPDATE `sector_scene_path`
  - `database/registry/locations/station_delta.tres` — UPDATE `sector_scene_path`
  - `database/registry/locations/station_epsilon.tres` — UPDATE `sector_scene_path`

  **PHASE 2 — SECTOR POSITION SCATTER:**
  - `database/registry/locations/station_alpha.tres` — UPDATE `global_position`
  - `database/registry/locations/station_beta.tres` — UPDATE `global_position`
  - `database/registry/locations/station_gamma.tres` — UPDATE `global_position`
  - `database/registry/locations/station_delta.tres` — UPDATE `global_position`
  - `database/registry/locations/station_epsilon.tres` — UPDATE `global_position`
  - `src/autoload/Constants.gd` — UPDATE `REFERENCE_ORIGIN`

  **PHASE 3 — DEBUG MAP MODULE:**
  - `src/core/ui/debug_map_panel/debug_map_panel.gd` — CREATE (~400 lines)
  - `src/core/ui/debug_map_panel/debug_map_panel.tscn` — CREATE
  - `scenes/levels/game_world/main_game_scene.tscn` — UPDATE (add DebugMapPanel node)

  **PHASE 4 — UNIT TESTS:**
  - `src/tests/core/ui/test_debug_map_panel.gd` — CREATE

- ATOMIC_TASKS:

  - [ ] TASK_1: Rename sector scene files from `sector_station_<name>.tscn` to `sector_<name>.tscn`
    - Rename 5 `.tscn` files in `scenes/levels/sectors/*/`
    - Update `sector_scene_path` in all 5 `database/registry/locations/station_*.tres`
    - Verify: `grep -r "sector_station_" src/ database/ scenes/` returns zero hits
    - Signatures: file rename (shell `mv`), .tres text edit

  - [ ] TASK_2: Scatter sector `global_position` values across galactic space
    - New coordinates (moderate scatter, ~200K diameter, centered near origin):
      - station_alpha: `Vector3(0, 0, 0)` — galactic reference anchor
      - station_beta: `Vector3(85000, 12000, 65000)` — ~108K from alpha
      - station_delta: `Vector3(35000, 8000, -55000)` — ~66K from alpha (hub junction)
      - station_gamma: `Vector3(-70000, -18000, 45000)` — ~85K from alpha (frontier)
      - station_epsilon: `Vector3(-95000, -5000, -35000)` — ~102K from alpha (remote)
    - Update `global_position` field in all 5 `.tres` files
    - Update `Constants.REFERENCE_ORIGIN` to `Vector3(0, 0, 0)` (Station Alpha is new origin)
    - Constraint: farthest nebula is spheroid1 at ~451K from origin; farthest sector
      offset is ~102K; worst-case nebula distance from any sector = ~553K < 1M z_far ✓
    - Signatures: .tres text edit, Constants.gd edit

  - [ ] TASK_3: Create `debug_map_panel.tscn` — scene layout
    - Root: `CanvasLayer` (layer 101, above SimDebugPanel at 100)
    - Child: `Panel` (anchored center, ~800×600, semi-transparent background)
    - Children of Panel:
      - `HBoxContainer` (top bar): title Label + navigation buttons
        (Rotate L/R/U/D, Zoom In/Out, Pan L/R/U/D, Reset) + Close button
      - `ViewportContainer` (fill remaining space, stretch=true)
        - `Viewport` (size 800×600, render_target_update_mode=ALWAYS, transparent_bg=true)
          - `MapCamera` (Camera, perspective, fov=60, z_near=1, z_far=1000000)
          - `MapContent` (Spatial) — container for all map geometry
    - Signatures: .tscn scene creation

  - [ ] TASK_4: Create `debug_map_panel.gd` — core logic
    - Toggle: F4 key (no collision with F3 for SimDebugPanel)
    - On show: call `_populate_map()` to build/refresh all map geometry
    - Camera controls (all proportional to current zoom distance):
      - Orbit rotation: buttons or mouse drag on viewport
      - Zoom: buttons or scroll wheel (clamp between 1K and 800K distance)
      - Pan: buttons shift camera pivot point
      - Reset: returns camera to default overview position
    - `_populate_map()`:
      - Clear existing children of MapContent
      - Read nebula positions from `global_nebulas.tscn` resource or hardcode
        the 4 authored positions + scales; create semi-transparent SphereMesh
        instances (SpatialMaterial, albedo alpha ~0.15, unshaded) at each
      - Read `TemplateDatabase.locations` for all sector templates:
        - Place small SphereMesh marker (radius ~1000, bright color) at `global_position`
        - Store marker reference for label projection
      - Read `GameState.world_topology` for connections:
        - Use `ImmediateGeometry` to draw lines between connected sector pairs
          (deduplicate: only draw A→B if A < B alphabetically)
    - Label overlay: Use a `Control` node layered over the ViewportContainer.
      Each frame (`_process`), project sector 3D positions through MapCamera
      to 2D screen coords, position Label nodes accordingly. Hide labels that
      project behind camera.
    - Refresh on `sim_tick_completed` signal (topology can change via discovery)
    - Signatures: extends CanvasLayer, onready var, export var (none needed),
      ImmediateGeometry, SpatialMaterial, ViewportContainer, Camera

  - [ ] TASK_5: Wire `DebugMapPanel` into `main_game_scene.tscn`
    - Add `DebugMapPanel` node as sibling of `SimDebugPanel`
    - Instance from `res://src/core/ui/debug_map_panel/debug_map_panel.tscn`
    - Signatures: .tscn ext_resource + node addition

  - [ ] TASK_6: Create unit tests `test_debug_map_panel.gd`
    - extends GutTest
    - `test_panel_starts_hidden`: instance panel, assert panel not visible
    - `test_toggle_shows_panel`: simulate F4 key, assert panel visible
    - `test_populate_creates_sector_markers`: call _populate_map, count MapContent
      children, assert >= 5 (one per sector)
    - `test_populate_creates_connection_lines`: call _populate_map, find
      ImmediateGeometry child, assert exists
    - `test_populate_creates_nebula_markers`: call _populate_map, count nebula
      mesh children, assert >= 4
    - `test_camera_initial_position`: assert camera translation.z > 0
      (overview distance)
    - `test_label_count_matches_sectors`: assert label overlay has >= 5 labels
    - before_each: seed GameState + TemplateDatabase with test topology
    - after_each: cleanup
    - Signatures: GutTest, InputEventKey simulation

  - [ ] VERIFICATION_1: Zero project-wide errors
    - Run `get_errors()` on all files — expect 0 parse/type errors

  - [ ] VERIFICATION_2: All GUT tests pass
    - Run full GUT suite — expect ≥ 174 tests, ≥ 560 asserts, 0 failures
    - New tests from TASK_6 add ~7 tests

  - [ ] VERIFICATION_3: Manual — sector scene rename integrity
    - Start game → load into Station Alpha → verify zone loads without error
    - Jump to Station Beta → verify zone loads, nebula visibly shifts

  - [ ] VERIFICATION_4: Manual — nebula parallax
    - Jump between Alpha (origin) and Epsilon (~102K away)
    - Global nebulas must visibly shift position between the two sectors

  - [ ] VERIFICATION_5: Manual — debug map visualization
    - Press F4 → map panel opens with all 5 sector markers, labels, connections
    - Nebula representations visible at correct relative positions
    - Rotate/zoom/pan controls work; labels track sector positions
    - Press F4 again → map panel closes
