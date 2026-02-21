**STATUS: IMPLEMENTED (2026-02-21)**
**Integrated into:** `python_sandbox/core/simulation/affinity_matrix.py`, `agent_layer.py`, `bridge_systems.py`
**Keep this file as design reference — do not delete.**

---

Concept

A "chemical" reactive architecture where entities use qualitative tags (e.g., PIRATE, WEALTHY) instead of complex AI trees or hardcoded scripts. A global Affinity Matrix defines numeric attraction/repulsion scores between specific tags. Entities scan their local environment, calculate scores, and simply move toward positive affinities or flee negative ones.

What It Achieves

Linear Development Complexity: Adding new NPCs or mechanics only requires adding new tags to the matrix, avoiding combinatorial explosion.

Low Simulation Overhead: Replaces heavy pathfinding, global economy tracking, and rigid state machines with basic arithmetic and local spatial polling.

Emergent Narrative: Meaningful behaviors (hunting, trading, scavenging) emerge naturally from overlapping tag affinities rather than predefined flowchart logic.

```
import random

AFFINITY_MATRIX = {
    ('AGGRESSIVE', 'WEAK'): 1.0,
    ('GREEDY', 'WEALTHY'): 1.0,
    ('PIRATE', 'TRADER'): 0.5,
    ('PIRATE', 'MINER'): 1.0,
    ('PATROL', 'DANGEROUS'): 1.5,
    ('COWARD', 'DANGEROUS'): -1.5,
    ('MINER', 'DANGEROUS'): -1.5,
    ('PIRATE', 'PATROL'): -1.0,
    ('TRADER', 'STATION'): 1.0,
    ('MINER', 'ASTEROID'): 1.5,
    ('SCAVENGER', 'WRECKAGE'): 1.5
}

def clamp(val, min_val=0, max_val=9):
    return max(min_val, min(val, max_val))

class Entity:
    def __init__(self, name, tags, x=0, y=0, wealth=100, stationary=False):
        self.name = name
        self.tags = tags
        self.x = clamp(x)
        self.y = clamp(y)
        self.wealth = wealth
        self.active = True
        self.stationary = stationary

    def move_towards(self, tx, ty):
        if self.stationary: return
        self.x = clamp(self.x + (1 if self.x < tx else (-1 if self.x > tx else 0)))
        self.y = clamp(self.y + (1 if self.y < ty else (-1 if self.y > ty else 0)))

    def move_away(self, tx, ty):
        if self.stationary: return
        self.x = clamp(self.x + (-1 if self.x < tx else (1 if self.x > tx else 0)))
        self.y = clamp(self.y + (-1 if self.y < ty else (1 if self.y > ty else 0)))
        
    def idle_routine(self):
        if self.stationary: return
        self.x = clamp(self.x + random.choice([-1, 0, 1]))
        self.y = clamp(self.y + random.choice([-1, 0, 1]))

def resolve_action(actor, target):
    if not actor.active or not target.active: return
    score = sum(AFFINITY_MATRIX.get((a, t), 0.0) for a in actor.tags for t in target.tags)
            
    if score >= 1.5:
        if "WRECKAGE" in target.tags or "ASTEROID" in target.tags:
            print(f" -> [HARVEST] {actor.name} exploits {target.name}.")
            actor.wealth += 20
            target.active = False
        else:
            print(f" -> [ATTACK] {actor.name} destroys {target.name}!")
            actor.wealth += min(target.wealth, 50)
            target.active = False
            target.tags = ["WRECKAGE", "WEAK"]
            target.name = f"Wreck of {target.name}"
    elif score <= -1.0:
        print(f" -> [FLEE] {actor.name} flees from {target.name}!")
        actor.idle_routine() # Quick jump away
    elif score >= 0.5:
        if "STATION" in target.tags:
            print(f" -> [DOCK] {actor.name} trades at {target.name}.")
            actor.wealth += 10

def run_simulation(entities, ticks=100):
    for tick in range(1, ticks + 1):
        # 1. Movement
        for actor in entities:
            if not actor.active or actor.stationary: continue
            best_score, best_target = 0, None
            for target in entities:
                if actor == target or not target.active: continue
                score = sum(AFFINITY_MATRIX.get((a, t), 0) for a in actor.tags for t in target.tags)
                if abs(score) > abs(best_score):
                    best_score, best_target = score, target
            
            if best_target and best_score != 0:
                if best_score > 0: actor.move_towards(best_target.x, best_target.y)
                elif best_score < 0: actor.move_away(best_target.x, best_target.y)
            else:
                actor.idle_routine()

        # 2. Encounters
        locations = {}
        for ent in entities:
            if ent.active: locations.setdefault((ent.x, ent.y), []).append(ent)
            
        for pos, group in locations.items():
            if len(group) > 1:
                encounter_happened = False
                init_order = sorted([(random.randint(1, 20), e) for e in group], key=lambda x: x[0], reverse=True)
                for init, actor in init_order:
                    for _, target in init_order:
                        if actor != target and actor.active and target.active:
                            score = sum(AFFINITY_MATRIX.get((a, t), 0) for a in actor.tags for t in target.tags)
                            if abs(score) >= 0.5:
                                if not encounter_happened:
                                    print(f"\n[Tick {tick}] Encounter at {pos}:")
                                    encounter_happened = True
                                resolve_action(actor, target)

        # 3. Dynamic Spawning (Keep world populated)
        if tick % 10 == 0:
            entities.append(Entity(f"Asteroid_{tick}", ["ASTEROID"], random.randint(0,9), random.randint(0,9), 0, True))

# --- Setup ---
entities = [
    Entity("Trade Station Alpha", ["STATION", "WEALTHY"], 5, 5, 1000, True),
    Entity("Pirate Base", ["STATION", "DANGEROUS"], 1, 8, 500, True),
    Entity("Miner 1", ["MINER", "WEAK"], random.randint(0,9), random.randint(0,9), 50),
    Entity("Miner 2", ["MINER", "WEAK"], random.randint(0,9), random.randint(0,9), 50),
    Entity("Trader 1", ["TRADER", "COWARD", "WEALTHY"], random.randint(0,9), random.randint(0,9), 200),
    Entity("Pirate 1", ["PIRATE", "AGGRESSIVE", "GREEDY", "DANGEROUS"], random.randint(0,9), random.randint(0,9), 0),
    Entity("Pirate 2", ["PIRATE", "AGGRESSIVE", "GREEDY", "DANGEROUS"], random.randint(0,9), random.randint(0,9), 0),
    Entity("Sector Patrol", ["PATROL", "DANGEROUS"], random.randint(0,9), random.randint(0,9), 0),
    Entity("Scavenger", ["SCAVENGER", "WEAK"], random.randint(0,9), random.randint(0,9), 0)
]

# Spawn initial asteroids
for i in range(5):
    entities.append(Entity(f"Asteroid_Init_{i}", ["ASTEROID"], random.randint(0,9), random.randint(0,9), 0, True))

run_simulation(entities, ticks=100)
```