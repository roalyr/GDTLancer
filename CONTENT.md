# Content guide

This guide is for content authors: the people who make models, sectors, factions, parts, trade and sounds.
It says how to set up, how to work through the development tool, and where each kind of content lives.
None of it needs code.

Running evolution, new eras, soak checks and releases are maintainer work: see [docs/MAINTAINING.md](docs/MAINTAINING.md).

**Contents**
- [Getting started](#getting-started): what to install, the first run
- [The development tool](#the-development-tool): its tabs and keys
- [Common tasks](#common-tasks): step by step
- Reference: [Factions](#factions), [Sectors](#sectors), [Ships: archetypes](#ships-archetypes), [Parts](#parts), [Commodities, stock hulls, game starts](#commodities-stock-hulls-game-starts), [A sector's economy](#a-sectors-economy), [Models](#models), [Sounds](#sounds), [The UI's look](#the-uis-look), [Words and languages](#words-and-languages)
- [Play saves and changed content](#play-saves-and-changed-content), [Checking your work](#checking-your-work)
- [Where things live](#where-things-live) and a [glossary](#glossary)

## Getting started

**You need:**
- **Linux.** The tools are only made and tested there.
- **Godot 3.6** (3.6.2 is the tested version), the standard Linux x11 build. Godot 4 cannot open the project, and the server or headless build crashes on its scenes.
- **Python 3.9 or newer**, with `venv` and `pip` (on Debian and Ubuntu: the `python3-venv` package).
- **git.**
- **Blender 3.6 LTS**, only for making models.

**Tell the tools where the programs are,** if they are not on your PATH as `godot` and `blender`:
- `GODOT=/path/to/godot`: the Godot 3.6 binary.
- `BLENDER=/path/to/blender`: Blender 3.6. A link at `tools/blender` also works (git ignores it).
- `GDTLANCER_APK=/path/to/file.apk`: where the debug APK goes (only if you build for Android).

Set them in your shell profile (for example `export GODOT=~/apps/godot-3.6.2/godot` in `~/.profile`).

**First run:**
1. Clone the repository.
2. Run `tools/dev.py`. The first run installs its one package (Textual) into `.dev/venv`, which only this tool uses (`tools/devtool/setup.sh` does that step on its own: to set up ahead, or `--fresh` to repair the venv), and imports the project (Godot converts the art and models into `.import/`, which git does not keep; under a minute). Opening the project once in the Godot editor does the same import.
3. The **Overview** tab checks everything. If Godot or Blender is missing or is the wrong version, or the project was never imported, a red **Setup** line says what to do.
4. Play the game from the Tools tab (`0`, then **Play**), or with `godot` in the project folder.

## The development tool

`tools/dev.py` opens the menu. `?` shows the keys. These keys work the same on every tab:
- `1` to `9`, `0` and `-` switch tabs. Tab and shift+Tab move between boxes.
- Enter opens or runs what is picked.
- `ctrl+s` saves and `ctrl+u` undoes the last save (press it again to undo the one before).
- `ctrl+n` makes something new (a file, a marker, a model). `ctrl+r` reads the files again.
- `q` quits.

Plain letters are each tab's own actions, and the footer lists them.

**The tabs, in key order:**
1. **Overview:** every content rule, checked at once, and what changed since the last commit.
   - Enter opens a problem's file where it is edited.
   - It also says when something derived from other data is out of date, with a key to fix it:
     - `a` part stats (apply_laws);
     - `f` the archetypes, built from their characters (refit_archetypes);
     - `c` `CATALOG.md` (classify_presets);
     - `l` sound loops.
   - It also lists models changed in Blender since their import, and starter `.blend` files that need rebuilding.
2. **Models:** every ship, station and rock model, with its files, who uses it and its check.
   - `i` imports, `o` opens it in Blender and `s` makes a review sheet.
   - `ctrl+n` starts a new model from a starter.
   - `c` sets a placeholder's shape, and `f` puts a rock in the asteroid fields or takes it out.
3. **Archetypes:** the twenty ship designs side by side as the game flies them, each with its character (what it is like, its tweaks and their price).
   - `e` opens a design's character in Data, `h` its ship (to set its model), and `s` makes a review sheet.
   - `p` prices the characters' tweaks.
   - Press `d` on one design, then `d` on another, and they duel.
4. **Factions:** wars, pilots and archetypes (and the mix of designs they make), traffic and havens.
   - Pick a cell and press `w` to make war or peace.
   - `e` opens the faction in Data, where its `pilot_shares` and `archetype_shares` are edited row by row.
   - Enter on a haven opens it in World, and `e` opens the faction in Data.
5. **World:** each sector's scene (stars, planets, moons, belts) and its layout (havens, beacons, hazards), on a map.
   - `ctrl+n` places something, `ctrl+d` copies it and `delete` removes it.
   - `e` opens the picked body's scene (or the layout, for a marker) in the Godot editor; on Models, `e` opens the model's scene.
   - The **New sector** and **Copy sector** buttons make sectors.
   - **Economy** shows the open sector's market.
6. **Parts:** weapons (`w`), modules (`m`), commodities (`c`) and starting kits (`k`), each with who uses it.
   - `p` plays a starting kit.
   - `t` lists the trade routes, and `e` shows the picked route's sector economy.
7. **Look:** shaders, faction paints, paint patterns and music.
   - `y` syncs the shaders' shared blocks.
   - `g` remakes the pattern library and `v` opens its sheet.
8. **Data:** every data file by kind, in a form built from its script.
   - Each field shows its note.
   - `delete` removes a file only if nothing else names it.
9. **Constants:** every value in `src/autoload/Constants.gd`, with its notes.
   - `ctrl+g` groups them by kind and `ctrl+f` finds one.
   - Godot checks that the script still parses before saving.
0. **Tools:** every other tool. Enter asks its questions, then runs it.
   - `g` reviews everything changed since the last commit and commits it with your message. Every file is ticked; `space` leaves one out, and **Put back this file** returns it to how the last commit had it (a new file is removed). A file outside the usual folders is marked `!`. Nothing is pushed.
   - `o` opens the newest output (sheets, screenshots go to `.dev/out/`).
   - `m` shows the maintainer tasks.

**`-` Strings:** every word the player reads, a key per row with its English and Ukrainian (`database/strings/strings.json`).
   - Type in the box to find a key or a word in any language; pick a key and edit its texts on the right, then `ctrl+s`.
   - `ctrl+n` adds a key (`section.what`), `ctrl+d` deletes one, `ctrl+e` shows only the keys with problems: a language left empty, placeholders (`%d`, `%s`) that differ between languages, a key the code asks for that the file lacks.

**Saving.** Godot writes every file, so the tool saves exactly what the Godot editor would.
Each save is checked against the content rules at once:
- green: every rule holds;
- red: the problem is listed. The file is still saved; `ctrl+u` puts it back.

**What a form shows.** A form shows only the fields that apply. A patrol beacon has an owner, a field has rocks, a laser has no magazine. Each script lists these rules in its `SHOWN_WHEN`.
A field marked in orange, "Not in the game yet", is kept and saved, but nothing in play reads it.

**From a terminal:** `tools/dev.py list` shows every task, and `tools/dev.py <task> key=value` runs one without the menu.

## Common tasks

**Tune a weapon or module**
1. Parts tab (`6`): pick the part and press Enter. It opens in Data.
2. Edit its `law_genes`, not its stats: the stats are made from the genes. Save.
3. Overview (`1`): press `a` to rebuild the part's stats from its genes.
4. If the Overview then says the archetypes are out of date, press `f`. If it says `CATALOG.md` is out of date, press `c`.

**Add a faction**
1. Data (`8`), Factions, `ctrl+n`. Set its `display_name`, `color` and paints.
2. Factions tab (`4`): set its wars; `e`, then set its `pilot_shares` and `archetype_shares`.
3. World (`5`): give it havens (see the next task).

**Add a station to a sector**
1. World (`5`): open the sector, pick its layout and press `ctrl+n`. Choose a haven marker.
2. Set its `haven_id`, `display_name`, `faction` and `model` (a station scene from the list).
3. Set who lives there (`ships`), its services, and its trade (`buys`, `sells`).
4. Check the trade in **Economy**: the Problems view lists stock that sells nowhere and buy-and-sell-back loops.

**Make a new sector**
1. World (`5`): **New sector**. This makes its folder, scene, layout (with its entry beacon) and Location file.
2. Pick **Scene** and press `ctrl+n` to add a star, planet, moon or belt. It is a copy of one you pick, named by the rules.
3. Change each body's looks in the Godot editor: pick it in World and press `e` to open its scene there. Place havens, beacons and hazards in the layout.
4. Optionally, give it music of its own (its Location's `music_*` fields; see [Sounds](#sounds)). Left empty, it plays the game's.

**Make a ship or station model**
1. Models (`2`): `ctrl+n` copies a starter and opens it in Blender.
2. Model it (see [Models](#models) for the rules), then save the `.blend`.
3. Back in Models, pick it and press `i`: this exports, scales, makes the levels of detail, imports and checks it.
4. Use it: point an archetype's ship `ship_scene` at it (Archetypes, `h`), or a haven's `model`.

**Add or change a sound**
1. Data (`8`), Sound bank: type or pick a sound file's path in a slot. Each slot's note says when it plays.
2. If the Overview says a sound loops wrong for its slot, press `l` there.

**Give a sector its own music:** see [Sounds](#sounds), "A sector's own music".

**Test a game start**
1. Data (`8`), Game starts, `ctrl+n`: pick a ship, a haven, a bank and a kit.
2. Parts (`6`), `k`, then `p` on the start plays it. Its saves are kept apart from the real ones.

**Commit your work:** Tools (`0`), `g`.

## Factions

**Where:** `database/factions/<id>.tres`. Each file is a `FactionTemplate`, and it sets:
- its name and colour, who it is at war with (`enemies`), and the player's starting standing with it. A war named on either side counts for both. When the player hits or kills a faction's ship, every faction at war with it thinks better of the player (`STANDING_ATTACK_ENEMY`, `STANDING_KILL_ENEMY`);
- whether it calls for help (`distress`), hires escorts (`escorts`) and pays patrol wages (`patrol_wages`);
- whether its havens welcome other factions as a neutral one does (`open_havens`, as the Free Port does). An open faction's own ships may also dock at any haven not at war with it;
- its paints (`hull_material`, `station_material`);
- what its havens fly, as two tables of shares (any numbers; each is read as a share of its total):
  - `pilot_shares`: pilot levels, `rookie`, `regular`, `veteran`, `ace`. Empty means the default shares. A level caps the hull: a rookie flies light hulls, a regular up to medium, a veteran up to heavy, an ace anything. A pilot flies the heaviest it may 70% of the time, a lighter one otherwise;
  - `archetype_shares`: archetypes, such as `trader_medium`. An archetype that isn't listed, or has a share of 0, is never flown. Empty means its havens fly nothing.

  Each spawn rolls a pilot, then one of the listed archetypes that its level may fly, mostly of its own class. If none fits, the pilot is raised to fly the lightest listed one. A haven's `prefer_role` narrows the roll to one family. The Factions tab shows each archetype's listed share next to the share of spawns that comes out. A level also sets how quickly the pilot decides and how often it misjudges a fight; the player sees it on the HUD;
- its **traffic**: how many of its ships of each family (`""` means any) travel the sectors apart from its havens' ships. A family it lists no archetype of flies any of its designs.

**Special factions:**
- **Pirates** set `outlaw`. They dock only at their own havens, nobody else docks at theirs, and their armed ships hunt instead of patrolling.
- **Aliens** set `no_standing` (they keep to themselves the same way), `territory` and `salvage_as`. They may fly a hull of their own (`ship_scene`) instead of their archetypes' hulls.

Making peace on the Factions tab takes each side out of the other's `enemies`.

## Sectors

**Where:** `scenes/levels/sectors/<sector>/`.

**Who does what:**
- **The Godot editor** composes scenes: one star, planet or moon, one asteroid belt filled with its rocks, one station or ship model.
- **The tool (World)** places them. It decides what a sector holds, where, and what is linked to what. It creates, moves and deletes the bodies and belts in the sector scene and every marker in its layout.

**Names and folders are rules** (`src/core/validation/sector_names.gd`, checked with the rest):
```
scenes/levels/sectors/sector_<word>/      the Location's id; its sector_scene_path points here
    sector_<word>.tscn                    the sector scene, root "Sector <Word>"
    sector_<word>_layout.tscn             its layout
    <body>/<body>.tscn                    one folder a body; its other parts there: <body>_<part>.tscn
```
- Body names:
  - `star_<word>` (then `star_<word>_b`, `_c`, and so on);
  - `planet_<word>_<letter>`;
  - `moon_<word>_<planet's letter><n>` (`moon_elace_b1` is Planet B's first moon);
  - `belt_<word>_<its own word>`.
- Everything is lower_snake_case. A body's root node, and its node in the sector scene, use its title ("Planet Elace B").
- A sector places each of its own bodies once. It may place the shared prefabs (`scenes/prefabs/celestial/`) as often as it likes, but nothing from another sector's folder.
- The tool names everything it makes by these rules:
  - **New sector** makes a folder, an empty scene, a layout with its entry, and its Location.
  - **Copy sector** makes the open sector again as a new one. The copy has no connections, its bodies are renamed and its havens get ids of their own.
  - **New body** (`ctrl+n` on Scene) copies a body you pick and names it by the rules (the next free letter, a moon of the planet you pick, a belt's word). Or it places a shared prefab as it is.
  - **Copy** (`ctrl+d` on a body) and **delete** work on single bodies. `ctrl+u` takes any of these back.

**The sector scene** (`<sector>.tscn`) places its bodies and belts under `SceneAssets`, with its layout.
- Nothing else goes there: no stations (they come with their haven) and no entry point (that is a beacon).
- A sector with no layout yet keeps an `EntryPoint` node until it gets one. `ctrl+n` on it in World makes a layout.
- **Scenery** goes under `AmbientVisuals`: things that are only seen, never solid, never targets (nebulas, glows, dust). `scenes/prefabs/ambient/nebula_cloud.tscn` is a local nebula that fades as the camera nears it.

**The layout** (`<sector>_layout.tscn`) is a scene of markers among the bodies.
- Move a marker (`translation`, in m) to move what it stands for. The layout's root sets the play area.
- A marker can be **attached** to a body (`attached_to`). Its translation is then from that body, and it moves with it (a star's radiation, a planet's ring of rocks).
- **Havens** (`HavenMarker`) are the stations NPCs live from. Each sets:
  - its id (`haven_id`), name and owner (`faction`);
  - its station (`model`, a station scene). The layout builds the station at the marker, turned as the marker is, so a haven and its station are one thing. Never place a station in a sector scene: the rules catch one;
  - `seen_anywhere`: it runs a beacon and shows on every sensor (as the home port does);
  - who lives there (`ships`), and which family it favours (`prefer_role`);
  - its services: `repair`, `rearm`, what it buys (`buys`) and what it makes and sells (`sells`). Each row is a commodity and a factor on its price. In `buys`, `*` means anything not listed. A haven with no `sells` rows sells no cargo, to NPCs or the player.
- **Beacons** (`BeaconMarker`):
  - patrol points (`owner_faction`);
  - rock fields (`rocks` within `radius`; `ring` for a planet's ring);
  - landmarks that routes go through. Planets and moons get theirs by themselves;
  - the sector's one **entry**: ships jumping in arrive `radius` out from it.
- **Hazards** (`HazardMarker`): a star's radiation, from `core` out to `radius`, attached to its star.

Routes go round planets and moons by themselves.

**Elace and the arena.**
- Elace (`sector_elace`) is the game's home. It is built round a rush on Planet B's rich ring, open to all:
  - each side has an outpost at the ring's edge;
  - the free port is the town;
  - both sides keep pickets on the ring and on the way to it, and a raider den sits over the routes.
- The refinery pays best for ore, across the star. Each side's haven sells its own good cheap and buys the other side's dear. The free port sells both.
- Evolution runs in **the arena** (`sector_arena`): Elace as it was, symmetric, so neither side starts ahead. Nothing connects to it, so play never goes there.

## Ships: archetypes

**Where:** `database/presets/archetypes/`. There is one ship design per family and weight class:
- families: fighter, prospector, raider, scavenger, trader. A lance is a part any ship may fit, not a family;
- weight classes: light, medium, heavy, superheavy.

That makes twenty. A faction flies a design when its `archetype_shares` list it and its `pilot_shares` have pilots of a level that flies that weight.

**Each archetype is made from its character.** You edit the character; the archetype's files are built from it.
- **Character:** `database/characters/character_<name>.tres`, a `CharacterSheet`. It holds:
  - who it is: `display_name` ("Smuggler"), `summary`, `strengths`, `weakness`, `quirk` and `looks`. The name is also its hull's in the game (the store, the HUD), so it needs a `name.` string in both languages (Strings tab: "Smuggler" is `name.smuggler`);
  - its base: an evolved genome (`base_genome`), with where it came from, its lives and fitness. `pick_archetypes` sets these from evolution's drafts and leaves the rest of the character alone;
  - its tweaks, each over the base: `genes` (pilot genes, below), `shares` (hull shares, `structure` `engine` `reactor` `capacitor` `hold`, taken relative to their sum), and `add_parts` and `remove_parts` (catalogue part ids, such as `preset_damper_medium`).
- **Built files:** in `database/presets/archetypes/`. `preset_ship_archetype_<name>.tres` is the hull, its stats, its fit and its model (`ship_scene`, the only field to set there). `agent_archetype_<name>.tres` is the pilot, with the genome the game flies.

**Change an archetype:**
1. Archetypes tab (`3`): `e` opens its character in Data. Edit it and save.
2. Overview: `f` builds the archetypes again (refit_archetypes), then `c` rewrites `CATALOG.md`.
3. Archetypes tab: `p` prices the tweaks (what they cost in fitness, death and earnings, from the last evolution era's lives), and `d` on two designs makes them duel. Set the duel's Free option to see how a character behaves when it isn't forced to fight.

**Pilot genes** (ranges in `Constants.EVO_BEHAVIOR_RANGES`):

| Gene | Range | What it does |
|---|---|---|
| engage | 0.3–4 | the desire it needs before it **starts** a fight: high is picky, low is eager |
| disengage | 0.1–3 | below this desire it breaks off: high gives up early |
| retreat_hull | 0–0.8 | hull share at which it runs home whatever the odds (0: never) |
| pursuit | 0–3 | how far it chases a runner |
| mercy | 0–1 | chance it lets a runner go that isn't shooting back |
| return_fire | 0–1 | chance it shoots back while running |
| teamwork | 0–2 | helps friends and follows leaders; armed ships at 0.8 or more escort traders; traders wait longer for a caravan |
| caution | 0–1 | keeps clear of enemies it hasn't been seen by |
| quiet | 0–0.9 | thrust it cuts while sneaking (a lower signature) |
| range | 0.3–1.5 | orbit distance as a share of its laser's reach |
| burn | 0–0.8 | power kept back from the afterburner for weapons |
| haul | 0.05–1 | how full it gets before going home to sell |

What the era 68 lives say: fighters and raiders do best picky (high `engage`) and holding on once in a fight (low `disengage`), so an eager or quick-to-quit combat pilot has a price. Speed costs scavengers lives. A prospector's or trader's design hardly changes its fitness, so those are free to give character.

**Rules:**
- A hull's weight class sets the size of all its hardpoints and module bays: small on a light hull, medium on a medium one, large on heavy and superheavy hulls. A part fits a slot of its own size or larger.
- An archetype's files must be what its character makes, with the laws' stats. The Overview says when they are not, and `f` builds them.
- The home station's store sells all twenty hulls, with the part catalogue.

`database/presets/CATALOG.md` describes every design: the archetypes first, then every evolved draft whose genome could become a character's base. Bases are picked from evolution's drafts (`database/drafts/`): see [docs/MAINTAINING.md](docs/MAINTAINING.md).

## Parts

**Where:** `database/presets/parts/`. This is the part catalogue: three of every kind (light, medium, heavy) and one harpoon.
- A light part is small, a medium part medium and a heavy part large. Heavy parts therefore need heavy or superheavy hulls.
- These are the only parts. Archetypes, starting kits, the store and evolution all use them, and the rules reject any other.
- Names are plain and the same for every kind: "Laser Mk I-light", "Plating Mk I-heavy". The mark (`Constants.PART_MARK`) is the generation.

**To tune a part,** edit its `law_genes`, then press `a` on the Overview (apply_laws) to rebuild its stats.
Every genome uses the catalogue's genes for its parts, so a change here re-balances every ship that carries the part.

## Commodities, stock hulls, game starts

**Where:** `database/registry/`. The game indexes these by `template_id`, and reports any field the script does not declare.
- `assets/ships/`: stock hulls, the hand-made ones (`ship_default`).
- `assets/commodities/`: commodities.
  - What each haven sells and buys is set on its marker (World: `sells`, `buys`).
  - The Parts tab's trade routes (`t`) list every route that makes money, priced as the game prices it.
  - The player trades by the same rules as NPC traders: at any station they buy what it makes and sell what it buys. Their standing with the station's faction makes both prices better.
- `game_starts/`: the player's start.
  - Its ship (`player_ship_template`) and its haven (`player_starting_location`, a haven id), which is also its home port.
  - Its bank, and the kit waiting in home storage (`starting_storage`).
  - `starting_standing` sets the player's standing with chosen factions.
  - Add starts to test with: see [Common tasks](#common-tasks).
- `locations/`: the sector graph, one Location per sector. The player jumps between connected sectors (fuel from the hold); NPCs stay in their sector: each sector's population is its havens' `ships`, and travellers show up only in `Constants.TRAFFIC_SECTORS` (Elace). World lists a Location with no scene yet and opens it in Data.
- `agents/`: the player's and the NPCs' agent settings.

(These folders are under `database/registry/`, not the top-level `assets/` folder, which holds art, models and audio.)

## A sector's economy

World: **Economy** (or Parts, `e`) shows one sector's market. It is priced by the same rules the content check uses (`src/core/validation/sector_economy.gd`).
- **Market** (`m`): what every haven charges and pays for every commodity.
- **Routes** (`r`): every route, timed for a ship (`[` and `]` pick it): a trip time, what a load costs, and WP an hour.
- **Hulls** (`h`): every archetype's best route here, and how long it takes to earn its own price.
- **Problems** (`p`): what breaks the two rules below.
- **Scope** (`o`): what the 0.x economy covers and what it does not estimate yet.

Times are estimates from the ship's numbers, not flown. Two rules hold for every sector the game plays:
1. A haven's stock must fetch at least 10% more somewhere else in its sector (`SectorEconomy.MIN_MARGIN_SHARE`). Fuel is the exception: it is burnt on jumps, not hauled to sell.
2. No haven may pay as much for a commodity as it charges for it, even at the best standing. Otherwise buying and selling back there pays without flying. Mind `*`: it covers a haven's own stock too.

## Models

A model is made in Blender and imported with one key (Models, `i`). The game builds the collision hull, the hit surface and the levels of detail itself.

**Start from a starter.** Use Models, `ctrl+n`, or copy `assets/models/starters/ship_starter.blend` (or `station_starter.blend`). A starter holds:
- a small model that already keeps the rules below, with its engine and hardpoint empties;
- every library material by its game name;
- a `Guides` collection: the nose arrow and a box of the game's ship length, or a ship for scale beside a station. It is never exported;
- a README in its Text Editor.

**In Blender:**
- **Ships can be any size.** Point the nose toward **+Y** and the top toward **+Z**. The import scales every ship to 17 m nose to tail (`Constants.SHIP_MODEL_LENGTH`), and the game sizes each ship from its preset (`model_scale`). Only the proportions count.
- **Stations can be any size.** Ships undock above their top.
- **Materials are picked by name.**
  - Name a material after a file in `assets/art/materials_generic/`: `hull_dark_metal` for `mat_hull_dark_metal.tres`. Case and spaces do not matter.
  - Short names also work: `glow`, `metal`, `dark`, `light`.
  - Name it **`paint`** for the surfaces that take the faction's paint.
  - Blender's colours do not reach the game: the library's materials replace them.
  - For a new look, copy a library material (Data, Material library, `ctrl+n`) and change its colours.
- **Engines:** ships fly at top speed in any direction, so a ship needs a main nozzle facing each way. Add an empty at each nozzle:
  - `Engine` at the rear ones; `EngineFront`, `EngineTop`, `EngineBottom`, `EngineLeft`, `EngineRight` at the others (`EngineTop.001` is fine).
  - The name sets the way the exhaust points; the rotation is ignored. The scale sets the size of the exhaust.
  - A nozzle burns as the ship pushes away from it: flying sideways lights the side nozzles.
  - A stationary hull (the weapon platform) needs none.
- **Hardpoints:** add an empty named `Weapon` where each tool shows and `Module` where each module shows. They fill in the scene's order.
  - Parts marked `internal` (Parts tab, the Sits column; edit it in Data) sit inside the hull and take no hardpoint: plating, thrusters, power cells, dampers, afterburners, magazines, bays and lances. Weapons, the harpoon, sensors and decoy launchers show outside.
  - An archetype's fit must have a hardpoint for each part it shows outside; the rules check it.
  - Hardpoints are fixed and only show the fit: tools still fire from the ship's centre.
  - Models shows each ship model's nozzles by direction and its hardpoints; the placeholder sheet draws the archetypes' parts at theirs.
- **What exports is what renders.**
  - Modifiers enabled for renders are applied, in order. Modifiers disabled for renders are dropped.
  - Objects disabled in renders (boolean cutters) and collections excluded from the view layer are left out.
  - Your `.blend` is never changed.

**Import.** Save the `.blend` as `assets/models/ships/<name>/<name>.blend` (stations: `assets/models/stations/<name>/<name>.blend`). Then press `i` on it in Models.
- The import exports the `.glb` beside the `.blend`, scales a ship, and makes the levels of detail (`lod/`) and the hit surface (`hit/`).
- It writes the scene `scenes/prefabs/ships/<name>.tscn` (or `scenes/prefabs/station/<name>.tscn`). A scene that already exists is kept.
- Last, it checks the scene against these rules. Import again after every change.
- From a terminal, `tools/import_model.sh <file>` does the same (add `--station` for a station).

**Use it:** point an archetype's `ship_scene` at the ship scene, or a haven's `model` at the station scene.
**Look at it:** Models, `s` renders it in every faction's paint (across) at each level of detail (down).

**Placeholders.** Until real models land, ships and stations are built from primitives (`Constants.gd`: `HULL_FORMS`, `STATION_FORMS`; the part fields are described in `src/scenes/game_world/models/primitive_form.gd`) Each hull form also lists its nozzles by direction and its `weapons` and `modules` hardpoints; the parts shown at hardpoints are `PART_FORMS`.
- Hulls are `scenes/prefabs/ships/placeholders/<family>_<weight>.tscn`; stations are `scenes/prefabs/station/placeholders/<form>.tscn`.
- Models, `c` edits a placeholder's shape.
- To replace a placeholder, point its archetype or haven at a real model's scene.

**Rocks.** Asteroid fields use the low-poly rocks in `Constants.FIELD_ROCK_MODELS`; `f` in Models puts a rock in the fields or takes it out. The dense rocks are placed in belt scenes by hand. Models shows which scenes use each rock.

**After changing the material library,** rebuild the starters (Tools, starters). The Overview says when they are out of date.

## Sounds

**Where:** `database/sounds/sound_bank.tres` (Data, Sound bank). The bank has one slot per game event. Each slot's note in the form says when it plays.
- A slot left empty is silent, so slots can be filled one at a time.
- **World** slots are heard where they happen, fading with distance.
- **Loop** slots (`engine`, `laser_hum`, `harpoon_reel`, `missile_engine`, `fuel_leak`) are carried by the nearest ships and missiles while they apply (`SOUND_LOOP_CARRIERS` of them). Their files must loop, and the other slots' files must not. The Overview says when one is wrong; `l` there sets each file's loop setting and imports it again.
- **UI** slots are heard as they are, wherever the player is.
- **Ambient** slots (`jump_travel`) are heard as they are and loop while something lasts: `jump_travel` from a jump's run-up to the arrival, fading in and out (`SOUND_AMBIENT_FADE`). Their files must loop, as loop slots' do.

**Files.** Short `.wav` files suit effects and `.ogg` suits loops. Make the files about equally loud.
- `Constants.gd` ("SOUND") sets the overall volume, the hearing distance and how many sounds play at once.
- Effects play on the `Effects` bus and music on the `Music` bus. The player sets each one's volume in Options.
- A hit with its own sound plays no `hull_hit`.

**Music** is separate. The Look tab sets the sector's three tracks:
- the calm one (`stream`);
- `danger_stream`: hostiles are on the sensors, but none has seen you;
- `combat_stream`: one has seen you, or you are under fire.

The music crossfades between them as the danger changes. These are the game's own tracks.

**A sector's own music.** Each sector's Location (Data, Locations) has three music fields: `music_calm`, `music_danger` and `music_combat`.
- Each one left empty plays the game's track, so a new sector needs nothing to start with. Fill in only the tracks the sector should play differently.
- On a jump to a sector with other tracks, the old ones fade out as the jump leaves and the sector's own fade in. Between sectors with the same tracks, the music plays on.

To give a sector its music (a new one or an existing one):
1. Save each track as an `.ogg` file that loops cleanly (end to start), in the folder for its kind: `assets/audio/music/ambient/`, `danger/` or `combat/`. Name it after the sector and the kind: `assets/audio/music/ambient/vidr_calm.ogg`, `assets/audio/music/combat/vidr_combat.ogg`.
2. Import it and switch looping on. Open the project in the Godot editor, pick the file, and in the Import dock tick **Loop** and press **Reimport**. (Without the editor: Tools, `import`, then set `loop=true` in the file's `.ogg.import` and import again.) A track that does not loop stops when it ends; nothing checks this yet.
3. Data (`8`), Locations: open the sector's Location (`sector_<word>`). Pick the file in `music_calm`, `music_danger` or `music_combat`, and save.
4. Play: jump to the sector (or use the debug overlay's JUMP page). The calm track plays first; the danger and combat tracks take over as hostiles show up.

**Placeholders:** `tools/make_placeholder_sounds.py` synthesizes stand-in sounds into `assets/audio/placeholders/` and `assets/audio/music/`. Fill a slot with a real file to replace one.

## The UI's look

**Where:** `assets/themes/` (Data, UI theme). `main_theme.tres` sets how every UI control looks; the fonts (`font_*.tres`) and styles (`style_*.tres`) it names are files beside it, so each can be tweaked on its own.
- An entry is `<Type>/<colors|fonts|styles|constants|icons>/<name>`. `Button/styles/normal` is every button's background, `Label/fonts/font` every label's font.
- **Named looks** stand in for one-off changes in scenes: `HeadingLabel` (amber headings), `NoteLabel`, `StoreRow`, `Shade` (the dim behind windows and prompts), `MenuBackground` and others. A look's `base_type` is the control it changes, and its note names the scenes that use it. It sets only what differs; the rest comes from the base type.
- A font's `size` is its letter height in px. A style's `bg_color` is its fill, `border_*` its border, `content_margin_*` the space inside it.
- One file can be named by several entries: `style_window.tres` is every window's and prompt's background. A new font or style starts as a copy of one (`ctrl+n`); then pick it in the theme's entry.
- A scene picks a look in the Godot editor (Inspector, Theme, Type Variation). The rules flag a look a scene names that the theme does not have.
- **Labels use the shared sizes, never their own font.** Every label takes its size from a named look (or the plain `Label`), so the same kind of text is the same size everywhere. For a new UI element pick from these:

  | Text | Look | Font, size |
  |---|---|---|
  | Window titles | `TitleLabel` | font_large, 33 |
  | Section headings, a prompt's title (amber) | `HeadingLabel`, `HeadingButton` | font_large, 33 |
  | Body text, values, buttons | plain `Label` / `Button` | font_default, 22 |
  | Notes, hints, dim keys | `NoteLabel` | font_default, 22, faded |
  | A window's bottom note ("THE GAME IS PAUSED...") | `SmallNoteLabel` | font_small, 18, faded |
  | Small print: captions, map names, radio | `SmallLabel`, `StatCaption` | font_small, 18 |
  | Ship numbers | `StatHull`, `StatPower`, `StatCargo`, `StatMotion`, `StatSensors`, `StatWarning` | font_medium, 28, coloured |
  | Emphasis: selected target, large buttons | `LargeLabel`, `LargeValueLabel`, `LargeButton` | font_large, 33 |
  | A window's way out: CLOSE, UNDOCK (amber) | `CloseButton` | font_large, 33 |
  | A setting that is OFF | `LargeOffLabel` (grey; ON values `LargeValueLabel`, yellow) | font_large, 33 |
  | Symbols (+, -), lighter fill | `SymbolButton` | font_menu, 50 |
  | Main menu | `MenuTitleLabel`, `MenuLabel`, `MainMenuButton` | font_menu_title 100, font_menu 50 |

  Backgrounds: every `ScrollContainer` is a shade lighter than its window (the theme's), except a window's whole-body `OverflowScroll`; a window's tab buttons take `TabButton` (lighter still; `LargeTabButton` in font_large, the interaction and options windows'), its tool buttons (the map's FIT, CENTRE ON SHIP) `LightButton` in the same lighter fill, its other buttons the plain dark `Button`. The open tab reads in brackets, `[MARKET]`, in amber: the code shows it in its look's open twin (`TabButtonOpen`, `LargeTabButtonOpen`), so the colour is changed in the theme.

  No `custom_fonts` in scenes and no `add_font_override` in code: switch `theme_type_variation` instead, and code that draws text reads the look's font (`get_font("font", "SmallLabel")`). A size that none of these fits is a new look in the theme, not an override.
- **UI SCALE** (Options, INTERFACE: x0.5 to x1.5 in steps of 0.1; below 1.0 for large monitors) multiplies every font size above, every button's size, and the HUD as a whole about its screen anchors (`src/autoload/UiScale.gd`). The sizes here are at x1.0, for a 12" 1366x768 screen; a phone's first run picks one from its screen. A scene or code sets sizes at x1.0 too. A HUD element goes under `ScreenControls` and is anchored to the corner or edge it belongs to, so it grows from there. The HUD grows no wider than the screen holds (`HUD_SCALE_WIDTH`; its words still take the full scale), the sliders keep their length above x1.0 (below it they shrink with the rest), and the flight row shrinks to fit between the bottom corner groups. **UI screenshots** shoot the HUD at every scale and print a `UI OVERLAP` line for each clash.

To see a change: Tools, `m`, **UI screenshots** (every store tab, a prompt, the windows), or play.

## Words and languages

Every word the player reads is a key in `database/strings/strings.json`, with its text in English and Ukrainian; the **Strings** tab edits them. Options, INTERFACE, LANGUAGE switches at once, without a restart; a first run starts in the system's language if the game has it.
- Code reads a key: `Strings.t("hud.button.dock")`, or `Strings.t("fit.button.buy", [price])` to fill its `%d`. A scene's label or button carries the key as its `str` meta and takes the text itself.
- Names from the data (parts, hulls, cargo) are keyed by their English name: `Laser Mk I-light` is `name.laser_mk_i_light`. Words the game keeps as state (an AI's `PATROLLING`, a side, a pilot level) are `word.` keys. A name with no key reads as it is: station, sector and faction names are not translated.
- A new word: add the key on the Strings tab with both languages, then use it. The checks fail on a key the code uses that the file lacks, and on a language left empty.
- Keep a word as short as the English where it sits on a button.
- Debug text (the debug overlay, `describe_*` lines) stays English.

## Play saves and changed content

Play saves are in `user://savegames/`. A save can name a hull, part, haven, commodity or faction that has since been removed or renamed. It still loads, put right as it loads (`SaveRepair`):
- an unknown hull becomes the game start's ship, and an unknown home becomes the start's haven;
- unknown parts and cargo are dropped;
- the player is told what changed.

When you delete a file in Data, the question names any local save that still names it. Only a change of the save format (`SAVE_FORMAT_VERSION`) deletes saves.

## Checking your work

The rules live in one place, `src/core/validation/content_validator.gd`. Two things use them:
- the development tool, on every save and on its Overview;
- the tests (Tools, tests), which also run everything else.

They check every faction, sector layout, haven, game start, archetype and part, every ship and station model in use, the material library, the sound bank and the UI theme. Examples of what fails:
- broken references, a missing roster genome, a broken haven;
- a buy list or kit naming something that does not exist;
- a market that does not pay, or pays too well;
- models that break the model rules;
- stats that are not what their genes give.

Tools, validate lists every problem from a terminal. Tools, check_model checks one model.

## Where things live

| Folder | What is there |
|---|---|
| `database/factions/` | factions |
| `database/characters/` | each archetype's character: what its files are built from |
| `database/presets/archetypes/` | the twenty ship designs the game flies (built from their characters) |
| `database/presets/parts/` | the part catalogue |
| `database/presets/CATALOG.md` | every design, described (written by classify_presets) |
| `database/drafts/` | evolution's exported designs, one folder per era. The game never reads them; archetypes are picked from them |
| `database/registry/` | stock hulls, commodities, game starts, Locations (sectors), agents |
| `database/sounds/` | the sound bank |
| `database/strings/` | every word the player reads, in each language |
| `database/definitions/` | the scripts each kind of data file is made from (their notes are the form's field notes) |
| `scenes/levels/sectors/` | sectors: their scenes, layouts and bodies |
| `scenes/prefabs/` | ship and station scenes, placeholders, shared celestial bodies, scenery |
| `assets/` | art (materials, shaders, textures), models (the `.blend` and `.glb` files), audio |
| `assets/themes/` | the UI theme, its fonts and styles |
| `src/` | the game's code; `src/autoload/Constants.gd` holds the tuning values |
| `tools/` | the development tool (`tools/dev.py`, `tools/devtool/`) and the scripts it runs |
| `docs/` | maintainer notes ([MAINTAINING.md](docs/MAINTAINING.md)) and Godot 3.6 shader reference pages |

## Glossary

- **Sector:** one place the game plays, such as Elace. It has a scene, a layout and a **Location** file.
- **Location:** a sector's file in `database/registry/locations/` (its name, scene and connections). It is not a station.
- **Layout:** a sector's scene of markers: havens, beacons and hazards.
- **Haven:** a station NPCs live from, set by a `HavenMarker` in a layout. Its `haven_id` is what game starts and saves name. "Station" is the model it is built with.
- **Home port:** the haven a game start docks at. The player's storage, store and refits are there.
- **Beacon:** a point on a sector's map: a patrol point, a rock field, a landmark or the entry.
- **Family / weight class:** what a ship does (fighter, prospector, raider, scavenger, trader) and how big it is (light to superheavy).
- **Archetype:** one of the twenty ship designs the game flies, one per family and weight class.
- **Character:** who an archetype is (a name, what it is like) and how it is made: an evolved base genome with hand tweaks.
- **Preset:** a design saved as files (ship and pilot). The archetypes and the part catalogue are presets.
- **Draft:** a design evolution exported, kept in `database/drafts/` to pick characters' bases from. It is never flown or sold.
- **Stock hull:** a hand-made hull in `database/registry/assets/ships/`.
- **Agent / pilot:** the settings of who flies a ship. An archetype's pilot holds its behaviour genes and **genome**.
- **Genome:** the genes a design is made from: hull genes, parts and behaviour.
- **Law genes:** the genes a part's or hull's stats are made from (`ShipLaws`). Edit these, not the stats.
- **Roster / traffic:** the archetypes a faction's havens fly, and the ships it sends travelling.
- **WP:** the currency.
- **Standing:** how a faction regards the player (from -1 to 1). It changes prices and who attacks.
- **Era:** a stretch of evolution under one set of rules (maintainers: see [docs/MAINTAINING.md](docs/MAINTAINING.md)).
