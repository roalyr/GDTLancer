<!--
PROJECT: GDTLancer
MODULE: TRUTH_CONTENT-CREATION-MANUAL.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TRUTH_SIMULATION-GRAPH.md §2.1, §6.4; TACTICAL_TODO.md TASK_1
LOG_REF: 2026-05-23 17:23:21
-->

# Content Creation Manual

**GDTLancer Designer & Artist Guide**  
**Version:** 1.4
**Date:** 2026-05-23

---

## Table of Contents

1. [Overview](#1-overview)
2. [Directory Structure Reference](#2-directory-structure-reference)
3. [How to Add New Content](#3-how-to-add-new-content)
   - [Adding a New Ship](#31-adding-a-new-ship)
   - [Adding a New Commodity](#32-adding-a-new-commodity)
   - [Adding a New Tool](#33-adding-a-new-tool)
    - [Adding a New Sector / Location](#34-adding-a-new-sector--location)
   - [Adding a New Contract](#35-adding-a-new-contract)
   - [Adding a New Character](#36-adding-a-new-character)
   - [Adding a New Agent Type](#37-adding-a-new-agent-type)
4. [Tuning & Balance](#4-tuning--balance)
5. [Art Pipeline](#5-art-pipeline)
6. [Testing Your Content](#6-testing-your-content)
7. [Common Mistakes](#7-common-mistakes)

---

## 1. Overview

This manual is for **Designers** and **Artists** who want to add or modify game content without touching engine code. The project separates:

| Folder | Contains | Who Edits |
|--------|----------|-----------|
| `/src` | Game logic (.gd scripts) | Programmers |
| `/assets` | Raw art files (.png, .glb, .gdshader) | Artists |
| `/database` | Game data definitions & instances | Designers |
| `/scenes` | Composed scenes (.tscn) | Both |

**Your primary workspace is `/database` and `/assets`.**

For world authoring, treat every file in `/database/registry/locations/` as a **sector-level registry resource** keyed by ids such as `sector_system_elace`. Dockable stations and other interactables live inside the referenced sector scene.

---

## 2. Directory Structure Reference

### `/database` - Game Data

```
database/
├── definitions/          # Template SCRIPTS (defines what fields exist)
│   ├── template.gd                    # Base template class
│   ├── action_template.gd             # Action definitions
│   ├── agent_template.gd              # NPC/Player agent definitions
│   ├── anchor_template.gd             # Patrol anchor points (Sprint 12)
│   ├── asset_template.gd              # Base asset class
│   ├── asset_commodity_template.gd    # Tradeable goods
│   ├── asset_module_template.gd       # Ship modules
│   ├── asset_ship_template.gd         # Ship hulls
│   ├── character_template.gd          # Character stats
│   ├── contract_template.gd           # Mission/contract definitions
│   ├── location_template.gd           # Sector/location contract used by registry/locations
│   ├── quirk_template.gd              # Ship quirks (Sprint 11)
│   └── utility_tool_template.gd       # Weapons and tools
│
├── registry/             # DATA INSTANCES (.tres files you create)
│   ├── actions/          # action_*.tres
│   ├── agents/           # player_default.tres, npc_*.tres
│   ├── assets/
│   │   ├── commodities/  # commodity_*.tres
│   │   ├── modules/      # module_*.tres
│   │   └── ships/        # ship_*.tres
│   ├── characters/       # character_*.tres
│   ├── contracts/        # delivery_*.tres, combat_*.tres, etc.
│   ├── locations/        # sector_system_*.tres, sector_runtime_*.tres
│   ├── quirks/           # quirk_*.tres (Sprint 11)
│   ├── tools/            # tool_*.tres
│   └── zones/            # Zone configuration data
│
└── config/               # Global tuning values
    └── (constants, PID tuning, balance spreadsheets)
```

### `/assets` - Art Assets

```
assets/
├── art/
│   ├── effects/          # Particle materials
│   ├── materials/        # Standard materials (.tres)
│   ├── shaders/          # .gdshader files
│   ├── textures/         # .png texture files
│   └── ui/               # UI graphics
│       ├── controls/     # HUD buttons, icons
│       ├── main_menu/    # Menu graphics
│       └── class_labels/ # Editor icons
│
├── fonts/                # .ttf font files
│   └── Roboto_Condensed/
│
├── models/               # 3D models
│   ├── nebulas/          # Environment meshes
│   ├── ships/            # Ship models (.glb)
│   └── sprites/          # Billboard sprites
│
└── themes/               # UI themes
    └── main_theme.tres
```

### `/scenes` - Composed Scenes

```
scenes/
├── prefabs/              # Reusable object templates
│   ├── agents/           # player_agent.tscn, npc_agent.tscn
│   ├── camera/           # orbit_camera.tscn
│   └── station/          # DockableStation.tscn
│
├── ui/                   # User interface
│   ├── hud/              # main_hud.tscn
│   ├── menus/            # main_menu.tscn, station_menu/
│   └── screens/          # inventory, character_status, etc.
│
└── levels/               # Playable areas
    ├── sectors/          # sector_system_elace/, sector_system_cob/, etc.
    ├── zones/            # basic_flight_zone.tscn
    └── game_world/       # main_game_scene.tscn
```

---

## 3. How to Add New Content

### 3.1 Adding a New Ship

**Example: Creating "Corsair" - a fast combat ship**

#### Step 1: ART - Add the 3D Model

1. Export your ship model as `.glb` from Blender
2. Place it in: `/assets/models/ships/Corsair.glb`
3. Godot will auto-import it

#### Step 2: DATA - Create Ship Definition

1. Navigate to `/database/registry/assets/ships/`
2. Duplicate `ship_default.tres` → rename to `ship_corsair.tres`
3. Open in Godot Inspector and edit:

```
[Resource - ShipTemplate]
├── template_id: "ship_corsair"
├── asset_type: "ship"
├── asset_icon_id: "icon_ship_corsair"
├── ship_model_name: "Corsair"
├── hull_integrity: 150
├── armor_integrity: 120
├── cargo_capacity: 20
├── interaction_radius: 18.0
├── tool_slots_small: 2
├── tool_slots_medium: 0
├── tool_slots_large: 0
├── equipped_tools: [ "tool_plasma_cutter" ]
├── power_capacity: 120.0
├── power_regen: 12.0
├── mass: 52000.0
├── linear_thrust: 6.5e+06
├── angular_thrust: 5.5e+06
└── alignment_threshold_angle_deg: 40.0
```

Live ship resources inherit `template_id` from `Template` and do **not** currently expose `display_name`, `description`, or `model_path`. Use `ship_model_name` as the authored label and keep scene/model hookup aligned with the existing ship prefab pipeline.

#### Step 3: PREFAB - (Optional) Create Variant Scene

If the ship needs unique behavior beyond stats:
1. Open `/scenes/prefabs/agents/agent.tscn`
2. Inherit scene: Scene → New Inherited Scene
3. Save as `/scenes/prefabs/agents/corsair_agent.tscn`
4. Customize node properties as needed

#### Step 4: Register (Automatic)

The `TemplateDatabase` autoload scans `/database/registry/` on startup. Your new ship will be available via:
```gdscript
var corsair = TemplateDatabase.get_template("ship_corsair")
```

---

### 3.2 Adding a New Commodity

**Example: Creating "Quantum Crystals" - rare luxury goods**

#### Step 1: DATA - Create Commodity Definition

1. Navigate to `/database/registry/assets/commodities/`
2. Duplicate `commodity_default.tres` → `commodity_quantum_crystals.tres`
3. Edit in Inspector:

```
[Resource - CommodityTemplate]
├── template_id: "commodity_quantum_crystals"
├── asset_type: "commodity"
├── asset_icon_id: "icon_quantum_crystals"
├── commodity_name: "Quantum Crystals"
├── base_value: 5000
```

The live `CommodityTemplate` is intentionally minimal right now. If you need fields such as legality, volatility, or category, add them to the definition script first rather than inventing ad hoc `.tres` keys.

#### Step 2: ART - (Optional) Add Icon

1. Create 64x64 PNG icon
2. Save to `/assets/art/ui/commodities/icon_quantum_crystals.png`
3. Reference the icon through `asset_icon_id = "icon_quantum_crystals"` (or the current UI icon lookup used by the consuming scene); the live commodity template does not expose a direct `icon_path` field

---

### 3.3 Adding a New Tool

**Example: Creating "Plasma Cutter" - mining tool**

#### Step 1: DATA - Create Tool Definition

1. Navigate to `/database/registry/tools/`
2. Duplicate `tool_ablative_laser.tres` → `tool_plasma_cutter.tres`
3. Edit:

```
[Resource - UtilityToolTemplate]
├── template_id: "tool_plasma_cutter"
├── tool_name: "Plasma Cutter"
├── description: "Industrial cutting tool, useful for mining"
├── tool_type: "mining"  # or "weapon", "utility"
├── damage: 15.0
├── range_effective: 120.0
├── range_max: 180.0
├── fire_rate: 2.0
├── energy_per_shot: 10.0
├── warmup_time: 0.2
├── mount_size: "small"
└── power_draw: 12.0
```

The live `UtilityToolTemplate` uses `range_effective` / `range_max` and `energy_per_shot` / `power_draw`. There is no `base_value` or `heat_generation` field on the current definition.

---

### 3.4 Adding a New Sector / Location

**Canonical model:** each entry in `/database/registry/locations/` is a sector-level `LocationTemplate` resource. It owns the sector id, galactic position, topology, scene-loading path, and compatibility data used by the current docked UI and bootstrap flow.

**Example: Creating `sector_system_nexus` - a new colony hub sector**

#### Step 1: DATA - Create Sector Definition

1. Navigate to `/database/registry/locations/`
2. Duplicate `sector_system_elace.tres` → `sector_system_nexus.tres`
3. Edit the cloned resource in the Inspector:

```
[Resource - LocationTemplate]
├── template_id: "sector_system_nexus"
├── location_name: "Nexus System"
├── location_type: "system"
├── position_in_zone: Vector3(0, 0, 0)
├── interaction_radius: 0.0
├── sector_scene_path: "res://scenes/levels/sectors/sector_system_nexus/sector_system_nexus.tscn"
├── global_position: Vector3(120000, 15000, -240000)
├── connections: PoolStringArray("sector_system_elace", "sector_system_cob")
├── sector_type: "colony"
├── market_inventory:
│   ├── commodity_food: {buy_price: 24, sell_price: 19, quantity: 80}
│   └── commodity_tech: {buy_price: 72, sell_price: 58, quantity: 30}
├── available_services: ["trade", "contracts", "repair"]
├── controlling_faction_id: "faction_traders"
├── danger_level: 1
├── initial_sector_tags: PoolStringArray("STATION", "SECURE", "MILD")
└── available_contract_ids: ["delivery_nexus_run"]
```

Keep the other world-layer fields aligned with your chosen source template or tuned intentionally for the new sector: `radiation_level`, `thermal_background_k`, `gravity_well_penalty`, `mineral_density`, `propellant_sources`, `station_power_output`, and `stockpile_capacity` all feed the live sector contract.

**Use these live field names:**
- `template_id`, not `id`
- `location_name`, not `display_name`
- `sector_scene_path`, not `scene_path`
- `market_inventory`, not `trade_goods`
- `available_services`, not `services`
- `global_position`, not `position`

#### Step 2: SCENE - Create the Sector Scene

1. Create a folder under `/scenes/levels/sectors/`, for example `/scenes/levels/sectors/sector_system_nexus/`
2. Duplicate an existing sector scene folder such as `/scenes/levels/sectors/sector_system_elace/` if you want a handcrafted starting point
3. Save the main scene as `/scenes/levels/sectors/sector_system_nexus/sector_system_nexus.tscn`
4. Point `sector_scene_path` in the `.tres` to that main sector scene
5. Keep dockable stations and other interactables inside the sector scene itself; if a dockable station should satisfy docking/bootstrap lookups, its `location_id` must match the sector resource `template_id`

#### Step 3: Optional Procedural Sector Setup

If the sector should use the procedural fallback instead of a handcrafted scene:

1. Leave `sector_scene_path` empty
2. Set `is_procedural = true`
3. Fill `procedural_type` and `procedural_hints` with generator-facing context
4. Still author `global_position`, `connections`, and `sector_type` so topology and jump routing remain valid

---

### 3.5 Adding a New Contract

**Example: Creating a cargo delivery mission**

#### Step 1: DATA - Create Contract Definition

1. Navigate to `/database/registry/contracts/`
2. Duplicate `delivery_01.tres` → `delivery_nexus_run.tres`
3. Edit:

```
[Resource - ContractTemplate]
├── template_id: "delivery_nexus_run"
├── contract_type: "delivery"
├── title: "Nexus Supply Run"
├── description: "Deliver quantum crystals to Nexus System. Payment on delivery."
├── issuer_id: "trade_dispatch_nexus"
├── faction_id: "faction_traders"
├── origin_location_id: "sector_system_elace"
├── destination_location_id: "sector_system_nexus"
├── required_commodity_id: "commodity_quantum_crystals"
├── required_quantity: 10
├── time_limit_seconds: 500  # Seconds
├── reward_credits: 25000
├── reward_reputation: 50
└── difficulty: 2
```

Use `title`, `issuer_id`, `origin_location_id`, and `required_commodity_id` exactly as exported by `contract_template.gd`. The live template does not expose `display_name`, `cargo_type`, or `required_reputation`.

---

### 3.6 Adding a New Character

**Example: Creating a merchant NPC**

#### Step 1: DATA - Create Character Definition

1. Navigate to `/database/registry/characters/`
2. Duplicate `character_default.tres` → `character_merchant_kane.tres`
3. Edit:

```
[Resource - CharacterTemplate]
├── template_id: "character_merchant_kane"
├── character_name: "Merchant Kane"
├── character_icon_id: "character_merchant_kane"
├── description: "A shrewd trader with connections everywhere"
├── faction_id: "faction_traders"
├── credits: 100000
├── focus_points: 2
├── skills:
│   ├── piloting: 3
│   ├── trading: 8
│   └── combat: 2
├── reputation: 500
├── initial_condition_tag: "HEALTHY"
└── initial_wealth_tag: "WEALTHY"
```

The live character template is simulation-facing. It does not currently expose `profession`, `portrait_path`, or `starting_*` fields, so use `description`, `skills`, standing dictionaries, and the qualitative starting tags instead.

---

### 3.7 Adding a New Agent Type

**Example: Creating a persistent pirate NPC**

#### Step 1: DATA - Create Agent Definition

1. Navigate to `/database/registry/agents/`
2. Duplicate `npc_hostile_default.tres` → `persistent_pirate_patrol.tres`
3. Edit:

```
[Resource - AgentTemplate]
├── template_id: "persistent_pirate_patrol"
├── agent_type: "npc"
├── is_persistent: true
├── home_location_id: "sector_system_vidr"
├── character_template_id: "character_crow"
├── respawn_timeout_seconds: 300.0
├── agent_role: "pirate"
└── initial_tags: PoolStringArray("HEALTHY", "COMFORTABLE", "LOADED")
```

The live `AgentTemplate` is intentionally narrow: it links an agent to a character template, a home sector, persistence rules, and qualitative tags. It does **not** currently assign a ship template, loot table, spawn weight, or behavior string directly.

---

## 4. Tuning & Balance

### 4.1 Global Constants Location

All global tuning values live in: **`/src/autoload/Constants.gd`**

(After migration: `/database/config/constants.gd` or dedicated config files)

**Key Constants:**
```gdscript
# Action Check System
ACTION_CHECK_CRIT_THRESHOLD_CAUTIOUS = 14
ACTION_CHECK_SWC_THRESHOLD_CAUTIOUS = 10
ACTION_CHECK_CRIT_THRESHOLD_RISKY = 16
ACTION_CHECK_SWC_THRESHOLD_RISKY = 12

# Character Defaults
FOCUS_MAX_DEFAULT = 3
FOCUS_BOOST_PER_POINT = 1
DEFAULT_UPKEEP_COST = 5

# Movement/Physics
LINEAR_DRAG = 0.5
ANGULAR_DRAG = 2.0
DEFAULT_LINEAR_THRUST = 5e6
DEFAULT_ANGULAR_THRUST = 5e6
DEFAULT_SHIP_MASS = 6e4
DEFAULT_ALIGNMENT_ANGLE_THRESHOLD = 45.0

# Time System
WORLD_TICK_INTERVAL_SECONDS = 60
TIME_TICK_INTERVAL_SECONDS = 1.0
```

### 4.2 PID Controller Tuning

PID controllers handle smooth ship movement and camera follow. Located in:
**`/src/core/utils/pid_controller.gd`**

The live project does not keep one central "PID tuning table" in the manual. The actual gains come from the owning gameplay or camera script that instantiates the controller.

| Controller | File | Parameters |
|------------|------|------------|
| Ship rotation / stopping | `Constants.gd`, `movement_system.gd`, `navigation_system.gd` | `PID_ROTATION_*`, `PID_POSITION_*`, thrust constants, per-command handler behavior |
| Camera rotation | `orbit_camera.gd` + `camera_rotation_controller.gd` | `pid_yaw_*`, `pid_pitch_*`, `pid_integral_limit`, `_rotation_max_speed`, `_rotation_input_curve` |
| Camera zoom / FoV | `orbit_camera.gd` + `camera_zoom_controller.gd` | `distance`, `zoom_speed`, `min_distance_multiplier`, `max_distance_multiplier`, `min_fov_deg`, `max_fov_deg` |

When tuning, inspect the owning script first and treat the manual as orientation only. The script is the source of truth for the current gains and clamping rules.

**Tuning Tips:**
- **Kp** (Proportional): Higher = faster response, too high = oscillation
- **Ki** (Integral): Eliminates steady-state error, too high = overshoot
- **Kd** (Derivative): Dampens oscillation, too high = sluggish

### 4.3 Economy Balance

Commodity prices are set per-item in their `.tres` files. Sector-level availability and local pricing live on the `LocationTemplate` resource:
- `market_inventory`: per-sector commodity entries keyed by commodity template id using `{buy_price, sell_price, quantity}`
- `available_services`: docked UI service list currently exposed for that sector
- `stockpile_capacity`: sector hub capacity for local commodity storage assumptions

### 4.4 Combat Balance

Tool stats in `/database/registry/tools/`:
- `damage`: Hull damage per hit
- `fire_rate`: Shots per second
- `range_effective` / `range_max`: falloff window
- `energy_per_shot`: Power drain per shot
- `power_draw`: mount power requirement

Ship defensive stats in `/database/registry/assets/ships/`:
- `hull_integrity`: Total hit points
- `armor_integrity`: Armor durability
- `power_capacity` / `power_regen`: sustained tool budget
- `tool_slots_small` / `medium` / `large`: mount availability

---

## 5. Art Pipeline

### 5.1 3D Models (Ships, Stations)

**Format:** `.glb` (GLTF Binary)  
**Export Settings (Blender):**
- Apply all transforms
- Include: Mesh, Materials
- Exclude: Animations (unless needed), Cameras, Lights

**Naming Convention:**
- Ships: `ShipName.glb` (PascalCase)
- Stations: `StationName.glb`

**Material Notes:**
- Use Principled BSDF
- Godot will import materials, but consider using Godot shaders for special effects

### 5.2 Textures

**Format:** `.png`  
**Locations:**
- General: `/assets/art/textures/`
- UI: `/assets/art/ui/`

**Sizes:**
- UI Icons: 64x64 or 128x128
- Textures: Power of 2 (256, 512, 1024, 2048)

### 5.3 Shaders

**Format:** `.gdshader`  
**Location:** `/assets/art/shaders/`

**Material Instances:**
Create `.tres` ShaderMaterial files that reference shaders in `/assets/art/materials/`

### 5.4 UI Assets

**Button Icons:** `/assets/art/ui/controls/`
- Format: PNG with transparency
- Size: 64x64 recommended
- Naming: `button_actionname.png`

---

## 6. Testing Your Content

### 6.1 Quick Validation

After adding content:
1. Open Godot Editor
2. Open your `.tres` file in the Inspector
3. Check for red error icons (missing references)
4. If you added or changed a sector resource, confirm the id and scene path follow the canonical sector model (`sector_system_*`, `sector_scene_path`, `connections`, `global_position`)
5. Run the game and check the console for errors

### 6.2 Runtime Testing

To test a new sector resource in a debug console or temporary tool script:
```gdscript
var sector_data = TemplateDatabase.locations.get("sector_system_nexus")
print(sector_data.location_name)      # Should print "Nexus System"
print(sector_data.sector_scene_path)  # Should print the sector .tscn path
```

If `sector_scene_path` points to a handcrafted scene, load the project once with:

```bash
godot --no-window --quit
```

That catches missing scene references, bad script bindings, and node-path drift before wider playtesting.

### 6.3 GUT Unit Tests

For programmers or technical designers touching sector bootstrap or loading, use exact-file GUT runs so the suite stays narrow:

```bash
godot --no-window -s addons/gut/gut_cmdln.gd -gdir= -gtest=res://src/tests/core/systems/test_sector_loader.gd -gexit
godot --no-window -s addons/gut/gut_cmdln.gd -gdir= -gtest=res://src/tests/scenes/game_world/world_manager/test_world_manager.gd -gexit
```

---

## 7. Common Mistakes

### ❌ Wrong File Location
**Problem:** Placed `.tres` file in `/src/` instead of `/database/registry/`  
**Solution:** Only `.gd` scripts go in `/src/`

### ❌ Missing Script Reference
**Problem:** `.tres` file shows "Invalid script" error  
**Solution:** Ensure the resource's `script` property points to the correct definition file in `/database/definitions/`

### ❌ Hardcoded Paths
**Problem:** Used `"res://assets/data/..."` (old path)  
**Solution:** Use new paths: `"res://database/registry/..."`

### ❌ Station-Era Fields In A Sector Resource
**Problem:** Used `id`, `display_name`, `scene_path`, `services`, `trade_goods`, or `position` in `/database/registry/locations/*.tres`  
**Solution:** Use `template_id`, `location_name`, `sector_scene_path`, `available_services`, `market_inventory`, and `global_position`

### ❌ Non-Canonical Sector IDs
**Problem:** Created location resources named like `station_nexus` while the live registry/topology uses `sector_system_*` ids  
**Solution:** Author registry locations with canonical sector ids such as `sector_system_nexus`; keep individual stations inside the sector scene

### ❌ One-Way Connections
**Problem:** Added a new target to one sector's `connections` array but did not update the reciprocal sector  
**Solution:** Keep handcrafted sector connections synchronized unless the topology is intentionally one-way

### ❌ Dockable Station ID Mismatch
**Problem:** The sector scene contains a dockable station, but docking/bootstrap code cannot resolve it correctly  
**Solution:** Match the dockable station node's `location_id` to the sector resource `template_id`

### ❌ Pre-Stabilization Field Names In Non-Location Resources
**Problem:** Authored ships, tools, contracts, characters, or agents with legacy keys such as `display_name`, `range`, `cargo_type`, `profession`, `ship_template`, or `behavior`  
**Solution:** Check the matching script in `/database/definitions/` first and mirror only its exported fields. The examples in Sections 3.1 through 3.7 now use the live schema.

### ❌ Case Sensitivity
**Problem:** Resource ID "Ship_Corsair" doesn't match lookup "ship_corsair"  
**Solution:** Use consistent lowercase_snake_case for all IDs

### ❌ Circular Dependencies
**Problem:** Ship template references module that references ship  
**Solution:** Use ID strings for references, not direct resource loads

### ❌ Forgot to Save
**Problem:** Changes don't appear in-game  
**Solution:** Always Ctrl+S the `.tres` file after editing in Inspector

---

## Quick Reference Card

| I want to... | Create file in... | Based on template... |
|--------------|-------------------|---------------------|
| Add a ship | `/database/registry/assets/ships/` | `ship_default.tres` |
| Add a commodity | `/database/registry/assets/commodities/` | `commodity_default.tres` |
| Add a tool | `/database/registry/tools/` | `tool_ablative_laser.tres` |
| Add a sector/location | `/database/registry/locations/` | `sector_system_elace.tres` |
| Add a contract | `/database/registry/contracts/` | `delivery_01.tres` |
| Add a character | `/database/registry/characters/` | `character_default.tres` |
| Add an NPC type | `/database/registry/agents/` | `npc_default.tres` or a matching `persistent_*.tres` |
| Add a 3D model | `/assets/models/ships/` | N/A (just import .glb) |
| Add a texture | `/assets/art/textures/` | N/A (just import .png) |
| Add a UI icon | `/assets/art/ui/` | N/A (just import .png) |

---

**END OF CONTENT CREATION MANUAL**
