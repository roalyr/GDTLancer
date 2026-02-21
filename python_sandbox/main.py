#!/usr/bin/env python3
#
# PROJECT: GDTLancer
# MODULE: main.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_13
# LOG_REF: 2026-02-21 (TASK_12)
#

"""Qualitative simulation CLI with compact tag dashboard output."""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from core.simulation.simulation_engine import SimulationEngine


def _parse_args():
    parser = argparse.ArgumentParser(description="GDTLancer qualitative simulation runner")
    parser.add_argument("--ticks", type=int, default=50)
    parser.add_argument("--seed", type=str, default="qualitative-default")
    parser.add_argument("--head", type=int, default=5)
    parser.add_argument("--tail", type=int, default=5)
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--viz", action="store_true", help="Show tick-by-tick visualization timeline")
    parser.add_argument("--viz-interval", type=int, default=10, help="Ticks between viz samples")
    parser.add_argument("--chronicle", action="store_true", help="Narrative chronicle report mode")
    parser.add_argument("--epoch-size", type=int, default=100, help="Ticks per chronicle epoch (default 100)")
    return parser.parse_args()


def _agent_name(state, agent_id: str) -> str:
    agent = state.agents.get(agent_id, {})
    character_id = agent.get("character_id", "")
    character = state.characters.get(character_id, {})
    return character.get("character_name", agent_id)


def _sector_table(state) -> list:
    rows = ["SECTORS:", "sector | colony | economy | security | environment | special"]
    for sector_id in sorted(state.world_topology.keys()):
        tags = state.sector_tags.get(sector_id, [])
        economy = [tag for tag in tags if tag.startswith(("RAW_", "MANUFACTURED_", "CURRENCY_"))]
        security = [tag for tag in tags if tag in {"SECURE", "CONTESTED", "LAWLESS"}]
        environment = [tag for tag in tags if tag in {"MILD", "HARSH", "EXTREME"}]
        special = [
            tag
            for tag in tags
            if tag in {"STATION", "FRONTIER", "HAS_SALVAGE", "DISABLED", "HOSTILE_INFESTED", "HOSTILE_THREATENED"}
        ]
        rows.append(
            f"{sector_id} | {state.colony_levels.get(sector_id, 'frontier')} | "
            f"{','.join(sorted(economy))} | {','.join(security) or '-'} | "
            f"{','.join(environment) or '-'} | {','.join(sorted(special)) or '-'}"
        )
    return rows


def _agent_table(state) -> list:
    rows = ["AGENTS:", "name | role | sector | condition | wealth | cargo | personality_tags | current_goal"]
    for agent_id in sorted(state.agents.keys()):
        agent = state.agents[agent_id]
        name = _agent_name(state, agent_id)
        character = state.characters.get(agent.get("character_id", ""), {})
        traits = sorted(character.get("personality_traits", {}).keys())
        rows.append(
            f"{name} | {agent.get('agent_role','idle')} | {agent.get('current_sector_id','')} | "
            f"{agent.get('condition_tag','HEALTHY')} | {agent.get('wealth_tag','COMFORTABLE')} | "
            f"{agent.get('cargo_tag','EMPTY')} | {','.join(traits) or '-'} | {agent.get('goal_archetype','idle')}"
        )
    return rows


def _chronicle_lines(state, max_items: int = 10) -> list:
    lines = ["CHRONICLE:"]
    rumors = state.chronicle_rumors[-max_items:]
    if not rumors:
        lines.append("-")
        return lines
    lines.extend(rumors)
    return lines


def _lifecycle_lines(state, max_items: int = 10) -> list:
    lines = ["LIFECYCLE:"]
    events = [
        e
        for e in state.chronicle_events
        if e.get("action") in {"spawn", "respawn", "catastrophe"}
    ]
    if not events:
        lines.append("-")
        return lines
    for event in events[-max_items:]:
        lines.append(f"t{event.get('tick', 0)} {event.get('action')} {event.get('actor_id', '')} {event.get('sector_id', '')}")
    return lines


