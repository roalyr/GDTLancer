#!/usr/bin/env python3
"""
GDTLancer Simulation Sandbox — CLI runner.

Usage:
    python main.py                  # 10 ticks, default seed
    python main.py --ticks 50       # 50 ticks
    python main.py --seed hello     # custom seed
    python main.py --verbose        # print every tick
    python main.py --dump-every 5   # dump state every 5 ticks
"""

import argparse
import sys
import os

# Ensure the sandbox directory is on the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from simulation_engine import SimulationEngine
import cli_viz
import ncurses_viz


def dump_state(engine: SimulationEngine, label: str = "") -> None:
    """Print a comprehensive state dump, similar to F3 SimDebugPanel."""
    s = engine.state
    tick = s.sim_tick_count
    matter_actual = engine._calculate_total_matter()
    matter_expected = s.world_total_matter
    drift = abs(matter_actual - matter_expected)
    axiom_ok = drift <= engine._tick_config.get("axiom1_tolerance", 0.01)

    lines = []
    lines.append("=" * 70)
    if label:
        lines.append(f"  {label}")
    lines.append(f"  Tick: {tick}  |  Seed: {s.world_seed}")
    lines.append(
        f"  Axiom 1: {'PASS' if axiom_ok else 'FAIL'}  "
        f"(expected: {matter_expected:.2f}, actual: {matter_actual:.2f}, "
        f"drift: {drift:.4f})"
    )
    lines.append("=" * 70)

    # --- Matter Breakdown ---
    bd = engine._matter_breakdown()
    lines.append(
        f"  Matter breakdown: resource_potential={bd['resource_potential']:.2f}  "
        f"grid_stockpiles={bd['grid_stockpiles']:.2f}  "
        f"wrecks={bd['wrecks']:.2f}  "
        f"agent_inv={bd['agent_inventories']:.2f}"
    )

    # --- Grid Layer per sector ---
    lines.append("")
    lines.append("  --- GRID LAYER (per sector) ---")
    for sector_id in sorted(s.world_topology.keys()):
        topology = s.world_topology[sector_id]
        sector_type = topology.get("sector_type", "?")

        # Stockpiles
        stockpile = s.grid_stockpiles.get(sector_id, {})
        commodities = stockpile.get("commodity_stockpiles", {})
        commodity_str = "  ".join(
            f"{_strip_prefix(k)}={v:.0f}" for k, v in sorted(commodities.items())
        )

        # Resource potential
        potential = s.world_resource_potential.get(sector_id, {})
        mineral = potential.get("mineral_density", 0.0)
        propellant = potential.get("propellant_sources", 0.0)

        # Dominion
        dominion = s.grid_dominion.get(sector_id, {})
        faction_inf = dominion.get("faction_influence", {})
        dominant = max(faction_inf, key=faction_inf.get) if faction_inf else "none"
        dominant = _strip_prefix(dominant)
        security = dominion.get("security_level", 0.0)
        piracy = dominion.get("pirate_activity", 0.0)

        # Market
        market = s.grid_market.get(sector_id, {})
        price_deltas = market.get("commodity_price_deltas", {})
        price_str = "  ".join(
            f"{_strip_prefix(k)}={v:+.3f}" for k, v in sorted(price_deltas.items())
        )

        lines.append(
            f"  [{sector_id}] ({sector_type})  "
            f"dominant={dominant}  sec={security:.2f}  piracy={piracy:.2f}"
        )
        lines.append(
            f"    stockpiles: {commodity_str}"
        )
        lines.append(
            f"    potential: mineral={mineral:.1f}  propellant={propellant:.1f}"
        )
        lines.append(
            f"    prices: {price_str}"
        )

    # --- Agent Layer ---
    lines.append("")
    lines.append("  --- AGENTS ---")
    for agent_id in sorted(s.agents.keys()):
        agent = s.agents[agent_id]
        char_uid = agent.get("char_uid", -1)
        char_data = s.characters.get(char_uid, {})
        name = char_data.get("character_name", f"UID:{char_uid}")
        sector = agent.get("current_sector_id", "?")
        hull = agent.get("hull_integrity", 0.0)
        cash = agent.get("cash_reserves", 0.0)
        goal = agent.get("goal_archetype", "?")
        disabled = agent.get("is_disabled", False)

        # Inventory
        inv_str = ""
        if char_uid in s.inventories and 2 in s.inventories[char_uid]:
            inv = s.inventories[char_uid][2]
            if inv:
                inv_str = "  cargo: " + ", ".join(
                    f"{_strip_prefix(k)}={v:.0f}" for k, v in inv.items() if v > 0
                )

        status = "DISABLED" if disabled else f"hull={hull:.2f}"
        lines.append(
            f"  {agent_id} ({name}): sector={sector}  {status}  "
            f"cash={cash:.0f}  goal={goal}{inv_str}"
        )

    # --- Hostile Population ---
    lines.append("")
    lines.append("  --- HOSTILE POPULATION ---")
    for hostile_type, pop_data in s.hostile_population_integral.items():
        count = pop_data.get("current_count", 0)
        capacity = pop_data.get("carrying_capacity", 0)
        sector_counts = pop_data.get("sector_counts", {})
        dist_str = "  ".join(
            f"{sid}={c}" for sid, c in sorted(sector_counts.items())
        )
        lines.append(
            f"  {hostile_type}: {count}/{capacity}  [{dist_str}]"
        )

    # --- Chronicle ---
    lines.append("")
    lines.append(f"  --- CHRONICLE (last 5 rumors of {len(s.chronicle_rumors)}) ---")
    for rumor in s.chronicle_rumors[-5:]:
        lines.append(f"    {rumor}")

    lines.append("=" * 70)
    print("\n".join(lines))


