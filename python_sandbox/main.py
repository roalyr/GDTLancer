#!/usr/bin/env python3
"""
GDTLancer Simulation Sandbox — CLI runner.

Outputs structured plain text optimized for LLM analysis.
All visualization code has been removed in favor of compact,
machine-readable state dumps.

Usage:
    python main.py                      # 10 ticks, default seed
    python main.py --ticks 50000        # 50k ticks
    python main.py --seed hello         # custom seed
    python main.py --sample-every 500   # sample metrics every N ticks
    python main.py --quiet              # final report only (no progress dots)
    python main.py --head 10            # show first N ticks in transient view
    python main.py --tail 10            # show last N ticks in transient view
"""

import argparse
import math
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from simulation_engine import SimulationEngine


# -----------------------------------------------------------------
# Suppress noisy layer prints
# -----------------------------------------------------------------
_original_print = print

def _quiet_print(*a, **kw):
    msg = " ".join(str(x) for x in a)
    prefixes = (
        "WorldLayer:", "GridLayer:", "AgentLayer:",
        "SimulationEngine:", "BridgeSystems:", "ChronicleLayer:",
        "AXIOM 1",
    )
    if any(msg.startswith(p) for p in prefixes):
        return
    _original_print(*a, **kw)


# -----------------------------------------------------------------
# Snapshot helpers (captured every tick for head/tail windows)
# -----------------------------------------------------------------
def _snapshot_agents(state):
    """Compact per-agent snapshot: name->(role,sector,hull,cash,debt,goal,disabled)"""
    snap = {}
    for agent_id in sorted(state.agents.keys()):
        a = state.agents[agent_id]
        char_uid = a.get("char_uid", -1)
        ch = state.characters.get(char_uid, {})
        name = ch.get("character_name", f"U{char_uid}")
        snap[name] = {
            "r": a.get("agent_role", "?")[:4],
            "s": a.get("current_sector_id", "?").replace("station_", "")[:3],
            "h": round(a.get("hull_integrity", 0.0), 3),
            "c": round(a.get("cash_reserves", 0.0), 1),
            "d": round(a.get("debt", 0.0), 1),
            "g": a.get("goal_archetype", "?")[:5],
            "x": 1 if a.get("is_disabled", False) else 0,
        }
    return snap


def _snapshot_sectors(state):
    """Compact per-sector snapshot."""
    snap = {}
    for sid in sorted(state.world_topology.keys()):
        short = sid.replace("station_", "").upper()[:3]
        pot = state.world_resource_potential.get(sid, {})
        hid = state.world_hidden_resources.get(sid, {})
        stock = state.grid_stockpiles.get(sid, {})
        dom = state.grid_dominion.get(sid, {})
        hz = state.world_hazards.get(sid, {})

        stot = sum(float(v) for v in stock.get("commodity_stockpiles", {}).values())
        fi = dom.get("faction_influence", {})
        dominant = max(fi, key=fi.get).replace("faction_", "")[:4] if fi else "?"

        snap[short] = {
            "dM": round(pot.get("mineral_density", 0.0), 1),
            "dP": round(pot.get("propellant_sources", 0.0), 1),
            "hM": round(hid.get("mineral_density", 0.0), 1),
            "hP": round(hid.get("propellant_sources", 0.0), 1),
            "stk": round(stot, 1),
            "sec": round(dom.get("security_level", 0.0), 3),
            "pir": round(dom.get("pirate_activity", 0.0), 4),
            "hos": round(dom.get("hostility_level", 0.0), 4),
            "rad": round(hz.get("radiation_level", 0.0), 4),
            "dom": dominant,
        }
    return snap


def _snapshot_hostiles(state):
    """Compact hostile population snapshot."""
    snap = {}
    for htype, pop in state.hostile_population_integral.items():
        counts = pop.get("sector_counts", {})
        total = pop.get("current_count", 0)
        dist = {k.replace("station_", "")[:3]: v for k, v in sorted(counts.items())}
        snap[htype[:5]] = {"n": total, "d": dist}
    return snap


def _snapshot_wrecks(state):
    """Wreck count and total matter in wrecks."""
    count = len(state.grid_wrecks)
    matter = 0.0
    for w in state.grid_wrecks.values():
        matter += w.get("wreck_integrity", 0.0)
        for qty in w.get("wreck_inventory", {}).values():
            matter += float(qty)
    return {"count": count, "matter": round(matter, 2)}


def _snapshot_matter(engine):
    """Compact matter breakdown."""
    bd = engine._matter_breakdown()
    return {k[:6]: round(v, 2) for k, v in bd.items()}