def _transient_snapshot(state) -> dict:
    sector_snapshot = {}
    for sector_id in sorted(state.sector_tags.keys()):
        sector_snapshot[sector_id] = sorted(state.sector_tags.get(sector_id, []))

    agent_snapshot = {}
    for agent_id in sorted(state.agents.keys()):
        agent = state.agents[agent_id]
        agent_snapshot[agent_id] = {
            "sector": agent.get("current_sector_id", ""),
            "condition": agent.get("condition_tag", "HEALTHY"),
            "wealth": agent.get("wealth_tag", "COMFORTABLE"),
            "cargo": agent.get("cargo_tag", "EMPTY"),
        }

    return {"sectors": sector_snapshot, "agents": agent_snapshot}


def _transient_lines(history: list, head: int, tail: int) -> list:
    lines = ["TRANSIENT:"]
    if not history:
        lines.append("-")
        return lines

    selected = history[:head] + ([{"sep": True}] if len(history) > head + tail else []) + history[-tail:]
    for item in selected:
        if item.get("sep"):
            lines.append("...")
            continue
        tick = item["tick"]
        lines.append(f"t{tick}")
        lines.append(f"  sectors={item['snapshot']['sectors']}")
        lines.append(f"  agents={item['snapshot']['agents']}")
    return lines


def _build_report(engine: SimulationEngine, transient_history: list, args) -> str:
    state = engine.state
    lines = []

    lines.append("WORLD:")
    lines.append(
        f"age={state.world_age} world_tags={','.join(state.world_tags)} "
        f"cycle_count={state.world_age_cycle_count} timer={state.world_age_timer}"
    )
    lines.append("")
    lines.extend(_sector_table(state))
    lines.append("")
    lines.extend(_agent_table(state))
    lines.append("")
    lines.extend(_chronicle_lines(state))
    lines.append("")
    lines.extend(_lifecycle_lines(state))
    lines.append("")
    lines.extend(_transient_lines(transient_history, args.head, args.tail))
    return "\n".join(lines)


# =========================================================================
# Chronicle report mode
# =========================================================================

_LOCATION_NAMES = {
    k: v.get("location_name", k)
    for k, v in __import__("database.registry.template_data", fromlist=["LOCATIONS"]).LOCATIONS.items()
}


def _loc(sector_id: str) -> str:
    """Resolve sector_id to short human name."""
    return _LOCATION_NAMES.get(sector_id, sector_id or "deep space")


def _agent_display(state, agent_id: str) -> str:
    agent = state.agents.get(agent_id, {})
    cid = agent.get("character_id", "")
    char = state.characters.get(cid, {})
    name = char.get("character_name", agent_id)
    role = agent.get("agent_role", "")
    return f"{name} ({role})" if role else name


def _economy_label(tags: list) -> str:
    for level in ("RICH", "ADEQUATE", "POOR"):
        if any(t.endswith(f"_{level}") for t in tags):
            return level.lower()
    return "adequate"


def _security_label(tags: list) -> str:
    for t in ("SECURE", "CONTESTED", "LAWLESS"):
        if t in tags:
            return t.lower()
    return "contested"


def _environment_label(tags: list) -> str:
    for t in ("MILD", "HARSH", "EXTREME"):
        if t in tags:
            return t.lower()
    return "mild"


def _collect_epoch_events(all_events: list, start: int, end: int) -> list:
    return [e for e in all_events if start < e.get("tick", 0) <= end]


