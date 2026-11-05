# Content guide

This guide says where the game's content lives and how to change it without touching code. Every file named here is a Godot resource (`.tres`) or scene (`.tscn`). You can edit them in the Godot inspector, or as text.

## Factions — `database/factions/<id>.tres`

Each file is a `FactionTemplate` that sets:
- its name and colour, and who it is at war with (`enemies`);
- the player's starting standing with it;
- whether it calls for help (`distress`), hires escorts (`escorts`) and pays patrol wages (`patrol_wages`);
- its paints (`hull_material`, `station_material`);
- its **roster**: the archetypes its havens fly.

Aliens set `no_standing`, `territory` and `salvage_as`, and may fly a hull of their own (`ship_scene`) instead of their archetypes' hulls. To add a faction, add a file, then give it havens.

## Sectors and havens — `scenes/levels/sectors/<sector>/<sector>_layout.tscn`

Each sector's layout is a scene of markers, placed among the sector's planets: open the sector scene and the markers sit under `SceneAssets/SectorLayout/Layout`, each drawing its reach as a ring in the editor. Move a marker to move what it stands for. Edit `<sector>_layout.tscn` itself (the instance in the sector scene only shows it). The layout's root sets the play area.
- **Havens** (`HavenMarker`): stations NPCs live from. Each sets:
  - its id, name and owner (`faction`);
  - its look (`model`: a station model scene, see **Models**), or `station`: a station already in the sector scene;
  - how many ships of each faction live there (`ships`), and which kind it favours (`prefer_role`);
  - its services: repair, rearm, and what it buys at what price (`buys`).
- **Beacons** (`BeaconMarker`): patrol points (`owner_faction`), rock fields (`rocks` within `radius`) and landmarks routes go through. Planets and moons get theirs by themselves.
- **Hazards** (`HazardMarker`): the star's radiation, from `core` out to `radius`.

Routes go round planets and moons by themselves.

## Ships: archetypes — `database/presets/archetypes/`

There are fifteen ship designs, one per family and weight class:
- families: fighter, lance, prospector, raider, scavenger;
- weight classes: light, medium, heavy.

Each design is a pair of files:
- **`preset_ship_archetype_<name>.tres`**: the hull and its fit;
- **`agent_archetype_<name>.tres`**: the pilot. It holds the behaviour and the exact `genome` the game flies.

`CATALOG.md` beside them describes every design. Factions pick from these through their roster. The home station's store sells them too, along with the era 51 drafts.

The game flies these files as they are: an archetype's ship file sets its stats, its fit and its model. To give one a hand-made model, point its `ship_scene` at the new scene (see **Models**).

## Play and evolution

The game and the evolution are two separate modes, and neither ever reads the other's data:

- **Play** (the game) works with the presets only. Its saves are in `user://savegames/`.
- **Evolution** is a developer's tool for breeding new designs. Every ship in it flies a placeholder hull. Its save, backups, life logs and status are all in `user://evolution/`.

To run evolution, open the debug overlay and press **EVOLUTION**, then **START EVOLUTION**. The game pauses, and evolution runs in a separate process until you press **STOP EVOLUTION**; it then saves and ends, and the game carries on. This only works when running from the project on a desktop. From a terminal: `godot --no-window -s tools/evolution_sim.gd -- --hours=4`.

New designs reach the game only when you export them as presets (`tools/export_presets.gd`).

## Models — ships and stations

A model is made in Blender, exported as `.glb`, and imported with one command. The game needs nothing else from it: it builds the collision hull, the hit surface and the levels of detail itself. Look at `src/tests/fixtures/models/test_hull/` for a small model made by these rules.

**In Blender**
- **Ships are 17 m nose to tail**, nose toward **+Y**, top toward **+Z**. A ship's size comes from its preset (`model_scale`), so every ship model is made at this one length.
- **Stations** can be any size. Ships undock above their top.
- **Materials are picked by name.** Name a material after a file in `assets/art/materials_generic/` (`hull_dark_metal` for `mat_hull_dark_metal.tres`; case and spaces don't matter, so "Hull Dark Metal" works). Short names: `glow`, `metal`, `dark`, `light`. Name it **`paint`** for the surfaces that take the faction's paint. Blender's colours don't reach the game: the library's materials replace them. To add a new look, add a `mat_<name>.tres` to the library.
- **Engines:** add an empty named `Engine` at each nozzle, unrotated. Its scale sets the size of the exhaust. Exhausts trail aft.

**Import:** save the `.glb` as `assets/models/ships/<name>/<name>.glb` (stations: `assets/models/stations/<name>/<name>.glb`), then run:

    tools/import_model.sh assets/models/ships/<name>/<name>.glb
    tools/import_model.sh --station assets/models/stations/<name>/<name>.glb

It makes the levels of detail (`lod/`) and the hit surface (`hit/`) beside the model, imports them, and writes the scene `scenes/prefabs/ships/<name>.tscn` (or `scenes/prefabs/station/<name>.tscn`). A scene that already exists is kept. Last, it checks the scene against these rules and lists any problems. Run it again after every export.

**Use it:** point an archetype's `ship_scene` at the ship scene, or a haven's `model` at the station scene.

**Look at it:** `godot res://tools/hull_sheet.tscn out=/abs/model.png scene=res://scenes/prefabs/ships/<name>` renders it in every faction's paint (across) at each level of detail (down). Leave `.tscn` off the `scene` path.

**Placeholders:** until real models land, ships and stations are built from primitives (`Constants.gd`: `HULL_FORMS`, `STATION_FORMS`; the part fields are described in `src/scenes/game_world/models/primitive_form.gd`). Hulls are `scenes/prefabs/ships/placeholders/<family>_<weight>.tscn`, stations `scenes/prefabs/station/placeholders/<form>.tscn`. Parts marked `"look": "paint"` take the faction's paint. To replace a placeholder, point its archetype or haven at a real model's scene.

**Rocks:** asteroid fields use the low-poly rocks in `Constants.FIELD_ROCK_MODELS`. The dense rocks are placed by hand in the sector scenes.

## Parts, commodities, starting kit — `database/registry/`

- `assets/ships`: stock hulls.
- `assets/modules`: modules.
- `tools`: weapons and tools.
- `assets/commodities`: commodities.
- `game_starts`: the player's start.
- `locations`: the sector graph. Jumps between sectors are off for 0.x (`Constants.jumps_enabled`): the game is Elace only until the other sectors are laid out.

These are indexed by `template_id`. A field the script does not declare is reported on load.

## Checking your work

Run the tests: `godot --no-window -s addons/gut/gut_cmdln.gd -gexit`. They load every faction, sector layout, haven and archetype, and fail on a missing roster genome or a broken haven. They also check every ship and station model in use against the rules above. To check one model: `godot --no-window -s tools/check_model.gd -- res://scenes/prefabs/ships/<name>.tscn` (add `--station` for a station).
