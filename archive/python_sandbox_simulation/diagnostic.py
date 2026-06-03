#!/usr/bin/env python3
"""Diagnostic probe: quantifies simulation behavior over a long run."""
import os, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from core.simulation.simulation_engine import SimulationEngine

engine = SimulationEngine()
engine.initialize_simulation("diagnostic-probe")

action_counts = collections.Counter()
sector_economy_history = {sid: [] for sid in engine.state.world_topology}
sector_security_history = {sid: [] for sid in engine.state.world_topology}
sector_env_history = {sid: [] for sid in engine.state.world_topology}
agent_condition_history = collections.Counter()
agent_wealth_history = collections.Counter()
agent_cargo_history = collections.Counter()
agent_sector_distribution = collections.Counter()
world_age_log = []
mortal_spawns = 0
mortal_deaths = 0
attacks = 0
trades = 0
prev_age = engine.state.world_age
phase_economy_samples = collections.defaultdict(lambda: collections.Counter())
phase_security_samples = collections.defaultdict(lambda: collections.Counter())

for tick in range(1, 1801):  # 2 full cycles
    engine.process_tick()
    
    # Track world age transitions
    if engine.state.world_age != prev_age:
        world_age_log.append((tick, prev_age, engine.state.world_age))
        prev_age = engine.state.world_age
    
    # Track actions from events
    for ev in engine.state.chronicle_events:
        if ev.get("tick") == tick:
            action_counts[ev["action"]] += 1
            if ev["action"] == "spawn":
                mortal_spawns += 1
            if ev["action"] == "attack":
                attacks += 1
            if ev["action"] == "agent_trade":
                trades += 1
    
    # Sector state every 10 ticks
    if tick % 10 == 0:
        for sid, tags in engine.state.sector_tags.items():
            econ = [t for t in tags if t.startswith(("RAW_", "MANUFACTURED_", "CURRENCY_"))]
            sec = [t for t in tags if t in {"SECURE", "CONTESTED", "LAWLESS"}]
            env = [t for t in tags if t in {"MILD", "HARSH", "EXTREME"}]
            sector_economy_history[sid].append(sorted(econ))
            sector_security_history[sid].append(sec)
            sector_env_history[sid].append(env)
            # track by phase
            phase = engine.state.world_age
            for tag in econ:
                phase_economy_samples[phase][tag] += 1
            for tag in sec:
                phase_security_samples[phase][tag] += 1
    
    # Agent state every 10 ticks
    if tick % 10 == 0:
        for aid, agent in engine.state.agents.items():
            if aid == "player": continue
            agent_condition_history[agent.get("condition_tag", "HEALTHY")] += 1
            agent_wealth_history[agent.get("wealth_tag", "COMFORTABLE")] += 1
            agent_cargo_history[agent.get("cargo_tag", "EMPTY")] += 1
            agent_sector_distribution[agent.get("current_sector_id", "")] += 1

mortal_deaths = len(engine.state.mortal_agent_deaths)

print("=" * 60)
print("DIAGNOSTIC REPORT (1800 ticks = 2 full world age cycles)")
print("=" * 60)

print("\n--- ACTION DISTRIBUTION ---")
for action, count in action_counts.most_common():
    print(f"  {action}: {count}")

print(f"\n--- KEY METRICS ---")
print(f"  Total attacks: {attacks}")
print(f"  Total trades: {trades}")
print(f"  Mortal spawns: {mortal_spawns}")
print(f"  Mortal deaths: {mortal_deaths}")
print(f"  Final agent count: {len(engine.state.agents)}")
print(f"  Final mortal counter: {engine.state.mortal_agent_counter}")

print("\n--- WORLD AGE TRANSITIONS ---")
for tick, old, new in world_age_log:
    print(f"  t{tick}: {old} -> {new}")

print("\n--- AGENT CONDITION DISTRIBUTION (sampled) ---")
total = sum(agent_condition_history.values())
for k, v in agent_condition_history.most_common():
    print(f"  {k}: {v} ({100*v/total:.1f}%)")

print("\n--- AGENT WEALTH DISTRIBUTION (sampled) ---")
total = sum(agent_wealth_history.values())
for k, v in agent_wealth_history.most_common():
    print(f"  {k}: {v} ({100*v/total:.1f}%)")

print("\n--- AGENT CARGO DISTRIBUTION (sampled) ---")
total = sum(agent_cargo_history.values())
for k, v in agent_cargo_history.most_common():
    print(f"  {k}: {v} ({100*v/total:.1f}%)")

print("\n--- AGENT SECTOR DISTRIBUTION (sampled) ---")
total = sum(agent_sector_distribution.values())
for k, v in agent_sector_distribution.most_common():
    print(f"  {k}: {v} ({100*v/total:.1f}%)")

print("\n--- SECTOR ECONOMY CONVERGENCE (last 5 samples) ---")
for sid, history in sector_economy_history.items():
    if history:
        print(f"  {sid}: {history[-5:]}")

print("\n--- SECTOR SECURITY CONVERGENCE (last 5 samples) ---")
for sid, history in sector_security_history.items():
    if history:
        print(f"  {sid}: {history[-5:]}")

print("\n--- SECTOR ENVIRONMENT CONVERGENCE (last 5 samples) ---")
for sid, history in sector_env_history.items():
    if history:
        print(f"  {sid}: {history[-5:]}")

print("\n--- COLONY LEVELS ---")
for sid, level in sorted(engine.state.colony_levels.items()):
    print(f"  {sid}: {level}")

print("\n--- ECONOMY TAGS BY WORLD AGE PHASE ---")
for phase in ["PROSPERITY", "DISRUPTION", "RECOVERY"]:
    total = sum(phase_economy_samples[phase].values())
    if total:
        print(f"  {phase}:")
        for tag, count in phase_economy_samples[phase].most_common():
            print(f"    {tag}: {count} ({100*count/total:.1f}%)")

print("\n--- SECURITY TAGS BY WORLD AGE PHASE ---")
for phase in ["PROSPERITY", "DISRUPTION", "RECOVERY"]:
    total = sum(phase_security_samples[phase].values())
    if total:
        print(f"  {phase}:")
        for tag, count in phase_security_samples[phase].most_common():
            print(f"    {tag}: {count} ({100*count/total:.1f}%)")