def _chronicle_epoch_narrative(epoch_events: list, state, epoch_start: int,
                               epoch_end: int, prev_sector_snap: dict) -> tuple:
    """Generate narrative lines for one epoch. Returns (lines, sector_snapshot)."""
    lines = []
    counts = {}
    attacker_counts = {}
    attack_sectors = {}
    trade_sectors = {}
    flee_count = 0
    spawn_names = []
    death_ids = set()
    catastrophe_sectors = []
    age_changes = []
    colony_changes = []
    cargo_loads = 0
    harvest_count = 0
    explore_count = 0

    for e in epoch_events:
        action = e.get("action", "")
        counts[action] = counts.get(action, 0) + 1
        actor = e.get("actor_id", "")
        sector = e.get("sector_id", "")

        if action == "attack":
            attacker_counts[actor] = attacker_counts.get(actor, 0) + 1
            attack_sectors[sector] = attack_sectors.get(sector, 0) + 1
        elif action == "agent_trade":
            trade_sectors[sector] = trade_sectors.get(sector, 0) + 1
        elif action == "flee":
            flee_count += 1
        elif action == "spawn":
            spawn_names.append((actor, sector))
        elif action == "catastrophe":
            catastrophe_sectors.append(sector)
        elif action == "age_change":
            new_age = e.get("metadata", {}).get("new_age", "")
            age_changes.append(new_age)
        elif action == "load_cargo":
            cargo_loads += 1
        elif action == "harvest":
            harvest_count += 1
        elif action == "exploration":
            explore_count += 1

    # Track destroyed agents from respawn events (implies prior death)
    respawn_count = counts.get("respawn", 0)

    # ---- Build narrative paragraphs ----

    # Sector state transitions  
    sector_snap = {}
    for sid in sorted(state.sector_tags.keys()):
        tags = state.sector_tags.get(sid, [])
        sector_snap[sid] = {
            "economy": _economy_label(tags),
            "security": _security_label(tags),
            "environment": _environment_label(tags),
            "colony": state.colony_levels.get(sid, "frontier"),
            "infested": "HOSTILE_INFESTED" in tags,
            "threatened": "HOSTILE_THREATENED" in tags,
        }

    # Detect sector changes
    changed_sectors = []
    for sid in sorted(sector_snap.keys()):
        cur = sector_snap[sid]
        prev = prev_sector_snap.get(sid, {})
        changes = []
        if prev.get("economy") and prev["economy"] != cur["economy"]:
            changes.append(f"economy shifted from {prev['economy']} to {cur['economy']}")
        if prev.get("security") and prev["security"] != cur["security"]:
            changes.append(f"security changed from {prev['security']} to {cur['security']}")
        if prev.get("environment") and prev["environment"] != cur["environment"]:
            changes.append(f"environment went from {prev['environment']} to {cur['environment']}")
        if prev.get("colony") and prev["colony"] != cur["colony"]:
            changes.append(f"grew from {prev['colony']} to {cur['colony']}" if
                          ["frontier", "outpost", "colony", "hub"].index(cur["colony"]) >
                          ["frontier", "outpost", "colony", "hub"].index(prev["colony"])
                          else f"declined from {prev['colony']} to {cur['colony']}")
        if not prev.get("infested") and cur["infested"]:
            changes.append("became infested with hostiles")
        elif prev.get("infested") and not cur["infested"]:
            changes.append("was cleared of hostile infestation")
        if changes:
            changed_sectors.append((_loc(sid), changes))

    # World age changes — major headline
    for new_age in age_changes:
        age_flavor = {
            "PROSPERITY": "A new age of Prosperity dawned across the sector. Trade routes reopened and stations bustled with commerce.",
            "DISRUPTION": "The age of Disruption began. Instability spread as pirate activity surged and supply lines faltered.",
            "RECOVERY": "Recovery took hold. Communities began rebuilding and order slowly returned to the trade lanes.",
        }
        lines.append(f"  >>> {age_flavor.get(new_age, f'The world entered {new_age}.')}")
        lines.append("")

    # Catastrophes — rare, always reported (deduplicate same sector)
    unique_catastrophes = list(dict.fromkeys(catastrophe_sectors))
    for csec in unique_catastrophes:
        lines.append(f"  *** CATASTROPHE struck {_loc(csec)}! The station was disabled and operations ceased. ***")
    if unique_catastrophes:
        lines.append("")

    # Sector state overview
    if changed_sectors:
        for loc_name, changes in changed_sectors:
            lines.append(f"  {loc_name}: {'; '.join(changes)}.")
        lines.append("")

    # Combat summary
    total_attacks = counts.get("attack", 0)
    if total_attacks > 0:
        # Most violent sector
        hotspot = max(attack_sectors, key=attack_sectors.get) if attack_sectors else ""
        hotspot_n = attack_sectors.get(hotspot, 0)
        # Most aggressive agent
        top_attacker = max(attacker_counts, key=attacker_counts.get) if attacker_counts else ""
        top_n = attacker_counts.get(top_attacker, 0)

        combat_line = f"  Combat: {total_attacks} engagements"
        if hotspot:
            combat_line += f", fiercest around {_loc(hotspot)} ({hotspot_n})"
        if top_attacker and top_n >= 3:
            combat_line += f". {_agent_display(state, top_attacker)} was most aggressive ({top_n} attacks)"
        combat_line += "."
        lines.append(combat_line)

    # Trade & economy
    total_trades = counts.get("agent_trade", 0)
    if total_trades > 0 or cargo_loads > 0:
        econ_parts = []
        if total_trades:
            top_trade_loc = max(trade_sectors, key=trade_sectors.get) if trade_sectors else ""
            trade_str = f"{total_trades} trades"
            if top_trade_loc:
                trade_str += f" (busiest: {_loc(top_trade_loc)})"
            econ_parts.append(trade_str)
        if cargo_loads:
            econ_parts.append(f"{cargo_loads} cargo runs loaded")
        if harvest_count:
            econ_parts.append(f"{harvest_count} salvage operations")
        lines.append(f"  Commerce: {', '.join(econ_parts)}.")

    # Flight & danger
    if flee_count >= 3:
        lines.append(f"  Danger: {flee_count} pilots fled dangerous encounters.")

    # Respawns
    if respawn_count > 0:
        lines.append(f"  Losses & returns: {respawn_count} pilots were destroyed and later returned to service.")

    # New arrivals — group by sector to avoid spam
    if spawn_names:
        seen_spawns = set()
        unique_spawns = []
        for aid, sec in spawn_names:
            key = (aid, sec)
            if key not in seen_spawns:
                seen_spawns.add(key)
                unique_spawns.append((aid, sec))
        # Group by sector
        sector_spawns: dict = {}
        for aid, sec in unique_spawns:
            sector_spawns.setdefault(sec, []).append(aid)
        for sec, aids in sector_spawns.items():
            names = [_agent_display(state, a) for a in aids]
            if len(names) <= 3:
                lines.append(f"  New arrivals at {_loc(sec)}: {', '.join(names)}.")
            else:
                lines.append(f"  {len(names)} new pilots appeared at {_loc(sec)}.")

    # Exploration
    if explore_count:
        lines.append(f"  Exploration: {explore_count} survey expeditions launched.")

    # If absolutely nothing interesting happened
    if not lines and total_attacks == 0 and total_trades == 0:
        lines.append("  A quiet period. Routine patrols and cargo runs continued without incident.")

    return lines, sector_snap


