# DRAFT: hull marks as shader slots, convex collision hulls

Status: **draft, written on mobile, never run in Godot**. Nothing here has been run: no
editor, no GUT, no on-device test. The agent finishing this works through the checklist below,
fixes what breaks, then deletes this file and rewords the draft commit.

## Why

The old hull marks painted vertex colours and UV2 on the CPU for every hit (GDScript, cost grows
with vertex count: ~3 ms on a dense rock, ~24 ms on the light Phoenix), re-uploaded whole meshes,
kept per-object copies of all mesh arrays for every LOD, and needed a lot of machinery to stay
affordable (pending queues, off-screen deferral, LOD replay, background vertex-grid thread). On
GLES2/mobile the real limits are fill rate and light passes, not polygons, so the work moves into
the shader, where it costs per pixel and is independent of mesh density.

## Intended design

1. **Hits are uniforms, not vertex data.** `HullScorch` keeps
   - up to `SCORCH_MAX_SCARS` (6) char scars: a stretch of the shot line (point where it met the
     collision hull, direction, radius, strength). Nearby hits from about the same direction merge
     (deeper, slightly wider); otherwise a free slot, or the weakest scar gives way into **wear**;
   - **wear**: a 0..`SCORCH_MAX_WEAR` share of the hull charred in blocky hashed cells (old damage);
   - up to `SCORCH_HEAT_SLOTS` (4) heat spots (point, radius, hit time, heat), merged when close.
   Slots live in the visual root's space and are converted per mesh group when pushed.
2. **Shaders** (`simple_solid_NLP`, `solid_dither_no_alpha_no_texture_8x8`, kept in sync by hand):
   char per pixel (distance to the shot line, a reach band in front of/behind the hit point, facing
   the shot), heat per vertex (3D distance, so it goes through thin plates and round edges), all
   gated by `damage_active` so hulls never hit pay nothing.
3. **Materials:** shared until the first hit; then one copy per (material, mesh placement group).
   LOD levels sit where their original does, so they share the copies and show the same marks
   without any extra work. Repair (`clear_marks`) puts the shared materials back.
4. **Clock:** `damage_time` is pushed per frame only while something is hot
   (`SCORCH_IDLE_HEAT`); then the heat slots are zeroed and processing stops.
5. **Where a shot lands:** a physics ray onto the target's collision shapes
   (`CollisionHull.ray_onto`, skipping up to `HIT_RAY_PASSES` other bodies such as the shooter's own
   hull). The char band reaches `SCORCH_SCAR_REACH_BACK` behind the hit point, so the mark lands on
   the visible plating even where the convex hull is a little outside it.
6. **Collision shapes:** ships and asteroids get a `ConvexPolygonShape` built at runtime from the
   model's lowest LOD (`Mesh.create_convex_shape()`, then cut down to the extreme vertex in
   `COLLISION_HULL_MAX_POINTS` directions), cached per model file; placement/stretch baked into
   the points. Falls back to the old capsule (ships) / inner sphere (rocks) if no hull can be built.
   Never concave shapes on RigidBodies.
7. **Lights:** laser hits have no OmniLight at all (heat glow plus the flash sprite carry it);
   wreck explosions light at most `EXPLOSION_MAX_LIGHTS` (1) at a time, freed when the flash ends.

## Edits in this commit

| File | Change |
|---|---|
| `src/core/agents/components/hull_scorch.gd` | Rewritten: slots, groups, lazy material copies, CPU mirrors (`get_char_at`, `get_heat_at`, `get_mark_level`), new save format |
| `src/core/agents/components/collision_hull.gd` | New: convex hull builder + `ray_onto` |
| `src/core/agents/components/vertex_grid.gd` | Deleted |
| `src/autoload/GlobalRefs.gd` | Removed VertexGrid shutdown hook |
| `src/autoload/Constants.gd` | Scorch constants replaced; `COLLISION_HULL_MAX_POINTS`, `HIT_RAY_PASSES`, `EXPLOSION_MAX_LIGHTS` added; `HIT_FX_LIGHT_*` removed |
| `assets/art/shaders/simple_solid_NLP.gdshader`, `solid_dither_no_alpha_no_texture_8x8.gdshader` | New damage block (uniform slots), one Bayer lookup per fragment shared by fade and marks, UV2/COLOR.a no longer used for marks |
| `src/core/agents/agent.gd` | Ship CollisionShape gets the convex hull; `register_hit` uses the ray, then marks |
| `src/scenes/game_world/celestial/asteroid.gd` | Convex hull instead of inner sphere; `register_hit` uses the ray |
| `src/core/agents/effects/laser_hit_effect.gd`, `scenes/prefabs/effects/laser_hit.tscn` | Light removed |
| `src/core/agents/effects/wreck_explosion_effect.gd` | Light capped and freed after the flash |
| `src/core/agents/components/mesh_lod.gd` | Comments only |
| tests | `test_hull_scorch.gd` rewritten, `test_collision_hull.gd` new, `test_mesh_lod.gd` (grid, light and LOD painting tests removed; LOD sharing test), `test_tool_controller.gd` (`get_mark_level`), `test_game_state_manager.gd` (new marks format) |

