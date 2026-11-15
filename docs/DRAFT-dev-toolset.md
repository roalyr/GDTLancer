# DRAFT: the development toolset, reviewed for completeness, consistency, robustness and UX

A survey of `tools/dev.py`, `tools/devtool/` and the standalone tools in `tools/`, with a work
order for a follow-up agent. Written 2026-11-15 from reading the code and docs, running the
tool's own tests and timing the content check; no project file was changed. Like the other
`docs/DRAFT-*.md` notes, delete this once its items are done or rejected.

The companion drafts (`DRAFT-cpu-optimizations.md`, `DRAFT-gpu-optimizations.md`) cover the game;
this one covers the tools only.

## Ground rules for the follow-up agent

- **The tool is the way to edit data.** Content is placed, created, deleted and linked through
  `tools/dev.py`; the Godot editor composes looks; code is edited elsewhere. Keep that contract:
  a new workflow becomes a task or a tab action, not a README paragraph.
- **Two layers, two dependency rules.** `tasks.py` and every `tools/devtool/*.py` that a task
  runs directly (`economy.py`, `evolution.py`, `soak.py`, `release.py`, `sounds.py`, `islands.py`)
  are standard library only, so `tools/dev.py <task>` runs without the venv. Only `app.py`
  imports Textual (pinned `textual==8.2.8` in `tools/devtool/requirements.txt`).
- **Godot writes every data file** through the bridge (`bridge.py` → `bridge.gd` →
  `bridge_commands.gd`), so a save is what the editor would save. Scenes are edited as text
  (`tscn_text.gd`) and reloaded after every change; Constants are parse-checked by Godot before
  they are written. Do not add a Python-side writer for `.tres` or `.tscn`.
- **Nothing is pushed, nothing is deleted.** The review screen commits; releases tag; the new-era
  flow backs up first and numbers a name that exists. Keep both.
- **Tests with every change.** `tools/dev.py selftest` (13 files, 104 tests; passed in 89.7 s on
  this machine with the live-bridge tests included) and the Godot side in
  `src/tests/tools/test_bridge_commands.gd` (32 tests). `test_app.py` drives the menu with
  Textual's pilot against `FakeBridge`; extend that stand-in rather than starting Godot in a test.
  GUT 7.4.3 hangs on a test file that does not parse, and one "Parse Error" line is expected
  (a test feeds a broken script to the script check on purpose).
- **Docs that must move together:** `CONTENT.md` (authors), `docs/MAINTAINING.md` (maintainers),
  `HELP` in `app.py`, the docstring at the top of `tools/dev.py`, and each task's `about`.
- **Commit style:** one commit per item, the message saying what was wrong, what changed and the
  measured or tested effect, as the recent `Dev tool:` commits do.
- **Do not touch:** evolution is frozen (era 67); the islands flow is in use on other laptops
  (`docs/ISLANDS.md`); `export_presets.cfg` preset names; the `.dev/` layout (`last.json`,
  `islands.json`, `venv`, `out/`), which users have on disk.

## Measured today

| What | Result |
|---|---|
| `tools/dev.py selftest` | 104 tests, OK, 89.7 s (DISPLAY=:0; includes the live bridge against Godot 3.6.2) |
| `godot --no-window -s tools/devtool/validate.gd` | every section OK, 1.7 s wall including Godot's start |
| `tools/dev.py list` | 42 tasks in 7 groups (Checks 6, Models 9, Content 3, Balance 2, Look 1, Game 5, Maintainer 16) |

The Overview's full check is cheap. Startup cost is Godot's own start plus the models section;
nothing here needs a performance pass. The findings below are about gaps, drift and failure
modes, not speed.

## What is there

