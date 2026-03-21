## CURRENT GOAL: Multi-Sector World — Handcrafted Sector Presets + Sector Travel + NPC Population

### EXECUTIVE SUMMARY

Two milestones are complete: the qualitative tag simulation produces rich
per-sector state every tick, and the ContactManager + Radar + Sector Info HUD
makes that state visible during flight. However, the **3D game world is a single
static zone** (`basic_flight_zone.tscn`) containing 3 hardcoded stations, while
the simulation models 5 interconnected sectors. All 6 persistent NPCs spawn in
the same zone regardless of their simulation `current_sector_id`. There is no
sector travel — the player cannot visit the sectors the simulation is modeling.

This milestone bridges simulation topology to the 3D game world using
**handcrafted sector presets** — each sector is a fully configurable `.tscn`
scene stored in its own folder, with its own cloned star/planet/station
templates independently editable by modders.

1. **Sector presets, not runtime generation.** Each sector is a hand-authored
   `.tscn` scene in `scenes/levels/sectors/<sector_id>/`. The simulation reads
   topology, tags, and connections from LocationTemplate `.tres` files
   (unchanged). The 3D game loads the sector's `.tscn` when the player visits.
   Star, planet, and station templates are cloned per-sector for independent
   customization — the game is a moddable engine with a modder-oriented workflow.

2. **Flexible sectors (not star systems).** A sector is any volume of space — a
   star system, a deep space region near a stellar body, an asteroid field, small
   multi-star clusters, etc. The LocationTemplate and sector `.tscn` structure
   accommodate this flexibility. The `sector_type` and `sector_description`
   fields describe the sector in general terms.

3. **100 km playable radius.** Sector content is placed within 100,000 Godot
   units from sector center. No hard borders — an invisible sphere serves only
   as an editor reference.

4. **JumpPoints injected at runtime.** Since connections can change (new sectors
   discovered via simulation exploration), JumpPoints are added by the
   SectorLoader at load time based on the sector's current connections. The
   player flies to a JumpPoint and presses Interact to travel.

5. **Procedural sector template (architecture only).** Newly discovered sectors
   (via simulation exploration at runtime) lack handcrafted `.tscn` files. The
   LocationTemplate supports procedural hint fields for a future generator. For
   this milestone, procedural sectors use a generic fallback scene. The actual
   procedural generation logic is a future milestone.

6. **Sim-driven NPC population.** AgentSystem only spawns agents whose
   simulation `current_sector_id` matches the loaded sector. On sector travel,
   old agents are despawned and new sector's agents are spawned.

**Why now:** The simulation models a multi-sector world with agents moving between
sectors, but the 3D game is stuck in one zone. Without sector travel, the
simulation's agent movement, sector-specific conditions, and topology are all
invisible gameplay-wise. This must come before trading, contracts, or chronicle
displays because those features depend on the player being able to visit
different sectors.

**Scope boundary:** This milestone does NOT include: procedural sector generation
logic (only the data architecture), combat or encounter triggering during travel,
zone transition visual effects (fade/warp), unique art per sector beyond template
clones, or modifications to the simulation layers.

### PREVIOUS MILESTONE STATUS: ContactManager + Radar + Sector Info HUD — Complete ✅

All 8 TASK items + 5 VERIFICATIONs. ContactManager system node bridges simulation
data to HUD. Radar Display shows color-coded agent contacts in TopRightZone.
Sector Info Panel shows BBCode-formatted sector conditions in TopCenterZone. All
refresh on sim_tick_completed. 160/160 GUT tests, 536/536 asserts.

---

