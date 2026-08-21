#!/usr/bin/env python3
"""
Inspect Godot Environment resources or space/sector scenes.

Usage:
    python3 tools/ship_tools/inspect_global_space.py [env_or_scene_path]
Example:
    python3 tools/ship_tools/inspect_global_space.py assets/art/environments/global_environment.tres
"""

import os
import sys
import argparse
import subprocess

def inspect_space(path):
    if not os.path.exists(path):
        print(f"Error: File not found: {path}")
        sys.exit(1)

    rel_path = os.path.relpath(path, start=os.getcwd()).replace('\\', '/')
    res_path = f"res://{rel_path}"

    gdscript = f'''extends SceneTree

func _init():
    var res = load("{res_path}")
    if not res:
        print("Failed to load: {res_path}")
        quit(1)
        return
    
    if res is Environment:
        print("=== Environment Resource: {res_path} ===")
        print("Background Mode: " + str(res.background_mode))
        print("Background Color: " + str(res.background_color))
        print("Ambient Light Color: " + str(res.ambient_light_color))
        print("Ambient Light Energy: " + str(res.ambient_light_energy))
        print("Glow Enabled: " + str(res.glow_enabled))
        print("Glow Intensity: " + str(res.glow_intensity))
        print("Glow Strength: " + str(res.glow_strength))
    elif res is PackedScene:
        var instance = res.instance()
        print("=== Scene Tree: {res_path} ===")
        print_tree(instance, "")
        instance.free()
    else:
        print("Resource class: " + res.get_class())
    
    quit(0)

func print_tree(node: Node, indent: String):
    var extra = ""
    if node is DirectionalLight:
        extra = " [energy=" + str(node.light_energy) + ", color=" + str(node.light_color) + "]"
    elif node is WorldEnvironment:
        extra = " [env=" + str(node.environment.resource_path if node.environment else "null") + "]"
    elif node is Camera:
        extra = " [fov=" + str(node.fov) + ", far=" + str(node.far) + "]"
    print(indent + "- " + node.name + " (" + node.get_class() + ")" + extra)
    for child in node.get_children():
        print_tree(child, indent + "  ")
'''

    worker_path = os.path.join("tools", "ship_tools", "worker_inspect_env.gd")
    try:
        with open(worker_path, "w") as f:
            f.write(gdscript)

        subprocess.run(["godot", "-s", worker_path, "--no-window"], text=True)
    finally:
        if os.path.exists(worker_path):
            os.remove(worker_path)

def main():
    parser = argparse.ArgumentParser(description="Inspect Godot environment or space scenes.")
    parser.add_argument("path", nargs="?", default="assets/art/environments/global_environment.tres", help="Path to .tres or .tscn")
    args = parser.parse_args()
    inspect_space(args.path)

if __name__ == "__main__":
    main()

