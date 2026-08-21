#!/usr/bin/env python3
"""
Assign or update material resources for nodes in a Godot .tscn scene file.

Usage:
    python3 tools/ship_tools/update_ship_material.py --node "engine" --material "assets/art/materials_generic/mat_engine_dark.tres" [--scene scenes/prefabs/ships/cargo_ship_1.tscn]
"""

import sys
import os
import re
import argparse

def assign_material_to_node(scene_path, node_name, material_path, is_surface=False, surface_idx=0):
    if not os.path.exists(scene_path):
        print(f"Error: Scene file not found: {scene_path}")
        sys.exit(1)

    rel_mat = os.path.relpath(material_path, start=os.getcwd()).replace('\\', '/')
    res_mat = f"res://{rel_mat}"

    with open(scene_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find existing ext_resources
    # [ext_resource path="res://..." type="Material" id=X]
    ext_pattern = re.compile(r'\[ext_resource path="([^"]+)" type="([^"]+)" id=(\d+)\]')
    ext_resources = {}
    max_ext_id = 0
    for match in ext_pattern.finditer(content):
        path, rtype, rid = match.groups()
        rid = int(rid)
        ext_resources[path] = (rid, rtype)
        if rid > max_ext_id:
            max_ext_id = rid

    # Check if target material already in ext_resource
    if res_mat in ext_resources:
        mat_ext_id = ext_resources[res_mat][0]
    else:
        # Need to add new ext_resource
        mat_ext_id = max_ext_id + 1
        # Determine resource type (ShaderMaterial or Material)
        rtype = "Material"
        if os.path.exists(material_path):
            with open(material_path, 'r', encoding='utf-8') as mf:
                m_content = mf.read(500)
                if 'type="ShaderMaterial"' in m_content or 'ShaderMaterial' in m_content:
                    rtype = "Material" # In Godot 3 ext_resource for ShaderMaterial is usually type="Material"
        
        new_ext_line = f'[ext_resource path="{res_mat}" type="{rtype}" id={mat_ext_id}]\n'
        # Insert after last ext_resource or after scene header
        last_ext = list(ext_pattern.finditer(content))
        if last_ext:
            pos = last_ext[-1].end()
            content = content[:pos] + '\n' + new_ext_line.strip() + content[pos:]
        else:
            header_end = content.find('\n\n')
            if header_end != -1:
                content = content[:header_end+1] + new_ext_line + content[header_end+1:]
            else:
                content = new_ext_line + content

    # Find target node
    node_pattern = re.compile(rf'(\[node name="{re.escape(node_name)}"[^\]]*\]\n)([\s\S]*?)(?=\n\[node|\n\[editable|\Z)')
    node_match = node_pattern.search(content)
    if not node_match:
        print(f"Error: Node '{node_name}' not found in {scene_path}")
        return False

    header, body = node_match.groups()
    mat_prop = f"material/{surface_idx}" if is_surface else "material_override"
    val = f"ExtResource( {mat_ext_id} )"

    if f"{mat_prop} =" in body:
        new_body = re.sub(rf'{re.escape(mat_prop)}\s*=\s*([^\n]+)', f'{mat_prop} = {val}', body)
    else:
        new_body = body.rstrip() + f'\n{mat_prop} = {val}\n'

    content = content[:node_match.start()] + header + new_body + content[node_match.end():]

    # Recalculate load_steps
    # load_steps = count(ext_resource) + count(sub_resource) + 1
    total_ext = len(re.findall(r'\[ext_resource ', content))
    total_sub = len(re.findall(r'\[sub_resource ', content))
    load_steps = total_ext + total_sub + 1
    content = re.sub(r'\[gd_scene load_steps=\d+', f'[gd_scene load_steps={load_steps}', content)

    with open(scene_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Successfully assigned {res_mat} (id={mat_ext_id}) to node '{node_name}' in {scene_path}")
    return True

def main():
    parser = argparse.ArgumentParser(description="Update node material in Godot scene.")
    parser.add_argument("--scene", default="scenes/prefabs/ships/cargo_ship_1.tscn", help="Path to .tscn")
    parser.add_argument("--node", required=True, help="Target node name")
    parser.add_argument("--material", required=True, help="Path to material .tres")
    parser.add_argument("--surface", action="store_true", help="Assign to surface material instead of material_override")
    parser.add_argument("--surface-idx", type=int, default=0, help="Surface index (default 0)")
    args = parser.parse_args()

    assign_material_to_node(args.scene, args.node, args.material, args.surface, args.surface_idx)

if __name__ == '__main__':
    main()