| Layer | Files | Lines | Tests |
|---|---|---|---|
| Entry and tasks | `tools/dev.py`, `devtool/tasks.py` | 105, 527 | `test_tasks.py` (9) |
| Menu | `devtool/app.py` | 3222 (10 tabs, 7 modal screens) | `test_app.py` (38) |
| Bridge | `bridge.py`, `bridge.gd`, `bridge_commands.gd` | 93, 49, 1327 | `test_bridge_live.py` (6), GUT (32) |
| Data model | `data.py`, `models.py`, `constants.py` | 182, 82, 193 | `test_data.py` (2), `test_not_in_game.py` (2), `test_constants.py` (4) |
| Views | `worldmap.py`, `economy.py` | 185, 178 | `test_worldmap.py` (10), `test_economy.py` (8) |
| Flows | `evolution.py`, `islands.py`, `soak.py`, `release.py`, `sounds.py`, `changes.py` | 268, 454, 146, 122, 90, 62 | 11, **0**, 5, 5, 3, 1 |
| Godot helpers | `sector_maker.gd`, `tscn_text.gd`, `validate.gd` | 405, 242, 24 | through the GUT bridge tests |
| Standalone tools | 22 `.gd` scripts (5 run as scenes), 9 `.py`, 2 `.sh` | | none of their own (by design: they are run, not imported) |

Every standalone tool is reachable from a task except `islands.py`, `merge_islands.gd` (which
islands runs), `make_placeholder_sounds.py`, and `islands_worker_setup.sh` (which the usb-kit
command copies). `export_blend.py`, `fit_length.py`, `generate_lods.py` and `new_model_scene.gd`
are steps of `import_model.sh`.

## Findings

Each item: what is there, why it matters, what to do, how to verify. Items marked **verify
first** rest on a reading of the code that a short experiment should confirm before any edit.

### A. Completeness

**A1. Islands have no task, no status in the menu and no tests.**
`tools/devtool/islands.py:423` (`main`: check, push, segment, run N, stop, usb-kit) is terminal
only; `docs/MAINTAINING.md` points at `docs/ISLANDS.md`. The Tools tab shows evolution as running
while a segment runs (islands writes the master `status.json`), but not which segment, how many
islands finished, or that `stop` was asked. `islands.py` is the largest flow module and the only
one with no test file.
Do: a Maintainer task `islands` with `Ask("action", choice, ["check", "push", "segment", "run",
"stop"])` and `Ask("segments", default "6")`; a status line in `tools_status()` (`app.py:211`)
read from the islands fields in `status.json` (`write_master_status`, `islands.py:307`); and
`tests/test_islands.py` for the pure parts: `load_config`, `islands_of`, `segment_hours` with
`on_battery` stubbed, `gone` (stale after `STALE` s), `append_logs` on temp folders, and
`segment` with `start`/`collect`/`merge` stand-ins. No SSH in tests.
Verify: `tools/dev.py islands action=check --dry` prints the command; selftest green.

**A2. Options the tools have that no task can pass.**
The tasks fix each tool's arguments to a subset; the rest is reachable only by typing the command
from the tool's header comment:
- `evolution` (`tasks.py:419`): `--new`, `--save-dir`, `--frozen`, `--probe`, `--island`,
  `--backup-every`, `--save-every` (`tools/evolution_sim.gd:14-31`). `--probe` is the stuck-NPC
  finder and `--frozen` the headless play-mode watch; both are maintainer workflows.
- `lance_duel`: `--rate` (`lance_duel.gd:47`). `harpoon_probe`: `lance=<damage>`
  (`harpoon_probe.gd:12`). `sound_probe`: `near=<faction>` (`sound_probe.gd:26`). `soak`:
  `every=` (`soak.gd:25`). `render_preview`: `tile=`, `time=`. `export_presets`: `--save`, `--out`
  (always the live save and `drafts/export/`). `tests`: one file (`-gselect=`); only `-gdir=` is
  asked. `validate`: a single section (`validate.gd` takes one after `--`). `classify_presets`:
  `--check`.
Do: optional `Ask`s with the tool's defaults, `fresh=True` where remembering the last answer would
surprise (`--new`, `--save-dir`). Keep each task's existing defaults so `last.json` answers stay
valid. The `--dry` preview and `test_every_task_builds_a_command` cover the plumbing.
Verify: `tools/dev.py evolution probe=yes --dry` shows `--probe`; `tools/dev.py tests
file=test_lance.gd --dry` shows `-gselect=test_lance.gd`.

**A3. `make_placeholder_sounds.py` has no task.**
It regenerates every placeholder sound and the music; the sound bank points at its outputs. Either
a Look-group task ("Remake placeholder sounds", with a note that real sounds replace them) or a
line in MAINTAINING saying it is retired. The former keeps the "everything goes through the tool"
rule.

