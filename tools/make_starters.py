"""
Writes the starter .blend files a modeller begins from (CONTENT.md, "Models"):
    assets/models/starters/ship_starter.blend
    assets/models/starters/station_starter.blend

Each holds:
- a small working model that imports as it is (tools/import_model.sh takes the .blend);
- every library material (assets/art/materials_generic/mat_*.tres, the faction colours aside), named
  the way the game looks them up and coloured like the game draws them, plus "Paint";
- for ships, two "Engine" empties at the nozzles;
- a "Guides" collection the export leaves out: the 17 m ship length box and a nose arrow (ships), a
  ship-sized box for scale (stations);
- a "README" text (Blender's Text Editor) with the rules.

Re-run after adding a library material:
    tools/blender -b -P tools/make_starters.py
"""

import math
import os
import re

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LIBRARY = os.path.join(ROOT, "assets", "art", "materials_generic")
OUT_DIR = os.path.join(ROOT, "assets", "models", "starters")
SHIP_LENGTH = 17.0  # Constants.SHIP_MODEL_LENGTH
GUIDES = "Guides"
SKIPPED_PREFIXES = ("hull_faction_",)  # Faction colours: a model takes its owner's through "Paint"
PAINT_PREVIEW = (0.55, 0.58, 0.62, 1.0)

README = """GDTLancer model starter
=======================
Full rules: CONTENT.md, "Models". In short:

- Ships are 17 m nose to tail, nose toward +Y, top toward +Z (the Guides box).
- Stations can be any size; ships undock above their top. The guide box is one ship for scale.
- Materials are picked by NAME. Use the ones in this file; Blender's colours here only preview the
  game's. "Paint" takes the owner's faction paint. A new look = a new mat_<name>.tres in
  assets/art/materials_generic/, then re-run tools/make_starters.py.
- Engines: an empty named "Engine" at each nozzle, unrotated; its scale sizes the exhaust.
- The "Guides" collection is never exported.

Save as  assets/models/ships/<name>/<name>.blend  (stations: assets/models/stations/<name>/<name>.blend)
Then:    tools/import_model.sh assets/models/ships/<name>/<name>.blend
         tools/import_model.sh --station assets/models/stations/<name>/<name>.blend
"""


def library_materials():
    """[(display name, albedo, emission)] from the material library, sorted by name."""
    out = []
    for file_name in sorted(os.listdir(LIBRARY)):
        match = re.match(r"mat_(.+)\.tres$", file_name)
        if not match or match.group(1).startswith(SKIPPED_PREFIXES):
            continue
        with open(os.path.join(LIBRARY, file_name)) as handle:
            text = handle.read()
        out.append((match.group(1).replace("_", " ").title(), color_param(text, "albedo"), color_param(text, "emission")))
    return out


def color_param(text, name):
    match = re.search(r"shader_param/%s = Color\( ([^)]*) \)" % name, text)
    if not match:
        return (0.0, 0.0, 0.0, 1.0)
    return tuple(float(value) for value in match.group(1).split(","))


def make_material(name, albedo, emission=(0.0, 0.0, 0.0, 1.0)):
    material = bpy.data.materials.new(name)
    material.use_fake_user = True  # Kept in the file while nothing uses it
    material.diffuse_color = albedo
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = albedo
    if max(emission[:3]) > 0.0:
        shader.inputs["Emission"].default_value = emission
        shader.inputs["Emission Strength"].default_value = 1.0
    return material


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = {"Paint": make_material("Paint", PAINT_PREVIEW)}
    for name, albedo, emission in library_materials():
        materials[name] = make_material(name, albedo, emission)
    text = bpy.data.texts.new("README")
    text.write(README)
    return materials


