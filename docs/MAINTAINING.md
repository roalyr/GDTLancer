# Maintaining

This guide is for whoever runs evolution, releases versions and looks after the development tool.
Content authors need only [CONTENT.md](../CONTENT.md), which also covers setup.

The development tool's Tools tab (`0`) hides these tasks until you press `m`. `m` also shows evolution's status and its keys: `x` stops it, `n` starts a new era. From a terminal, `tools/dev.py list` shows them as the Maintainer group.

**Contents**
- [Play and evolution](#play-and-evolution)
- [Running evolution](#running-evolution)
- [Drafts, archetypes and the catalog](#drafts-archetypes-and-the-catalog)
- [A new era](#a-new-era)
- [Islands: evolution on several machines](#islands-evolution-on-several-machines)
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

## Running evolution

- **From the game:** open the debug overlay and press **EVOLUTION**, then **START EVOLUTION**. The game pauses while evolution runs as a separate process, until you press **STOP EVOLUTION**. It then saves and ends, and the game carries on. This works only from the project on a desktop.
- **From the tool:** Tools, `m`, then **Run evolution (headless)**. It goes on with the current era, detached: the menu comes back at once, its console goes to `user://evolution/continued_<date>.log`, and `x` stops it. It will not start a second run. Its `follow` option runs it in the terminal instead (`ctrl+c` then kills it, losing what it has not saved).
- **From a terminal:** `godot --no-window -s tools/evolution_sim.gd -- --hours=4`.

The Tools tab shows whether evolution is running, its era, its save, newest backup and newest life log. `x` asks it to save and stop at its next check. **Evolution report** summarises the newest life log.

A smoke run on a copied save still appends to the real era's log: truncate it afterwards, or use `--new`.

## Drafts, archetypes and the catalog

- **Drafts** are evolution's best designs, exported as preset files to `database/drafts/era<N>_min<k>/`: era `N`, designs whose genome flew at least `k` lives. They are committed, but the game never reads them.
  - The new-era flow exports them (below).
  - **Export presets from evolution** writes to `database/drafts/export/` for a one-off look. Its `clean` option empties only a folder inside `database/drafts/`.
- **Archetypes** (`database/presets/archetypes/`) are what the game flies. **Pick archetypes from drafts** replaces each archetype with the drafts folder's design of the same family and weight class. Its `add` option also makes the archetypes that are missing.
- **The catalog** (`database/presets/CATALOG.md`) lists the archetypes and every draft, by family and weight class. **Classify presets + CATALOG.md** labels them and rewrites it. Rerun it, and commit `CATALOG.md`, with every draft export. The Overview says when it is out of date (`c` fixes it).

After changing a law or the part catalogue:
1. **Apply the ship laws** (Overview `a`) rebuilds the catalogue's and stock hulls' stats from their genes.
2. **Refit the archetypes** (Overview `f`) gives the archetypes the catalogue's parts and the laws' stats.

The content rules flag both when they are needed.

## A new era

A new era starts when the rules change, so fitness earned under the old ones no longer counts. It always goes through the tool: Tools, `m`, then `n` (or `tools/dev.py new_era label=<this era> next=<next era>`). With evolution stopped, the flow:
1. copies the save to `backups/era<N>_<name>_t<hours>h_<date>.sav` and checks the copy byte for byte. A backup is never overwritten;
2. exports that copy's drafts to `database/drafts/era<N>_min10/` and `_min5/`. Folders already there are left as they are, since drafts get edited after export, unless you ask to export again (`redo_drafts`);
3. rewrites `database/presets/CATALOG.md`;
4. commits the drafts and the catalog (nothing else);
5. records the new era in `user://evolution/era.json`;
6. starts it in the background, its console going to `era<N+1>_<name>.log`.

If a step fails, the flow stops there and lists what is already done.

The era number comes from `era.json`. If that is missing, the flow guesses from the backups' and drafts' names and asks you to confirm.

## Islands: evolution on several machines

One Godot process runs evolution on one CPU core. `tools/devtool/islands.py` runs several side by side, on this machine and on others over SSH, and merges them after each segment. See [ISLANDS.md](ISLANDS.md). From the tool: Tools, `m`, **Evolution islands** (check, push, segment, run, stop); segments and runs start detached, their output in `user://evolution/logs/islands_<date>.log`, and the Tools tab shows which islands a segment waits for and whether a stop was asked.

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

- `docs/DRAFT-*.md` are notes on unfinished work written away from Godot. Delete each one once its work is finished.
- `docs/godot/` holds Godot 3.6 reference pages (the shading language and shader types), for writing shaders offline.
