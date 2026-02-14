"""
GDTLancer ncurses TUI — real-time simulation dashboard.

Displays spatial (sector map, agent positions, hostiles) and non-spatial
(stockpiles, dominion, market, chronicle, matter conservation) data in a
single curses screen that redraws every tick (1 tick ≈ 1 second).

No external dependencies beyond the Python standard library.

Key bindings:
    q / ESC  — quit
    SPACE    — pause / resume
    +/-      — speed up / slow down tick interval
    r        — restart simulation
"""

import curses
import time
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from simulation_engine import SimulationEngine


# ═══════════════════════════════════════════════════════════════════
# Color pair IDs
# ═══════════════════════════════════════════════════════════════════
CP_DEFAULT    = 0
CP_TITLE      = 1
CP_HEADER     = 2
CP_GOOD       = 3
CP_WARN       = 4
CP_BAD        = 5
CP_DIM        = 6
CP_CYAN       = 7
CP_MAGENTA    = 8
CP_ORE        = 9
CP_FUEL       = 10
CP_FOOD       = 11
CP_TECH       = 12
CP_LUXURY     = 13
CP_MINER      = 14
CP_TRADER     = 15
CP_INDIE      = 16
CP_BAR_EMPTY  = 17
CP_PIRATE     = 18
CP_PLAYER     = 19
CP_AXIOM_OK   = 20
CP_AXIOM_FAIL = 21
CP_CHRONICLE  = 22
CP_BOX        = 23
CP_SECTOR_HUB = 24
CP_SECTOR_FRT = 25
CP_CASH_HIGH  = 26
CP_CASH_MID   = 27
CP_CASH_LOW   = 28
CP_MILITARY   = 29
CP_AGE_PROSPERITY = 30
CP_AGE_DISRUPTION = 31
CP_AGE_RECOVERY   = 32

COMMODITY_CP = {
    "commodity_ore":    CP_ORE,
    "commodity_fuel":   CP_FUEL,
    "commodity_food":   CP_FOOD,
    "commodity_tech":   CP_TECH,
    "commodity_luxury": CP_LUXURY,
}

COMMODITY_SHORT = {
    "commodity_ore":    "ORE",
    "commodity_fuel":   "FUL",
    "commodity_food":   "FOD",
    "commodity_tech":   "TEC",
    "commodity_luxury": "LUX",
}

FACTION_CP = {
    "faction_miners":       CP_MINER,
    "faction_traders":      CP_TRADER,
    "faction_independents": CP_INDIE,
    "faction_military":     CP_MILITARY,
}

FACTION_SHORT = {
    "faction_miners":       "MIN",
    "faction_traders":      "TRD",
    "faction_independents": "IND",
    "faction_military":     "MIL",
}


def _short_commodity(cid: str) -> str:
    return COMMODITY_SHORT.get(cid, cid.replace("commodity_", "")[:3].upper())


def _short_faction(fid: str) -> str:
    return FACTION_SHORT.get(fid, fid.replace("faction_", "")[:3].upper())


def _loc_short(sid: str) -> str:
    return sid.replace("station_", "").upper()


