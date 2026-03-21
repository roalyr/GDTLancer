## CURRENT GOAL: ContactManager + Radar Display + Sector Info HUD

### EXECUTIVE SUMMARY

The qualitative tag simulation is fully ported and running in Godot (all 13 tasks
+ 6 verifications complete — milestone closed 2026-03-21). The simulation produces
rich state every tick — agent dispositions, sector economy/security/environment
tags, colony levels, world age, chronicle events/rumors — but **none of this data
reaches the player during gameplay**. The only visibility is the F3 debug panel.

This milestone bridges the simulation layer to the player's HUD with three
components:

1. **ContactManager** — A new system node that reads `GameState.agents`,
   `GameState.agent_tags`, `GameState.sector_tags` and provides gameplay-facing
   APIs: sector agent roster, disposition scoring, sector condition queries.
   Uses `AffinityMatrix` for disposition computation between the player and
   every agent in the current sector.

2. **Radar Display** — A HUD panel in the existing `TopRightZone` (replacing
   the `_PlaceholderMap`) showing all simulation agents in the player's current
   sector as color-coded contact entries. Color = disposition toward player
   (green/yellow/red). Displays agent name, role, and condition. Refreshes on
   `sim_tick_completed`.

3. **Sector Info Panel** — A compact HUD strip (below `TopLeftZone` info or
   integrated into `TopCenterZone`) showing the current sector's name, economy
   tags, security tag, environment tag, colony level, and world age with tick
   counter. Refreshes on `sim_tick_completed`.

**Why now:** This is the shortest path to making the simulation *perceivable*
during gameplay. All three components are pure read-only consumers of existing
GameState data — no simulation modifications needed. The ContactManager API
also becomes the foundation for future sim-driven 3D agent spawning, encounter
generation, and NPC interaction.

**Scope boundary:** This milestone does NOT include sim-driven 3D agent spawning
(AgentBody instances from simulation state), sector travel / zone transitions,
or encounter generation. Those are separate future milestones that build on the
ContactManager API.

### PREVIOUS MILESTONE STATUS: Port Qualitative Tag Simulation — Complete ✅

All 13 TASK items + 6 VERIFICATIONs. Python sandbox 1:1 ported to GDScript.
Affinity-driven agent actions, tag-transition CA, world-age cycling, chronicle
events/rumors, filament topology exploration, mortal lifecycle. 49/49 GUT tests,
167/167 asserts. F3 debug panel with Run 30/300/3000 batch reports. Sim ticks
event-driven (dock/undock + debug button). All non-simulation systems verified
functional (TimeSystem, docking, HUD, main menu).

---

- TARGET_FILES:

  **PHASE 1 — CONTACT MANAGER (Data Bridge):**
  - `src/core/systems/contact_manager.gd` — CREATE (simulation data bridge + disposition API)
  - `src/autoload/GlobalRefs.gd` — UPDATE (add `contact_manager` variable + setter)
  - `src/autoload/EventBus.gd` — UPDATE (add `sector_contacts_changed` signal)
  - `scenes/levels/game_world/main_game_scene.tscn` — UPDATE (add ContactManager node)

  **PHASE 2 — RADAR DISPLAY (Contact Roster):**
  - `src/core/ui/radar_display/radar_display.gd` — CREATE (contact list HUD panel)
  - `scenes/ui/hud/radar_display.tscn` — CREATE (scene definition)
  - `scenes/ui/hud/main_hud.tscn` — UPDATE (replace `_PlaceholderMap` in TopRightZone with radar)
  - `src/core/ui/main_hud/main_hud.gd` — UPDATE (wire radar refresh signals)

  **PHASE 3 — SECTOR INFO PANEL:**
  - `src/core/ui/sector_info_panel/sector_info_panel.gd` — CREATE (sector status display)
  - `scenes/ui/hud/sector_info_panel.tscn` — CREATE (scene definition)
  - `scenes/ui/hud/main_hud.tscn` — UPDATE (add sector info panel node)
  - `src/core/ui/main_hud/main_hud.gd` — UPDATE (wire sector panel refresh)

  **PHASE 4 — TESTS:**
  - `src/tests/core/systems/test_contact_manager.gd` — CREATE (unit tests)

