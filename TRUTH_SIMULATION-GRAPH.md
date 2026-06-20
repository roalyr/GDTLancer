<!--
PROJECT: GDTLancer
MODULE: TRUTH_SIMULATION-GRAPH.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
LOG_REF: 2026-06-20 19:13:27
-->

# 8.1-GDD-Simulation-Graph-System

**Version:** 1.5
**Date:** 2026-05-28
**Status:** Mixed Historical Design + Live Implementation Notes
**Related:** `8-GDD-Simulation-Architecture.md`, `1.2-GDD-Core-Cellular-Automata.md`, `TACTICAL_TODO.md`

---

## 0. Implementation Reality (2026-05-23)

This file still contains substantial **historical numeric design language** from the pre-pivot simulation model. The live Godot runtime no longer treats numeric stockpiles, price deltas, or matter-conservation buckets as the authoritative simulation substrate.

For the current implementation in `src/core/simulation/`:

* `WorldLayer` provides topology and hazard seeds.
* `GridLayer` is a qualitative tag-transition CA with bounded counters and thresholds.
* `BridgeSystems` + `AffinityMatrix` refresh derived sector/agent/world tags, including faction, legality, and cargo-provenance semantics needed by the live interaction layer.
* `contract_generation_system.gd` builds bounded runtime contract occurrences from active demand tags.
* `AgentLayer` claims and services those runtime occurrences via cargo/dock flow, and routine human-to-human interactions should resolve through non-lethal disruption or gated trade rather than generic lethal combat.
* `simulation_raw_logger.gd` provides an additive console-only JSON-lines stream for full per-tick snapshots without replacing the chronicle/composite report surfaces, and the Sim Debug Panel now starts that raw stream in continuous mode until process exit.
* Authored `ContractTemplate` resources and `LocationTemplate.available_contract_ids` are **optional curated overrides**, not the default contract pipeline.

Until this document is fully rewritten, treat **Sections 1 through 5 as archived design intent**. Section 6 below is the authoritative implementation map for the live qualitative runtime.

---

## 1. The Core Philosophy: The Closed Loop

The GDTLancer universe is a **Closed Hydraulic System**. Matter is never created or destroyed within the known sectors; it only changes state or location. The total mass of the mapped frontier (`TOTAL_MATTER`) is recalculated whenever new sectors are surveyed.

### The Five Laws of the Graph

1. **Conservation:** `Sum(All Matter Nodes) == TOTAL_MATTER` at every tick boundary.
2. **Transformation:** Matter moves from **Low Entropy** (Ordered/Useful) to **High Entropy** (Disordered/Waste).
3. **Reclamation:** High Entropy matter (Hostiles/Wrecks) can be harvested back into Low Entropy matter (Resources/Scrap), closing the loop.
4. **Asymmetry (Mass Displacement):** Fuel is **expended** to generate energy. The physical mass of spent fuel is transferred to the Hostile Pool as exhaust/entropy. The fuel does not vanish — it pours from the "Tank" bucket into the "Hostile" bucket. This is a one-way valve: mass flows from ordered fuel into disordered entropy, never back.
5. **Heat Death & Discovery:** A fraction of matter is permanently lost to **Slag** (irreversible waste) each cycle. Over infinite ticks, the known universe trends toward heat death. The counter-force is **Sector Discovery** — exploring new sectors adds fresh matter from the `UNDISCOVERED_MATTER_POOL` into `TOTAL_MATTER`, extending the universe's lifespan.

---

## 2. The Entity Graph (Nodes)

These are the containers where matter resides. Every unit of matter in the simulation must be inside exactly one of these nodes at all times.

### 2.1 The World Nodes (Static Topology — Layer 1)

* **Sector Node:** A container for resources and entities.
  * **Resource Potential (`mineral_density`, `propellant_sources`):** The theoretical maximum matter available for extraction. Depleted by mining, replenished only by recycling (wreck decay, waste return).
  * **Hidden Resources (`hidden_resources`):** Matter that exists but cannot be targeted yet. Converted to exposed resources by Prospecting.
  * **Exposed Resources:** Matter available for mining (tracked via `mineral_density`, `propellant_sources`).

### 2.2 The Grid Nodes (Dynamic Infrastructure — Layer 2)

* **Station Stockpile:** The primary "buffers" of the system.
  * Holds: `ore`, `fuel`, `food`, `tech`, `luxury` (per-commodity stockpiles).
  * *Constraint:* Capacity scaled by Colony Level (`capacity_mult`). Limited by inflow from trade and extraction.

* **Station Energy Budget:** Derived from fuel expenditure, not stored independently.
  * Stations and agents expend fuel to generate energy (mass displacement). The spent fuel mass transfers to the Hostile Pool as entropy exhaust.
  * Energy cannot be stockpiled across ticks — it is consumed or wasted within the tick it is generated.
  * Waste exhaust → Hostile Pool (same mass-displacement path as propulsion).

* **Station Population (The Sink):**
  * Represents the workforce. Population density scales with Colony Level.
  * They do not hold matter directly — they **burn** matter to survive (`CONSUMPTION_RATE_PER_TICK`).

### 2.2.1 Cash as Matter (Specie Standard) vs electronic Credits

The economy operates on a dual-currency system that balances convenience and trust:

1. **Electronic Credits (Trust-Bound Transactions):**
   * Abstract fiat currency tracked in character profiles (e.g. `CharacterSystem` credits).
   * Credits allow convenient trading within factions, at secure station dock markets, and under other circumstances where there is enough trust between agents and entities.
   * Using credits to trade with distrustful entities, black markets, or cross-faction outlaws will not be possible due to the lack of shared financial network trust.
   * Credits are electronic promises of value and are not counted directly in the physical simulation's `TOTAL_MATTER`.

2. **Physical Specie (Barter and Hard Cash):**
   * The ultimate baseline economy is a **half-barter system** anchored by a single physical medium of exchange: **Specie** — standardized coins and bars of a precious, inert metal.
   * Specie cargo item (`commodity_specie`) acts as a go-to bartering hard currency, allowing agents to use the convenient credit system where trust exists, yet still rely on hard cash when there is no common ground.
   * Specie functions as cash because of its properties:
     * **Inert** — does not degrade or react (zero entropy cost to hold).
     * **Dense** — high value-to-mass ratio (practical to carry).
     * **Widely accepted across known anchorages** — its physical properties make it a practical fallback when shared trust does not exist between parties.
   
   * **Specie IS counted in `TOTAL_MATTER`** — it is a commodity like any other, occupying cargo or stockpile space.
   * **Paying for repairs** = transferring `commodity_specie` from `Agent(cargo)` → `Station(stockpile)`.
   * **Earning from trade** = receiving `commodity_specie` in exchange for goods. The matter itself always moves.
   * **Transaction logic is simple:** `if agent.cargo['commodity_specie'] >= cost: pay()`. No weighted basket, no multi-commodity transfer.
   * **Debt** = a promise of future Specie transfer, not matter itself (not counted in TOTAL_MATTER).
   * **Specie enters circulation** via mining (rare metal deposits) and salvage (wrecks contain Specie from dead agents). It exits circulation the same way all matter does — through entropy and slag.