def _chronicle_summary(all_events: list, total_ticks: int, state) -> list:
    """Final summary paragraph after all epochs."""
    lines = []
    action_totals = {}
    for e in all_events:
        a = e.get("action", "")
        action_totals[a] = action_totals.get(a, 0) + 1

    total_attacks = action_totals.get("attack", 0)
    total_trades = action_totals.get("agent_trade", 0)
    total_spawns = action_totals.get("spawn", 0)
    total_catastrophes = action_totals.get("catastrophe", 0)
    total_respawns = action_totals.get("respawn", 0)
    age_changes = action_totals.get("age_change", 0)

    lines.append("=" * 64)
    lines.append("OVERALL SUMMARY")
    lines.append("=" * 64)
    lines.append(f"  Simulation ran for {total_ticks} ticks ({age_changes} world-age transitions).")
    lines.append(f"  Total engagements: {total_attacks}  |  Total trades: {total_trades}")
    lines.append(f"  Newcomers arrived: {total_spawns}  |  Pilots lost & returned: {total_respawns}")
    if total_catastrophes:
        lines.append(f"  Catastrophes endured: {total_catastrophes}")

    # Final world state
    lines.append("")
    lines.append("  Final state of the sector:")
    for sid in sorted(state.sector_tags.keys()):
        tags = state.sector_tags.get(sid, [])
        econ = _economy_label(tags)
        sec = _security_label(tags)
        env = _environment_label(tags)
        col = state.colony_levels.get(sid, "frontier")
        lines.append(f"    {_loc(sid)}: {econ} economy, {sec}, {env} environment [{col}]")

    # Final agent roster
    lines.append("")
    lines.append("  Active pilots:")
    for aid in sorted(state.agents.keys()):
        if aid == "player":
            continue
        agent = state.agents[aid]
        if agent.get("is_disabled"):
            continue
        cond = agent.get("condition_tag", "HEALTHY").lower()
        wealth = agent.get("wealth_tag", "COMFORTABLE").lower()
        sector = _loc(agent.get("current_sector_id", ""))
        lines.append(f"    {_agent_display(state, aid)}: {cond}, {wealth}, at {sector}")

    return lines