- TARGET_FILES:

  **PHASE 1 — PREFAB EXTRACTION + SECTOR PRESET STRUCTURE:**
  - `scenes/prefabs/celestial/Star_default.tscn` — CREATE (extracted star from basic_flight_zone)
  - `scenes/prefabs/celestial/Planet_default.tscn` — CREATE (extracted planet from basic_flight_zone)
  - `scenes/levels/sectors/station_alpha/Star_alpha.tscn` — CREATE (clone of Star_default)
  - `scenes/levels/sectors/station_alpha/Planet_alpha.tscn` — CREATE (clone of Planet_default)
  - `scenes/levels/sectors/station_alpha/Station_alpha.tscn` — CREATE (clone of DockableStation, alpha defaults)
  - `scenes/levels/sectors/station_alpha/sector_station_alpha.tscn` — CREATE (sector scene)
  - [same pattern for station_beta, station_gamma, station_delta, station_epsilon]

  **PHASE 2 — TEMPLATE + STATE UPDATES:**
  - `database/definitions/location_template.gd` — UPDATE (add sector_scene_path, global_position, procedural fields)
  - `database/registry/locations/*.tres` (5 files) — UPDATE (add new field values)
  - `src/autoload/GameState.gd` — UPDATE (add current_sector_id)
  - `src/autoload/Constants.gd` — UPDATE (add sector travel constants)

  **PHASE 3 — JUMP POINT SYSTEM:**
  - `src/scenes/game_world/jump_point.gd` — CREATE (Area-based travel trigger)
  - `scenes/prefabs/navigation/JumpPoint.tscn` — CREATE (scene definition)
  - `src/autoload/EventBus.gd` — UPDATE (add jump signals)

  **PHASE 4 — SECTOR LOADING + TRAVEL:**
  - `src/core/systems/sector_loader.gd` — CREATE (loads preset, injects JumpPoints, offsets nebula)
  - `src/scenes/game_world/world_manager.gd` — UPDATE (load_sector, travel_to_sector)
  - `src/modules/piloting/player_controller_ship.gd` — UPDATE (Interact handles jump)

  **PHASE 5 — AGENT SPAWNING + HUD:**
  - `src/core/systems/agent_system.gd` — UPDATE (filter spawns by current sector)
  - `src/core/ui/main_hud/main_hud.gd` — UPDATE (jump prompt display)

  **PHASE 6 — TESTS:**
  - `src/tests/core/systems/test_sector_loader.gd` — CREATE (unit tests)

- TRUTH_RELIANCE:
  - `TRUTH_PROJECT.md` — Godot 3.6 stable, GLES2, Python 3 sandbox
  - `TRUTH_CONSTRAINTS.md` — No @export, @onready, await (Godot 3 syntax)
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §2 (Flow Graph) — Sector topology, connections
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §3.1 (Layer 1: World Layer) — world_topology structure
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §3.3 (Layer 3: Agent Layer) — agent current_sector_id, movement
  - `TRUTH-GDD-COMBINED-TEXT` §1.1 — Core Systems (stateless systems pattern)
  - `TRUTH-GDD-COMBINED-TEXT` §3 — Architecture (autoload singletons, EventBus decoupling)

- TECHNICAL_CONSTRAINTS:
  - Godot 3.6 stable, GDScript 3.x syntax (NO @export, @onready, await)
  - Use `export var` for template properties, `onready var` for scene node references
  - Sector presets are hand-authored `.tscn` files — one per sector, fully editable in Godot editor
  - JumpPoints are injected at runtime by SectorLoader (connections can change when new sectors are discovered)
  - Global nebula offset applied at runtime by SectorLoader (not baked into sector `.tscn`)
  - Reuse existing scene resources: DockableStation.tscn base (cloned per sector), global_nebulas.tscn (nebula), star/planet prefabs (extracted then cloned per sector)
  - SectorLoader extends Reference (stateless, called by WorldManager, not a persistent Node)
  - Zone cleanup follows existing `_cleanup_current_zone()` pattern (queue_free, clear GlobalRefs)
  - AgentSystem spawns only agents matching loaded sector — reads `GameState.agents[id].current_sector_id`
  - Keep ALL existing systems functional — simulation layers, ContactManager, HUD panels, docking, TimeSystem
  - Player's simulation `current_sector_id` in `GameState.agents["player"]` must stay in sync with loaded zone
  - `GameState.current_sector_id` is authoritative record of which sector is loaded in 3D
  - GLES2 compatible (no visual changes beyond JumpPoint marker meshes)
  - Content within 100,000 units of sector center (no hard borders)
  - Per-sector folders are self-contained: sector `.tscn` + cloned star/planet/station = full modder workspace

