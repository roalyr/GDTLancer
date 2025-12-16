# Migration Plan: Prototype → Production Structure

**Version:** 1.0  
**Date:** 2025-12-16  
**Status:** DRAFT - Review Before Execution

---

## 1. Executive Summary

This document defines the migration from the current deeply-nested, mixed asset/logic structure to a clean "Modder-Friendly" workspace layout that separates:

- **Logic** (`/src`) - Pure GDScript files
- **Art** (`/assets`) - Raw visual assets (textures, models, shaders)
- **Data** (`/database`) - Game definitions, configurations, and resource instances
- **Scenes** (`/scenes`) - Composed .tscn files

---

## 2. Target Directory Structure

```
GDTLancer/
├── src/                          # ALL .gd logic files
│   ├── autoload/                 # Singleton scripts
│   ├── core/
│   │   ├── agents/               # Agent logic
│   │   │   └── components/       # Movement, Navigation, Weapons
│   │   ├── systems/              # Game systems (inventory, combat, etc.)
│   │   ├── ui/                   # UI controller scripts
│   │   └── utils/                # Utilities (PID controller, etc.)
│   ├── modules/
│   │   └── piloting/             # Ship control, player input states
│   └── tests/                    # All test files remain .gd
│
├── assets/                       # RAW art only
│   ├── art/
│   │   ├── effects/              # Particle materials, curves
│   │   ├── materials/            # .tres material definitions
│   │   ├── shaders/              # .gdshader and shader .tres
│   │   ├── textures/             # .png, noise packs
│   │   └── ui/                   # UI textures (buttons, icons)
│   ├── fonts/                    # Font files (.ttf, .fnt)
│   ├── models/                   # 3D models (.glb, .blend)
│   └── themes/                   # UI themes (.tres)
│
├── database/                     # GAME DATA only
│   ├── definitions/              # Template scripts that define resource schemas
│   ├── registry/                 # Actual .tres instances
│   │   ├── actions/
│   │   ├── agents/
│   │   ├── assets/
│   │   │   ├── commodities/
│   │   │   ├── modules/
│   │   │   └── ships/
│   │   ├── characters/
│   │   ├── contracts/
│   │   ├── locations/
│   │   └── weapons/
│   └── config/                   # Tuning values, constants
│
├── scenes/                       # ALL composed .tscn files
│   ├── prefabs/                  # Reusable objects
│   │   ├── agents/               # player_agent.tscn, npc_agent.tscn, agent.tscn
│   │   ├── camera/               # orbit_camera.tscn
│   │   └── station/              # DockableStation.tscn
│   ├── ui/                       # UI layouts
│   │   ├── hud/                  # main_hud.tscn
│   │   ├── menus/                # main_menu.tscn, station_menu/
│   │   └── screens/              # inventory, character_status, action_check
│   └── levels/                   # World chunks
│       ├── zones/                # basic_flight_zone.tscn
│       └── game_world/           # main_game_scene.tscn
│
├── addons/                       # Third-party (unchanged)
├── tests/                        # Test data files (non-.gd)
│   └── data/
└── [project files]               # project.godot, etc.
```

---

## 3. Folder Migration Manifest

### 3.1 SOURCE → DESTINATION MAPPING