def _strip_prefix(s: str) -> str:
    """Strip common prefixes for compact display."""
    for prefix in ("commodity_", "faction_", "persistent_"):
        if s.startswith(prefix):
            return s[len(prefix):]
    return s


def main():
    parser = argparse.ArgumentParser(
        description="GDTLancer Simulation Sandbox"
    )
    parser.add_argument(
        "--ticks", type=int, default=10,
        help="Number of simulation ticks to run (default: 10)"
    )
    parser.add_argument(
        "--seed", type=str, default="default_seed",
        help="World generation seed (default: 'default_seed')"
    )
    parser.add_argument(
        "--verbose", action="store_true",
        help="Print init messages from each layer"
    )
    parser.add_argument(
        "--dump-every", type=int, default=0,
        help="Dump full state every N ticks (0 = only at end)"
    )
    parser.add_argument(
        "--viz", action="store_true",
        help="Show colored CLI dashboard at start and end"
    )
    parser.add_argument(
        "--viz-every", type=int, default=0,
        help="Show full colored dashboard every N ticks (0 = only start/end)"
    )
    parser.add_argument(
        "--viz-stream", action="store_true",
        help="Print compact colored tick summary every tick"
    )
    parser.add_argument(
        "--tui", action="store_true",
        help="Launch interactive ncurses dashboard (1 tick/sec, real-time)"
    )
    args = parser.parse_args()

    # --- ncurses TUI mode: launch and exit ---
    if args.tui:
        ncurses_viz.run_tui(seed=args.seed, max_ticks=args.ticks)
        return

    # Suppress layer prints unless verbose
    if not args.verbose:
        import builtins
        _original_print = builtins.print

        def _quiet_print(*a, **kw):
            # Only suppress lines starting with known layer prefixes
            msg = " ".join(str(x) for x in a)
            prefixes = (
                "WorldLayer:", "GridLayer:", "AgentLayer:",
                "SimulationEngine:", "BridgeSystems:", "ChronicleLayer:",
            )
            if any(msg.startswith(p) for p in prefixes):
                return
            _original_print(*a, **kw)

        builtins.print = _quiet_print

    engine = SimulationEngine()
    engine.initialize_simulation(args.seed)

    # Restore print for dumps
    if not args.verbose:
        import builtins
        builtins.print = _original_print  # type: ignore

    # Show initial state
    if args.viz or args.viz_every:
        cli_viz.print_dashboard(engine, tick_label="POST-INITIALIZATION")
    else:
        dump_state(engine, label="POST-INITIALIZATION (Tick 0)")

    for i in range(1, args.ticks + 1):
        if not args.verbose:
            import builtins
            builtins.print = _quiet_print  # type: ignore

        engine.process_tick()

        if not args.verbose:
            import builtins
            builtins.print = _original_print  # type: ignore

        if args.dump_every and i % args.dump_every == 0:
            dump_state(engine, label=f"TICK {i}")

        if args.viz_every and i % args.viz_every == 0:
            cli_viz.print_dashboard(engine, tick_label=f"TICK {i}")
        elif args.viz_stream:
            cli_viz.print_tick_summary(engine)

    # Show final state
    if args.viz or args.viz_every:
        cli_viz.print_dashboard(engine, tick_label=f"FINAL ({args.ticks} ticks)")
    else:
        dump_state(engine, label=f"FINAL STATE (after {args.ticks} ticks)")


if __name__ == "__main__":
    main()
