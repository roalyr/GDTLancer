# Content guide

This guide says where the game's content lives and how to change it without touching code.

**Work through the development tool:** `tools/dev.py`. It opens a menu (the first run installs its one package into `.dev/`). `?` shows its keys; they mean the same on every tab (`ctrl+s` save, `ctrl+r` refresh, `ctrl+u` undo the last save, `ctrl+n` new, Enter open or run, Tab the next box), and the footer lists each tab's own:
- **Overview:** every content rule below, checked at once, and what changed since the last commit. Models changed in Blender since their last import are listed too.
- **Models:** every ship and station model, with its files, levels of detail, hit surface, who uses it and its check. Keys: `i` import, `o` open in Blender, `s` review sheet, `ctrl+n` new model from a starter.
- **Archetypes:** the twelve designs side by side as the game flies them: fitted mass, speed (and with the afterburner), acceleration, gun damage per second, slots, price, and which factions fly each. The picked one's pilot genes are drawn against evolution's ranges. `s` review sheet; `p` and `h` open its pilot or ship in Data.
- **Factions:** every faction with its colour and paint, who is at war with whom (a matrix: pick a cell, `w` makes war or peace), its roster (tick archetypes, `ctrl+s`) and its havens (Enter opens one in World). `e` opens the faction in Data.
- **Data:** every data file by kind (factions, archetypes, parts, commodities, the game start, locations, agents, the material library, the sound bank), in a form built from its script, with each field's note. `ctrl+s` saves, and the rules are checked at once on every save. `ctrl+u` puts the file back as it was before the last save, `ctrl+n` makes a new file of the kind, and `delete` deletes one, but only if no other file names it (by path or id; the tool says which do). A field the game does not read yet says so in orange ("Not in the game yet"): it is kept and saved, but changing it changes nothing in play.
- **World:** each sector as two lists in a tree: **Scene** (the stars, planets, moons and asteroid belts its scene places) and its layout (havens, beacons, hazards). Pick one to move or turn it in the form (`translation` in m, `rotation_degrees` as in the Godot inspector); `ctrl+n` places a new one (a scene from a list, or a marker), `ctrl+d` copies, `delete` removes. The map is to scale, from above or from the side (heights), on a grid in round km, with owners' colours, the picked one's size or reach as a ring, and buttons to zoom on the picked one, see the whole sector or hide the map. Its legend is also its filter: click a kind to hide or show it. A sector with no layout yet is marked so; `ctrl+n` on it makes one, with its entry beacon, and places it in the sector scene.
- **Constants:** every value in `src/autoload/Constants.gd`, by section (or by kind of value, `ctrl+g`), with its notes; `ctrl+f` finds one. A value is changed in place, so its comments stay. Godot checks that the script still parses before it is saved.
- **Parts:** weapons (`w`), modules (`m`), commodities (`c`) and the starting kit (`k`) side by side, with what uses each; `a` hides the archetypes' own parts. Enter opens one in Data.
- **Look:** every shader (red when its shared blocks are out of date; `y` syncs them) and what uses it, each faction's paints, the paint patterns (`g` remakes the library, `v` opens its sheet) and the music (pick a track, `ctrl+s`).
- **Tools:** whether evolution is running and in which era (`x` asks it to stop, `n` starts a new era), its save, backups and logs; the APK; the newest outputs (`o` opens one). Below, every other tool (tests, sheets, presets, evolution, balance, the APK): Enter asks its questions, then runs it.

A form shows only the fields that apply: a patrol beacon has an owner, a field its rocks, a laser no magazine. Each script says which in its `SHOWN_WHEN` (a field, and the values of another it applies with), and the game reads no field where its rule says it does not apply.

Godot reads and writes every file, so the tool saves exactly what the Godot editor would; in a layout, only the lines of what changed change. From a terminal, `tools/dev.py list` shows the tasks, and `tools/dev.py <task> key=value` runs one.

## Factions — `database/factions/<id>.tres`

Each file is a `FactionTemplate` that sets:
- its name and colour, and who it is at war with (`enemies`);
- the player's starting standing with it;
- whether it calls for help (`distress`), hires escorts (`escorts`) and pays patrol wages (`patrol_wages`);
- its paints (`hull_material`, `station_material`);
- its **roster**: the archetypes its havens fly.

Aliens set `no_standing`, `territory` and `salvage_as`, and may fly a hull of their own (`ship_scene`) instead of their archetypes' hulls. To add a faction, add a file (Data, Factions, `ctrl+n`), then give it havens (World). Wars and rosters are quickest on the Factions tab; making peace there takes the other side out of both lists.

## Sectors — `scenes/levels/sectors/<sector>/`