# ═══════════════════════════════════════════════════════════════════
# Init colors
# ═══════════════════════════════════════════════════════════════════
def _init_colors():
    curses.start_color()
    curses.use_default_colors()

    curses.init_pair(CP_TITLE,      curses.COLOR_CYAN,    -1)
    curses.init_pair(CP_HEADER,     curses.COLOR_WHITE,   -1)
    curses.init_pair(CP_GOOD,       curses.COLOR_GREEN,   -1)
    curses.init_pair(CP_WARN,       curses.COLOR_YELLOW,  -1)
    curses.init_pair(CP_BAD,        curses.COLOR_RED,     -1)
    curses.init_pair(CP_DIM,        8,                    -1)  # bright black = gray
    curses.init_pair(CP_CYAN,       curses.COLOR_CYAN,    -1)
    curses.init_pair(CP_MAGENTA,    curses.COLOR_MAGENTA, -1)

    # Commodities  (use available 8 colors; ore=yellow, fuel=cyan, food=green, tech=magenta, luxury=yellow)
    curses.init_pair(CP_ORE,        curses.COLOR_YELLOW,  -1)
    curses.init_pair(CP_FUEL,       curses.COLOR_CYAN,    -1)
    curses.init_pair(CP_FOOD,       curses.COLOR_GREEN,   -1)
    curses.init_pair(CP_TECH,       curses.COLOR_MAGENTA, -1)
    curses.init_pair(CP_LUXURY,     curses.COLOR_YELLOW,  -1)

    # Factions
    curses.init_pair(CP_MINER,      curses.COLOR_YELLOW,  -1)
    curses.init_pair(CP_TRADER,     curses.COLOR_CYAN,    -1)
    curses.init_pair(CP_INDIE,      curses.COLOR_GREEN,   -1)

    curses.init_pair(CP_BAR_EMPTY,  8,                    -1)
    curses.init_pair(CP_PIRATE,     curses.COLOR_RED,     -1)
    curses.init_pair(CP_PLAYER,     curses.COLOR_GREEN,   -1)

    curses.init_pair(CP_AXIOM_OK,   curses.COLOR_GREEN,   -1)
    curses.init_pair(CP_AXIOM_FAIL, curses.COLOR_RED,     -1)
    curses.init_pair(CP_CHRONICLE,  curses.COLOR_MAGENTA, -1)
    curses.init_pair(CP_BOX,        curses.COLOR_CYAN,    -1)

    curses.init_pair(CP_SECTOR_HUB, curses.COLOR_CYAN,    -1)
    curses.init_pair(CP_SECTOR_FRT, curses.COLOR_YELLOW,  -1)

    curses.init_pair(CP_CASH_HIGH,  curses.COLOR_GREEN,   -1)
    curses.init_pair(CP_CASH_MID,   curses.COLOR_YELLOW,  -1)
    curses.init_pair(CP_CASH_LOW,   curses.COLOR_RED,     -1)
    curses.init_pair(CP_MILITARY,   curses.COLOR_RED,     -1)
    curses.init_pair(CP_AGE_PROSPERITY, curses.COLOR_GREEN,   -1)
    curses.init_pair(CP_AGE_DISRUPTION, curses.COLOR_RED,     -1)
    curses.init_pair(CP_AGE_RECOVERY,   curses.COLOR_CYAN,    -1)


# ═══════════════════════════════════════════════════════════════════
# Drawing helpers
# ═══════════════════════════════════════════════════════════════════
def _safe_addstr(win, y, x, text, attr=0):
    """Write text to window, silently ignoring out-of-bounds."""
    max_y, max_x = win.getmaxyx()
    if y < 0 or y >= max_y or x < 0:
        return
    avail = max_x - x
    if avail <= 0:
        return
    try:
        win.addnstr(y, x, text, avail, attr)
    except curses.error:
        pass


def _hbar(win, y, x, value, max_val, width, cp_fill, cp_empty=CP_BAR_EMPTY):
    """Draw a horizontal bar gauge."""
    max_y, max_x = win.getmaxyx()
    if y < 0 or y >= max_y:
        return
    ratio = max(0.0, min(1.0, value / max_val)) if max_val > 0 else 0.0
    filled = int(ratio * width)
    empty = width - filled
    _safe_addstr(win, y, x, "█" * filled, curses.color_pair(cp_fill))
    _safe_addstr(win, y, x + filled, "░" * empty, curses.color_pair(cp_empty))


def _section_header(win, y, x, title):
    """Draw a section header with underline."""
    _safe_addstr(win, y, x, title, curses.color_pair(CP_HEADER) | curses.A_BOLD | curses.A_UNDERLINE)
    return y + 1


# ═══════════════════════════════════════════════════════════════════
# Panel renderers — each returns the next free row
# ═══════════════════════════════════════════════════════════════════

