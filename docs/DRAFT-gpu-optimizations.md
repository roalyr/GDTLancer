# DRAFT: GPU and rendering optimisations, a survey with instructions for the next pass

Written 2026-11-15, the rendering companion to [DRAFT-cpu-optimizations.md](DRAFT-cpu-optimizations.md),
after reading the render settings, every shader, the scene prefabs (ships, exhausts, effects, star,
nebula starsphere, rocks, planets, HUD) and the two bench tools. Nothing here is implemented. It is a
work order for whoever picks it up, ranked by expected win over risk. Delete this note once the
items are done or struck out.

Rendering here is GLES2 on purpose (phones). That fixes what costs what; see "GLES2 facts" below.
Several items below cannot be measured on the desktop at all (tile-GPU behaviour): those say so and
need the phone and its FPS readout (Settings `show_fps`).

## Ground rules for the pass

- **The picture does not change** unless an item says "visual change" and the user has agreed. A
  pure-cost item must produce the same frame, pixel for pixel or as near as dithering allows. Compare
  with the screenshot tools: `tools/ui_shots.gd`, `tools/flight_shots.gd` (see MAINTAINING.md,
  "Probes, screenshots and balance runs") before and after.
- **Measure before and after, same way.**
  - Traffic, no fight: `DISPLAY=:0 godot --no-window -s tools/perf_ablation.gd mode=<mode>`, one mode
    per process. Modes: `base` (quarter-scale render), `base_full` (full scale), `no_3d`, `no_hud`,
    `no_lights`, `no_particles`, `no_rocks`, `no_ships_3d`, `lod_low`, `physics_30`, `no_ai`. It prints
    one `ABLATE` line with frame times, the physics/idle split, and the engine monitors (`draws`,
    `objects`, `materials`, `shaders`, `surfaces`, `2d_items`, `2d_draws`, `vertices`), then the
    FrameProfiler report. A run takes about 3.5 minutes on this desktop (two of them are loading and
    settling); give it a timeout of at least 8 minutes, and never run two at once (they share the GPU
    and the numbers are meaningless).
  - Fight: `DISPLAY=:0 godot --no-window -s tools/fight_bench.gd n=8 secs=30` (quarter scale).
  - `base_full - base` is the fill-rate share; `base - no_3d` is everything 3D costs on the CPU side
    (culling, draw submission, GLES2 state changes); `no_hud` the 2D share.
- **The phone is the target.** Desktop GLES2 hides tile-GPU costs (`discard`, overdraw, highp). After
  each item the user exports a debug APK to Dropbox/Dump (their rule) and reads the FPS overlay. Note
  in the commit which device.
- **Tests stay green:** `godot --no-window -s addons/gut/gut_cmdln.gd -gexit` (GUT 7.4.3 hangs on a
  test file that fails to parse; one "Parse Error" line in the output is expected).
- **Shaders share blocks** (`// @common dither`, `// @common nlp`) synced by `tools/sync_shader_blocks.py`.
  Edit a block once and run the sync; never hand-edit a copy.
- **Options stay options.** Existing render options in Settings: `render_scale` (1, 0.5, 0.25),
  `particles`, `hit_effects` (scars, slag, hit surfaces), `engine_exhausts`, `show_fps`,
  `slow_down_on_lag`. A cut that changes the look belongs behind one of these or a new one, default
  as today, the user decides.
- **Commit style:** one commit per item, long plain-prose message: what was drawn, why it cost, what
  changed, the numbers before/after and on which machine. Include the user's own uncommitted edits.
