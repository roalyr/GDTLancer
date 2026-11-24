# GDTLancer

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**GDTLancer** is a harsh, single-player space sandbox about fitting a ship from parts and making a living on a frontier: mining, salvage, trade and escort work among rival factions, pirates and an alien hive. Think *EVE-style fitting in a small, lawless sector*.

There is a clear "right way" to play, and the rules are consistent enough to leave room for unorthodox approaches without designing for them.

## Setting

A raw, early-stage frontier. There are no sprawling empires or massive navies, only small, isolated communities where spaceflight is rare, perilous and logistically heavy.

## Gameplay

You fly the ship, not the guns: distance and relative velocity decide a fight, and your tools resolve on their own. Fit lasers, cannons, missiles and harpoons at home, then mine, haul, salvage or hire out as an escort. Losing the ship costs the ship, its fit and its hold; you wake at home with your bank, your storage and your standing.

## Design Principles

- **One set of rules for everyone.** The player and the AI follow the same rules. Nothing is scripted to happen.
- **Parts change verbs, not just numbers.** Every part has a legitimate purpose.
- **A few interacting rules, not many rules.**
- **The world reacts by its rules.** For example, predators weigh expected gain against risk.
- **Parity between player and NPCs.** Whatever an NPC knows or can do, the player gets an equivalent, and vice versa.

## Status

0.x: four sectors (home: Elace; Cob, Lywin, Vidr a jump away), playable as a sandbox. Content and balance are still changing.

## Documentation

This README is the way in: it lists every document, and each guide is in `docs/`. For developers (Linux, Godot 3.6: see the [requirements](docs/GETTING_STARTED.md#requirements)), in reading order. Each one starts simple and leaves the details for later sections:

| # | Guide | For | What it covers |
|---|---|---|---|
| 1 | [GETTING_STARTED.md](docs/GETTING_STARTED.md) | everyone new (start here) | Installing, the first run, and two small changes with a guide at each step (about half an hour) |
| 2 | [CONTENT.md](docs/CONTENT.md) | content authors | How the content fits together, step-by-step tasks, then a reference for each kind: factions, sectors, ships, parts, models, sounds, the UI, words |
| 3 | [MAINTAINING.md](docs/MAINTAINING.md) | maintainers | Checks and releases first, then evolution (the balance tool), then the development tool's own code |

When you need them:
- [ISLANDS.md](docs/ISLANDS.md): setting up laptops to run evolution together (maintainers, once per laptop).
- [PLAYTESTS.md](docs/PLAYTESTS.md): AI agents playing the game through its interface (maintainers).

Reference, to look things up rather than read through:
- [UI_LABELS.md](docs/UI_LABELS.md): every text in the UI and the look that sizes it.
- [CATALOG.md](database/presets/CATALOG.md): every ship design, the archetypes and evolution's drafts (generated).
- [docs/godot/](docs/godot/): Godot 3.6's shading language and shader pages, for writing shaders offline.

## License

This project is licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**. See [LICENSE](LICENSE.md) for details. See also [AI-ACKNOWLEDGEMENT.md](AI-ACKNOWLEDGEMENT.md).
