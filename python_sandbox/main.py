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
    )
    if any(msg.startswith(p) for p in prefixes):
        return
    _original_print(*a, **kw)


# -----------------------------------------------------------------
# Report generation
# -----------------------------------------------------------------
def generate_report(engine, ticks_run, sample_data, age_transitions):
    """Produce a single structured report after the run completes."""
    s = engine.state
    sectors = sorted(s.world_topology.keys())
    init_matter = s.world_total_matter
    actual_matter = engine._calculate_total_matter()
    drift = abs(actual_matter - init_matter)

    out = []
    out.append(f"=== Simulation Report: {ticks_run} ticks, seed='{s.world_seed}' ===")
    out.append("")

    # -- Axiom 1 --
    drifts = sample_data["axiom1_drifts"]
    max_d = max(drifts) if drifts else drift
    avg_d = sum(drifts) / len(drifts) if drifts else drift
    out.append(f"AXIOM_1: max_drift={max_d:.8f} avg_drift={avg_d:.8f} "
               f"budget={init_matter:.2f} final={actual_matter:.2f}")

    # -- World Age --
    out.append(f"WORLD_AGE: current={s.world_age} cycles_completed={s.world_age_cycle_count} "
               f"transitions={len(age_transitions)}")
    if age_transitions:
        out.append(f"  first_3: {age_transitions[:3]}")
        out.append(f"  last_3:  {age_transitions[-3:]}")
    out.append("")

    # -- Per-sector table --
    out.append("SECTOR_STATE:")
    out.append("  sector     | type     | disc_M    disc_P   | hidden_M  hidden_P | "
               "stock_tot | sec   piracy | dominant    | rad     therm_K")
    out.append("  " + "-" * 115)
    for sid in sectors:
        short = sid.replace("station_", "").upper()
        topo = s.world_topology[sid]
        stype = topo.get("sector_type", "?")[:8]
        pot = s.world_resource_potential.get(sid, {})
        hid = s.world_hidden_resources.get(sid, {})
        stock = s.grid_stockpiles.get(sid, {})
        dom = s.grid_dominion.get(sid, {})
        hazards = s.world_hazards.get(sid, {})

        disc_m = pot.get("mineral_density", 0.0)
        disc_p = pot.get("propellant_sources", 0.0)
        hid_m = hid.get("mineral_density", 0.0)
        hid_p = hid.get("propellant_sources", 0.0)
        stot = sum(float(v) for v in stock.get("commodity_stockpiles", {}).values())
        sec = dom.get("security_level", 0.0)
        pir = dom.get("pirate_activity", 0.0)
        fi = dom.get("faction_influence", {})
        dominant = max(fi, key=fi.get).replace("faction_", "") if fi else "none"
        rad = hazards.get("radiation_level", 0.0)
        therm = hazards.get("thermal_background_k", 0.0)

        out.append(f"  {short:<10} {stype:<8}  {disc_m:>8.1f} {disc_p:>8.1f}   "
                   f"{hid_m:>8.1f} {hid_p:>8.1f}   {stot:>8.1f}   "
                   f"{sec:.2f}  {pir:.4f}   {dominant:<12} {rad:.4f}  {therm:.0f}")
    out.append("")

    # -- Matter breakdown --
    bd = engine._matter_breakdown()
    total = sum(bd.values())
    out.append("MATTER_BREAKDOWN:")
    for k, v in bd.items():
        pct = v / total * 100 if total > 0 else 0
        out.append(f"  {k}: {v:.2f} ({pct:.1f}%)")
    out.append("")

    # -- Hidden resource depletion timeline --
    init_hidden = sample_data.get("init_hidden", {})
    out.append("HIDDEN_DEPLETION:")
    total_h_ts = sample_data.get("total_hidden_ts", [])
    total_d_ts = sample_data.get("total_disc_ts", [])
    total_s_ts = sample_data.get("total_stock_ts", [])
    se = sample_data.get("sample_every", 1)

    if total_h_ts:
        def _at_tick(ts, tick):
            idx = tick // se - 1
            if idx < 0: idx = 0
            if idx >= len(ts): idx = len(ts) - 1
            return ts[idx]

        markers = [se, 1000, 5000, 10000, 25000, ticks_run]
        markers = sorted(set(t for t in markers if t <= ticks_run))
        parts_h = " ".join(f"t{t}={_at_tick(total_h_ts, t):.0f}" for t in markers)
        parts_d = " ".join(f"t{t}={_at_tick(total_d_ts, t):.0f}" for t in markers)
        parts_s = " ".join(f"t{t}={_at_tick(total_s_ts, t):.0f}" for t in markers)
        out.append(f"  hidden_total:     {parts_h}")
        out.append(f"  discovered_total: {parts_d}")
        out.append(f"  stockpile_total:  {parts_s}")
    out.append("")

    # -- Depletion milestones --
    hidden_m_ts = sample_data.get("hidden_mineral_ts", {})
    hidden_p_ts = sample_data.get("hidden_propellant_ts", {})
    if hidden_m_ts:
        out.append("DEPLETION_MILESTONES (<1% hidden remaining):")
        for sid in sectors:
            short = sid.replace("station_", "").upper()
            ih = init_hidden.get(sid, {"m": 0, "p": 0})
            m_dep = p_dep = None
            hm_list = hidden_m_ts.get(sid, [])
            hp_list = hidden_p_ts.get(sid, [])
            for i, hm in enumerate(hm_list):
                if m_dep is None and ih["m"] > 0 and hm / ih["m"] < 0.01:
                    m_dep = (i + 1) * se
            for i, hp in enumerate(hp_list):
                if p_dep is None and ih["p"] > 0 and hp / ih["p"] < 0.01:
                    p_dep = (i + 1) * se
            out.append(f"  {short}: mineral_<1%={m_dep or 'never'}  propellant_<1%={p_dep or 'never'}")
        out.append("")

    # -- Stockpile dynamics --
    out.append("STOCKPILE_DYNAMICS:")
    for sid in sectors:
        short = sid.replace("station_", "").upper()
        ts = sample_data.get("stockpile_ts", {}).get(sid, [])
        if ts:
            mn, mx = min(ts), max(ts)
            avg = sum(ts) / len(ts)
            std = math.sqrt(sum((x - avg) ** 2 for x in ts) / len(ts))
            out.append(f"  {short}: min={mn:.1f} max={mx:.1f} avg={avg:.1f} std={std:.1f}")
    out.append("")

    # -- Hazard drift --
    if s.world_hazards_base:
        out.append("HAZARD_DRIFT:")
        for sid in sectors:
            short = sid.replace("station_", "").upper()
            base_r = s.world_hazards_base[sid]["radiation_level"]
            base_t = s.world_hazards_base[sid]["thermal_background_k"]
            r_ts = sample_data.get("radiation_ts", {}).get(sid, [])
            t_ts = sample_data.get("thermal_ts", {}).get(sid, [])
            if r_ts:
                out.append(f"  {short}: rad_base={base_r:.4f} range=[{min(r_ts):.4f},{max(r_ts):.4f}]  "
                           f"therm_base={base_t:.0f} range=[{min(t_ts):.0f},{max(t_ts):.0f}]")
        out.append("")

    # -- Agent summary --
    out.append("AGENTS:")
    for agent_id in sorted(s.agents.keys()):
        agent = s.agents[agent_id]
        char_uid = agent.get("char_uid", -1)
        char_data = s.characters.get(char_uid, {})
        name = char_data.get("character_name", f"UID:{char_uid}")
        sector = agent.get("current_sector_id", "?").replace("station_", "")
        hull = agent.get("hull_integrity", 0.0)
        cash = agent.get("cash_reserves", 0.0)
        goal = agent.get("goal_archetype", "?")
        disabled = agent.get("is_disabled", False)
        status = "DISABLED" if disabled else f"hull={hull:.2f}"
        out.append(f"  {name}: sector={sector} {status} cash={cash:.0f} goal={goal}")
    out.append("")

    # -- Hostile population --
    out.append("HOSTILES:")
    for htype, pop in s.hostile_population_integral.items():
        count = pop.get("current_count", 0)
        cap = pop.get("carrying_capacity", 0)
        dist = pop.get("sector_counts", {})
        dist_str = " ".join(f"{k.replace('station_','')}={v}" for k, v in sorted(dist.items()))
        out.append(f"  {htype}: {count}/{cap}  [{dist_str}]")
    out.append("")

    # -- Market prices (final) --
    out.append("MARKET_PRICES (delta from base):")
    for sid in sectors:
        short = sid.replace("station_", "").upper()
        mkt = s.grid_market.get(sid, {})
        deltas = mkt.get("commodity_price_deltas", {})
        parts = " ".join(f"{k.replace('commodity_','')}{v:+.3f}" for k, v in sorted(deltas.items()))
        out.append(f"  {short}: {parts}")
    out.append("")

    # -- Chronicle (last 5) --
    out.append(f"CHRONICLE: {len(s.chronicle_rumors)} total rumors, last 5:")
    for r in s.chronicle_rumors[-5:]:
        out.append(f"  {r}")

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
    args = parser.parse_args()

    # Auto sample interval: ~1000 data points max
    sample_every = args.sample_every if args.sample_every > 0 else max(1, args.ticks // 1000)

    # Suppress layer spam
    import builtins
    builtins.print = _quiet_print

    engine = SimulationEngine()
    engine.initialize_simulation(args.seed)

    builtins.print = _original_print

    sectors = sorted(engine.state.world_topology.keys())

    # Snapshot initial hidden resources
    init_hidden = {}
    for sid in sectors:
        h = engine.state.world_hidden_resources.get(sid, {})
        init_hidden[sid] = {
            "m": h.get("mineral_density", 0.0),
            "p": h.get("propellant_sources", 0.0),
        }

    # Tracking arrays
    axiom1_drifts = []
    hidden_mineral_ts = {sid: [] for sid in sectors}
    hidden_propellant_ts = {sid: [] for sid in sectors}
    total_hidden_ts = []
    total_disc_ts = []
    total_stock_ts = []
    stockpile_ts = {sid: [] for sid in sectors}
    radiation_ts = {sid: [] for sid in sectors}
    thermal_ts = {sid: [] for sid in sectors}
    age_transitions = []
    prev_age = engine.state.world_age
    init_matter = engine.state.world_total_matter

    if not args.quiet:
        _original_print(f"Running {args.ticks} ticks (sample every {sample_every})...", end="", flush=True)

    # Suppress layer spam during tick loop
    builtins.print = _quiet_print

    for tick in range(1, args.ticks + 1):
        engine.process_tick()

        # Track age transitions
        if engine.state.world_age != prev_age:
            age_transitions.append((tick, prev_age, engine.state.world_age))
            prev_age = engine.state.world_age

        # Sample
        if tick % sample_every == 0:
            actual = engine._calculate_total_matter()
            axiom1_drifts.append(abs(actual - init_matter))

            total_h = total_d = total_s = 0.0
            for sid in sectors:
                h = engine.state.world_hidden_resources.get(sid, {})
                p = engine.state.world_resource_potential.get(sid, {})
                hm = h.get("mineral_density", 0.0)
                hp = h.get("propellant_sources", 0.0)
                dm = p.get("mineral_density", 0.0)
                dp = p.get("propellant_sources", 0.0)
                hidden_mineral_ts[sid].append(hm)
                hidden_propellant_ts[sid].append(hp)
                total_h += hm + hp
                total_d += dm + dp

                stock = engine.state.grid_stockpiles.get(sid, {})
                stot = sum(float(v) for v in stock.get("commodity_stockpiles", {}).values())
                stockpile_ts[sid].append(stot)
                total_s += stot

                hazards = engine.state.world_hazards.get(sid, {})
                radiation_ts[sid].append(hazards.get("radiation_level", 0.0))
                thermal_ts[sid].append(hazards.get("thermal_background_k", 300.0))

            total_hidden_ts.append(total_h)
            total_disc_ts.append(total_d)
            total_stock_ts.append(total_s)

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
        "stockpile_ts": stockpile_ts,
        "hidden_mineral_ts": hidden_mineral_ts,
        "hidden_propellant_ts": hidden_propellant_ts,
        "radiation_ts": radiation_ts,
        "thermal_ts": thermal_ts,
        "sample_every": sample_every,
    }

    report = generate_report(engine, args.ticks, sample_data, age_transitions)
    _original_print(report)


if __name__ == "__main__":
    main()