- **Do not touch** (the user's decisions): GLES2 stays; the dither/posterize look stays; the
  wrecks, scars and effects stay as features; Godot stays 3.6.

## GLES2 facts that shape every item (Godot 3.6)

- Forward renderer, **one pass per light per object**: an object touched by the star's light and
  three hit lights is drawn four times (plus one for the ambient). A hit light's reach (40 m) and an
  explosion's (144 m) decide what it touches; `Constants.HIT_FX_MAX_LIGHTS` (10) and
  `EXPLOSION_MAX_LIGHTS` (1) cap them for this reason.
- **No instancing in 3D**: every MeshInstance is a draw call; a MultiMesh is one draw per instance.
  The monitors `draws` and `surfaces` are the honest count.
- **No 3D batching**: state changes (`materials`, `shaders`, `surfaces` monitors) each cost CPU in
  the driver; sharing materials and meshes reduces them.
- **Transparent objects** (`blend_add`, `blend_mix`) are sorted and drawn back to front after the
  opaque pass; each full-screen transparent layer is a full-screen fill. Tile GPUs (every phone) are
  fast at opaque with early depth rejection and slow at layered transparency.
- **`discard` in a fragment shader** turns off early depth rejection and hidden-surface removal for
  every object using that shader on tile GPUs (PowerVR, Mali, Adreno): the whole object is shaded,
  then rejected. Invisible on desktop GPUs.
- **Precision**: the project sets `gles2/compatibility/disable_half_float=true`, so every shader runs
  at full precision on phones. Half precision is up to twice as fast per fragment on Mali/Adreno; it
  was presumably turned off for a precision bug (the dither takes `FRAGCOORD`, distances run to
  300 km). Only an on-device experiment can say (item 12).
- **Glow** (post-process) is off: `global_environment.tres` sets glow parameters but not
  `glow_enabled`. Keep it off; on GLES2 it is several full-screen passes.
- **Shadows**: no light casts them. The `quality/shadow_atlas/size=2048` setting only allocates a
  root-viewport texture; the world viewport has its own `shadow_atlas_size` (0). Harmless.
- **2D batching** is on by default in 3.6 GLES2; the HUD's `2d_draws` monitor shows how well it
  merges.

## What a frame draws (Elace, by the home station)

- **Background:** `global_environment.tres` draws a ProceduralSky (one full-screen pass) and the
  starsphere `scenes/starspheres/global_nebulas_starsphere/global_nebulas.tscn` draws over it: 27
  mesh instances, 19 of them nebula shells (`nebula.gdshader`: `blend_add`, `cull_front`, three
  triplanar texture reads and a `discard`) seen from inside, each covering the whole screen, plus
  three star sprites. The shells are centred on the camera (`starsphere_slot.gd`) and the shader has
  no `TIME`: the background is a fixed picture from the camera's point of view.
- **Star:** surface sphere + two corona shells (`cull_front`, vertex displacement sampling three
  textures per vertex) + a halo (glow shader) + a sprite, all additive, one OmniLight of 300 km reach
  (the sun).
- **Planets and moons:** six bodies, each one SphereMesh with `solid.gdshader` (no detail textures
  set, so two of its texture reads are skipped), scaled down far away by the NLP block.
- **Rocks:** 65 in the two fields plus the belt; models of 45k to 73k triangles with LODs at 50%,
  25%, 12.5% (`rock_06_73k`: 73728 / 36863 / 18431 / 9215), picked by view band
  (`LOD_LEVEL_BY_BAND_DENSE = [0, 1, 2, 3, 3]`): a rock 10 px tall still draws 9k triangles.
  One material (`mat_asteroid_rock.tres`, solid shader), so draws are cheap state-wise.
- **Ships:** placeholder hulls from primitives (`primitive_form.gd`): 8 to 13 MeshInstances per hull
  by weight class, each with its own freshly made CubeMesh/CylinderMesh/SphereMesh (low-poly, but
  not shared between pieces or ships), three shared materials (paint, metal, glow). Fitted parts add
  2 to 3 primitives each at 4 weapon and 2 module hardpoints. **Engines:** every form has 6 nozzles
  (rear, front, top, bottom, left, right), each an `engine_exhaust.tscn` of 5 MeshInstances (2
  nozzle shapes always shown, 3 plume cones) with `fx_engine_exhaust.gdshader` (`blend_add`,
  `depth_draw_opaque`): **30 additive draws per ship**, 18 of them plumes. Scars: one unshaded draw
  per 16-blob chunk, slag likewise. A hit surface (trimesh) that is never drawn.
- **Effects:** each laser hit spawns `laser_hit.tscn` (OmniLight capped at 10 at once, a glow flash
  mesh, 10 CPU vapour particles) and a `LaserBeam` ImmediateGeometry; smoulder spots (two CPUParticles
  each, 12 emitting at once), damage trails (12), fuel leaks (20 particles), wreck explosions (light,
  flash, two puffs, 16 fragments). Camera dust: three CPUParticles of 50/200/100 quads.
- **HUD:** 117 nodes in `main_hud.tscn`, plus one `projected_target_bracket.tscn` (Button, two
  TextureRects, two panels, two Labels, a TargetMarker custom draw with antialiased lines) per
  target in the zone (~170 in Elace; hidden ones cost nothing).
- **A second 3D viewport:** the fitting window's `hull_preview.tscn` (400×240, own world, MSAA 4x,
  `render_target_update_mode = 3` = always), under a ViewportContainer that is hidden most of the time.

