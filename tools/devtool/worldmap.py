"""
A sector seen from above, in characters: its bodies and its layout's markers (the bridge's
sector_map), x to the right and z down, scaled to fit. The picked marker is drawn reversed.

    render(items, selected="Havens/VerdantHaven", width=64, height=20) -> Rich markup
"""

SYMBOLS = {"star": "*", "planet": "O", "moon": "o", "station": "#",
           "haven_marker": "H", "beacon_marker": "B", "hazard_marker": "!"}
LEGEND = "* star  O planet  o moon  # station  H haven  B beacon  ! hazard"
CHAR_ASPECT = 2.0  # A character is about twice as tall as it is wide


def render(items, selected="", width=64, height=20):
    if not items:
        return "(nothing to draw)"
    xs = [item["x"] for item in items]
    zs = [item["z"] for item in items]
    span_x = max(max(xs) - min(xs), 1.0)
    span_z = max(max(zs) - min(zs), 1.0)
    per_char = max(span_x / (width - 1), span_z * CHAR_ASPECT / (height - 1))  # m per column, rows CHAR_ASPECT times that
    mid_x, mid_z = (max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2
    grid = [[" "] * width for _ in range(height)]
    picked = None
    # Markers last, so they show over bodies; the picked one last of all
    order = sorted(items, key=lambda item: (item.get("node", "") != "", item.get("node", "") == selected and selected != ""))
    for item in order:
        column = int(round((item["x"] - mid_x) / per_char + (width - 1) / 2))
        row = int(round((item["z"] - mid_z) * CHAR_ASPECT / per_char + (height - 1) / 2))
        column, row = min(max(column, 0), width - 1), min(max(row, 0), height - 1)
        grid[row][column] = SYMBOLS.get(item["kind"], "?")
        if selected and item.get("node", "") == selected:
            picked = (row, column)
    lines = []
    for row_index, row in enumerate(grid):
        text = "".join(row)
        if picked and picked[0] == row_index:
            column = picked[1]
            text = text[:column] + "[reverse bold]" + text[column] + "[/]" + text[column + 1:]
        lines.append(text)
    border = "+" + "-" * width + "+"
    out = [border] + ["|" + line + "|" for line in lines] + [border]
    out.append("[dim]%s;  one column %s[/dim]" % (LEGEND, _distance(per_char)))
    return "\n".join(out)


def _distance(metres):
    return "%.1f km" % (metres / 1000.0) if metres >= 1000 else "%d m" % metres
