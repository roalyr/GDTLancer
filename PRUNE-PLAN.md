# GDTLancer — Prune Plan & Engine Freeze

**Branch:** `reboot/prune`
**Date:** 2026-10-17
**Status:** Active. This document supersedes `MODEL-CASCADE-PROTOCOL.md`, all `TRUTH_*` design docs, `STRATEGICAL-TODO.md`, `TACTICAL_TODO.md` and `SESSION-LOG.md`. Ignore the `OWNER` / `ACCESS` / `TRUTH_LINK` headers in source files; they are being retired.

---

## 1. Why

The project grew into many genres at once (flight, cards, crafting, degradation, companions, world simulation, meta-progression) and stalled. The new direction is a single, typical game done honestly:

> A harsh space game about fitting a ship from parts and taking it into dangerous sectors. There's a clear "right way" to play, and the rules are consistent enough to leave room for unorthodox approaches without designing for them.

Working template: *Pixel Dungeon in space, with EVE-style fitting.* Single-player. Short runs.

Guiding principles for anything kept or built:
- Rules are consistent and apply to everyone, AI included. No special-case scripted outcomes.
- Parts change **verbs**, not just numbers. Every part has a legitimate purpose.
- A few interacting rules, not many rules.
- The world reacts by its rules (e.g. predators weigh expected gain against risk) rather than by scripted moments.

Gameplay content (which parts, hulls and encounters) is **not** defined here. This document only covers pruning and the engine feature set.

---

## 2. Phases

1. **Prune:** remove everything outside the new direction (§3–§5). The project must open, run and fly in a sector at the end.
2. **Complete the engine:** build the missing features (§6).
3. **Freeze the engine:** after the freeze, work is content (parts, hulls, sectors, encounters), tuning, art and bug fixes only. New engine features need an explicit decision to unfreeze.

---

## 3. Keep

The flight core is already close to the target game.

**Flight and control**
- `src/core/agents/agent.gd`: keep. Remove the character/combat-registration coupling (see §5).
- `src/core/agents/components/movement_system.gd`: RigidBody + PID 6DOF thrust. Mass, thrust and torque come from the ship template, so fittings change handling automatically.
- `src/core/agents/components/navigation_system.gd` and `navigation_system/command_*.gd` (approach, orbit, flee, align, move, stop, idle). This is an EVE-like command set.
- `src/core/utils/pid_controller.gd`, `rotating_object.gd`, `editor_object.gd`
- `src/modules/piloting/player_controller_ship.gd` (simplify, §4) and `player_input_states/*`
- `src/modules/piloting/ship_controller_ai.gd`: patrol / combat / flee states, the base for predator AI.
- `src/core/agents/components/tool_controller.gd`: keep the structure; its combat hand-off is currently stubbed (see §6).
- `src/core/targeting/*`: targeting and route targets.

**Camera and HUD**
- `src/scenes/camera/**`, `scenes/prefabs/camera/orbit_camera.tscn`
- `src/core/ui/main_hud/*` (simplify), `scenes/ui/hud/main_hud.tscn`, `projected_target_bracket.tscn`
- `src/core/ui/radar_display/*`, `scenes/ui/hud/radar_display.tscn`
- `src/core/ui/main_menu/*`, `scenes/ui/menus/main_menu.tscn`
- `src/core/ui/helpers/*`, `scenes/ui/shared/*`
- `src/core/ui/debug_window/*`: keep if useful for tuning; strip simulation views.

**World and scenes**
- `src/scenes/game_world/world_manager.gd` + `world_manager/*` (simplify, §4)
- `src/scenes/game_world/jump_point.gd`, `jump_transition/*`, `starsphere_slot.gd`, `world_rendering.gd`, `station/dockable_station.gd`
- `src/core/systems/sector_loader.gd`, `agent_system.gd` (simplify), `asset_system.gd` (simplify)
- `scenes/prefabs/**` (agents, camera, celestial, navigation, ships, station)
- `scenes/levels/**` (all sector scenes, `main_game_scene.tscn` after cleanup)
- `scenes/environment/*`, `scenes/starspheres/*`