## Baseline (2026-11-15, desktop)

The desktop is a ThinkPad X230 (i5-3210M, Intel HD 4000, Mesa, X11 `DISPLAY=:0`): an old integrated
GPU, so its fill-rate numbers are nearer a phone's than a gaming PC's would be, and `base_full` vs
`base` means something here.

Fight bench, 16 ships, quarter scale: frame 24.4 ms = physics 10.2 + idle 14.2, of which HUD script
1.9; the other ~12 ms of idle is rendering, swap and unsectioned scripts (see the CPU draft, item 0).

Ablation (traffic by the home station, player docked), run 02:30 to 03:00 on 2026-11-15. **The frame
times of these runs are invalid**: every mode, `no_3d` included, reported ~1000 ms frames with
~950 ms in `process`, i.e. the buffer swap blocked for a second a frame (the monitor was asleep, vsync
on; `fight_bench.gd` turns vsync off in `_initialize` and measured fine, `perf_ablation.gd` does not).
**First fix: add `OS.vsync_enabled = false` to `perf_ablation._initialize` (or the override.cfg its
header mentions) and rerun the modes for frame times.** The engine monitors are counts, not times, and
stand:

| mode | draws | objects | materials | shaders | surfaces | 2d_items | 2d_draws | vertices |
|---|---|---|---|---|---|---|---|---|
| base (quarter) | 135 | 135 | 27 | 9 | 117 | 99 | 680 | 184846 |
| base_full | 148 | 143 | 32 | 12 | 128 | 101 | 689 | 189769 |
| no_3d | 20 | 20 | 9 | 3 | 18 | 102 | 695 | 1980 |
| no_hud | 88 | 89 | 15 | 4 | 72 | 1 | 26 | 178019 |
| no_lights | 125 | 124 | 28 | 9 | 107 | 99 | 684 | 184655 |
| no_rocks | 128 | 126 | 30 | 11 | 119 | 100 | 688 | 155428 |
| no_ships_3d | 81 | 80 | 28 | 10 | 62 | 99 | 681 | 179557 |
| no_particles | 119 | 117 | 27 | 9 | 100 | 99 | 681 | 180917 |
| lod_low | 137 | 133 | 32 | 13 | 115 | 99 | 684 | 184528 |

