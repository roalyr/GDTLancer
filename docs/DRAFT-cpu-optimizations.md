# DRAFT: CPU optimisations, a survey with instructions for the next pass

Written 2026-11-15 after reading every `_process` / `_physics_process` path and the systems they
call, with one fresh fight bench. Nothing here is implemented. It is a work order for whoever picks
it up (an agent or a person), ranked by expected win over risk. Delete this note once the items are
done or struck out.

## Ground rules for the pass

- **No feature degrades.** Every change below is meant to produce the same decisions, the same
  hits, the same sounds and the same picture, only computed less often or shared. Where an item
  trades a bounded delay for cost, the delay is stated; do not go past it without asking.
- **Measure before and after, same way.** Baseline and verification:
  - `DISPLAY=:0 godot --no-window -s tools/fight_bench.gd n=8 secs=30` (16 ships fighting by the home
    station, quarter-scale render). Print `FIGHT` and `PROFILER` lines; compare median/p95/p99 and the
    profiler sections.
  - `DISPLAY=:0 godot --no-window -s tools/perf_ablation.gd mode=base` for the traffic-only case.
  - Run each at least twice; the bench seeds its RNG but fights diverge. Note the machine.
- **Tests stay green:** `godot --no-window -s addons/gut/gut_cmdln.gd -gexit` (all), or
  `-gselect=<file>` for one file. GUT 7.4.3 hangs on a test file that fails to parse, so parse new
  test files first. One "Parse Error" line in the output is expected (a test feeds a broken script on
  purpose). `assert_eq_deep` takes 2 arguments.
- **Caching rules already in the code, keep to them:**
  - Per-step caches live only in the game world: `StepCache.active()` (WorldManager switches it on as
    a zone loads). Unit tests run inside physics steps and change things between looks, so outside
    the world everything is fetched fresh. Any new per-step cache follows `StepCache.group`,
    `Agent.get_signature` (frame-stamped) or `Projectile.hittable_ships` (one static per-frame list).
  - Lists that stand longer than a step (obstacles) are invalidated by the things that change them
    (`NavigationSystem.forget_obstacles`), not by time.
  - Every periodic interval goes in the `UPDATE CADENCES` block of `src/autoload/Constants.gd`, with
    a comment stating the maximum tolerable delay, and ships' timers start at a random phase so the
    work spreads over steps.
- **Player/NPC parity:** anything an NPC reads (detection, enemy status, ranges) the player's HUD
  reads through the same functions; a cache must serve both or neither.
- **Commit style:** one commit per item, a long plain-prose message saying what was slow, why, what
  changed and the numbers before/after (see `git log` for the house style). Include the user's own
  uncommitted edits in the commit. End with the attribution line the session asks for.
