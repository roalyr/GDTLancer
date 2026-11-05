"""
Exports a model's .blend to the .glb the game imports, beside it under the same name, leaving out
the "Guides" collection (the starters' measuring boxes and labels; tools/make_starters.py).
tools/import_model.sh runs this when it is given a .blend.

Usage:
    tools/blender -b assets/models/ships/<name>/<name>.blend -P tools/export_blend.py
"""

import os

import bpy

GUIDES = "Guides"


def drop_guides():
    collection = bpy.data.collections.get(GUIDES)
    if collection is None:
        return
    for obj in list(collection.all_objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(collection)


def main():
    source = bpy.data.filepath
    if not source:
        raise SystemExit("Open a .blend: tools/blender -b <model>.blend -P tools/export_blend.py")
    drop_guides()
    out_path = os.path.splitext(source)[0] + ".glb"
    # Nose +Y, top +Z in Blender become -Z and +Y in Godot (glTF's +Y up).
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=True, export_materials="EXPORT")
    print("EXPORTED " + out_path)


main()
