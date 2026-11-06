"""
A sector seen from above, in characters: its bodies and its layout's markers (the bridge's
sector_map), x to the right and z down.

Each cell is two characters wide, which a terminal draws about square, and covers the same metres
across as down, so distances read true in every direction. A grid in round kilometres lies under
everything, labelled along the top and the left; the lines through the middle (x 0, z 0) are
brighter. Each thing is a symbol, with a count after it when more than one shares its cell; havens
and beacons take their owner's colour. Rings show the play area, each hazard's reach and the
picked marker's radius. The picked marker is drawn reversed.

    render(items, selected="Havens/VerdantHaven", columns=40, rows=20, colors={"verdant": "#3a6b3a"}, zoom=2)

zoom: 1 fits everything; each doubling halves the metres per cell, centred on the picked marker.
"""

import math

SYMBOLS = {"star": "*", "planet": "O", "moon": "o", "station": "#",
           "haven_marker": "H", "beacon_marker": "B", "hazard_marker": "!"}
LEGEND = "* star  O planet  o moon  H haven  B beacon  ! hazard  · rings: play area, hazards, the picked one's radius"
# Which symbol a shared cell shows: the picked marker first, then havens, hazards, beacons, bodies
RANK = {"haven_marker": 0, "hazard_marker": 1, "beacon_marker": 2, "station": 3, "star": 4, "planet": 5, "moon": 6}
BODY_STYLE = {"star": "bold yellow", "planet": "cyan", "moon": "dim cyan", "station": "white", "hazard_marker": "bold red"}
NICE = (1, 2, 2.5, 5)
LABEL_WIDTH = 7


def nice_step(at_least):
    """The smallest 1, 2 or 5 x 10^n not below `at_least`."""
    if at_least <= 0:
        return 1.0
    power = 10 ** math.floor(math.log10(at_least))
    for factor in NICE + (10,):
        if factor * power >= at_least:
            return float(factor * power)
    return float(10 * power)


def km(metres):
    return ("%g" % (metres / 1000.0)) if metres else "0"


def distance(metres):
    return "%g km" % (metres / 1000.0) if metres >= 1000 else "%g m" % metres