Read: the docked view is ~135 draws and ~185k vertices, a light scene; the ships in view are ~55
draws (`no_ships_3d`), the HUD ~47 draws of the 3D count (its brackets' 3D side) and ~660 2D draws
for ~100 2D items (item 9: the antialiased marks are not batching well); rocks are ~30k vertices
here (the fields are far from the station), so item 5 matters in the belt, not at the dock; the star's
light adds ~10 passes even with no fight (`no_lights`). The phone's trouble is therefore fill
(background, additive layers, light passes) and tile-GPU behaviour, not geometry. The fight bench's
~12 ms of unsectioned idle time on this desktop is the number to split next, with vsync off.

## Items, ranked

### 0. Measure first (half a day)

- Run the ablation modes above, in sequence, and paste the lines into this file.
- Add modes to `perf_ablation.gd` (and a `mode=` to `fight_bench.gd` the same way) for the items
  below: `no_starsphere` (hide the starsphere slot's child), `sky_color` (environment
  `background_mode = COLOR`), `no_exhausts` (`Settings.set_option("engine_exhausts", false)` or hide
  every `Engines` node), `no_hit_lights` (set `HIT_FX_MAX_LIGHTS`-like cap to 0 by freeing the lights
  as they spawn, or run the fight with `no_lights`), `no_preview` (hull preview viewport update mode
  disabled), `no_star` (hide the star's Model and ModelAdditional).
- On the phone, the same cannot be scripted; use `show_fps` with the options that exist
  (`render_scale` 0.25 vs 1 tells fill from everything else; `engine_exhausts` off; `particles` off;
  `hit_effects` off) and write the readings here.

### 1. The background: 20 full-screen additive passes (largest fill cost)

Where: `global_nebulas.tscn` (19 nebula shells + sprites) over a ProceduralSky
(`assets/art/environments/global_environment.tres`, `background_mode = 1`).

What happens: from inside, each `cull_front` shell covers the whole screen; every one is a
full-screen fragment pass with three texture reads, a `discard`, the rim and dither maths, blended
additively. At full scale on a 1080p phone that is ~20 × 2 M fragments a frame before anything in
the game is drawn. The sky pass underneath is a 21st.

Change, same picture: the starsphere is static relative to the camera (centred on it, no `TIME`, the
fades are camera-distance and therefore constant), so it can be **baked once** into a panorama or
cubemap and drawn as one inside-out sphere with a single texture read (an unshaded shader that
applies the dither block to the sample so the look matches). Bake with a small tool script
(`tools/bake_starsphere.gd`: a camera at the origin of the starsphere scene rendering six faces to a
Viewport, saved as PNG; or one equirectangular render), import at a size the phone can hold (2048×1024
is enough: the shells are soft), and keep `global_nebulas.tscn` as the source the bake is made from.
Differences to expect: the dither pattern is screen-space now and would be baked at the bake's
resolution; applying `dither_posterize3` in the display shader instead of baking it keeps it
screen-space. Then set the environment's background to COLOR (the sky is fully covered by the sphere),
which removes the 21st pass. If the user prefers to keep the live shells (they are the lore's look
and may move later), the fallback is fewer shells: measure how many are visible from the play area at
all (several clusters may face away or sit behind others) and cut the shader's work (the triplanar
read to one planar read at this distance).

Verify: `no_starsphere` ablation gives the ceiling; screenshots before/after from `flight_shots.gd`
at three headings; the phone's FPS at `render_scale` 1.

### 2. Hit lights in a fight (GLES2 light passes)

Where: `laser_hit.tscn` (OmniLight 40 m, `HIT_FX_MAX_LIGHTS = 10`), `wreck_explosion.tscn` (144 m,
cap 1), `src/core/agents/effects/laser_hit_effect.gd` `should_light`.

What happens: in a 16-ship melee the ten nearest hits all light; every ship, part, scar chunk and
rock within 40 m of each is drawn once more per light. Ships carry 40 to 60 draws each, so a ship
under three lights is ~200 draws. Rocks near the fight are the worst: 9k to 73k triangles per extra
pass.

Change (visual change, small: fewer simultaneous flashes): a lower cap on phones, e.g.
`HIT_FX_MAX_LIGHTS_MOBILE = 3` chosen by `OS.has_feature("mobile")`, or make the cap follow
`render_scale` (the user's own "my phone is slow" dial). Same-picture part: `should_light` already
skips lights whose reach is below VIEW_FAR; also skip lighting when the hit body is a rock whose
current LOD level is 0 or 1 (a 40 m light on a 70k-triangle rock), or cull the light's reach to the
hit's intensity (a weak hit's 40 m reach is mostly dark anyway: `omni_range` scaled by
`sqrt(_intensity)` touches fewer objects, barely visible).

Verify: fight bench with `no_lights` vs base; the `objects` monitor (it counts per-pass objects).

### 3. Exhaust plumes: 18 additive draws per ship that are mostly invisible

Where: `engine_exhaust.tscn` (5 meshes), `engine_exhaust_set.gd` `_apply`: `plume.visible = not dead
and t > 0.0`. `_engine_thrust` in `agent.gd` is a `linear_interpolate` toward zero, so `t` is almost
never exactly 0: an idle ship keeps all 18 plume cones drawn at `ENGINE_PLUME_IDLE_LENGTH` (0.15 m),
and every one is an additive transparent draw with `depth_draw_opaque`.

Change, same picture: hide a nozzle's PlumeShapes when `t < ENGINE_PLUME_VISIBLE_MIN` (0.02: a 0.2 m
cone at 10 px of ship is nothing), and treat `thrust` below that as 0 in `_apply`'s change test.
Also by view band (ViewDetail `band_changed`, as scars do): no PlumeShapes past VIEW_MID, no
NozzleShapes past VIEW_FAR (at VIEW_DOT the ship is under 10 px; the hull's glow piece still marks
it). The last is a visual change of a pixel or two at distance; list it separately in the commit.
Materials: each ship duplicates its exhaust materials per direction by design (per-ship glow); fine.

Verify: `no_exhausts` ablation gives the ceiling; `draws` monitor in a traffic scene (expect ~18 fewer
per idle ship); screenshots of a ship at idle, cruising and braking.

### 4. `discard` in the solid shader (phone only)

