# GDTLancer

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**GDTLancer** is a harsh, single-player space game about fitting a ship from parts and taking it into dangerous sectors. Runs are short. Think *Pixel Dungeon in space, with EVE-style fitting*.

There is a clear "right way" to play, and the rules are consistent enough to leave room for unorthodox approaches without designing for them.

## Design Principles

- **One set of rules for everyone.** The player and the AI follow the same rules. Nothing is scripted to happen.
- **Parts change verbs, not just numbers.** Every part has a legitimate purpose.
- **A few interacting rules, not many rules.**
- **The world reacts by its rules.** For example, predators weigh expected gain against risk.

## Setting

A raw, early-stage frontier. There are no sprawling empires or massive navies, only small, isolated communities where spaceflight is rare, perilous and logistically heavy.

## Status

The project is pruned back to its flight core. What works now:

- 6DOF RigidBody flight with PID autopilot commands: approach, orbit, flee, align, move and stop
- Targeting, the orbit camera and the flight HUD
- Docking, and jumping between handcrafted sectors with a jump transition
- New game, save and load
- Laser combat without manual aim: damage depends on range and the target's angular velocity; hull, power and wrecks
- Hostile NPCs spawn in every sector, patrol, engage and flee
- Hits leave lasting marks on the hull (vertex-painted, proportional to damage)
- Salvage: harpoon a wreck, it reels in to a safe towing distance and is stripped into the hold; cargo adds mass

## Roadmap

Complete the engine, then freeze it. After the freeze, work is content, tuning and art only.

1. Damage, destruction and wrecks (same for player and AI)
2. Tools end-to-end from `utility_tool_template` data: fire, cooldown, power draw, damage / grapple / drill
3. Fitting at docks with slots; recomputed mass and stats; fitting UI
4. Module effects as data (stat modifiers plus verb flags)
5. Power budget: capacity, regeneration, draw
6. Signature and detection, one rule for player and AI
7. Harpoon tether / towing; towed mass affects handling
8. Salvage cargo; cargo adds mass and perceived value
9. Predator AI: engage or disengage on expected gain vs. risk
10. Run loop: start, bank salvage at home, die, restart
11. Optional data-driven run modifiers (infrastructure only)
12. Feel pass on camera, HUD, docking and jumps

**Decisions so far:**
- Combat has no manual aim, EVE-style: you fly the ship (distance, relative velocity) and tools resolve on their own. The laser comes first.
- Damage is hull only.
- Running out of power stops the tool, nothing more.
- A run is the hand-built sector graph with free travel. Spawns are uniform everywhere until the layout of space is final.

**Freeze when:** all of the above work with placeholder content, new parts, hulls, sectors and encounters need only data or scene files, and the tests pass.

**Out of scope:** multiplayer, narrative, companions, crafting, economy, world simulation, meta-progression, card or board mechanics.

## Controls

| Input | Action |
|---|---|
| Left mouse | Select target |
| Space | Tool on/off for the selected target (laser on ships, harpoon on wrecks); otherwise dock or jump |
| A | Approach target |
| O | Orbit target |
| F | Flee from target |
| S | Stop |
| M | Toggle free flight |
| Up / Down | Throttle up / down |
| Esc | Main menu |

## Project Layout

| Path | Contents |
|---|---|
| `src/autoload/` | Singletons: Constants, EventBus, GlobalRefs, TemplateDatabase, GameState, GameStateManager |
| `src/core/agents/` | Agent body, movement (thrust/PID), navigation commands, tool controller |
| `src/core/systems/` | Agent spawning, ship template lookup, sector loading |
| `src/core/ui/` | HUD, main menu, debug window, radar |
| `src/modules/piloting/` | Player input controller and ship AI |
| `src/scenes/` | Camera, world manager, jump orchestration and transition |
| `database/definitions/` | Template resource scripts (ships, modules, tools, agents, locations, game starts) |
| `database/registry/` | Template data (`.tres`); new content goes here |
| `scenes/` | Levels, sectors, prefabs and UI scenes |
| `docs/godot/` | Godot 3.6 shader reference |

## Running Tests

Tests use [GUT](https://github.com/bitwes/Gut) and live in `src/tests/`. To run them all headless:

```sh
godot --no-window -s addons/gut/gut_cmdln.gd -gexit
```

## Technology Stack

* **Engine:** Godot Engine 3 (3.6 stable, GLES2)
* **Auxiliary tooling:** Python 3 (`tools/`)

## License

This project is licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**. See [LICENSE](LICENSE.md) for details. See also [AI-ACKNOWLEDGEMENT.md](AI-ACKNOWLEDGEMENT.md).
