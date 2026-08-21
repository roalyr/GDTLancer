#!/usr/bin/env python3
"""
Render preview screenshots of a 3D ship/station model from multiple camera angles
using Godot in headless mode.

Features:
    - Tight bounding-box (AABB) camera framing so the ship occupies ~88-90% of the frame.
    - Low/customizable resolution suitable for UI asset cards and descriptions.
    - Configurable lighting presets (scene, deep_space, warm_star, cold_star, harsh_sun, studio).

Usage:
    python3 tools/render_ship.py [--scene scenes/prefabs/ships/cargo_ship_1.tscn] [--lighting scene] [--width 640] [--height 480]
"""

import os
import sys
import argparse
import subprocess

def render_ship(scene_path, env_path, output_dir, lighting="scene", width=640, height=480, target_fill=0.88):
    if not os.path.exists(scene_path):
        print(f"Error: Scene file not found: {scene_path}")
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    rel_scene = os.path.relpath(scene_path, start=os.getcwd()).replace('\\', '/')
    res_scene = f"res://{rel_scene}"

    res_env = ""
    if env_path and os.path.exists(env_path):
        rel_env = os.path.relpath(env_path, start=os.getcwd()).replace('\\', '/')
        res_env = f"res://{rel_env}"

    abs_output_dir = os.path.abspath(output_dir).replace('\\', '/')

    script_content = f'''extends SceneTree

func _init():
    var viewport = Viewport.new()
    viewport.size = Vector2({width}, {height})
    viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
    viewport.render_target_v_flip = true
    root.add_child(viewport)
    
    # Load Environment
    var env_path = "{res_env}"
    if env_path != "":
        var env_node = WorldEnvironment.new()
        var env_res = load(env_path)
        if env_res:
            env_node.environment = env_res
            viewport.add_child(env_node)
    
    # Instance scene
    var scene_res = load("{res_scene}")
    if not scene_res:
        print("Error: Could not load scene {res_scene}")
        quit(1)
        return
        
    var scene = scene_res.instance()
    scene.visible = true
    viewport.add_child(scene)
    
    # Calculate AABB
    var mesh_aabb = [AABB()]
    var first_mesh = [true]
    find_meshes_and_aabb(scene, Transform.IDENTITY, mesh_aabb, first_mesh)
    
    var aabb = mesh_aabb[0]
    var center = aabb.position + aabb.size * 0.5
    print("Model AABB pos=" + str(aabb.position) + ", size=" + str(aabb.size) + ", center=" + str(center))
    
    # Configure Lighting based on preset: {lighting}
    var preset = "{lighting}"
    var ship_light = scene.get_node_or_null("DirectionalLight")
    
    if preset == "scene" and ship_light:
        ship_light.editor_only = false
        ship_light.visible = true
        # Add subtle opposing fill light to soften dark side
        var fill = DirectionalLight.new()
        fill.light_energy = 0.2
        fill.light_color = Color(0.65, 0.75, 0.9)
        fill.transform = Transform(-ship_light.transform.basis.x, ship_light.transform.basis.y, -ship_light.transform.basis.z, Vector3(0, 50, 0))
        viewport.add_child(fill)
    else:
        if ship_light:
            ship_light.visible = false
            
        var key = DirectionalLight.new()
        var fill = DirectionalLight.new()
        viewport.add_child(key)
        viewport.add_child(fill)
        
        if preset == "deep_space":
            key.light_energy = 0.6
            key.light_color = Color(0.95, 0.95, 0.98)
            key.transform = Transform(Vector3(0.707, 0.5, 0.5), Vector3(0.0, -0.707, 0.707), Vector3(0.707, -0.5, -0.5), Vector3(0, 50, 0))
            fill.light_energy = 0.22
            fill.light_color = Color(0.45, 0.55, 0.75)
            fill.transform = Transform(Vector3(-0.707, 0.0, -0.707), Vector3(0.0, 1.0, 0.0), Vector3(0.707, 0.0, -0.707), Vector3(0, -50, 0))
        elif preset == "warm_star":
            key.light_energy = 0.85
            key.light_color = Color(0.96, 0.85, 0.68)
            key.transform = Transform(Vector3(0.707, 0.5, 0.5), Vector3(0.0, -0.707, 0.707), Vector3(0.707, -0.5, -0.5), Vector3(0, 50, 0))
            fill.light_energy = 0.2
            fill.light_color = Color(0.4, 0.45, 0.6)
            fill.transform = Transform(Vector3(-0.707, 0.0, -0.707), Vector3(0.0, 1.0, 0.0), Vector3(0.707, 0.0, -0.707), Vector3(0, -50, 0))
        elif preset == "cold_star":
            key.light_energy = 0.75
            key.light_color = Color(0.65, 0.8, 0.95)
            key.transform = Transform(Vector3(0.707, 0.5, 0.5), Vector3(0.0, -0.707, 0.707), Vector3(0.707, -0.5, -0.5), Vector3(0, 50, 0))
            fill.light_energy = 0.2
            fill.light_color = Color(0.3, 0.35, 0.5)
            fill.transform = Transform(Vector3(-0.707, 0.0, -0.707), Vector3(0.0, 1.0, 0.0), Vector3(0.707, 0.0, -0.707), Vector3(0, -50, 0))
        elif preset == "harsh_sun":
            key.light_energy = 1.2
            key.light_color = Color(1.0, 0.98, 0.95)
            key.transform = Transform(Vector3(0.707, 0.5, 0.5), Vector3(0.0, -0.707, 0.707), Vector3(0.707, -0.5, -0.5), Vector3(0, 50, 0))
            fill.light_energy = 0.12
            fill.light_color = Color(0.5, 0.5, 0.7)
            fill.transform = Transform(Vector3(-0.707, 0.0, -0.707), Vector3(0.0, 1.0, 0.0), Vector3(0.707, 0.0, -0.707), Vector3(0, -50, 0))
        else: # studio
            key.light_energy = 0.75
            key.light_color = Color(1.0, 0.98, 0.95)
            key.transform = Transform(Vector3(0.78, 0.03, 0.63), Vector3(-0.63, 0.04, 0.78), Vector3(0.0, -1.0, 0.05), Vector3(0, 50, 0))
            fill.light_energy = 0.35
            fill.light_color = Color(0.6, 0.7, 0.9)
            fill.transform = Transform(Vector3(-0.78, 0.0, -0.63), Vector3(0.0, 1.0, 0.0), Vector3(0.63, 0.0, -0.78), Vector3(0, -50, 0))
    
    var fov_deg = 35.0
    var cam = Camera.new()
    cam.current = true
    cam.far = max(3000.0, aabb.size.length() * 20.0)
    cam.fov = fov_deg
    viewport.add_child(cam)
    
    var aspect = float({width}) / float({height})
    var target_fill = {target_fill}
    var out_dir = "{abs_output_dir}"
    
    var shot_definitions = [
        {{
            "name": out_dir + "/ship_front_34.png",
            "dir": Vector3(0.65, 0.3, -0.7),
            "up": Vector3(0, 1, 0)
        }},
        {{
            "name": out_dir + "/ship_rear_34.png",
            "dir": Vector3(0.65, 0.3, 0.7),
            "up": Vector3(0, 1, 0)
        }},
        {{
            "name": out_dir + "/ship_top.png",
            "dir": Vector3(0.0001, 1.0, 0.0),
            "up": Vector3(0, 0, -1)
        }},
        {{
            "name": out_dir + "/ship_bottom.png",
            "dir": Vector3(0.0001, -1.0, 0.0),
            "up": Vector3(0, 0, 1)
        }},
        {{
            "name": out_dir + "/ship_side.png",
            "dir": Vector3(1.0, 0.05, 0.0),
            "up": Vector3(0, 1, 0)
        }},
        {{
            "name": out_dir + "/ship_angle_top.png",
            "dir": Vector3(0.7, 0.55, 0.45),
            "up": Vector3(0, 1, 0)
        }},
        {{
            "name": out_dir + "/ship_angle_bottom.png",
            "dir": Vector3(0.7, -0.55, 0.45),
            "up": Vector3(0, 1, 0)
        }}
    ]
    
    for shot in shot_definitions:
        var dist = calculate_tight_distance(aabb, shot["dir"], shot["up"], fov_deg, aspect, target_fill)
        cam.transform.origin = center + shot["dir"].normalized() * dist
        cam.look_at(center, shot["up"])
        
        for i in range(5):
            yield(self, "idle_frame")
            
        var tex = viewport.get_texture()
        var img = tex.get_data()
        img.save_png(shot["name"])
        print("Saved: " + shot["name"] + " (dist=" + str(stepify(dist, 0.1)) + ")")
        
    quit(0)

func calculate_tight_distance(p_aabb: AABB, p_dir: Vector3, p_up: Vector3, p_fov_deg: float, p_aspect: float, p_fill: float) -> float:
    var center = p_aabb.position + p_aabb.size * 0.5
    var z_cam = p_dir.normalized()
    var x_cam = p_up.cross(z_cam).normalized()
    var y_cam = z_cam.cross(x_cam).normalized()
    
    var half_fov_y = deg2rad(p_fov_deg * 0.5)
    var tan_half_fov_y = tan(half_fov_y)
    var tan_half_fov_x = tan_half_fov_y * p_aspect
    
    var p0 = p_aabb.position
    var s = p_aabb.size
    var corners = [
        p0,
        p0 + Vector3(s.x, 0, 0),
        p0 + Vector3(0, s.y, 0),
        p0 + Vector3(0, 0, s.z),
        p0 + Vector3(s.x, s.y, 0),
        p0 + Vector3(s.x, 0, s.z),
        p0 + Vector3(0, s.y, s.z),
        p0 + s
    ]
    
    var max_dist: float = 1.0
    for corner in corners:
        var v = corner - center
        var cx = v.dot(x_cam)
        var cy = v.dot(y_cam)
        var cz = v.dot(z_cam)
        
        var req_x = cz + (abs(cx) / (p_fill * tan_half_fov_x))
        var req_y = cz + (abs(cy) / (p_fill * tan_half_fov_y))
        var req = max(req_x, req_y)
        if req > max_dist:
            max_dist = req
            
    return max_dist

func find_meshes_and_aabb(node: Node, parent_xform: Transform, total_aabb: Array, first_mesh: Array):
    var current_xform = parent_xform
    if node is Spatial:
        current_xform = parent_xform * node.transform
    if node is MeshInstance and node.mesh:
        var local_aabb = node.mesh.get_aabb()
        var xformed_aabb = current_xform.xform(local_aabb)
        if first_mesh[0]:
            total_aabb[0] = xformed_aabb
            first_mesh[0] = false
        else:
            total_aabb[0] = total_aabb[0].merge(xformed_aabb)
    for child in node.get_children():
        find_meshes_and_aabb(child, current_xform, total_aabb, first_mesh)
'''

    worker_file = os.path.join("tools", "ship_tools", "render_worker.gd")
    try:
        with open(worker_file, 'w') as f:
            f.write(script_content)

        res = subprocess.run(['godot', '-s', worker_file, '--no-window'], capture_output=True, text=True)
        print(res.stdout)
        if res.stderr:
            for line in res.stderr.splitlines():
                if "WARNING:" not in line and "OpenGL ES" not in line:
                    print(line, file=sys.stderr)
    finally:
        if os.path.exists(worker_file):
            os.remove(worker_file)
    print(f"Renders saved to {output_dir}")

def main():
    parser = argparse.ArgumentParser(description="Render multi-angle screenshots of a 3D Godot scene.")
    parser.add_argument("--scene", default="scenes/prefabs/ships/cargo_ship_1.tscn", help="Path to Godot .tscn scene")
    parser.add_argument("--env", default="assets/art/environments/global_environment.tres", help="Path to Environment .tres")
    parser.add_argument("--lighting", default="scene", choices=["scene", "deep_space", "warm_star", "cold_star", "harsh_sun", "studio"], help="Lighting preset")
    parser.add_argument("--output-dir", default="tools/renders/cargo_ship_1", help="Output directory for PNG renders")
    parser.add_argument("--width", type=int, default=640, help="Render width (default: 640)")
    parser.add_argument("--height", type=int, default=480, help="Render height (default: 480)")
    parser.add_argument("--fill", type=float, default=0.88, help="Frame fill ratio (default: 0.88)")
    args = parser.parse_args()

    render_ship(args.scene, args.env, args.output_dir, args.lighting, args.width, args.height, args.fill)

if __name__ == '__main__':
    main()



