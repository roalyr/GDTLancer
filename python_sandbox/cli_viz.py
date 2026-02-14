"""
GDTLancer CLI Visualization — colored terminal display of simulation state.

Renders the simulation layers as compact visual dashboards:
  - Sector topology map with connections
  - Stockpile bar charts per sector
  - Dominion / faction influence heat strip
  - Piracy & security gauges
  - Agent positions and status
  - Hostile population distribution
  - Matter conservation tracker
  - Chronicle rumor feed

Uses ANSI escape codes for color. No external dependencies.
"""

import os
import sys
import shutil

# =========================================================================
# === ANSI COLOR HELPERS ==================================================
# =========================================================================

# Basic colors
RESET   = "\033[0m"
BOLD    = "\033[1m"
DIM     = "\033[2m"
UNDERLINE = "\033[4m"

# Foreground
BLACK   = "\033[30m"
RED     = "\033[31m"
GREEN   = "\033[32m"
YELLOW  = "\033[33m"
BLUE    = "\033[34m"
MAGENTA = "\033[35m"
CYAN    = "\033[36m"
WHITE   = "\033[37m"

# Bright foreground
BRED    = "\033[91m"
BGREEN  = "\033[92m"
BYELLOW = "\033[93m"
BBLUE   = "\033[94m"
BMAGENTA= "\033[95m"
BCYAN   = "\033[96m"
BWHITE  = "\033[97m"

# Background
BG_BLACK   = "\033[40m"
BG_RED     = "\033[41m"
BG_GREEN   = "\033[42m"
BG_YELLOW  = "\033[43m"
BG_BLUE    = "\033[44m"
BG_MAGENTA = "\033[45m"
BG_CYAN    = "\033[46m"
BG_WHITE   = "\033[47m"
BG_GRAY    = "\033[100m"

# 256-color helpers
def fg256(n: int) -> str:
    return f"\033[38;5;{n}m"

def bg256(n: int) -> str:
    return f"\033[48;5;{n}m"


def strip_ansi(s: str) -> str:
    """Remove ANSI escape sequences to get visible length."""
    import re
    return re.sub(r'\033\[[0-9;]*m', '', s)


def visible_len(s: str) -> int:
    return len(strip_ansi(s))


def pad_right(s: str, width: int) -> str:
    """Pad string to width accounting for ANSI codes."""
    vl = visible_len(s)
    if vl >= width:
        return s
    return s + " " * (width - vl)


# =========================================================================
# === BAR RENDERING =======================================================
# =========================================================================

def bar(value: float, max_val: float, width: int = 20,
        fill_color: str = GREEN, empty_color: str = DIM,
        char_fill: str = "█", char_empty: str = "░") -> str:
    """Render a colored progress bar."""
    if max_val <= 0:
        ratio = 0.0
    else:
        ratio = max(0.0, min(1.0, value / max_val))
    filled = int(ratio * width)
    empty = width - filled
    return f"{fill_color}{char_fill * filled}{empty_color}{char_empty * empty}{RESET}"


def bar_diverging(value: float, width: int = 20,
                  pos_color: str = GREEN, neg_color: str = RED) -> str:
    """Render a diverging bar for values in [-1, 1] range."""
    half = width // 2
    clamped = max(-1.0, min(1.0, value))
    if clamped >= 0:
        filled = int(clamped * half)
        return (f"{DIM}{'░' * half}{RESET}"
                f"{pos_color}{'█' * filled}{RESET}"
                f"{DIM}{'░' * (half - filled)}{RESET}")
    else:
        filled = int(abs(clamped) * half)
        return (f"{DIM}{'░' * (half - filled)}{RESET}"
                f"{neg_color}{'█' * filled}{RESET}"
                f"{DIM}{'░' * half}{RESET}")


def spark_line(values: list, width: int = 0) -> str:
    """Render a spark line from a list of values."""
    if not values:
        return ""
    blocks = " ▁▂▃▄▅▆▇█"
    mn = min(values)
    mx = max(values)
    rng = mx - mn if mx != mn else 1.0
    result = ""
    for v in values:
        idx = int(((v - mn) / rng) * (len(blocks) - 1))
        result += blocks[idx]
    return result