def _run_chronicle(engine, args):
    """Run simulation and produce a narrative chronicle report."""
    epoch_size = max(1, args.epoch_size)
    total_ticks = max(0, args.ticks)
    all_events = []
    epoch_start = 0
    epoch_num = 0
    prev_sector_snap = {}

    # Take initial sector snapshot
    for sid in sorted(engine.state.sector_tags.keys()):
        tags = engine.state.sector_tags.get(sid, [])
        prev_sector_snap[sid] = {
            "economy": _economy_label(tags),
            "security": _security_label(tags),
            "environment": _environment_label(tags),
            "colony": engine.state.colony_levels.get(sid, "frontier"),
            "infested": "HOSTILE_INFESTED" in tags,
            "threatened": "HOSTILE_THREATENED" in tags,
        }

    print("=" * 64)
    print(f"CHRONICLE OF THE SECTOR  (seed: {args.seed})")
    print("=" * 64)
    print()

    seen_event_ids = set()
    for tick_num in range(total_ticks):
        engine.process_tick()
        # Collect only new, unseen events (dedup by object identity)
        for e in engine.state.chronicle_events:
            eid = id(e)
            if eid not in seen_event_ids:
                seen_event_ids.add(eid)
                all_events.append(e)

        # End of epoch?
        current_tick = engine.state.sim_tick_count
        if current_tick % epoch_size == 0 or tick_num == total_ticks - 1:
            epoch_end = current_tick
            epoch_num += 1
            epoch_events = _collect_epoch_events(all_events, epoch_start, epoch_end)

            age = engine.state.world_age
            header = f"--- Epoch {epoch_num}: ticks {epoch_start + 1}–{epoch_end} [{age}] ---"
            print(header)

            narrative, prev_sector_snap = _chronicle_epoch_narrative(
                epoch_events, engine.state, epoch_start, epoch_end, prev_sector_snap
            )
            if narrative:
                print("\n".join(narrative))
            print()

            epoch_start = epoch_end

    # Final summary
    summary = _chronicle_summary(all_events, total_ticks, engine.state)
    print("\n".join(summary))


# =========================================================================
# Visualization mode
# =========================================================================

# ANSI color codes
_C_RESET = "\033[0m"
_C_BOLD = "\033[1m"
_C_DIM = "\033[2m"
_C_RED = "\033[31m"
_C_GREEN = "\033[32m"
_C_YELLOW = "\033[33m"
_C_BLUE = "\033[34m"
_C_MAGENTA = "\033[35m"
_C_CYAN = "\033[36m"
_C_WHITE = "\033[37m"
_C_BG_RED = "\033[41m"
_C_BG_GREEN = "\033[42m"
_C_BG_YELLOW = "\033[43m"