### 2.3 The Agent Nodes (Mobile Capacitors — Layer 3)

All roles are shared by both **Named (persistent)** and **Mortal (expendable)** vessel-commanding agents. Every **vessel operator** can trade, mine, prospect, salvage, or take on patrol work depending on their goal queue and circumstances. Role selection is driven by the agent's goal queue and situational context, not a fixed class.

> [!NOTE]
> **Scarce Pilot Doctrine (LORE-2.2):** Not every person at a station is a vessel operator. The agent layer represents the frontier's rare vessel-commanding class. Station populations, maintenance workers, families, medics, and administrators are modeled through the sub-agent layer, not as primary agents.

* **Agent Ship (Named / Mortal):**
  * **Hull Mass (`hull_integrity`):** The physical matter of the ship itself. Degrades via entropy, combat, hazards.
  * **Fuel Tank (`propellant`):** Volatile matter used for movement and energy generation. Consumed by propulsion and shipboard systems.
  * **Inventory (`cargo`):** Matter being transported between nodes. Includes trade goods and Specie (physical metal currency).
  * **Energy Draw:** Per-tick fuel expenditure for running ship systems (`ENERGY_DRAIN_PER_TICK`). Spent fuel mass displaces to Hostile Pool as entropy exhaust.

* **Hostile Unit (Drone / Alien):**
  * **Biomass (`body_mass`):** The physical matter of the hostile unit (equivalent to Hull + Fuel). Set by `HOSTILE_SPAWN_COST` when spawned from pool.

### 2.4 The Entropy Nodes (The Recyclers)

* **Hostile Pools (`drone_pool`, `alien_pool`):** Invisible per-type matter reservoirs.
  * Input: Entropy Tax from station consumption, fuel burn exhaust, ship/station system exhaust (mass displacement), wreck salvage in low-security sectors.
  * Output: Spawning new Hostile Units (pool → `body_mass`).
  * *Constraint:* NO passive/free spawning — if pool is empty, no hostiles spawn.

* **Wrecks (`wrecks` per sector):** Dead matter in space.
  * Input: Destruction of Agents or Hostiles.
  * Output: Salvage (to Agent Inventory), hostile wreck salvage (to Hostile Pools in low-sec), decay (to Hidden Resources via `WRECK_DEBRIS_RETURN_FRACTION`).

---

## 3. The Flow Graph (Edges)

This defines how matter moves between Nodes. Every edge is a conservation-preserving transfer: the source loses exactly what the destination gains.

### 3.1 The Production Cycle (Low Entropy → Useful)

```
┌─────────────────────┐    Mining     ┌──────────────────┐    Trade     ┌──────────────────────┐
│ Sector              │──────────────→│ Agent            │────────────→│ Station              │
│ (Exposed Resources) │  extraction   │ (Inventory)      │  sell/dock  │ (Stockpile)          │
└─────────────────────┘               └──────────────────┘             └──────────────────────┘
```

1. **Extraction:** `Sector(Exposed)` → `Agent(Inventory)`
   * *Action:* Mining. Rate governed by `CA_EXTRACTION_RATE_DEFAULT` × Colony Level `extraction_mult`.
   * *Conservation:* `mineral_density` decreases; `cargo` increases by the same amount.

2. **Trade:** `Agent(Inventory)` → `Station(Stockpile)`
   * *Action:* Selling / Unloading.
   * *Conservation:* `cargo` decreases; `stockpile` increases by the same amount.

3. **Refinement:** `Station(Ore)` → `Station(Tech)`
   * *Action:* Industry (Colony Level dependent).
   * *Rate:* `refinement_output = ore_input × colony_level_modifier`.
   * *Conservation:* Total stockpile mass unchanged — only commodity type changes.

### 3.2 The Consumption Cycle (Useful → High Entropy)

```
┌──────────────────────┐   Metabolism   ┌────────────────┐
│ Station              │───────────────→│ Hostile Pool   │ (Entropy Tax fraction)
│ (Stockpile: Food,   │                └────────────────┘
│  Fuel, etc.)         │───────────────→ Hidden Resources  (Waste recycling fraction)
└──────────────────────┘

┌──────────────────┐   Propulsion    ┌────────────────┐
│ Agent            │────────────────→│ Hostile Pool   │ (Fuel mass → exhaust)
│ (Fuel Tank)      │                 └────────────────┘
│                  │   Ship Systems  ┌────────────────┐
│                  │────────────────→│ Hostile Pool   │ (Fuel mass → exhaust)
└──────────────────┘                 └────────────────┘

┌──────────────────┐   Station Power ┌────────────────┐
│ Station          │────────────────→│ Hostile Pool   │ (Fuel mass → exhaust)
│ (Fuel Stockpile) │                 └────────────────┘
└──────────────────┘
```

1. **Metabolism:** `Station(Stockpile)` → `Hostile Pool` + `Hidden Resources`
   * *Action:* Station upkeep. Population consumes resources each tick.
   * *Rate:* `CONSUMPTION_RATE_PER_TICK` × `population_density`.
   * *Split:* `CONSUMPTION_ENTROPY_TAX` (3%) → Hostile Pool. Remainder (97%) → `hidden_resources` (waste recycled to ground).
   * *Conservation:* `stockpile` decreases; `hostile_pool` + `hidden_resources` increase by the same total.

2. **Propulsion:** `Agent(Fuel)` → `Hostile Pool`
   * *Action:* Movement between sectors.
   * *Rate:* `PROPELLANT_DRAIN_PER_TICK`.
   * *Logic:* Burnt fuel pollutes the void, strengthening the Hostile swarm. The more active the economy, the more entropy feeds hostiles.
   * *Conservation:* `propellant` decreases; `hostile_pool` increases.