**What goes where.** The Godot editor makes things; the tool puts them in the world:
- **The Godot editor** composes scenes: one star, planet or moon (`<sector>/<body>/<body>.tscn`), one asteroid belt filled with its rocks (`<sector>/belt_<name>/belt_<name>.tscn`), one station or ship model (see **Models**).
- **The tool (World)** places them: what a sector holds, where, what is linked to what. It creates, moves and deletes the bodies and belts in the sector scene and every marker in its layout, and links markers to bodies. Placing by hand in the Godot editor works too, but the tool is the way.

**Names and folders are rules** (`src/core/validation/sector_names.gd`, checked with the rest):
```
scenes/levels/sectors/sector_<word>/      the location's id; its location's sector_scene_path points here
    sector_<word>.tscn                    the sector scene, root "Sector <Word>"
    sector_<word>_layout.tscn             its layout
    <body>/<body>.tscn                    one folder a body; other files there are its parts: <body>_<part>.tscn
```
A body is `star_<word>` (then `star_<word>_b`, `_c`...), `planet_<word>_<letter>`, `moon_<word>_<planet's letter><n>` (`moon_elace_b1`: Planet B's first), or `belt_<word>_<its own word>`. Everything is lower_snake_case. A body's root, and its node in the sector scene, are its title ("Planet Elace B"). A sector places each of its own bodies once, and the shared prefabs (`scenes/prefabs/celestial/`) as often as it likes; nothing from another sector's folder. The tool names everything it makes by these rules, so what it makes passes them:
- **New sector** (button): its folder, an empty scene, a layout with its entry, and its location (made, or the one there pointed at it).
- **Copy sector** (button): the open sector as a new one, apart (no connections), its bodies renamed and its havens' ids made its own.
- **New body** (`ctrl+n` on Scene): a copy of a body you pick, named by the rules (the next free letter; a moon of the planet you pick; a belt's word), placed in the sector scene; then change its looks in the Godot editor. Or a shared prefab placed as it is.
- **Copy** (`ctrl+d` on a body) makes a new body like it; **delete** removes a body and its folder. `ctrl+u` takes any of these back.

**Elace and the arena.** Elace (`sector_elace`) is the game's home, built round a rush: Planet B's ring (Elace B Belt) is rich and open to all, with each side's outpost at its edge (prospectors and the guards that escort them), the free port as its town, both sides' pickets on it and on their lanes, and the raider den over the lanes. The refinery pays best for ore, across the star; miners weigh the whole round (there, back, and refilling the hold, `AI_MARKET_FILL_TIME`), so many haul round it by the passes. Travellers come in at the entry and fly to work. The deep belt at the Xenohive is richer per rock, and the hive's. Travelling NPCs work at the richest field clear of a territory (the rush). Evolution runs in **the arena** (`sector_arena`, `Constants.EVO_SECTOR_ID`): Elace as it was, symmetric, so neither side starts ahead; nothing connects to it, so the game never goes there, and evolution's run starts docked there (`start_evolution`). The rules keep it so: only the arena stands apart, and each mode's start docks in its own sector.

**The sector scene** (`<sector>.tscn`) places its bodies and belts under `SceneAssets`, with its layout (`SectorLayout`). Nothing else is placed there: no stations (they come with their haven) and no entry point (a beacon). A sector with no layout yet keeps an `EntryPoint` node instead, where ships arrive until it has one.

**Scenery** goes under the sector scene's `AmbientVisuals` node: what is only seen, never solid, never a target, never in the way (nebulas, glows, dust). Whatever sits there is made so as it loads (`src/scenes/game_world/ambient/ambient_visuals.gd`). `scenes/prefabs/ambient/nebula_cloud.tscn` is a local nebula: soft glows in a ball (`radius`, `puffs`, `puff_size`, `tint`, `strength`, `seed_value`), fading out as the camera nears so flying through it never blanks the screen.

**The layout** (`<sector>_layout.tscn`) is a scene of markers among the bodies. Move a marker (`translation`, in m) to move what it stands for. The layout's root sets the play area. A marker can be **attached** to a body (`attached_to`): its translation is then from that body, and it moves with it (the star's radiation, a planet's ring of rocks). In the Godot editor the markers sit under `SceneAssets/SectorLayout/Layout`, each drawing its reach as a ring (an attached one's round its body, where the game puts it).
- **Havens** (`HavenMarker`): stations NPCs live from. Each sets:
  - its id, name and owner (`faction`);
  - its station (`model`: a station model scene, see **Models**, picked from a list in the tool). A haven and its station are one thing: the layout builds the station at the marker, turned as the marker is (`rotation_degrees`), so moving the marker moves the station. Never place a station in a sector scene itself; the rules catch one;
  - whether it is seen from anywhere (`seen_anywhere`: it runs a beacon, as the home port does), instead of by its size;
  - how many ships of each faction live there (`ships`), and which kind it favours (`prefer_role`);
  - its services: repair, rearm, and what it buys at what price (`buys`). The tool lists them as rows: a commodity (or `*`, anything not listed) and its factor on the commodity's price, with what one unit then fetches. A haven with no rows buys nothing.
- **Beacons** (`BeaconMarker`): patrol points (`owner_faction`), rock fields (`rocks` within `radius`; `ring` round a planet), landmarks routes go through, and the sector's one **entry** (`kind` "entry"): ships jumping in, the player and travelling NPCs alike, arrive `radius` out from it (no radius: the sector's `jump_in_distance`). A new game starts docked at the home port instead. Planets and moons get their landmarks by themselves.
- **Hazards** (`HazardMarker`): the star's radiation, from `core` out to `radius` (attached to its star).

