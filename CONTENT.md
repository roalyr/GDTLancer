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

A model is made in Blender and imported with one command. The game needs nothing else from it: it builds the collision hull, the hit surface and the levels of detail itself.

**Start from a starter:** copy `assets/models/starters/ship_starter.blend` (or `station_starter.blend`). It holds a small model that already keeps the rules below, every library material by its game name (coloured roughly as the game draws it), the engine empties, and a `Guides` collection (the nose arrow and a box of the game's ship length for ships, a ship for scale for stations) that is never exported. Its Text Editor has a README. After adding a library material, rebuild the starters: `tools/blender -b -P tools/make_starters.py`.

**In Blender**
- **Ships: any size**, nose toward **+Y**, top toward **+Z**. The import scales every ship model to 17 m nose to tail (`Constants.SHIP_MODEL_LENGTH`), and the game sizes each ship from its preset (`model_scale`: a light fighter is about 14 m, a heavy one 33 m). Only the proportions count; engine empties scale with the rest.
- **Stations** can be any size. Ships undock above their top.
- **Materials are picked by name.** Name a material after a file in `assets/art/materials_generic/` (`hull_dark_metal` for `mat_hull_dark_metal.tres`; case and spaces don't matter, so "Hull Dark Metal" works). Short names: `glow`, `metal`, `dark`, `light`. Name it **`paint`** for the surfaces that take the faction's paint. Blender's colours don't reach the game: the library's materials replace them. To add a new look, add a `mat_<name>.tres` to the library.
- **Engines:** add an empty named `Engine` at each nozzle, unrotated. Its scale sets the size of the exhaust. Exhausts trail aft.

**Import:** save the `.blend` as `assets/models/ships/<name>/<name>.blend` (stations: `assets/models/stations/<name>/<name>.blend`), then run:

    tools/import_model.sh assets/models/ships/<name>/<name>.blend
    tools/import_model.sh --station assets/models/stations/<name>/<name>.blend

It exports the `.glb` beside the `.blend` itself, leaving `Guides` out, and scales a ship's `.glb` to 17 m. A `.glb` exported by hand works too.

It makes the levels of detail (`lod/`) and the hit surface (`hit/`) beside the model, imports them, and writes the scene `scenes/prefabs/ships/<name>.tscn` (or `scenes/prefabs/station/<name>.tscn`). A scene that already exists is kept. Last, it checks the scene against these rules and lists any problems. Run it again after every change.

**Use it:** point an archetype's `ship_scene` at the ship scene, or a haven's `model` at the station scene.

**Look at it:** `godot res://tools/hull_sheet.tscn out=/abs/model.png scene=res://scenes/prefabs/ships/<name>` renders it in every faction's paint (across) at each level of detail (down). Leave `.tscn` off the `scene` path.

**Placeholders:** until real models land, ships and stations are built from primitives (`Constants.gd`: `HULL_FORMS`, `STATION_FORMS`; the part fields are described in `src/scenes/game_world/models/primitive_form.gd`). Hulls are `scenes/prefabs/ships/placeholders/<family>_<weight>.tscn`, stations `scenes/prefabs/station/placeholders/<form>.tscn`. Parts marked `"look": "paint"` take the faction's paint. To replace a placeholder, point its archetype or haven at a real model's scene.

**Rocks:** asteroid fields use the low-poly rocks in `Constants.FIELD_ROCK_MODELS`. The dense rocks are placed by hand in the sector scenes.

## Sounds — `database/sounds/sound_bank.tres`

The sound bank has one slot per game event: guns, missiles, the harpoon and the lance, hits and wrecks, the afterburner, engines, buttons, notices, radio and docking (each slot is described in `src/core/sound/sound_bank.gd`). Open the bank in the inspector and drop a sound file on a slot. A slot left empty is silent, so they can be filled one at a time.

- **World** slots are heard where they happen, fading with distance from the player's ship.
- **Loop** slots (`engine`, `missile_engine`) are carried by every ship or missile while it flies; the engine gets louder and higher with thrust. Their files must loop: select the file, tick **Loop** in the Import dock, and press Reimport. The other slots must not loop.
- **UI** slots are heard as they are.

Short `.wav` files suit effects; `.ogg` suits loops. Make the files about equally loud: `Constants.gd` ("SOUND") sets the overall volume, the hearing distance and how many sounds play at once. The tests check that every filled slot holds a sound and loops as its kind says. Music is separate: the main scene's `AmbientMusic`.

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
