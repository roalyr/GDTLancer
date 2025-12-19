# Content Creation Manual

**GDTLancer Designer & Artist Guide**  
**Version:** 1.1  
**Date:** 2025-12-19  

---

## Table of Contents

1. [Overview](#1-overview)
2. [Directory Structure Reference](#2-directory-structure-reference)
3. [How to Add New Content](#3-how-to-add-new-content)
   - [Adding a New Ship](#31-adding-a-new-ship)
   - [Adding a New Commodity](#32-adding-a-new-commodity)
   - [Adding a New Weapon/Tool](#33-adding-a-new-weapontool)
   - [Adding a New Location](#34-adding-a-new-location)
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
│   ├── location_template.gd           # Stations, planets, etc.
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
│   ├── locations/        # station_*.tres
│   ├── quirks/           # quirk_*.tres (Sprint 11)
│   ├── weapons/          # weapon_*.tres
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
├── id: "ship_corsair"
├── display_name: "Corsair"
├── description: "A nimble interceptor built for speed"
├── base_value: 50000
├── mass: 800.0
├── max_hull: 150
├── max_speed: 400.0
├── acceleration: 0.7
├── turn_rate: 1.2
├── hardpoint_count: 2
├── cargo_capacity: 20
└── model_path: "res://assets/models/ships/Corsair.glb"
```

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
├── id: "commodity_quantum_crystals"
├── display_name: "Quantum Crystals"
├── description: "Rare crystals used in FTL drives"
├── base_value: 5000
├── mass: 0.1
├── is_illegal: false
├── category: "luxury"
└── volatility: 0.3  (price fluctuation factor)
```

#### Step 2: ART - (Optional) Add Icon

1. Create 64x64 PNG icon
2. Save to `/assets/art/ui/commodities/icon_quantum_crystals.png`
3. Reference in the .tres: `icon_path: "res://assets/art/ui/commodities/icon_quantum_crystals.png"`

---

### 3.3 Adding a New Weapon/Tool

**Example: Creating "Plasma Cutter" - mining tool**

#### Step 1: DATA - Create Weapon Definition

1. Navigate to `/database/registry/weapons/`
2. Duplicate `weapon_ablative_laser.tres` → `weapon_plasma_cutter.tres`
3. Edit:

```
[Resource - UtilityToolTemplate]
├── id: "weapon_plasma_cutter"
├── display_name: "Plasma Cutter"
├── description: "Industrial cutting tool, useful for mining"
├── tool_type: "mining"  # or "weapon", "utility"
├── damage: 15
├── range: 500.0
├── fire_rate: 2.0
├── energy_cost: 10
├── heat_generation: 25
└── base_value: 8000
```

---

### 3.4 Adding a New Location

**Example: Creating "Nexus Station" - a trading hub**

#### Step 1: DATA - Create Location Definition

1. Navigate to `/database/registry/locations/`
2. Duplicate `station_alpha.tres` → `station_nexus.tres`
3. Edit:

```
[Resource - LocationTemplate]
├── id: "station_nexus"
├── display_name: "Nexus Station"
├── description: "The galaxy's premier trading hub"
├── location_type: "station"
├── faction: "traders_guild"
├── services: ["trade", "refuel", "repair", "contracts"]
├── danger_level: 0
├── trade_goods: ["commodity_tech", "commodity_luxury", "commodity_quantum_crystals"]
└── position: Vector3(5000, 0, 3000)  # World coordinates
```

#### Step 2: PREFAB - Create Station Scene (if unique visuals)

1. Inherit from `/scenes/prefabs/station/DockableStation.tscn`
2. Add custom meshes, collision shapes
3. Save as `/scenes/prefabs/station/NexusStation.tscn`
4. Reference in .tres: `scene_path: "res://scenes/prefabs/station/NexusStation.tscn"`

---

### 3.5 Adding a New Contract

**Example: Creating a cargo delivery mission**

#### Step 1: DATA - Create Contract Definition

1. Navigate to `/database/registry/contracts/`
2. Duplicate `delivery_01.tres` → `delivery_nexus_run.tres`
3. Edit:

```
[Resource - ContractTemplate]
├── id: "delivery_nexus_run"
├── display_name: "Nexus Supply Run"
├── description: "Deliver quantum crystals to Nexus Station"
├── contract_type: "delivery"
├── cargo_type: "commodity_quantum_crystals"
├── cargo_amount: 10
├── origin_location: "station_alpha"
├── destination_location: "station_nexus"
├── time_limit_tu: 500  # Time Units
├── reward_credits: 25000
├── reputation_reward: 50
├── danger_level: 1
└── required_reputation: 100
```

---

### 3.6 Adding a New Character

**Example: Creating a merchant NPC**

#### Step 1: DATA - Create Character Definition

1. Navigate to `/database/registry/characters/`
2. Duplicate `character_default.tres` → `character_merchant_kane.tres`
3. Edit:

```
[Resource - CharacterTemplate]
├── id: "character_merchant_kane"
├── display_name: "Merchant Kane"
├── description: "A shrewd trader with connections everywhere"
├── profession: "merchant"
├── faction: "traders_guild"
├── starting_credits: 100000
├── starting_reputation: 500
├── skills:
│   ├── piloting: 3
│   ├── trading: 8
│   ├── combat: 2
│   └── diplomacy: 6
└── portrait_path: "res://assets/art/portraits/kane.png"
```

---

### 3.7 Adding a New Agent Type

**Example: Creating a pirate patrol NPC**

#### Step 1: DATA - Create Agent Definition

1. Navigate to `/database/registry/agents/`
2. Duplicate `npc_hostile_default.tres` → `npc_pirate_patrol.tres`
3. Edit:

```
[Resource - AgentTemplate]
├── id: "npc_pirate_patrol"
├── display_name: "Pirate Patrol"
├── character_template: "character_pirate"  # Reference another template
├── ship_template: "ship_corsair"           # Ship they fly
├── behavior: "patrol_hostile"
├── spawn_weight: 0.3  # Spawn probability
├── loot_table: ["commodity_ore", "commodity_tech"]
└── aggression: 0.8
```

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
DEFAULT_MAX_MOVE_SPEED = 300.0
DEFAULT_ACCELERATION = 0.5
DEFAULT_DECELERATION = 0.5
DEFAULT_MAX_TURN_SPEED = 0.75
DEFAULT_ALIGNMENT_ANGLE_THRESHOLD = 45  # degrees

# Time System
TIME_CLOCK_MAX_TU = 60
TIME_TICK_INTERVAL_SECONDS = 1.0
```

### 4.2 PID Controller Tuning

PID controllers handle smooth ship movement and camera follow. Located in:
**`/src/core/utils/pid_controller.gd`**

Default values are set per-instance in scenes. To adjust globally:

| Controller | File | Parameters |
|------------|------|------------|
| Ship Rotation | `navigation_system.gd` | `Kp=2.0, Ki=0.1, Kd=0.5` |
| Camera Rotation | `camera_rotation_controller.gd` | `Kp=3.0, Ki=0.0, Kd=1.0` |
| Camera Zoom | `camera_zoom_controller.gd` | `Kp=5.0, Ki=0.2, Kd=0.8` |

**Tuning Tips:**
- **Kp** (Proportional): Higher = faster response, too high = oscillation
- **Ki** (Integral): Eliminates steady-state error, too high = overshoot
- **Kd** (Derivative): Dampens oscillation, too high = sluggish

### 4.3 Economy Balance

Commodity prices are set per-item in their `.tres` files. Market dynamics:
- `base_value`: Starting price
- `volatility`: How much prices fluctuate (0.0-1.0)
- Station `trade_goods` array determines what's available where

### 4.4 Combat Balance

Weapon stats in `/database/registry/weapons/`:
- `damage`: Hull damage per hit
- `fire_rate`: Shots per second
- `energy_cost`: Power drain per shot
- `heat_generation`: Thermal buildup

Ship defensive stats in `/database/registry/assets/ships/`:
- `max_hull`: Total hit points
- `shield_capacity`: Shield pool (if implemented)
- `armor`: Damage reduction

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
4. Run the game and check the console for errors

### 6.2 Runtime Testing

To test a new ship in-game:
```gdscript
# In any test scene or debug console:
var ship_data = TemplateDatabase.get_template("ship_corsair")
print(ship_data.display_name)  # Should print "Corsair"
```

### 6.3 GUT Unit Tests

For programmers: Add tests in `/src/tests/data/` to validate template loading.

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
| Add a weapon | `/database/registry/weapons/` | `weapon_ablative_laser.tres` |
| Add a station | `/database/registry/locations/` | `station_alpha.tres` |
| Add a contract | `/database/registry/contracts/` | `delivery_01.tres` |
| Add a character | `/database/registry/characters/` | `character_default.tres` |
| Add an NPC type | `/database/registry/agents/` | `npc_default.tres` |
| Add a 3D model | `/assets/models/ships/` | N/A (just import .glb) |
| Add a texture | `/assets/art/textures/` | N/A (just import .png) |
| Add a UI icon | `/assets/art/ui/` | N/A (just import .png) |

---

**END OF CONTENT CREATION MANUAL**
