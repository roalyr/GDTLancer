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

The project has just been pruned back to its flight core (see [PRUNE-PLAN.md](PRUNE-PLAN.md)). What works now:

- 6DOF RigidBody flight with PID autopilot commands: approach, orbit, flee, align, move and stop
- Targeting, the orbit camera and the flight HUD
- Docking, and jumping between handcrafted sectors with a jump transition
- New game, save and load

Next is completing the engine (damage, tools, fitting, power, signature and detection, towing, salvage, predator AI, the run loop), followed by an **engine freeze**. After the freeze, work is content, tuning and art only. PRUNE-PLAN.md §6 lists the features and the freeze criteria.

## Controls

| Input | Action |
|---|---|
| Left mouse | Select target / fire |
| Space | Fire |
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
| `docs/godot/` | Godot 3.6 shader reference (spatial, CanvasItem, particle, shading language) |

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
