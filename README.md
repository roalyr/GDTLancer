# GDTLancer

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**GDTLancer** is a harsh, single-player space game about fitting a ship from parts and taking it into dangerous sectors. Runs are short. Think *Pixel Dungeon in space, with EVE-style fitting*.

There is a clear "right way" to play, and the rules are consistent enough to leave room for unorthodox approaches without designing for them.

## Design Principles

- **One set of rules for everyone.** The player and the AI follow the same rules. Nothing is scripted to happen.
- **Parts change verbs, not just numbers.** Every part has a legitimate purpose.
- **A few interacting rules, not many rules.**
- **The world reacts by its rules.** For example, predators weigh expected gain against risk.
- **Parity between player and NPCs.** Whatever an NPC knows or can do, the player gets an equivalent, and vice versa. NPCs read numbers; the player reads the same facts as cues (a target's difficulty, who can see you, your own signature). NPCs act like players: they hesitate before deciding, faster when skilled, slower when the call is close.

## Setting

A raw, early-stage frontier. There are no sprawling empires or massive navies, only small, isolated communities where spaceflight is rare, perilous and logistically heavy.

## Status

The project is pruned back to its flight core. What works now (details live in the code comments and `Constants`):

- 6DOF flight with PID autopilot commands (approach, orbit, flee, align, move, stop), targeting, the orbit camera and the flight HUD
- Docking, jumping between handcrafted sectors, new game, save and load
- Combat without manual aim: lasers, missiles, cannons, kinetic lances; hull, power, wrecks and hull damage marks
- Fitting at the home station from data-driven parts; ships and parts follow power laws (`ShipLaws`)
- Sector layouts (`SectorLayout`): havens, beacons, rock fields and hazards; NPCs route and choose by beacon (`BeaconNetwork`)
- Factions, raiders and the xenohive; standing (`Standing`), bounties (`Bounty`), prices (`Market`), fuel (`Fuel`)
- Mining with a lance, laser and harpoon; salvage and towing
- NPC AI with behaviour genes, signatures and detection, ranks, assists and runners; off-screen resolution (`Offscreen`)
- Travellers between sectors; megastructures in Cob and Lywin
- Evolution of NPC designs into presets (`Evolution`, `PresetClassifier`)
- Debug overlay (the bug button): refit, go to, jump

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
- Combat has no manual aim, EVE-style: you fly the ship (distance, relative velocity) and tools resolve on their own; a cannon's aim is the autopilot's.
- Damage is hull only.
- Running out of power stops the tool, nothing more.
- A run is the hand-built sector graph with free travel. Spawns are uniform everywhere until the layout of space is final.

**Freeze when:** all of the above work with placeholder content, new parts, hulls, sectors and encounters need only data or scene files, and the tests pass.

**Out of scope:** multiplayer, narrative, companions, crafting, market simulation, production chains, meta-progression, card or board mechanics. Persistent NPCs travel the sector graph (fuel per jump) on an abstract off-screen timetable; sessions can be short or long, as the player likes.

## Controls

| Input | Action |
|---|---|
| Left mouse | Select target (a click on empty space keeps it; a target out of sensor range is lost, and commands on it stop) |
| Tool buttons (one per fitted tool) | That tool on the selected target, or off (laser: FIRE / CEASE, missiles: LAUNCH one / HOLD, cannon: AIM+FIRE / CEASE, harpoon: LAUNCH / RELEASE); racks and cannons show rounds left |
| Dock button | DOCK at a selected station, UNDOCK, or TRAVEL along a selected route |
| Ship button (docked at home) | Fitting: buy, sell, fit and unfit parts |
| Space | Shortcut: the tool that fits the selected target on or off; otherwise dock or jump |
| A | Approach target (with the lance armed: the pass that throws it) |
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

## Evolution Runs

The havens' NPCs evolve while you play, or headless and sped up:

```sh
godot --no-window -s tools/evolution_sim.gd -- --hours=4 --speed=6
```

Useful tools:

- `--new` starts a new game, `--new-era` restarts every genome's record after a rule change
- Each finished life is written to `user://evolution_logs/run_<id>.jsonl`; `python3 tools/evolution_report.py [log]` summarises it
- `godot --no-window -s tools/export_presets.gd -- --min-lives=10` exports the best design per archetype to `database/presets/`
- `godot --no-window -s tools/classify_presets.gd` rebuilds `database/presets/CATALOG.md`
- `godot --no-window -s tools/apply_laws.gd` brings registry parts in line after a law change
- `godot --no-window -s tools/lance_duel.gd -- --duels=6` duels lance designs (`--weapons` for missiles and cannons)

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