- TRUTH_RELIANCE:
  - `TRUTH_PROJECT.md` — Godot 3.6 stable, GLES2, Python 3 sandbox
  - `TRUTH_CONSTRAINTS.md` — No @export, @onready, await (Godot 3 syntax)
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §4.5 (Social Graph) — Agent sentiment_tags, disposition derivation
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §5 (Information Graph) — Signal propagation, knowledge model
  - `TRUTH_SIMULATION-GRAPH.md` v1.2 §6 (Architectural Implementation Map) — System file assignments
  - `TRUTH-GDD-COMBINED-TEXT` §1.1 — Core Systems listing (6 stateless systems pattern)
  - `TRUTH-GDD-COMBINED-TEXT` §3 — Architecture & Coding Standards (autoload singletons, EventBus decoupling)
  - `TRUTH-GDD-COMBINED-TEXT` §7 — Assets & Style Guide (UI: functional, monochromatic, saturated highlights)
  - Python sandbox AffinityMatrix — tag vocabulary + compute_affinity() reference

- TECHNICAL_CONSTRAINTS:
  - Godot 3.6 stable, GDScript 3.x syntax (NO @export, @onready, await)
  - Use `onready var` for scene node references, `export var` for template properties
  - ContactManager is a `Node` child of WorldManager in main_game_scene — follows pattern of EventSystem, AgentSystem
  - Radar and SectorInfo panels are `Control` nodes instanced as children of MainHUD
  - All data reads from `GameState` autoload (single source of truth) — no direct simulation layer access
  - `AffinityMatrix` is instantiated locally by ContactManager (stateless Reference, no shared state)
  - `TemplateDatabase` autoload provides location/character names for display
  - All signal connections via `EventBus` — no direct inter-system coupling
  - UI style per GDD §7: dark background, light text, monochromatic base, saturated color only for disposition indicators (green=friendly `#55FF55`, yellow=neutral `#FFFF55`, red=hostile `#FF5555`, cyan=player `#55FFFF`)
  - Keep existing non-simulation systems functional — no changes to TimeSystem, InventorySystem, AssetSystem, CharacterSystem, AgentSpawner, docking
  - GLES2 compatible (no visual changes beyond HUD panels)

- DESIGN_DECISIONS:

  - **ContactManager as system Node, not autoload.** Follows the pattern of EventSystem, CharacterSystem — a Node child of WorldManager in main_game_scene.tscn. Registered in GlobalRefs for cross-system access. Lightweight: caches sector roster on sim tick, provides instant queries.

  - **Player sector derived from simulation state.** `get_player_sector()` reads `GameState.agents["player"]["current_sector_id"]`. This is set during `agent_layer.initialize_agents()` and stays constant in the current single-zone game. Future multi-sector travel will update this field.

  - **Disposition = AffinityMatrix.compute_affinity(player_tags, target_tags).** ContactManager instantiates its own AffinityMatrix (stateless Reference, cheap). Player tags = `GameState.agent_tags.get("player", [])`. Target tags = `GameState.agent_tags.get(agent_id, [])`. Score mapped to disposition category: FRIENDLY (≥ TRADE_THRESHOLD), NEUTRAL (between FLEE and TRADE thresholds), HOSTILE (≤ FLEE_THRESHOLD).

  - **Radar = contact list, not spatial minimap.** Simulation agents have abstract `current_sector_id` but no 3D position. The radar displays a vertical list of contacts (colored dot + name + role + condition) rather than a spatial layout. This is a "sensor readout" showing WHO is in-sector, not WHERE. Spatial radar with 3D-projected dots is a future milestone (requires sim-driven 3D agent spawning).

  - **TopRightZone reactivation.** The existing `TopRightZone` (470×470px, currently `visible=false` with a `_PlaceholderMap`) is the designated radar location per original HUD layout. Radar Display replaces the placeholder, makes the zone visible, and uses the full allocated space.

  - **Sector Info Panel = compact BBCode strip.** Placed in `TopCenterZone` (below existing elements). Uses a RichTextLabel with BBCode for color-coded tag display. Compact two-line format showing sector name, economy/security/environment tags, colony level, and world age with tick count.

  - **Refresh on sim_tick_completed only.** Both panels update when the simulation ticks (not every frame). Additional refresh on `sim_initialized` for initialization. This matches the simulation's event-driven tick model.