3. **Ship Systems (Mass Displacement):** `Agent(Fuel)` → `Hostile Pool`
   * *Action:* Running shipboard systems (sensors, life support, computing).
   * *Rate:* `ENERGY_DRAIN_PER_TICK` expressed as fuel-mass expended.
   * *Logic:* Fuel is not "converted" to energy — fuel is **expended** to generate energy. The physical mass of the spent fuel is transferred to the Hostile Pool as exhaust/entropy. The fluid doesn't vanish; it pours from the "Tank" bucket into the "Hostile" bucket. (Law 4.)
   * *Conservation:* `propellant` decreases; `hostile_pool` increases by the same mass.

4. **Station Power (Mass Displacement):** `Station(Fuel Stockpile)` → `Hostile Pool`
   * *Action:* Station power systems (`station_power_draw`).
   * *Rate:* Proportional to `power_load_ratio` × fuel-mass expended for power generation.
   * *Logic:* Same mass displacement — fuel burned for power, spent mass becomes entropy exhaust.
   * *Conservation:* `stockpile(fuel)` decreases; `hostile_pool` increases by the same mass.

### 3.3 The Life & Death Cycle (Reclamation)

```
                    Construction                         Destruction
Station(Stockpile) ──────────────→ Agent(Hull/Fuel) ──────────────→ Wreck
                                                                      │
                              ┌───────────────────────────────────────┘
                              │ Salvage          │ Decay
                              ↓                  ↓
                     Agent(Inventory)     Hidden Resources
                              │
                              │ Trade
                              ↓
                     Station(Stockpile)

                    Manifestation                   Hostile Death
Hostile Pool ─────────────────→ Hostile(Biomass) ──────────────→ Wreck
```

1. **Construction (Agent Spawn):** `Station(Stockpile)` → `Agent(Hull/Fuel/Specie)`
   * *Constraint:* A Mortal Agent **cannot** spawn if the Station lacks sufficient stockpile (`MORTAL_SPAWN_MIN_STOCKPILE`). Named Agents queue for respawn if resources are insufficient.
   * *Conservation:* `stockpile` decreases by hull + fuel + starting-Specie cost; `hull_integrity` + `propellant` + `cargo(commodity_specie)` initialized. Starting Specie is physical metal withdrawn from station stockpile.
   * **Emergency Draft:** If `total_stockpile == 0` and no agents exist in the sector, the colony **cannibalizes its own infrastructure**. The colony downgrades one level (e.g., colony → outpost), converting the freed infrastructure matter into enough stockpile to spawn one emergency agent. This prevents permanent softlocks. If already at `frontier` level, word spreads through traders and gossip networks — a nearby community with surplus may choose to send a relief agent. Nothing is guaranteed; the response depends on prior standing, distance, and whether any vessel operator can be spared. Matter for any relief sent is debited from the originating community's stockpile, not created from nothing.

2. **Destruction (Agent Death):** `Agent(Hull + Fuel + Cargo)` → `Wreck`
   * *Action:* Combat death, entropy death (hull reaches `ENTROPY_DEATH_HULL_THRESHOLD`).
   * *Conservation:* All agent matter (hull + fuel + cargo) → `wrecks` in the sector.

3. **Salvage:** `Wreck` → `Agent(Inventory)`
   * *Action:* Scavenging by Agents (prospectors in high-sec sectors).
   * *Rate:* `PROSPECTOR_WRECK_SALVAGE_RATE` per tick.
   * *Conservation:* `wrecks` decreases; `cargo` increases.

4. **Wreck Decay:** `Wreck` → `Hidden Resources` + `Slag`
   * *Action:* Natural degradation over time.
   * *Rate:* `WRECK_DEGRADATION_PER_TICK`.
   * *Split:* Three distinct outputs, clearly defined:
     * **Salvageable fraction** (`WRECK_DEBRIS_RETURN_FRACTION` = 70%) → `hidden_resources`. This is recoverable matter — it requires Prospecting to find, then mining to extract, but it is not lost.
     * **Slag fraction** (`WRECK_SLAG_FRACTION` = 30%) → `slag_total`. This is **permanently irreversible waste**. It cannot be prospected, mined, or recovered by any mechanism. It is removed from `TOTAL_MATTER` and added to `slag_total`.
   * *Conservation:* `wrecks` decreases; `hidden_resources` increases by salvageable fraction; `TOTAL_MATTER` decreases by slag fraction (tracked separately in `slag_total`).

### Matter Terminology (Disambiguation)

To prevent confusion, the simulation uses exactly **five matter states** with no overlap:

| Term | Recoverable? | Where it lives | How to access it |
|---|---|---|---|
| **Exposed Resources** | Yes | `mineral_density`, `propellant_sources` | Mining (direct extraction) |
| **Hidden Resources** | Yes | `hidden_resources` | Prospecting → then Mining |
| **Stockpile / Cargo / Hull / Fuel** | Yes | Station, Agent, Hostile nodes | Trade, combat, salvage |
| **Wrecks** | Yes | `wrecks` per sector | Salvage, or wait for decay |
| **Slag** | **NO** | `slag_total` (global counter) | **Permanently lost** — heat death matter |

**Slag** is the only irreversible sink. It is the universe's thermodynamic arrow. Over infinite ticks without new sector discovery, all matter trends toward Slag and the simulation reaches heat death.

### Sector Discovery (The Counter-Force to Heat Death) — [SUPERSEDED]

> [!IMPORTANT]
> **This section is superseded** by the Manual Space Graph & In-Sector POI Spawning resolved decision (§8.8). Dynamic sector sprouting from the undiscovered pool is disabled; space topology is fixed and manual, while dynamic content is generated as POIs within sectors.

The known universe at Tick 0 is a small fraction of the total universe. A vast `UNDISCOVERED_MATTER_POOL` exists beyond the frontier, orders of magnitude larger than `TOTAL_MATTER`.

* **Discovery:** When an agent discovers a new sector, that sector's resources (exposed + hidden) are drawn from `UNDISCOVERED_MATTER_POOL` and added to `TOTAL_MATTER`.
* **Gameplay consequence:** A community that stops surveying new territory will eventually exhaust its local matter budget, slowly starving.
* **True finite frontier:** `UNDISCOVERED_MATTER_POOL` is large but finite. The local region *will* eventually exhaust if every reachable sector is surveyed and all matter degrades to Slag. This is intentional.

> [!NOTE]
> **Archived framing caveat (LORE-1.1):** References to "civilization" in this archived section are legacy design language. On this frontier, there is no civilization-scale actor — only isolated communities struggling to survive. The mechanic is superseded; the civilizational framing does not apply.