**Data**
- `database/definitions/template.gd`, `asset_template.gd`, `asset_ship_template.gd`, `asset_module_template.gd`, `utility_tool_template.gd`, `agent_template.gd`, `location_template.gd`, `game_start_template.gd`
- `database/registry/assets/ships/*`, `assets/modules/*`, `tools/*` (harpoon, drill and ablative laser fit the new direction)
- `database/registry/agents/player_default.tres`, `npc_default.tres`, `npc_hostile_default.tres`
- `database/registry/locations/*`, `game_starts/*`
- `src/autoload/Constants.gd`, `EventBus.gd`, `GlobalRefs.gd`, `TemplateDatabase.gd`, `GameState.gd`, `GameStateManager.gd` (all simplified, §4)

**Art and tooling**
- `assets/**` (shaders, materials, models, textures, fonts, themes)
- `tools/render_ship.py`, `tools/ship_tools`, `tools/renders`
- `addons/gut`, `addons/gdformat`
- `TRUTH_DOCS_*_Godot_3.6.md`: Godot reference docs. Move them to `docs/godot/` and drop the `TRUTH_` prefix.
- `LICENSE.md`, `AI-ACKNOWLEDGEMENT.md`, `Icon*`, `Splash*`, `export_presets.cfg`

---

## 4. Simplify

Keep the file and its structure, and remove the simulation-, board- or character-era parts.

| File | Remove | Keep |
|---|---|---|
| `GameState.gd` | World topology/tags/tracks, colony/security/economy progress, contracts, infestation, catastrophes, chronicle/rumours, sim ticks, world age, characters, npc_data | Current sector, player ship/fitting, player transform, run state |
| `GameStateManager.gd` | Serialisation of removed fields | New game / save / load of the kept fields |
| `GlobalRefs.gd` | `character_system`, `event_system`, `inventory_system`, `time_system`, `simulation_engine`, `contact_manager` | Player body, camera, world manager, zone, agent container, HUD, spawner, asset system |
| `Constants.gd` | Constants for removed systems (board, cards, sim, contracts, etc.) | Flight, camera, AI, rendering constants |
| `EventBus.gd` | Signals only used by removed systems | Flight, targeting, docking, jump, HUD, combat signals |
| `TemplateDatabase.gd` | Loading of actions, cards, characters, contracts, factions, narrative templates, commodities (unless reused as salvage cargo) | Ships, modules, tools, agents, locations, game starts |
| `world_manager.gd` | `simulation_engine` init/tick calls (around lines 126, 159, 427) and `time_system` advance (around line 480) | Zone loading, player spawn, camera/HUD hooks, jump orchestration |
| `world_generator.gd`, `template_indexer.gd` | Faction/character/sim seeding | Sector and template indexing |
| `agent.gd` | `_register_with_combat_system` coupling to the removed layer; character-based ship lookup if characters go | Template init, movement/navigation params, commands |
| `agent_system.gd` | Persistent named agents, character linkage | Spawning player and NPC agents from templates |
| `asset_system.gd` | Card/inventory coupling, `get_ship_for_character` if characters go | Ship template lookup for player and NPCs |
| `player_controller_ship.gd` | Trade (`_is_npc_tradeable`), contract/interaction-window hooks | Free flight, commands, targeting, docking, jumping, firing |
| `main_hud.gd` | Board, contract, sim-panel, interaction-window buttons and hooks | Flight HUD, targeting, throttle, dock/jump prompts |
| `main_game_scene.tscn` | `CharacterSystem`, `EventSystem`, `InventorySystem`, `TimeSystem`, `WorldClock`, `ContactManager`, `SimDebugPanel`, `DebugMapPanel` (unless repurposed), `ContractBoard` nodes | `WorldManager`, `AgentSpawner`, `AssetSystem`, `WorldRendering`, `MainHUD`, `MainMenu`, `CurrentZoneContainer`, `OrbitCamera`, `JumpTransitionRig`, `DebugWindow` |
| `project.godot` | `WorldClock` autoload; `CoreMechanicsAPI` autoload (3d6 action checks) | Remaining autoloads |