# -----------------------------------------------------------------
# Report generation
# -----------------------------------------------------------------
def generate_report(engine, ticks_run, sample_data, age_transitions,
                    transient_head, transient_tail, head_n, tail_n):
    """Produce a single structured report after the run completes."""
    s = engine.state
    sectors = sorted(s.world_topology.keys())  # Dynamic: includes discovered sectors
    init_matter = s.world_total_matter
    actual_matter = engine._calculate_total_matter()
    drift = abs(actual_matter - init_matter)

    out = []
    out.append(f"=== Simulation Report: {ticks_run} ticks, seed='{s.world_seed}' ===")
    out.append(f"  head={head_n} tail={tail_n} sample_every={sample_data.get('sample_every', 1)}")
    out.append("")

    # == AXIOM 1 (relative drift) ==
    drifts = sample_data["axiom1_drifts"]
    max_d = max(drifts) if drifts else drift
    avg_d = sum(drifts) / len(drifts) if drifts else drift
    max_rel = max_d / max(init_matter, 1.0) * 100.0
    avg_rel = avg_d / max(init_matter, 1.0) * 100.0
    out.append(f"AXIOM_1: max_drift={max_d:.2f} ({max_rel:.4f}%) "
               f"avg_drift={avg_d:.2f} ({avg_rel:.4f}%) "
               f"budget={init_matter:.2f} final={actual_matter:.2f}")

    # == WORLD AGE ==
    out.append(f"WORLD_AGE: current={s.world_age} timer={s.world_age_timer} "
               f"cycles={s.world_age_cycle_count} transitions={len(age_transitions)}")
    if age_transitions:
        out.append(f"  first_3: {age_transitions[:3]}")
        out.append(f"  last_3:  {age_transitions[-3:]}")
    out.append("")

    # == SECTOR STATE (final) ==
    out.append("SECTOR_STATE (final):")
    out.append("  sector   |type    |disc_M    disc_P  |hidden_M hidden_P|stock  |"
               "sec  pir    hos    |dom         |rad    therm")
    out.append("  " + "-" * 110)
    for sid in sectors:
        sh = sid.replace("station_", "").upper()
        tp = s.world_topology[sid]
        stype = tp.get("sector_type", "?")[:6]
        pot = s.world_resource_potential.get(sid, {})
        hid = s.world_hidden_resources.get(sid, {})
        stk = s.grid_stockpiles.get(sid, {})
        dom = s.grid_dominion.get(sid, {})
        hz = s.world_hazards.get(sid, {})

        dm = pot.get("mineral_density", 0.0)
        dp = pot.get("propellant_sources", 0.0)
        hm = hid.get("mineral_density", 0.0)
        hp = hid.get("propellant_sources", 0.0)
        stot = sum(float(v) for v in stk.get("commodity_stockpiles", {}).values())
        sec = dom.get("security_level", 0.0)
        pir = dom.get("pirate_activity", 0.0)
        hos = dom.get("hostility_level", 0.0)
        fi = dom.get("faction_influence", {})
        dominant = max(fi, key=fi.get).replace("faction_", "") if fi else "none"
        rad = hz.get("radiation_level", 0.0)
        therm = hz.get("thermal_background_k", 0.0)

        out.append(f"  {sh:<8} {stype:<7} {dm:>8.1f} {dp:>7.1f}  "
                   f"{hm:>7.1f} {hp:>7.1f}  {stot:>6.0f}  "
                   f"{sec:.2f} {pir:.4f} {hos:.4f}  {dominant:<12} "
                   f"{rad:.4f} {therm:.0f}")
    out.append("")

    # == MATTER BREAKDOWN (final) ==
    bd = engine._matter_breakdown()
    total = sum(bd.values())
    out.append("MATTER_BREAKDOWN (final):")
    parts = "  ".join(f"{k}={v:.1f}({v/total*100:.1f}%)" for k, v in bd.items()) if total > 0 else ""
    out.append(f"  {parts}")
    out.append(f"  TOTAL={total:.2f}")
    out.append("")

    # == AGENTS (final) ==
    out.append("AGENTS (final):")
    out.append("  name         role      sector     hull  cash      debt      goal     inv")
    out.append("  " + "-" * 85)
    for agent_id in sorted(s.agents.keys()):
        a = s.agents[agent_id]
        char_uid = a.get("char_uid", -1)
        ch = s.characters.get(char_uid, {})
        name = ch.get("character_name", f"UID:{char_uid}")
        sector = a.get("current_sector_id", "?").replace("station_", "")
        hull = a.get("hull_integrity", 0.0)
        cash = a.get("cash_reserves", 0.0)
        debt = a.get("debt", 0.0)
        goal = a.get("goal_archetype", "?")
        role = a.get("agent_role", "?")
        disabled = a.get("is_disabled", False)
        inv = s.inventories.get(char_uid, {}).get(2, {})
        inv_total = sum(float(v) for v in inv.values())
        status = "DEAD" if disabled else f"{hull:.2f}"
        out.append(f"  {name:<12} {role:<9} {sector:<10} {status:<5} "
                   f"{cash:>8.0f} {debt:>8.0f}  {goal:<8} {inv_total:.0f}")
    out.append("")

    # == HOSTILES (final) ==
    out.append("HOSTILES (final):")
    total_hostiles = 0
    for htype, pop in s.hostile_population_integral.items():
        count = pop.get("current_count", 0)
        dist = pop.get("sector_counts", {})
        dist_str = " ".join(f"{k.replace('station_','')[:3]}={v}" for k, v in sorted(dist.items()))
        pool_data = s.hostile_pools.get(htype, {"reserve": 0.0, "body_mass": 0.0})
        out.append(f"  {htype}: count={count}  reserve={pool_data['reserve']:.1f}  body_mass={pool_data['body_mass']:.1f}  [{dist_str}]")
        total_hostiles += count
    total_hostile_reserve = sum(p["reserve"] for p in s.hostile_pools.values())
    total_hostile_body = sum(p["body_mass"] for p in s.hostile_pools.values())
    budget = sum(engine._matter_breakdown().values())
    pool_pct = ((total_hostile_reserve + total_hostile_body) / budget * 100) if budget > 0 else 0.0
    wreck_count = len(s.grid_wrecks)
    wreck_matter = sum(
        sum(float(v) for v in w.get("wreck_inventory", {}).values()) + w.get("wreck_integrity", 0.0)
        for w in s.grid_wrecks.values()
    )
    out.append(f"  hostile_pools_total={total_hostile_reserve + total_hostile_body:.2f} ({pool_pct:.1f}% of budget)")
    out.append(f"  total_hostiles={total_hostiles}  wrecks={wreck_count} wreck_matter={wreck_matter:.1f}")
    out.append("")

    # == RESOURCE FLOW TIMELINE ==
    init_hidden = sample_data.get("init_hidden", {})
    total_h_ts = sample_data.get("total_hidden_ts", [])
    total_d_ts = sample_data.get("total_disc_ts", [])
    total_s_ts = sample_data.get("total_stock_ts", [])
    total_w_ts = sample_data.get("total_wreck_ts", [])
    se = sample_data.get("sample_every", 1)

    out.append("RESOURCE_FLOW_TIMELINE:")
    if total_h_ts:
        def _at_tick(ts, tick):
            idx = tick // se - 1
            if idx < 0: idx = 0
            if idx >= len(ts): idx = len(ts) - 1
            return ts[idx]

        markers = [se, 100, 500, 1000, 5000, 10000, 25000, ticks_run]
        markers = sorted(set(t for t in markers if t <= ticks_run))
        parts_h = " ".join(f"t{t}={_at_tick(total_h_ts, t):.0f}" for t in markers)
        parts_d = " ".join(f"t{t}={_at_tick(total_d_ts, t):.0f}" for t in markers)
        parts_s = " ".join(f"t{t}={_at_tick(total_s_ts, t):.0f}" for t in markers)
        out.append(f"  hidden:     {parts_h}")
        out.append(f"  discovered: {parts_d}")
        out.append(f"  stockpile:  {parts_s}")
        if total_w_ts:
            parts_w = " ".join(f"t{t}={_at_tick(total_w_ts, t):.0f}" for t in markers)
            out.append(f"  wrecks:     {parts_w}")
    out.append("")

    # == DEPLETION MILESTONES ==
    hidden_m_ts = sample_data.get("hidden_mineral_ts", {})
    hidden_p_ts = sample_data.get("hidden_propellant_ts", {})
    if hidden_m_ts:
        out.append("DEPLETION_MILESTONES (<10% / <1% hidden remaining):")
        for sid in sectors:
            sh = sid.replace("station_", "").upper()
            ih = init_hidden.get(sid, {"m": 0, "p": 0})
            m1 = m10 = p1 = p10 = None
            hm_list = hidden_m_ts.get(sid, [])
            hp_list = hidden_p_ts.get(sid, [])
            for i, hm in enumerate(hm_list):
                if m10 is None and ih["m"] > 0 and hm / ih["m"] < 0.10:
                    m10 = (i + 1) * se
                if m1 is None and ih["m"] > 0 and hm / ih["m"] < 0.01:
                    m1 = (i + 1) * se
            for i, hp in enumerate(hp_list):
                if p10 is None and ih["p"] > 0 and hp / ih["p"] < 0.10:
                    p10 = (i + 1) * se
                if p1 is None and ih["p"] > 0 and hp / ih["p"] < 0.01:
                    p1 = (i + 1) * se
            out.append(f"  {sh}: mineral(<10%={m10 or 'never'} <1%={m1 or 'never'})  "
                       f"propellant(<10%={p10 or 'never'} <1%={p1 or 'never'})")
        out.append("")

    # == STOCKPILE DYNAMICS ==
    out.append("STOCKPILE_DYNAMICS:")
    for sid in sectors:
        sh = sid.replace("station_", "").upper()
        ts = sample_data.get("stockpile_ts", {}).get(sid, [])
        if ts:
            mn, mx = min(ts), max(ts)
            avg = sum(ts) / len(ts)
            std = math.sqrt(sum((x - avg) ** 2 for x in ts) / len(ts)) if len(ts) > 1 else 0
            out.append(f"  {sh}: min={mn:.0f} max={mx:.0f} avg={avg:.0f} std={std:.1f}")
    out.append("")

    # == PER-COMMODITY STOCKPILE BREAKDOWN (final) ==
    out.append("STOCKPILE_COMMODITIES (final):")
    header_coms = set()
    for sid in sectors:
        cs = s.grid_stockpiles.get(sid, {}).get("commodity_stockpiles", {})
        header_coms.update(cs.keys())
    header_coms = sorted(header_coms)
    if header_coms:
        com_short = [c.replace("commodity_", "")[:4] for c in header_coms]
        out.append("  sector   " + " ".join(f"{c:>7}" for c in com_short))
        for sid in sectors:
            sh = sid.replace("station_", "").upper()
            cs = s.grid_stockpiles.get(sid, {}).get("commodity_stockpiles", {})
            vals = " ".join(f"{cs.get(c, 0.0):>7.1f}" for c in header_coms)
            out.append(f"  {sh:<8} {vals}")
    out.append("")

    # == HAZARD DRIFT ==
    if s.world_hazards_base:
        out.append("HAZARD_DRIFT:")
        for sid in sectors:
            sh = sid.replace("station_", "").upper()
            br = s.world_hazards_base[sid]["radiation_level"]
            bt = s.world_hazards_base[sid]["thermal_background_k"]
            r_ts = sample_data.get("radiation_ts", {}).get(sid, [])
            t_ts = sample_data.get("thermal_ts", {}).get(sid, [])
            if r_ts:
                out.append(f"  {sh}: rad base={br:.4f} [{min(r_ts):.4f},{max(r_ts):.4f}]  "
                           f"therm base={bt:.0f} [{min(t_ts):.0f},{max(t_ts):.0f}]")
        out.append("")

    # == MARKET PRICES (final) ==
    out.append("MARKET_PRICES (delta from base):")
    for sid in sectors:
        sh = sid.replace("station_", "").upper()
        mkt = s.grid_market.get(sid, {})
        deltas = mkt.get("commodity_price_deltas", {})
        parts = " ".join(f"{k.replace('commodity_','')[:4]}{v:+.3f}" for k, v in sorted(deltas.items()))
        out.append(f"  {sh}: {parts}")
    out.append("")

    # == AGENT STATS (sampled aggregates) ==
    agent_hull_ts = sample_data.get("agent_hull_ts", {})
    agent_cash_ts = sample_data.get("agent_cash_ts", {})
    agent_debt_ts = sample_data.get("agent_debt_ts", {})
    if agent_hull_ts:
        out.append("AGENT_STATS (sampled aggregates):")
        out.append("  name         hull_avg hull_min cash_avg cash_max  debt_final")
        out.append("  " + "-" * 65)
        for name in sorted(agent_hull_ts.keys()):
            hulls = agent_hull_ts[name]
            cashes = agent_cash_ts.get(name, [0])
            debts = agent_debt_ts.get(name, [0])
            h_avg = sum(hulls) / len(hulls) if hulls else 0
            h_min = min(hulls) if hulls else 0
            c_avg = sum(cashes) / len(cashes) if cashes else 0
            c_max = max(cashes) if cashes else 0
            d_final = debts[-1] if debts else 0
            out.append(f"  {name:<12} {h_avg:>8.3f} {h_min:>8.3f} "
                       f"{c_avg:>8.0f} {c_max:>8.0f} {d_final:>10.0f}")
        out.append("")

    # == HOSTILE POPULATION TIMELINE ==
    hostile_ts = sample_data.get("hostile_total_ts", [])
    if hostile_ts and total_h_ts:
        out.append("HOSTILE_POP_TIMELINE:")
        markers2 = [se, 100, 500, 1000, 5000, 10000, 25000, ticks_run]
        markers2 = sorted(set(t for t in markers2 if t <= ticks_run))
        parts_hp = " ".join(f"t{t}={_at_tick(hostile_ts, t):.0f}" for t in markers2)
        out.append(f"  total: {parts_hp}")
        hmin = min(hostile_ts)
        hmax = max(hostile_ts)
        havg = sum(hostile_ts) / len(hostile_ts)
        out.append(f"  min={hmin} max={hmax} avg={havg:.1f}")
        out.append("")

    # == AGENT LIFECYCLE EVENTS ==
    lifecycle = sample_data.get("lifecycle_events", [])
    out.append(f"AGENT_LIFECYCLE: {len(lifecycle)} events")
    if lifecycle:
        show_n = 15
        if len(lifecycle) <= show_n * 2:
            for ev in lifecycle:
                out.append(f"  {ev}")
        else:
            for ev in lifecycle[:show_n]:
                out.append(f"  {ev}")
            out.append(f"  ... ({len(lifecycle) - show_n * 2} more)")
            for ev in lifecycle[-show_n:]:
                out.append(f"  {ev}")
    out.append("")

    # == CATASTROPHES ==
    out.append(f"CATASTROPHES: {len(s.catastrophe_log)} total")
    if s.catastrophe_log:
        show_c = min(8, len(s.catastrophe_log))
        for cat in s.catastrophe_log[-show_c:]:
            sh = cat.get("sector_id", "?").replace("station_", "").upper()
            tick = cat.get("tick", 0)
            matter = cat.get("matter_converted", 0.0)
            until = cat.get("disable_until", 0)
            out.append(f"  t={tick} {sh} matter={matter:.1f} disabled_until={until}")
    out.append("")

    # == DISABLED SECTORS ==
    active_disabled = {sid: until for sid, until in s.sector_disabled_until.items()
                       if until > s.sim_tick_count}
    if active_disabled:
        out.append("DISABLED_SECTORS:")
        for sid, until in sorted(active_disabled.items()):
            sh = sid.replace("station_", "").upper()
            out.append(f"  {sh}: until tick {until}")
        out.append("")

    # == COLONY LEVELS (final) ==
    out.append("COLONY_LEVELS (final):")
    for sid in sectors:
        sh = sid.replace("station_", "").upper()
        level = s.colony_levels.get(sid, "frontier")
        up_prog = s.colony_upgrade_progress.get(sid, 0)
        dn_prog = s.colony_downgrade_progress.get(sid, 0)
        out.append(f"  {sh}: {level:<10} upgrade_prog={up_prog:>4} downgrade_prog={dn_prog:>4}")
    if s.colony_level_history:
        out.append(f"  transitions ({len(s.colony_level_history)}):")
        show_cl = min(10, len(s.colony_level_history))
        for ev in s.colony_level_history[-show_cl:]:
            out.append(f"    {ev}")
    out.append("")

    # == MORTAL AGENTS ==
    mortal_count = sum(1 for a in s.agents.values()
                       if not a.get("is_persistent", True))
    mortal_alive = sum(1 for a in s.agents.values()
                       if not a.get("is_persistent", True) and not a.get("is_disabled", False))
    out.append(f"MORTAL_AGENTS: spawned_total={s.mortal_agent_counter} "
               f"currently_alive={mortal_alive} currently_tracked={mortal_count} "
               f"deaths={len(s.mortal_agent_deaths)}")
    if s.mortal_agent_deaths:
        show_md = min(10, len(s.mortal_agent_deaths))
        for ev in s.mortal_agent_deaths[-show_md:]:
            out.append(f"  {ev}")
    out.append("")

    # == SECTOR DISCOVERY ==
    out.append(f"SECTOR_DISCOVERY: discovered={s.discovered_sector_count} "
               f"total_sectors={len(sectors)}")
    if s.discovery_log:
        for ev in s.discovery_log:
            out.append(f"  {ev}")
    out.append("")

    # == CHRONICLE ==
    out.append(f"CHRONICLE: {len(s.chronicle_rumors)} rumors, last 8:")
    for r in s.chronicle_rumors[-8:]:
        out.append(f"  {r}")
    out.append("")

    # ================================================================
    # TRANSIENT STATES  tick-by-tick snapshots for head/tail windows
    # ================================================================
    if transient_head or transient_tail:
        out.append("=" * 80)
        out.append("TRANSIENT STATES (tick-by-tick)")
        out.append("=" * 80)
        out.append("")

        all_blocks = []
        if transient_head:
            all_blocks.append(("HEAD", transient_head))
        if transient_tail:
            all_blocks.append(("TAIL", transient_tail))

        for label, snapshots in all_blocks:
            if not snapshots:
                continue
            tick_range = f"t{snapshots[0]['tick']}..t{snapshots[-1]['tick']}"
            out.append(f"-- {label} ({tick_range}) --")
            out.append("")

            sec_names = sorted(snapshots[0]["sectors"].keys())
            agent_names = sorted(snapshots[0]["agents"].keys())

            # -- Sector table: one row per tick, columns = per-sector key metrics --
            out.append(f"  SECTORS ({label}):")
            # Header: tick age | SEC1:stk/hM/sec/pir/hos | SEC2:... |
            hdr_parts = []
            for sn in sec_names:
                hdr_parts.append(f"{sn}:stk hM hP sec pir hos")
            out.append(f"  {'tick':>5} {'age':>4} | " + " | ".join(hdr_parts))
            for snap in snapshots:
                t = snap["tick"]
                age = snap["age"][:4]
                row_parts = []
                for sn in sec_names:
                    sd = snap["sectors"].get(sn, {})
                    row_parts.append(
                        f"{sn}:{sd.get('stk',0):>4.0f} "
                        f"{sd.get('hM',0):>4.0f} "
                        f"{sd.get('hP',0):>4.0f} "
                        f"{sd.get('sec',0):.2f} "
                        f"{sd.get('pir',0):.3f} "
                        f"{sd.get('hos',0):.3f}"
                    )
                out.append(f"  {t:>5} {age:>4} | " + " | ".join(row_parts))
            out.append("")

            # -- Agent state table --
            out.append(f"  AGENTS ({label}):  format= hull/cash/goal  (X=disabled)")
            hdr = f"  {'tick':>5} |"
            for n in agent_names:
                hdr += f" {n[:7]:>10} |"
            out.append(hdr)
            for snap in snapshots:
                t = snap["tick"]
                row = f"  {t:>5} |"
                for n in agent_names:
                    ad = snap["agents"].get(n, {})
                    if ad.get("x", 0):
                        cell = "DEAD"
                    else:
                        h = ad.get("h", 0)
                        c = ad.get("c", 0)
                        g = ad.get("g", "?")[:3]
                        cell = f"{h:.2f}/{c:.0f}/{g}"
                    row += f" {cell:>10} |"
                out.append(row)
            out.append("")

            # -- Agent debt table (only if any debt exists) --
            has_debt = any(
                snap["agents"].get(n, {}).get("d", 0) > 0
                for snap in snapshots for n in agent_names
            )
            if has_debt:
                out.append(f"  DEBT ({label}):")
                hdr = f"  {'tick':>5} |"
                for n in agent_names:
                    hdr += f" {n[:7]:>8} |"
                out.append(hdr)
                for snap in snapshots:
                    t = snap["tick"]
                    row = f"  {t:>5} |"
                    for n in agent_names:
                        d = snap["agents"].get(n, {}).get("d", 0)
                        row += f" {d:>8.0f} |"
                    out.append(row)
                out.append("")

            # -- Hostiles per tick --
            out.append(f"  HOSTILES ({label}):")
            htypes = sorted(snapshots[0]["hostiles"].keys())
            for snap in snapshots:
                t = snap["tick"]
                parts = []
                for ht in htypes:
                    hd = snap["hostiles"].get(ht, {})
                    n = hd.get("n", 0)
                    dist = hd.get("d", {})
                    ds = " ".join(f"{k}={v}" for k, v in sorted(dist.items()))
                    parts.append(f"{ht}={n}[{ds}]")
                out.append(f"  {t:>5}: " + "  ".join(parts))
            out.append("")

            # -- Wrecks + matter per tick --
            out.append(f"  WRECKS_MATTER ({label}):")
            out.append(f"  {'tick':>5}  wrecks wreck_matter hostile_pool agent_inv")
            for snap in snapshots:
                t = snap["tick"]
                w = snap["wrecks"]
                m = snap["matter"]
                out.append(f"  {t:>5}  {w['count']:>6} {w['matter']:>12.2f} "
                           f"{m.get('hostil', 0):>12.2f} "
                           f"{m.get('agent_', 0):>9.2f}")
            out.append("")

            # -- Axiom 1 drift per tick --
            out.append(f"  AXIOM1 ({label}):")
            for snap in snapshots:
                t = snap["tick"]
                d = snap["drift"]
                rel = d / max(init_matter, 1.0) * 100.0
                out.append(f"  {t:>5}: drift={d:.2f} ({rel:.4f}%)")
            out.append("")

    out.append("=== END REPORT ===")
    return "\n".join(out)