# =========================================================================
# === COMMODITY / FACTION DISPLAY HELPERS =================================
# =========================================================================

COMMODITY_COLORS = {
    "commodity_ore":    fg256(208),   # orange
    "commodity_fuel":   fg256(39),    # blue
    "commodity_food":   fg256(82),    # green
    "commodity_tech":   fg256(141),   # purple
    "commodity_luxury": fg256(220),   # gold
}

COMMODITY_ICONS = {
    "commodity_ore":    "*",
    "commodity_fuel":   "~",
    "commodity_food":   "#",
    "commodity_tech":   "+",
    "commodity_luxury": "$",
}

COMMODITY_SHORT = {
    "commodity_ore":    "ORE",
    "commodity_fuel":   "FUL",
    "commodity_food":   "FOD",
    "commodity_tech":   "TEC",
    "commodity_luxury": "LUX",
}

FACTION_COLORS = {
    "faction_miners":       fg256(208),   # orange
    "faction_traders":      fg256(39),    # blue
    "faction_independents": fg256(82),    # green
}

FACTION_SHORT = {
    "faction_miners":       "MIN",
    "faction_traders":      "TRD",
    "faction_independents": "IND",
}

SECTOR_TYPE_COLORS = {
    "hub":      BCYAN,
    "frontier": BYELLOW,
}


def _short_commodity(cid: str) -> str:
    return COMMODITY_SHORT.get(cid, cid.replace("commodity_", "")[:3].upper())


def _color_commodity(cid: str, text: str) -> str:
    color = COMMODITY_COLORS.get(cid, WHITE)
    return f"{color}{text}{RESET}"


def _short_faction(fid: str) -> str:
    return FACTION_SHORT.get(fid, fid.replace("faction_", "")[:3].upper())


def _color_faction(fid: str, text: str) -> str:
    color = FACTION_COLORS.get(fid, WHITE)
    return f"{color}{text}{RESET}"


# =========================================================================
# === SECTOR MAP ==========================================================
# =========================================================================