5. **Manifestation (Hostile Spawn):** `Hostile Pool` → `Hostile(Biomass)`
   * *Action:* Hostile spawning when pool exceeds threshold.
   * *Trigger:* `pool > HOSTILE_POOL_PRESSURE_THRESHOLD`.
   * *Cost:* `HOSTILE_SPAWN_COST` per hostile spawned.
   * *Conservation:* `hostile_pool` decreases; `body_mass` of new hostile created.

6. **Hostile Death:** `Hostile(Biomass)` → `Wreck`
   * *Action:* Combat death (patrol agents, sector defense).
   * *Conservation:* `body_mass` → `wrecks` in the sector.

7. **Hostile Wreck Salvage (Low-Sec):** `Wreck` → `Hostile Pool`
   * *Action:* Hostiles feed on wreckage in low-security sectors.
   * *Rate:* `HOSTILE_WRECK_SALVAGE_RATE` per tick.
   * *Condition:* `security_level < HOSTILE_LOW_SECURITY_THRESHOLD`.
   * *Conservation:* `wrecks` decreases; `hostile_pool` increases.

8. **Hostile Raids:** `Station(Stockpile)` → `Wreck`
   * *Action:* When hostiles swarm a sector (`count >= HOSTILE_RAID_THRESHOLD`), they raid stockpiles.
   * *Rate:* `HOSTILE_RAID_STOCKPILE_FRACTION` of total stockpile per raid.
   * *Conservation:* `stockpile` decreases; `wrecks` increases.

### 3.4 The Maintenance Cycle (Colony Upkeep)

Colony levels are not permanent upgrades — they require **continuous matter investment** to maintain. Technology and infrastructure are susceptible to decay without upkeep.

1. **Colony Maintenance:** `Station(Stockpile: Tech/Ore)` → `Hidden Resources` + `Hostile Pool`
   * *Action:* Ongoing maintenance of colony infrastructure. Higher colony levels demand more maintenance matter per tick.
   * *Rate:* Scales with Colony Level — `hub` > `colony` > `outpost` > `frontier`.
   * *Split:* Maintenance waste follows the same entropy split as metabolism (`CONSUMPTION_ENTROPY_TAX` → Hostile Pool, remainder → `hidden_resources`).
   * *Consequence:* If stockpiles cannot cover maintenance, colony **degrades** toward `frontier`. This prevents colonies from becoming permanent fixtures — they must be actively supplied.
   * *Conservation:* `stockpile(tech/ore)` decreases; `hidden_resources` + `hostile_pool` increase.

2. **Colony Upgrade:** Threshold-based (stockpile and security over `COLONY_UPGRADE_TICKS_REQUIRED` consecutive ticks) — but the upgraded level then demands higher maintenance.

3. **Colony Downgrade:** Triggered when maintenance cannot be met (stockpile below `COLONY_DOWNGRADE_STOCKPILE_FRACTION`) or security drops below `COLONY_DOWNGRADE_SECURITY_MIN`.

### 3.5 The Prospecting Cycle (Hidden → Exposed)

```
Hidden Resources ──── Prospecting ───→ Exposed Resources (mineral_density, propellant_sources)
```

1. **Prospecting:** `Hidden Resources` → `Exposed Resources`
   * *Action:* Prospector agents discover new deposits.
   * *Rate:* `PROSPECTING_BASE_RATE × hidden_remaining × scarcity_factor × security_factor × hazard_factor`.
   * *Conservation:* `hidden_resources` decreases; `mineral_density` / `propellant_sources` increases.
   * *Note:* This is NOT matter creation — it reveals matter already counted in `TOTAL_MATTER` at Tick 0.

---

## 4. The Complete Matter Circuit (Summary)

The full closed loop as a linear flow list. Every arrow is a conservation-preserving transfer. Primary consumer of this section is LLM context; clarity over aesthetics.

### 4.1 Flow List (Every Edge in the Graph)

**Production (Low → Useful):**
- `Sector(Exposed)` →[Mining]→ `Agent(Cargo)` →[Trade]→ `Station(Stockpile)`
- `Station(Ore)` →[Refinement]→ `Station(Tech)` (mass-neutral type change)

**Consumption (Useful → Entropy):**
- `Station(Stockpile)` →[Metabolism]→ 97% `Hidden Resources` + 3% `Hostile Pool`
- `Agent(Fuel)` →[Propulsion]→ `Hostile Pool`
- `Agent(Fuel)` →[Ship Systems]→ `Hostile Pool` (mass displacement)
- `Station(Fuel)` →[Station Power]→ `Hostile Pool` (mass displacement)
- `Station(Tech/Ore)` →[Colony Maintenance]→ `Hidden Resources` + `Hostile Pool`

**Lifecycle:**
- `Station(Stockpile)` →[Construction]→ `Agent(Hull + Fuel + Specie)`
- `Agent(All Matter)` →[Death]→ `Wrecks`
- `Hostile Pool` →[Manifestation]→ `Hostile(Biomass)`
- `Hostile(Biomass)` →[Death]→ `Wrecks`
- `Station(Stockpile)` →[Hostile Raid]→ `Wrecks`

**Reclamation:**
- `Wrecks` →[Agent Salvage]→ `Agent(Cargo)`
- `Wrecks` →[Hostile Salvage, low-sec]→ `Hostile Pool`
- `Wrecks` →[Decay, 70%]→ `Hidden Resources`
- `Wrecks` →[Decay, 30%]→ **`Slag`** (permanently lost)

**Discovery:**
- `Hidden Resources` →[Prospecting]→ `Exposed Resources`
- `UNDISCOVERED_MATTER_POOL` →[Sector Discovery]→ `TOTAL_MATTER` (new sector resources)

**Emergency:**
- `Colony Infrastructure` →[Emergency Draft]→ `Station(Stockpile)` (colony downgrades)
- `Neighbor Colony(Stockpile)` →[Faction Distress]→ dispatched relief Agent

### 4.2 Conservation Audit

Trace any unit of matter through the graph:

```
Undiscovered Pool → [Discovery] → Exposed Resource → [Mining] → Cargo →
[Trade] → Stockpile → [Metabolism] → Hidden Resource → [Prospecting] →
Exposed Resource → ... (cycle repeats, losing ~30% to Slag per wreck-decay pass)
```

**Every arrow has a source debit and a destination credit.** No arrow points "out" into the void except Slag, which is the intentional heat-death drain.

**Key invariant:** `TOTAL_MATTER + UNDISCOVERED_MATTER_POOL + slag_total == UNIVERSE_CONSTANT` (set at initialization, never changes).