| Current Path | New Path | Type | Notes |
|-------------|----------|------|-------|
| `autoload/` | `src/autoload/` | MOVE | All .gd files |
| `core/resource/` | `database/definitions/` | MOVE | Template definition scripts |
| `core/systems/` | `src/core/systems/` | MOVE | All system .gd files |
| `core/utils/` | `src/core/utils/` | MOVE | pid_controller, etc. |
| `core/agents/*.gd` | `src/core/agents/` | SPLIT | Scripts only |
| `core/agents/*.tscn` | `scenes/prefabs/agents/` | SPLIT | Scenes only |
| `core/agents/components/` | `src/core/agents/components/` | MOVE | All .gd files |
| `core/ui/action_check/*.gd` | `src/core/ui/action_check/` | SPLIT | Scripts |
| `core/ui/action_check/*.tscn` | `scenes/ui/screens/` | SPLIT | Scenes |
| `core/ui/character_status/*.gd` | `src/core/ui/character_status/` | SPLIT | Scripts |
| `core/ui/character_status/*.tscn` | `scenes/ui/screens/` | SPLIT | Scenes |
| `core/ui/inventory_screen/*.gd` | `src/core/ui/inventory_screen/` | SPLIT | Scripts |
| `core/ui/inventory_screen/*.tscn` | `scenes/ui/screens/` | SPLIT | Scenes |
| `core/ui/main_hud/*.gd` | `src/core/ui/main_hud/` | SPLIT | Scripts |
| `core/ui/main_hud/*.tscn` | `scenes/ui/hud/` | SPLIT | Scenes |
| `core/ui/main_menu/*.gd` | `src/core/ui/main_menu/` | SPLIT | Scripts |
| `core/ui/main_menu/*.tscn` | `scenes/ui/menus/` | SPLIT | Scenes |
| `core/ui/ui_helper_classes/` | `src/core/ui/helpers/` | MOVE | Helper scripts |
| `modules/piloting/scripts/` | `src/modules/piloting/` | MOVE | All .gd files |
| `scenes/camera/*.gd` | `src/scenes/camera/` | SPLIT | Scripts |
| `scenes/camera/*.tscn` | `scenes/prefabs/camera/` | SPLIT | Scenes |
| `scenes/camera/components/` | `src/scenes/camera/components/` | MOVE | .gd files |
| `scenes/game_world/*.gd` | `src/scenes/game_world/` | SPLIT | Scripts |
| `scenes/game_world/*.tscn` | `scenes/levels/game_world/` | SPLIT | main_game_scene.tscn |
| `scenes/game_world/station/*.gd` | `src/scenes/game_world/station/` | SPLIT | Scripts |
| `scenes/game_world/station/*.tscn` | `scenes/prefabs/station/` | SPLIT | Scenes |
| `scenes/game_world/world_manager/` | `src/scenes/game_world/world_manager/` | MOVE | All .gd files |
| `scenes/ui/station_menu/*.gd` | `src/scenes/ui/station_menu/` | SPLIT | Scripts |
| `scenes/ui/station_menu/*.tscn` | `scenes/ui/menus/station_menu/` | SPLIT | Scenes |
| `scenes/zones/*.tscn` | `scenes/levels/zones/` | MOVE | Zone scenes |
| `scenes/zones/*.tres` | `database/registry/zones/` | MOVE | Zone resource data |
| `assets/data/` | `database/registry/` | MOVE | All .tres data files |
| `assets/art/` | `assets/art/` | KEEP | No change |
| `assets/models/` | `assets/models/` | KEEP | No change |
| `assets/fonts/` | `assets/fonts/` | KEEP | No change |
| `assets/themes/` | `assets/themes/` | KEEP | No change |
| `tests/` (structure) | `src/tests/` | RESTRUCTURE | See Section 3.3 |

### 3.2 SPLIT TARGETS (Detailed)

These folders contain BOTH `.gd` AND `.tscn` files that must be separated:

#### `core/agents/`
| File | Destination |
|------|-------------|
| `agent.gd` | `src/core/agents/agent.gd` |
| `agent.tscn` | `scenes/prefabs/agents/agent.tscn` |
| `npc_agent.tscn` | `scenes/prefabs/agents/npc_agent.tscn` |
| `player_agent.tscn` | `scenes/prefabs/agents/player_agent.tscn` |
| `components/` (all .gd) | `src/core/agents/components/` |

#### `core/ui/action_check/`
| File | Destination |
|------|-------------|
| `action_check.gd` | `src/core/ui/action_check/action_check.gd` |
| `action_check.tscn` | `scenes/ui/screens/action_check.tscn` |

#### `core/ui/character_status/`
| File | Destination |
|------|-------------|
| `character_status.gd` | `src/core/ui/character_status/character_status.gd` |
| `character_status.tscn` | `scenes/ui/screens/character_status.tscn` |

#### `core/ui/inventory_screen/`
| File | Destination |
|------|-------------|
| `inventory_screen.gd` | `src/core/ui/inventory_screen/inventory_screen.gd` |
| `inventory_screen.tscn` | `scenes/ui/screens/inventory_screen.tscn` |

#### `core/ui/main_hud/`
| File | Destination |
|------|-------------|
| `main_hud.gd` | `src/core/ui/main_hud/main_hud.gd` |
| `main_hud.tscn` | `scenes/ui/hud/main_hud.tscn` |

