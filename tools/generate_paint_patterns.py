#!/usr/bin/env python3
"""Generate seamless, grayscale paint patterns: camouflage, stripes and geometric designs a faction
might paint on its ships (decorative paint, not plating detail).

Every pattern is built on a torus (periodic noise, integer stripe directions, wrapped Voronoi), so
the image tiles without seams. Edges are antialiased by supersampling. Output: 8-bit grayscale PNG.

Usage (from the project root):
    python3 tools/generate_paint_patterns.py PATTERN [options] -o out.png
    python3 tools/generate_paint_patterns.py --library [--out-dir DIR]   # the presets, + a contact sheet
    python3 tools/generate_paint_patterns.py --list                      # patterns and presets

Patterns (main options in brackets; all take --seed, --size, --invert):
    camo       woodland blobs in --tones (--scale, --warp, --detail)
    digital    pixelated camo (--scale, --pixels: blocks across the tile)
    splinter   angular shards (--cells, --stretch, --angle)
    tiger      broken, wavy stripes (--count, --dir, --warp, --duty)
    dazzle     razzle-dazzle: regions of stripes at different angles (--cells, --count)
    stripes    straight stripes (--count, --dir, --duty)
    chevrons   zigzag stripes (--count, --zigzags, --depth, --duty)
    checker    checkerboard (--count)
    diamonds   argyle diamonds (--count, --duty)
    dots       polka dots on a staggered grid (--count, --duty: dot size)
    hex        hexagon cells, filled in --tones or outlined (--count, --outline)
    triangles  triangle tiling in --tones (--count)
    grid       grid lines (--count, --duty: line width)

--tones: the gray levels used, e.g. "0,1" (black and white) or "0,0.35,0.7,1". Noise patterns
split their area evenly between the tones. --dir "a,b": stripe direction as whole numbers of
repeats across x and y (keeps the tile seamless): "1,0" vertical, "0,1" horizontal, "1,1" diagonal.

In Godot, import the PNGs with Repeat on (the --library run writes .import files that set it).
"""

import argparse
import math
import os
import sys

import numpy as np
from PIL import Image

AA = 2  # Supersampling factor for antialiased edges


# --- Periodic building blocks (coordinates are in [0, 1) and wrap) -------------------------------

def grid(size):
    """Pixel-centre coordinates x, y in [0, 1), at the supersampled resolution."""
    n = size * AA
    c = (np.arange(n) + 0.5) / n
    return np.meshgrid(c, c)


def value_noise(x, y, freq, rng):
    """Smooth periodic value noise with `freq` lattice cells across the tile, in 0..1."""
    lattice = rng.random((freq, freq))
    fx, fy = x * freq, y * freq
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    x0, y0 = ix % freq, iy % freq
    x1, y1 = (ix + 1) % freq, (iy + 1) % freq
    a = lattice[y0, x0] * (1 - tx) + lattice[y0, x1] * tx
    b = lattice[y1, x0] * (1 - tx) + lattice[y1, x1] * tx
    return a * (1 - ty) + b * ty


def fbm(x, y, freq, rng, octaves=4, gain=0.5):
    """Periodic fractal noise: octaves at freq, 2 freq, ...; normalised to 0..1."""
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + amp * value_noise(x, y, freq * 2 ** o, rng)
        norm += amp
        amp *= gain
    return total / norm


