import os
import glob

# File renames
moves = [
    ("database/registry/locations/sector_star_lywin_A.tres", "database/registry/locations/sector_star_lywin.tres"),
    ("scenes/levels/sectors/sector_star_lywin/sector_star_lywin_A.tscn", "scenes/levels/sectors/sector_star_lywin/sector_star_lywin.tscn"),
]

for src, dst in moves:
    if os.path.exists(src):
        os.rename(src, dst)

# Folder restructuring
base_dir = "scenes/levels/sectors/sector_star_lywin"
stars_dir = os.path.join(base_dir, "stars_lywin")

if os.path.exists(stars_dir):
    os.makedirs(os.path.join(base_dir, "star_lywin"), exist_ok=True)
    os.makedirs(os.path.join(base_dir, "star_lywin_B"), exist_ok=True)
    os.makedirs(os.path.join(base_dir, "star_lywin_C"), exist_ok=True)
    os.makedirs(os.path.join(base_dir, "star_lywin_D"), exist_ok=True)
    os.makedirs(os.path.join(base_dir, "star_lywin_E"), exist_ok=True)
    
    star_moves = [
        ("star_lywin_A.tscn", "star_lywin/star_lywin.tscn"),
        ("star_lywin_B.tscn", "star_lywin_B/star_lywin_B.tscn"),
        ("star_lywin_C.tscn", "star_lywin_C/star_lywin_C.tscn"),
        ("star_lywin_D.tscn", "star_lywin_D/star_lywin_D.tscn"),
        ("star_lywin_E.tscn", "star_lywin_E/star_lywin_E.tscn"),
        ("star_lywin_sprite.tscn", "star_lywin/star_lywin_sprite.tscn")
    ]
    for src_file, dst_path in star_moves:
        src = os.path.join(stars_dir, src_file)
        dst = os.path.join(base_dir, dst_path)
        if os.path.exists(src):
            os.rename(src, dst)
    try:
        os.rmdir(stars_dir)
    except:
        pass

# String replacements
replacements = [
    ("sector_star_lywin_A", "sector_star_lywin"),
    ("Lywin A Star", "Lywin Star"),
    ("Sector Star Lywin A", "Sector Star Lywin"),
    ("Star Lywin A", "Star Lywin"),
    ("stars_lywin/star_lywin_A.tscn", "star_lywin/star_lywin.tscn"),
    ("stars_lywin/star_lywin_B.tscn", "star_lywin_B/star_lywin_B.tscn"),
    ("stars_lywin/star_lywin_C.tscn", "star_lywin_C/star_lywin_C.tscn"),
    ("stars_lywin/star_lywin_D.tscn", "star_lywin_D/star_lywin_D.tscn"),
    ("stars_lywin/star_lywin_E.tscn", "star_lywin_E/star_lywin_E.tscn"),
    ("stars_lywin/star_lywin_sprite.tscn", "star_lywin/star_lywin_sprite.tscn"),
    ("lywin_a_", "lywin_"),
    ("sector_star_lywin_A.tres", "sector_star_lywin.tres"),
    ("sector_star_lywin_A.tscn", "sector_star_lywin.tscn"),
]

files_to_check = glob.glob("**/*.tres", recursive=True) + glob.glob("**/*.tscn", recursive=True) + glob.glob("**/*.gd", recursive=True)

for file in files_to_check:
    try:
        with open(file, 'r', encoding='utf-8') as f:
            content = f.read()
        new_content = content
        for old, new in replacements:
            new_content = new_content.replace(old, new)
        if new_content != content:
            with open(file, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print("Updated", file)
    except Exception as e:
        print("Could not process", file, e)