#### `core/ui/main_menu/`
| File | Destination |
|------|-------------|
| `main_menu.gd` | `src/core/ui/main_menu/main_menu.gd` |
| `main_menu.tscn` | `scenes/ui/menus/main_menu.tscn` |

#### `scenes/camera/`
| File | Destination |
|------|-------------|
| `orbit_camera.gd` | `src/scenes/camera/orbit_camera.gd` |
| `orbit_camera.tscn` | `scenes/prefabs/camera/orbit_camera.tscn` |
| `components/*.gd` | `src/scenes/camera/components/` |

#### `scenes/game_world/`
| File | Destination |
|------|-------------|
| `world_manager.gd` | `src/scenes/game_world/world_manager.gd` |
| `world_rendering.gd` | `src/scenes/game_world/world_rendering.gd` |
| `main_game_scene.tscn` | `scenes/levels/game_world/main_game_scene.tscn` |

#### `scenes/game_world/station/`
| File | Destination |
|------|-------------|
| `dockable_station.gd` | `src/scenes/game_world/station/dockable_station.gd` |
| `DockableStation.tscn` | `scenes/prefabs/station/DockableStation.tscn` |

#### `scenes/game_world/world_manager/`
| File | Destination |
|------|-------------|
| `template_indexer.gd` | `src/scenes/game_world/world_manager/template_indexer.gd` |
| `world_generator.gd` | `src/scenes/game_world/world_manager/world_generator.gd` |

#### `scenes/ui/station_menu/`
| File | Destination |
|------|-------------|
| `station_menu.gd` | `src/scenes/ui/station_menu/station_menu.gd` |
| `trade_interface.gd` | `src/scenes/ui/station_menu/trade_interface.gd` |
| `contract_interface.gd` | `src/scenes/ui/station_menu/contract_interface.gd` |
| `StationMenu.tscn` | `scenes/ui/menus/station_menu/StationMenu.tscn` |
| `TradeInterface.tscn` | `scenes/ui/menus/station_menu/TradeInterface.tscn` |
| `ContractInterface.tscn` | `scenes/ui/menus/station_menu/ContractInterface.tscn` |

### 3.3 TEST FILE RESTRUCTURE

Tests mirror the source structure under `src/tests/`:

| Current Path | New Path |
|-------------|----------|
| `tests/autoload/` | `src/tests/autoload/` |
| `tests/core/` | `src/tests/core/` |
| `tests/modules/` | `src/tests/modules/` |
| `tests/scenes/` | `src/tests/scenes/` |
| `tests/helpers/` (*.gd) | `src/tests/helpers/` |
| `tests/helpers/` (*.tscn) | `src/tests/helpers/` (keep together for tests) |
| `tests/data/` | `tests/data/` (keep non-.gd test data) |

---

## 4. CRITICAL: Path References to Update

### 4.1 project.godot Changes

**Autoload paths:**
```
Constants="*res://autoload/Constants.gd"         → "*res://src/autoload/Constants.gd"
EventBus="*res://autoload/EventBus.gd"           → "*res://src/autoload/EventBus.gd"
GlobalRefs="*res://autoload/GlobalRefs.gd"       → "*res://src/autoload/GlobalRefs.gd"
TemplateDatabase="*res://autoload/TemplateDatabase.gd" → "*res://src/autoload/TemplateDatabase.gd"
GameState="*res://autoload/GameState.gd"         → "*res://src/autoload/GameState.gd"
CoreMechanicsAPI="*res://autoload/CoreMechanicsAPI.gd" → "*res://src/autoload/CoreMechanicsAPI.gd"
GameStateManager="*res://autoload/GameStateManager.gd" → "*res://src/autoload/GameStateManager.gd"
NarrativeOutcomes="*res://autoload/NarrativeOutcomes.gd" → "*res://src/autoload/NarrativeOutcomes.gd"
```

**Main scene:**
```
run/main_scene="res://scenes/game_world/main_game_scene.tscn" → "res://scenes/levels/game_world/main_game_scene.tscn"
```

