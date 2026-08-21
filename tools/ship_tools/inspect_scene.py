#!/usr/bin/env python3
"""
Inspect a Godot .tscn scene or 3D asset hierarchy, printing node hierarchy,
MeshInstances, material assignments, and overall model AABB.

Usage:
    python3 tools/ship_tools/inspect_scene.py [scene_path]
Example:
    python3 tools/ship_tools/inspect_scene.py scenes/prefabs/ships/cargo_ship_1.tscn
"""

import os
import sys
import argparse
import subprocess

def inspect_scene(scene_path):
    if not os.path.exists(scene_path):
        print(f"Error: Scene file not found: {scene_path}")
        sys.exit(1)

    rel_path = os.path.relpath(scene_path, start=os.getcwd()).replace('\\', '/')
    res_path = f"res://{rel_path}"

    gdscript = f'''extends SceneTree

func _init():
    var scene_res = load("{res_path}")
    if not scene_res:
        print("Failed to load scene: {res_path}")
        quit(1)
        return
    
    var instance = scene_res.instance()
    if not instance:
        print("Failed to instance scene: {res_path}")
        quit(1)
        return
    
    print("=== Hierarchy of {res_path} ===")
    var mesh_count = [0]
    var total_aabb = [AABB()]
    var first_mesh = [true]
    
    print_tree(instance, "", mesh_count, total_aabb, first_mesh, Transform.IDENTITY)
    
    print("\\n=== Summary ===")
    print("Total MeshInstances: " + str(mesh_count[0]))
    if not first_mesh[0]:
        var aabb = total_aabb[0]
        print("Combined Model AABB: pos=" + str(aabb.position) + ", size=" + str(aabb.size))
        print("Center: " + str(aabb.position + aabb.size * 0.5))
        print("Extents (radius approx): " + str(aabb.size.length() * 0.5))
    
    instance.free()
    quit(0)

func print_tree(node: Node, indent: String, mesh_count: Array, total_aabb: Array, first_mesh: Array, parent_xform: Transform):
    var extra = ""
    var current_xform = parent_xform
    if node is Spatial:
        current_xform = parent_xform * node.transform

    if node is MeshInstance:
        mesh_count[0] += 1
        var mo = node.material_override
        var mo_str = mo.resource_path if (mo and mo.resource_path != "") else ("inline(" + mo.get_class() + ")" if mo else "none")
        var s_mats = []
        if node.mesh:
            for s in range(node.mesh.get_surface_count()):
                var sm = node.get_surface_material(s)
                var sm_str = sm.resource_path if (sm and sm.resource_path != "") else ("inline(" + sm.get_class() + ")" if sm else "none")
                s_mats.append("s" + str(s) + ":" + sm_str)
            
            var local_aabb = node.mesh.get_aabb()
            var xformed_aabb = current_xform.xform(local_aabb)
            if first_mesh[0]:
                total_aabb[0] = xformed_aabb
                first_mesh[0] = false
            else:
                total_aabb[0] = total_aabb[0].merge(xformed_aabb)
            
            extra = " [Mesh=" + node.mesh.get_class() + ", override=" + mo_str
            if len(s_mats) > 0:
                extra += ", surfaces=[" + ", ".join(s_mats) + "]"
            extra += "]"
        else:
            extra = " [MeshInstance without Mesh, override=" + mo_str + "]"
    elif node is CollisionShape:
        extra = " [Shape=" + (node.shape.get_class() if node.shape else "none") + "]"
    elif node is Light:
        extra = " [Light energy=" + str(node.light_energy) + "]"
    elif node is Camera:
        extra = " [Camera fov=" + str(node.fov) + "]"
    
    print(indent + "- " + node.name + " (" + node.get_class() + ")" + extra)
    
    for child in node.get_children():
        print_tree(child, indent + "  ", mesh_count, total_aabb, first_mesh, current_xform)
'''

    worker_file = os.path.join("tools", "ship_tools", "worker_inspect_scene.gd")
    try:
        with open(worker_file, "w") as f:
            f.write(gdscript)
        
        cmd = ["godot", "-s", worker_file, "--no-window"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            for line in result.stderr.splitlines():
                if "WARNING:" not in line and "OpenGL ES" not in line:
                    print(line, file=sys.stderr)
    finally:
        if os.path.exists(worker_file):
            os.remove(worker_file)

def main():
    parser = argparse.ArgumentParser(description="Inspect Godot scene node tree and materials.")
    parser.add_argument("scene", nargs="?", default="scenes/prefabs/ships/cargo_ship_1.tscn", help="Path to scene .tscn")
    args = parser.parse_args()
    inspect_scene(args.scene)

if __name__ == "__main__":
    main()