---

## 5. The Information Graph (Signal Propagation — Layer 4 / Chronicle)

Agents need a heuristic map to make decisions. This creates the "Gold Rush" behavior.

### 5.1 The Heatmap Nodes

Every Sector has dynamic "Signal" properties that decay over time:

1. **Economic Heat:** Sum of recent trade value at the sector's station.
2. **Resource Heat:** Sum of recent mining yield from the sector.
3. **Threat Heat:** Sum of recent damage taken by ships in the sector.
4. **Entropy Signature:** Sum of fuel/system exhaust mass displaced into the sector's vicinity. High activity = high signature, regardless of intent.

**Note on Decoys:** An agent (player or AI) could deliberately generate high Threat Heat and Entropy Signature in an empty sector through pointless combat or fuel burning. This is **intentional emergent behavior** — it functions as a decoy or lure. You cannot hide massive movement and energy signatures in the vacuum of space. Scavengers and hostiles don't care *why* the entropy is high; they respond to it mechanically.

### 5.2 Signal Flow (Gossip)

* **Direct Observation:** Agent enters Sector → Agent updates internal Knowledge Snapshot.
* **Station Gossip:** Agent docks at Station → Station shares top "Hot" sectors (filtered by `knowledge_decay_rate`).
* **Decay:** All signals fade per tick (governed by `AGENT_KNOWLEDGE_NOISE_FACTOR` and Chronicle `decay_threshold_ticks`). This ensures old "Gold Rushes" fade if activity stops.

### 5.3 Emergent "Gold Rush" Scenario

With this graph, a "Gold Rush" is mathematically inevitable:

1. Sector 6 has high `Resource Potential` (hidden resources discovered by prospector).
2. Miner discovers rich deposits → `Resource Heat` spikes.
3. Miner sells at local Station → `Stockpiles` rise → Prices drop locally (`commodity_price_deltas` go negative).
4. Traders see `Economic Heat` and `Price Disparity` → They flock to buy cheap.
5. Traders burn massive fuel to get there → `Entropy` rises → Hostile Pools grow.
6. Hostiles detect high entropy/fuel density → Hostiles swarm Sector 6.
7. Combat creates Wrecks → Attracts salvagers → Creates more economic activity.
8. **Result:** Community-pressure cascade gameplay without a single line of scripted "event" code.

> [!NOTE]
> **Archived framing caveat (LORE-3.3):** The "Gold Rush" metaphor above is legacy system design language describing emergent pressure dynamics. In the live simulation, agents do not rush sectors for personal profit. They respond because their home community's survival depends on it, or because a trusted contact asked them to go. The *mechanism* described here is valid; the *framing* should not carry over into chronicle text or narrative templates.

---

## 6. Architectural Implementation Map

How this graph maps to the code systems (both Python sandbox and target Godot architecture).

### 6.1 The `GridLayer` / Qualitative Demand CA

* **Responsibility:** Evolves sector state through qualitative tags rather than numeric commodity ledgers.
* **Live logic:**
   * Steps economy, security, environment, hostile pressure, and colony progression through bounded counters and thresholds.
   * Surfaces `CONTRACT_DEMAND_*`, `RELIEF_NEEDED`, and `TRADE_LANE_ACTIVE` tags from sustained `*_POOR` sector states and relief traffic.
   * Surfaces catastrophe-disabled sector state through `DISABLED` tags and recovery timers, which downstream delivery systems treat as a service gate rather than a new economy model.
   * Maintains only qualitative support state (`*_progress`, thresholds, cooldowns); it does not own numeric stockpiles or prices.
* **Files:** `src/core/simulation/grid_layer.gd`, `src/autoload/GameState.gd`, `src/autoload/Constants.gd`

### 6.2 The `BridgeSystems` + `AffinityMatrix` / Tag Derivation Layer

* **Responsibility:** Refreshes normalized sector, agent, and world tags after each grid tick.
* **Live logic:**
   * Rebuilds security/environment/economy tags while preserving custom qualitative tags such as runtime demand markers.
   * Derives role/personality/cargo tags for agents so downstream behavior stays affinity-driven.
   * Keeps the shared tag vocabulary authoritative for both sector-state transitions and agent choice.
* **Files:** `src/core/simulation/bridge_systems.gd`, `src/core/simulation/affinity_matrix.gd`

### 6.3 The `ContractGenerationSystem` + `AgentLayer` / Runtime Delivery Loop

* **Responsibility:** Converts qualitative demand into runtime contract occurrences, then resolves those occurrences through agent behavior.
* **Live logic:**
   * `contract_generation_system.gd` runs after `BridgeSystems` and before `AgentLayer` each tick.
   * Active `CONTRACT_DEMAND_*` tags become bounded runtime delivery occurrences sourced from nearby qualifying sectors.
   * Each occurrence carries shared accounting ownership (`source_accounting_sector_id`, `payment_accounting_sector_id`) plus reservation state (`source_reserved`, `payment_reserved`, `cargo_picked_up`) so player and NPC delivery flow use the same bounded source/payment seam.
   * Claimed/in-transit occurrences are retained across generator refresh so multi-tick deliveries survive even if the demand tag clears, but pre-pickup claims that lose a valid claimant or become unserviceable must release reserved source/payment backing instead of silently stranding it.
   * Traders and haulers claim occurrences by affinity, route to source sectors, load cargo, travel to target sectors, and complete deliveries through the existing cargo/dock flow.
   * `BridgeSystems` + `AffinityMatrix` must derive faction, legality, and cargo-provenance tags from the existing character, sector-control, and agent cargo state before `AgentLayer` resolves human interactions.
   * Human-to-human interaction should distinguish lawful cooperation, illicit exchange, coercive disruption, and exceptional lethal force. Routine internal human conflict must not disable or destroy other humans by default.
   * Player contract actions stay explicit through the Contract Board helpers, but pickup/completion consequences share the same `AgentLayer` gates and accounting transitions as NPC deliveries.
   * Active runtime contract cargo and reservation-backed deliveries are protected cargo, not generic bilateral trade inventory. Generic interaction logic must not leak or confiscate that cargo unless a later contract explicitly redefines the shared delivery seam.
   * When the source sector is disabled, pickup is blocked; when the target sector is disabled after pickup, the in-transit occurrence remains retained and the held payment reservation stays blocked until recovery or claimant cleanup resolves it.
   * Claimant disable/death cleanup must clear player mirrors, reopen or remove the affected occurrence according to pickup state, and restore any stranded reservation backing so the runtime store never carries a dead claim indefinitely.
   * The Contract Board is read-only against this seam: it reflects reservation state and disabled-source/disabled-target recovery waits, but it does not become a second authority for contract lifecycle changes.