def _draw_title_bar(win, y, engine, paused, tick_delay):
    max_y, max_x = win.getmaxyx()
    state = engine.state
    tick = state.sim_tick_count
    speed_str = f"{tick_delay:.1f}s/tick"
    pause_str = " [PAUSED]" if paused else ""

    # World age info
    age = getattr(state, "world_age", "")
    age_timer = getattr(state, "world_age_timer", 0)
    age_cycle = getattr(state, "world_age_cycle_count", 0)
    age_str = f"  │ {age} ({age_timer}t left · cycle #{age_cycle})" if age else ""

    title = f" GDTLancer — Tick {tick}  ({speed_str}){pause_str}{age_str} "
    bar_line = "═" * (max_x - 2)

    _safe_addstr(win, y, 0, "╔" + bar_line + "╗", curses.color_pair(CP_BOX) | curses.A_BOLD)
    _safe_addstr(win, y + 1, 0, "║", curses.color_pair(CP_BOX) | curses.A_BOLD)

    # Title text with age-colored segment
    base_title = f" GDTLancer — Tick {tick}  ({speed_str}){pause_str}"
    _safe_addstr(win, y + 1, 1, base_title, curses.color_pair(CP_TITLE) | curses.A_BOLD)
    if age:
        age_cp_map = {
            "PROSPERITY": CP_AGE_PROSPERITY,
            "DISRUPTION": CP_AGE_DISRUPTION,
            "RECOVERY":   CP_AGE_RECOVERY,
        }
        acp = age_cp_map.get(age, CP_TITLE)
        age_display = f"  │ {age} ({age_timer}t · cycle #{age_cycle})"
        _safe_addstr(win, y + 1, 1 + len(base_title), age_display,
                     curses.color_pair(acp) | curses.A_BOLD)

    _safe_addstr(win, y + 1, max_x - 1, "║", curses.color_pair(CP_BOX) | curses.A_BOLD)
    _safe_addstr(win, y + 2, 0, "╚" + bar_line + "╝", curses.color_pair(CP_BOX) | curses.A_BOLD)
    return y + 3