- DESIGN_DECISIONS:

  - **Handcrafted presets, not runtime-built zones.** Each sector's 3D content is
    authored in a `.tscn` file the modder can open and edit. The simulation reads
    topology from `.tres` files (unchanged). This inverts the old
    "SectorZoneFactory builds at runtime" approach. Advantages: full editor
    support (modders see node inspector, transform gizmos, material previews),
    per-sector unique content without generator complexity, moddable engine
    philosophy.

  - **Per-sector cloned assets.** Star, planet, and station templates are
    DUPLICATED into each sector's folder (`scenes/levels/sectors/<id>/`). This
    means `Star_alpha.tscn` is initially identical to `Star_default.tscn` but
    independently editable. A modder customizing station_gamma's star doesn't
    affect other sectors. The master prefabs in `scenes/prefabs/celestial/` serve
    as the source templates for cloning — they are NOT instanced at runtime.

  - **Flexible sector definition.** A sector is NOT required to have a star,
    planet, or station. The sector `.tscn` can contain anything — asteroid fields,
    empty deep space with only a nav beacon, binary star systems, nebula
    interiors. The LocationTemplate's `sector_type` and `sector_description`
    describe the sector in general terms. The 5 initial sectors each get a star +
    planet + station using the visual style from `basic_flight_zone.tscn`.

  - **100 km playable radius, no hard borders.** Content is placed within 100,000
    Godot units from sector center (origin). A `_PlayableArea` invisible sphere
    mesh at scale 100,000 exists as an EDITOR REFERENCE ONLY — no collision, no
    gameplay effect. The player can fly beyond; content just becomes sparse.

  - **JumpPoints at sector edges, direction-based.** For each connection, a
    JumpPoint is placed at `JUMP_POINT_RING_RADIUS` (80,000 units) from sector
    origin, in the direction of the connected sector's `global_position`:
    `jump_pos = (target.global_position - this.global_position).normalized() * JUMP_POINT_RING_RADIUS`.
    This naturally places jump points toward the edge of the playable area, in
    the directionally correct orientation for galactic travel.

  - **Global nebula offset = galactic illusion.** The nebula in
    `global_nebulas.tscn` is hand-authored at absolute positions (hundreds of
    thousands of units). To maintain visual consistency across sectors, the
    SectorLoader applies a local offset to the nebula instance:
    `nebula_offset = REFERENCE_ORIGIN - sector_global_position`. Where
    `REFERENCE_ORIGIN` is Station Alpha's `global_position`. At Alpha, offset is
    zero (nebula appears as original). At other sectors, the offset shifts the
    nebula to maintain galactic perspective. The `StarsphereSlot` already handles
    camera-following.

  - **Travel flow: JumpPoint Area → signal → WorldManager.** JumpPoint emits
    `jump_available(target_sector_id, target_name)` on body_entered (player
    only). Player presses Interact. WorldManager listens for
    `player_jump_requested`, calls `travel_to_sector()`. Travel is instant (no
    transition effect in this milestone). Cleanup → load new sector → inject
    JumpPoints → spawn agents → emit zone_loaded.

  - **Simulation player sector sync.** When travel completes,
    `GameState.agents["player"]["current_sector_id"]` is updated to match the new
    sector. This keeps the simulation consistent with the 3D world. A sim tick
    fires after travel (same as dock/undock).

  - **SectorLoader as Reference, not Node.** Stateless builder called by
    WorldManager. Loads the sector `.tscn`, finds its StarsphereSlot, offsets the
    nebula, creates and injects JumpPoint nodes for each connection, returns the
    ready zone. Follows the WorldGenerator pattern (instantiated, used, discarded).

  - **`global_position` on LocationTemplate.** New field representing the sector's
    position in the galaxy. Drives: (a) nebula offset calculation, (b) JumpPoint
    direction vectors, (c) potential future inter-sector distance calculations.
    The existing `position_in_zone` values (48042,233,-673 etc.) are reused as
    `global_position` since they already represent galactic-scale spread. The old
    `position_in_zone` field is KEPT for backward compat but is no longer the
    primary spatial reference.

  - **Procedural sector data architecture.** LocationTemplate gains
    `is_procedural: bool`, `procedural_type: String`, and
    `procedural_hints: Dictionary`. For handcrafted sectors, `is_procedural =
    false` and `sector_scene_path` points to the `.tscn`. For discovered sectors,
    `is_procedural = true`, `sector_scene_path = ""`, and the hints describe
    general characteristics (density, hazard_type, celestial_count, etc.) for a
    future procedural generator. In THIS milestone, if `sector_scene_path` is
    empty, the SectorLoader uses a minimal generic fallback scene (Spatial +
    AgentContainer + StarsphereSlot — blank space). The procedural generator is
    out of scope.

  - **Preserve basic_flight_zone.tscn as reference.** The existing zone is NOT
    deleted — it remains as the original visual reference and source material for
    prefab extraction. It is no longer loaded at runtime (sector presets replace
    it).

  - **Star/planet extracted from basic_flight_zone.tscn.** The Star_1 node
    subtree (StaticBody → CollisionShape + Model/StarSurface + Model/StarCorona +
    ModelAdditional/Star_sprite + StarHalo + OmniLight) is extracted into
    `Star_default.tscn`. Planet_a (StaticBody → CollisionShape + Model/
    PlanetSurface + small asteroid StaticBody) is extracted into
    `Planet_default.tscn`. Both reference existing materials in
    `scenes/levels/zones/zone1/scene_materials/`. Per-sector clones inherit these
    material paths (modder can override).

  - **Station clones per sector.** Each sector gets a Station_<id>.tscn that is a
    clone of `scenes/prefabs/station/DockableStation.tscn` with sector-specific
    `location_id` and `station_name` defaults baked in. The modder can then
    customize the mesh, scale, materials, docking zone radius, etc. per sector.

---