* **Files:** `src/core/simulation/contract_generation_system.gd`, `src/core/simulation/simulation_engine.gd`, `src/core/simulation/agent_layer.gd`

### 6.4 System Interaction Matrix

| Source System | Destination System | Data Transferred | Edge Type |
|---|---|---|---|
| WorldLayer | GridLayer | Sector topology, hazards, starting tags | Initialization |
| GridLayer | Sector Tags | Economy/security/environment/hostile/colony transitions | Qualitative CA |
| GridLayer | Demand State | `contract_generation_pressure`, thresholds, demand tags | Qualitative CA |
| BridgeSystems | Sector / Agent Tags | Normalized tags plus preserved custom demand markers, faction-control context, legality context, and cargo-provenance hints | Derivation |
| AffinityMatrix | AgentLayer | Role, condition, cargo, faction, and legality affinities plus the shared vocabulary that scores them | Decision Support |
| GridLayer / Sector Tags | ContractGenerationSystem | `CONTRACT_DEMAND_*` tags plus disabled-sector serviceability context | Runtime Generation Gate |
| ContractGenerationSystem | Runtime Contract Store | Bounded occurrence dictionaries, accounting-owner ids, and reservation state | Runtime Generation |
| Runtime Contract Store | AgentLayer | Claimable `delivery`-style qualitative occurrences with shared reservation/cargo state | Goal Selection |
| GridLayer / Sector Tags | AgentLayer | Disabled-source and disabled-target gating for pickup/completion, plus lawful/unlawful context for human interaction | Action Gate |
| AgentLayer | Runtime Contract Store | Claim, reservation release, blocked in-transit retention, claimant cleanup, and completion state | Runtime Resolution |
| AgentLayer | Sector Tags | Relief movement, docking, cargo delivery side effects, and non-lethal disruption fallout | Simulation Action |
| AgentLayer | Chronicle | Claim/load/complete, movement, trade, coercive, and other interaction events | Event Capture |
| Runtime Contract Store | ContractBoard | Player-visible occurrence state, reservation flags, and recovery-wait hints | Read-Only UI |
| SimDebugPanel | SimulationEngine | Continuous raw-stream start request metadata | Debug Control |
| SimulationEngine | SimulationRawLogger | Live tick processing and current tick config | Raw Snapshot Stream |
| SimulationRawLogger | Console JSONL Stream | `run_started`, repeated `tick_snapshot`, and best-effort `run_finished` records | Raw Observability |
| ContractTemplate / `available_contract_ids` | Docked/UI or curated content entry points | Optional handcrafted override content | Curated Override |

### 6.5 The `SimDebugPanel` + `SimulationRawLogger` / Continuous Raw Stream

* **Responsibility:** Starts additive console-only continuous raw logging for the live simulation without replacing the existing chronicle/composite report view.
* **Live logic:**
   * `sim_debug_panel.gd` keeps the existing `Run 30`, `Run 300`, and `Run 3000` report buttons intact, and routes `Run Raw Simulation` through `SimulationEngine.start_silent_raw_stream(...)`.
   * `simulation_engine.gd` owns the continuous raw-stream loop; once started, `_process()` keeps advancing live ticks and forwarding them into `simulation_raw_logger.gd` until the process exits or the engine is torn down.
   * The earlier bounded helper `SimulationEngine.run_silent_simulation_log(...)` remains additive for finite probes, but the panel-owned raw path is now the continuous stream.
   * `simulation_raw_logger.gd` emits one JSON object per line with `schema_id = "gdtlancer.sim_snapshot.v1"`.
   * `run_started` records advertise `run_id`, `tick_start`, `stream_mode`, the request context, the active tick config, the auto-captured `game_state_fields` list, and the normalization contract the later parser must obey.
   * `tick_snapshot` records emit once per processed tick and carry `run_id`, `tick_index`, `sim_tick`, the active tick config, and a full `game_state` payload.
   * `run_finished` records close bounded runs normally and close continuous runs only on graceful shutdown/teardown; if the process is killed hard, downstream tooling must tolerate a stream that ends after the last `tick_snapshot` without a closing record.
   * `game_state` is sourced from `GameState.get_script().get_script_property_list()` without a `PROPERTY_USAGE_STORAGE` filter, so live autoload fields are not dropped and new simulation fields appear automatically without maintaining a second manual whitelist.
   * Non-scalar Godot Variants are normalized into JSON-safe dictionaries tagged by `__type`; vectors, colors, resources, nodes/objects, transforms, node paths, RIDs, and pooled arrays must preserve enough metadata for a later offline parser to reconstruct meaning.
   * Dictionary keys are stringified at emission time, so downstream tooling should treat JSON objects as normalized views of Godot dictionaries rather than assuming original key types were all strings.
* **Files:** `src/core/ui/sim_debug_panel/sim_debug_panel.gd`, `scenes/ui/hud/sim_debug_panel.tscn`, `src/core/simulation/simulation_engine.gd`, `src/core/simulation/simulation_raw_logger.gd`

### 6.6 Manual Space Graph & In-Sector POI System

* **Responsibility:** Manages the static world topology graph and instantiates dynamic Points of Interest (POIs) within the 3D volume of sector nodes.
* **Live logic:**
   * The inter-sector space graph is statically defined and designer-authored (Star → Planet → Moon). Dynamic sector sprouting or deep-space sprout/decay is disabled.
   * `world_layer.gd` reads this static graph during bootstrap and maintains the fixed routing connections.
   * In-sector POIs (derelicts, anomalies, deposits) are spawned within the sector's 3D volume and registered as local simulation objects. They are not nodes in the world-level graph.
* **Files:** `src/core/simulation/world_layer.gd`, `database/definitions/location_template.gd`, `src/core/systems/sector_loader.gd`

---

## 7. Graph Validation (The Unit Tests)

To ensure the graph works, we define these invariant tests:

### 7.1 The Zero-Sum Test (Axiom 1)

```
Sum(
    all sector mineral_density
  + all sector propellant_sources
  + all sector hidden_resources
  + all station stockpiles (all commodities, including Specie)
  + all agent cargo (including Specie)
  + all agent hull_integrity
  + all agent propellant
  + all hostile body_mass
  + all hostile_pool reserves (drone_pool + alien_pool)
  + all sector wrecks
) == TOTAL_MATTER  ±  AXIOM1_RELATIVE_TOLERANCE
```

