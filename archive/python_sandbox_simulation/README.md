# GDTLancer – Python Simulation Sandbox

Pure-Python re-implementation of the four-layer simulation engine for fast
prototyping without the Godot overhead.

## Architecture

The simulation mirrors the GDScript implementation:

| Layer | Module | Purpose |
|-------|--------|---------|
| 1 | `world_layer.py` | Static topology, hazards, finite resource potential |
| 2 | `grid_layer.py` | CA-driven stockpiles, dominion, market, power, maintenance, wrecks |
| 2→3 | `bridge_systems.py` | Heat, entropy, knowledge refresh |
| 3 | `agent_layer.py` | NPC goal evaluation + action execution |
| 4 | `chronicle_layer.py` | Event capture + rumor generation |
| — | `ca_rules.py` | Pure-function CA transition rules |
| — | `simulation_engine.py` | Tick orchestrator + Axiom 1 conservation check |
| — | `game_state.py` | Central data store (replaces GameState autoload) |
| — | `constants.py` | Tuning knobs (replaces Constants autoload) |
| — | `template_data.py` | Hardcoded template data (replaces TemplateDatabase) |

## Running

```bash
cd python_sandbox
python main.py              # Run 10 ticks with default seed
python main.py --ticks 50   # Run 50 ticks
python main.py --seed hello # Custom seed
```

No dependencies required – uses only the Python standard library.

## Goal

Prototype simulation logic here, then integrate proven changes back into
the GDScript Godot implementation.