## Checklist for the finishing agent

### 1. Parse and run tests
- [ ] Open the project once in the editor (or `godot --no-window --editor --quit`) and check that
      both solid shaders compile: watch the output for shader errors. Things most likely to break:
      - built-ins (`VERTEX`, `NORMAL`) are passed into the helper functions as parameters on
        purpose; check that nothing reads a varying inside a helper function;
      - `step()` / `smoothstep()` argument order (GLSL `smoothstep` with edge0 > edge1 is undefined,
        so the code uses `1.0 - smoothstep(0, r, d)`);
      - `uniform vec2` set from GDScript with `Vector2`, `uniform vec4` set with `Plane`.
- [ ] Run GUT: `godot --no-window -s addons/gut/gut_cmdln.gd -gexit`. Fix failures. Points to watch:
      - `test_mesh_lod.gd::test_attached_levels_show_one_at_a_time_and_share_the_hull_marks`
        assumes the LOD files' `Hull joined` node has the same local transform as the original's
        (one placement group). If not, either compare transforms with a tolerance in
        `HullScorch._group_for`, or group LOD copies with their original explicitly.
      - `test_collision_hull.gd::test_a_shot_ray_finds_its_target_through_other_bodies` needs
        Bullet to have registered the new bodies; add another `physics_frame` yield if flaky.
      - GUT `assert_almost_eq` with `Vector3` arguments: if unsupported in this GUT version, compare
        per component.
      - `Mesh.create_convex_shape()` on Godot 3.6 should return a cleaned hull (`clean = true`
        default). If it returns raw vertices, `reduce()` still caps the count; only build time grows.
- [ ] Grep the output for GDScript warnings in the touched files (shadowing, unused vars).

### 2. Look at it in the game (desktop first)
- [ ] Shoot a Phoenix and a rock from several angles and ranges. Char should sit on the visible
      plating, roughly circular, stretched on oblique faces; heat glows red and cools over ~6 s.
- [ ] Switch LOD distances while marked: marks must not jump or vanish.
- [ ] Wing gaps on the Phoenix: shots aimed between wings should either mark the wing the line
      passes or nothing. If marks float in the air or the convex hull lets ships clip badly, author a
      compound hull (a few `-convcolonly` nodes in the model) for that ship; `CollisionHull` would
      then need to prefer authored collision nodes over the generated hull.
- [ ] Clean hulls must look exactly as before. The old shader darkened ~20% of dithered pixels by
      ~25% even on clean hulls (the dither pushed a zero mark over the edge); that is now gated with
      `step(0.001, damage_mark)`. If the old look was liked, it was an accident worth reproducing on
      purpose, not by the mark code.
- [ ] Repair at a station: marks gone, shared materials back. Save/load: player scars and wear come
      back cooled. Old saves (vertex-alpha format) load as a clean hull, no errors.
- [ ] Ship handling: inertia now comes from a convex hull instead of a capsule (Bullet computes it
      from the shape). Check that turning and docking feel the same; adjust in MovementSystem if not.
- [ ] Asteroids: ships and the harpoon should now touch the rock surface, not stop short or sink in.

### 3. Measure
- [ ] Headless bench equivalent of the old one: per-hit cost (expect microseconds now) and the 40 s
      docked-observer battle (old: 99th percentile frame 24.5 ms).
- [ ] On a phone: battle frame time with render scale x1.0 and x0.5, compared with the commit before
      this one. If fill rate is the limit, try 4 scars instead of 6 (constants plus shader uniforms).
- [ ] Load time of a sector with many rocks (convex hull build is once per rock model, cached).

### 4. Finish
- [ ] Delete this file and the `docs/DRAFT-hull-marks-rework.md` reference in `collision_hull.gd`.
- [ ] Reword the commit (drop "DRAFT"), keep the Co-Authored-By line.

## Not done here (follow-ups, need a device or the editor)
- **Bayer as an 8×8 texture** instead of arithmetic: needs a texture asset and a sampler on every
  material; the arithmetic still runs once in `fragment()` and once per light pass in `light()`.
- **`discard` out of near shaders:** the distance-fade `discard` can turn off early-Z on tile-based
  mobile GPUs. It only kicks in past `fade_start` (300 km), so measure first, then consider a
  far-only shader variant.
- **Collision layers** (ships / celestial / debris) so weapon rays use a mask rather than the
  exclude loop.
- **Authored compound hulls** for ships whose wing gaps matter (see above).
- **Varyings budget:** the solid shaders now add `damage_pos` (vec4) and `damage_normal` (vec3);
  check compilation on the weakest target GPU (GLES2 guarantees only 8 varying vectors).