And the universal invariant (never changes, ever):

```
TOTAL_MATTER + UNDISCOVERED_MATTER_POOL + slag_total == UNIVERSE_CONSTANT
```

Every tick ends with both assertions. If either fails, matter leaked.

**Note on Specie:** Since Specie is a physical commodity (`commodity_specie`), it is already counted within `agent cargo` and `station stockpiles`. There is no separate cash bucket. Debt is a promise, not matter — excluded from both sums.

**Note on Slag:** `slag_total` accumulates irreversibly. As Slag grows, `TOTAL_MATTER` shrinks (via wreck decay). Discovery of new sectors counters this by moving mass from `UNDISCOVERED_MATTER_POOL` into `TOTAL_MATTER`.

**Note on Energy:** Energy is not a separate term. Fuel expended for energy is mass-displaced into `hostile_pool` within the same tick. No energy→matter conversion exists (Law 4).

### 7.2 The Starvation Test

* Remove all Ore from the universe at Tick N.
* **Expected:** Agents should eventually stop spawning (no stockpile for construction). Stations should downgrade (stockpiles deplete below `COLONY_DOWNGRADE_STOCKPILE_FRACTION`). Simulation should freeze into a stable low-activity state but **not crash or drift**.
* **Validates:** No hidden matter sources, no magic spawning.

### 7.3 The Inflation Test

* Inject 1,000,000 units of Fuel into a single sector at Tick N.
* **Expected:** Hostile spawns should skyrocket (fuel burn → entropy → pool growth). Wrecks should increase from increased combat. Eventually fuel returns to the Scavenge/Salvage cycle and the system re-equilibrates.
* **Validates:** Entropy feedback loop works. System self-corrects.

### 7.4 The Isolation Test

* Disconnect one sector (no agents travel to/from it).
* **Expected:** Internal metabolism slowly depletes stockpiles → entropy tax feeds hostile pool → hostiles spawn and raid → stockpiles → wrecks → decay to hidden resources → prospecting reveals resources → but no miners to extract → sector dies gracefully to frontier level.
* **Validates:** Every subsystem works independently. No dependency on external input.

### 7.5 The Catastrophe Recovery Test

* Trigger a Catastrophe event (`CATASTROPHE_STOCKPILE_TO_WRECK = 60%` of stockpiles → wrecks).
* **Expected:** Economy crashes locally. Wrecks attract salvagers. Prices spike (scarcity). Traders bring goods from other sectors. Recovery happens organically over 100–500 ticks.
* **Validates:** The system is resilient. Catastrophes are temporary disruptions, not permanent damage.

---

## 8. Resolved Design Decisions

These questions were raised during initial graph design and have been resolved:

### 8.1 Cash Flow → Cash is Matter (Specie Standard) vs electronic Credits

**Decision:** The economy balances electronic credits with physical commodity cash (**Specie** — standardized coins and bars of a precious, inert metal, `commodity_specie`).
* Electronic credits act as a convenient fiat ledger for trading within factions or when trust is established. Using credits to trade with distrustful or outlaw entities is blocked.
* Specie acts as the baseline physical medium of exchange (barter standard) when trust does not exist.
* **Specie IS counted in `TOTAL_MATTER`** — it occupies the same accounting bucket as any other commodity, whereas abstract credits do not.
* Paying for services (repairs, docking, fuel) = transferring `commodity_specie` from Agent → Station, or deducting credits when trust/faction service is available.
* Specie lost on death becomes wreck matter. Specie enters circulation via rare mining deposits and salvage.

### 8.2 Energy as Matter → Mass Displacement (Law 4)

**Decision:** Energy is generated by **expending fuel**. The fuel is not "converted" — its physical mass is **displaced** from the Tank bucket into the Hostile Pool bucket as exhaust. The fluid never vanishes; it changes container.

* Ship systems (`ENERGY_DRAIN_PER_TICK`) expend fuel mass. That mass transfers to Hostile Pool.
* Station power systems (`station_power_draw`) expend stockpile fuel mass. Same path.
* **This is the Fourth Law of the Graph** — mass flows one-way from ordered fuel into disordered entropy exhaust, never back.
* **Graph impact:** Two edges: `Agent(Ship Systems)` → `Hostile Pool` and `Grid(Station Power)` → `Hostile Pool`.
* **Gameplay consequence:** Advanced technology expends more fuel for systems, displacing more mass into entropy, attracting more hostiles. Capability has a thermodynamic cost.

### 8.3 Inter-Station Trade → Agents Handle All Trade

**Decision:** Stations do **not** trade with each other directly. All inter-station commerce flows through agents.

* Both Named (persistent) and Mortal (expendable) agents share **all roles** — trader, miner, prospector, salvager, pirate, patrol. Role selection is driven by the agent's goal queue and situational context, not a fixed class.
* There is no separate "caravan" NPC type. Mortal agents spawned by prosperous sectors naturally fill the trader role when price disparities exist.
* Agent-mediated trade does **not** mean every human pairing should behave like a free, lawful market edge. Faction, legality, and cargo-provenance tags may gate whether an interaction is cooperative trade, illicit exchange, coercive seizure, or no trade at all.
* Active runtime contract cargo is protected delivery state, not generic bilateral trade inventory.
* This keeps the graph simple — the `Agent(Inventory)` node is the **only** mobile matter carrier. No station-to-station edge needed.
* **Graph impact:** No new edges. The existing `Agent(Trade)` ↔ `Grid(Stockpile)` edges handle all commerce. Agent diversity is behavioral, not structural.

### 8.4 Faction Influence → Emergent, Not Matter-Backed

**Decision:** Faction influence is a **soft informational overlay**, not backed by matter.

* Influence is defined by **who explored and colonized** a sector. The founding faction's identity persists through the colony.
* Colonies spawn agents of their faction. Those agents propagate population and influence to neighboring sectors naturally through trade and migration.
* In the live qualitative interaction layer, faction and legality remain informational tags, but they now also act as decision inputs for who humans cooperate with, trade with, coerce, or refuse.
* `faction_influence` is a signal (like Economic Heat), not a material. It doesn't enter the Axiom 1 sum.
* **Graph impact:** No new matter edges. Faction influence lives in the **Information Graph** (Section 5), not the Matter Graph. It's driven by agent population density and colony ownership.
* **Gameplay consequence:** Factions expand/contract organically based on economic success and population, not by spending resources on a "claim" mechanic.

### 8.5 Colony Level → Continuous Maintenance + Emergency Draft

