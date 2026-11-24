# Agent playtests: the game played through its interface

This page is for maintainers who run agent playtests or extend them.

One of the guides the [README](../README.md#documentation) lists, for when you need it; it goes with [MAINTAINING.md](MAINTAINING.md#agent-playtests).

**Contents**
- [What they are](#what-they-are)
- [The parts](#the-parts): the server and the client
- [Slots and machines](#slots-and-machines)
- [Running playtests with Claude Code](#running-playtests-with-claude-code): the agent, a scenario, what a run costs
- [Checking findings](#checking-findings)
- [Extending it](#extending-it), [Limits](#limits)

## What they are

Cheap AI agents play the real game the way a player does, by clicking its buttons, and report what
is broken, inconsistent or confusing. They find the bugs that only a playtest finds: script errors
that only happen in play, numbers the HUD shows that disagree with the game's, buttons that do
nothing, cues a first-time player would miss. They run on this laptop and on the evolution islands'
machines, several at once.

They are a filter, not a judge. Every finding is checked by hand before anything is changed: the
agents often take a design choice for a bug (see "Checking findings").

## The parts

| Part | What it is |
|---|---|
| `tools/playtest/play_server.tscn` (`.gd`) | The real game (the main scene) with a small command server inside it |
| `tools/playtest/play.py` | The command line the agents use: one command per call, prints what a player could see |
| `.claude/agents/playtester.md` | The agent's definition for Claude Code: its model, its tools and how it plays |
| `.playtest/<slot>/` | Each run's files: the game's log, screenshots, findings (git-ignored) |

### The server

`play_server.gd` loads the main scene and listens on `127.0.0.1:<port>`. A request is one line of
JSON, `{"cmd": name, "args": {...}}`; the answer is one line, `{"ok", "result" or "error", "events"}`.
One connection per request.

- **Input is real.** Clicks and drags go in as mouse events through `Input.parse_input_event`, so
  the HUD, `PointerRouter`, the target brackets and the modal windows see exactly what a player's
  clicks would. Nothing is called behind the interface's back.
- **`look`** lists what a player could see and press:
  - buttons in draw order, each with an id, its text and its centre;
  - an icon button named by the labels drawn over it;
  - target brackets in space as `target: <name>` (flag `world`);
  - the selected target flagged `selected`, toggles `on`/`off`, greyed buttons `disabled`;
  - every visible label's text.
  It leaves out buttons covered by a window that takes the pointer, and rows a scroll container has
  scrolled out of view.
- **Events.** The server listens to EventBus and every reply carries what happened since the last
  one, in game time:
  - notices (`announcement`), dock and attack feedback;
  - docking, undocking, a new ship or respawn, the player's ship destroyed;
  - sector changes and threat level.
  Without them an agent misses whatever happens during a long `wait`. The first run took a ship
  loss for vanished cargo this way.
- **Saves and options.** Each slot saves in its own `user://playtest_saves/<slot>/`, emptied at each
  start unless `--keep` is given. The settings file is never written, and the player's saves are never
  touched. The game runs with the `test_start=start_default` argument, which keeps the autoloads off
  the player's saves before the server is up. A new game resets the save folder, and the server sets
  it back every frame.
- **vsync is off.** A hidden window's vsync holds the game to 1 frame a second (the Lenovo showed
  1 fps before; 73-84 fps with two slots after).

### The client

`tools/playtest/play.py [--slot S] <command>`:

| Command | Does |
|---|---|
| `start [--keep] [--window]` | Launches the game on the slot and waits for the main menu (about 10 s). `--window` shows it |
| `look [--shot]` | Buttons and text on screen; `--shot` also takes a screenshot and prints its path |
| `click <id>` / `click --text T` / `click --at X Y` | Presses a button (by `look`'s id, or its text) or clicks a point. `--double` for a double click |
| `drag X1 Y1 X2 Y2` | Press, move, release: turns the camera in empty space, moves a slider |
| `key <action> [seconds]` | Holds an input action (`actions` lists them) |
| `wait <seconds>` | Lets the game run, in real time (at most 300) |
| `state` | What the game itself holds: sector, docked station, bank, cargo, hull, speed, position, paused |
| `shot [name]` | A screenshot to `.playtest/<slot>/<name>.png` |
| `errors` | Every Godot error and warning of the run |
| `stop` | Ends the game on the slot |
| `slots` | Every slot and whether it is running |
| `push` | Sends the project and Godot to the island hosts (the islands' own push) |
| `stop-all` | Stops every slot |

Two details:
- **Click by text** matches a button's text exactly first, then as a part of it, and only enabled
  buttons. It never matches a target bracket unless asked for as `target: <name>`, so "lance" means
  the LANCE button, not a lance stuck in a rock.
- **Every reply ends with the new Godot errors** since the last command, filtered of noise (Godot's
  own "physics interpolation" warnings, and the ALSA error of a machine without a sound card).

## Slots and machines

Slots come from the islands' settings, `.dev/islands.json` (see [ISLANDS.md](ISLANDS.md)):
- **`l1`..`lN` run here:** N is the file's `local` count, at least 1.
- **`<host's last number>-1`.. run on each host:** for example `104-1` and `104-2`, as many as the
  host has islands.

Each slot has its own port (from 47321 up), run folder and save folder.

A host's slot runs over SSH in the copy of the project the islands keep there:
- **The copy:** `~/gdtl-island/project`, with their Godot at `~/gdtl-island/godot`.
- **The script:** `play.py` on the master runs `play.py` there with `PLAYTEST_HERE=1`, and copies any
  screenshot back into `.playtest/<slot>/`, so the paths it prints are local.
- **A desktop:** the host must be logged in to its desktop (`DISPLAY=:0`), as for the islands.

**Before using a host's slots, run `play.py push`** after any change to the game or to the playtest
tool. A push leaves `.playtest/` alone on both sides (it is in the islands' rsync excludes).

Prefer the hosts' slots for long runs: two local slots load this laptop (and its UPS), and each ran
at about 24 fps together against 75-85 on the Lenovo.

## Running playtests with Claude Code

1. Check the slots: `tools/playtest/play.py slots`. If you use host slots, run `tools/playtest/play.py push`.
2. Ask Claude Code for playtesters, one per slot, each with its own scenario. For example: "four
   playtesters: 104-1 trading, 104-2 mining, l1 saves and menus, l2 fitting and combat".
3. Claude Code starts one `playtester` agent per slot in the background. Each one:
   - starts its slot and plays its scenario;
   - checks the screen against `state` after each meaningful action;
   - stops its slot at the end;
   - reports its findings with the exact commands to repeat them.
4. Check each finding by hand ("Checking findings") before fixing anything.

### The agent

`.claude/agents/playtester.md` sets `model: sonnet`, `effort: low` and the tools `Bash` and `Read`
(Read to see screenshots). Its instructions:
- name the slot in every command;
- read the events before judging a surprise;
- stay away from the debug button;
- keep to the action budget;
- report each finding with its severity (crash, bug, inconsistency, confusing), steps, expected and
  seen.

It never reads or edits code. To make it cheaper, set `model: haiku` (it may misread the dense HUD
more often: compare one run of each on the same scenario first).

### A scenario

Give each agent:
- its slot;
- a goal a player would have;
- the odd paths to try;
- a budget in commands (80 to 150).

For example:

> Slot: 104-2. Scenario: a miner's career. Start a new game (the starting ship is a prospector with
> laser, harpoon and lance). Undock, find an asteroid, and try every way to get ore. Collect it, work a
> rock until it is worked out, take the ore to a station and sell it. Compare cargo and bank against
> `state` throughout. Odd paths: tools with no target, at a station, at a moon, with the safety on
> and off; switch tools mid-action; fill the hold and keep mining. If you lose the ship, read the
> events and carry on from the respawn. About 150 play.py commands at most, then `stop` the slot.
> Ignore the ALSA audio-driver error (no sound card on that machine). End with your report of findings.

The scenarios run so far:
- **Trading** end to end: buy, fly to another station, sell, with prices at each, and escorts.
- **Mining:** laser, lance, harpoon, a worked-out rock, a full hold, selling ore.
- **Menus and saves:** every slot, overwriting, loading, the options, losing the ship.
- **Fitting and combat:** every store tab, the stats line, then each weapon, tool and course button
  in a fight.

### What a run costs

The first runs (2026-11-15), Sonnet at low effort:

| Budget | Time | Tokens |
|---|---|---|
| 45 to 125 commands | 5 to 18 minutes | 38 to 77 thousand |

Four at once made one batch.

## Checking findings

Reproduce each finding yourself on a free slot before changing anything: the agent's own steps,
then `state`, `errors` and a screenshot.

The agents' usual misreadings:
- **Cargo gone after a ship loss** is the loss rule. The events show "PLAYER SHIP DESTROYED" and
  "SHIP LOST".
- **APPROACH reading HOLD <distance>** means a weapon is switched on at the target, and the ship holds
  at its range. "Approach crawls at 1 m/s" was this.
- **An overlay button turned off** hides the brackets of its kind. "No targets at all" was this.
- **Patrol beacons and passes** are points, not stations: an empty triangle is a beacon, a square a
  station.
- **A click by id after the list changed** may press another button: ids change with every `look`.
- **An error only on a host** may belong to the machine (no sound card, the `NO GRAB` of a hidden
  window). Check it here.

Findings worth keeping, once confirmed, go in a commit message like any fix: what the playtest saw,
the cause, the fix, how it was checked.

## Extending it

- **A server command** is a `cmd_<name>(args)` function in `play_server.gd`. It returns a value, or
  `{"error": text}`, and may yield (wait frames or seconds) before returning. Add its arguments in
  `play.py`'s `command()`, and a line in the table above.
- **Another event** is one more `EventBus.connect` in `_ready`, logged through `_log`. Keep it to what a
  player would notice on screen. The NPC radio was left out as noise, since `look` shows it as text.
- **Another kind of control in `look`** goes in `_collect`. Keep its rule: only what a player can see
  and press. Anything the interface hides stays hidden.
- **Noise in the error lines** goes in `play.py`'s `NOISE`, never in the game.
- **Scenarios the agents cannot reach from a new game** (combat, escorts, a loaded hold) want a
  prepared start. A game start in `database/registry/game_starts/` could do it. `play.py start`
  always passes `test_start=start_default`, so it would need an option to name another start. Neither
  is made yet.

## Limits

- Real time only: a 3-minute flight takes 3 minutes. The world is never sped up (`Engine.time_scale`
  stretches the physics steps).
- One request at a time per slot. A long `wait` blocks the slot's other commands.
- Free flight (MANUAL) captures the mouse. In a hidden window that gives `NO GRAB` and clicks then
  leave free flight, as the router's rule says.
- No sound is checked: hosts without a sound card run the dummy audio driver.
