# DRAFT: chunked scar and slag meshes, zoom-aware detail

This covers two drafts written on mobile without Godot: `c139b93` (merged meshes, more slag) and the commit after it (chunks, deferred builds, lighter slag, zoom-aware distances). Nothing has been parsed, run or looked at. Delete this note once the work is finished.

## Why
- **MultiMesh draw calls.** As far as we know, Godot 3's GLES2 renderer draws a MultiMesh **one instance per draw call**. A battered heavy ship would cost about 128 draw calls.
- **Whole-mesh rebuilds.** One merged mesh per ship fixes the draw calls, but then every hit re-uploads the whole mesh: up to about 355 KB on a heavy, at most 10 times a second.
- **Zoom.** In playtests the player often zooms in on far objects. Every camera-distance check for detail (LODs, scars, effects) used the raw distance, so a far ship seen through a 6° zoom still showed its lowest LOD and no scars.

## What changed

### Zoom-aware distances
- **`ScreenSpace.view_distance(camera, point)`:** the camera distance × tan(fov/2) / tan(`VIEW_REFERENCE_FOV_DEG`/2), with the reference at 70°. In words: how far the point would be at 70° to look the size it looks now.
- **Used by:**
  - MeshLod;
  - HullScars (scars and slag);
  - smoulder spots, damage trails and rock dust;
  - the hit light gate (still capped at `HIT_FX_MAX_LIGHTS`).
- **At full zoom (6°)** the factor is about 1/13. A ship 15 km out counts as about 1.1 km, so it shows LOD0-ish detail and its scars.
- **Side effect at normal zoom levels:** the orbit camera's FOV runs from 25° (close) to 100° (far), so LODs now switch by apparent size there too.
  - At 25°, models keep detail about 3× further out than before.
  - At 100°, they drop it about 1.7× sooner.

  That's intended (the thresholds were written for a 70° view), but check how it feels and what the polygon counts do.

### HullScars
- **Spatial with chunk MeshInstances.** Scar chunks are `Scars0`, `Scars1`, …; slag chunks sit under the child `Slag` as `Slag0`, `Slag1`, ….
  - Each chunk merges up to `HULL_SCAR_CHUNK_BLOBS` (16) blobs and is one draw call.
  - Chunk nodes are made on first use.
  - Slots fill chunks in order, so a new scar only rebuilds the newest chunk. A reheat or grow rebuilds that scar's chunk; a replaced scar also rebuilds its slag's chunk(s).
- **Draw calls at full damage:**

  | Ship | Scar chunks | Slag chunks | Total |
  |---|---|---|---|
  | Light Phoenix (36 scars + 56 slag) | 3 | 4 | 7 |
  | Heavy (72 + 112) | 5 | 7 | 12 |

  Lightly damaged ships use 1 + 1. The upload per change is at most one chunk: about 16 × 66 vertices, 50 KB.
- **Deferred building.** A blob's vertices (`_blobs[i]`) are worked out only when its chunk is rebuilt, and chunks rebuild only while shown. Rebuilds happen in `_process`, at most every `HULL_SCAR_REBUILD_INTERVAL`, and immediately on coming into view. A hit on a ship nobody sees costs only its placement math.
- **Slag:**
  - lighter template `hull_slag_mesh.tres` (6×3 segments, 35 vertices; scars stay 10×4, 66 vertices);
  - shown within a view distance of `HULL_SLAG_VISIBLE_DISTANCE` (700 m); scars within `HULL_SCAR_VISIBLE_DISTANCE` (1500 m);
  - up to 56 per ship (112 on the heavy), at most 2 per scar, on the scars with the fewest, newest first;
  - follows its scar when the scar is replaced or grows.
- **Per-blob data moves to vertex attributes:**
  - **Hit time:** `UV2.x`.
  - **Seed:** `UV2.y`.
  - **Facing:** `COLOR.r`.

  Surfaces are added uncompressed (`compress_flags = 0`) so hit times keep full precision. The lumps are baked on the CPU, and the shader's `lump` uniform is gone.

## PC checklist
- [ ] Everything parses, and the tests pass, including the new ones:
  - `test_hull_scars.gd`: chunks, only-its-chunk rebuild, hidden ships, slag placement, vertex data;
  - `test_screen_space.gd`.
- [ ] `SphereMesh.get_mesh_arrays()` works where the tests run. If the tests run headless with a dummy renderer and it returns nothing, ship both templates as ArrayMesh `.tres` files.
- [ ] **Draw calls:** with several battered ships close by, check the render monitor on `73f8516` against this. Expect 2–12 per scarred ship in view.
- [ ] **Rebuild cost during sustained fire on a heavy:** check the FrameProfiler. Expect at most about 50 KB per rebuild, 10 times a second.
- [ ] **Zoom:**
  - At full zoom on a ship 10–20 km out: LOD0 or LOD1, scars and slag visible, smoulder embers emitting.
  - Zooming out again: detail drops off.
  - Detail can lag a zoom change by up to `LOD_CHECK_INTERVAL` (0.25 s). If the pop is noticeable, trigger a check when the camera's FOV changes.
- [ ] **Normal zoom levels:** LOD switching feels the same or better, and the polygon count with many rocks close by is acceptable. Dense rocks use `LOD_DISTANCE_RADII_DENSE`, and a 25° FOV now keeps them detailed further out.
- [ ] **Looks unchanged:** lumps, cooling over 20 s, slag flaring every 5–10 s (each blob on its own period, from `UV2.y`), dither and posterize.
- [ ] **Mobile GPU:** `UV2` and `COLOR` arrive as full floats. If cooling looks stepped after long sessions, something is compressing them or lowering their precision.
- [ ] **Culling:** each chunk's AABB covers its blobs, so off-screen scars cull per chunk.
- [ ] **Slag at zero hull:** up to 56 on the light Phoenix, but only with 28 or more scars. Check that two slag blobs on one scar don't look crowded; tune `HULL_SLAG_SIZE_SHARE` and `HULL_SLAG_MAX_SIZE` if they do.
