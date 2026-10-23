# DRAFT: chunked scar and slag meshes, zoom-aware detail

This covers two drafts written on mobile without Godot: `c139b93` (merged meshes, more slag) and `0bd0ec5` (chunks, deferred builds, lighter slag). The zoom handling from `0bd0ec5` was replaced by view bands: see `docs/DRAFT-view-detail.md`. Parsed and tested on PC (see the checklist); what is left needs a look in play. Delete this note once the work is finished.

## Why
- **MultiMesh draw calls.** As far as we know, Godot 3's GLES2 renderer draws a MultiMesh **one instance per draw call**. A battered heavy ship would cost about 128 draw calls.
- **Whole-mesh rebuilds.** One merged mesh per ship fixes the draw calls, but then every hit re-uploads the whole mesh: up to about 355 KB on a heavy, at most 10 times a second.

## What changed

### Zoom-aware distances
Replaced by view bands in the next draft: see `docs/DRAFT-view-detail.md`. `ScreenSpace.view_distance` and `VIEW_REFERENCE_FOV_DEG` are gone.

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
  - shown up to `HULL_SLAG_MAX_BAND` (scars up to `HULL_SCAR_MAX_BAND`; see the view-detail note);
  - up to 56 per ship (112 on the heavy), at most 2 per scar, on the scars with the fewest, newest first;
  - follows its scar when the scar is replaced or grows.
- **Per-blob data moves to vertex attributes:**
  - **Hit time:** `UV2.x`.
  - **Seed:** `UV2.y`.
  - **Facing:** `COLOR.r`.

  Surfaces are added uncompressed (`compress_flags = 0`) so hit times keep full precision. The lumps are baked on the CPU, and the shader's `lump` uniform is gone.

## PC checklist
- [x] Everything parses, and the tests pass, including the new ones (one fix: `seed` is a GDScript builtin):
  - `test_hull_scars.gd`: chunks, only-its-chunk rebuild, hidden ships, slag placement, vertex data;
- [x] `SphereMesh.get_mesh_arrays()` works where the tests run (headless, GLES2). If the tests run headless with a dummy renderer and it returns nothing, ship both templates as ArrayMesh `.tres` files.
- [x] **Draw calls:** `tools/perf_ablation.gd mode=base` (battle by the home station): 42 draw calls against 127 on `73f8516`, frame median 9.3 ms against 10.0 ms. With rocks hidden: 35 against 87.
- [ ] **Rebuild cost during sustained fire on a heavy:** check the FrameProfiler. Expect at most about 50 KB per rebuild, 10 times a second.
- [ ] **Looks unchanged:** lumps, cooling over 20 s, slag flaring every 5–10 s (each blob on its own period, from `UV2.y`), dither and posterize.
- [ ] **Mobile GPU:** `UV2` and `COLOR` arrive as full floats. If cooling looks stepped after long sessions, something is compressing them or lowering their precision.
- [ ] **Culling:** each chunk's AABB covers its blobs, so off-screen scars cull per chunk.
- [ ] **Slag at zero hull:** up to 56 on the light Phoenix, but only with 28 or more scars. Check that two slag blobs on one scar don't look crowded; tune `HULL_SLAG_SIZE_SHARE` and `HULL_SLAG_MAX_SIZE` if they do.