def _draw_sector_map(win, y, state):
    """Spatial: sector diamond with agent/hostile counts."""
    y = _section_header(win, y, 1, "SECTOR MAP")
    sectors = sorted(state.world_topology.keys())

    # Build agent-per-sector
    agent_in = {s: [] for s in sectors}
    for aid, ag in state.agents.items():
        sec = ag.get("current_sector_id", "")
        if sec in agent_in:
            char_uid = ag.get("char_uid", -1)
            char_data = state.characters.get(char_uid, {})
            nm = char_data.get("character_name", aid)[:4]
            disabled = ag.get("is_disabled", False)
            agent_in[sec].append((aid, nm, disabled))

    # Hostile per sector
    hostile_in = {}
    for htype, hdata in state.hostile_population_integral.items():
        for sid, cnt in hdata.get("sector_counts", {}).items():
            hostile_in[sid] = hostile_in.get(sid, 0) + cnt

    def _draw_sector_box(win, by, bx, sid):
        """Draw a single sector box returning rows used."""
        stype = state.world_topology[sid].get("sector_type", "?")
        tcp = CP_SECTOR_HUB if stype == "hub" else CP_SECTOR_FRT
        _safe_addstr(win, by, bx, _loc_short(sid), curses.color_pair(tcp) | curses.A_BOLD)
        _safe_addstr(win, by, bx + len(_loc_short(sid)), f" ({stype})", curses.color_pair(CP_DIM))

        ax = bx + 1
        for aid, nm, dis in agent_in.get(sid, []):
            if dis:
                _safe_addstr(win, by + 1, ax, "✖", curses.color_pair(CP_BAD))
            elif aid == "player":
                _safe_addstr(win, by + 1, ax, "▶", curses.color_pair(CP_PLAYER))
            else:
                _safe_addstr(win, by + 1, ax, "●", curses.color_pair(CP_CYAN))
            _safe_addstr(win, by + 1, ax + 1, nm + " ", curses.color_pair(CP_DEFAULT))
            ax += len(nm) + 2

        hc = hostile_in.get(sid, 0)
        if hc > 0:
            _safe_addstr(win, by + 2, bx + 1, f"☠×{hc}", curses.color_pair(CP_BAD))
        return 3

    if len(sectors) >= 4:
        # Diamond:  s0 top, s2 left, s1 right, s3 bottom
        s0, s1, s2, s3 = sectors[0], sectors[1], sectors[2], sectors[3]
        center_x = 22
        left_x = 2
        right_x = 42

        # Top sector (alpha)
        _draw_sector_box(win, y, center_x, s0)

        # Connection lines
        _safe_addstr(win, y + 3, center_x - 3, "/  |  \\", curses.color_pair(CP_DIM))

        # Middle sectors (gamma left, beta right)
        mid_y = y + 4
        _draw_sector_box(win, mid_y, left_x, s2)
        _safe_addstr(win, mid_y, center_x + 2, "|", curses.color_pair(CP_DIM))
        _draw_sector_box(win, mid_y, right_x, s1)

        # Connection lines
        _safe_addstr(win, mid_y + 3, center_x - 3, "\\  |  /", curses.color_pair(CP_DIM))

        # Bottom sector (delta)
        bot_y = mid_y + 4
        _draw_sector_box(win, bot_y, center_x, s3)

        return bot_y + 3

    elif len(sectors) >= 3:
        s0, s1, s2 = sectors[0], sectors[1], sectors[2]
        half_w = 38

        for idx, (sid, col_x) in enumerate([(s0, 2), (s1, half_w + 6)]):
            _draw_sector_box(win, y, col_x, sid)

        _safe_addstr(win, y, half_w, "────", curses.color_pair(CP_DIM))
        _safe_addstr(win, y + 3, 6, "\\", curses.color_pair(CP_DIM))
        _safe_addstr(win, y + 3, half_w + 3, "/", curses.color_pair(CP_DIM))

        cy = y + 4
        _draw_sector_box(win, cy, 18, s2)
        return cy + 3
    else:
        for sid in sectors:
            _safe_addstr(win, y, 2, f"{_loc_short(sid)}", curses.color_pair(CP_HEADER) | curses.A_BOLD)
            y += 1
        return y


def _draw_stockpiles(win, y, state, col_x=1, col_w=20):
    """Compact stockpile bars for all sectors side by side."""
    sectors = sorted(state.world_topology.keys())
    y = _section_header(win, y, col_x, "STOCKPILES")

    for si, sid in enumerate(sectors):
        sx = col_x + si * col_w
        stockpile = state.grid_stockpiles.get(sid, {})
        commodities = stockpile.get("commodity_stockpiles", {})
        capacity = stockpile.get("stockpile_capacity", 1000)
        total = sum(commodities.values())

        stype = state.world_topology[sid].get("sector_type", "?")
        tcp = CP_SECTOR_HUB if stype == "hub" else CP_SECTOR_FRT
        _safe_addstr(win, y, sx, _loc_short(sid), curses.color_pair(tcp) | curses.A_BOLD)
        _safe_addstr(win, y, sx + len(_loc_short(sid)) + 1, f"{total:.0f}/{capacity}", curses.color_pair(CP_DIM))

        row = y + 1
        for cid in sorted(commodities.keys()):
            qty = commodities[cid]
            short = _short_commodity(cid)
            cp = COMMODITY_CP.get(cid, CP_DEFAULT)
            _safe_addstr(win, row, sx, short, curses.color_pair(cp))
            _hbar(win, row, sx + 4, qty, capacity * 0.4, 7, cp)
            _safe_addstr(win, row, sx + 12, f"{qty:5.0f}", curses.color_pair(CP_DIM))
            row += 1

    max_rows = max(
        len(state.grid_stockpiles.get(sid, {}).get("commodity_stockpiles", {}))
        for sid in sectors
    ) if sectors else 0
    return y + 1 + max_rows