**Global script classes (all paths in `_global_script_classes`):**
```
"path": "res://core/resource/action_template.gd"   → "res://database/definitions/action_template.gd"
"path": "res://core/resource/agent_template.gd"    → "res://database/definitions/agent_template.gd"
"path": "res://core/resource/asset_template.gd"    → "res://database/definitions/asset_template.gd"
"path": "res://core/resource/character_template.gd" → "res://database/definitions/character_template.gd"
"path": "res://core/resource/asset_commodity_template.gd" → "res://database/definitions/asset_commodity_template.gd"
"path": "res://core/resource/contract_template.gd" → "res://database/definitions/contract_template.gd"
"path": "res://core/resource/location_template.gd" → "res://database/definitions/location_template.gd"
"path": "res://core/resource/asset_module_template.gd" → "res://database/definitions/asset_module_template.gd"
"path": "res://core/resource/asset_ship_template.gd" → "res://database/definitions/asset_ship_template.gd"
"path": "res://core/resource/template.gd"          → "res://database/definitions/template.gd"
"path": "res://core/resource/utility_tool_template.gd" → "res://database/definitions/utility_tool_template.gd"
"path": "res://core/utils/pid_controller.gd"       → "res://src/core/utils/pid_controller.gd"
"path": "res://core/ui/ui_helper_classes/CenteredGrowingLabel.gd" → "res://src/core/ui/helpers/CenteredGrowingLabel.gd"
"path": "res://scenes/camera/components/camera_position_controller.gd" → "res://src/scenes/camera/components/camera_position_controller.gd"
"path": "res://scenes/camera/components/camera_rotation_controller.gd" → "res://src/scenes/camera/components/camera_rotation_controller.gd"
"path": "res://scenes/camera/components/camera_zoom_controller.gd"     → "res://src/scenes/camera/components/camera_zoom_controller.gd"
"path": "res://modules/piloting/scripts/player_input_states/state_base.gd" → "res://src/modules/piloting/player_input_states/state_base.gd"
```

### 4.2 GDScript load()/preload() Changes

**Critical files with hardcoded paths:**

#### `autoload/Constants.gd`
```gdscript
# OLD → NEW
PLAYER_AGENT_SCENE_PATH = "res://core/agents/player_agent.tscn"
    → "res://scenes/prefabs/agents/player_agent.tscn"
NPC_AGENT_SCENE_PATH = "res://core/agents/npc_agent.tscn"
    → "res://scenes/prefabs/agents/npc_agent.tscn"
INITIAL_ZONE_SCENE_PATH = "res://scenes/zones/basic_flight_zone.tscn"
    → "res://scenes/levels/zones/basic_flight_zone.tscn"
PLAYER_DEFAULT_TEMPLATE_PATH = "res://assets/data/agents/player_default.tres"
    → "res://database/registry/agents/player_default.tres"
NPC_TRAFFIC_TEMPLATE_PATH = "res://assets/data/agents/npc_default.tres"
    → "res://database/registry/agents/npc_default.tres"
NPC_HOSTILE_TEMPLATE_PATH = "res://assets/data/agents/npc_hostile_default.tres"
    → "res://database/registry/agents/npc_hostile_default.tres"
MAIN_HUD_SCENE_PATH = "res://core/ui/main_hud.tscn"
    → "res://scenes/ui/hud/main_hud.tscn"
```

#### `autoload/GameStateManager.gd`
```gdscript
const InventorySystem = preload("res://core/systems/inventory_system.gd")
    → preload("res://src/core/systems/inventory_system.gd")
```

#### `core/agents/agent.gd`
```gdscript
ship_template = load("res://assets/data/assets/ships/ship_hostile_default.tres")
    → load("res://database/registry/assets/ships/ship_hostile_default.tres")
```

#### `core/agents/components/navigation_system.gd`
```gdscript
const PIDControllerScript = preload("res://core/utils/pid_controller.gd")
    → preload("res://src/core/utils/pid_controller.gd")
```

#### `core/agents/components/weapon_controller.gd`
```gdscript
const UtilityToolTemplate = preload("res://core/resource/utility_tool_template.gd")
    → preload("res://database/definitions/utility_tool_template.gd")
```

#### `core/systems/combat_system.gd`
```gdscript
const UtilityToolTemplate = preload("res://core/resource/utility_tool_template.gd")
    → preload("res://database/definitions/utility_tool_template.gd")
```

#### `core/systems/contract_system.gd`
```gdscript
const InventorySystem = preload("res://core/systems/inventory_system.gd")
    → preload("res://src/core/systems/inventory_system.gd")
```