**A4. First-run steps the tool could do itself.**
`CONTENT.md` Getting started asks the author to open the editor once (the import) before the tool
works, and `tools/dev.py:44-49` installs Textual with `pip` and no guard. The Overview already
reports missing programs (`setup_problems`); it could also report a missing `.import/` folder and
offer the import (`godot --no-window --editor --quit`, the same command `import_model.sh` and
`sounds.py` already run), and `with_textual` could check `python3 -m venv --help` works before
calling it. See C2 for the error path.

**A5. Refresh after a task is by group, and misses the Maintainer tasks that change content.**
`run_task` (`app.py:3200-3218`) refreshes the data tree, models and the Overview only for the
Models, Content and Checks groups. `pick_archetypes`, `new_era`, `export_presets`, `release`
and `fix_loops` (Checks, fine) change files the Archetypes, Overview and Tools status show. With
the full check at 1.7 s there is no reason not to refresh everything after every task.
Do: drop the group test; call `refresh_views_worker` and `refresh_parts_worker` too.

**A6. No way from the menu to the editor at a given scene.** (verify first)
World says "change each body's looks in the Godot editor" (`CONTENT.md`, Make a new sector) but
the only editor task opens the project root. Godot 3 opens a scene with `godot -e <scene>`;
check that on 3.6.2, then add `e` on World (the picked body or the sector scene) and on Models
(the model scene) that runs `godot -e res://...`.

**A7. Text drift.**
- `data.py:50,52`: "The fifteen designs" (there are 20; `CONTENT.md` says twenty everywhere).
- `tools/dev.py` docstring, "Parts:" lists six files; `docs/MAINTAINING.md`, "The development
  tool itself", lists nine. Missing from both: `islands.py`, `worldmap.py`, `constants.py`,
  `changes.py`, `sounds.py`, `sector_maker.gd`, `tscn_text.gd`, `validate.gd`.
- `HELP` (`app.py:1088`) does not mention the Economy screen's keys (`m r h p`, `[` `]`) or the
  World buttons (New sector, Copy sector, Economy); `CONTENT.md` does.
Do: one pass over the three; add a selftest that `data.KINDS` texts do not name a count that
differs from `len(archetypes())`.

### B. Consistency

**B1. Three answers to "where is user://".**
`data.user_dir()` (`data.py:116`) honours `GODOT_USER_DIR` and hard-codes `~/.local/share`;
`evolution.user_dir()` (`evolution.py:47`) honours `XDG_DATA_HOME` and nothing else; the menu
asks Godot (`cmd_user_dir`, `bridge_commands.gd:630`), which is the truth. `tasks.saves()`
(`tasks.py:192`) uses evolution's, `data.saves_naming()` (`data.py:131`) uses data's. With either
environment variable set, the Save report's list and the delete-time save scan look in different
places, and neither is where Godot looks.
Do: one `user_dir()` in `tasks.py` (override → `XDG_DATA_HOME` → default), imported by both;
the app passes the bridge's answer into `data` and `evolution` calls once it has it.
Verify: a test that sets each variable in turn and asserts both modules agree.