_AGE_COLORS = {
    "PROSPERITY": _C_GREEN,
    "DISRUPTION": _C_RED,
    "RECOVERY": _C_YELLOW,
}

_ECON_GLYPHS = {"RICH": f"{_C_GREEN}\u2588{_C_RESET}", "ADEQUATE": f"{_C_YELLOW}\u2592{_C_RESET}", "POOR": f"{_C_RED}\u2591{_C_RESET}"}
_SEC_GLYPHS = {"SECURE": f"{_C_GREEN}\u25cf{_C_RESET}", "CONTESTED": f"{_C_YELLOW}\u25d0{_C_RESET}", "LAWLESS": f"{_C_RED}\u25cb{_C_RESET}"}
_ENV_GLYPHS = {"MILD": f"{_C_CYAN}~{_C_RESET}", "HARSH": f"{_C_YELLOW}#{_C_RESET}", "EXTREME": f"{_C_RED}!{_C_RESET}"}
_COND_GLYPHS = {"HEALTHY": f"{_C_GREEN}\u2665{_C_RESET}", "DAMAGED": f"{_C_YELLOW}\u2666{_C_RESET}", "DESTROYED": f"{_C_RED}\u2620{_C_RESET}"}
_WEALTH_GLYPHS = {"WEALTHY": f"{_C_GREEN}${_C_RESET}", "COMFORTABLE": f"{_C_YELLOW}c{_C_RESET}", "BROKE": f"{_C_RED}_{_C_RESET}"}


def _viz_economy_level(tags: list, category: str) -> str:
    for level in ("RICH", "ADEQUATE", "POOR"):
        if f"{category}_{level}" in tags:
            return level
    return "ADEQUATE"


def _viz_security(tags: list) -> str:
    for tag in ("SECURE", "CONTESTED", "LAWLESS"):
        if tag in tags:
            return tag
    return "CONTESTED"


def _viz_environment(tags: list) -> str:
    for tag in ("MILD", "HARSH", "EXTREME"):
        if tag in tags:
            return tag
    return "MILD"


# -- ANSI-aware string helpers --
_ANSI_RE = re.compile(r'\033\[[0-9;]*m')


def _visible_len(s: str) -> int:
    """Length of string excluding ANSI escape sequences."""
    return len(_ANSI_RE.sub('', s))


def _pad_right(s: str, width: int) -> str:
    """Pad *s* with spaces so its visible width reaches *width*."""
    return s + ' ' * max(0, width - _visible_len(s))


# -- 2-D grid layout --
# Each row is a list of (sector_id, short_label) tuples.
_GRID_ROWS = [
    [("station_epsilon", "EPS"), ("station_beta", "BET")],
    [("station_alpha", "ALP"), ("station_delta", "DEL")],
    [("station_gamma", "GAM")],
]
_CELL_INNER = 26          # visible-char width inside the box border
_CELL_OUTER = _CELL_INNER + 2   # including │ on each side
_COL_GAP = 1                     # space between columns


def _viz_agent_glyph(agent: dict) -> str:
    cond = _COND_GLYPHS.get(agent.get("condition_tag", "HEALTHY"), "?")
    wealth = _WEALTH_GLYPHS.get(agent.get("wealth_tag", "COMFORTABLE"), "?")
    cargo = f"{_C_BLUE}L{_C_RESET}" if agent.get("cargo_tag") == "LOADED" else f"{_C_DIM}.{_C_RESET}"
    return f"{cond}{wealth}{cargo}"


