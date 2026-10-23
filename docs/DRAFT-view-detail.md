# DRAFT: one view-detail rule for models, scars and effects

This was written on mobile without Godot. Nothing has been parsed, run or looked at. Delete this note once the work is finished.

## The problem
Detail dropped off by a mix of unrelated rules:
- **Ship and rock LODs:** multiples of the object's radius from the camera.
- **Scars, slag, smoulder, damage trails, rock dust, hit lights and tether cables:** each had its own absolute distance in metres.
- **Zoom:** ignored, apart from a stopgap in `0bd0ec5`.

So a heavy ship's scars vanished at the same distance as a fighter's. A ship could show LOD0 with its embers already off, or LOD2 with its slag still drawn. Zooming in on a far ship did not bring its detail back.

## The rule
Everything goes by **apparent size**, in five bands. An object's *screen share* is the part of the screen height its diameter covers, with the camera's current field of view included:

| Band | Screen share | ≈ px tall (743 px screen) |
|---|---|---|
| `VIEW_CLOSE` | ≥ 0.33 | 245 |
| `VIEW_NEAR` | ≥ 0.12 | 90 |
| `VIEW_MID` | ≥ 0.04 | 30 |
| `VIEW_FAR` | ≥ 0.013 | 10 |
| `VIEW_DOT` | below | — |

- **Hysteresis:** `VIEW_BAND_HYSTERESIS` (10%) keeps the current band until the share is clearly past a threshold, so nothing flickers.
- **Hosts** (ships and rocks) carry a `ViewDetail` node that keeps their band:
  - it checks every `VIEW_CHECK_INTERVAL` (0.25 s, spread over frames);
  - it checks **at once whenever the camera's field of view changes**, so zooming in shows detail without a delay;
  - it emits `band_changed`.
- **Everything on a host follows the host's band.** For an asteroid, which is scaled after it's placed, the band uses `get_apparent_radius()`. One band per ship means its model, scars and embers always change together, and only one camera measurement is made per ship instead of one per part.
- **Loose effects with no host to follow** (rock dust, at a fixed size) take a band from their own size (`ViewBand.band_of`, `ROCK_DUST_RADIUS`).

**Why bands and not a constants review:** with bands, each consumer states one thing: the last band it shows in. Consistency between consumers and with the zoom comes for free. Tuning is either one threshold table for everything, or one `*_MAX_BAND` per consumer.

## Who follows what

| Thing | Before | Now |
|---|---|---|
| Ship LODs | 15 / 40 / 100 radii | `LOD_LEVEL_BY_BAND = [0, 0, 1, 2, 3]` |
| Rock LODs | 4 / 10 / 25 radii | `LOD_LEVEL_BY_BAND_DENSE = [0, 1, 2, 3, 3]` |
| Scars | 1500 m | up to `VIEW_FAR` (host) |
| Slag | 700 m | up to `VIEW_MID` (host) |
| Smoulder spots | 2500 m | up to `VIEW_FAR` (host) |
| Damage trails | 3000 m | up to `VIEW_FAR` (host) |
| Hit light | 2000 m | up to `VIEW_FAR` (the body hit) |
| Tether rope simulation | 1500 m | up to `VIEW_FAR` (the holding ship) |
| Rock dust | 2500 m | up to `VIEW_FAR` (its own size, 8 m) |

### Where things now switch at a 70° view, unzoomed

| Object | radius | CLOSE ends | NEAR ends | MID ends | FAR ends |
|---|---|---|---|---|---|
| Fighter / light Phoenix | 12 m | 52 m | 143 m | 428 m | 1.3 km |
| Heavy | 34 m | 147 m | 405 m | 1.2 km | 3.7 km |
| Rock | 300 m | 1.3 km | 3.6 km | 10.7 km | 33 km |
| Dust puff | 8 m | — | — | — | 880 m |

- **LODs** match the old radius thresholds closely:
  - ships switch to LOD1/2/3 at 143 / 428 / 1300 m (were 180 / 480 / 1200 m);
  - rocks at 1.3 / 3.6 / 10.7 km (were 1.2 / 3 / 7.5 km).