#### `core/ui/inventory_screen/inventory_screen.gd`
```gdscript
const InventorySystem = preload("res://core/systems/inventory_system.gd")
    → preload("res://src/core/systems/inventory_system.gd")
```

#### `core/ui/main_hud/main_hud.gd`
```gdscript
const StationMenuScene = preload("res://scenes/ui/station_menu/StationMenu.tscn")
    → preload("res://scenes/ui/menus/station_menu/StationMenu.tscn")
const ActionCheckScene = preload("res://core/ui/action_check/action_check.tscn")
    → preload("res://scenes/ui/screens/action_check.tscn")
```

#### `modules/piloting/scripts/player_controller_ship.gd`
```gdscript
const StateBase = preload("res://modules/piloting/scripts/player_input_states/state_base.gd")
    → preload("res://src/modules/piloting/player_input_states/state_base.gd")
const StateDefault = preload("res://modules/piloting/scripts/player_input_states/state_default.gd")
    → preload("res://src/modules/piloting/player_input_states/state_default.gd")
```

#### `scenes/camera/orbit_camera.gd`
```gdscript
const ZoomControllerScript = preload("res://scenes/camera/components/camera_zoom_controller.gd")
    → preload("res://src/scenes/camera/components/camera_zoom_controller.gd")
```

#### `scenes/camera/components/camera_rotation_controller.gd`
```gdscript
const PIDControllerScript = preload("res://core/utils/pid_controller.gd")
    → preload("res://src/core/utils/pid_controller.gd")
```

#### `scenes/game_world/world_manager.gd`
```gdscript
const TemplateIndexer = preload("res://scenes/game_world/world_manager/template_indexer.gd")
    → preload("res://src/scenes/game_world/world_manager/template_indexer.gd")
const WorldGenerator = preload("res://scenes/game_world/world_manager/world_generator.gd")
    → preload("res://src/scenes/game_world/world_manager/world_generator.gd")
```

#### `scenes/game_world/world_manager/world_generator.gd`
```gdscript
const InventorySystem = preload("res://core/systems/inventory_system.gd")
    → preload("res://src/core/systems/inventory_system.gd")
```

#### `scenes/ui/station_menu/station_menu.gd`
```gdscript
const TradeInterfaceScene = preload("res://scenes/ui/station_menu/TradeInterface.tscn")
    → preload("res://scenes/ui/menus/station_menu/TradeInterface.tscn")
const ContractInterfaceScene = preload("res://scenes/ui/station_menu/ContractInterface.tscn")
    → preload("res://scenes/ui/menus/station_menu/ContractInterface.tscn")
```

### 4.3 Resource Files (.tres) - Script References

All `.tres` files in `assets/data/` reference scripts via `ext_resource`. These paths will break:

```
[ext_resource path="res://core/resource/action_template.gd" ...]
    → "res://database/definitions/action_template.gd"

[ext_resource path="res://core/resource/agent_template.gd" ...]
    → "res://database/definitions/agent_template.gd"

[ext_resource path="res://core/resource/asset_commodity_template.gd" ...]
    → "res://database/definitions/asset_commodity_template.gd"

[ext_resource path="res://core/resource/asset_module_template.gd" ...]
    → "res://database/definitions/asset_module_template.gd"

[ext_resource path="res://core/resource/asset_ship_template.gd" ...]
    → "res://database/definitions/asset_ship_template.gd"

[ext_resource path="res://core/resource/character_template.gd" ...]
    → "res://database/definitions/character_template.gd"

[ext_resource path="res://core/resource/contract_template.gd" ...]
    → "res://database/definitions/contract_template.gd"

[ext_resource path="res://core/resource/location_template.gd" ...]
    → "res://database/definitions/location_template.gd"

[ext_resource path="res://core/resource/utility_tool_template.gd" ...]
    → "res://database/definitions/utility_tool_template.gd"
```

**Affected files:**
- `assets/data/actions/action_default.tres`
- `assets/data/agents/npc_default.tres`
- `assets/data/agents/npc_hostile_default.tres`
- `assets/data/agents/player_default.tres`
- `assets/data/assets/commodities/*.tres` (6 files)
- `assets/data/assets/modules/module_default.tres`
- `assets/data/assets/ships/*.tres` (2 files)
- `assets/data/characters/character_default.tres`
- `assets/data/contracts/*.tres` (6 files)
- `assets/data/locations/*.tres` (3 files)
- `assets/data/weapons/*.tres` (3 files)
- `tests/data/test_action.tres`