# -----------------------------------------------------------------
# Main
# -----------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="GDTLancer Simulation Sandbox")
    parser.add_argument("--ticks", type=int, default=10,
                        help="Number of simulation ticks (default: 10)")
    parser.add_argument("--seed", type=str, default="default_seed",
                        help="World generation seed (default: 'default_seed')")
    parser.add_argument("--sample-every", type=int, default=0,
                        help="Sample metrics every N ticks (default: auto)")
    parser.add_argument("--quiet", action="store_true",
                        help="Suppress progress dots, print only final report")
    parser.add_argument("--head", type=int, default=10,
                        help="Ticks for transient head window (default: 10)")
    parser.add_argument("--tail", type=int, default=10,
                        help="Ticks for transient tail window (default: 10)")
    args = parser.parse_args()

    head_n = args.head
    tail_n = args.tail

    # Auto sample interval: ~1000 data points max
    sample_every = args.sample_every if args.sample_every > 0 else max(1, args.ticks // 1000)

    # Suppress layer spam
    import builtins
    builtins.print = _quiet_print

    engine = SimulationEngine()
    engine.initialize_simulation(args.seed)

    builtins.print = _original_print

    sectors = sorted(engine.state.world_topology.keys())
    init_matter = engine.state.world_total_matter

    # Snapshot initial hidden resources
    init_hidden = {}
    for sid in sectors:
        h = engine.state.world_hidden_resources.get(sid, {})
        init_hidden[sid] = {
            "m": h.get("mineral_density", 0.0),
            "p": h.get("propellant_sources", 0.0),
        }

    # Tracking arrays (sampled at sample_every interval)
    axiom1_drifts = []
    hidden_mineral_ts = {sid: [] for sid in sectors}
    hidden_propellant_ts = {sid: [] for sid in sectors}
    total_hidden_ts = []
    total_disc_ts = []
    total_stock_ts = []
    total_wreck_ts = []
    stockpile_ts = {sid: [] for sid in sectors}
    radiation_ts = {sid: [] for sid in sectors}
    thermal_ts = {sid: [] for sid in sectors}
    age_transitions = []
    prev_age = engine.state.world_age

    # Agent time series (sampled)
    agent_hull_ts = {}
    agent_cash_ts = {}
    agent_debt_ts = {}
    hostile_total_ts = []

    # Lifecycle events
    lifecycle_events = []

    # Transient snapshots (tick-by-tick, step=1)
    transient_head = []
    transient_tail = []

    if not args.quiet:
        _original_print(f"Running {args.ticks} ticks (sample every {sample_every}, "
                        f"head={head_n}, tail={tail_n})...", end="", flush=True)

    # Suppress layer spam during tick loop
    builtins.print = _quiet_print

    for tick in range(1, args.ticks + 1):
        # Pre-tick state for lifecycle detection
        pre_disabled = {aid: a.get("is_disabled", False)
                        for aid, a in engine.state.agents.items()}

        engine.process_tick()

        # Age transitions
        if engine.state.world_age != prev_age:
            age_transitions.append((tick, prev_age, engine.state.world_age))
            prev_age = engine.state.world_age

        # Lifecycle events: disabled/respawned
        for aid, a in engine.state.agents.items():
            if aid == "player":
                continue
            was_disabled = pre_disabled.get(aid, False)
            is_disabled = a.get("is_disabled", False)
            char_uid = a.get("char_uid", -1)
            ch = engine.state.characters.get(char_uid, {})
            name = ch.get("character_name", f"U{char_uid}")
            if is_disabled and not was_disabled:
                lifecycle_events.append(
                    f"t={tick} {name} DISABLED hull={a.get('hull_integrity',0):.2f} "
                    f"cash={a.get('cash_reserves',0):.0f} debt={a.get('debt',0):.0f}")
            elif was_disabled and not is_disabled:
                lifecycle_events.append(
                    f"t={tick} {name} RESPAWNED cash={a.get('cash_reserves',0):.0f} "
                    f"debt={a.get('debt',0):.0f}")

        # Transient snapshot (every tick for head/tail windows)
        in_head = tick <= head_n
        in_tail = tick > args.ticks - tail_n

        if in_head or in_tail:
            actual = engine._calculate_total_matter()
            snap = {
                "tick": tick,
                "age": engine.state.world_age,
                "agents": _snapshot_agents(engine.state),
                "sectors": _snapshot_sectors(engine.state),
                "hostiles": _snapshot_hostiles(engine.state),
                "wrecks": _snapshot_wrecks(engine.state),
                "matter": _snapshot_matter(engine),
                "drift": abs(actual - init_matter),
            }
            if in_head:
                transient_head.append(snap)
            if in_tail:
                transient_tail.append(snap)

        # Periodic sample
        if tick % sample_every == 0:
            actual = engine._calculate_total_matter()
            axiom1_drifts.append(abs(actual - init_matter))

            total_h = total_d = total_s = 0.0
            current_sectors = sorted(engine.state.world_topology.keys())
            for sid in current_sectors:
                h = engine.state.world_hidden_resources.get(sid, {})
                p = engine.state.world_resource_potential.get(sid, {})
                hm = h.get("mineral_density", 0.0)
                hp = h.get("propellant_sources", 0.0)
                dm = p.get("mineral_density", 0.0)
                dp = p.get("propellant_sources", 0.0)
                hidden_mineral_ts.setdefault(sid, []).append(hm)
                hidden_propellant_ts.setdefault(sid, []).append(hp)
                total_h += hm + hp
                total_d += dm + dp

                stock = engine.state.grid_stockpiles.get(sid, {})
                stot = sum(float(v) for v in stock.get("commodity_stockpiles", {}).values())
                stockpile_ts.setdefault(sid, []).append(stot)
                total_s += stot

                hazards = engine.state.world_hazards.get(sid, {})
                radiation_ts.setdefault(sid, []).append(hazards.get("radiation_level", 0.0))
                thermal_ts.setdefault(sid, []).append(hazards.get("thermal_background_k", 300.0))

            total_hidden_ts.append(total_h)
            total_disc_ts.append(total_d)
            total_stock_ts.append(total_s)

            # Wreck matter
            wreck_matter = 0.0
            for w in engine.state.grid_wrecks.values():
                wreck_matter += w.get("wreck_integrity", 0.0)
                for qty in w.get("wreck_inventory", {}).values():
                    wreck_matter += float(qty)
            total_wreck_ts.append(wreck_matter)

            # Hostile total
            htot = sum(pop.get("current_count", 0)
                       for pop in engine.state.hostile_population_integral.values())
            hostile_total_ts.append(htot)

            # Agent stats
            for aid, a in engine.state.agents.items():
                if aid == "player":
                    continue
                char_uid = a.get("char_uid", -1)
                ch = engine.state.characters.get(char_uid, {})
                name = ch.get("character_name", f"U{char_uid}")
                agent_hull_ts.setdefault(name, []).append(a.get("hull_integrity", 0.0))
                agent_cash_ts.setdefault(name, []).append(a.get("cash_reserves", 0.0))
                agent_debt_ts.setdefault(name, []).append(a.get("debt", 0.0))

            # Progress dot every 10%
            if not args.quiet and tick % max(1, args.ticks // 10) < sample_every:
                builtins.print = _original_print
                _original_print(".", end="", flush=True)
                builtins.print = _quiet_print

    builtins.print = _original_print
    if not args.quiet:
        _original_print(" done.")

    sample_data = {
        "axiom1_drifts": axiom1_drifts,
        "init_hidden": init_hidden,
        "total_hidden_ts": total_hidden_ts,
        "total_disc_ts": total_disc_ts,
        "total_stock_ts": total_stock_ts,
        "total_wreck_ts": total_wreck_ts,
        "stockpile_ts": stockpile_ts,
        "hidden_mineral_ts": hidden_mineral_ts,
        "hidden_propellant_ts": hidden_propellant_ts,
        "radiation_ts": radiation_ts,
        "thermal_ts": thermal_ts,
        "sample_every": sample_every,
        "lifecycle_events": lifecycle_events,
        "agent_hull_ts": agent_hull_ts,
        "agent_cash_ts": agent_cash_ts,
        "agent_debt_ts": agent_debt_ts,
        "hostile_total_ts": hostile_total_ts,
    }

    report = generate_report(engine, args.ticks, sample_data, age_transitions,
                             transient_head, transient_tail, head_n, tail_n)
    _original_print(report)


if __name__ == "__main__":
    main()