**Decision:** Colony levels require **ongoing matter investment** to maintain. Technology and infrastructure are susceptible to decay. Additionally, colonies can **cannibalize** themselves to prevent softlocks.

* Colony upgrades remain threshold-based (stockpile + security over `COLONY_UPGRADE_TICKS_REQUIRED` ticks).
* **But** higher colony levels demand proportionally more maintenance matter per tick (tech/ore consumed to keep infrastructure running).
* If maintenance cannot be covered by current stockpiles, the colony degrades.
* **Emergency Draft:** When stockpiles hit zero and no agents remain, the colony downgrades one level, converting infrastructure matter into enough stockpile for one emergency agent spawn. At `frontier` level, a Faction Distress Signal is sent instead — the nearest surplus colony dispatches a relief agent (matter debited from that colony, not created).
* This creates a natural carrying capacity per sector — a colony can only sustain a level that its economy can feed.
* **Graph impact:** New edge in Section 3.4: `Station(Stockpile: Tech/Ore)` → `Hidden Resources + Hostile Pool` (maintenance waste follows the standard entropy split). Emergency Draft edge: `Colony Infrastructure` → `Station(Stockpile)`.
* **Gameplay consequence:** Colonies are living things, not permanent achievements. A supply disruption cascades: colony downgrade → reduced extraction → further supply problems → potential Emergency Draft → faction-wide resource strain.

### 8.6 Routine Human Conflict → Non-Lethal by Default

**Decision:** Routine human-to-human conflict should resolve through **non-lethal disruption** by default.

* Coercion, sabotage, interception, extortion, and forced dispersal are valid human interaction outcomes.
* Generic human interaction should not disable or destroy another human by default just because wealth, cargo, or aggression tags align.
* Lethal combat pressure should remain concentrated primarily in external hostile forces, with exceptional human lethality treated as a later explicit doctrine or combat-system seam rather than the default simulation baseline.
* **Graph impact:** No new matter edge is required for this doctrine. The primary change is to the live interaction gate and the kinds of chronicle events the human interaction seam emits.

### 8.7 Cargo Provenance And Legality → Qualitative Interaction Gates

**Decision:** Cargo provenance and legality are qualitative interaction gates, not a return to numeric inventory accounting.

* The live interaction seam may distinguish categories such as protected contract cargo, ordinary lawful cargo, illicit cargo, and salvage without introducing numeric trade ledgers.
* Those provenance tags determine whether another human treats the cargo as tradable, contraband, protected service state, or a coercive target.
* Protected runtime contract cargo must remain attached to the shared contract occurrence and reservation seam until a later milestone explicitly changes that rule.
* **Graph impact:** No new matter accounting bucket is added. Provenance is an interaction tag that changes routing and compatibility, not a separate conserved quantity.

### 8.8 Manual Space Graph & In-Sector POI Spawning

**Decision:** The inter-sector space graph is permanently manual and designer-authored. Dynamic sprouting or deep-space sector sprouting/decay is disabled.

* Space is partitioned statically as a manual graph (Star → Planet → Moon). Celestial role determines the development and security baseline.
* Dynamic content lives *within* sectors: derelicts, anomalies, deposits, and temporary outposts spawn dynamically inside the sector's 3D volume as local simulation objects.
* Exploration and prospecting mechanics interact with these in-sector POIs without adding new nodes to the world graph.
* **Graph impact:** The older agentic-sprouting and discovery pool model (drawing from `UNDISCOVERED_MATTER_POOL` to spawn new graph nodes) is **superseded** and marked inactive.

---

## Appendix A: Constants Cross-Reference

All constants referenced in this document, mapped to their definition in `constants.py` / `Constants.gd`:

| Graph Edge | Governing Constant | Current Value |
|---|---|---|
| Extraction rate | `CA_EXTRACTION_RATE_DEFAULT` | 0.01 |
| Consumption rate | `CONSUMPTION_RATE_PER_TICK` | 0.001 |
| Entropy tax | `CONSUMPTION_ENTROPY_TAX` | 0.03 (3%) |
| Fuel burn | `PROPELLANT_DRAIN_PER_TICK` | 0.5 |
| Ship energy waste | `ENERGY_DRAIN_PER_TICK` | 0.3 |
| Station power draw | `POWER_DRAW_PER_SERVICE` | 10.0 |
| Hostile spawn cost | `HOSTILE_SPAWN_COST` | 10.0 |
| Hostile spawn threshold | `HOSTILE_POOL_PRESSURE_THRESHOLD` | 500.0 |
| Wreck decay rate | `WRECK_DEGRADATION_PER_TICK` | 0.05 |
| Wreck salvage fraction | `WRECK_DEBRIS_RETURN_FRACTION` | 0.70 |
| Wreck slag fraction | `WRECK_SLAG_FRACTION` | 0.30 |
| Hostile wreck salvage | `HOSTILE_WRECK_SALVAGE_RATE` | 0.10 |
| Prospecting rate | `PROSPECTING_BASE_RATE` | 0.002 |
| Hostile raid threshold | `HOSTILE_RAID_THRESHOLD` | 5 |
| Hostile raid stockpile loss | `HOSTILE_RAID_STOCKPILE_FRACTION` | 0.05 |
| Catastrophe stockpile loss | `CATASTROPHE_STOCKPILE_TO_WRECK` | 0.60 |
| Axiom 1 tolerance | `AXIOM1_RELATIVE_TOLERANCE` | 0.015 (1.5%) |
| Mortal spawn min stockpile | `MORTAL_SPAWN_MIN_STOCKPILE` | 500.0 |
| Mortal spawn min security | `MORTAL_SPAWN_MIN_SECURITY` | 0.5 |
| Colony upgrade stockpile threshold | `COLONY_UPGRADE_STOCKPILE_FRACTION` | 0.6 |
| Colony upgrade security threshold | `COLONY_UPGRADE_SECURITY_MIN` | 0.5 |
| Colony upgrade ticks required | `COLONY_UPGRADE_TICKS_REQUIRED` | 200 |
| Colony downgrade stockpile threshold | `COLONY_DOWNGRADE_STOCKPILE_FRACTION` | 0.1 |
| Colony downgrade security threshold | `COLONY_DOWNGRADE_SECURITY_MIN` | 0.2 |
| Colony downgrade ticks required | `COLONY_DOWNGRADE_TICKS_REQUIRED` | 300 |
| Universal matter invariant | `UNIVERSE_CONSTANT` | *(set at init)* |
| Undiscovered matter pool | `UNDISCOVERED_MATTER_POOL` | *(set at init)* |
