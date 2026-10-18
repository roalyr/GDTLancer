"""
Generate LOD meshes for .glb models with Blender: each level applies a Decimate (collapse)
modifier at --ratio to the previous level, so LOD1 has ratio, LOD2 ratio^2 and so on of the
original triangles. Object names and hierarchy are kept, so a LOD can stand in for the original
node by node.

Output: <model folder>/lod/<model>_LOD<n>.glb. Run the Godot editor once afterwards
(godot --no-window --editor --quit) so the new files get imported.

Never for nebulas: their look depends on the exact cloud geometry. Paths under a "nebulas"
folder are refused.

Ratio: 0.5 suits dense meshes (rocks); already low-poly hard-surface models (ships) fall apart
that fast, so use a gentler ratio for them (0.7).

Usage (tools/blender links the project's Blender 3.6):
    tools/blender -b -P tools/generate_lods.py -- [--levels 3] [--ratio 0.5] model.glb [model2.glb ...]
"""

import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy

# Older Blender glTF add-ons (3.4) use numpy aliases removed in numpy 1.24, which bites when a
# system Blender runs against the system numpy. Restore them for this process only; harmless otherwise.
for _alias, _type in (("bool", bool), ("int", int), ("float", float), ("object", object)):
    if _alias not in numpy.__dict__:
        setattr(numpy, _alias, _type)


AUTO_SMOOTH_DEGREES = 30.0  # Edges sharper than this shade hard on decimated levels


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Generate decimated LOD .glb files.")
    parser.add_argument("--levels", type=int, default=3)
    parser.add_argument("--ratio", type=float, default=0.5, help="Decimate ratio applied per level")
    parser.add_argument("models", nargs="+")
    return parser.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mesh_objects():
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def triangle_count():
    total = 0
    for obj in mesh_objects():
        for polygon in obj.data.polygons:
            total += len(polygon.vertices) - 2
    return total


def decimate_all(ratio):
    for obj in mesh_objects():
        if obj.data.users > 1:
            obj.data = obj.data.copy()  # Shared mesh data cannot take an applied modifier
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new(name="LOD_Decimate", type="DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        delete_loose(obj)
        restore_hard_edges(obj)


# The imported custom normals no longer match the decimated faces, and without them everything
# shades smooth: hard-surface hulls go dark and blobby. Drop them and shade by angle instead.
def restore_hard_edges(obj):
    mesh = obj.data
    if mesh.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    mesh.use_auto_smooth = True
    mesh.auto_smooth_angle = math.radians(AUTO_SMOOTH_DEGREES)


# Decimating can leave vertices and edges no face uses (thin parts of a hull collapse to lines);
# they are invisible, and Blender 3.4's glTF exporter fails on them.
def delete_loose(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.delete(mesh, geom=[edge for edge in mesh.edges if not edge.link_faces], context="EDGES")
    bmesh.ops.delete(mesh, geom=[vert for vert in mesh.verts if not vert.link_faces], context="VERTS")
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()


def generate(model_path, levels, ratio):
    model_path = os.path.abspath(model_path)
    if "nebulas" in model_path.replace("\\", "/").split("/"):
        print("SKIP (never LOD nebulas): " + model_path)
        return
    base = os.path.splitext(os.path.basename(model_path))[0]
    out_dir = os.path.join(os.path.dirname(model_path), "lod")
    os.makedirs(out_dir, exist_ok=True)
    report = []
    source = model_path
    for level in range(1, levels + 1):
        # Each level starts from the previous level's exported file, so every level is built and
        # checked like the first.
        clear_scene()
        bpy.ops.import_scene.gltf(filepath=source)
        if level == 1:
            report.append("%s: LOD0 %d tris" % (base, triangle_count()))
        decimate_all(ratio)
        out_path = os.path.join(out_dir, "%s_LOD%d.glb" % (base, level))
        bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=True)
        report.append("LOD%d %d tris" % (level, triangle_count()))
        source = out_path
    print("LODS " + ", ".join(report))


def main():
    args = parse_args()
    for model in args.models:
        generate(model, args.levels, args.ratio)


main()