def _draw_resource_potential(win, y, state, col_x=1):
    """Resource potential remaining per sector."""
    sectors = sorted(state.world_topology.keys())
    y = _section_header(win, y, col_x, "RESOURCE POTENTIAL")

    for sid in sectors:
        pot = state.world_resource_potential.get(sid, {})
        mineral = pot.get("mineral_density", 0.0)
        propellant = pot.get("propellant_sources", 0.0)

        stype = state.world_topology[sid].get("sector_type", "?")
        tcp = CP_SECTOR_HUB if stype == "hub" else CP_SECTOR_FRT
        _safe_addstr(win, y, col_x, _loc_short(sid), curses.color_pair(tcp) | curses.A_BOLD)

        _safe_addstr(win, y, col_x + 7, "MIN", curses.color_pair(CP_ORE))
        _hbar(win, y, col_x + 11, mineral, 300.0, 8, CP_ORE)
        _safe_addstr(win, y, col_x + 20, f"{mineral:6.1f}", curses.color_pair(CP_DIM))

        _safe_addstr(win, y, col_x + 28, "PRP", curses.color_pair(CP_FUEL))
        _hbar(win, y, col_x + 32, propellant, 300.0, 8, CP_FUEL)
        _safe_addstr(win, y, col_x + 41, f"{propellant:6.1f}", curses.color_pair(CP_DIM))

        y += 1
    return y


def _draw_dominion(win, y, state, col_x=1, col_w=26):
    """Faction influence + security + piracy per sector, side by side."""
    sectors = sorted(state.world_topology.keys())
    y = _section_header(win, y, col_x, "DOMINION & SECURITY")

    max_rows = 0
    for si, sid in enumerate(sectors):
        sx = col_x + si * col_w
        dominion = state.grid_dominion.get(sid, {})
        faction_inf = dominion.get("faction_influence", {})
        security = dominion.get("security_level", 0.0)
        piracy = dominion.get("pirate_activity", 0.0)

        stype = state.world_topology[sid].get("sector_type", "?")
        tcp = CP_SECTOR_HUB if stype == "hub" else CP_SECTOR_FRT
        _safe_addstr(win, y, sx, _loc_short(sid), curses.color_pair(tcp) | curses.A_BOLD)

        row = y + 1
        for fid in sorted(faction_inf.keys()):
            val = faction_inf[fid]
            short = _short_faction(fid)
            cp = FACTION_CP.get(fid, CP_DEFAULT)
            _safe_addstr(win, row, sx, short, curses.color_pair(cp))
            _hbar(win, row, sx + 4, val, 1.0, 8, cp)
            _safe_addstr(win, row, sx + 13, f"{val:.2f}", curses.color_pair(CP_DIM))
            row += 1

        sec_cp = CP_GOOD if security > 0.5 else (CP_WARN if security > 0.2 else CP_BAD)
        _safe_addstr(win, row, sx, "SEC", curses.color_pair(CP_DIM))
        _hbar(win, row, sx + 4, security, 1.0, 8, sec_cp)
        _safe_addstr(win, row, sx + 13, f"{security:.2f}", curses.color_pair(sec_cp))
        row += 1

        pir_cp = CP_BAD if piracy > 0.5 else (CP_WARN if piracy > 0.2 else CP_GOOD)
        _safe_addstr(win, row, sx, "PIR", curses.color_pair(CP_DIM))
        _hbar(win, row, sx + 4, piracy, 1.0, 8, pir_cp)
        _safe_addstr(win, row, sx + 13, f"{piracy:.2f}", curses.color_pair(pir_cp))
        row += 1

        rows_used = row - y
        if rows_used > max_rows:
            max_rows = rows_used

    return y + max_rows