- **Do not touch** (the user's decisions): wrecks stay unfrozen; physics stays at 30 Hz with
  interpolation; evolution is frozen (no behaviour change may alter what an NPC decides; caches
  must return the same values a fresh call would within the same step); the HitSurface bodies stay
  in the physics space unless measured to matter (item 11).

## Baseline (2026-11-15, desktop, fight_bench n=8 secs=30, quarter-scale render)

```
FIGHT n=8 frames=1418 median=23.9ms p95=33.4ms p99=42.5ms max=67.9ms rounds=77 alive=10
PROFILER frame 24.4 ms = physics 10.2 (0.73 steps/frame) + idle 14.2; sections: ai 2.6, nav 1.0, hud 1.9 (brackets 1.7 inside hud)
```

Per physics step that is ~14 ms, of which the profiler sees ai ~3.5 and nav ~1.4; the other ~9 ms
is Bullet, ToolController, OffScreen, projectiles, Agent._physics_process and the lance, none of
them sectioned. Of the 14.2 ms idle per frame, the HUD is 1.9; the other ~12 ms is rendering plus
the per-frame scripts (sound, effects, exhausts, view bands, camera), also unsectioned. **Item 0 is
to make those visible before cutting blind.**

The earlier pass (commits 624f29c, 2cb425c) measured by hand: AI ~2.6 ms, ToolController ~1.7,
OffScreen ~1.5 average, nav ~1.4, Bullet ~3 per desktop step in this fight.

## Items, ranked

### 0. Make the unsectioned time visible: DONE

Sections "tools", "offscreen", "rounds", "agent" (in physics steps) and "sound", "exhaust", "view"
(per frame) wrap those functions; the HUD readout lists them on two lines; fight_bench averages the
profiler over the whole measured run (it printed the last second only). Two runs, same machine:

```
FIGHT n=8 frames=1322 median=25.1ms p95=33.4ms p99=38.5ms max=49.3ms rounds=61 alive=8
PROFILER frame 23.1 ms = physics 9.0 (0.69 steps) + idle 14.1; sections ms a frame: ai 2.11, hud 1.87, sound 1.76, brackets 1.74, tools 1.21, view 1.11, nav 1.01, rounds 0.88, offscreen 0.59, agent 0.47, exhaust 0.19
FIGHT n=8 frames=1121 median=28.4ms p95=37.5ms p99=45.2ms max=72.4ms rounds=71 alive=11
PROFILER frame 27.1 ms = physics 11.8 (0.81 steps) + idle 15.3; sections ms a frame: ai 2.62, hud 2.39, brackets 2.26, sound 1.77, tools 1.63, nav 1.59, rounds 1.19, view 1.12, offscreen 0.81, agent 0.54, exhaust 0.21
```

Reading (first run): of 9.0 ms physics a frame the sections cover 6.3; the other ~2.7 is Bullet,
the lance and `_integrate_forces` outside nav. Of 14.1 ms idle, the per-frame sections cover ~4.9
(brackets are inside hud); ~9 ms is rendering at quarter scale, the swap and unmarked scripts.
What changes the plan: **sound is 1.8 ms a frame**, as much as the whole HUD, so item 6 moves up
beside item 1; **view (ViewDetail, every ship every frame) is 1.1 ms** and had no item (see 6b);
exhaust is cheap (0.2). `Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS` were tried and dropped:
Godot 3 keeps the worst frame of each second in them, not an average.

The original plan for this item follows.

- Add `FrameProfiler` sections round: `ToolController._physics_process` ("tools"),
  `OffScreen._physics_process` ("offscreen"), `Projectile._physics_process` ("rounds"),
  `Agent._physics_process` ("agent"), `SoundEffects._process` ("sound"),
  `EngineExhaustSet._process` ("exhaust"), `ViewDetail._process` ("view"). `begin/end` costs two
  meta reads and a dictionary write per call when a profiler runs, nothing when none does; for the
  per-ship ones wrap the whole function, not inner loops.
- Report `Performance.TIME_PROCESS` and `Performance.TIME_PHYSICS_PROCESS` beside the frame figures
  in `fight_bench.gd` (perf_ablation already does), so "idle minus TIME_PROCESS" gives the render and
  swap share. If that share dominates, the per-frame script items below (6, 7, 8, 9) matter less
  than draw calls, and `perf_ablation` modes `no_3d`, `no_ships_3d`, `no_particles` should be run on
  a fight (add a `mode=` to fight_bench the same way).
- Keep the readout in the HUD debug overlay as the existing sections are (`MainHUD._update_debug_overlay`).

### 1. AI scans: side strength recomputed per candidate: MEASURED, DROPPED

Tried as a memo for the length of one think (sides and damage per second, cleared on ammo
recovered, docking and undocking): exact, and no gain. Temporary sub-sections in the bench showed
`desire_against` at ~0.4 ms a frame with the memo and without; a ship asks it once or twice a think
(most candidates are filtered out before it), so there was nothing to share. Where the AI's
~2.4 ms a frame goes, from those sub-sections (they add ~0.5 ms of their own): combat handling 1.3
to 1.5 (engagement range 0.5, `_fire_at` 0.27, `_should_retreat` 0.23, `can_charge` 0.13,
`_charge` 0.10), desire 0.4, patrol 0.3, scans 0.1 to 0.3, decisions 0.1. No single cut is large;
the per-tool walks (`can_target`, `reach_on`, `lock_range_for`) under range, fire and retreat are
the common part, and a per-think cache of `reach_on` per tool and target would serve all three.

Follow-up, DONE: a per-think memo of `can_target` / `reach_on` was counted first and dropped (13 and
8 repeated calls a frame, ~0.1 ms). Split by state, a think is combat 1.16 ms a frame, docked 0.2
to 0.4 (`is_station_watched`, `is_called_out`: small, varies), patrol 0.12, the rest under 0.1;
combat is engagement range 0.35, retreat 0.18, fire 0.17, desire 0.17. Timed on live ships,
`can_target` was 14 to 25 us, over half of it `Agent.detects`, asked again for every tool against
the same target (the target's four weapons each asked whether it sees this ship). ToolController
now splits it into `sees(target)` and `fits(tool, target)`; the loops over tools ask `sees` once,
and `_engagement_range` passes its one answer to the cannon search, the base range and its own
lock. `_should_retreat` works out its level (desperation walks the fit for its value) once, not
twice. Engagement range ~210 to ~125 us a call, the retreat check ~45 to ~24 us; the bench's ai
section is too noisy to show it (1.9 to 2.5 ms either way). Left: desperation's `get_value` (a
template lookup per fitted part, several times a think) could be kept per fit if that ever shows.

The original note follows.


Where: `src/modules/piloting/ship_controller_ai.gd` `scan_for_target()` (1751) →
`desire_against()` (1779) → `src/core/systems/combat_assessment.gd` `side_of()` (37).

What happens: for every candidate enemy, `desire_against` calls `side_of(agent_script)` and
`side_of(target)`. Each `side_of` walks every agent body (`get_tree().get_nodes_in_group`, not
`StepCache.group`), and for each friend within `AI_TEAM_RADIUS` calls `get_damage_per_second()`,
which walks that ship's tools and lances and calls `get_top_speed()`. Per scan per ship that is
O(candidates × ships) dps evaluations; with 16 ships ~128 per scan, all in one step. Scans are
staggered (1 s each) but each is a spike inside a think, and `_process_combat` repeats
`desire_against` on the current target every `AI_SCAN_INTERVAL`, `_tick_decision` once more.

Change, same results within a step:
- Cache `side_of(body)` per physics frame in the world: a static dictionary
  `{instance_id: [frame, side]}` in CombatAssessment cleared when the frame changes, used only when
  `StepCache.active()`. Within one scan `side_of(agent_script)` is identical for every candidate,
  and every friend of the same target scanning in the same step shares `side_of(target)`.
- Cache `Agent.get_damage_per_second()` per physics frame the way `get_signature` is (frame stamp
  on the agent). Ammo can only change inside a step by a shot fired earlier in the same step; the
  AI's estimate is one step stale at most, which is within what `AI_SCAN_INTERVAL` already allows.
  If that staleness worries anyone, cache only within `side_of` (one dictionary per call chain)
  instead.
- `side_of` and `fire_on` use `StepCache.group`.

Verify: `test_ship_controller_ai.gd`, `test_evolution.gd` (desire figures), and in the bench the
`ai` section. Expected: `ai` from ~3.5 to ~1.5 ms a step.

### 2. One ship snapshot per step for the many group walks

Where: every per-step or per-second loop over `"agent_body"` that reads `get("is_wreck")`,
`get("is_docked")`, `get("faction")`, `global_transform.origin` through dynamic property access:
`ToolController.friend_in_the_way` (691, per laser/cannon cycle), `OffScreen._nearest_enemy` (281,
per off-screen ship per tick, and it uses `get_nodes_in_group` rather than `StepCache.group`),
`CombatAssessment.side_of`, `ThreatRing.threats` (38), `AwarenessZone.ships_seen` (128),
`ShipControllerAI.scan_for_target`, `get_caravan`, `muster_mates`, `is_station_watched`, `_take_ward`,
`LooseLance._physics_process`, `Hazard._physics_process`, `BeaconNetwork._update`.
There are 77 `get("is_wreck")`/`get("is_docked")` sites; dynamic `get()` and `has_method()` are
the GDScript overhead the earlier pass measured at ~17 us per `detects()` call.

Change: extend `Projectile.hittable_ships` into a general per-step list (move it to a small
`src/core/utils/ship_index.gd` or into StepCache): `[body, origin, faction, is_wreck, is_docked,
radius, is_platform]` built once per physics frame in the world from `StepCache.group`. Callers
that only need live, undocked ships iterate it and skip the dynamic gets. Keep `is_instance_valid`
checks (a ship freed earlier in the step is still listed, as now). Per-frame HUD callers (`threats`,
`ships_seen`) run in idle time, outside a step, where `StepCache.active()` is false: either let the
index also be valid for the idle part of the same frame (stamp with `Engine.get_physics_frames()`
and accept that bodies do not move between the last step and the idle frame, which is true), or
leave those callers alone (they run at 0.13 to 0.5 s cadences and are cheap enough).

Verify: tests for each touched system; bench sections "tools", "offscreen" from item 0.
Expected: OffScreen and ToolController each a third to a half cheaper per step.

### 3. `is_enemy_of` walks the station group for territorial factions

Where: `src/core/agents/agent.gd` `is_enemy_of` (597) → `in_territory` (611) →
`get_tree().get_nodes_in_group("faction_station")` per call. `is_enemy_of` is called from scans,
bracket refreshes (each bracket every 0.25 s), the threat ring (0.27 s), the awareness strip
(0.13 s), ThreatWatch (0.5 s), OffScreen `_nearest_enemy` (per pair per tick) and `_limit_mark_distances`.

Change:
- Cache the territorial stations per faction the way obstacles are cached: a tree meta
  `{faction: [positions]}` built on first use, dropped by stations entering/leaving the tree (add
  a `forget` call where `faction_station` is added/removed, and on zone load) and when
  `StepCache.set_active` clears things.
- Reorder the checks so the cheapest decisive one runs first: grudge, then the faction war list
  (for a non-player `other`), then bounty, then territory. All branches are ORs returning true, so
  the result is unchanged; for `other.faction == "player"` keep the standing branch last as now.

Verify: the tests that exercise `is_enemy_of` (`test_ship_controller_ai.gd`, `test_lance.gd`,
`test_standing_market.gd`, `test_main_hud_projected_targeting.gd`); the station group is joined in
`src/scenes/game_world/station/faction_station.gd` (the place for the `forget` call); the bench's
`ai` and HUD sections.

### 4. Engagement range computed twice per think: DONE

Kept for the think (`_thinking`, `_range_memo`: target and covering as the key; fresh outside a
think, as tests ask). In a bench run it was asked 4477 times and worked out 3478: about 0.1 ms a
frame saved of the ~0.5 it costs, under the bench's run-to-run noise but exact.


Where: `ship_controller_ai.gd` `get_engagement_range()` (579), called from `_process_combat` (872)
and again from `_update_afterburner` (687) in the same `_think`. Each call runs
`_base_engagement_range` (616, walks tools × `can_target` → `detects`, `reach_on` → `lock_range_for`),
`_own_lock_on` (607, the same walk) and `lock_range_of(target)` (594, the target's tools).

Change: memoise per think: store `[Engine.get_physics_frames(), target, value]` and return it when
both match. Identical values within a step. Optionally let `_fire_at` (935) reuse the per-tool
`reach_on` results computed in the same think.

Verify: `test_ship_controller_ai.gd`. Small but free.

### 5. Rounds raycast for rocks every step

MEASURED, NOT WORTH IT as written: split in the bench, the rounds section (~1.15 ms a frame) is
ships 0.63, the rock raycast 0.12, the rest (steering, moving) ~0.4. A pre-cull would save at most
0.1 ms and has to prove obstacle radii cover every rock's collider. The cost is `_first_ship_on`:
every round tests every hittable ship, 58 in the bench (traffic far from the fight included).
Exact alternative if wanted: in `hittable_ships`, bin each ship per step into the 1 km cells its
reach sphere (radius + speed x delta + PROJECTILE_FUSE_MARGIN) overlaps; a round looks only in the
cells its own sphere of `step` round `from` overlaps. A ship passing today's distance test shares a
cell (the point of its reach sphere nearest `from` is in both boxes), so the hits are the same;
dedupe ships met in two cells. Expected 0.63 to ~0.2 ms, less the binning (~58 inserts a step).

The original note follows.


Where: `src/core/agents/components/projectile.gd` `_first_rock_on` (118): one
`intersect_ray` per round per step against `SHOT_BLOCK_MASK` (every layer, then filtered to the
`asteroid` group). Cannon-heavy fights keep tens of rounds in flight at 30 steps/s.

Change, identical hits: before raycasting, test the step segment against the cached obstacle index
(`NavigationSystem.get_obstacle_index(tree).tree`, the nested bins; the segment is short so one
`_push_along`-style sphere-segment test suffices, written as a static `segment_near(from, to,
items)`), and raycast only when the segment passes within an obstacle's radius plus a margin
(`PROJECTILE_FUSE_MARGIN`). Rocks, stations and planets are all obstacles, so nothing that could be
hit is skipped; ships are handled by `_first_ship_on`. A round that is not near any obstacle skips
the physics query entirely.

Verify: `test_weapons.gd` and `test_tool_controller.gd` (shell hits on rocks); the bench's
"rounds" section with a cannon-heavy side (bench SIDE lists include cannons already).

### 6. Sound: every ship re-ranked and re-polled every frame

DONE: 1.8 to 0.8 ms a frame (three bench runs). The mixer tracks every ship in the sector (58 in
the bench, traffic included), not only the fight. Sub-sections showed the carried loops at 1.2 ms
(three `get_node_or_null` by name per ship per frame), engines 0.5, ranking 0.4. Now each ship's
entry keeps its loop nodes, a ship off the air with none is skipped, a loop off and silent is left
alone, the wreck check runs only for heard ships, and carriers are re-ranked every
`SOUND_CARRIER_INTERVAL` (0.23 s). Tests: `test_sound_effects.gd` (two new).

The original note follows.

Where: `src/core/sound/sound_effects.gd` `_process` (119) and `loop_carriers` (160). Per frame:
three `duplicate()`s of the voice/ship/missile lists; `loop_carriers` measures and sorts every ship
and missile by distance; then per ship `_drive_engine`, `laser_on` (walks tools), `winching` (walks
tools and tethers), `leaking`, and three `_drive_loop`s (three `get_node_or_null`, meta reads,
`set_volume_3d` each), for ships that are not even on air.

Change:
- Rank carriers on a cadence: `SOUND_CARRIER_INTERVAL 0.25 s` (new constant in UPDATE CADENCES,
  max tolerable ~0.5 s: a loop switching on a quarter second later is inaudible), keeping the
  `{id: true}` dictionary between.
- Per frame touch only ships that are on air or still have a loop node fading out: `_drive_loop`
  already returns when there is no node and `on` is false, so compute `on` (`laser_on`,
  `winching`, `leaking`) only for ships in `heard`, and skip the three lookups otherwise by keeping
  a per-ship "has loops" flag set when a loop is attached and cleared when all are silent.
- Drop the `duplicate()`s: collect removals in a list and erase after the loop.

Verify: `test_sound_effects.gd` (it checks bus peaks, keep its expectations; see the memory note
that real audio output is verified by bus peak, not properties). Expected: a per-frame cost that
grows with ships becomes one that grows with carriers (`SOUND_LOOP_CARRIERS`).

### 6b. ViewDetail: every ship and rock runs `_process` every frame (found by item 0)

DONE: 1.1 to 0.35 ms a frame, and the engine's per-node dispatch for ~160 details (ships, rocks)
is gone too (idle ~1 ms lower). No separate driver node (a deferred one showed up as an orphan in
GUT): the first ViewDetail in the tree leads and checks them all, the next takes over when it
leaves. Checks fall due on a shared clock (the frames' deltas summed), so a detail not due costs one
field read; a field of view change in any viewport makes all due at once. `_timer` stays as a
setget onto the due time for tests. Test: `test_view_band.gd` (leader hand-over).

The original note follows.

Where: `src/core/agents/components/view_detail.gd` `_judge`. Every host (each ship, each of ~65
rocks) has a ViewDetail node whose `_process` fetches `get_viewport().get_camera()` and compares
`camera.fov` every frame, to judge its band only every `VIEW_CHECK_INTERVAL` or on a zoom. With
~90 hosts that is ~1.1 ms a frame of script calls doing almost nothing.

Change, same bands at the same moments: one driver per viewport (a static registry of live
ViewDetails, or a single node the WorldManager adds) that reads the camera and fov once a frame,
and only then walks the details whose timer is due, or all of them when the fov changed. Each
ViewDetail does `set_process(false)` and registers in `attach`, unregisters on `_exit_tree`. Keep
`update_band(camera)` public (tests call it). Tests also call `detail._process(0.0)` directly
(`test_view_band.gd`), so keep that entry working for a detail with no driver.

Verify: `test_view_band.gd`, `test_mesh_lod.gd`, `test_hull_scars.gd`; bench "view" section to
~0.1 ms.

### 7. Smoulder spots, leaks and trails write particle and shader properties every frame

Where: `hull_smoulder_effect.gd` `_process` (65): per spot per frame sets `_sparks.emitting`,
`_embers.emitting`, `_embers.initial_velocity` and a shader param, shown or not;
`fuel_leak_effect.gd` `_process`: shader param and `initial_velocity` per leak per frame;
`laser_hit_effect.gd`, `damage_trail_effect.gd` are short-lived or already cadenced.
After a fight there are dozens of spots, most hidden by `SMOULDER_MAX_SHOWN`.

Change, same picture: a spot not shown only ages (and runs its `SMOULDER_CHECK_INTERVAL` check);
a shown one writes `emitting` only when the value changes, and writes glow-dependent values when
`glow` has moved by more than 1/64 since the last write (invisible on a 0..1 intensity). Same for
the leak's pressure. Quantising to 1/64 steps the fade in 64 steps over its duration; nobody sees it.

Verify: `test_hull_scars.gd` (no smoulder test exists; add a small one for the "write only on
change" guard), and a look in play (a scarred ship cooling).

### 8. Hull scars set a shared shader clock once per ship per frame

DONE: one write a frame per material (`_CLOCK_SET`, by idle frame). Too small to see in the bench.


Where: `hull_scars.gd` `_process` (134): every scarred ship sets `ScarMaterial` and
`SlagMaterial` `now` per frame; the materials are shared, so all but the first write are redundant.

Change: a static `_CLOCK_FRAME` guard: write when `Engine.get_frames_drawn()` differs from the last
write. Trivial, zero risk.

### 9. HUD: unconditional modulate writes per frame

MEASURED, NOT WORTH IT: the hud section minus brackets is 0.1 to 0.2 ms a frame in the bench, and
these writes live in that; `ThreatRing._draw` already returns at once with nothing to draw. Brackets
(~1.8 ms) are the HUD's cost; see the last paragraph below.


Where: `main_hud.gd` `_refresh_toggle_button_states` (954), per frame by design (a tap answers at
once): eight `modulate` writes a frame whether or not anything changed, plus
`_get_player_navigation_command_type`.

Change: keep the per-frame call; in `_apply_button_toggle_state` compare against the button's
current modulate (or a stored bool) and skip the write. Also `ThreatRing._process` calls
`update()` every frame even when it has nothing to draw: call it only when `_threats` or the
partners list is non-empty or was non-empty last frame.

Brackets, DONE (part): ~1.95 to ~1.45 ms a frame (three runs each; 186 brackets, 40 shown, 10 on
screen). Split in the bench: the slow re-check slice 1.3 (detects 0.34, refresh_style 0.36, the
distance-mark ranking 0.27, which is a ~2.7 ms spike each quarter second: `is_enemy_of` on all 58
ships), the per-frame loop ~0.9. Now: marks ranked only among shown brackets (a hidden one shows no
number; on a full refresh after the loop, so it goes by the fresh world_shown); the 146 hidden
brackets skip the hide call when already hidden; the viewport scale and the interpolation setting
are read once a frame and Interp.origin / ScreenSpace.world_to_screen inlined. Left: detects and
refresh_style in the slice (per-bracket GDScript, nothing repeated).

Brackets (1.7 ms a frame here with ~170 brackets) are already lean per bracket (~10 us); the
remaining cost is per-bracket GDScript. Do not halve their update rate (static targets would judder
during camera pans). If item 0 shows brackets still matter on the phone, the one safe cut is to skip
re-projection when neither the camera transform nor the target moved since last frame (camera still,
target static), which helps while docked or paused, not in flight.

### 10. Per-ship per-step small change (cheap, do alongside item 2)

- `agent.gd` `_physics_process` (1254): `Settings.get_option("engine_exhausts")` and two
  `movement_system.get("last_thrust_fraction")` per ship per step. Cache the option in a member set
  from `Settings.changed` (EngineExhaustSet already listens), and read `movement_system.last_thrust_fraction`
  directly (movement_system is always the MovementSystem script). `exp(-delta / SIG_ENGINE_SMOOTHING)`
  is a constant for the fixed step; keep it as is unless profiling shows it (it will not).
- `navigation_system.gd` `_update_navigation` (172): `_tools.has_method("cannon_facing")` per step;
  cache the bool with the `_tools` lookup. `command_approach.gd` `execute` calls
  `_get_target_effective_size` (376) every step; for a target without `get_interaction_radius` it
  falls to `get_node_or_null("Model")` and more. Store the size in the command dictionary on
  `is_new` (a target's size does not change while approached). Same for `command_orbit`.
- `tool_controller.gd` `_physics_process` (457): `_point_defence` (489) scans the tool list for a
  free laser every step; keep a count of lasers so ships without one return at once.
- `loose_lance.gd` `can_be_scooped_by`: test the distance first, then the method and property
  checks (same result, far fewer dynamic calls when many ships are far away).

### 11. Bullet: hit-surface trimeshes move with every ship (deferred by the user; measure only)

Each ship carries a `StaticBody` with a trimesh (`CollisionHull.add_hit_surface`, on layer 20,
mask 0) under its visual root, so Bullet updates a static trimesh body's transform and broadphase
AABB every step per ship. Only shot rays use it. The user deferred moving these out of the physics
space (hand-fitted primitives later; see the physics-performance note). Do nothing to the game here
except measure: a one-line switch in the bench that skips `add_hit_surface` (shots then land on the
convex hull, scars misplaced, fine for a measurement) tells how much of the ~3 ms Bullet step they
are. Report the number; the user decides.

Likewise `can_sleep = false` on every RigidBody is intentional (wrecks stay live). Leave it.

### 12. Not recommended without a separate decision

- Switching the physics engine (Bullet → GodotPhysics): different contact behaviour, the evolution
  presets were bred under Bullet. No.
- `rendering/threads/thread_model` multi-threaded: experimental in Godot 3.6, unreliable on Android
  GLES2/3 drivers. Only as an experiment on desktop if item 0 shows render command building as the
  main idle cost.
- Lower `AI_THINK_INTERVAL`, `NAV_AVOID_INTERVAL` or any cadence past its stated maximum: reaction
  time shows in fights.

## Suggested order and checkpoints

1. Item 0 (sections, the bench averaging the profiler). Done; baseline recorded under item 0.
2. Item 1 (dropped, measured) and 4 (done). Next 6 and 6b (sound and view: together ~2.9 ms a
   frame, item 0's surprise), before 2 and 3.
   Done since: 6, 6b, 8; 9 and 5 measured and left (see each). Left, by measured size: brackets
   (~1.8 ms, see the end of item 9), AI combat handling (item 1's note: a per-think `reach_on`
   cache), item 2 (tools 1.3, offscreen 0.7), the rounds' ship grid (item 5's note), 3, 7, 10, 11.
   The bench varies ±10% run to run (fights diverge): compare sections over three runs, and for
   small items count calls instead (a temporary counter printed at the end of the bench).
3. Item 2 (ship snapshot) and the item 10 bits, then 3. Bench. Commit each.
4. Item 5. Bench with a cannon-heavy fight. Commit.
5. Items 6, 7, 8, 9 (idle-time scripts). Bench. Commit each.
6. Item 11 measurement only; write the number here.
7. After the pass: the user exports a debug APK to Dropbox/Dump for the phone test (their rule), and
   the frame readout (`show_fps`, the debug overlay) is what they will compare.

Each step: run the touched test files with `-gselect` first, the full suite before the commit, the
bench twice, and put the before/after medians in the commit message. If an item does not move the
numbers, say so in the commit or drop it; do not keep a cache nobody needs.

## Test files that cover the touched code

- `src/tests/modules/piloting/test_ship_controller_ai.gd` (items 1, 3, 4)
- `src/tests/core/agents/components/test_tool_controller.gd` (items 2, 5, 10)
- `src/tests/core/agents/components/test_navigation_system.gd` (item 10)
- `src/tests/core/sound/test_sound_effects.gd` (item 6)
- `src/tests/core/ui/test_main_hud_projected_targeting.gd` (item 9)
- `src/tests/core/evolution/test_evolution.gd` (item 1: desire values must not change)
- `src/tests/core/systems/test_offscreen.gd`, `test_threat_watch.gd`, `test_wages.gd`,
  `test_docking_logic.gd` (item 2)
- `src/tests/core/agents/components/test_weapons.gd` (item 5)
- `src/tests/core/agents/effects/test_hull_scars.gd` (items 7, 8)