def render_sector_map(state) -> list:
    """Render a text-art sector topology map with connections."""
    lines = []
    sectors = sorted(state.world_topology.keys())

    if len(sectors) == 3:
        # Hardcoded triangle layout for 3 sectors
        # (alpha) ---- (beta)
        #      \      /
        #      (gamma)
        names = {}
        types = {}
        for sid in sectors:
            loc_name = sid.replace("station_", "").upper()
            stype = state.world_topology[sid].get("sector_type", "?")
            tc = SECTOR_TYPE_COLORS.get(stype, WHITE)
            names[sid] = f"{tc}{BOLD}{loc_name}{RESET}"
            types[sid] = f"{DIM}({stype}){RESET}"

        # Count agents per sector
        agent_counts = {}
        for sid in sectors:
            agent_counts[sid] = []
        for aid, agent in state.agents.items():
            sec = agent.get("current_sector_id", "")
            if sec in agent_counts:
                disabled = agent.get("is_disabled", False)
                char_uid = agent.get("char_uid", -1)
                char_data = state.characters.get(char_uid, {})
                name = char_data.get("character_name", aid)[:4]
                if disabled:
                    agent_counts[sec].append(f"{RED}✖{name}{RESET}")
                elif aid == "player":
                    agent_counts[sec].append(f"{BGREEN}▶{name}{RESET}")
                else:
                    agent_counts[sec].append(f"{CYAN}●{name}{RESET}")

        # Hostile counts
        hostile_counts = {}
        for htype, hdata in state.hostile_population_integral.items():
            for sid, cnt in hdata.get("sector_counts", {}).items():
                hostile_counts[sid] = hostile_counts.get(sid, 0) + cnt

        s0, s1, s2 = sectors[0], sectors[1], sectors[2]

        w = 28  # box width

        def sector_box(sid):
            box_lines = []
            stype = state.world_topology[sid].get("sector_type", "?")
            tc = SECTOR_TYPE_COLORS.get(stype, WHITE)
            loc_name = sid.replace("station_", "").upper()

            header = f" {tc}{BOLD}{loc_name}{RESET} {DIM}({stype}){RESET}"
            box_lines.append(header)

            # Agents in this sector
            agents_here = agent_counts.get(sid, [])
            if agents_here:
                box_lines.append(f"  {DIM}agents:{RESET} " + " ".join(agents_here))
            else:
                box_lines.append(f"  {DIM}agents: (none){RESET}")

            # Hostiles
            hc = hostile_counts.get(sid, 0)
            if hc > 0:
                box_lines.append(f"  {RED}hostiles: {hc}{RESET}")

            return box_lines

        box0 = sector_box(s0)
        box1 = sector_box(s1)
        box2 = sector_box(s2)

        lines.append(f"  {BOLD}{UNDERLINE}SECTOR MAP{RESET}")
        lines.append("")

        # Render side by side: s0 and s1
        max_height = max(len(box0), len(box1))
        for i in range(max_height):
            left = box0[i] if i < len(box0) else ""
            right = box1[i] if i < len(box1) else ""
            left_padded = pad_right(left, 35)
            conn_str = f"{DIM}────{RESET}" if i == 0 else "    "
            lines.append(f"  {left_padded} {conn_str}  {right}")

        # Connection lines down to s2
        lines.append(f"  {DIM}    \\                             /{RESET}")
        lines.append(f"  {DIM}     \\                           /{RESET}")
        lines.append(f"  {DIM}      \\                         /{RESET}")

        # Center box for s2
        for bline in box2:
            lines.append(f"                  {bline}")
        lines.append("")

    else:
        # Generic list fallback
        lines.append(f"  {BOLD}{UNDERLINE}SECTOR MAP{RESET}")
        for sid in sectors:
            topology = state.world_topology[sid]
            stype = topology.get("sector_type", "?")
            conns = topology.get("connections", [])
            tc = SECTOR_TYPE_COLORS.get(stype, WHITE)
            conn_str = ", ".join(c.replace("station_", "") for c in conns)
            lines.append(f"  {tc}{BOLD}{sid}{RESET} ({stype}) → [{conn_str}]")
        lines.append("")

    return lines


# =========================================================================
# === STOCKPILE VISUALIZATION =============================================
# =========================================================================

def render_stockpiles(state) -> list:
    """Render per-sector stockpile bar charts."""
    lines = []
    lines.append(f"  {BOLD}{UNDERLINE}STOCKPILES{RESET}  {DIM}(extracted commodities per sector){RESET}")
    lines.append("")

    for sector_id in sorted(state.world_topology.keys()):
        stockpile = state.grid_stockpiles.get(sector_id, {})
        commodities = stockpile.get("commodity_stockpiles", {})
        capacity = stockpile.get("stockpile_capacity", 1000)

        loc_short = sector_id.replace("station_", "").upper()
        stype = state.world_topology[sector_id].get("sector_type", "?")
        tc = SECTOR_TYPE_COLORS.get(stype, WHITE)
        lines.append(f"  {tc}{BOLD}{loc_short}{RESET}")

        total = sum(commodities.values())
        lines.append(f"    {DIM}capacity:{RESET} {bar(total, capacity, 30, BBLUE)} "
                      f"{total:.0f}/{capacity}")

        for cid in sorted(commodities.keys()):
            qty = commodities[cid]
            short = _short_commodity(cid)
            color = COMMODITY_COLORS.get(cid, WHITE)
            b = bar(qty, capacity * 0.5, 20, color)
            lines.append(f"    {color}{short}{RESET} {b} {qty:.0f}")

        lines.append("")

    return lines


# =========================================================================
# === RESOURCE POTENTIAL ==================================================
# =========================================================================