**B2. Four argument styles across the tools.**
`key=value` for scene tools and `fight_bench`/`perf_ablation`/`soak`; `-- --flag=value` for the
SceneTree scripts (`evolution_sim`, `lance_duel`, `export_presets`, `pick_archetypes`,
`check_model`, `merge_islands`, `validate`); `key=value` for `devtool/*.py`; argparse
`--flag value` for the Blender scripts. The task layer hides this from the menu, which is the
right fix, so do not rewrite the tools. Do: state the rule in MAINTAINING ("a SceneTree script
takes `--flag=value` after `--`; a scene takes `key=value`; a Python flow takes `key=value`") so
new tools follow it, and look for an existing shared parser in `src/core/utils/` before writing
one.

**B3. vsync is handled three ways.**
Eight tools set `OS.vsync_enabled = false` themselves; `perf_ablation.gd:10`, `balance_sim.gd:4`
and `render_preview.gd:8` tell the user to add an `override.cfg`. The GPU draft measured the
consequence on this machine (frames of ~1000 ms with the monitor asleep, every ablation frame time
invalid). Do: the one line in all three. `render_preview` captures after `time` seconds, so it
needs frames to flow regardless.
Verify: `tools/dev.py perf mode=no_3d` prints frame times under 50 ms with the monitor off.

**B4. DISPLAY is set for the soak only.**
`soak.py:45` defaults `DISPLAY` to `:0`; `tasks.environment()` (`tasks.py:133`) passes only
`GODOT` and `BLENDER`. From a bare terminal or over SSH, every other Godot task (and the bridge,
so the whole menu) fails with Godot's display error, and the "Godot did not start" message
points at the setup section, which is about versions. The islands notes already say the x11
build needs a display even with `--no-window`.
Do: `env.setdefault("DISPLAY", ":0")` in `tasks.environment()` and in `Bridge.__init__`; add
"no display: set DISPLAY, the x11 build needs one" to `godot_problem`'s message when `DISPLAY` is
unset.

**B5. Numeric questions are free text.**
`Ask` kinds are text, choice, file, flag; `duels`, `speed`, `hours`, `minutes`, `n`, `secs`,
`ratio`, `levels`, `radius`, `top`, `min_lives` are text. A stray letter reaches Godot or Blender
and fails late with its own message. Do: kinds `int` and `float`, checked in `AskScreen._run`
(`app.py:690`) and in `tools/dev.py main` before `tasks.run`; `tasks.missing()` (`tasks.py:501`)
is the natural place. One test per kind.

**B6. File questions in the menu cannot take a typed path.**
`AskScreen.compose` (`app.py:676`) drops the `(type a path)` option that the CLI honours, so
`check_model`, `render_preview`, `lods` and `import_model` can only pick from their globs; a
model outside `assets/models/{ships,stations}/` or a scene outside `scenes/` cannot be given
from the menu. Do: an `Input` with `SuggestFromList(ask.options())` for kind `file` (the Data tab
already does this for resource fields), or keep the `Select` and open `NameScreen` on the last
option.

**B7. The tools ship in the APK.**
`export_presets.cfg:7-9`: `export_filter="all_resources"`, empty `exclude_filter`, and `tools/`
has no `.gdignore`. Every probe scene and script, `tools/devtool/*.gd`, `tools/renders/`
(768 KB of PNGs plus their imports) and `docs/` go into every Android build. Do: an
`exclude_filter` of `tools/*, docs/*, *.md` after grepping `src/` for `res://tools` (only the
tools reference each other) and comparing the APK size before and after (`tools/dev.py apk`).
`release.py` rewrites two lines of that file by regex and is unaffected.

### C. Robustness

**C1. The bridge never times out.**
`START_TIMEOUT` (`bridge.py:21`) is defined and never used; `_reply_for` (`bridge.py:54-56`)
blocks on `readline()` until Godot answers or exits. A Godot that hangs (a scene that never
instances, a modal engine prompt, a deadlock in a command) leaves the worker thread waiting for
good; the menu stays responsive but that `exclusive=True` group (`form`, `world`, `check`,
`models`, `views`) accepts no more work, Save and Check never return, and nothing says why. The
same holds for `sounds.py` and the live tests.
Do: a reader thread that feeds a queue; `call(..., timeout=)` with a default (60 s) and longer
for `validate`/`models`; on timeout raise `BridgeError("Godot did not answer in N s")`, kill the
process, and have the app offer `ctrl+r` (which calls `restart_bridge`, `app.py:1594`). Test with
a `FakeBridge` whose `call` sleeps.

**C2. First-run install has no error path.**
`tools/dev.py:47-48` runs `venv` and `pip install` with `check_call`; without `python3-venv`
(Debian's split package) or without network the author sees a traceback. Do: catch
`CalledProcessError`, print the two likely causes and the two ways on (install `python3-venv`;
or `pip install textual==8.2.8` in any environment, or use `tools/dev.py <task>` which needs no
Textual), then exit 1.

**C3. The tests task and the release can hang on a test file that does not parse.**
`tasks.py:338` and `release.py:71` run `gut_cmdln.gd` with no timeout; the hang is known (it is
in MAINTAINING and in the project's memory notes) and a release would sit forever on step 2.
The bridge already has `check_script` (`bridge_commands.gd:898`), which parses a source string.
Do: before GUT runs, parse every `src/tests/**/*.gd` through one bridge (a few seconds) and stop
with the file's name if one fails; and give the GUT run in `release.py` a `timeout=` (a
generous one, say 45 min) via `subprocess.run`. That removes the hang class rather than
documenting it.
Verify: drop a test file with a syntax error into a temp copy of `src/tests`, run the task, see
the name and a non-zero exit within seconds.

**C4. Review and commit is all or nothing.**
`ChangesScreen` lists every change and `changes.commit` stages with `git add -A`
(`changes.py:55`). The list is visible, which is the safeguard, but a stray file (an empty
`tools/.probe_tmp/` exists in the tree today; a `docs/DRAFT-*.md`; a screenshot dropped in the
project) can only be left out by quitting and using git. Do: a tick per row, all ticked by
default (the house rule is to include the user's edits), `git add -- <ticked>` instead of `-A`;
and a yellow note on rows outside `database/`, `assets/`, `scenes/`, `src/`, `docs/`, `tools/`,
`CONTENT.md`, `README.md`.

**C5. Undo covers form saves, not task outputs.**
`ctrl+u` steps back through writes made by the forms and the World actions (`_undo_point`,
`app.py:1615`); the Content tasks (`apply_laws`, `refit_archetypes`, `classify_presets`,
`paint_patterns`, `pick_archetypes`, `bake_hits`, `starters`, `fix_loops`) rewrite many files
outside it, and the review screen shows the diff but has no way back. Do: a "Put back" button in
`ChangesScreen` for the picked row (`git checkout -- <path>` for tracked files, delete for new
ones, after `ConfirmScreen`), which also covers C4's stray files. Cheaper and more general than
snapshotting task outputs.

**C6. Caches inside one bridge session after a save.** (verify first)
`_checked` (`bridge_commands.gd:1109-1111`) clears `TemplateDatabase._factions` and
`_sector_layouts` after a write; the Parts, Archetypes and Economy views are built from
`PartCatalog`, `TemplateDatabase` and `ShipFit` in the same process. If any of those cache by
path, a part saved in Data and then `ctrl+r` on Parts shows the old numbers until a Constants
save restarts Godot. Verify: save a part's `law_genes`, refresh Parts, compare with the file. If
stale, clear the other caches in `_checked` (or reload the resource with `ResourceLoader.load(path,
"", true)` where the views read it).

**C7. "Running" is a live pid.**
`evolution.status` (`evolution.py:78`) says running when `status.json` says so and `os.kill(pid,
0)` succeeds. After a blackout and reboot (the project has had several) the pid can belong to
another process, so the Tools tab shows a dead run as running and `n` refuses to start a new era
until `x` is pressed and times out. Do: also require `status.json` updated within a staleness
window (islands uses `STALE = 600` s), or compare the process start time from
`/proc/<pid>/stat` with `status.json`'s `started`.

**C8. Release stops safely, but can leave the tree dirty.**
`release.py` reverts `export_presets.cfg` only when no APK was produced; if the export succeeds
and the commit fails (a hook, a lock), the file stays modified next to a built APK, and the
message says only "The commit failed". Acceptable; say in the stop message what to do
(`git checkout -- export_presets.cfg`, or commit it by hand). `Failing tests` parsing
(`release.py:73`) stops the release when the pattern is absent, which is the safe way round.

**C9. `data.references()` reads the whole project per call.**
`data.py:152` walks every `.tres`, `.tscn`, `.gd`, `.cfg`, `.godot`, `.glb` under the root on
each delete. Fine for a delete; it is why D4 (showing users in the form) needs a worker or a
per-session index keyed by mtime.

### D. UX

**D1. Running evolution from the menu holds the terminal and cannot be stopped cleanly.**
The `evolution` task runs `evolution_sim.gd` in the foreground under `suspend()`; the Tools tab's
`x` (the stop file) is unreachable while it runs, and `ctrl+c` kills Godot, losing up to
`--save-every` (15 simulated minutes). `new_era` step 7 already detaches with `start_detached`
(`evolution.py:250`) to a log the tab shows. Do: the `evolution` task starts the same way (a
`before`/custom runner in `tasks.py`, log in `user://evolution/`), notifies "running, x stops
it", and returns; or, at least, `tasks.run` writes the stop file on `KeyboardInterrupt` for that
task and waits for Godot to save. Do the same for `islands run` once A1 exists.

**D2. The terminal CLI has no per-task help.**
`tools/dev.py list` shows keys and defaults; `tools/dev.py <task> --help` is not a thing (it is
parsed as "Not key=value"). Do: print the task's title, `about`, and each `Ask` with its label,
kind, default and choices. Five lines in `main`.

**D3. After a form save that breaks a rule, the Overview is stale.**
The form shows red with the problems; the Overview's table and its "N problems" summary change
only on its own `ctrl+r` or after a task. Do: `check_all_worker()` after any save whose result
has problems (and after `ctrl+u`). With the full check at 1.7 s this can run after every save.

**D4. Forms do not say who uses a file.**
Archetypes show `flown_by`, Parts show `used_by`; a faction, commodity, location, game start or
material in Data shows nothing until delete time. Do: "Named in: N files (a, b, c...)" in the
form title from `data.references()` in a worker (C9), computed once per open file.

**D5. Long tasks give no sense of time.**
`soak` (5 min), `perf` (~4 min a mode here), `fight_bench`, `ui_shots`, `apk` and `release`
suspend the menu with only the tool's own output. Do: a `minutes` hint in each long task's
`about` ("about 4 minutes a mode on a laptop"), and the exit line already printed by `run_task`
could add the elapsed time.

**D6. The Tools status line names outputs that are rarely there.**
`.dev/out/` is empty on this machine although sheets and screenshots were made in the last
sessions: the tasks write there only when run through the menu with the default `out=`, and the
probes write under `user://`. Fine as designed; make the line say "none yet (sheets and
screenshots land here when run from the menu)" when empty, which it nearly does.

**D7. Keys and tabs are consistent.**
`ctrl+s`/`ctrl+u`/`ctrl+r`/`ctrl+n`/`delete` mean the same on every tab; plain letters are per
tab and shown in the footer; `check_action` (`app.py:1545`) keeps digits, `q` and `?` typeable in
fields; `m` gates the maintainer keys. Nothing to change. One small thing: `ctrl+r` on the
Overview is labelled "Check again" and elsewhere "Refresh"; both do what they say.

### E. Not recommended

- Rewriting the standalone tools to one argument style (B2): the task layer already hides it, and
  the tools are used from the terminal in notes and memory with their current flags.
- Moving the menu off Textual or splitting `app.py` for its own sake: 3222 lines in one file with
  a tab per section is readable, and `test_app.py` covers it; split only when a tab grows a
  second screen.
- A Python `.tres` writer "for speed": Godot's save is the correctness guarantee.
- Running the Overview's check continuously: it is cheap, but a check on every keystroke would
  fight the bridge lock; after saves and tasks is enough (A5, D3).

## Suggested order

1. B4 and B3 (two one-line fixes that unblock every measurement from a bare terminal).
2. C1 (bridge timeout) and C2 (first-run error path): the two silent failure modes.
3. C3 (parse pre-check before GUT; release timeout).
4. D1 (evolution detaches).
5. B1 (one `user_dir`).
6. A2, B5, B6 together (the `Ask` layer: new kinds, typed paths, the missing options).
7. A1 (islands task, status, tests).
8. C4 and C5 (review screen: per-file ticks and "Put back").
9. A5 and D3 (refresh after every task and after a failing save).
10. B7 (export filter), measured by APK size.
11. A7, A3, A4, D2, D4, D5 (text, small conveniences).
12. C6 and C7 after their experiments.

## Verification

- `tools/dev.py selftest`: 104 tests today; every item above adds at least one.
- `DISPLAY=:0 godot --no-window -s addons/gut/gut_cmdln.gd -gexit -gselect=test_bridge_commands.gd`
  after any bridge change (32 tests; one "Parse Error" line is expected).
- `tools/dev.py list` and `tools/dev.py <task> --dry` for every task touched; the printed command
  is the contract.
- A menu smoke run after app changes: each tab opens; a faction field saved and `ctrl+u` put back;
  a World marker added, copied, removed and put back; a Constants value saved (Godot restarts) and
  put back; `g` shows the changes; `0` then `m` shows the maintainer tasks and evolution's status.
- Test files to extend: `test_tasks.py` (new kinds, options), `test_app.py` (AskScreen typed
  paths, refresh after tasks, Put back), `test_bridge_live.py` (timeout), `test_evolution.py`
  (stale status), `test_changes.py` (per-file add), new `test_islands.py`.