def _draw_market(win, y, state, col_x=1, col_w=20):
    """Compact price deltas per sector, side by side."""
    sectors = sorted(state.world_topology.keys())
    y = _section_header(win, y, col_x, "MARKET (price deltas)")

    max_rows = 0
    for si, sid in enumerate(sectors):
        sx = col_x + si * col_w
        market = state.grid_market.get(sid, {})
        price_deltas = market.get("commodity_price_deltas", {})
        svc = market.get("service_cost_modifier", 1.0)

        stype = state.world_topology[sid].get("sector_type", "?")
        tcp = CP_SECTOR_HUB if stype == "hub" else CP_SECTOR_FRT
        _safe_addstr(win, y, sx, _loc_short(sid), curses.color_pair(tcp) | curses.A_BOLD)
        _safe_addstr(win, y, sx + len(_loc_short(sid)) + 1, f"svc={svc:.2f}", curses.color_pair(CP_DIM))

        row = y + 1
        for cid in sorted(price_deltas.keys()):
            delta = price_deltas[cid]
            short = _short_commodity(cid)
            cp = COMMODITY_CP.get(cid, CP_DEFAULT)
            sign = "+" if delta >= 0 else ""
            delta_cp = CP_GOOD if delta > 0 else (CP_BAD if delta < -0.05 else CP_DIM)
            _safe_addstr(win, row, sx, short, curses.color_pair(cp))
            _safe_addstr(win, row, sx + 4, f"{sign}{delta:+.3f}", curses.color_pair(delta_cp))
            row += 1

        rows_used = row - y
        if rows_used > max_rows:
            max_rows = rows_used

    return y + max_rows


def _draw_agents(win, y, state):
    """Agent list: name, sector, hull bar, cash, goal, cargo."""
    y = _section_header(win, y, 1, "AGENTS")

    for agent_id in sorted(state.agents.keys()):
        agent = state.agents[agent_id]
        char_uid = agent.get("char_uid", -1)
        char_data = state.characters.get(char_uid, {})
        name = char_data.get("character_name", agent_id)
        sector = agent.get("current_sector_id", "?")
        hull = agent.get("hull_integrity", 0.0)
        cash = agent.get("cash_reserves", 0.0)
        goal = agent.get("goal_archetype", "?")
        disabled = agent.get("is_disabled", False)
        propellant = agent.get("propellant_reserves", 0.0)

        # Name (8 chars)
        if agent_id == "player":
            _safe_addstr(win, y, 1, "▶", curses.color_pair(CP_PLAYER))
            _safe_addstr(win, y, 2, f"{name[:7]:7s}", curses.color_pair(CP_PLAYER) | curses.A_BOLD)
        elif disabled:
            _safe_addstr(win, y, 1, "✖", curses.color_pair(CP_BAD))
            _safe_addstr(win, y, 2, f"{name[:7]:7s}", curses.color_pair(CP_BAD))
        else:
            _safe_addstr(win, y, 1, "●", curses.color_pair(CP_CYAN))
            _safe_addstr(win, y, 2, f"{name[:7]:7s}", curses.color_pair(CP_CYAN))

        # Sector (7 chars)
        sec_short = _loc_short(sector)[:5]
        _safe_addstr(win, y, 10, f"@{sec_short:5s}", curses.color_pair(CP_DIM))

        # Hull bar (8 wide)
        hull_cp = CP_GOOD if hull > 0.7 else (CP_WARN if hull > 0.3 else CP_BAD)
        _hbar(win, y, 17, hull, 1.0, 6, hull_cp)
        _safe_addstr(win, y, 24, f"{hull:.2f}", curses.color_pair(hull_cp))

        # Cash
        cash_cp = CP_CASH_HIGH if cash > 2000 else (CP_CASH_MID if cash > 500 else CP_CASH_LOW)
        _safe_addstr(win, y, 30, f"${cash:>6.0f}", curses.color_pair(cash_cp))

        # Goal
        goal_cp = CP_WARN if goal == "trade" else (CP_BAD if goal == "repair" else CP_DIM)
        _safe_addstr(win, y, 38, f"[{goal:6s}]", curses.color_pair(goal_cp))

        # Propellant
        prop_cp = CP_GOOD if propellant > 50 else (CP_WARN if propellant > 10 else CP_BAD)
        _safe_addstr(win, y, 47, f"P:{propellant:4.0f}", curses.color_pair(prop_cp))

        # Cargo (compact)
        cargo_str = ""
        if char_uid in state.inventories and 2 in state.inventories[char_uid]:
            inv = state.inventories[char_uid][2]
            parts = []
            for cid, qty in sorted(inv.items()):
                if qty > 0:
                    parts.append(f"{_short_commodity(cid)}={qty:.0f}")
            cargo_str = " ".join(parts)
        if cargo_str:
            _safe_addstr(win, y, 54, cargo_str[:25], curses.color_pair(CP_DIM))

        y += 1

    return y