def render(items, selected="", columns=40, rows=20, colors=None, zoom=1, max_rows=40):
    """rows=None: as many as the sector needs down at the scale its width sets (up to max_rows)."""
    colors = colors or {}
    drawn = [item for item in items if item["kind"] in SYMBOLS]
    if not drawn:
        return "(nothing to draw)"
    xs = [item["x"] for item in drawn] + [0.0]
    zs = [item["z"] for item in drawn] + [0.0]
    if rows is None and zoom > 1:
        rows = min(max_rows, max(8, columns // 2))
    if rows is None:
        cell_guess = nice_step(max((max(xs) - min(xs)) / max(columns - 3, 1), (max(zs) - min(zs)) / max(max_rows - 3, 1), 1.0) / max(zoom, 1))
        rows = int(min(max_rows, max(8, math.ceil((max(zs) - min(zs)) / cell_guess) + 3)))
    span = max((max(xs) - min(xs)) / max(columns - 3, 1), (max(zs) - min(zs)) / max(rows - 3, 1), 1.0)
    cell = nice_step(span / max(zoom, 1))  # m per cell, across and down alike
    grid_step = nice_step(cell * 3)  # A grid line every three to five cells
    if grid_step / cell != round(grid_step / cell):  # 2.5 km cells: lines on whole cells
        grid_step = cell * 4
    middle_x = (max(xs) + min(xs)) / 2.0
    middle_z = (max(zs) + min(zs)) / 2.0
    focus = [item for item in items if selected and item.get("node") == selected]
    if zoom > 1 and focus:
        middle_x, middle_z = focus[0]["x"], focus[0]["z"]
    # Cells are centred on whole multiples of `cell` (grid_step is one too), so the grid lines and
    # anything at a round place fall on a cell's middle, never on an edge between two
    first_x = round(middle_x / cell - (columns - 1) / 2.0)
    first_z = round(middle_z / cell - (rows - 1) / 2.0)

    def centre_x(c):
        return (first_x + c) * cell

    def centre_z(r):
        return (first_z + r) * cell

    def cell_of(x, z):
        return int(round(z / cell)) - first_z, int(round(x / cell)) - first_x

    def on_line(centre):
        return abs(centre / grid_step - round(centre / grid_step)) < 1e-6

    column_lines = [on_line(centre_x(c)) for c in range(columns)]
    row_lines = [on_line(centre_z(r)) for r in range(rows)]
    zero_column = cell_of(0.0, 0.0)[1]
    zero_row = cell_of(0.0, 0.0)[0]

    # Background: the grid
    cells = [[None] * columns for _ in range(rows)]
    for r in range(rows):
        for c in range(columns):
            vertical, horizontal = column_lines[c], row_lines[r]
            axis = c == zero_column or r == zero_row
            style = "grey50" if axis else "grey30"
            if vertical and horizontal:
                cells[r][c] = ("┼─", style)
            elif vertical:
                cells[r][c] = ("│ ", style)
            elif horizontal:
                cells[r][c] = ("──", style)
            else:
                cells[r][c] = ("  ", "")

    # Rings: the play area, hazards' reach, the picked marker's radius
    rings = [(item, "grey50") for item in items if item["kind"] == "play_area" and item.get("radius")]
    rings += [(item, "red") for item in items if item["kind"] == "hazard_marker" and item.get("radius")]
    rings += [(item, "bold white") for item in items if selected and item.get("node") == selected and item.get("radius")]
    for item, style in rings:
        steps = max(int(2 * math.pi * item["radius"] / cell * 1.5), 16)
        for step in range(steps):
            angle = 2 * math.pi * step / steps
            r, c = cell_of(item["x"] + item["radius"] * math.cos(angle), item["z"] + item["radius"] * math.sin(angle))
            if 0 <= r < rows and 0 <= c < columns:
                cells[r][c] = ("· ", style)

    # Things, the most telling of each cell on top
    shared = {}
    off_map = 0
    for item in drawn:
        r, c = cell_of(item["x"], item["z"])
        if not (0 <= r < rows and 0 <= c < columns):
            off_map += 1
            continue
        shared.setdefault((r, c), []).append(item)
    for (r, c), here in shared.items():
        here.sort(key=lambda item: (not (selected and item.get("node") == selected), RANK.get(item["kind"], 9)))
        first = here[0]
        count = " " if len(here) == 1 else (str(len(here)) if len(here) < 10 else "+")
        style = BODY_STYLE.get(first["kind"], "white")
        if first.get("faction") and colors.get(first["faction"]):
            style = "bold " + colors[first["faction"]]
        elif first["kind"] in ("haven_marker", "beacon_marker"):
            style = "bold white"
        if selected and first.get("node") == selected:
            style += " reverse"
        cells[r][c] = (SYMBOLS[first["kind"]] + count, style)

    # Labels: km along the top on grid columns, down the left on grid rows
    header = [" "] * (columns * 2)
    for c in range(columns):
        if column_lines[c]:
            text = km(centre_x(c))
            if all(ch == " " for ch in header[c * 2:c * 2 + len(text) + 1]):
                header[c * 2:c * 2 + len(text)] = list(text)
    lines = [" " * LABEL_WIDTH + "".join(header[:columns * 2]).rstrip()]
    lines.append(" " * (LABEL_WIDTH - 1) + "┌" + "─" * (columns * 2) + "┐")
    for r in range(rows):
        label = ""
        if row_lines[r]:
            label = km(centre_z(r))
        body = "".join(("[%s]%s[/]" % (style, text.replace("[", "\\[")) if style else text) for text, style in cells[r])
        lines.append(label.rjust(LABEL_WIDTH - 2) + " │" + body + "│")
    lines.append(" " * (LABEL_WIDTH - 1) + "└" + "─" * (columns * 2) + "┘")
    note = "grid %s, one cell %s, x across, z down (km)%s" % (distance(grid_step), distance(cell), ", zoom x%d" % zoom if zoom > 1 else "")
    if off_map:
        note += "; %d off the map" % off_map
    lines.append("[dim]%s\n%s[/dim]" % (LEGEND, note))
    return "\n".join(lines)