Routes go round planets and moons by themselves.

## Ships: archetypes — `database/presets/archetypes/`

There is one ship design per family and weight class:
- families: fighter, prospector, raider, scavenger (a lance is a part any ship may fit, not a family);
- weight classes: light, medium, heavy, superheavy (no superheavies are picked yet; until then there are twelve).

`tools/pick_archetypes.gd --from=<drafts folder> --era=<n>` replaces each archetype with that folder's design of the same family and weight class.

A hull's weight class also sets the size of all its hardpoints and module bays: small on a light hull, medium on a medium one, large on heavy and superheavy hulls. A part fits a slot of its own size or larger.

Each design is a pair of files:
- **`preset_ship_archetype_<name>.tres`**: the hull and its fit;
- **`agent_archetype_<name>.tres`**: the pilot. It holds the behaviour and the exact `genome` the game flies.

`CATALOG.md` beside them describes every design; the Archetypes tab compares them. Factions pick from these through their roster. The home station's store sells them too, along with the era 51 drafts.

The game flies these files as they are: an archetype's ship file sets its stats, its fit and its model. To give one a hand-made model, point its `ship_scene` at the new scene (see **Models**).

## Play and evolution

The game and the evolution are two separate modes, and neither ever reads the other's data:

- **Play** (the game) works with the presets only. Its saves are in `user://savegames/`.
- **Evolution** is a developer's tool for breeding new designs. Every ship in it flies a placeholder hull. Its save, backups, life logs and status are all in `user://evolution/`.

To run evolution, open the debug overlay and press **EVOLUTION**, then **START EVOLUTION**. The game pauses, and evolution runs in a separate process until you press **STOP EVOLUTION**; it then saves and ends, and the game carries on. This only works when running from the project on a desktop. From a terminal: `godot --no-window -s tools/evolution_sim.gd -- --hours=4`.

New designs reach the game only when you export them as presets (`tools/export_presets.gd`).

**A new era** (the rules changed, so fitness earned under the old ones no longer counts) always goes through the tool: Tools, `n`, or `tools/dev.py new_era label=<this era> next=<next era>`. With evolution stopped, it:
1. copies the save to `backups/era<N>_<name>_t<hours>h_<date>.sav` and checks the copy byte for byte (a backup is never overwritten);
2. exports that copy's drafts to `database/presets/drafts_era<N>_min10/` and `_min5/` (folders already there are left as they are, since drafts get edited after export, unless you ask to export again);
3. rewrites `database/presets/CATALOG.md`, and commits the drafts and the catalog (nothing else);
4. records the new era in `user://evolution/era.json`, and starts it in the background, its console going to `era<N+1>_<name>.log`.

If a step fails, the flow stops there and lists what is already done. The Tools tab's evolution task only goes on with the current era.

## Models — ships and stations

A model is made in Blender and imported with one command. The game needs nothing else from it: it builds the collision hull, the hit surface and the levels of detail itself.