---

- ATOMIC_TASKS:

  ### PHASE 1: ContactManager System

  - [x] TASK_1: Add EventBus signal + GlobalRefs variable + disposition constants
    - File: `src/autoload/EventBus.gd` — ADD signal:
      - `signal sector_contacts_changed(sector_id)` — emitted by ContactManager after roster rebuild
    - File: `src/autoload/GlobalRefs.gd` — ADD variable + setter:
      - `var contact_manager = null setget set_contact_manager` — follows existing setter pattern (validity check, print confirmation, error on invalid)
    - File: `src/autoload/Constants.gd` — ADD section `# ---- CONTACT MANAGER ----`:
      - `const DISPOSITION_FRIENDLY_THRESHOLD: float = 0.5` — score ≥ this = friendly (green)
      - `const DISPOSITION_HOSTILE_THRESHOLD: float = -0.5` — score ≤ this = hostile (red)
      - Between thresholds = neutral (yellow)
    - Signature: No behavioral changes. Pure data additions.

  - [x] TASK_2: Create `contact_manager.gd` — simulation data bridge
    - File: `src/core/systems/contact_manager.gd` — CREATE
    - Class: `extends Node`
    - **Dependencies:** `AffinityMatrix` (instantiated locally), reads `GameState`, `TemplateDatabase`, `Constants`
    - **State:**
      - `var _affinity_matrix: Reference` — AffinityMatrix instance
      - `var _sector_roster_cache: Dictionary = {}` — `{sector_id: [agent_id, ...]}` rebuilt on tick
      - `var _disposition_cache: Dictionary = {}` — `{agent_id: float}` player disposition toward each agent, rebuilt on tick
    - **_ready():**
      - Instantiate `_affinity_matrix = AffinityMatrix.new()`
      - Register in GlobalRefs: `GlobalRefs.set_contact_manager(self)`
      - Connect signals: `EventBus.sim_tick_completed` → `_on_sim_tick_completed`, `EventBus.sim_initialized` → `_on_sim_initialized`
    - **Public API methods:**
      - `func get_player_sector() -> String` — returns `GameState.agents.get("player", {}).get("current_sector_id", "")`. Returns `""` if player agent not initialized.
      - `func get_agents_in_sector(sector_id: String) -> Array` — returns Array of agent_id Strings for all non-player, non-disabled agents in that sector. Reads from `_sector_roster_cache`.
      - `func get_agents_in_player_sector() -> Array` — shortcut: `get_agents_in_sector(get_player_sector())`
      - `func get_agent_disposition(agent_id: String) -> float` — returns cached disposition score (player → agent). Returns `0.0` if not cached.
      - `func get_disposition_category(agent_id: String) -> String` — returns `"friendly"` / `"neutral"` / `"hostile"` based on score vs Constants thresholds.
      - `func get_agent_info(agent_id: String) -> Dictionary` — returns a display-ready dict: `{"agent_id": String, "name": String, "role": String, "condition_tag": String, "wealth_tag": String, "cargo_tag": String, "disposition": float, "disposition_category": String, "sector_id": String}`. Name resolved from `TemplateDatabase.characters` or `GameState.characters` via agent's `character_id`. Returns empty dict if agent not found.
      - `func get_sector_info(sector_id: String) -> Dictionary` — returns `{"sector_id": String, "name": String, "economy_tags": Array, "security_tag": String, "environment_tag": String, "colony_level": String, "dominion": String, "world_age": String, "world_age_timer": int, "sim_tick_count": int}`. Name from `TemplateDatabase.locations` (falling back to `GameState.sector_names`). Tags parsed from `GameState.sector_tags[sector_id]`.
      - `func get_current_sector_info() -> Dictionary` — shortcut: `get_sector_info(get_player_sector())`
    - **Private methods:**
      - `func _rebuild_caches() -> void` — iterates `GameState.agents`, groups by `current_sector_id` into `_sector_roster_cache`, computes disposition for agents in player's sector into `_disposition_cache`, emits `EventBus.sector_contacts_changed(player_sector)`
      - `func _compute_player_disposition(agent_id: String) -> float` — `_affinity_matrix.compute_affinity(player_tags, agent_tags)` where player_tags = `GameState.agent_tags.get("player", [])`, agent_tags = `GameState.agent_tags.get(agent_id, [])`
      - `func _resolve_agent_name(agent_id: String) -> String` — checks `GameState.agents[agent_id]["character_id"]`, looks up name from `TemplateDatabase.characters` (Resource with `character_name` property) or `GameState.characters` (Dict with `"character_name"` key). Falls back to `agent_id`.
      - `func _resolve_sector_name(sector_id: String) -> String` — checks `TemplateDatabase.locations` for `location_name` property, falls back to `GameState.sector_names.get(sector_id, sector_id)`.
      - `func _parse_security_tag(tags: Array) -> String` — returns first match from `["SECURE", "CONTESTED", "LAWLESS"]`, default `"UNKNOWN"`
      - `func _parse_environment_tag(tags: Array) -> String` — returns first match from `["MILD", "HARSH", "EXTREME"]`, default `"UNKNOWN"`
      - `func _parse_economy_tags(tags: Array) -> Array` — returns all tags matching `*_RICH`, `*_ADEQUATE`, `*_POOR` patterns
    - **Signal handlers:**
      - `func _on_sim_tick_completed(_tick_count) -> void` — calls `_rebuild_caches()`
      - `func _on_sim_initialized(_seed_string) -> void` — calls `_rebuild_caches()`
    - **_notification(NOTIFICATION_PREDELETE):** Cleanup GlobalRefs + disconnect signals (follow EventSystem pattern)
    - Signature: ~200 lines. Pure read-only bridge. No GameState mutation. No simulation coupling.

  - [x] TASK_3: Add ContactManager node to main_game_scene.tscn
    - File: `scenes/levels/game_world/main_game_scene.tscn` — UPDATE
    - Add a new child node of WorldManager:
      - Name: `ContactManager`
      - Type: Node (with script `res://src/core/systems/contact_manager.gd`)
    - Place it after SimulationEngine in the node order (it depends on sim signals being available).
    - Follow the same pattern as existing system nodes (EventSystem, AgentSpawner, etc.)
    - Signature: Pure scene tree addition. No script changes.

  ### PHASE 2: Radar Display

  - [x] TASK_4: Create `radar_display.gd` + `radar_display.tscn` — contact roster panel
    - Script file: `src/core/ui/radar_display/radar_display.gd` — CREATE
    - Scene file: `scenes/ui/hud/radar_display.tscn` — CREATE
    - Class: `extends Control`
    - **Scene structure (.tscn):**
      ```
      RadarDisplay (Control, script=radar_display.gd)
      ├── PanelBg (Panel) — dark semi-transparent background
      │   ├── VBoxContainer
      │   │   ├── HeaderLabel (Label) — "SECTOR SCAN" title
      │   │   ├── SectorLabel (Label) — current sector name, compact
      │   │   ├── HSeparator
      │   │   └── ContactList (VBoxContainer) — dynamically populated with contact entries
      ```
    - **Contact entry** (created dynamically per agent, not in .tscn):
      - `HBoxContainer` containing:
        - `ColorRect` (12×12 px) — disposition color dot
        - `Label` — `"[Name] — [Role]"` text
        - `Label` — condition indicator (`"✓"` HEALTHY, `"⚠"` DAMAGED, `"✗"` DESTROYED) right-aligned
    - **Script API:**
      - `func refresh(contact_manager) -> void` — clears `ContactList` children, calls `contact_manager.get_agents_in_player_sector()`, creates contact entry nodes for each, sets colors from `contact_manager.get_disposition_category()`. Also updates `SectorLabel` with sector name.
    - **Color mapping:**
      - `"friendly"` → `Color(0.33, 1.0, 0.33)` (green `#55FF55`)
      - `"neutral"` → `Color(1.0, 1.0, 0.33)` (yellow `#FFFF55`)
      - `"hostile"` → `Color(1.0, 0.33, 0.33)` (red `#FF5555`)
    - **Layout:** Anchored to fill parent (TopRightZone). PanelBg uses StyleBoxFlat with dark background (`Color(0.1, 0.1, 0.12, 0.85)`). Text uses default theme font. Contact entries use `size_flags_horizontal = SIZE_EXPAND_FILL`.
    - **Empty state:** When no contacts in sector, show `"No contacts detected"` label.
    - Signature: ~100 lines script. Purely presentational — reads from ContactManager, no direct GameState access.

  - [x] TASK_5: Wire radar into main_hud — scene + script integration
    - File: `scenes/ui/hud/main_hud.tscn` — UPDATE:
      - Set `TopRightZone` `visible = true`
      - Remove or hide `_PlaceholderMap` (set visible=false or delete node)
      - Add child node under `TopRightZone`:
        - Name: `RadarDisplay`
        - Instance: `res://scenes/ui/hud/radar_display.tscn`
        - Anchors: fill parent (anchor_right=1.0, anchor_bottom=1.0)
    - File: `src/core/ui/main_hud/main_hud.gd` — UPDATE:
      - Add `onready var radar_display = $ScreenControls/TopRightZone/RadarDisplay`
      - In `_ready()`: connect `EventBus.sim_tick_completed` → `_on_sim_tick_for_panels`, connect `EventBus.sim_initialized` → `_on_sim_initialized_for_panels`
      - Add handler:
        ```
        func _on_sim_tick_for_panels(_tick_count) -> void:
            _refresh_hud_panels()

        func _on_sim_initialized_for_panels(_seed) -> void:
            _refresh_hud_panels()

        func _refresh_hud_panels() -> void:
            if is_instance_valid(GlobalRefs.contact_manager):
                if is_instance_valid(radar_display):
                    radar_display.refresh(GlobalRefs.contact_manager)
        ```
    - Signature: Minimal additions to main_hud.gd (~20 lines). Radar owns its own rendering; MainHUD just triggers refresh.

  ### PHASE 3: Sector Info Panel

  - [x] TASK_6: Create `sector_info_panel.gd` + `sector_info_panel.tscn` — sector status display
    - Script file: `src/core/ui/sector_info_panel/sector_info_panel.gd` — CREATE
    - Scene file: `scenes/ui/hud/sector_info_panel.tscn` — CREATE
    - Class: `extends Control`
    - **Scene structure (.tscn):**
      ```
      SectorInfoPanel (Control, script=sector_info_panel.gd)
      ├── PanelBg (Panel) — dark semi-transparent background, compact
      │   └── InfoLabel (RichTextLabel) — BBCode-enabled, two-line sector status
      ```
    - **Script API:**
      - `func refresh(contact_manager) -> void` — calls `contact_manager.get_current_sector_info()`, builds BBCode string, sets `InfoLabel.bbcode_text`.
    - **BBCode format:**
      ```
      [b][SECTOR_NAME][/b]  Econ: [color-coded tags]  Sec: [color tag]  Env: [color tag]
      Colony: [color level]  Age: [color WORLD_AGE] (tick [N])
      ```
    - **Tag coloring:**
      - Economy: `*_RICH` → green, `*_ADEQUATE` → yellow, `*_POOR` → red
      - Security: `SECURE` → green, `CONTESTED` → yellow, `LAWLESS` → red
      - Environment: `MILD` → green, `HARSH` → yellow, `EXTREME` → red
      - Colony: `hub` → cyan, `colony` → green, `outpost` → yellow, `frontier` → white
      - World Age: `PROSPERITY` → green, `DISRUPTION` → red, `RECOVERY` → yellow
    - **Layout:** Compact strip. Height auto-sized from content. Width fills available space. PanelBg with dark background matching radar panel style.
    - **Empty state:** If no sector info available (sim not initialized), show `"Awaiting sensor data..."`.
    - Signature: ~80 lines script. Purely presentational.

  - [x] TASK_7: Wire sector info panel into main_hud — scene + script integration
    - File: `scenes/ui/hud/main_hud.tscn` — UPDATE:
      - Add new child under `ScreenControls/TopCenterZone`:
        - Name: `SectorInfoPanel`
        - Instance: `res://scenes/ui/hud/sector_info_panel.tscn`
        - Position: Anchored at top-center, below `DockingPrompt` and `TargetInfoPanel`.
    - File: `src/core/ui/main_hud/main_hud.gd` — UPDATE:
      - Add `onready var sector_info_panel = $ScreenControls/TopCenterZone/SectorInfoPanel`
      - Extend `_refresh_hud_panels()` to also refresh sector info panel:
        ```
        if is_instance_valid(sector_info_panel):
            sector_info_panel.refresh(GlobalRefs.contact_manager)
        ```
    - Signature: Minimal additions (~3 lines to main_hud.gd).

  ### PHASE 4: Tests

  - [x] TASK_8: Create unit tests for ContactManager
    - File: `src/tests/core/systems/test_contact_manager.gd` — CREATE
    - Framework: GUT `extends GutTest`
    - **Setup pattern:** `before_each()` resets `GameState.reset_state()`, seeds minimal simulation state (world_topology, agents, agent_tags, sector_tags, characters), creates ContactManager instance. `after_each()` frees ContactManager.
    - **Required tests:**
      - `test_get_player_sector_returns_current_sector` — set `GameState.agents["player"]["current_sector_id"] = "station_alpha"`, assert `get_player_sector() == "station_alpha"`
      - `test_get_agents_in_sector_returns_correct_agents` — seed 3 agents in "station_alpha", 2 in "station_beta", assert `get_agents_in_sector("station_alpha")` returns 3 ids, `get_agents_in_sector("station_beta")` returns 2
      - `test_get_agents_excludes_player` — seed player + NPC in same sector, assert player not in `get_agents_in_sector()`
      - `test_get_agents_excludes_disabled` — seed disabled agent, assert not in roster
      - `test_get_agent_disposition_computes_affinity` — seed player with MILITARY tag, target with PIRATE tag, assert disposition < 0 (hostile)
      - `test_get_disposition_category_friendly` — seed high-affinity pair, assert `"friendly"`
      - `test_get_disposition_category_hostile` — seed antagonistic pair, assert `"hostile"`
      - `test_get_agent_info_returns_display_dict` — seed agent with known character, assert returned dict has all expected keys (name, role, condition_tag, disposition, etc.)
      - `test_get_sector_info_returns_tags` — seed sector_tags for "station_alpha", assert returned dict has economy_tags, security_tag, environment_tag, colony_level
      - `test_rebuild_caches_updates_on_tick` — manually call `_rebuild_caches()`, verify caches populated
    - All tests: `before_each/after_each` with full state reset. No scene-tree dependency beyond ContactManager node.
    - Signature: ~150 lines. 10 tests, all self-contained.

  ### PHASE 5: Validation

  - [x] VERIFICATION_1: Project loads in Godot 3.6 with 0 errors — run `get_errors()` across all modified/new files
  - [x] VERIFICATION_2: GUT test suite — `test_contact_manager.gd` passes (0 failures, 0 errors). Existing simulation tests still pass.
  - [x] VERIFICATION_3: Manual — launch game, press F3 debug panel Tick button, verify radar display shows agents with correct disposition colors matching F3 panel agent data
  - [x] VERIFICATION_4: Manual — dock/undock at station, verify radar + sector panel refresh after sim tick
  - [x] VERIFICATION_5: Manual — Run 30 ticks via F3 batch button, verify sector info panel updates (world age timer changes, economy/security tags may shift)
