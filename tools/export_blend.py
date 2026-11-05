"""
Exports a model's .blend to the .glb the game imports, beside it under the same name, as it renders:
- the "Guides" collection (the starters' measuring boxes and labels; tools/make_starters.py),
  objects disabled in renders (boolean cutters and the like) and collections excluded from the
  view layer (parts kept for instancing) are left out;
- collection instances become real objects;
- every modifier enabled for renders is applied, in order (also ones hidden in the viewport); ones
  disabled for renders are dropped. Shape keys are applied as they are mixed. Linked duplicates get
  meshes of their own first, so each takes its own modifiers;
- curves, surfaces, text and metaballs become meshes.
The .blend itself is never saved. tools/import_model.sh runs this when it is given a .blend.

Usage:
    tools/blender -b assets/models/ships/<name>/<name>.blend -P tools/export_blend.py
"""

import os

import bpy

GUIDES = "Guides"
GEOMETRY = {"MESH", "CURVE", "SURFACE", "FONT", "META"}


def drop_guides():
    collection = bpy.data.collections.get(GUIDES)
    if collection is None:
        return
    for obj in list(collection.all_objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(collection)


def scene_objects():
    """The objects in the view layer (collections excluded from it are not part of the model)."""
    bpy.context.view_layer.update()  # Drops objects removed since
    return [obj for obj in bpy.context.view_layer.objects if obj is not None]


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


def reveal():
    """Every object visible and selectable in the viewport, so the operators below reach it."""
    for collection in bpy.data.collections:
        collection.hide_viewport = False
        collection.hide_select = False
    for obj in scene_objects():
        obj.hide_viewport = False
        obj.hide_select = False
        obj.hide_set(False)


def realize_instances():
    instancers = [obj for obj in scene_objects() if obj.instance_type == "COLLECTION" and obj.instance_collection is not None]
    if instancers:
        select_only(instancers)
        bpy.ops.object.duplicates_make_real(use_base_parent=True, use_hierarchy=True)
    return len(instancers)


def drop_excluded():
    """Objects outside the view layer: in collections excluded from it (the exporter would keep them)."""
    shown = set(scene_objects())
    gone = [obj for obj in bpy.context.scene.objects if obj not in shown]
    for obj in gone:
        bpy.data.objects.remove(obj, do_unlink=True)
    return len(gone)


def bake_geometry():
    """Applies modifiers and shape keys and turns all geometry into meshes: [applied, dropped, converted]."""
    geometry = [obj for obj in scene_objects() if obj.type in GEOMETRY]
    applied, dropped = 0, []
    for obj in geometry:
        for modifier in list(obj.modifiers):
            if modifier.show_render:
                modifier.show_viewport = True  # The conversion applies what the viewport shows
                applied += 1
            else:
                dropped.append("%s: %s" % (obj.name, modifier.name))
                obj.modifiers.remove(modifier)
    if not geometry:
        return [0, dropped, 0]
    select_only(geometry)
    bpy.ops.object.make_single_user(object=True, obdata=True)
    for obj in geometry:
        if obj.type == "MESH" and obj.data.shape_keys is not None:
            select_only([obj])
            bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    converted = len([obj for obj in geometry if obj.type != "MESH"])
    select_only(geometry)
    bpy.ops.object.convert(target="MESH")
    return [applied, dropped, converted]


def drop_unrendered():
    """Objects disabled in renders (after the modifiers that use them, booleans' cutters, are applied)."""
    gone = [obj for obj in scene_objects() if obj.hide_render]
    for obj in gone:
        bpy.data.objects.remove(obj, do_unlink=True)
    return len(gone)


def leftovers():
    return [obj.name for obj in scene_objects() if obj.type in GEOMETRY and (obj.type != "MESH" or len(obj.modifiers) > 0)]


def main():
    source = bpy.data.filepath
    if not source:
        raise SystemExit("Open a .blend: tools/blender -b <model>.blend -P tools/export_blend.py")
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    drop_guides()
    reveal()
    instances = realize_instances()
    excluded = drop_excluded()
    applied, dropped, converted = bake_geometry()
    unrendered = drop_unrendered()
    left = leftovers()
    if left:
        raise SystemExit("EXPORT FAILED: modifiers left on %s" % ", ".join(left))
    out_path = os.path.splitext(source)[0] + ".glb"
    # Nose +Y, top +Z in Blender become -Z and +Y in Godot (glTF's +Y up).
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=True, export_materials="EXPORT")
    print("EXPORTED %s: %d modifiers applied, %d instances made real, %d converted to meshes, %d not rendered and %d excluded left out"
          % (out_path, applied, instances, converted, unrendered, excluded))
    for line in dropped:
        print("EXPORTED (dropped, disabled for renders) " + line)


main()
