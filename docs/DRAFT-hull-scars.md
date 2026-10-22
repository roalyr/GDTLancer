# DRAFT: hull scars (glowing blobs that cool to char)

This was written on mobile without Godot, so **nothing here has been run**: no parse check, no tests, no visuals. This note tells the PC agent what was meant, what to check, and what to measure. Delete it once the draft is finished.

## Intent

A hit on a ship's plating leaves a small lumpy blob, sunk part way into the hull. It glows white-orange, cools through dull red to dark char over `HULL_SCAR_COOL_TIME` (8 s), and stays until the hull is repaired. This replaces the removed shader-slot hull marks (`58fe25a`).

- The hull materials and shaders are untouched.
- All of a ship's scars are one MultiMeshInstance, unshaded, so lights add no extra passes.
- Cooling runs in the shader. The CPU sets one shared uniform per frame, and only while some scar is hot.

Scars need **exact hit points on the plating**. A blob placed on the convex hull would float up to 15 m off the ship. So hit surfaces come back (`71c3106`), with the two faults that got them removed fixed:

| Fault in 71c3106 | Fix in this draft |
|---|---|
| Every shot was blocked: `ToolController.find_blocker` hit the shooter's own hit surface (311 of 311). | `find_blocker` uses `Constants.SHOT_BLOCK_MASK`, which is every layer except layer 20. |
| About 0.9 s of startup building trimeshes. | Trimeshes are baked to `<model folder>/hit/<model>_hit.res` by `tools/bake_hit_shapes.gd`. Ships only: rocks get no hit surface and keep their dust. |

## What changed

| File | Change |
|---|---|
| `src/autoload/Constants.gd` | `HIT_SURFACE_LAYER` (layer 20), `HIT_SURFACE_LOD` (1), `SHOT_BLOCK_MASK`, `HULL_SCAR_*` |
| `src/core/agents/components/collision_hull.gd` | `add_hit_surface`, `surface_for_model` (loads the baked file, else builds it with a warning), `baked_surface_path`, `build_surface`, `hit_surface_of`; `ray_onto(..., plating = true)` |
| `src/core/agents/components/tool_controller.gd` | `find_blocker` mask |
| `src/core/agents/effects/hull_scars.gd` (new) | MultiMeshInstance pool: `scar_transform` (pure placement math), `add_scar` (merge or reheat, edge check, round robin), `export_scars` / `import_scars`, `clear_scars` |
| `assets/art/shaders/hull_scar.gdshader`, `assets/art/effects/hull_scar_material.tres`, `assets/art/effects/hull_scar_mesh.tres` (all new) | Blob shader, the shared material, and a SphereMesh (r 0.5, 12×6) |
| `src/core/agents/agent.gd` | Hit surface and HullScars added at init. `register_hit` tries the plating 3 times, then the convex hull, then the facing point, and only plating hits scar. Smoulder spots sit at the hit when it was on the plating. `repair_hull` clears scars. `get_hull_scar_count()`. |
| `GameState.gd`, `GameStateManager.gd` | `player_hull_scars`: saved, loaded, reset |
| `tools/bake_hit_shapes.gd` (new) | Bakes the hit trimeshes |
| Tests | New `src/tests/core/agents/effects/test_hull_scars.gd`; new hit-surface and blocker tests in `test_collision_hull.gd`; scar save test in `test_game_state_manager.gd` |

### How a scar is placed (`HullScars.scar_transform`)

| Blob axis | Direction | Length |
|---|---|---|
| y | Hit normal, flipped toward the shooter if it came off a back face | `size × HULL_SCAR_FLATNESS` |
| z | Beam direction flattened onto the plating | `size × stretch`, with `stretch = 1/max(|cos θ|, HULL_SCAR_MIN_FACING)` |
| x | `y × z` | `size` |

The basis is built in world space, then converted with `global_transform.affine_inverse()`, so a scaled visual root is handled. The centre is sunk `HULL_SCAR_SINK × height` below the hit, and the plating's depth hides the rest.

- Head-on scars get a random twist about the normal. Streaks only get ±0.25 rad.
- `_fits`: two short rays at the streak's ends against the same hit surface. If either misses (over an edge or a hollow), the scar is halved and made round.

### Instance custom data
- `x`: hit time on `HullScars.clock()`, which is ticks in seconds. Not shader `TIME`, because that wraps every 3600 s.
- `y`: seed for the lumps.
- `z`: facing (head-on glows hotter).
- `w`: size in metres.