- ATOMIC_TASKS:

  ### PHASE 1: Prefab Extraction + Sector Preset Structure

  - [ ] TASK_1: Extract star and planet from basic_flight_zone into standalone prefab .tscn files
    - File: `scenes/prefabs/celestial/Star_default.tscn` — CREATE
      **Node tree extracted from basic_flight_zone.tscn `SceneAssets/System_1/Star_1`:**
      ```
      Star_default (StaticBody)
      ├── CollisionShape (SphereShape, radius=5000)
      ├── Model (Spatial, complex transform preserved from basic_flight_zone)
      │   ├── StarSurface (MeshInstance, SphereMesh, material=star_1_surface.tres)
      │   └── StarCorona (MeshInstance, SphereMesh radial_segments=32, material=star_1_corona.tres)
      ├── ModelAdditional (Spatial)
      │   ├── Star_sprite_square_wide (instance of Star_sprite_square_wide.glb, material=star_1_sprite.tres)
      │   └── StarHalo (MeshInstance, SphereMesh 16x16, ShaderMaterial with halo rim shader — inline sub_resource)
      └── OmniLight (color=warm yellow, energy=1.5, range=100000)
      ```
      - ext_resources: `rotating_object.gd` (id=8 in original), `star_1_surface.tres`, `star_1_corona.tres`, `star_1_sprite.tres`, `Star_sprite_square_wide.glb`
      - sub_resources: SphereShape (r=5000), SphereMesh (star surface), SphereMesh (corona, radial=32), ShaderMaterial (halo rim shader with params), SphereMesh (halo, 16x16)
      - The Model transform preserves the original scaling/rotation from basic_flight_zone
      - Star_default has NO parent positioning — its transform is (1,0,0,0,1,0,0,0,1,0,0,0). The per-sector .tscn positions it.
    - File: `scenes/prefabs/celestial/Planet_default.tscn` — CREATE
      **Node tree extracted from basic_flight_zone.tscn `SceneAssets/System_1/Star_1/Planet_a` (detached from Star parent):**
      ```
      Planet_default (StaticBody)
      ├── CollisionShape (SphereShape, radius=1000)
      ├── Model (Spatial, scale=1000)
      │   └── PlanetSurface (MeshInstance, SphereMesh, ShaderMaterial using solid.gdshader with planet texture params)
      └── StaticBody3 (small asteroid/moon near planet)
          ├── CollisionShape (BoxShape)
          └── Model/MeshInstance (CubeMesh)
      ```
      - ext_resources: `rotating_object.gd`, `solid.gdshader`, Craters textures (normal + bw noise)
      - sub_resources: SphereShape (r=1000), SphereMesh, ShaderMaterial (solid shader with planet params), BoxShape, CubeMesh, ConcavePolygonShape
      - Planet_default transform = identity. Per-sector .tscn positions it.
    - Signature: 2 new .tscn files. Pure asset extraction, no code changes.

  - [ ] TASK_2: Create sector preset folders with cloned assets and sector scenes for all 5 sectors
    - **Folder structure created:**
      ```
      scenes/levels/sectors/
      ├── station_alpha/
      │   ├── sector_station_alpha.tscn     # Sector scene (main)
      │   ├── Star_alpha.tscn               # Clone of Star_default.tscn
      │   ├── Planet_alpha.tscn             # Clone of Planet_default.tscn
      │   └── Station_alpha.tscn            # Clone of DockableStation.tscn, location_id="station_alpha", station_name="Station Alpha - Mining Hub"
      ├── station_beta/
      │   ├── sector_station_beta.tscn
      │   ├── Star_beta.tscn
      │   ├── Planet_beta.tscn
      │   └── Station_beta.tscn             # location_id="station_beta", station_name="Station Beta - Trade Post"
      ├── station_gamma/
      │   ├── sector_station_gamma.tscn
      │   ├── Star_gamma.tscn
      │   ├── Planet_gamma.tscn
      │   └── Station_gamma.tscn            # location_id="station_gamma", station_name="Freeport Gamma"
      ├── station_delta/
      │   ├── sector_station_delta.tscn
      │   ├── Star_delta.tscn
      │   ├── Planet_delta.tscn
      │   └── Station_delta.tscn            # location_id="station_delta", station_name="Outpost Delta - Military Garrison"
      └── station_epsilon/
          ├── sector_station_epsilon.tscn
          ├── Star_epsilon.tscn
          ├── Planet_epsilon.tscn
          └── Station_epsilon.tscn          # location_id="station_epsilon", station_name="Epsilon Refinery Complex"
      ```
    - **Per-sector station clone:** Copy of DockableStation.tscn with sector-specific `location_id` and `station_name` baked into the .tscn resource overrides. Same script (`dockable_station.gd`), same structure (StaticBody + CollisionShape + MeshInstance + DockingZone/Area).
    - **Per-sector star/planet clone:** Byte-identical copies of Star_default.tscn and Planet_default.tscn. These are placed in the sector folder for independent modder customization.
    - **Sector scene structure (each sector_*.tscn):**
      ```
      SectorRoot (Spatial)
      ├── _PlayableArea (MeshInstance, invisible SphereMesh, scale=100000, editor reference only)
      ├── AgentContainer (Spatial, name="AgentContainer")
      ├── StarsphereSlot (Spatial, script=starsphere_slot.gd)
      │   └── Globalnebulas (instance of global_nebulas.tscn)
      ├── SceneAssets (Spatial)
      │   ├── Star (instance of local Star_<id>.tscn, positioned in scene)
      │   │   └── Planet (instance of local Planet_<id>.tscn, positioned relative to star)
      │   ├── Station (instance of local Station_<id>.tscn, positioned in scene)
      │   └── EntryPoint (Position3D — default player spawn position near station)
      └── [JumpPoints — injected at runtime by SectorLoader, NOT in .tscn]
      ```
    - **Sector Alpha layout:** Mirrors basic_flight_zone layout — star near center, planet orbiting, station at ~(500, 0, 200), EntryPoint near station. All within 100,000 unit radius.
    - **Sectors Beta–Epsilon:** Same visual template (star + planet + station), different station positions and EntryPoint offsets. Initially identical star/planet visuals (modder customizes later).
    - **ext_resources per sector .tscn:** starsphere_slot.gd, global_nebulas.tscn, editor_object.gd (for _PlayableArea), local Star/Planet/Station .tscn paths.
    - Signature: 20 new .tscn files (4 per sector × 5 sectors). Pure scene creation.

  ### PHASE 2: Template + State Updates

  - [ ] TASK_3: Update LocationTemplate + .tres files + GameState + Constants
    - File: `database/definitions/location_template.gd` — UPDATE
      - ADD after `position_in_zone` line:
        ```
        # --- Sector Scene Configuration ---
        ## Path to the handcrafted .tscn scene for this sector. Empty for procedural sectors.
        export var sector_scene_path: String = ""
        ## Galactic position of this sector. Drives starsphere offset and JumpPoint directions.
        export var global_position: Vector3 = Vector3.ZERO

        # --- Procedural Generation Hints (for runtime-discovered sectors) ---
        ## If true, this sector has no handcrafted .tscn and uses procedural generation.
        export var is_procedural: bool = false
        ## Type hint for future procedural generator: deep_space, asteroid_field, stellar_approach, nebula_interior, etc.
        export var procedural_type: String = "deep_space"
        ## Generator parameters: {density: float, hazard_type: String, celestial_count: int, etc.}
        export var procedural_hints: Dictionary = {}
        ## Human-readable description of the sector for UI and generator context.
        export var sector_description: String = ""
        ```
    - File: `database/registry/locations/station_alpha.tres` — UPDATE
      - ADD: `sector_scene_path = "res://scenes/levels/sectors/station_alpha/sector_station_alpha.tscn"`
      - ADD: `global_position = Vector3( 48042, 233, -673 )` (same value as position_in_zone)
      - ADD: `sector_description = "Mining hub orbiting a warm star. Rich mineral deposits in the nearby asteroid belt."`
    - File: `database/registry/locations/station_beta.tres` — UPDATE
      - ADD: `sector_scene_path = "res://scenes/levels/sectors/station_beta/sector_station_beta.tscn"`
      - ADD: `global_position = Vector3( 49500, 100, 1500 )`
      - ADD: `sector_description = "Busy trade post at a stellar crossroads. Strong manufactured goods economy."`
    - File: `database/registry/locations/station_gamma.tres` — UPDATE
      - ADD: `sector_scene_path = "res://scenes/levels/sectors/station_gamma/sector_station_gamma.tscn"`
      - ADD: `global_position = Vector3( 46000, -200, 500 )`
      - ADD: `sector_description = "Lawless freeport near a cold star. Rich propellant sources draw traders and pirates alike."`
    - File: `database/registry/locations/station_delta.tres` — UPDATE
      - ADD: `sector_scene_path = "res://scenes/levels/sectors/station_delta/sector_station_delta.tscn"`
      - ADD: `global_position = Vector3( 47000, 150, 800 )`
      - ADD: `sector_description = "Military garrison outpost maintaining order at a key junction. Well-defended."`
    - File: `database/registry/locations/station_epsilon.tres` — UPDATE
      - ADD: `sector_scene_path = "res://scenes/levels/sectors/station_epsilon/sector_station_epsilon.tscn"`
      - ADD: `global_position = Vector3( 44500, -100, 1200 )`
      - ADD: `sector_description = "Remote refinery complex. High mineral density but harsh environment."`
    - File: `src/autoload/GameState.gd` — UPDATE
      - ADD in `# === SCENE STATE ===` section:
        `var current_sector_id: String = ""`
      - ADD to `reset_state()`:
        `current_sector_id = ""`
    - File: `src/autoload/Constants.gd` — UPDATE
      - ADD section `# ---- SECTOR TRAVEL ----`:
        ```
        const JUMP_POINT_RING_RADIUS: float = 80000.0       # Distance from sector center where JumpPoints appear
        const JUMP_POINT_DETECTION_RADIUS: float = 300.0     # Area radius for player detection
        const REFERENCE_ORIGIN: Vector3 = Vector3(48042, 233, -673)  # Station Alpha global_position (nebula reference)
        const SECTOR_CONTENT_RADIUS: float = 100000.0        # Recommended content placement radius
        const INITIAL_SECTOR_ID: String = "station_alpha"    # Starting sector for new game
        ```
    - Signature: 8 files updated. Pure data additions. No behavioral changes.

  ### PHASE 3: JumpPoint System

  - [ ] TASK_4: Create JumpPoint script + scene + EventBus signals
    - Script file: `src/scenes/game_world/jump_point.gd` — CREATE
    - Scene file: `scenes/prefabs/navigation/JumpPoint.tscn` — CREATE
    - Class: `extends StaticBody` (follows DockableStation pattern)
    - **Scene structure (.tscn):**
      ```
      JumpPoint (StaticBody, script=jump_point.gd)
      ├── CollisionShape (SphereShape, radius=10) — small solid body
      ├── Model (Spatial)
      │   └── MeshInstance (SphereMesh, radius=15, unshaded cyan material) — visible marker
      ├── DetectionZone (Area)
      │   └── CollisionShape (SphereShape, radius=JUMP_POINT_DETECTION_RADIUS from Constants)
      └── [Label3D for future — not in this milestone]
      ```
    - **Exported properties:**
      `export var target_sector_id: String = ""`
      `export var target_sector_name: String = ""`
    - **Script logic (~40 lines):**
      - `_ready()`: add to group `"jump_point"`, connect DetectionZone signals
      - `_on_body_entered(body)`: if player (`body.has_method("is_player") and body.is_player()`), emit `EventBus.emit_signal("jump_available", target_sector_id, target_sector_name)`
      - `_on_body_exited(body)`: if player, emit `EventBus.emit_signal("jump_unavailable")`
    - **Visual:** Unshaded cyan sphere (Color(0.33, 1.0, 1.0)) — visible beacon for navigation.
    - File: `src/autoload/EventBus.gd` — UPDATE
      - ADD section `# --- Sector Travel Signals ---`:
        `signal jump_available(target_sector_id, target_sector_name)`
        `signal jump_unavailable`
        `signal player_jump_requested(target_sector_id)`
        `signal sector_changed(new_sector_id, old_sector_id)`
    - Signature: 2 new files + 1 updated. Follows DockableStation pattern exactly.

  ### PHASE 4: Sector Loading + Travel

  - [ ] TASK_5: Create SectorLoader — loads preset, injects JumpPoints, offsets nebula
    - File: `src/core/systems/sector_loader.gd` — CREATE
    - Class: `extends Reference` (stateless builder, same pattern as WorldGenerator)
    - **Dependencies:** Reads `TemplateDatabase.locations`, `GameState.world_topology`, `Constants`
    - **Preloaded resource:**
      `const JumpPointScene = preload("res://scenes/prefabs/navigation/JumpPoint.tscn")`
    - **Public API:**
      - `func load_sector(sector_id: String) -> Spatial`
        1. Look up LocationTemplate: `var template = TemplateDatabase.locations.get(sector_id)`
        2. If template is null or sector_id not in `GameState.world_topology`: return null
        3. Determine scene path:
           - If `template.sector_scene_path != ""`: load that `.tscn`
           - Else (procedural fallback): build minimal Spatial with AgentContainer + StarsphereSlot (no content)
        4. Instance the scene: `var zone_root = scene.instance()`
        5. Inject JumpPoints: `_inject_jump_points(zone_root, sector_id, template)`
        6. Offset nebula: `_offset_nebula(zone_root, template)`
        7. Return `zone_root`
    - **Private methods:**
      - `func _inject_jump_points(zone_root: Spatial, sector_id: String, template) -> void`
        - Get connections: `GameState.world_topology[sector_id].get("connections", [])`
        - For each connected sector_id:
          - Compute direction: `var target_template = TemplateDatabase.locations.get(target_id)`
          - `var direction = (target_template.global_position - template.global_position).normalized()`
          - `var jump_pos = direction * Constants.JUMP_POINT_RING_RADIUS`
          - Instance JumpPointScene, set `target_sector_id`, `target_sector_name`
          - Set JumpPoint transform.origin = jump_pos
          - Add as child of zone_root (or a "JumpPoints" Spatial container)
        - If direction is zero (same position, edge case): use arbitrary offset
      - `func _offset_nebula(zone_root: Spatial, template) -> void`
        - Find StarsphereSlot: `zone_root.find_node("StarsphereSlot", true, false)`
        - Find Globalnebulas child
        - Compute offset: `Constants.REFERENCE_ORIGIN - template.global_position`
        - Apply to Globalnebulas local transform: `nebulas.transform.origin = offset`
      - `func _build_procedural_fallback(sector_id: String) -> Spatial`
        - Returns minimal zone: Spatial root + AgentContainer + StarsphereSlot/Globalnebulas
        - Use for sectors with no sector_scene_path (future procedural discovery)
    - Signature: ~100 lines. Stateless loader. No GameState mutation (caller handles that).

  - [ ] TASK_6: Update WorldManager — load_sector + travel flow
    - File: `src/scenes/game_world/world_manager.gd` — UPDATE
    - **New state:**
      `var _sector_loader = null` — SectorLoader Reference instance
      `var _pending_jump_target: String = ""` — sector_id of available jump point
    - **New method: `load_sector(sector_id: String)`**
      Replaces `load_zone()` calls for gameplay. Flow:
      1. Validate `sector_id` exists in `GameState.world_topology`
      2. Call `_cleanup_current_zone()` (existing method)
      3. `yield(get_tree(), "idle_frame")`
      4. Lazy-init: `if _sector_loader == null: _sector_loader = load("res://src/core/systems/sector_loader.gd").new()`
      5. `var zone_root: Spatial = _sector_loader.load_sector(sector_id)`
      6. If null: `printerr("WM Error: SectorLoader returned null for: ", sector_id); return`
      7. Find `CurrentZoneContainer`, add zone_root as child
      8. Set `GameState.current_zone_instance = zone_root`, `GlobalRefs.current_zone = zone_root`
      9. Find AgentContainer in zone_root, set `GlobalRefs.agent_container`
      10. Set `GameState.current_sector_id = sector_id`
      11. Emit `EventBus.zone_loaded(zone_root, sector_id, agent_container)`
    - **New method: `travel_to_sector(target_sector_id: String)`**
      Called when player confirms jump. Flow:
      1. `var old_sector = GameState.current_sector_id`
      2. Set `GameState.player_docked_at = ""` (undock if docked)
      3. Update simulation: `GameState.agents["player"]["current_sector_id"] = target_sector_id`
      4. Emit `EventBus.sector_changed(target_sector_id, old_sector)`
      5. Call `load_sector(target_sector_id)`
      6. Request sim tick: `if is_instance_valid(GlobalRefs.simulation_engine): GlobalRefs.simulation_engine.request_tick()`
    - **_ready() updates:**
      - Connect `EventBus.player_jump_requested` → `_on_player_jump_requested`
      - Connect `EventBus.jump_available` → `_on_jump_available`
      - Connect `EventBus.jump_unavailable` → `_on_jump_unavailable`
    - **Signal handlers:**
      - `_on_jump_available(target_sector_id, _name)`: store `_pending_jump_target = target_sector_id`
      - `_on_jump_unavailable()`: clear `_pending_jump_target = ""`
      - `_on_player_jump_requested(target_sector_id)`: call `travel_to_sector(target_sector_id)`
    - **Update `_on_new_game_requested()`:**
      - Replace `load_zone(Constants.INITIAL_ZONE_SCENE_PATH)` with `load_sector(Constants.INITIAL_SECTOR_ID)`
      - After sim init: `GameState.agents["player"]["current_sector_id"] = Constants.INITIAL_SECTOR_ID`
    - **Update `_on_game_state_loaded()`:**
      - Replace `load_zone(Constants.INITIAL_ZONE_SCENE_PATH)` with:
        ```
        var saved_sector = GameState.current_sector_id
        if saved_sector == "": saved_sector = Constants.INITIAL_SECTOR_ID
        load_sector(saved_sector)
        ```
    - **Keep `load_zone()` intact** as private fallback method — not deleted, not called by gameplay code.
    - File: `src/modules/piloting/player_controller_ship.gd` — UPDATE (minimal)
      - In the existing interact handler:
        ```
        # If a jump point is available and we're NOT in docking range, trigger jump
        if _pending_jump_target != "":
            EventBus.emit_signal("player_jump_requested", _pending_jump_target)
            return
        ```
      - Add state: `var _pending_jump_target: String = ""`
      - Connect in `_ready()`:
        `EventBus.connect("jump_available", self, "_on_jump_available")`
        `EventBus.connect("jump_unavailable", self, "_on_jump_unavailable")`
      - Handlers:
        `func _on_jump_available(target_id, _name): _pending_jump_target = target_id`
        `func _on_jump_unavailable(): _pending_jump_target = ""`
      - **Priority:** Docking takes priority over jumping. If dock_available is active, Interact docks. Jump only triggers when no dock is available.
    - Signature: ~80 new/modified lines in world_manager. ~15 new lines in player_controller.

  ### PHASE 5: Agent Spawning + HUD

  - [ ] TASK_7: Update AgentSystem for sector-filtered spawning
    - File: `src/core/systems/agent_system.gd` — UPDATE
    - **Update `spawn_persistent_agents()`:**
      - Add explicit sector check before existing logic:
        ```
        var sim_sector = ""
        if GameState.agents.has(agent_id):
            sim_sector = GameState.agents[agent_id].get("current_sector_id", "")
        if sim_sector != GameState.current_sector_id:
            continue  # Agent is in a different sector — don't spawn here
        ```
      - This ensures only agents whose simulation says they're in the loaded sector get spawned.
    - **`_get_dock_position_in_zone()` unchanged** — it already finds the station in the scene tree by location_id. Works with per-sector cloned Station .tscn instances as long as they have the correct `location_id` and are in the `"dockable_station"` group.
    - **`spawn_player()` unchanged** — it already uses dock position or entry point logic. The sector .tscn has an EntryPoint Position3D.
    - Signature: ~10 modified lines. Core filtering logic.

  - [ ] TASK_8: Add jump prompt to MainHUD (reuse docking prompt pattern)
    - File: `src/core/ui/main_hud/main_hud.gd` — UPDATE
      - Connect in `_ready()`:
        `EventBus.connect("jump_available", self, "_on_jump_available")`
        `EventBus.connect("jump_unavailable", self, "_on_jump_unavailable")`
      - Handlers:
        ```
        func _on_jump_available(_target_id, target_name) -> void:
            if docking_prompt and docking_label:
                docking_prompt.visible = true
                docking_label.text = "Jump to " + target_name + " - Press Interact"

        func _on_jump_unavailable() -> void:
            if docking_prompt and docking_label and "Jump" in docking_label.text:
                docking_prompt.visible = false
        ```
    - **Reuses existing DockingPrompt UI.** The prompt label text changes between dock and jump context. No new UI nodes needed.
    - Signature: ~15 new lines.

  ### PHASE 6: Tests

  - [ ] TASK_9: Create unit tests for SectorLoader
    - File: `src/tests/core/systems/test_sector_loader.gd` — CREATE
    - Framework: GUT `extends GutTest`
    - **Setup:** `before_each()` resets `GameState.reset_state()`, seeds minimal world_topology (2 sectors: station_alpha connected to station_beta), seeds TemplateDatabase.locations with mock LocationTemplate resources (global_position set, sector_scene_path pointing to sector presets). `after_each()` cleanup.
    - **Required tests:**
      - `test_load_sector_returns_spatial`:
        Call `load_sector("station_alpha")`. Assert result is Spatial. Assert not null.
      - `test_zone_has_agent_container`:
        Load sector, find node named "AgentContainer". Assert exists and is Spatial.
      - `test_zone_has_station_with_correct_location_id`:
        Load sector for station_alpha. Find DockableStation in group "dockable_station".
        Assert `location_id == "station_alpha"`.
      - `test_zone_has_jump_points_for_connections`:
        Load sector for station_alpha (connected to station_beta, station_delta).
        Find nodes in group "jump_point". Assert count >= 2.
        Assert one has `target_sector_id == "station_beta"`.
      - `test_zone_has_starsphere`:
        Load sector, find node named "StarsphereSlot". Assert exists.
      - `test_load_invalid_sector_returns_null`:
        Call `load_sector("nonexistent")`. Assert result is null.
      - `test_nebula_offset_differs_between_sectors`:
        Load sectors for station_alpha and station_beta.
        Get StarsphereSlot/Globalnebulas transform from each.
        Assert transforms differ (different offsets).
    - Signature: ~120 lines. 7 tests, self-contained.

  ### PHASE 7: Validation

  - [ ] VERIFICATION_1: Project loads in Godot 3.6 with 0 errors — run `get_errors()` across all modified/new files
  - [ ] VERIFICATION_2: GUT test suite — test_sector_loader.gd passes (7 tests, 0 failures). All existing tests still pass.
  - [ ] VERIFICATION_3: Manual — launch game, New Game starts at Station Alpha sector. Radar shows agents in station_alpha. Sector info panel shows station_alpha data.
  - [ ] VERIFICATION_4: Manual — fly to a JumpPoint (cyan sphere), see "Jump to [X] - Press Interact" prompt. Press Interact. Zone transitions to new sector with correct station. Radar updates to show agents in new sector.
  - [ ] VERIFICATION_5: Manual — travel to station_beta, dock. Undock. Travel back to station_alpha via jump point. Verify round-trip works. Run 30 sim ticks — agents may have moved sectors; radar reflects current sector population.