def render_resource_potential(state) -> list:
    """Render remaining resource potential per sector."""
    lines = []
    lines.append(f"  {BOLD}{UNDERLINE}RESOURCE POTENTIAL{RESET}  {DIM}(finite, depletes via extraction){RESET}")
    lines.append("")

    for sector_id in sorted(state.world_topology.keys()):
        potential = state.world_resource_potential.get(sector_id, {})
        mineral = potential.get("mineral_density", 0.0)
        propellant = potential.get("propellant_sources", 0.0)

        loc_short = sector_id.replace("station_", "").upper()
        stype = state.world_topology[sector_id].get("sector_type", "?")
        tc = SECTOR_TYPE_COLORS.get(stype, WHITE)

        # Use 300 as a reference max (initial values are ~50-200 range)
        m_bar = bar(mineral, 300.0, 20, fg256(208))
        p_bar = bar(propellant, 300.0, 20, fg256(39))

        lines.append(f"  {tc}{BOLD}{loc_short}{RESET}  "
                      f"{fg256(208)}MIN{RESET} {m_bar} {mineral:.1f}  "
                      f"{fg256(39)}PRP{RESET} {p_bar} {propellant:.1f}")

    lines.append("")
    return lines


# =========================================================================
# === DOMINION / FACTION INFLUENCE ========================================
# =========================================================================

def render_dominion(state) -> list:
    """Render faction influence, security, and piracy per sector."""
    lines = []
    lines.append(f"  {BOLD}{UNDERLINE}DOMINION & SECURITY{RESET}  {DIM}(CA: faction influence → security → piracy){RESET}")
    lines.append("")

    for sector_id in sorted(state.world_topology.keys()):
        dominion = state.grid_dominion.get(sector_id, {})
        faction_inf = dominion.get("faction_influence", {})
        security = dominion.get("security_level", 0.0)
        piracy = dominion.get("pirate_activity", 0.0)

        loc_short = sector_id.replace("station_", "").upper()
        stype = state.world_topology[sector_id].get("sector_type", "?")
        tc = SECTOR_TYPE_COLORS.get(stype, WHITE)

        lines.append(f"  {tc}{BOLD}{loc_short}{RESET}")

        # Faction influence bars
        for fid in sorted(faction_inf.keys()):
            val = faction_inf[fid]
            short = _short_faction(fid)
            color = FACTION_COLORS.get(fid, WHITE)
            b = bar(val, 1.0, 15, color)
            lines.append(f"    {color}{short}{RESET} {b} {val:.3f}")

        # Security gauge
        sec_color = BGREEN if security > 0.5 else (YELLOW if security > 0.2 else RED)
        sec_bar = bar(security, 1.0, 15, sec_color)
        lines.append(f"    {DIM}SEC{RESET} {sec_bar} {sec_color}{security:.3f}{RESET}")

        # Piracy gauge
        pir_color = RED if piracy > 0.5 else (YELLOW if piracy > 0.2 else GREEN)
        pir_bar = bar(piracy, 1.0, 15, pir_color, char_fill="▓")
        lines.append(f"    {DIM}PIR{RESET} {pir_bar} {pir_color}{piracy:.3f}{RESET}")

        lines.append("")

    return lines


# =========================================================================
# === MARKET PRICES =======================================================
# =========================================================================

def render_market(state) -> list:
    """Render commodity price deltas per sector."""
    lines = []
    lines.append(f"  {BOLD}{UNDERLINE}MARKET PRESSURE{RESET}  {DIM}(price delta: +surplus / -scarcity){RESET}")
    lines.append("")

    for sector_id in sorted(state.world_topology.keys()):
        market = state.grid_market.get(sector_id, {})
        price_deltas = market.get("commodity_price_deltas", {})
        service_mod = market.get("service_cost_modifier", 1.0)

        loc_short = sector_id.replace("station_", "").upper()
        stype = state.world_topology[sector_id].get("sector_type", "?")
        tc = SECTOR_TYPE_COLORS.get(stype, WHITE)

        lines.append(f"  {tc}{BOLD}{loc_short}{RESET}  {DIM}svc_mod={service_mod:.2f}{RESET}")

        for cid in sorted(price_deltas.keys()):
            delta = price_deltas[cid]
            short = _short_commodity(cid)
            color = COMMODITY_COLORS.get(cid, WHITE)
            # Show diverging bar
            # Clamp delta to reasonable range for display
            display_val = max(-1.0, min(1.0, delta * 10.0))
            dbar = bar_diverging(display_val, 20,
                                 pos_color=GREEN, neg_color=RED)
            sign = "+" if delta >= 0 else ""
            lines.append(f"    {color}{short}{RESET} {dbar} {sign}{delta:.4f}")

        lines.append("")

    return lines