def box(name, size, location, material, collection=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if material is not None:
        obj.data.materials.append(material)
    if collection is not None:
        move_to(obj, collection)
    return obj


def cylinder(name, radius, depth, location, material, rotation=(0.0, 0.0, 0.0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(rotation=True)
    obj.data.materials.append(material)
    return obj


def torus(name, major, minor, material):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32, minor_segments=8)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(material)
    return obj


def empty(name, location, scale, display="PLAIN_AXES"):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = display
    obj.location = location
    obj.scale = (scale, scale, scale)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def guides_collection():
    collection = bpy.data.collections.new(GUIDES)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to(obj, collection):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)


def guide_box(name, size, location, collection):
    obj = box(name, size, location, None, collection)
    obj.display_type = "WIRE"
    obj.hide_select = True
    obj.hide_render = True
    return obj


def guide_label(text, location, collection, size=1.0):
    curve = bpy.data.curves.new(text, "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    obj = bpy.data.objects.new(text, curve)
    obj.location = location
    obj.hide_select = True
    obj.hide_render = True
    collection.objects.link(obj)
    return obj


def ship_starter(materials):
    half = SHIP_LENGTH * 0.5
    box("Hull", (3.0, 13.0, 2.0), (0.0, 0.5, 0.0), materials["Paint"])
    box("Nose", (1.6, 2.0, 1.2), (0.0, half - 1.0, -0.2), materials["Hull Dark Metal"])
    box("Canopy", (1.0, 2.5, 0.4), (0.0, 4.0, 1.1), materials["Hull Glow"])
    box("Engine Block", (2.8, 2.5, 1.6), (0.0, -half + 1.25, 0.0), materials["Engine Dark Alloy"])
    box("Radiator", (6.0, 2.0, 0.15), (0.0, -3.0, 0.0), materials["Radiator Graphite"])
    for side, x in (("L", -0.7), ("R", 0.7)):
        empty("Engine.%s" % side, (x, -half, 0.0), 0.8)
    guides = guides_collection()
    guide_box("Ship length 17 m", (6.0, SHIP_LENGTH, 4.0), (0.0, 0.0, 0.0), guides)
    arrow = empty("Nose +Y", (0.0, half, 0.0), 3.0, "SINGLE_ARROW")
    arrow.rotation_euler = (-math.pi * 0.5, 0.0, 0.0)  # The arrow points along its +Z: tip it to +Y
    move_to(arrow, guides)
    guide_label("NOSE +Y", (0.0, half + 4.0, 0.0), guides)
    guide_label("TAIL: engines", (0.0, -half - 2.0, 0.0), guides, 0.7)


def station_starter(materials):
    cylinder("Core", 6.0, 30.0, (0.0, 0.0, 0.0), materials["Paint"])
    torus("Ring", 22.0, 2.0, materials["Habitat Ring Light"])
    box("Spoke X", (40.0, 1.5, 1.5), (0.0, 0.0, 0.0), materials["Hull Dark Metal"])
    box("Spoke Y", (1.5, 40.0, 1.5), (0.0, 0.0, 0.0), materials["Hull Dark Metal"])
    cylinder("Beacon", 1.0, 1.0, (0.0, 0.0, 15.5), materials["Hull Glow"])
    box("Tanks", (8.0, 8.0, 6.0), (0.0, 0.0, -18.0), materials["Tanks Cryo Alloy"])
    guides = guides_collection()
    guide_box("Ship for scale (17 m)", (6.0, SHIP_LENGTH, 4.0), (35.0, 0.0, 0.0), guides)
    guide_label("ONE SHIP", (35.0, 0.0, 4.0), guides, 2.0)
    guide_label("SHIPS UNDOCK ABOVE THE TOP (+Z)", (0.0, 0.0, 22.0), guides, 2.0)


def save(name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    bpy.context.preferences.filepaths.save_version = 0  # No .blend1 backup beside it
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    print("WROTE " + os.path.relpath(path, ROOT))


def main():
    ship_starter(reset())
    save("ship_starter.blend")
    station_starter(reset())
    save("station_starter.blend")


main()