### Save format
`player_hull_scars` is an Array of 15-float arrays per scar: basis x, y, z columns, origin (in HullScars' node space, the visual root), then seed, facing and size. Saved scars load cold.

## PC checklist

### 1. Parse and import
- [ ] Open the editor and confirm the new shader, `.tres` files and scripts load without errors.
- [ ] `hull_scar_mesh.tres` is a hand-written SphereMesh. Check that it imports as one, and fix the header if not.
- [ ] Check that `const SHOT_BLOCK_MASK = 0x7FFFFFFF & ~HIT_SURFACE_LAYER` folds as a constant. If not, write the number out (`0x7FF7FFFF`).

### 2. Bake
- [ ] Run `godot --no-window -s tools/bake_hit_shapes.gd`. It should print OK per ship .glb, with the triangle count and time.
- [ ] Commit `assets/models/ships/hit/*_hit.res`.
- [ ] `Ship modules.glb` and `Spinal-ortho.glb` are not flown ships as far as I know. Skip them if they bloat the folder.

### 3. Tests
- [ ] Run the full GUT suite.
- [ ] `test_shots_land_on_the_hit_surface_inside_the_hull` shoots straight down at the Phoenix. If that line passes between its parts the test goes pending, so pick a line that hits.
- [ ] `test_export_import_round_trip_comes_back_cold` compares float arrays with `assert_eq_deep`. If float32 rounding of `Transform` trips it, compare with a tolerance.

### 4. Shots land (the regression that killed 71c3106)
- [ ] Headless battle (`tools/perf_ablation.gd` or `tools/balance_sim.gd`): shots are **not** all blocked, and ships die at roughly the same rate as on `e3dbed9`.
- [ ] Other rays that might now see layer 20: `player_controller_ship._raycast_for_target` uses mask 1, which is fine. `grep intersect_ray` for anything added since.

### 5. Startup
- [ ] Measure load to player against `e3dbed9`, which was about 0.85 s headless. Target: no more than +0.1 s with baked files.
- [ ] If loading the `.res` is still slow, split the time between `load()` and Bullet's tree build when the shape is first used. The tree should build once per shape resource, since ships of a model share one.
- [ ] Delete a baked file and confirm the warning appears and the runtime fallback still works.

### 6. Visuals (the main thing to judge)
- [ ] Scars sit **on** the plating with an irregular outline, not floating and not invisible (fully buried). Tune `HULL_SCAR_SINK` and `HULL_SCAR_FLATNESS`.
- [ ] The LOD1 hit surface vs what's drawn: on LOD0 a blob may sink fully or stand proud where LOD1 differs. If visible, use `HIT_SURFACE_LOD = 0` for ships (more triangles, but baked, so only memory).
- [ ] Glancing hits make streaks along the beam; head-on hits make round splashes.
- [ ] Cooling: white-orange, then red, then char over about 8 s. It must not snap. Check `now` is being set: `_process` runs only while hot.
- [ ] Several ships hot at once all cool correctly (shared material, shared `now`).
- [ ] Scars move and turn with the ship, and stay put through LOD switches.
- [ ] `lod_max_distance = HULL_SCAR_VISIBLE_DISTANCE` (1500 m): scars vanish beyond it. Check it's measured from the camera the way we expect, and that they don't pop distractingly.
- [ ] Unshaded char vs the dithered hull. If it looks pasted on, try the dither from `solid_dither_no_alpha_no_texture_8x8.gdshader` in `fragment()`, or a little `light()`.
- [ ] Lumps (`lump = 0.12`): bumpy but not spiky.
- [ ] Smoulder spots now sit on the plating instead of inset by `EMBER_INSET_SHARE`. Commit `083a511` moved emitters further in on purpose. Check embers don't spawn visibly outside the hull. If they do, keep the inset for plating hits too (one line in `_add_smoulder`).

### 7. Performance
- [ ] In GLES2, MultiMesh may be drawn as one draw call per instance (no hardware instancing). Check the FrameProfiler and render monitors with several fully scarred ships (24 each) in view. If draw calls hurt, lower `HULL_SCAR_MAX_PER_SHIP`, or shorten `HULL_SCAR_VISIBLE_DISTANCE`.
- [ ] Check that `INSTANCE_CUSTOM` reaches the shader in GLES2 (per-instance hit time). If it doesn't, scars won't cool individually: fall back to instance colour (`COLOR_FLOAT`) and read `COLOR` instead.
- [ ] Per-hit cost: `register_hit` with scar placement plus the 2 edge rays. Expect well under 0.1 ms.

### 8. Saves
- [ ] Get scarred, save, load: the scars come back in the same places, cold.
- [ ] Docking at home and refitting both clear them (`repair_hull`).
- [ ] An old save without `player_hull_scars` loads clean.

## Open choices for the PC session
- Scars on wrecks stay. Wrecks are cleared away eventually, so this is fine.
- NPC scars are not saved, since NPCs are respawned.
- Rocks: no scars by design (dust instead). To add them later, bake rock hit shapes too and decide on a size scale.