**Start from a starter:** copy `assets/models/starters/ship_starter.blend` (or `station_starter.blend`), or let the menu do it (`tools/dev.py new_model`). It holds a small model that already keeps the rules below, every library material by its game name (coloured roughly as the game draws it), the engine empties, and a `Guides` collection (the nose arrow and a box of the game's ship length for ships, a ship for scale for stations) that is never exported. Its Text Editor has a README. After changing the material library, rebuild the starters (`tools/dev.py starters`); the Overview says when they are out of date.

**In Blender**
- **Ships: any size**, nose toward **+Y**, top toward **+Z**. The import scales every ship model to 17 m nose to tail (`Constants.SHIP_MODEL_LENGTH`), and the game sizes each ship from its preset (`model_scale`: a light fighter is about 14 m, a heavy one 33 m). Only the proportions count; engine empties scale with the rest.
- **Stations** can be any size. Ships undock above their top.
- **Materials are picked by name.** Name a material after a file in `assets/art/materials_generic/` (`hull_dark_metal` for `mat_hull_dark_metal.tres`; case and spaces don't matter, so "Hull Dark Metal" works). Short names: `glow`, `metal`, `dark`, `light`. Name it **`paint`** for the surfaces that take the faction's paint. Blender's colours don't reach the game: the library's materials replace them. To add a new look, copy a library material in the tool (Data, Material library, `ctrl+n`) and change its colours; the rules check that it is named `mat_<lower_case>.tres` and uses a model shader.
- **Engines:** add an empty named `Engine` at each nozzle, unrotated. Its scale sets the size of the exhaust. Exhausts trail aft.
- **What exports is what renders.** Modifiers enabled for renders are applied, in order, even ones hidden in the viewport; ones disabled for renders are dropped (the import lists them). Shape keys are applied as mixed, collection instances become real objects, curves and text become meshes. Objects disabled in renders (boolean cutters) and collections excluded from the view layer (parts for instancing) are left out. Your `.blend` is never changed.

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

The sound bank has one slot per game event: guns, missiles, the harpoon and the lance, hits and wrecks, engines, buttons, notices, radio and docking (each slot is described in `src/core/sound/sound_bank.gd`). Each weapon is heard as it is: a laser only where it hits (a welding spark) while its ship hums; a cannon at the shot and the hit; a missile's release click, its thruster and its blast; the lance's heavy throw and dull thud; the harpoon's launch, the hook clamping on and the winch; a wrecked ship blows up. A hit with its own sound plays no `hull_hit`. Open the bank in the tool (Data, Sound bank) and type or pick a sound file's path in a slot. A slot left empty is silent, so they can be filled one at a time.

- **World** slots are heard where they happen, fading with distance from the player's ship.
- **Loop** slots (`engine`, `laser_hum`, `harpoon_reel`, `missile_engine`) are carried by every ship or missile while it flies: the engine gets louder with speed and higher while the afterburner burns; a ship hums while a laser is on, and its winch turns while a harpoon reels in. Their files must loop, and the other slots' must not. The Overview says when one is wrong; `l` there (or `tools/dev.py fix_loops`) sets each file's import loop setting and imports it again.
- **UI** slots are heard as they are.

Short `.wav` files suit effects; `.ogg` suits loops. Make the files about equally loud: `Constants.gd` ("SOUND") sets the overall volume, the hearing distance and how many sounds play at once. The tests check that every filled slot holds a sound and loops as its kind says. Music is separate: the Look tab sets the sector's three tracks (the main scene's `AmbientMusic`): the calm one (`stream`), `danger_stream` (hostiles on the sensors, none has seen you) and `combat_stream` (one has, or you are under fire); the music crossfades between them as the danger changes. The `hostile_detected` and `hostile_aware` slots are the matching notices.

**Placeholders:** `tools/make_placeholder_sounds.py` synthesizes the hull hit, every weapon's sounds, the engine loop, the two notices and the danger and combat tracks into `assets/audio/placeholders/` and `assets/audio/music/`. Replace a slot's file to replace it.

## Parts — `database/presets/parts/`

The part catalogue: three of every kind, light, medium and heavy, and one harpoon. A light part is small, a medium one medium, a heavy one large, so heavy parts need heavy or superheavy hulls. These are the only parts. Archetypes, starting kits, the store and evolution all use them, and the validator rejects any other. Names are plain and the same for every kind: "Laser Mk I-light", "Plating Mk I-heavy"; hulls follow the same pattern ("Lance Mk I-medium"). The mark (`Constants.PART_MARK`) is the generation.

To tune a part, edit its `law_genes`, then run `tools/dev.py apply_laws` to rebuild its stats. Evolution picks a kind and a weight only: a genome's part genes are always the catalogue's, so a change here re-balances every ship that carries the part. The Parts tab lists them all with who uses each.

## Commodities, stock hulls, starting kit — `database/registry/`

- `assets/ships`: stock hulls.
- `assets/commodities`: commodities.
- `game_starts`: the player's start: its ship, the haven it starts docked at (also its home port), its bank, and the kit waiting in home storage (`starting_storage`). The tool lists the kit as rows of part and count, with its worth and mass; ship and haven are picked from lists.
- `locations`: the sector graph. Jumps between sectors are off for 0.x (`Constants.jumps_enabled`): the game is Elace only until the other sectors are laid out.

These are indexed by `template_id`. A field the script does not declare is reported on load.

## Checking your work

The rules live in one place, `src/core/validation/content_validator.gd`, and two things use them:
- the development tool, on every save and on its Overview;
- the tests (`tools/dev.py tests`), which also run everything else.

They load every faction, sector layout, haven, game start and archetype, every ship and station model in use, the material library and the sound bank. Broken references, a missing roster genome, a broken haven, a buy list or kit naming something that does not exist, and models off the rules all fail. `tools/dev.py validate` lists every problem from a terminal; `tools/dev.py check_model scene=<path>` checks one model.

To add a rule, add it to the validator. The tool and the tests both pick it up.
