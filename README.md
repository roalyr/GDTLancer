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

The project is pruned back to its flight core. What works now:

- 6DOF RigidBody flight with PID autopilot commands: approach, orbit, flee, align, move and stop
- Targeting, the orbit camera and the flight HUD
- Docking, and jumping between handcrafted sectors with a jump transition
- New game, save and load
- Laser combat without manual aim: damage depends on range and the target's angular velocity; hull, power and wrecks
- Three arenas in the Elace system (1v1, 2v2, 3v3), each with a beacon and two stations per faction: Verdant and Violet NPCs spawn docked there, fight round the beacon, strip wrecks, and dock to sell salvage, repair or escape. They leave the player alone unless the player shoots one. Brackets show each side in its colour, and what each ship is doing
- Ships and parts follow governing laws (`ShipLaws`, Constants SHIP AND PART LAWS): every stat is a power law of mass (and, for lasers, shot energy), with the Phoenix Light and Ablative Laser as reference points. Bigger hulls are the Phoenix Light scaled up, with more hardpoints and bays
- Evolution (`Evolution`, Constants ARENA AND EVOLUTION): each arena NPC is a genome (hull size and mass split, a part per slot, later behaviour), scored by return on cost. Each faction keeps an archive of niches (size, role, laser range) with the best genome in each, so different builds survive side by side. Saved with the game; every life is logged
- Runners and pursuers: a ship running from a fight shoots back or not; its pursuer chases only while it reckons it can catch it before it docks or gets clear, and may let one go that holds fire. All three are behaviour genes (every NPC has them, not only the arenas'), so careful sides that disengage and reckless fights to the death can both evolve. Desperation bends them: a pilot with little WP for its ship's worth fights at worse odds, chases harder and spares less. Each life's flights, escapes, holds of fire and let-goes are logged. A docked ship waits while an enemy hangs about its station
- Kinetic lance (a module, one per ship): a seat on the ship's axis and a quiver of lances; the seat armours the bow. Armed (the LANCE button; NPCs while they ram), a lance strikes a ship its tip meets at 60 m/s or more of closing speed, square-on, for damage that grows with speed and the lance's mass; the lance stays in the target (the ship is lighter by it) and the next slides into the seat. Slower, it glances off; at an angle it goes in by chance: sure square-on, less likely the more oblique, and past 60 degrees only a long lance may slip between parts. Ramming is an approach that never brakes: straight at the target's lead point, and straight away to build speed when too close. With the lance armed the APPROACH button becomes RAM. NPCs ram while their lasers fire, and see a charge through once begun. Lances are restocked when docking, or recovered from wrecks with a harpoon (those that fit the seat go back in the quiver; lancers short of lances seek such wrecks first). A ship charging with an armed lance is seen coming from 500 m: its target turns hostile (an NPC answers as if shot; the player is warned)
- Weapon archetypes. Lasers: turrets, no ammunition, but they drain power (sustained fire needs a big reactor, power cells or capacitors; short of power a laser waits), and they shoot down missiles coming at their own ship (point defence, by the same hit quality: light fast turrets do it best). Lances: melee, recoverable, no power (and a reactor's heat is part of a ship's signature, so a lancer's small reactor keeps it hard to see). Missile racks: guided heavy hitters launched from beyond laser reach, one use each; a missile turns at a limited rate, so an agile ship near enough can make it overshoot, and its fuel runs out; more only at a base or from a missile ship's wreck. Rail cannons: fixed forward, so the ship aims (the autopilot points the nose where the target will be when a round gets there, holding the range); rounds fly at a finite speed, from a magazine, light on power. Magazines refill at the home station (paid per round) and are salvaged with the harpoon from wrecks that carried the same rounds
- Hits leave lasting marks on the hull (vertex-painted, proportional to damage)
- Salvage: harpoon a wreck, it reels in to a safe towing distance and is stripped into the hold; cargo adds mass
- Fuel leaks vent along the hull and push the ship; destroyed ships explode into a drifting cloud
- Run loop: start docked at the home station (in the 3v3 arena, off to the side of both factions), bank cargo and repair there, lose the ship and the run is over (permadeath), start a new run
- Engine exhausts that stretch and brighten with thrust; a space ambient soundtrack
- Hand-placed asteroids (round the arenas' centre, where the home station used to be) block laser fire; the autopilot steers around them
- Signatures and detection (one rule for all), predators that weigh gain against risk and hesitate by skill; target difficulty and "sees you" cues for the player
- Fitting at the home station: tool and module slots, data-driven modules, part mass, buy / sell with banked value

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

**Out of scope:** multiplayer, narrative, companions, crafting, economy, world simulation, meta-progression, card or board mechanics.

## Controls

| Input | Action |
|---|---|
| Left mouse | Select target (a click on empty space keeps it; a target out of sensor range is lost, and commands on it stop) |
| Tool buttons (one per fitted tool) | That tool on the selected target, or off (laser: FIRE / CEASE, missiles: LAUNCH / HOLD, cannon: AIM+FIRE / CEASE, harpoon: LAUNCH / RELEASE); racks and cannons show rounds left |
| Dock button | DOCK at a selected station, UNDOCK, or TRAVEL along a selected route |
| Ship button (docked at home) | Fitting: buy, sell, fit and unfit parts |
| Space | Shortcut: the tool that fits the selected target on or off; otherwise dock or jump |
| A | Approach target (ram it while the lance is armed) |
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

The arenas evolve while you play (the home station is in the 3v3 arena; fly to a beacon for the others), or headless and sped up:

```sh
godot --no-window -s tools/evolution_sim.gd -- --hours=4 --speed=6
```

It runs about 3 simulated hours per wall-clock hour on a desktop; each save line also prints node, object and memory counts, to catch a run slowing down. It loads the saved game (or starts one with `--new`), saves to it as it goes, and prints `EVO` lines and a report every few simulated minutes. Every finished life is also written in full to `user://evolution_logs/run_<id>.jsonl`. `python3 tools/evolution_report.py [log]` summarises a log: fitness over time, the best niches and their genomes (preset candidates), part use, and who kills whom. `godot --no-window -s tools/export_presets.gd -- --top=6 --min-lives=3` writes each faction's best niches from the save as presets (ship, parts, AgentTemplate with behaviour genes) under `database/presets/`, outside the registry: move the ones you want into `database/registry/`. After changing a law, run `godot --no-window -s tools/apply_laws.gd` to bring the registry parts in line. `godot --no-window -s tools/lance_duel.gd -- --duels=6` pits lance designs against laser ships and an unarmed hauler, one on one, and prints wins, strikes, glances and closing speeds; with `--weapons`, missile and cannon designs against lasers, each other and a lancer (with rounds fired, hits and missiles shot down).

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