def _viz_specials(tags: list) -> str:
    """Return coloured special-tag string."""
    s = ""
    if "HOSTILE_INFESTED" in tags:
        s += f" {_C_RED}!H{_C_RESET}"
    elif "HOSTILE_THREATENED" in tags:
        s += f" {_C_YELLOW}?H{_C_RESET}"
    if "HAS_SALVAGE" in tags:
        s += f" {_C_MAGENTA}S{_C_RESET}"
    if "DISABLED" in tags:
        s += f" {_C_RED}X{_C_RESET}"
    return s


def _viz_cell_lines(sector_id: str, label: str, state) -> list:
    """Return 4 fixed-width lines: top border, tag row, agent row, bottom border."""
    w = _CELL_INNER
    tags = state.sector_tags.get(sector_id, [])

    # Economy / security / environment glyphs
    raw = _ECON_GLYPHS[_viz_economy_level(tags, "RAW")]
    mfg = _ECON_GLYPHS[_viz_economy_level(tags, "MANUFACTURED")]
    cur = _ECON_GLYPHS[_viz_economy_level(tags, "CURRENCY")]
    sec = _SEC_GLYPHS[_viz_security(tags)]
    env = _ENV_GLYPHS[_viz_environment(tags)]
    specials = _viz_specials(tags)
    colony = state.colony_levels.get(sector_id, "fro")[:3]

    tag_line = f" {_C_BOLD}{label}{_C_RESET} {raw}{mfg}{cur} {sec}{env}{specials} {_C_DIM}{colony}{_C_RESET}"

    # Agents in this sector
    agents_here = [
        a for aid, a in state.agents.items()
        if aid != "player" and not a.get("is_disabled")
        and a.get("current_sector_id") == sector_id
    ]
    if agents_here:
        glyphs = ""
        for a in agents_here[:6]:
            glyphs += _viz_agent_glyph(a)
        leftover = len(agents_here) - 6
        if leftover > 0:
            glyphs += f" {_C_DIM}+{leftover}{_C_RESET}"
        agent_line = f" {glyphs}"
    else:
        agent_line = f" {_C_DIM}··{_C_RESET}"

    hbar = "\u2500" * w
    top = f"\u250c{hbar}\u2510"
    mid1 = f"\u2502{_pad_right(tag_line, w)}\u2502"
    mid2 = f"\u2502{_pad_right(agent_line, w)}\u2502"
    bot = f"\u2514{hbar}\u2518"
    return [top, mid1, mid2, bot]


def _viz_empty_cell() -> list:
    """Return 4 blank lines the same visible width as a real cell."""
    blank = ' ' * _CELL_OUTER
    return [blank, blank, blank, blank]


def _viz_event_summary(events: list) -> str:
    """Collapse event list into a compact coloured string."""
    counts: dict = {}
    last_age = ""
    for e in events:
        action = e.get("action", "")
        if action in ("attack", "catastrophe", "spawn", "respawn"):
            counts[action] = counts.get(action, 0) + 1
        elif action == "age_change":
            last_age = e.get("metadata", {}).get("new_age", "")
    parts = []
    if "attack" in counts:
        parts.append(f"{_C_RED}\u2694{counts['attack']}{_C_RESET}")
    if "catastrophe" in counts:
        parts.append(f"{_C_BG_RED}\u26a1{counts['catastrophe']}{_C_RESET}")
    if "spawn" in counts:
        parts.append(f"{_C_CYAN}+{counts['spawn']}{_C_RESET}")
    if "respawn" in counts:
        parts.append(f"{_C_GREEN}\u21ba{counts['respawn']}{_C_RESET}")
    if last_age:
        parts.append(f"{_C_BOLD}\u2192{last_age}{_C_RESET}")
    return " ".join(parts)