Where: `assets/art/shaders/solid.gdshader`, the distance-fade block in `fragment()`:
`if (fade_range > 0.0 && distance_vert > fade_start) { ... discard; }`. Every ship, rock, station,
planet and moon uses this shader; `fade_start` is 300 km on all of them, so the branch never fires,
but its presence turns off early depth rejection for all opaque geometry on tile GPUs. Also
`nebula.gdshader` (item 1 removes it) and `glow.gdshader` has none.

Change, same picture: a `solid_fading.gdshader` that keeps the fade for materials that need it (none
today), and `solid.gdshader` without the discard (Godot 3 shaders have no `#ifdef`; the shared blocks
stay synced by `tools/sync_shader_blocks.py`). Alternatively keep one shader and move the fade to
`ALPHA_SCISSOR`, which has the same tile-GPU cost, so no.

Verify: desktop numbers will not move. On the phone: FPS by a rock field at `render_scale` 1 before
and after; if the user's phone is PowerVR or Mali this can be the largest single win of the pass.

### 5. Rocks: 9k triangles at 10 px

Where: `tools/generate_lods.py` (ratio 0.5 a level, three levels), `Constants.LOD_LEVEL_BY_BAND_DENSE
= [0, 1, 2, 3, 3]`, `mesh_lod.gd`. The farthest level of a 73k rock is 9215 triangles; of a 45k rock
~5.7k; at VIEW_FAR (10 px) and VIEW_DOT (under) 65 rocks can be 300k vertices a frame.

