# Content guide

This guide says where the game's content lives and how to change it without touching code. Every file named here is a Godot resource (`.tres`) or scene (`.tscn`). You can edit them in the Godot inspector, or as text.

## Factions — `database/factions/<id>.tres`

Each file is a `FactionTemplate` that sets:
- its name and colour, and who it is at war with (`enemies`);
- the player's starting standing with it;
- whether it calls for help (`distress`), hires escorts (`escorts`) and pays patrol wages (`patrol_wages`);
- its paints (`hull_material`, `station_material`);
- its **roster**: the archetypes its havens fly.

Aliens set `no_standing`, `territory` and `salvage_as`. To add a faction, add a file, then give it havens.

## Sectors and havens — `database/sectors/`

- **`<sector id>.tres`** (`SectorLayoutTemplate`) sets:
  - the play area;
  - hazards, such as the star's radiation;
  - beacons: patrol points, rock fields and landmarks;
  - the list of its havens.
- **`<sector id>/havens/<id>.tres`** (`HavenTemplate`) is one station NPCs live from. It sets:
  - its owner and position;
  - its look (`form`, see below);
  - how many ships of each faction live there (`ships`), and which kind it favours (`prefer_role`);
  - its services: repair, rearm, and what it buys at what price.
- Planets and moons stand in the sector scene (`scenes/levels/sectors/<sector>/`). Routes go round them by themselves.

## Ships: archetypes — `database/presets/archetypes/`

There are fifteen ship designs, one per family and weight class:
- families: fighter, lance, prospector, raider, scavenger;
- weight classes: light, medium, heavy.

Each design is a pair of files:
- **`preset_ship_archetype_<name>.tres`**: the hull and its fit;
- **`agent_archetype_<name>.tres`**: the pilot. It holds the behaviour and the exact `genome` the game flies.

`CATALOG.md` beside them describes every design. Factions pick from these through their roster. The home station's store sells them too, along with the era 51 drafts.

Archetypes come out of the arena evolution, a developer's tool (`tools/evolution_sim.gd`). To fly the game's own world headless instead, run `godot --no-window -s tools/evolution_sim.gd -- --new --frozen --save-dir=user://watch/`.

## Placeholder models — `Constants.gd`, `HULL_FORMS` and `STATION_FORMS`

Until real models land, hulls and stations are built from primitives: boxes, cylinders, cones and spheres. Each family has its own silhouette, and heavier weight classes are wider and carry extra parts. The part fields are described in `src/scenes/game_world/primitive_form.gd`.

Parts marked `"look": "paint"` take the faction's paint. The hull scenes are `scenes/prefabs/ships/placeholders/<family>_<weight>.tscn`. To replace one with a real model, point the archetype's ship file at another scene.

## Parts, commodities, starting kit — `database/registry/`

- `assets/ships`: stock hulls.
- `assets/modules`: modules.
- `tools`: weapons and tools.
- `assets/commodities`: commodities.
- `game_starts`: the player's start.
- `locations`: the sector graph.

These are indexed by `template_id`. A field the script does not declare is reported on load.

## Checking your work

Run the tests: `godot --no-window -s addons/gut/gut_cmdln.gd -gexit`. They load every faction, sector, haven and archetype, and fail on a missing roster genome or a broken haven.