def _viz_render_frame(tick: int, state, prev_events: list) -> str:
    """Render one 2-D grid-map frame."""
    lines: list = []
    age_color = _AGE_COLORS.get(state.world_age, _C_WHITE)
    evt = _viz_event_summary(prev_events)
    dbar_s = "\u2550" * 3
    dbar_l = "\u2550" * 28
    header = (
        f"{_C_DIM}{dbar_s}{_C_RESET} "
        f"t{tick:<5} {age_color}{_C_BOLD}{state.world_age}{_C_RESET} "
        f"{_C_DIM}{dbar_l}{_C_RESET}"
    )
    if evt:
        header += f"  {evt}"
    lines.append(header)

    max_cols = max(len(row) for row in _GRID_ROWS)
    for row_def in _GRID_ROWS:
        cells = []
        for sector_id, label in row_def:
            cells.append(_viz_cell_lines(sector_id, label, state))
        while len(cells) < max_cols:
            cells.append(_viz_empty_cell())
        # Print 4 sub-lines side-by-side
        gap = ' ' * _COL_GAP
        for i in range(4):
            lines.append(gap.join(cells[col][i] for col in range(max_cols)))

    return "\n".join(lines)


def _viz_legend() -> str:
    lines = [
        f"{_C_BOLD}=== SIMULATION MAP ==={_C_RESET}",
        "",
        f"  Economy:  {_ECON_GLYPHS['RICH']}RICH  {_ECON_GLYPHS['ADEQUATE']}ADEQUATE  {_ECON_GLYPHS['POOR']}POOR  (R M C)",
        f"  Security: {_SEC_GLYPHS['SECURE']}SECURE  {_SEC_GLYPHS['CONTESTED']}CONTESTED  {_SEC_GLYPHS['LAWLESS']}LAWLESS",
        f"  Environ:  {_ENV_GLYPHS['MILD']}MILD  {_ENV_GLYPHS['HARSH']}HARSH  {_ENV_GLYPHS['EXTREME']}EXTREME",
        f"  Agents:   {_COND_GLYPHS['HEALTHY']}healthy {_COND_GLYPHS['DAMAGED']}damaged {_COND_GLYPHS['DESTROYED']}destroyed"
        f"  {_WEALTH_GLYPHS['WEALTHY']}wealthy {_WEALTH_GLYPHS['COMFORTABLE']}ok {_WEALTH_GLYPHS['BROKE']}broke"
        f"  {_C_BLUE}L{_C_RESET}loaded {_C_DIM}.{_C_RESET}empty",
        f"  Specials: {_C_RED}!H{_C_RESET}infested  {_C_YELLOW}?H{_C_RESET}threatened  {_C_MAGENTA}S{_C_RESET}salvage  {_C_RED}X{_C_RESET}disabled",
        f"  Events:   {_C_RED}\u2694{_C_RESET}attack  {_C_BG_RED}\u26a1{_C_RESET}catastrophe  {_C_CYAN}+{_C_RESET}spawn  {_C_GREEN}\u21ba{_C_RESET}respawn  {_C_BOLD}\u2192{_C_RESET}age_change",
        "",
    ]
    return "\n".join(lines)


def _run_viz(engine, args):
    print(_viz_legend())

    pending_events = []
    for tick_num in range(max(0, args.ticks)):
        engine.process_tick()
        pending_events.extend(
            e for e in engine.state.chronicle_events
            if e.get("tick") == engine.state.sim_tick_count
        )

        if engine.state.sim_tick_count % args.viz_interval == 0 or tick_num == args.ticks - 1:
            print(_viz_render_frame(engine.state.sim_tick_count, engine.state, pending_events))
            print()
            pending_events.clear()


def main():
    args = _parse_args()

    engine = SimulationEngine()
    engine.initialize_simulation(args.seed)

    if args.viz:
        _run_viz(engine, args)
        return

    if args.chronicle:
        _run_chronicle(engine, args)
        return

    transient_history = []
    for _ in range(max(0, args.ticks)):
        engine.process_tick()
        transient_history.append(
            {
                "tick": engine.state.sim_tick_count,
                "snapshot": _transient_snapshot(engine.state),
            }
        )

    report = _build_report(engine, transient_history, args)
    print(report)


if __name__ == "__main__":
    main()
