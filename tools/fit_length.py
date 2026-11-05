"""
Scales a ship model's .glb (in place) so its meshes run --length m nose to tail (Blender's Y), about
its origin: ship models can be made at any size, since the game sizes every ship from its preset
(model_scale times Constants.SHIP_MODEL_LENGTH). The scale is baked into the meshes; empties
(engine markers) keep it as their own scale, so exhausts stay in proportion. A model already at the
length is left untouched. tools/import_model.sh runs this for ships before making the LODs.

Usage:
    tools/blender -b -P tools/fit_length.py -- --length 17 model.glb
"""

import argparse
import sys

import bpy
import numpy
from mathutils import Matrix, Vector

for _alias, _type in (("bool", bool), ("int", int), ("float", float), ("object", object)):
    if _alias not in numpy.__dict__:  # Older glTF add-ons and numpy 1.24 (see generate_lods.py)
        setattr(numpy, _alias, _type)

TOLERANCE = 0.001  # Share of the length within which a model counts as fitted


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--length", type=float, required=True)
    parser.add_argument("model")
    return parser.parse_args(argv)


def mesh_length():
    low, high = None, None
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        for vertex in evaluated.data.vertices:
            y = (obj.matrix_world @ vertex.co).y
            low = y if low is None else min(low, y)
            high = y if high is None else max(high, y)
    return 0.0 if low is None else high - low


def main():
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.model)
    length = mesh_length()
    if length <= 0.0:
        raise SystemExit("FIT FAILED %s: no meshes" % args.model)
    factor = args.length / length
    if abs(factor - 1.0) <= TOLERANCE:
        print("FIT %s: %.2f m, as it is" % (args.model, length))
        return
    scale = Matrix.Scale(factor, 4)
    for obj in bpy.context.scene.objects:
        if obj.parent is None:
            obj.matrix_world = scale @ obj.matrix_world
    bpy.context.view_layer.update()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    if meshes:
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.make_single_user(object=True, obdata=True)  # Shared meshes can't take a scale each
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.export_scene.gltf(filepath=args.model, export_format="GLB", export_apply=True, export_materials="EXPORT")
    print("FIT %s: %.2f m scaled by %.3f to %.2f m" % (args.model, length, factor, mesh_length()))


main()