def _draw_hostiles(win, y, state):
    """Hostile population summary."""
    y = _section_header(win, y, 1, "HOSTILES")
    sectors = sorted(state.world_topology.keys())

    for htype, hdata in state.hostile_population_integral.items():
        count = hdata.get("current_count", 0)
        capacity = hdata.get("carrying_capacity", 0)
        sector_counts = hdata.get("sector_counts", {})

        _safe_addstr(win, y, 1, f"{htype}", curses.color_pair(CP_BAD) | curses.A_BOLD)
        _hbar(win, y, 10, count, max(capacity, 1), 8, CP_BAD)
        _safe_addstr(win, y, 19, f"{count}/{capacity}", curses.color_pair(CP_DIM))
        y += 1

        # Per-sector distribution
        dist_parts = []
        for sid in sectors:
            cnt = sector_counts.get(sid, 0)
            sname = _loc_short(sid)[:3]
            dist_parts.append(f"{sname}:{cnt}")
        _safe_addstr(win, y, 3, "  ".join(dist_parts), curses.color_pair(CP_DIM))
        y += 1

    return y


def _draw_matter_conservation(win, y, engine):
    """Axiom 1 check."""
    state = engine.state
    actual = engine._calculate_total_matter()
    expected = state.world_total_matter
    drift = abs(actual - expected)
    tol = engine._tick_config.get("axiom1_tolerance", 0.01)
    ok = drift <= tol

    y = _section_header(win, y, 1, "AXIOM 1  (matter conservation)")

    bd = engine._matter_breakdown()

    if ok:
        _safe_addstr(win, y, 1, "✓ PASS", curses.color_pair(CP_AXIOM_OK) | curses.A_BOLD)
    else:
        _safe_addstr(win, y, 1, "✗ FAIL", curses.color_pair(CP_AXIOM_FAIL) | curses.A_BOLD)

    _safe_addstr(win, y, 8, f"drift={drift:.6f}", curses.color_pair(CP_DIM))
    _safe_addstr(win, y, 25, f"expected={expected:.1f}  actual={actual:.1f}", curses.color_pair(CP_DIM))
    y += 1

    labels = [
        ("res_pot",   bd["resource_potential"],  CP_ORE),
        ("stockpile", bd["grid_stockpiles"],     CP_FUEL),
        ("wrecks",    bd["wrecks"],              CP_BAD),
        ("agent_inv", bd["agent_inventories"],   CP_GOOD),
    ]
    for label, val, cp in labels:
        pct = (val / actual * 100) if actual > 0 else 0
        _safe_addstr(win, y, 1, f"{label:10s}", curses.color_pair(CP_DIM))
        _hbar(win, y, 12, val, actual, 20, cp)
        _safe_addstr(win, y, 33, f"{val:8.1f} ({pct:4.1f}%)", curses.color_pair(CP_DIM))
        y += 1

    return y


def _draw_chronicle(win, y, state, max_lines=6):
    """Recent chronicle rumors."""
    total = len(state.chronicle_rumors)
    y = _section_header(win, y, 1, f"CHRONICLE ({total} rumors)")

    recent = state.chronicle_rumors[-max_lines:]
    if not recent:
        _safe_addstr(win, y, 3, "(no rumors yet)", curses.color_pair(CP_DIM))
        y += 1
    else:
        for rumor in recent:
            _safe_addstr(win, y, 2, "▸", curses.color_pair(CP_CHRONICLE))
            _safe_addstr(win, y, 4, str(rumor)[:75], curses.color_pair(CP_DEFAULT))
            y += 1
    return y