Change, same picture: generate a fourth level (ratio 0.5 again: ~4.6k / 2.8k) and a fifth at ~1k
(decimate to a fixed face count, `--levels 5` or a `--min-faces`), map DOT to the last. At 10 px no
one can tell 1k from 9k triangles. Rocks are static, and GLES2 has no instancing, so the draw count
stays; the vertex count drops. Optional (visual change): at VIEW_DOT hide the rock mesh entirely
(the bracket's dot marks it already), behind the `render_scale` dial.

Verify: `vertices` monitor in `no_rocks` vs base vs `lod_low`; the rock test
(`test_mesh_lod.gd`); screenshots of a far field.

### 6. The hidden hull preview renders every frame

Where: `scenes/ui/menus/fitting/hull_preview.tscn`: a 400×240 viewport, own world, **MSAA 4x**,
`render_target_update_mode = 3` (always), under the fitting window's ViewportContainer. A hidden
ViewportContainer stops the texture being drawn, not the viewport being rendered: the ship model
(primitives, 30 exhaust draws, its own light) is rendered every frame whenever a model has been
shown once (`show_ship`). The ablation log's physics-interpolation warnings name its nodes, so it is
live in a plain new game.

Change, same picture: set `render_target_update_mode` to `UPDATE_DISABLED` while not visible
(`visibility_changed` / `is_visible_in_tree()` in `_process`, where the turning already stops) and
back to `UPDATE_ALWAYS` when shown; free the model on hide if it is cheap to rebuild. Drop MSAA on
phones (`msaa = 0` unless `OS.has_feature("pc")`) or leave it: at 400×240 it is small.

Verify: `objects`/`draws` monitors with the fitting window closed, before and after.

### 7. Primitive meshes made per piece

Where: `primitive_form.gd` `_mesh()` makes a new CubeMesh/CylinderMesh/SphereMesh for every piece
of every hull and every fitted part. Same geometry, separate vertex buffers: the `surfaces` monitor
counts a change per draw, and memory grows with the fleet.

Change, same picture: a static cache of the four unit meshes (`{"box": CubeMesh, ...}`) shared by
every piece; the piece's transform carries the size as now. Draw calls stay; surface changes and VRAM
drop. Trivial.

### 8. The star's shells at all distances

Where: `star_elace.tscn` (surface, two coronas, halo, sprite: five additive or opaque shells;
the coronas displace vertices with three texture reads each). Their shaders fade with distance but
still rasterise the whole shell; near the star (the 15 km radiation zone) each shell is a large part
of the screen.

Change, same picture: hide the coronas and halo when their screen share is below a band (a
ViewDetail on the star, as rocks have), keeping the sprite and surface; and hide the sprite when the
surface is large (the sprite is the far look). Both are already faded to nothing at those distances
by the shaders, so the picture is unchanged.

Verify: `no_star` ablation; screenshots at three distances from the star.

### 9. HUD 2D

Where: brackets (`projected_target_bracket.tscn`, `target_marker.gd` with `antialiased = true`
lines), `main_hud.tscn`, DynamicFont `use_filter = true`.

Antialiased 2D lines in Godot 3 add feather geometry per segment and break batches; the TargetMarker
draws polygons and rings (24 segments) for every visible mark. Options, in order of picture change:
redraw a mark only when it changes (already so: `set_mark` calls `update()`); drop `antialiased` on
the ring and lines when `render_scale` < 1 (the HUD stays full-res, so this is visible: user's
call); replace per-mark lines with a small texture atlas (visual change; the author chose lines
because scaled textures went soft). Check `2d_draws` in `no_hud` vs base first; the fight bench
says the HUD's script side is 1.9 ms, its draw side is unknown.

### 10. Particles

Where: camera dust (350 quads in three emitters, CPU-simulated every frame while the camera moves),
hit vapour (10 each, tens alive in a fight), smoulder (two emitters per spot), trails, leaks.

CPUParticles cost CPU to simulate and one draw each; the `particles` option already turns them all
off. Same-picture cuts: the far dust emitter (100 particles, 30 s lifetime) can stop emitting when
the camera is still (the controller already stops below `min_camera_speed_threshold`); hit vapour
could skip emitting below VIEW_FAR like the lights do (`should_light` has the test). Low.

### 11. Render scale defaults and the sky

- `Settings` default `render_scale = 1.0` on every platform. A phone default of 0.5 (with the HUD at
  full resolution, which the design already provides) is the single largest fill cut and the author
  built the dial for it; whether to default it is the user's call (visual change: softer 3D).
- With item 1 done, set `background_mode = COLOR` in `global_environment.tres`. Before item 1, test
  it alone (`sky_color` ablation): the sky under the shells is a full-screen pass that contributes
  only a faint gradient under additive shells; the user judges the look.

### 12. Experiments on the phone only (no desktop signal; user decides)

- `gles2/compatibility/disable_half_float` back to false: faster fragments, risk of precision
  artefacts in the dither (`FRAGCOORD` is highp regardless) and in the far-distance maths (the NLP
  block and fades use `length(VERTEX)` at up to 300 km, which overflows half floats: those would need
  explicit `highp` declarations, which Godot 3 shaders cannot add per variable). Try it; if the far
  planets or the star break, drop it.
- `quality/intended_usage/framebuffer_allocation`: 3D (3) is right; "3D without effects" (2) saves a
  buffer only when no post-process is used, and the code toggles none, so (2) may be free. Test.
- `rendering/threads/thread_model = 2`: experimental in 3.6, often slower on Android drivers. Not
  recommended.

### 13. Not recommended

- GLES3: not on this project's phones.
- MultiMesh for rocks or brackets: GLES2 draws MultiMesh instances one by one; no gain.
- Baking lighting or shadows: nothing casts shadows; the toon light is the look.

## Suggested order and checkpoints

1. Item 0: ablation lines pasted here (desktop), phone readings with the existing options.
2. Item 6 (hull preview) and 7 (shared meshes): trivial, same picture. Commit each.
3. Item 3 (plumes), then 5 (rock LODs): same picture. Commit each, with `draws`/`vertices`.
4. Item 1 (starsphere bake): the big one. Prototype the bake, show the user the before/after
   screenshots, then switch. Commit with the `no_starsphere`/`sky_color` numbers.
5. Item 4 (discard): desktop neutral; needs a phone run before and after. Commit with the phone's FPS.
6. Items 2 and 11: visual-change items, each a question to the user with the numbers in hand.
7. Items 8, 9, 10 as the measurements justify.

Each step: the touched tests with `-gselect` first, the full suite before the commit, the relevant
ablation mode twice, screenshots when the item touches what is drawn, and the APK for the phone.

## Test files that cover the touched code

- `src/tests/core/agents/components/test_mesh_lod.gd` (item 5)
- `src/tests/core/agents/components/test_collision_hull.gd` (item 7: hulls are built from the
  primitives' meshes)
- `src/tests/scenes/game_world/test_ship_model.gd` (items 3, 7)
- `src/tests/core/agents/effects/test_hull_scars.gd` (item 2's band logic shares ViewDetail)
- `src/tests/core/ui/test_main_hud_projected_targeting.gd` (item 9)
- `src/tests/modules/piloting/` for anything that reads `Settings` options (items 2, 11)
