"""
A sector's economy, from the bridge's economy command (SectorEconomy): what each haven charges and
pays, every trade route with an estimated travel time and WP an hour for a ship, what each hull
earns trading and how long it takes to pay for itself, what is wrong with the market, and what
the 0.x economy has yet to estimate (SCOPE). The economy screen (World: Economy; Parts: e) and the
economy task show it.

    python3 tools/devtool/economy.py [sector=sector_elace] [ship=trader_medium]

Times are estimates from the ship's numbers, not flown: top speed = thrust / (mass * drag) with the
hold's cargo counted in the mass, plus the lag of speeding up and slowing down and the stops.
"""

import math
import os
import sys

APPROACH_TIME = 30.0  # s at each stop slowing for the dock and lining up, besides the dock itself (a guess, not flown)
DEFAULT_SECTOR = "sector_elace"
DEFAULT_SHIP = "trader_medium"

# What the 0.x economy covers (one sector to trade in, no jumps): (what, how this view stands on it,
# status). "shown" and "estimated" are here; "to estimate" is in the game but not worked out here
# yet; "after 0.x" is not in the game.
SCOPE = [
    ("Market", "What each haven charges and pays for every commodity, at even markups and standing 0", "shown"),
    ("Markups", "Each station rolls 0..{markup:.0%} on its prices every 24-36 min of world time: shown as a route's margin range", "shown"),
    ("Standing", "Moves prices up to {standing:.0%} either way; buying and selling back at one haven is checked at the best standing", "checked"),
    ("Trade routes", "Every seller to every other haven of the sector that buys, and which NPC factions may fly it", "shown"),
    ("Problems", "Stock that pays nowhere in the sector, and havens that pay as much as they charge: content problems in 0.x", "checked"),
    ("Travel times", "Each leg from the ship's top speed (thrust, fitted mass, cargo, drag) plus speeding up, slowing down and docking", "estimated"),
    ("WP an hour", "A full hold one way and back empty, at even markups; the best route per hull, and the hours it takes to earn the hull", "estimated"),
    ("Mining", "Ore from the fields to the best ore buyer: needs a lance's yield an hour (rocks, chunks, scooping)", "to estimate"),
    ("Salvage", "Scrap and tech from wrecks: comes with fights, so per fight, not per hour", "to estimate"),
    ("Bounties and wages", "Pay per kill (bounties) and per hour of escort or patrol (Wages)", "to estimate"),
    ("Running costs", "Repairs, rearming, lost cargo and hulls: what an hour of each kind of work costs", "to estimate"),
    ("Between sectors", "Routes across jumps and their fuel; stock that pays only in another sector becomes a warning (SectorEconomy.STOCK_MUST_PAY_IN_SECTOR)", "after 0.x"),
]
STATUS_COLOURS = {"shown": "green", "checked": "green", "estimated": "cyan", "to estimate": "yellow", "after 0.x": "dim"}


def scope_lines(economy):
    """SCOPE with the economy's own numbers filled in: [(what, about, status)]."""
    return [(what, about.format(markup=economy.get("markup_max", 0.5), standing=economy.get("standing_share", 0.1)), status)
            for what, about, status in SCOPE]


def ship(economy, ship_id):
    """The ship `ship_id` from the economy's ships, or the default one (DEFAULT_SHIP, else the first)."""
    ships = economy.get("ships", [])
    by_id = {entry["id"]: entry for entry in ships}
    return by_id.get(ship_id) or by_id.get(DEFAULT_SHIP) or (ships[0] if ships else None)


def top_speed(entry, drag, cargo_kg=0.0):
    """m/s the ship holds at full thrust with `cargo_kg` in the hold."""
    mass = entry["mass"] + cargo_kg
    return entry["thrust"] / (mass * drag) if mass > 0 and drag > 0 else 0.0


def leg_seconds(km, speed, drag):
    """Seconds to fly `km` at `speed` top speed: with linear drag a ship gets to most of its top
    speed in about 1/drag s, so it trails a flying start by that, and as much again slowing down."""
    if speed <= 0:
        return math.inf
    return km * 1000.0 / speed + 2.0 / drag


def trip(route, entry, economy):
    """A full hold of the route's commodity one way, back empty: {units, cargo_kg, load (WP to buy
    it), profit (WP a trip), loaded, empty, stops, total (s), wp_hour}."""
    drag, units = economy["drag"], int(entry["hold"])
    cargo = units * route["mass"]
    loaded = leg_seconds(route["km"], top_speed(entry, drag, cargo), drag)
    empty = leg_seconds(route["km"], top_speed(entry, drag), drag)
    stops = 2.0 * (economy["dock_time"] + APPROACH_TIME)
    total = loaded + empty + stops
    profit = units * (route["sale"] - route["buy"])
    return {"units": units, "cargo_kg": cargo, "load": units * route["buy"], "profit": profit, "loaded": loaded, "empty": empty,
            "stops": stops, "total": total, "wp_hour": profit * 3600.0 / total if math.isfinite(total) and total > 0 else 0.0}


