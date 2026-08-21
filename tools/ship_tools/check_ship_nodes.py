#!/usr/bin/env python3
"""
Inspect MeshInstance nodes and material bindings in a Godot scene.

Usage:
    python3 tools/ship_tools/check_ship_nodes.py [scene_path]
Example:
    python3 tools/ship_tools/check_ship_nodes.py scenes/prefabs/ships/cargo_ship_1.tscn
"""

import os
import sys
import argparse
import subprocess

def check_nodes(scene_path):
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
    print("=== Nodes & Materials for {res_path} ===")
    print("%-6s %-30s %-45s %s" % ["INDEX", "NODE NAME", "OVERRIDE", "SURFACE 0"])
    print("---------------------------------------------------------------------------------------------------------")
    
    var idx = [0]
    collect_meshes(instance, "", idx)
    
    instance.free()
    quit(0)

func collect_meshes(node: Node, path: String, idx: Array):
    var current_path = node.name if path == "" else path + "/" + node.name
    if node is MeshInstance:
        var mo = node.material_override
        var mo_str = mo.resource_path if (mo and mo.resource_path != "") else ("inline" if mo else "NONE")
        var s0 = node.get_surface_material(0)
        var s0_str = s0.resource_path if (s0 and s0.resource_path != "") else ("inline" if s0 else "NONE")
        
        print("%-6d %-30s %-45s %s" % [idx[0], node.name, mo_str, s0_str])
        idx[0] += 1
    
    for child in node.get_children():
        collect_meshes(child, current_path, idx)
'''

    worker_path = os.path.join("tools", "ship_tools", "worker_check_nodes.gd")
    try:
        with open(worker_path, "w") as f:
            f.write(gdscript)

        subprocess.run(["godot", "-s", worker_path, "--no-window"], text=True)
    finally:
        if os.path.exists(worker_path):
            os.remove(worker_path)

def main():
    parser = argparse.ArgumentParser(description="Check mesh nodes and material overrides in a scene.")
    parser.add_argument("scene", nargs="?", default="scenes/prefabs/ships/cargo_ship_1.tscn", help="Path to scene .tscn")
    args = parser.parse_args()
    check_nodes(args.scene)

if __name__ == "__main__":
    main()

