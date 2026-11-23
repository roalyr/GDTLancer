# Maintaining

This guide is for whoever runs evolution, releases versions and looks after the development tool.
Content authors need only [CONTENT.md](../CONTENT.md), which also covers setup.

The development tool's Tools tab (`0`) hides these tasks until you press `m`. `m` also shows evolution's status and its keys: `x` stops it, `n` starts a new era. From a terminal, `tools/dev.py list` shows them as the Maintainer group.

**Contents**
- [Play and evolution](#play-and-evolution)
- [When to run evolution](#when-to-run-evolution)
- [Running evolution](#running-evolution)
- [Watching a run](#watching-a-run)
- [Drafts, archetypes and the catalog](#drafts-archetypes-and-the-catalog) (and [updating the game's ships](#updating-the-games-ships-from-a-running-era))
- [A new era](#a-new-era)
- [Islands: evolution on several machines](#islands-evolution-on-several-machines)
- [When something goes wrong](#when-something-goes-wrong)
- [Checks: tests, selftest, soak](#checks-tests-selftest-soak)
- [Releasing](#releasing)
- [Probes, screenshots and balance runs](#probes-screenshots-and-balance-runs)
- [The development tool itself](#the-development-tool-itself)
- [Notes in docs/](#notes-in-docs)

## Play and evolution

The game and evolution are two separate modes, and neither ever reads the other's data:
- **Play** flies the presets only: the archetypes and the part catalogue in `database/presets/`. Its saves are in `user://savegames/`.
- **Evolution** is a developer's tool for breeding and balancing designs. Every ship in it flies a placeholder hull, in the arena (`sector_arena`). Its save, backups, life logs and status are in `user://evolution/`.

New designs reach the game only by being exported as drafts and picked as archetypes (see below).

## When to run evolution

Evolution is how the archetypes get balanced: it breeds designs (hull, parts and behaviour) under the game's rules, and the best of them are picked as the archetypes the game flies. It is worth running:
- **after a rule change** that changes how ships fight, fly, earn or die (a law, a part, the flight model, an NPC tactic): start a new era (below), so fitness earned under the old rules stops counting;
- **for longer**, while the picked archetypes still change from one export to the next.

It is not worth running for changes that do not reach a fight or a trade: models, sounds, UI, words, sector looks. Evolution flies placeholder hulls in the arena, so new models never change it.

**How long it takes.** At speed 8, one process simulates about 2 to 4 hours per real hour (its pace, in the Tools tab). With 4 islands (2 on this laptop, 2 on another), one 1.2-hour segment takes about an hour of real time, and some 350 lives end in it. A new era's designs need a few hours before most niches have a design with 5 lives (`min5` drafts), and about a day for 10 (`min10`).

## Running evolution

Everything here is in the Tools tab (`0`) after `m`. The tab then shows evolution's status: running or done, its era, its pace, its save, newest backup and newest log. `x` stops a run, `n` starts a new era.

- **One process (simplest):** **Run evolution (headless)**. It goes on with the current era, detached: the menu comes back at once, its console goes to `user://evolution/continued_<date>.log`, and `x` stops it. It will not start a second run. Its `follow` option runs it in the terminal instead (`ctrl+c` then kills it, losing what it has not saved).
- **Islands (faster: several cores and laptops):** **Evolution islands**, action `run`, with the number of segments. See [Islands](#islands-evolution-on-several-machines) below.
- **From the game:** open the debug overlay and press **EVOLUTION**, then **START EVOLUTION**. The game pauses while evolution runs as a separate process, until you press **STOP EVOLUTION**. It then saves and ends, and the game carries on. This works only from the project on a desktop.
- **From a terminal:** `godot --no-window -s tools/evolution_sim.gd -- --hours=4`.

**Stopping** always saves first: `x` in the Tools tab, or **Evolution islands**, action `stop` (the islands finish their segment, merge, then stop). Wait until the Tools tab says **done** before starting a new era or editing files under `user://evolution/`.

**Code changes reach a run** only when it starts: islands send the project to every machine before each segment, so they pick up a change at the next one; a single process needs stopping and starting again.

**A run apart:** **Run evolution (headless)** with a `save_dir` of its own (for example `user://smoke/`) keeps its save, logs and status there, apart from the era. Use it to try something without touching the era's records.

## Watching a run

- **The Tools tab** (`0`, `m`): running or done, the simulated time, the pace, and for islands which island a segment waits for and whether a stop was asked.
- **Evolution report** (Maintainer): the newest life log in words: each faction's niches, its best designs with their fitness, lives, kills, deaths and earnings, and which parts and roles are flown.
- **The logs**, in `user://evolution/` (`~/.local/share/godot/app_userdata/GDTLancer/evolution/`):
  - `logs/islands_<date>.log`: islands' segments. A good segment ends with `MERGE ok <N> islands ...: <lives> lives ended` and `backup islands_t<hours>h.sav`.
  - `logs/run_<id>.jsonl`: every life of the era, one per line (what the report reads).
  - `era<N>_<name>.log`, `continued_<date>.log`: a single process's console.
  - `era.json`: the era's number and name; `status.json`: what the Tools tab shows.
- **Backups**, in `user://evolution/backups/`: `era<N>_<name>_t<hours>h_<date>.sav` (each era's end, kept for good), `islands_t<hours>h.sav` (after each islands segment, the newest three) and `auto_t<hours>h.sav` (every 2 simulated hours of a single process, the newest three).

## Drafts, archetypes and the catalog

- **Drafts** are evolution's best designs, exported as preset files to `database/drafts/era<N>_min<k>/`: era `N`, designs whose genome flew at least `k` lives. They are committed, but the game never reads them.
  - The new-era flow exports them (below).
  - **Export presets from evolution** exports them while an era runs. Its `clean` option empties the folder first (only a folder inside `database/drafts/`).
- **Archetypes** (`database/presets/archetypes/`) are what the game flies. **Pick archetypes from drafts** replaces each archetype with the drafts folder's design of the same family and weight class; archetypes the folder has nothing for stay as they are. Its `add` option also makes the archetypes that are missing.
- **The catalog** (`database/presets/CATALOG.md`) lists the archetypes and every draft, by family and weight class. **Classify presets + CATALOG.md** labels them and rewrites it. Rerun it, and commit `CATALOG.md`, with every draft export. The Overview says when it is out of date (`c` fixes it).

After changing a law or the part catalogue:
1. **Apply the ship laws** (Overview `a`) rebuilds the catalogue's and stock hulls' stats from their genes.
2. **Refit the archetypes** (Overview `f`) gives the archetypes the catalogue's parts and the laws' stats.

The content rules flag both when they are needed.

### Updating the game's ships from a running era

Do this as often as you like while an era runs (every hour or few), or once at its end. Era `N` is the one in the Tools tab.
1. Tools, `m`, **Export presets from evolution**: `Minimum lives` 5 (or 10: fewer designs, on firmer evidence), `Empty ... first` yes, `To this folder` `res://database/drafts/era<N>_min5/`. It says "no niche's best has 5 lives yet" when it is too early: try again later.
2. **Pick archetypes from drafts**, folder `era<N>_min5`.
3. Overview (`1`): press `f` if it says the archetypes are out of date, and `c` for `CATALOG.md`. Every rule must be green.
4. Tools, **Run the tests**. They must all pass.
5. Look at what changed: the Archetypes tab (`3`) side by side, `d` on two designs to make them duel, and play the game a little.
6. Commit: Tools, `g`. To keep the old archetypes instead, **Put back this file** on the files under `database/presets/` (or untick them), and commit only the drafts and the catalog.
7. **Export the debug APK** to try it on a phone.

Early in an era the picks change a lot from one export to the next, since each rests on few lives. When the same designs keep winning, the era has done its work.

At the era's end, run the new-era flow with `redo_drafts` yes, so its final drafts replace the ones exported during the era.

## A new era

A new era starts when the rules change, so fitness earned under the old ones no longer counts. It always goes through the tool: Tools, `m`, then `n` (or `tools/dev.py new_era label=<this era> next=<next era>`). Names are lower case letters, digits and `_` (`no_lance_family`, `one_model_flight`). With evolution stopped, the flow:
1. copies the save to `backups/era<N>_<name>_t<hours>h_<date>.sav` and checks the copy byte for byte. A backup is never overwritten;
2. exports that copy's drafts to `database/drafts/era<N>_min10/` and `_min5/`. Folders already there are left as they are, since drafts get edited after export, unless you ask to export again (`redo_drafts`);
3. rewrites `database/presets/CATALOG.md`;
4. commits the drafts and the catalog (nothing else);
5. records the new era in `user://evolution/era.json`;
6. starts it, as `start` says:
   - `yes`: one process in the background for `hours` simulated hours, its console going to `era<N+1>_<name>.log`;
   - `islands`: a run of about a minute starts the era on the save (every design's record starts over), then the islands run `segments` segments from it (check the machines first: [Islands](#islands-evolution-on-several-machines));
   - `no`: nothing starts. **Do not then start islands on their own**: islands never start an era, so the old era's records would carry on. Start it with **Run evolution (headless)** for a few minutes first, or run the flow with `start` set.

`kind` is `era` (the designs stay, their records start over: the usual choice) or `fresh` (evolution starts again from guessed designs: only when the old designs make no sense any more).

If a step fails, the flow stops there and lists what is already done. Run it again once the cause is fixed: the backup and drafts already made stay.

The era number comes from `era.json`. If that is missing, the flow guesses from the backups' and drafts' names and asks you to confirm.

## Islands: evolution on several machines

One Godot process runs evolution on one CPU core. **Evolution islands** runs several side by side, on this machine and on other laptops in the local network over SSH, and merges them after each segment. Setting up a laptop as a worker (once) is in [ISLANDS.md](ISLANDS.md).

All from Tools, `m`, **Evolution islands**:
- `check`: every machine in `.dev/islands.json`, reachable or not, its cores, whether it has Godot and a display. Run it first.
- `push`: sends Godot and the project to every machine. `push: <machine> up to date` means it is done. Each segment pushes again by itself.
- `segment`: one segment, then the merge. `run` with `Segments (run)`: that many, one after another. Both start detached: the menu comes back, their output goes to `user://evolution/logs/islands_<date>.log`, and the Tools tab shows them.
- `stop`: every island saves and ends; the run stops after the merge.

**Which machines, how many islands and how long a segment is** live in `.dev/islands.json`. It is a text file of this machine's own, not committed; edit it in any text editor (format in [ISLANDS.md](ISLANDS.md#4-tell-the-master-about-the-workers)). It is read again before every segment, so a change takes effect at the next one. Usual values: `"local": 2` (islands on this laptop; 0 to spare it), 2 islands per 2-core laptop, `"hours": 1.2` (about an hour), `"speed": 8`.

**A machine that does not answer** is left out of the segment; the others go on. `check` says why:
- `UNREACHABLE (... No route to host)` or a timeout: the laptop is off, asleep, off the network, or has a new address. Wake it; on it, `ip -4 addr` shows its address; put that in `.dev/islands.json`. A fixed address in the router (a DHCP reservation) stops it changing.
- `UNREACHABLE (... Permission denied ...)`: this laptop's key is not on it (ISLANDS.md, step 3).
- `no desktop on :0`: nobody is logged in to its desktop, and Godot needs one. Log in (a live USB session does by itself).

## When something goes wrong

- **A blackout or a crash.** Saves are written whole, then swapped in, the old one kept as `save_0.sav.bak`; loading falls back to it. Start again as before: **Evolution islands** `run` (the next segment starts from the last merged save; the segment that was running is lost), or **Run evolution (headless)**. Not a new era: the era goes on.
- **The save will not load.** With evolution stopped, copy the newest backup from `user://evolution/backups/` over `user://evolution/save_0.sav` in a file manager, then start again.
- **The Tools tab says running, but nothing is.** A run that was killed leaves `status.json` saying running; the tab checks its process and shows it stopped. If a new era still refuses, look for a stray `godot` process (`ps aux | grep godot`) and end it.
- **Evolution quits at once.** Read its console log (above): a script error there names the file and line. Run the tests; they catch most of them.
- **A worker took the wrong files.** `push` sends what is on this laptop, committed or not: commit or put back half-done edits before a run.

## Agent playtests

AI agents (Claude Code's `playtester`, `.claude/agents/playtester.md`) play the real game through its buttons and report bugs and confusing spots, on this machine and on the islands' hosts, one slot each. `tools/playtest/play.py` is what they drive; `tools/playtest/play.py slots` lists the slots, `push` updates the hosts. See [PLAYTESTS.md](PLAYTESTS.md): the parts, running them, checking their findings (they often take a design choice for a bug) and extending them.

## Checks: tests, selftest, soak

- **Run the tests** (Tools): every GUT test, the content rules and models included. From a terminal: `godot --no-window -s addons/gut/gut_cmdln.gd -gexit` (`-gselect=<file>` for one test file).
  - A test file that fails to parse hangs the runner (GUT 7.4.3). The task (and the release) compile every test script first (`tools/devtool/test_run.py`) and name any that does not parse, with its line and error, before GUT starts; GUT itself is stopped after 45 minutes. Run GUT by hand only on files that parse.
  - One "Parse Error" in the output is expected: a test feeds a broken script to the script check on purpose.
- **Test the development tool** (Maintainer): the tool's own Python tests. A "Missing: Scene" line in the output is expected.
- **Soak the game** (Maintainer) leaves the real game running for a few minutes: a new game in Elace, docked at home, at normal speed. It fails on:
  - script or engine errors;
  - orphaned nodes or memory still growing after the first two minutes;
  - wrecks or loose lances past their caps;
  - bookkeeping (sound, threat notices, travellers, markups) that keeps growing.

  It prints the frame rates and the deaths, but does not judge them. It needs a display: it sets `DISPLAY=:0` itself and turns vsync off, since a hidden window's vsync holds the game to one frame a second.

## Releasing

**Release a version** (Maintainer) needs everything committed. It then:
1. runs the tests and a 3-minute soak (`soak=0` skips the soak);
2. sets the Android build's version in `export_presets.cfg` (the version name, and the version code one up);
3. exports `GDTLancer-<version>.apk` beside the usual APK;
4. commits that and tags it `v<version>`.

It pushes nothing: push the commit and the tag once the build plays well.

**Export the debug APK** (Tools, Game) builds the debug APK to `$GDTLANCER_APK`. It needs Godot's Android export templates and SDK set up in the editor. Never rename the presets in `export_presets.cfg`.

## Probes, screenshots and balance runs

All are in the Maintainer group, and write to `.dev/out/` where they write files:
- **UI screenshots** and **Flight screenshots**: every store tab and prompt, and the HUD in flight.
- **Sound probe** and **Harpoon probe**: print what plays, or the tether, each second.
- **Battle balance sim**, **Lance duels** and **Performance ablation**: headless battles and frame times with one system switched off.
- **Evolution report**: the newest life log in words.

Content authors keep **Duel two archetypes** (Archetypes, `d`) and **Sector economy**.

## The development tool itself

- **Its parts** are in `tools/devtool/`:
  - `tasks.py`: every task, and the Godot and Blender checks;
  - `app.py`: the menu (the only part that needs Textual);
  - `bridge.py`, `bridge.gd` and `bridge_commands.gd`: Godot reading and writing files for the tool;
  - `data.py` (data kinds, references), `models.py`, `constants.py` (Constants.gd by section), `worldmap.py` (World's map), `economy.py`;
  - `changes.py` (the review screen's git), `evolution.py` (status, new eras, detached runs), `islands.py`, `release.py`, `soak.py`, `sounds.py`, `test_run.py` (parse check, then GUT);
  - Godot scripts the flows run: `validate.gd`, `sector_maker.gd`, `tscn_text.gd`;
  - `tests/`: the self-test (`tools/dev.py selftest`).
- **Every Godot it starts** (tasks, the bridge, the flows) gets `tasks.environment()`: `DISPLAY=:0` when none is set, since the x11 build needs a display even with `--no-window`. The Overview reports a display that is not there (`display_problem`). Tools that time frames turn vsync off themselves (`OS.vsync_enabled = false`); a sleeping monitor otherwise holds them to a frame a second.
- **To add a task,** add a `Task` to `TASKS` in `tasks.py`, in its group. Put it in the `Maintainer` group if content authors do not need it. Its `about` says what it does (and how long it takes, if more than a few seconds).
- **A new tool's arguments** follow the kind of tool it is (the tasks hide the differences from the menu; the old tools stay as they are):
  - a SceneTree script (`godot -s tools/x.gd`) takes `--flag=value` after `--`, read from `OS.get_cmdline_args()`;
  - a scene (`godot res://tools/x.tscn`) takes `key=value`;
  - a Python flow in `tools/devtool/` takes `key=value`;
  - the Blender scripts keep argparse's `--flag value` after `--`.
  There is no shared parser in `src/core/utils/`; each tool reads its few arguments itself.
- **To add a content rule,** add it to `src/core/validation/content_validator.gd`. The tool and the tests both pick it up.
- **Field notes** come from the data scripts: the comment after an `export var` on its line, or the comment lines just above it. Sound bank slots take theirs from `SoundBank.SLOTS`.
  - `SHOWN_WHEN` in a script hides the fields that do not apply.
  - `data.NOT_IN_GAME` marks fields the game does not read yet (shown in orange; a test guards the list).
- **Derived data the Overview watches:**
  - part stats against their law genes (`ShipLaws.stale_fields`);
  - archetypes against their genomes (`ContentValidator.archetype_stale`);
  - the catalog (`tools/classify_presets.gd --check`, which writes nothing);
  - the material library against the starter `.blend` files;
  - sound loops against their slots.

## Notes in docs/

- The code was frozen on 2026-11-22. The notes on work left undone then (CPU and GPU optimisation work orders, view-detail and scar-mesh checks in play, the handover playtest) were deleted; they are in git history (last in c03a118).
- `docs/godot/` holds Godot 3.6 reference pages (the shading language and shader types), for writing shaders offline.