# =========================================================================
# === AGENTS ==============================================================
# =========================================================================

def render_agents(state) -> list:
    """Render agent status with colored health/cash gauges."""
    lines = []
    lines.append(f"  {BOLD}{UNDERLINE}AGENTS{RESET}")
    lines.append("")

    for agent_id in sorted(state.agents.keys()):
        agent = state.agents[agent_id]
        char_uid = agent.get("char_uid", -1)
        char_data = state.characters.get(char_uid, {})
        name = char_data.get("character_name", f"UID:{char_uid}")
        sector = agent.get("current_sector_id", "?")
        hull = agent.get("hull_integrity", 0.0)
        cash = agent.get("cash_reserves", 0.0)
        goal = agent.get("goal_archetype", "?")
        disabled = agent.get("is_disabled", False)
        heat = agent.get("current_heat_level", 0.0)

        sec_short = sector.replace("station_", "").upper()

        # Name styling
        if agent_id == "player":
            name_str = f"{BGREEN}{BOLD}▶ {name}{RESET}"
        elif disabled:
            name_str = f"{RED}✖ {name}{RESET}"
        else:
            name_str = f"{CYAN}● {name}{RESET}"

        # Hull bar
        hull_color = BGREEN if hull > 0.7 else (YELLOW if hull > 0.3 else RED)
        hull_bar = bar(hull, 1.0, 10, hull_color)

        # Goal styling
        goal_colors = {
            "trade": BYELLOW,
            "repair": RED,
            "idle": DIM,
        }
        goal_color = goal_colors.get(goal, WHITE)

        # Cash
        cash_color = BGREEN if cash > 2000 else (YELLOW if cash > 500 else RED)

        lines.append(
            f"  {pad_right(name_str, 22)} "
            f"{DIM}@{RESET}{BCYAN}{sec_short:6s}{RESET} "
            f"hull {hull_bar} {hull_color}{hull:.2f}{RESET}  "
            f"{cash_color}${cash:.0f}{RESET}  "
            f"{goal_color}[{goal}]{RESET}"
        )

        # Inventory
        if char_uid in state.inventories and 2 in state.inventories[char_uid]:
            inv = state.inventories[char_uid][2]
            cargo_items = [(k, v) for k, v in inv.items() if v > 0]
            if cargo_items:
                cargo_parts = []
                for cid, qty in sorted(cargo_items):
                    color = COMMODITY_COLORS.get(cid, WHITE)
                    short = _short_commodity(cid)
                    cargo_parts.append(f"{color}{short}={qty:.0f}{RESET}")
                lines.append(f"  {' ' * 16} {DIM}cargo:{RESET} {', '.join(cargo_parts)}")

    lines.append("")
    return lines


# =========================================================================
# === HOSTILE POPULATION ==================================================
# =========================================================================

def render_hostiles(state) -> list:
    """Render hostile population with per-sector distribution bars."""
    lines = []
    lines.append(f"  {BOLD}{UNDERLINE}HOSTILE POPULATION{RESET}")
    lines.append("")

    sectors = sorted(state.world_topology.keys())

    for htype, hdata in state.hostile_population_integral.items():
        count = hdata.get("current_count", 0)
        capacity = hdata.get("carrying_capacity", 0)
        sector_counts = hdata.get("sector_counts", {})

        pop_bar = bar(count, max(capacity, 1), 15, RED)
        lines.append(f"  {RED}{BOLD}{htype}{RESET}  {pop_bar} {count}/{capacity}")

        for sid in sectors:
            cnt = sector_counts.get(sid, 0)
            loc_short = sid.replace("station_", "").upper()
            skull_str = f"{RED}☠{RESET}" * min(cnt, 20)
            if cnt == 0:
                skull_str = f"{DIM}—{RESET}"
            lines.append(f"    {loc_short:8s} {skull_str}  ({cnt})")

    lines.append("")
    return lines