def _draw_help_bar(win, y):
    """Bottom help bar."""
    max_y, max_x = win.getmaxyx()
    y = max_y - 1
    help_text = " q:Quit  SPACE:Pause  +/-:Speed  r:Restart "
    _safe_addstr(win, y, 0, help_text.center(max_x), curses.color_pair(CP_DIM))
    return y


# ═══════════════════════════════════════════════════════════════════
# Main TUI loop
# ═══════════════════════════════════════════════════════════════════
def run_tui(seed: str = "default_seed", max_ticks: int = 0):
    """Launch the ncurses TUI. max_ticks=0 means run forever."""

    def _main(stdscr):
        _init_colors()
        curses.curs_set(0)          # hide cursor
        stdscr.nodelay(True)        # non-blocking getch
        stdscr.timeout(50)          # 50ms polling

        engine = SimulationEngine()

        # Suppress print noise during init
        import builtins
        _orig_print = builtins.print
        def _quiet(*a, **kw):
            pass
        builtins.print = _quiet
        engine.initialize_simulation(seed)
        builtins.print = _orig_print

        paused = False
        tick_delay = 1.0   # seconds per tick
        last_tick_time = time.time()
        ticks_run = 0

        while True:
            # --- Input ---
            ch = stdscr.getch()
            if ch == ord('q') or ch == 27:  # q or ESC
                break
            elif ch == ord(' '):
                paused = not paused
            elif ch == ord('+') or ch == ord('='):
                tick_delay = max(0.1, tick_delay - 0.1)
            elif ch == ord('-') or ch == ord('_'):
                tick_delay = min(5.0, tick_delay + 0.1)
            elif ch == ord('r'):
                builtins.print = _quiet
                engine = SimulationEngine()
                engine.initialize_simulation(seed)
                builtins.print = _orig_print
                ticks_run = 0
                paused = False
                last_tick_time = time.time()

            # --- Tick ---
            now = time.time()
            if not paused and (now - last_tick_time) >= tick_delay:
                if max_ticks == 0 or ticks_run < max_ticks:
                    builtins.print = _quiet
                    engine.process_tick()
                    builtins.print = _orig_print
                    ticks_run += 1
                    last_tick_time = now

            # --- Render ---
            stdscr.erase()
            max_y, max_x = stdscr.getmaxyx()

            row = 0
            row = _draw_title_bar(stdscr, row, engine, paused, tick_delay)

            # Decide layout based on terminal height
            # We need ~55 rows for everything; if terminal is smaller, compress
            row = _draw_sector_map(stdscr, row, engine.state)
            row += 1

            row = _draw_stockpiles(stdscr, row, engine.state)
            row += 1

            row = _draw_resource_potential(stdscr, row, engine.state)
            row += 1

            row = _draw_dominion(stdscr, row, engine.state)
            row += 1

            row = _draw_market(stdscr, row, engine.state)
            row += 1

            row = _draw_agents(stdscr, row, engine.state)
            row += 1

            row = _draw_hostiles(stdscr, row, engine.state)
            row += 1

            row = _draw_matter_conservation(stdscr, row, engine)
            row += 1

            # Chronicle: fill remaining space
            remaining = max_y - row - 2  # reserve 1 for help bar
            chronicle_lines = max(3, remaining)
            row = _draw_chronicle(stdscr, row, engine.state, max_lines=chronicle_lines)

            _draw_help_bar(stdscr, row)

            stdscr.noutrefresh()
            curses.doupdate()

    curses.wrapper(_main)


# ═══════════════════════════════════════════════════════════════════
# CLI entry point (can be run standalone)
# ═══════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="GDTLancer ncurses TUI")
    parser.add_argument("--seed", type=str, default="default_seed", help="World seed")
    parser.add_argument("--ticks", type=int, default=0, help="Max ticks (0=infinite)")
    args = parser.parse_args()
    run_tui(seed=args.seed, max_ticks=args.ticks)