### 4.4 Scene Files (.tscn) - Script & Resource References

All `.tscn` files have `ext_resource` entries that need updating. Major files:

#### `scenes/game_world/main_game_scene.tscn`
All system scripts move from `core/systems/` to `src/core/systems/`.

#### `core/agents/agent.tscn`
```
[ext_resource path="res://core/agents/agent.gd" ...]
    → "res://src/core/agents/agent.gd"
[ext_resource path="res://core/agents/components/movement_system.gd" ...]
    → "res://src/core/agents/components/movement_system.gd"
[ext_resource path="res://core/agents/components/navigation_system.gd" ...]
    → "res://src/core/agents/components/navigation_system.gd"
```

#### `core/agents/player_agent.tscn` & `npc_agent.tscn`
```
[ext_resource path="res://modules/piloting/scripts/player_controller_ship.gd" ...]
    → "res://src/modules/piloting/player_controller_ship.gd"
[ext_resource path="res://modules/piloting/scripts/ship_controller_ai.gd" ...]
    → "res://src/modules/piloting/ship_controller_ai.gd"
[ext_resource path="res://core/agents/components/weapon_controller.gd" ...]
    → "res://src/core/agents/components/weapon_controller.gd"
```

### 4.5 Test Files - All paths need updating

**Files with preload/load statements:**
- `tests/autoload/test_event_bus.gd`
- `tests/autoload/test_game_state_manager.gd`
- `tests/core/systems/test_*.gd` (all files)
- `tests/core/agents/components/test_*.gd` (all files)
- `tests/core/utils/test_pid_controller.gd`
- `tests/modules/piloting/test_ship_controller_ai.gd`
- `tests/scenes/test_*.gd` (all files)
- `tests/scenes/game_world/world_manager/test_*.gd`

---

## 5. Migration Execution Order

### Phase 1: Create New Directory Structure
```bash
mkdir -p src/{autoload,core/{agents/components,systems,ui/{action_check,character_status,inventory_screen,main_hud,main_menu,helpers},utils},modules/piloting/player_input_states,scenes/{camera/components,game_world/{station,world_manager},ui/station_menu},tests/{autoload,core/{agents/components,systems,utils},modules/piloting,scenes/game_world/world_manager,helpers}}
mkdir -p database/{definitions,registry/{actions,agents,assets/{commodities,modules,ships},characters,contracts,locations,weapons,zones},config}
mkdir -p scenes/{prefabs/{agents,camera,station},ui/{hud,menus/station_menu,screens},levels/{zones,game_world}}
```

### Phase 2: Move Files (Ordered by Dependency)
1. **Definition scripts first** (no dependencies)
2. **Utility scripts** (pid_controller, etc.)
3. **System scripts** (depend on definitions)
4. **Component scripts** (depend on systems)
5. **Controller scripts** (depend on components)
6. **UI scripts** (depend on systems)
7. **Autoload scripts** (depend on all above)
8. **Scene files** (.tscn)
9. **Resource files** (.tres)

### Phase 3: String Replacement
Run find-and-replace across all files for each path change.

### Phase 4: Update project.godot
Manually update autoload paths and global script class paths.

### Phase 5: Test
Run full GUT test suite to verify nothing broke.

---

## 6. Rollback Plan

Before starting migration:
1. Create a git branch: `git checkout -b migration/production-structure`
2. Commit current state
3. If migration fails: `git checkout main`

---

## 7. Post-Migration Verification Checklist

- [ ] Project loads without errors
- [ ] Main scene runs
- [ ] All autoloads initialize
- [ ] GUT tests pass
- [ ] No orphaned files in old locations
- [ ] All .tres files load correctly
- [ ] All scenes instantiate correctly

---

## 8. Files NOT to Move

| Path | Reason |
|------|--------|
| `addons/` | Third-party plugin, maintain original structure |
| `project.godot` | Root project file |
| `default_env.tres` | Root environment |
| `export_presets.cfg` | Export configuration |
| `*.md` (root) | Documentation |
| `*.sh` (root) | Build scripts |
| `Icon.png`, `Splash.png` | Root assets |

---

**END OF MIGRATION PLAN**