# =========================================================================
# === MATTER CONSERVATION =================================================
# =========================================================================

def render_matter_conservation(engine) -> list:
    """Render the Axiom 1 matter conservation check."""
    lines = []
    s = engine.state
    actual = engine._calculate_total_matter()
    expected = s.world_total_matter
    drift = abs(actual - expected)
    tolerance = engine._tick_config.get("axiom1_tolerance", 0.01)
    ok = drift <= tolerance

    bd = engine._matter_breakdown()

    lines.append(f"  {BOLD}{UNDERLINE}MATTER CONSERVATION (Axiom 1){RESET}")
    lines.append("")

    if ok:
        status = f"{BGREEN}{BOLD}✓ PASS{RESET}"
    else:
        status = f"{BRED}{BOLD}✗ FAIL{RESET}"

    lines.append(f"  {status}  drift={drift:.6f}  tol={tolerance}")
    lines.append(f"    {DIM}expected:{RESET} {expected:.2f}  {DIM}actual:{RESET} {actual:.2f}")
    lines.append("")

    # Breakdown as stacked bar
    total = actual if actual > 0 else 1.0
    labels = [
        ("res_pot",   bd["resource_potential"],  fg256(208)),
        ("stockpile", bd["grid_stockpiles"],     fg256(39)),
        ("wrecks",    bd["wrecks"],              fg256(196)),
        ("agent_inv", bd["agent_inventories"],   fg256(82)),
    ]

    bar_width = 50
    for label, val, color in labels:
        ratio = val / total
        filled = int(ratio * bar_width)
        pct = ratio * 100
        b = f"{color}{'█' * filled}{RESET}{DIM}{'░' * (bar_width - filled)}{RESET}"
        lines.append(f"    {pad_right(label, 10)} {b} {val:8.2f} ({pct:5.1f}%)")

    lines.append("")
    return lines


# =========================================================================
# === CHRONICLE ===========================================================
# =========================================================================

def render_chronicle(state, max_rumors: int = 8) -> list:
    """Render recent chronicle rumors."""
    lines = []
    total = len(state.chronicle_rumors)
    lines.append(f"  {BOLD}{UNDERLINE}CHRONICLE{RESET}  {DIM}({total} total rumors){RESET}")
    lines.append("")

    recent = state.chronicle_rumors[-max_rumors:]
    if not recent:
        lines.append(f"    {DIM}(no rumors yet){RESET}")
    else:
        for rumor in recent:
            lines.append(f"    {MAGENTA}▸{RESET} {rumor}")

    lines.append("")
    return lines


# =========================================================================
# === POWER & MAINTENANCE =================================================
# =========================================================================

def render_power_maintenance(state) -> list:
    """Render power load and maintenance per sector."""
    lines = []
    lines.append(f"  {BOLD}{UNDERLINE}POWER & MAINTENANCE{RESET}")
    lines.append("")

    for sector_id in sorted(state.world_topology.keys()):
        power = state.grid_power.get(sector_id, {})
        maintenance = state.grid_maintenance.get(sector_id, {})

        loc_short = sector_id.replace("station_", "").upper()
        stype = state.world_topology[sector_id].get("sector_type", "?")
        tc = SECTOR_TYPE_COLORS.get(stype, WHITE)

        output = power.get("station_power_output", 0.0)
        draw = power.get("station_power_draw", 0.0)
        load_ratio = power.get("power_load_ratio", 0.0)
        entropy = maintenance.get("local_entropy_rate", 0.0)
        maint_mod = maintenance.get("maintenance_cost_modifier", 1.0)

        load_color = BGREEN if load_ratio < 0.5 else (YELLOW if load_ratio < 0.8 else RED)
        load_bar = bar(load_ratio, 1.0, 12, load_color)

        lines.append(
            f"  {tc}{BOLD}{loc_short}{RESET}  "
            f"{DIM}pwr:{RESET} {load_bar} {load_color}{load_ratio:.2f}{RESET} "
            f"({draw:.0f}/{output:.0f})  "
            f"{DIM}entropy:{RESET} {entropy:.4f}  "
            f"{DIM}maint_mod:{RESET} {maint_mod:.2f}"
        )

    lines.append("")
    return lines