def warped(x, y, freq, warp, rng, octaves=4):
    """fbm with its domain pushed around by two more fbm fields: organic, flowing shapes."""
    wx = fbm(x, y, max(1, freq // 2), rng, 3) - 0.5
    wy = fbm(x, y, max(1, freq // 2), rng, 3) - 0.5
    return fbm((x + warp * wx) % 1.0, (y + warp * wy) % 1.0, freq, rng, octaves)


def voronoi(x, y, points, sx=1.0, sy=1.0):
    """Nearest and second-nearest wrapped distances, and the index of the nearest point.
    sx, sy stretch the metric (elongated cells)."""
    d1 = np.full(x.shape, np.inf)
    d2 = np.full(x.shape, np.inf)
    idx = np.zeros(x.shape, dtype=int)
    for i, (px, py) in enumerate(points):
        dx = np.abs(x - px)
        dy = np.abs(y - py)
        dx = np.minimum(dx, 1 - dx) * sx
        dy = np.minimum(dy, 1 - dy) * sy
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    return d1, d2, idx


def rotate(x, y, angle_deg):
    """Coordinates turned by an angle (for anisotropic metrics; not periodic on its own)."""
    a = math.radians(angle_deg)
    return x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)


def tri(v):
    """Triangle wave, period 1, 0..1."""
    return 1 - 2 * np.abs(np.mod(v, 1.0) - 0.5)


def even_tones(field, tones):
    """Splits `field` into len(tones) bands of equal area and paints each its tone."""
    cuts = np.quantile(field, np.linspace(0, 1, len(tones) + 1)[1:-1])
    out = np.full(field.shape, tones[0], dtype=float)
    for cut, tone in zip(cuts, tones[1:]):
        out = np.where(field >= cut, tone, out)
    return out


def parse_dir(text):
    a, b = (int(v) for v in text.split(","))
    if a == 0 and b == 0:
        sys.exit("--dir cannot be 0,0")
    return a, b


# --- Patterns: each returns a float image in 0..1 at the supersampled size ------------------------

def p_camo(o, rng):
    x, y = grid(o.size)
    field = warped(x, y, o.scale, o.warp, rng, octaves=o.detail)
    return even_tones(field, o.tones)


def p_digital(o, rng):
    x, y = grid(o.size)
    # Sample the camo field at the centre of each block: a block of pixels takes one tone.
    block = 1.0 / o.pixels
    bx = (np.floor(x / block) + 0.5) * block
    by = (np.floor(y / block) + 0.5) * block
    field = warped(bx, by, o.scale, o.warp, rng, octaves=o.detail)
    return even_tones(field, o.tones)


def p_splinter(o, rng):
    x, y = grid(o.size)
    points = rng.random((o.cells, 2))
    # Stretched along --angle: the metric is applied after rotating the wrapped offsets.
    a = math.radians(o.angle)
    d1 = np.full(x.shape, np.inf)
    idx = np.zeros(x.shape, dtype=int)
    for i, (px, py) in enumerate(points):
        dx = np.mod(x - px + 0.5, 1.0) - 0.5
        dy = np.mod(y - py + 0.5, 1.0) - 0.5
        u = dx * math.cos(a) + dy * math.sin(a)
        v = -dx * math.sin(a) + dy * math.cos(a)
        d = np.abs(u) / o.stretch + np.abs(v)  # Manhattan-like: straight, angular edges
        closer = d < d1
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    cell_tone = np.array([o.tones[i % len(o.tones)] for i in rng.permutation(o.cells)])
    return cell_tone[idx]


def p_tiger(o, rng):
    x, y = grid(o.size)
    a, b = parse_dir(o.dir)
    wave = o.count * (a * x + b * y) + o.warp * (fbm(x, y, 3, rng, 3) - 0.5) * 4
    breakup = fbm(x, y, 4, rng, 3) - 0.5
    return np.where(tri(wave) < o.duty + breakup * 0.8, o.tones[-1], o.tones[0])


def p_dazzle(o, rng):
    x, y = grid(o.size)
    points = rng.random((o.cells, 2))
    _, _, idx = voronoi(x, y, points)
    out = np.zeros(x.shape)
    dirs = [(1, 0), (0, 1), (1, 1), (1, -1), (2, 1), (1, 2), (2, -1), (1, -2)]
    for i in range(o.cells):
        mask = idx == i
        if rng.random() < 0.2:  # Some regions are solid
            out[mask] = o.tones[rng.integers(len(o.tones))]
            continue
        a, b = dirs[rng.integers(len(dirs))]
        count = max(1, int(o.count * rng.uniform(0.5, 1.5)))
        phase = rng.random()
        stripe = np.mod(count * (a * x[mask] + b * y[mask]) + phase, 1.0) < o.duty
        out[mask] = np.where(stripe, o.tones[-1], o.tones[0])
    return out


def p_stripes(o, rng):
    x, y = grid(o.size)
    a, b = parse_dir(o.dir)
    return np.where(np.mod(o.count * (a * x + b * y), 1.0) < o.duty, o.tones[-1], o.tones[0])


def p_chevrons(o, rng):
    x, y = grid(o.size)
    # Stripes across y, bent into a zigzag along x.
    v = o.count * y + o.depth * tri(o.zigzags * x)
    return np.where(np.mod(v, 1.0) < o.duty, o.tones[-1], o.tones[0])


def p_checker(o, rng):
    x, y = grid(o.size)
    cell = (np.floor(x * o.count) + np.floor(y * o.count)) % 2
    return np.where(cell == 0, o.tones[0], o.tones[-1])


def p_diamonds(o, rng):
    x, y = grid(o.size)
    d = np.abs(np.mod(x * o.count, 1.0) - 0.5) + np.abs(np.mod(y * o.count, 1.0) - 0.5)
    return np.where(d < o.duty, o.tones[-1], o.tones[0])


def p_dots(o, rng):
    x, y = grid(o.size)
    # Staggered rows: every other row shifted by half a cell (count rows, so it wraps).
    row = np.floor(y * o.count)
    fx = np.mod(x * o.count + 0.5 * (row % 2), 1.0) - 0.5
    fy = np.mod(y * o.count, 1.0) - 0.5
    return np.where(np.sqrt(fx * fx + fy * fy) < o.duty * 0.5, o.tones[-1], o.tones[0])


def p_hex(o, rng):
    x, y = grid(o.size)
    cols = o.count
    if o.outline <= 0 and len(o.tones) >= 3:
        cols = max(3, int(round(cols / 3.0)) * 3)  # Three-colouring wraps only with columns in threes
    rows = max(2, int(round(cols * 2 / math.sqrt(3) / 2)) * 2)  # Even, so the stagger wraps
    points = [((i + 0.5 * (j % 2) + 0.25) / cols, (j + 0.5) / rows) for j in range(rows) for i in range(cols)]
    d1, d2, idx = voronoi(x, y, points)
    if o.outline > 0:
        return np.where(d2 - d1 < o.outline / cols, o.tones[-1], o.tones[0])
    # Odd rows sit half a cell right ("odd-r"); in axial coordinates (q, r) no two neighbours share
    # (q - r) mod 3, so three tones never touch themselves. Fewer tones: random per cell.
    j, i = idx // cols, idx % cols
    if len(o.tones) >= 3:
        q = i - (j - (j % 2)) // 2
        k = np.mod(q - j, 3)
    else:
        k = rng.integers(len(o.tones), size=cols * rows)[idx]
    return np.array(o.tones)[k]


def p_triangles(o, rng):
    x, y = grid(o.size)
    fx, fy = np.mod(x * o.count, 1.0), np.mod(y * o.count, 1.0)
    cell = (np.floor(x * o.count) + np.floor(y * o.count)) % 2
    lower = fx + fy < 1.0  # Each square split along its diagonal
    k = (cell * 2 + lower).astype(int)
    tones = np.array(o.tones)
    return tones[k % len(tones)]


def p_grid(o, rng):
    x, y = grid(o.size)
    fx = np.abs(np.mod(x * o.count, 1.0) - 0.5)
    fy = np.abs(np.mod(y * o.count, 1.0) - 0.5)
    line = (fx > 0.5 - o.duty * 0.5) | (fy > 0.5 - o.duty * 0.5)
    return np.where(line, o.tones[-1], o.tones[0])


PATTERNS = {
    "camo": p_camo, "digital": p_digital, "splinter": p_splinter, "tiger": p_tiger,
    "dazzle": p_dazzle, "stripes": p_stripes, "chevrons": p_chevrons, "checker": p_checker,
    "diamonds": p_diamonds, "dots": p_dots, "hex": p_hex, "triangles": p_triangles, "grid": p_grid,
}

DEFAULTS = dict(
    seed=1, size=512, tones="0,1", invert=False,
    scale=3, warp=0.35, detail=4, pixels=64,
    cells=24, stretch=3.0, angle=30.0,
    count=6, dir="1,1", duty=0.5, zigzags=4, depth=1.0, outline=0.0,
)

# The library: name -> (pattern, overrides). Names say what the pattern is; edit freely.
LIBRARY = {
    "camo_woodland_4tone": ("camo", dict(tones="0,0.33,0.66,1", scale=3, warp=0.4, seed=11)),
    "camo_blotch_2tone": ("camo", dict(tones="0,1", scale=2, warp=0.5, detail=3, seed=4)),
    "camo_fine_3tone": ("camo", dict(tones="0,0.5,1", scale=5, warp=0.3, seed=7)),
    "camo_digital_4tone": ("digital", dict(tones="0,0.33,0.66,1", scale=3, pixels=64, seed=11)),
    "camo_digital_coarse_3tone": ("digital", dict(tones="0,0.5,1", scale=2, pixels=32, seed=5)),
    "camo_splinter_3tone": ("splinter", dict(tones="0,0.5,1", cells=28, stretch=3.0, angle=25, seed=3)),
    "camo_splinter_wide_2tone": ("splinter", dict(tones="0,1", cells=16, stretch=5.0, angle=-15, seed=8)),
    "tiger_stripes": ("tiger", dict(count=5, dir="1,0", warp=0.6, duty=0.3, seed=2)),
    "dazzle": ("dazzle", dict(cells=9, count=7, seed=6)),
    "dazzle_busy": ("dazzle", dict(cells=16, count=10, seed=12)),
    "stripes_diagonal": ("stripes", dict(count=6, dir="1,1", duty=0.5)),
    "stripes_hazard": ("stripes", dict(count=8, dir="1,1", duty=0.5)),
    "stripes_pinstripe": ("stripes", dict(count=16, dir="0,1", duty=0.12)),
    "stripes_racing": ("stripes", dict(count=2, dir="1,0", duty=0.18)),
    "chevrons": ("chevrons", dict(count=6, zigzags=3, depth=1.0, duty=0.5)),
    "chevrons_shallow": ("chevrons", dict(count=8, zigzags=6, depth=0.6, duty=0.35)),
    "checker": ("checker", dict(count=8)),
    "checker_large": ("checker", dict(count=4)),
    "diamonds": ("diamonds", dict(count=6, duty=0.4)),
    "dots": ("dots", dict(count=10, duty=0.55)),
    "hex_cells_3tone": ("hex", dict(count=8, tones="0,0.5,1")),
    "hex_outline": ("hex", dict(count=8, outline=0.08)),
    "triangles_4tone": ("triangles", dict(count=6, tones="0,0.33,0.66,1")),
    "grid": ("grid", dict(count=8, duty=0.08)),
}


def render(pattern, o):
    o.tones = [float(v) for v in str(o.tones).split(",")]
    rng = np.random.default_rng(o.seed)
    img = PATTERNS[pattern](o, rng)
    img = img.reshape(o.size, AA, o.size, AA).mean(axis=(1, 3))  # Supersampled -> antialiased
    if o.invert:
        img = 1.0 - img
    return Image.fromarray(np.clip(img * 255.0 + 0.5, 0, 255).astype(np.uint8), mode="L")


def options(overrides):
    o = argparse.Namespace(**DEFAULTS)
    for k, v in overrides.items():
        setattr(o, k, v)
    return o


IMPORT_TEMPLATE = """[remap]

importer="texture"
type="StreamTexture"

[deps]

source_file="{res}"

[params]

compress/mode=0
compress/lossy_quality=0.7
compress/hdr_mode=0
compress/bptc_ldr=0
compress/normal_map=0
flags/repeat=1
flags/filter=true
flags/mipmaps=true
flags/anisotropic=false
flags/srgb=2
process/fix_alpha_border=true
process/premult_alpha=false
process/HDR_as_SRGB=false
process/invert_color=false
process/normal_map_invert_y=false
stream=false
size_limit=0
detect_3d=false
svg/scale=1.0
"""


def write_import(path):
    """A Godot .import next to the PNG with Repeat on (the editor fills in the rest on import)."""
    res = "res://" + os.path.relpath(os.path.abspath(path), os.getcwd()).replace(os.sep, "/")
    with open(path + ".import", "w") as f:
        f.write(IMPORT_TEMPLATE.format(res=res))


def contact_sheet(paths, out, tile=192, columns=6):
    """All patterns side by side, each tiled 2x2 at half size so seams would show."""
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new("L", (columns * tile, rows * (tile + 16)), 40)
    for i, path in enumerate(paths):
        img = Image.open(path).resize((tile // 2, tile // 2), Image.LANCZOS)
        cx, cy = (i % columns) * tile, (i // columns) * (tile + 16)
        for dx in (0, tile // 2):
            for dy in (0, tile // 2):
                sheet.paste(img, (cx + dx, cy + dy))
    sheet.save(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pattern", nargs="?", choices=sorted(PATTERNS))
    ap.add_argument("-o", "--out", help="output PNG (one pattern)")
    ap.add_argument("--library", action="store_true", help="write every preset to --out-dir, plus a contact sheet")
    ap.add_argument("--out-dir", default="assets/art/textures/paint_patterns")
    ap.add_argument("--sheet", default="tools/renders/paint_patterns_sheet.png", help="contact sheet of the library (kept out of the game's assets)")
    ap.add_argument("--list", action="store_true")
    for k, v in DEFAULTS.items():
        if isinstance(v, bool):
            ap.add_argument("--" + k, action="store_true")
        else:
            ap.add_argument("--" + k, type=type(v), default=v)
    args = ap.parse_args()

    if args.list:
        print("Patterns:", ", ".join(sorted(PATTERNS)))
        for name, (pattern, kw) in LIBRARY.items():
            print("  %-28s %-10s %s" % (name, pattern, " ".join("--%s %s" % kv for kv in kw.items())))
        return
    if args.library:
        os.makedirs(args.out_dir, exist_ok=True)
        paths = []
        for name, (pattern, kw) in LIBRARY.items():
            path = os.path.join(args.out_dir, name + ".png")
            render(pattern, options(dict(kw, size=args.size))).save(path)
            if not os.path.exists(path + ".import"):
                write_import(path)
            paths.append(path)
            print("wrote", path)
        contact_sheet(paths, args.sheet)
        print("sheet", args.sheet)
        return
    if not args.pattern or not args.out:
        ap.error("give a PATTERN and -o OUT, or --library, or --list")
    o = options({k: getattr(args, k) for k in DEFAULTS})
    render(args.pattern, o).save(args.out)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