def ranked_routes(economy, entry):
    """[(route, trip)] for the ship, most WP an hour first."""
    rows = [(route, trip(route, entry, economy)) for route in economy.get("routes", [])]
    return sorted(rows, key=lambda item: -item[1]["wp_hour"])


def ship_rows(economy):
    """Every hull's trading here: [{ship, speed, loaded_speed (with its hold full of the best
    route's cargo), route, trip, hours (to earn its own value; inf: no route pays)}], best earner first."""
    out = []
    for entry in economy.get("ships", []):
        ranked = ranked_routes(economy, entry)
        route, best = ranked[0] if ranked and ranked[0][1]["wp_hour"] > 0 else (None, None)
        speed = top_speed(entry, economy["drag"])
        loaded = top_speed(entry, economy["drag"], best["cargo_kg"]) if best else speed
        hours = entry["value"] / best["wp_hour"] if best else math.inf
        out.append({"ship": entry, "speed": speed, "loaded_speed": loaded, "route": route, "trip": best, "hours": hours})
    return sorted(out, key=lambda row: -(row["trip"]["wp_hour"] if row["trip"] else 0.0))


def market_grid(economy):
    """(commodity ids, rows): one row per haven with each commodity's cell (charge, pays), None where neither."""
    goods = [item["id"] for item in economy.get("commodities", []) if item["sold_at"] or item["bought_at"]]
    rows = []
    for haven in economy.get("havens", []):
        rows.append((haven, [(haven["sells"].get(good), haven["buys"].get(good)) for good in goods]))
    return goods, rows


def names(economy):
    """{commodity or haven id: its name}."""
    out = {item["id"]: item["name"] for item in economy.get("commodities", [])}
    out.update({haven["id"]: haven["name"] for haven in economy.get("havens", [])})
    return out


def duration(seconds):
    if not math.isfinite(seconds):
        return "never"
    if seconds >= 3600:
        return "%.1f h" % (seconds / 3600.0)
    return "%d:%02d" % (seconds // 60, seconds % 60)


def report(economy, ship_id=""):
    """The economy as plain text lines (the task's output)."""
    entry = ship(economy, ship_id)
    label = names(economy)
    lines = ["ECONOMY %s%s" % (economy["sector"], " (the evolution arena: problems are only warnings)" if economy.get("practice") else "")]
    goods, grid = market_grid(economy)
    lines.append("Market (WP a unit: sells / pays; even markups, standing 0):")
    lines.append("  %-20s " % "" + " ".join("%-13s" % label.get(good, good)[:13] for good in goods))
    for haven, cells in grid:
        lines.append("  %-20s " % haven["name"][:20] + " ".join("%-13s" % (
            "%s / %s" % (sold if sold is not None else "-", paid if paid is not None else "-") if sold is not None or paid is not None else "")
            for sold, paid in cells))
    problems = economy.get("problems", [])
    lines.append("Problems (%d):" % len(problems))
    for problem in problems:
        lines.append("  %s %s" % ("ERROR" if problem["hard"] else "warn ", problem["text"]))
    if entry is not None:
        lines.append("Routes for %s (hold %d units, %.0f m/s empty):" % (entry["id"], entry["hold"], top_speed(entry, economy["drag"])))
        for route, done in ranked_routes(economy, entry):
            lines.append("  %-16s %-18s -> %-18s %+4d a unit, %5.1f km, trip %7s, %+7.0f WP/h  %s" % (
                route["name"][:16], route["from_name"][:18], route["to_name"][:18], route["sale"] - route["buy"], route["km"],
                duration(done["total"]), done["wp_hour"], ", ".join(route["factions"]) or "no NPC"))
    lines.append("Hulls trading here (best route each):")
    for row in ship_rows(economy):
        route = row["route"]
        lines.append("  %-22s %4.0f m/s, hold %3d, %+7.0f WP/h, earns its %d WP in %s%s" % (
            row["ship"]["id"], row["speed"], row["ship"]["hold"], row["trip"]["wp_hour"] if row["trip"] else 0.0, row["ship"]["value"],
            duration(row["hours"] * 3600.0), " (%s, %s -> %s)" % (route["name"], route["from_name"], route["to_name"]) if route else ""))
    lines.append("Scope (0.x):")
    for what, about, status in scope_lines(economy):
        lines.append("  %-18s %-12s %s" % (what, status, about))
    return lines


def main(argv):
    values = dict(arg.split("=", 1) for arg in argv if "=" in arg)
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from devtool.bridge import Bridge, BridgeError
    bridge = Bridge()
    try:
        economy = bridge.call("economy", sector=values.get("sector", DEFAULT_SECTOR))
    except BridgeError as error:
        print(error)
        return 1
    finally:
        bridge.close()
    print("\n".join(report(economy, values.get("ship", ""))))
    return 1 if any(problem["hard"] for problem in economy["problems"]) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