# =========================================================================
# === FULL DASHBOARD ======================================================
# =========================================================================

def render_dashboard(engine, tick_label: str = "") -> str:
    """Render the full simulation dashboard as a single string."""
    state = engine.state
    term_width = shutil.get_terminal_size((80, 24)).columns

    lines = []

    # Header
    header_bar = "═" * (term_width - 2)
    lines.append(f"{BOLD}{CYAN}╔{header_bar}╗{RESET}")

    title = f"GDTLancer Simulation — Tick {state.sim_tick_count}"
    if tick_label:
        title += f"  ({tick_label})"
    title_padded = title.center(term_width - 2)
    lines.append(f"{BOLD}{CYAN}║{RESET}{BOLD}{title_padded}{RESET}{BOLD}{CYAN}║{RESET}")

    lines.append(f"{BOLD}{CYAN}╚{header_bar}╝{RESET}")
    lines.append("")

    # Sections
    lines.extend(render_sector_map(state))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_stockpiles(state))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_resource_potential(state))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_dominion(state))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_market(state))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_power_maintenance(state))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_agents(state))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_hostiles(state))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_matter_conservation(engine))
    lines.append(f"  {DIM}{'─' * (term_width - 4)}{RESET}")
    lines.extend(render_chronicle(state))

    # Footer
    lines.append(f"{DIM}{'─' * term_width}{RESET}")

    return "\n".join(lines)


def print_dashboard(engine, tick_label: str = "") -> None:
    """Print the full dashboard, optionally clearing screen first."""
    output = render_dashboard(engine, tick_label)
    print(output)


# =========================================================================
# === COMPACT TICK SUMMARY ================================================
# =========================================================================

def render_tick_summary(engine) -> str:
    """Render a single-line compact tick summary for streaming output."""
    state = engine.state
    tick = state.sim_tick_count

    # Matter check
    actual = engine._calculate_total_matter()
    expected = state.world_total_matter
    drift = abs(actual - expected)
    tol = engine._tick_config.get("axiom1_tolerance", 0.01)
    axiom_ok = drift <= tol

    # Agent summary
    active = sum(1 for a in state.agents.values() if not a.get("is_disabled", False))
    disabled = sum(1 for a in state.agents.values() if a.get("is_disabled", False))

    # Hostile count
    total_hostiles = sum(
        hd.get("current_count", 0)
        for hd in state.hostile_population_integral.values()
    )

    # Total stockpiles
    total_stock = 0.0
    for sid, sp in state.grid_stockpiles.items():
        for cid, qty in sp.get("commodity_stockpiles", {}).items():
            total_stock += qty

    axiom_str = f"{BGREEN}✓{RESET}" if axiom_ok else f"{BRED}✗{RESET}"

    parts = [
        f"{BOLD}T{tick:>5}{RESET}",
        f"{axiom_str}",
        f"{DIM}stk:{RESET}{total_stock:>7.0f}",
        f"{DIM}agt:{RESET}{CYAN}{active}{RESET}/{RED}{disabled}{RESET}",
        f"{DIM}hos:{RESET}{RED}{total_hostiles}{RESET}",
        f"{DIM}drift:{RESET}{drift:.4f}",
    ]

    # Per-sector piracy sparkline
    piracies = []
    for sid in sorted(state.world_topology.keys()):
        dom = state.grid_dominion.get(sid, {})
        piracies.append(dom.get("pirate_activity", 0.0))
    pir_spark = spark_line(piracies)

    parts.append(f"{DIM}pir:{RESET}{RED}{pir_spark}{RESET}")

    return "  ".join(parts)


def print_tick_summary(engine) -> None:
    """Print a compact single-line tick summary."""
    print(render_tick_summary(engine))
