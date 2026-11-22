# DRAFT: handover check before the extensive playtest

Written 2026-11-15 at `6ef3ffb`. A read-only check: nothing was run, built or edited for it, and the
tests were not rerun. Delete this note once the playtest has started and its items have moved into
commits or the other drafts.

## State at handover

| What | State |
|---|---|
| Working tree | Clean. |
| Branch | `master`, one commit ahead of `origin/master` (`6ef3ffb`, docs only): not pushed. |
| Tests | Not rerun here. The last code commit (`5041414`) records GUT 759 passing, 0 failing, 0 risky; only a docs commit came after it. |
| APK | `Dropbox/Dump/GDTLancer-rev.apk`, built 2026-11-15 19:21, the minute of the last code commit. It should hold everything; the build itself was not checked. |
| Physics | 30 Hz (`physics_fps=30` in `project.godot`). |
| Evolution | Frozen since 2026-11-12 (era 67). No Godot process is running. |
| Code markers | No TODO, FIXME, XXX or HACK in `src` or `scenes`. |
| Playtest slots | `.playtest/` holds `l1`, `l2`, `104-1`, `104-2`. The island host has the game as of the last `play.py push`, which may be older than the last fixes. |
| Export version | `version/name="1.0"`, `version/code=1` in `export_presets.cfg`, while the README says 0.x. |

## What changed since the last hands-on play

All of these came from the agent playtests on 2026-11-15 and were checked on screenshots or by
tests, never by a person playing:

- **Menus** (`01b326f`): Save needs a game, New asks during one, a real clock, a MENU button while docked.
- **Loading** (`669e1ad`): no stacked sectors after a load, save slots with a picker, the autosave apart from the player's saves.
- **Lance and cannon** (`a792b09`): one lance per CHARGE, never at a moon; the cannon asks for a ship.
- **Course and tool buttons** (`9eb2dee`): ORBIT, FLEE and APPROACH say what they need with nothing selected; the laser on a whole rock says it gives no ore; HOLD says why the ship stops at weapon range.
- **Store** (`eec746c`): storage names in full, FIT stacked over SELL.
- **Beacons** (`5041414`): a picket in its faction's standing colour, other beacons amber, a mayday red and filled.
- **Mining** (`1939cfe`): worked-out rocks say so, grow their ore back, and a save keeps them as left.
- **Autolevel** (`4e686c3`): the ship slowly rolls level, a setting, on by default.
- **Exhausts** (`624d1ff`, `bf9807c`): a lit afterburner lengthens the plume; a missile's plume burns again.

## What only a person can check

The agents play through text and screenshots in real time, on the desktop. They do not hear, do not
feel the controls and never touched the phone.

### On the phone
- **Frame rate in a crowded fight**, with `show_fps` on. Readings are owed for the options as they
  are and for `discard` in the solid shader (`98d3ef5`): see `DRAFT-gpu-optimizations.md`, items 0, 4 and 12.
- **30 Hz feel**: the dynamic camera is on by default again, its leash now a spring stepped with the physics and drawn interpolated; does it still jitter at speed?
- **SLOW DOWN ON LAG**: still waiting for a verdict since 2026-11-10.
- **Scar cooling**: stepped colour after a long session would mean lowered precision (`DRAFT-merged-scar-mesh.md`).
- **Touch**: every action from an on-screen control, the store's stacked storage rows, the save picker.

### Looks, in play
- **View detail** (`DRAFT-view-detail.md`, six items open): LOD switching at normal zoom, full zoom
  on a ship 10 to 20 km out, band flicker while orbiting at a threshold, light ships losing scars
  from about 1.3 km, rock dust from 880 m, the cost of `ViewDetail` in a full sector.
- **Scars and slag** (`DRAFT-merged-scar-mesh.md`, five items open): rebuild cost under sustained
  fire on a heavy, looks unchanged, culling per chunk, slag crowding at zero hull.
- **Beacon colours** against the nebula, and whether a filled red mayday reads at a glance.
- **Autolevel**: whether it fights the player in MANUAL flight or while orbiting.

### Sound
Never checked by the agents (the hosts run a dummy audio driver). Listen to a fight, a dock, the
lance, the afterburner.

### Play the agents could not reach
From a new game they got to docking, trading, mining and the menus. They did not get to:
- **Combat** beyond a first contact, and the cannon's FAR / CLOSING / TURNING / BLOCKED words in a real fight.
- **Escort work and wages.**
- **A long session**: save and load after hours, regrown rocks after a reload, the autosave next to hand saves.
- **A ship loss** and waking at home.
- **Free flight (MANUAL)**: in a hidden window it loses the mouse grab.

## Known and left as it is

Not bugs; listed so they are not reported again.
- **Parity gaps** deferred on 2026-11-14: the player sees only the docked station's prices, and cannot call a mayday.
- **Ideas not built**: stealthy NPCs throttling down, simple dialogue on the radio.
- **CPU pass paused** on 2026-11-15 (fight bench about 18 to 24 ms a frame): items 3, 7, 10 and 11 and three notes are left in `DRAFT-cpu-optimizations.md`.
- **GPU pass**: items 8 to 12 are open; the starsphere stays as it is.
- **Hit surfaces and collision hulls** stay trimeshes for now.
- **Prepared starts for playtests** (a fight, an escort, a loaded hold) are not made.

## Before starting

1. Decide on the unpushed commit `6ef3ffb` (docs only).
2. Install the APK from 19:21. If in doubt about it, export again: nothing in the game changed after it.
3. Start a new game for the first session: saves from before `669e1ad` (slots) and `1939cfe` (rock
   deposits kept) were not checked against the current build.
4. Turn `show_fps` on, and note the device, the scene and the number with each performance remark.

## Reporting

One line per finding is enough: where, what was done, what was seen, what was expected. A screenshot
for anything visual. Findings on looks belong to the checklists in the two drafts above, so those can
be ticked or tuned and then deleted.