---

## 5. Remove

Nothing is lost: it all remains in git history and under the `pre-prune` tag (§7, step 0).

**Systems (`src/core/systems/`):** `action_check_engine`, `board_action_loop`, `character_system`, `contact_manager`, `crafting_system`, `event_system`, `hook_generator`, `impact_table_manager`, `inventory_system`, `mode_transition_manager`, `narrative_system`, `node_gate_system`, `npc_manager`, `tight_beam_system`, `time_system`
- Check first: `sector_manager.gd`. Keep it only if sector loading or jumping depends on it.

**Other source**
- `src/core/cards/*`, `src/core/resources/impact_card_*`
- `src/core/simulation/*` (`world_clock`, `vessel_data`, `vessel_manager`)
- `src/autoload/CoreMechanicsAPI.gd`
- `src/core/utils/legacy_system_name_generator.gd` (unless it's used for sector names)
- UI: `src/core/ui/board/**`, `action_tray/*`, `contract_board/*`, `interaction_window/*`, `station_menu/*`, `sim_debug_panel/*`, `sector_info_panel/*` (check: it may be worth keeping as a plain sector label), `debug_map_panel/*` (unless repurposed as a sector map)
- Scenes: `scenes/ui/board/**`, `scenes/ui/menus/action_tray`, `contract_board`, `interaction_window`, `station_menu`, `scenes/ui/hud/sim_debug_panel.tscn`, `sector_info_panel.tscn` (same check as above)

**Data**
- `database/definitions/action_template.gd`, `character_template.gd`, `contract_template.gd`, `faction_template.gd`, `narrative_template.gd`
- `asset_commodity_template.gd`: keep only if reused for salvage cargo; otherwise remove.
- `database/registry/actions`, `cards`, `characters`, `contracts`, `factions`, `narrative_templates`
- `database/registry/agents/persistent_*.tres`
- `database/registry/assets/commodities/*`: keep `scrap`/`fuel`/`tech` only if salvage cargo is kept.

**Tests (`src/tests/`):** remove tests for every removed system, including `test_core_mechanics_api`, `test_impact_resources`, all of `core/simulation/*`, `test_asset_card_corpus`, `test_board_action_loop`, `test_character_system`, `test_contact_manager`, `test_event_system`, `test_hook_generator`, `test_impact_table_manager`, `test_inventory_system`, `test_m29_playable_board_game_mvp`, `test_mode_transition_manager`, `test_node_gate_system`, `test_npc_manager`, `test_persistent_agents`, `test_tight_beam_system`, `test_time_system`, `test_board_ui`, `test_chronicle_view_transitions`, `test_contract_board`, `test_debug_map_panel*`, `test_sim_debug_panel`, `test_station_menu`, `test_faction_loading`.
Keep and fix the tests for kept code: movement, navigation, PID, tool controller, player controller, orbit camera, docking, sector loader, agent spawner, asset system, template indexer, world generator/manager, jump transition, HUD targeting, global refs, event bus, constants, game state manager.

**Project root and auxiliary folders**
- `MODEL-CASCADE-PROTOCOL.md`, `STRATEGICAL-TODO.md`, `TACTICAL_TODO.md`, `SESSION-LOG.md`
- `TRUTH_PROJECT.md`, `TRUTH_GAME-LOOP-VISION.md`, `TRUTH_EXPLORATION-PILLARS.md`, `TRUTH_LORE-CONSTRAINTS.md`, `TRUTH_META-PROGRESSION.md`, `TRUTH_DEGRADATION.md`, `TRUTH_PROHIBITED-SEAMS.md`
- `python_sandbox/`, `log_browser/`
- `archive/`, except optionally `archive/old_planetary_shaders` and `archive/locations` if still useful as art reference.
- `Project_dump_text_*.sh`: the owner decides whether to keep them. They were for feeding agents without Godot access.

**Source file headers:** strip the `PROJECT / MODULE / STATUS / OWNER / ACCESS / USER INSTRUCTION / TRUTH_LINK / LOG_REF` comment blocks from kept files (many have the block twice). A short purpose comment is enough.

---

## 6. Engine features to complete before freezing

Each item is an engine capability, not content. Content (specific parts, hulls, numbers) comes after the freeze.

1. **Damage and destruction:** hull (and optionally armour) damage, a destroyed state, and wreck spawning. This replaces the stubbed combat layer in `tool_controller.gd` and `agent.gd`. It applies identically to the player and the AI.
2. **Tools working end-to-end:** firing, cooldowns, power draw and effects (`damage`, `grapple`/tether, `drill`) driven entirely by `utility_tool_template` data.
3. **Fitting:** ship templates expose slots; modules and tools are installed and removed at a dock; fitted mass, power and other stats are recomputed and pushed into `movement_system`. Includes a fitting UI.
4. **Module effects as data:** a small, generic effect model on `asset_module_template` (stat modifiers plus a few verb flags), so new parts are new `.tres` files, not new code.
5. **Power budget:** capacity and regeneration from the ship; draw from active parts. Running out of power has consistent consequences.
6. **Signature and detection:** each ship has a signature derived from its fitting and state. Detection range depends on the observer's sensors and the target's signature. The same rule applies to the player and the AI.
7. **Tether / towing physics:** attach any RigidBody (wreck, asteroid, ship) with the harpoon. Towed mass affects handling.
8. **Cargo / salvage:** pick up, carry and deliver salvage. Cargo contributes to mass and to how valuable a ship appears.
9. **Predator AI evaluation:** extend `ship_controller_ai.gd` so the decision to engage, keep fighting or disengage comes from expected gain (perceived cargo value, visible signature) against expected risk (visible weapons, damage taken so far). This should be a single rule, applied consistently.
10. **Run loop:** start a run from a game start, dock at home to bank salvage and refit, die and lose the run, restart. Minimal persistence (settings, plus whatever carries between runs if anything).
11. **Optional run modifiers:** an honest opt-in hook (data-driven), like Pixel Dungeon challenges. Infrastructure only.
12. **Feel pass on kept systems:** camera, HUD, docking and jump transitions, polished and then frozen.

**Engine freeze criteria**
- All items above work with placeholder content.
- Adding a new part, hull, sector or encounter requires only new data/scene files, no new code.
- Tests for the kept and new systems pass.

**Explicitly out of scope:** multiplayer, narrative or dialogue systems, companions, crafting, an economy or trading, world simulation, meta-progression trees, card or board mechanics. Ideas go in `LATER.md` and are not acted on before the freeze.

---

## 7. Procedure

0. On `master`: `git tag pre-prune` and push the tag.
1. Remove root docs and auxiliary folders (§5, project root). Move the Godot docs to `docs/godot/`.
2. Remove leaf UI (board, contract board, station menu, interaction window, action tray, sim/debug-map panels) and clean `main_game_scene.tscn` and `main_hud`.
3. Remove systems, cards, simulation and their nodes, and the `WorldClock`/`CoreMechanicsAPI` autoloads.
4. Simplify `GlobalRefs`, `GameState`, `GameStateManager`, `Constants`, `EventBus`, `TemplateDatabase`, `world_manager` and related files.
5. Remove the data definitions and registry entries; fix `TemplateDatabase` and the indexer.
6. Remove or fix tests.
7. Strip the source file headers.
8. Rewrite `README.md` for the new direction.

After **each** step: open the project in Godot, check that the main scene loads with no missing-resource or script errors, fly the ship in a sector, dock and jump, and run the focused GUT tests for the touched areas. Commit per step.

**Done when:** the project opens with no errors or warnings about missing resources, the player can fly, target, dock and jump between sectors, and the remaining GUT suite passes.