- **Light ships** lose scars, embers, trails, hit lights and rope simulation a bit sooner than before (about 1.3 km instead of 1.5–3 km). Heavies keep them longer (3.7 km).
- **Dust** goes sooner (880 m instead of 2.5 km).
- **At full zoom (6°)** every distance is about 13× longer, so a fighter 15 km out reaches `VIEW_FAR`.

## Code
- `src/core/utils/view_band.gd` (new):
  - `screen_share(camera, point, radius)`;
  - `band_for(share, current)` with hysteresis;
  - `band_of(...)` for loose effects;
  - `distance_leaving(band, radius, fov)` for tuning and tests.
- `src/core/agents/components/view_detail.gd` (new):
  - `ViewDetail.attach(host, radius)`;
  - `ViewDetail.of(node)` and `band_of_host(node)`, which walk up to the host; a node with no host counts as `VIEW_CLOSE`, i.e. everything shown;
  - signal `band_changed`.
- `MeshLod` no longer measures distance:
  - `attach(visual_root, view_detail, by_band)` connects each MeshLod to its host's `band_changed`;
  - `level_for_band(band, count, by_band)` replaces `level_for(distance, …)`;
  - with a null `view_detail`, the model stays at full detail.
- `agent.gd` and `asteroid.gd` attach a ViewDetail and pass it to `MeshLod.attach`.
- `HullScars.show_band(band)`, connected in `_ready`, replaces its own camera timer.
- Smoulder, damage trails, the hit light and the tether rope check `ViewDetail.band_of_host(...)`.
- Rock dust uses `ViewBand.band_of(camera, point, ROCK_DUST_RADIUS)`.
- **Constants:** the LEVELS OF DETAIL section became VIEW DETAIL.
  - **Removed:** `LOD_DISTANCE_RADII(_DENSE)`, `LOD_HYSTERESIS`, `LOD_CHECK_INTERVAL`, `VIEW_REFERENCE_FOV_DEG`, `HULL_SCAR_VISIBLE_DISTANCE`, `HULL_SLAG_VISIBLE_DISTANCE`, `SMOULDER_VISIBLE_DISTANCE`, `DAMAGE_TRAIL_VISIBLE_DISTANCE`, `ROCK_DUST_VISIBLE_DISTANCE`, `HIT_FX_LIGHT_DISTANCE`, `TETHER_ROPE_SIM_DISTANCE`.
  - `ScreenSpace.view_distance` is gone.
- **Tests:**
  - new `src/tests/core/utils/test_view_band.gd`;
  - `test_mesh_lod.gd` rewritten for bands;
  - `test_hull_scars.gd`: scars follow the ship's band;
  - `test_tool_controller.gd`: the rock dust test is placed with `distance_leaving`;
  - `test_screen_space.gd` removed.

## PC checklist
- [ ] Everything parses. `grep` for any leftover use of the removed constants in scenes and tools.
- [ ] Tests pass.
- [ ] **LODs at normal zoom feel as before:** ships and rocks switch about where they did. Check the polygon count by a rock field.
- [ ] **Full zoom on a ship 10–20 km out:** scars, slag (if close enough), embers and trails appear together with the higher LOD, and go together when you zoom back out. No visible delay while zooming.
- [ ] **No band flicker** while orbiting at a threshold distance. If there is, raise `VIEW_BAND_HYSTERESIS`.
- [ ] **Hit lights:** big rocks reach `VIEW_FAR` out to about 33 km, so hits on far rocks may take light slots (`HIT_FX_MAX_LIGHTS` = 4, first come) from hits nearby. If that happens:
  - give rocks a separate light band (for example `VIEW_MID`); or
  - let near hits take a slot from far ones.
- [ ] **Light ships losing scars and embers from about 1.3 km** (was 1.5–3 km): judge in play. If it's too soon, move the four FAR thresholds down (`VIEW_BAND_SHARES[3]`) or set those consumers to `VIEW_DOT` with their shown budgets as the limit.
- [ ] **Rock dust from 880 m** (was 2.5 km): if it's missed, raise `ROCK_DUST_RADIUS` or allow `VIEW_DOT`.
- [ ] **Perf:** one ViewDetail per ship and rock replaces the per-part camera checks (MeshLod, HullScars, each smoulder spot and trail). `ViewDetail._process` still runs each frame to compare the camera FOV: check its cost in a full sector. If it shows up, move the FOV check to a single place, for example the camera emitting a signal that all ViewDetails share.
