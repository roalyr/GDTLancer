# DRAFT: merged scar and slag meshes, more slag

This was written on mobile without Godot. Nothing has been parsed, run or looked at. Delete this note once the work is finished.

## Why
As far as we know, Godot 3's GLES2 renderer draws a MultiMesh **one instance per draw call**. A heavily damaged heavy ship (72 scars + 56 slag) could cost about 128 draw calls, and a few such ships nearby would add hundreds. That's a lot for mobile.

## What changed
- **`HullScars` is now a MeshInstance with one ArrayMesh.** All scars are merged into one surface, and the child `Slag` MeshInstance holds all slag blobs in another. That's **2 draw calls per ship**, however many blobs there are.
  - Each blob's vertices are worked out on the CPU once, when it's placed, reheated or grown, from the template `hull_scar_mesh.tres` (now 10×4 segments, 66 vertices), and kept per slot.
  - A rebuild only joins the kept arrays (`append_array`), cuts a cached index list to size, and uploads.
  - Rebuilds happen in `_process`, at most every `HULL_SCAR_REBUILD_INTERVAL` (0.1 s). `flush()` forces one.
- **Lumps are baked into the vertices** with the same formula as before; `HULL_SCAR_LUMP` is 0.12 and `HULL_SLAG_LUMP` is 0.25. The `lump` uniform is gone from the shader and both materials.
- **Per-blob data moves to vertex attributes:**
  - **Hit time:** `UV2.x`.
  - **Seed:** `UV2.y`.
  - **Facing:** `COLOR.r`.

  The surface is added **uncompressed** (`compress_flags = 0`), so hit times keep full float precision. The shader reads `UV2` and `COLOR` instead of `INSTANCE_CUSTOM`.
- **More slag:**
  - `HULL_SLAG_MAX` goes from 28 to 56, scaled by ship size as before (112 on the heavy).
  - Up to `HULL_SLAG_PER_SCAR` (2) slag blobs per scar.
  - New slag goes on the scar with the fewest, newest first.
- **Slag follows its scar.** When a scar's slot is taken by a new scar, or the scar grows, its slag is re-seated on it. Slag no longer stays behind on bare plating.

## PC checklist
- [ ] Everything parses, and `get_mesh_arrays()` on the SphereMesh works in a headless test run. If it doesn't, the test runner uses a dummy renderer, so ship the template as an ArrayMesh `.tres` instead.
- [ ] Tests pass (`test_hull_scars.gd`: new mesh, slag-placement and vertex-data tests).
- [ ] **Draw calls:** with several badly scarred ships close by, expect +2 per scarred ship in view. Compare with the render monitors on `73f8516`.
- [ ] **Per-hit cost:** one blob is about 66 vertices of script work; the rebuild of a full heavy (72 + 112 blobs, about 12k vertices) is native joins plus an upload. Use the FrameProfiler during sustained fire on one heavy. If rebuilds show up:
  - raise `HULL_SCAR_REBUILD_INTERVAL`; or
  - use a smaller template.
- [ ] **Looks unchanged:**
  - lumps, the hot middle and cooler rim, and cooling over 20 s;
  - slag flaring every 5–10 s with its own period per blob (from the seed in `UV2.y`);
  - dither and posterize still banding.
- [ ] **Mobile GPU:** `UV2` and `COLOR` arrive as full floats in GLES2 (the hit time is about `OS.get_ticks_msec()/1000`). If cooling looks stepped or wrong after long sessions, the attribute is being compressed or lowp somewhere.
- [ ] **Frustum culling:** the merged mesh's AABB covers all blobs, so a ship whose scars are off-screen still culls normally.
- [ ] **Slag count:** at 0 hull a light Phoenix shows up to 56 slag, but only while it has at least 28 scars (2 per scar). Check that this reads right, and tune `HULL_SLAG_SIZE_SHARE` / `HULL_SLAG_MAX_SIZE` if two slag blobs on one scar crowd it.
