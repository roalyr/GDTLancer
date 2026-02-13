--- Start of ./0.0-GDD-Internal-Rules-Conventions.md ---

# 0.0 GDTLancer - Internal GDD Rules and Conventions

**Version:** 2.0
**Date:** February 12, 2026
**Related Documents:** `0.1-GDD-Main.md`, `README.md`

---

## 1. Overview

This document defines the structural conventions for the GDTLancer Game Design Documentation (GDD).

---

## 2. GDD Structure & Numeration

* **Format:** `X.Y-GDD-<ChapterName>-<SubChapterName>.md`
* **Ordering:** Numerical prefixes ensure logical sort order. The `README.md` serves as the master index.

| Prefix | Domain |
|--------|--------|
| `0.x` | Vision, glossary, conventions |
| `1.x` | Core mechanics, systems, simulation |
| `2.x` | Development planning & scope |
| `3` | Coding architecture (Godot) |
| `4.x` | Analogue TTRPG *(deferred — see Section 4)* |
| `5.x` | Gameplay modules |
| `6.x` | Lore & narrative |
| `7.x` | Assets & style |
| `8` | Simulation architecture |

---

## 3. Standard Page Structure

Most GDD pages should follow this structure:

1. **Header:** Title, Version, Date, Related Documents.
2. **Overview:** Scope and purpose of the page.
3. **Core Content:** The design specification — lore, data parameters, system interactions.
4. **Phase 1 Scope:** What subset of this design is implemented in Phase 1.

---

## 4. Analogue TTRPG Status

The Analogue (Tabletop RPG) version shares lore and narrative themes with the Digital version but is **deferred** for active development. Documents `4.x` are retained for reference but not actively maintained. Individual GDD pages no longer require a dedicated "Analogue Implementation" section.

---

## 5. Citations

All GDD pages must use cross-references (e.g., `See 8-GDD-Simulation-Architecture.md Section 3`) to maintain traceability.

--- Start of ./0.1-GDD-Main.md ---

# GDTLancer - Main GDD

**Version:** 4.0
**Date:** February 13, 2026
**Related Documents:** `8-GDD-Simulation-Architecture.md`, `1.1-GDD-Core-Systems.md`, `3-GDD-Architecture-Coding.md`

## 1. Introduction

* **Game Title:** GDTLancer (Working Title)
* **Logline:** A space adventure RPG where player and AI actions shape a living world through a layered data-driven simulation.
* **Genre:** 3D Space Adventure, RPG, Sandbox, Simulation.
* **Theme:** Emergent stories from a simulated world; pragmatic, function-first sci-fi. Managing risk, time, and resources.
* **Target Audience:** Fans of Space Sims (Elite, Freelancer), Sandbox RPGs (Mount & Blade), Narrative TTRPGs (Stars Without Number).
* **Platform:** PC (Godot 3). Analogue TTRPG version deferred (see `0.0` Section 4).

## 2. Glossary

| Term | Definition |
|------|-----------|
| **Action Check** | Core dice roll for Narrative Actions: `3d6 + Module Modifier`. See `1-GDD-Core-Mechanics.md`. |
| **Agent** | An active entity pursuing goals. **Persistent** (named, permanent) or **Temporary** (population-budgeted). Non-human hostiles tracked as global integrals. |
| **Asset** | A significant non-consumable item (ship, equipment). |
| **Cash** | Physical commodity money — standardized refined metal units. The universe's only currency (**Axiom 3**). See `1-GDD` Section 6.1. |
| **Chronicle** | Output layer that captures events and translates them into player-facing narrative. See `8-GDD` Section 5. |
| **Conservation Axioms** | Five governing invariants (Matter, Population, Material Value, Thermodynamic Arrow, Causality) that constrain all simulation systems. See `8-GDD` Section 1.3. |
| **Contact** | A Persistent Agent the player has met. Synonymous with Persistent Agent. |
| **Equipment Slot** | A slot on a ship hull that accepts swappable equipment. Equipment provides Action Check modifiers or enables gameplay capabilities. See `7.1-GDD`. |
| **Faction** | A political/corporate entity with which the player gains or loses standing. |
| **G-Stasis Cradle** | In-lore tech enabling pilots to survive high-G maneuvers. |
| **Grid** | Dynamic systemic simulation layer driven by CA. See `8-GDD` Section 3. |
| **Knowledge Snapshot** | Agent's personal, potentially outdated copy of Grid data. See `8-GDD` Section 4.4. |
| **Loyalty Points (LP)** | Per-faction contribution credit. Earned by faction work, spent on faction services. Finite and tracked. See `1-GDD` Section 6.2. |
| **Module** | A set of mechanics for a specific activity (Combat, Piloting, Trading). |
| **Narrative Action** | An action resolved by dice roll (`3d6 + Modifier`), not real-time skill. See `1-GDD` Section 2.2. |
| **Population Budget** | Fixed initial human population; changes driven by economic integrals, not spawn dice (**Axiom 2**). |
| **Preservation Convention** | Cultural norm prioritizing ship disablement over destruction. |
| **Ship Quirk** | A negative trait acquired through damage. *Deferred — not implemented in Phase 1.* |
| **Skill Action** | An action resolved by real-time player performance. Outcome is authoritative. See `1-GDD` Section 2.1. |
| **World** | Static physical foundation layer. See `8-GDD` Section 2. |
| **World Event Tick** | Periodic simulation step that advances the Grid, Bridge Systems, and Agent state. See `8-GDD` Section 7. |
| **Wreck** | A disabled ship persisting in a sector as salvageable asset. Degrades via entropy; returns matter to Resource Potential Map when fully degraded. See `8-GDD` Section 3.7. |

## 3. Game Pillars

* **Living World:** Evolves based on all agents' actions and time passage, driven by the four-layer simulation (`8-GDD`).
* **Emergent Narrative:** Stories emerge from the simulation and player choices, surfaced via the Chronicle.
* **Meaningful Progression:** Improve skills, complete goals, acquire assets, build wealth.
* **Simple, Consistent Rules:** Unified `3d6 + Modifier` core mechanic.
* **Player Driven:** Players direct the experience by managing risk, time, and resources.

### 3.1. World Design: Finite Resource Sandbox

A small, tightly-scoped universe where every element is handcrafted, countable, and meaningful. Governed by Conservation Axioms (`8-GDD` Section 1.3) — total matter, population, and monetary mass are finite and tracked.

* **Comprehensible Scale:** The player can fully understand the world's actors, factions, and locations.
* **Emergent Lore:** Minimal starting lore. World history develops through gameplay.
* **Depth Before Breadth:** Perfect core systems before expanding quantity.
* **Controlled Expansion:** Procedural generation added sparingly in focused updates.

**Phase 1 Demo Scope:**

| Element | Quantity | Notes |
|---------|----------|-------|
| Factions | 3 | Miners, Traders, Independents |
| Locations | 6–9 | 2–3 per faction |
| Persistent Agents | 6 | 2 per faction |
| Player Ships | 2 | Starting + 1 unlockable |
| Commodities | 3–5 | Core trading goods (including Cash-grade refined metals) |
| Temporary Agent Types | 1–2 | Non-human hostiles (drones/fauna), global population integral |

## 4. Core Gameplay

* **Philosophy:** Simulation-first. Players interact with Modules and make choices about risk and resource management.
* **Modules:** Piloting, Combat, Trading. (Mining/Industrial, Investigation planned for later phases.)
* **Core Loop:** Use modules → key actions trigger Skill or Narrative resolution → outcomes affect World State and resources.

## 5. Simulation Architecture

The simulation operates on four data layers processed sequentially each World Event Tick:

1. **The World** — Static physical foundation (topology, hazards, resource potential).
2. **The Grid** — Dynamic systemic state driven by CA (resources, dominion, markets, entropy).
3. **The Agents** — Cognitive entities with physical state, knowledge, social graphs, goals.
4. **The Chronicle** — Event capture, causality chains, rumor engine.

Full specification: `8-GDD-Simulation-Architecture.md`.

## 6. Development Framework

* **Structure:** Organized by Modules (activities), Systems (cross-cutting rules), and the four simulation layers.
* **Phased Plan:**
    * **Phase 1 (Core Loop):** Playable vertical slice — Piloting, Combat, Trading with stub simulation layers.
    * **Phase 2 (Narrative):** Mining/Industrial; full CA-driven Grid; Inventory Flow.
    * **Phase 3 (Living World):** Investigation; full Agent knowledge/goals; Chronicle causality.

## 7. Art & Audio

* **Visuals:** "Neo-Retro 3D" — GLES2, medium-low-poly, hard-edged models. See `7-GDD-Assets-Style.md`.
* **Audio:** Minimalist, functional SFX and atmospheric music.
* **UI/UX:** Clean, non-intrusive, functional. See `7-GDD-Assets-Style.md`.

## 8. Technical

* **Engine:** Godot 3 (GLES2 backend).
* **Architecture:** Stateless systems operating on centralized `GameState`. See `3-GDD-Architecture-Coding.md`.
* **Modularity:** Systems are independent and maintainable.

--- Start of ./0.2-GDD-Main-Sayings.md ---

# GDTLancer - Mottos & Sayings

**Version:** 1.7
**Date:** February 12, 2026
**Related Documents:** `0.1-GDD-Main.md` (v3.0)

## 1. Purpose

This document lists mottos for the game and in-setting sayings that reflect the pragmatic culture of the sector's colonists. These phrases should inform character dialogue and ambient storytelling.

## 2. Game Motto (Development Ethos)

* **"GDTLancer: Delivered as Designed."**
    *(This is an external motto for the development team, reflecting a commitment to the GDD's scope.)*

## 3. In-Setting Sayings & Mottos

These phrases reflect the pragmatic, resilient, and resourceful culture of the people in this sector, shaped by the challenges of scarcity and exploration.

* "Waste not, want not."
    *(The most common adage, deeply ingrained in the culture.)*

* "Measure the cost, master the consequence."
    *(Reflects a cultural focus on calculated risk-taking.)*

* "Every component has a purpose."
    *(Highlights the importance of efficiency, repair, and modularity.)*

* "A broken tool teaches a lesson."
    *(A practical view on failure as a learning opportunity.)*

* "Skill carves status; action defines worth."
    *(The core of a meritocratic, frontier-style society.)*

* "Good salvage makes good neighbors."
    *(A cynical but common phrase related to resource acquisition.)*

* "The void yields to the prepared."
    *(Emphasizes the value of foresight and expertise.)*

--- Start of ./1.1-GDD-Core-Systems.md ---

# GDTLancer - Core Systems (Phase 1)

**Version:** 5.0
**Date:** February 13, 2026
**Related Documents:** `0.1-GDD-Main.md` (v4.0), `8-GDD-Simulation-Architecture.md`, `3-GDD-Architecture-Coding.md`

## 1. Overview

Defines the stateless system APIs that implement the simulation architecture. All systems are `Node` scripts in `core/systems/`, parented under `WorldManager`. They read from and write to `GameState` — they hold no state of their own.

Each system maps to one or more simulation layers from `8-GDD-Simulation-Architecture.md`.

## 2. Systems

### System 1: Time System
* **Script:** `core/systems/time_system.gd`
* **Sim Layer:** Bridge — drives the World Event Tick sequence (`8-GDD` Section 7).
* **Responsibility:** Manage the real-time clock. When `Constants.TIME_TICK_INTERVAL_SECONDS` elapses, emit `world_event_tick_triggered` on `EventBus`, then trigger the tick sequence: Grid CA → Bridge Systems → Agent processing → Chronicle.
* **Phase 1:** Operational. Triggers Grid CA stubs and Bridge System entropy processing.

### System 2: Event System
* **Script:** `core/systems/event_system.gd`
* **Sim Layer:** Grid (CA engine) + Chronicle (event generation).
* **Responsibility:** Generate in-game events (ambushes, market opportunities, distress calls) based on Grid state and time passage. Feed Event Packets into the Chronicle's Event Buffer.
* **Phase 1:** Triggers combat encounters from Free Flight. Stub CA processing.

### System 3: Character System
* **Script:** `core/systems/character_system.gd`
* **Sim Layer:** Agent (operational capacity, social graph).
* **Responsibility:** Stateless API for `GameState.characters`. Manage skills, cash reserves, faction/character standings, reputation, loyalty points.
* **Key API:** `add_cash(uid, amount)`, `subtract_cash(uid, amount)`, `get_skill_level(uid, skill_name)`, `add_lp(uid, faction_id, amount)`, `get_lp(uid, faction_id)`.

### System 4: Inventory System
* **Script:** `core/systems/inventory_system.gd`
* **Sim Layer:** Agent (cargo) + Grid (commodity stockpiles, `8-GDD` Section 3.6).
* **Responsibility:** Manage inventories in `GameState.inventories`.
* **Key API:** `add_asset(uid, type, id, qty)`, `remove_asset(uid, type, id, qty)`, `get_asset_count(uid, type, id)`.

### System 5: Asset System
* **Script:** `core/systems/asset_system.gd`
* **Sim Layer:** Agent (physical state, maintenance state — `8-GDD` Sections 4.1, 4.3).
* **Responsibility:** Stateless API for ship instances in `GameState.assets_ships`. Tracks hull integrity, heat level, propellant/energy reserves, equipped slot configuration, fleet ownership.
* **Key API:** `get_ship(uid)`, `get_player_ship()`, `get_fleet(uid)`, `transfer_ship(from_uid, to_uid, ship_id)`. Ship stats: `cargo_capacity`, `hull_integrity`, `current_heat_level`, `equipped_slots`.
* **Repair:** `repair_hull(uid, amount)` — consumes physical materials from station `commodity_stockpiles` via Inventory System. No materials = no repair (**Axiom 3**).
* **Phase 1:** Heat is a binary check (overheating Y/N). Ships use hull+slot model (see `7.1-GDD`). Ship Quirks and Component Degradation are deferred. Repair costs a fixed material amount.

### System 6: Agent System
* **Script:** `core/systems/agent_system.gd`
* **Sim Layer:** Agent (spatial state, knowledge, goals, narrative inventory — `8-GDD` Sections 4.1, 4.4–4.7).
* **Responsibility:** Manage lifecycle of all agents. Track location, disabled status, respawn timers, goal queues, knowledge snapshots.
* **Social Layer:** Persistent Agents have a detached social overlay — personality, goals, and player interaction depth — operating independently from their CA grid token. This layer drives dialogue, relationship building, and narrative depth (similar to lords in Mount & Blade or NPCs in Dwarf Fortress). NPC behavior emerges from personality traits + goal heuristics, not manual scripting.

**Agent Categories:**

| | Persistent | Temporary |
|---|-----------|-----------|
| **Lifespan** | Permanent, respawns at home base | Transient, removed on disable |
| **Agency** | Full goal-driven behavior | Simple reactive behavior |
| **Personality** | Unique traits (risk_tolerance, greed, loyalty, aggression) | None — type-based |
| **Relationships** | Tracked standings | None |

**Phase 1 Roster:**

| ID | Name | Faction | Home Base | Traits |
|----|------|---------|-----------|--------|
| `kai` | Kai | Miners | mining_outpost_alpha | Pragmatic, experienced |
| `juno` | Juno | Miners | mining_outpost_beta | Ambitious, impatient |
| `vera` | Vera | Traders | trade_hub_central | Cautious, calculating |
| `milo` | Milo | Traders | trade_hub_rim | Opportunistic, friendly |
| `rex` | Rex | Independents | freeport_station | Risky, independent |
| `ada` | Ada | Independents | salvage_yard | Resourceful, quiet |

## 3. Template Definitions

### CharacterTemplate Properties
```
├── character_name: String
├── faction_id: String
├── cash: int
├── loyalty_points: Dictionary  # {faction_id: int}
├── skills: {piloting: int, combat: int, trading: int}
├── personality_traits: {risk_tolerance: float, greed: float, loyalty: float, aggression: float}
├── goals: Array
├── reputation: int
├── faction_standings: Dictionary
└── character_standings: Dictionary
```

### AgentTemplate Properties
```
├── agent_type: String ("player", "npc", "hostile")
├── agent_uid: int
├── is_persistent: bool
├── home_location_id: String
├── character_template_id: String
└── respawn_timeout_seconds: float
```

*Note: `CoreMechanicsAPI` (`autoload/CoreMechanicsAPI.gd`) provides `perform_action_check()` but is a utility, not a system.*

--- Start of ./1.2-GDD-Core-Cellular-Automata.md ---

# GDTLancer - Cellular Automata

**Version:** 2.0
**Date:** February 12, 2026
**Related Documents:** `0.1-GDD-Main.md` (v3.0), `8-GDD-Simulation-Architecture.md`

## 1. Overview

CA implementations are background simulation engines that drive the **Grid layer** (`8-GDD` Section 3). They run during step 2 of the World Event Tick sequence, updating resource availability, faction dominion, market pressure, and social networks. Their outputs feed Agent decision-making and Chronicle event generation.

The player influences CA indirectly through gameplay actions. Results are surfaced via diegetic means: maps, descriptions, dialogue, and evolving opportunities.

**Phase 1:** All CAs are lightweight stubs advanced by the World Event Tick and influenced by player Action outcomes.

## 2. World & Economy CAs

### CA 1: Strategic Map
* **Grid Params:** `faction_influence`, `security_level`, `pirate_activity` (`8-GDD` Section 3.3).
* **Behavior:** Models faction control and pirate activity. Player actions (faction contracts, combat) modify values; CA propagates influence to neighbors each tick.
* **Player Feedback:** "Sector Intel Map" — colored overlays showing dominant faction, text stats ("Pirate Activity: Declining").

### CA 2: Supply & Demand Flow
* **Grid Params:** `commodity_stockpiles`, `commodity_price_deltas`, `extraction_rate` (`8-GDD` Sections 3.4, 3.6).
* **Behavior:** Player trade actions change local stockpile levels. Extraction draws from finite Resource Potential Map (**Axiom 1**). Surplus/deficit states propagate to neighbors over ticks.
* **Player Feedback:** "Station Bulletin Board" — narrative rumors ("Surplus of Scrap Metal at Scrapyard Station").

## 3. Social CAs

### CA 3: Influence Network
* **Agent Params:** `character_standings`, `sentiment_tags` (`8-GDD` Section 4.5).
* **Behavior:** Information and reputation spread through NPC contact networks each tick.
* **Player Feedback:** Contextual dialogue referencing second-hand knowledge.

### CA 4: Rivalry & Alliance
* **Agent Params:** `character_standings` between NPCs.
* **Behavior:** Player actions in "Contact Dilemma" events shift NPC-to-NPC relationships.
* **Player Feedback:** Conflicting missions; accepting from one Contact may lock out their rival.

### CA 5: Trust & Deception
* **Chronicle Params:** `trust_tag` on rumors (`8-GDD` Section 5.3).
* **Behavior:** Rumors are tagged with trust levels based on source and relay hops.
* **Player Feedback:** UI tags: `[Verified Intel]`, `[Market Rumor]`, `[Unconfirmed Hearsay]`.

### CA 6: Favor & Obligation
* **Agent Params:** `sentiment_tags` (`"owes_favor"`, `"owed_favor"`).
* **Behavior:** Player actions create favor/debt states with Contacts.
* **Player Feedback:** Contextual options: `[Call in Favor]` or obligation warnings.

## 4. Agent CAs

### CA 7: Personal Goal Progression
* **Agent Params:** `goal_queue` progress (`8-GDD` Section 4.6).
* **Behavior:** NPC goal progress ticks slowly; player actions provide boosts.
* **Player Feedback:** "Contacts Panel" progress bars; completion messages.

## 5. Future Phase CAs

| CA | Phase | Description |
|----|-------|-------------|
| System Surveying | 2 | Anomaly mapping mini-simulation |
| Salvage Analysis | 2 | Reverse-engineering mini-simulation |
| Ideological Alignment | 3 | Location-based social stance shifts |

--- Start of ./1-GDD-Core-Mechanics.md ---

# GDTLancer - Core Mechanics

**Version:** 5.0
**Date:** February 13, 2026
**Related Documents:** `0.1-GDD-Main.md` (v4.0), `8-GDD-Simulation-Architecture.md`

## 1. Purpose

Defines the universal rules for resolving actions and managing core resources. Used across all gameplay modules.

## 2. Action Categories

Player actions fall into two distinct categories:

### 2.1. Skill Actions (Real-Time)

Actions resolved by real-time player performance. The outcome is authoritative — no dice roll overrides it.

* **Examples:** Ship combat, flight challenges, manual docking.
* **Outcome:** Determined entirely by player skill and ship stats during the real-time gameplay segment.

### 2.2. Narrative Actions (Dice-Resolved)

Actions resolved by the Action Check mechanic. Used for social, economic, and situational decisions where the outcome depends on character capability rather than player reflexes.

* **Examples:** Negotiations, trade deals, information gathering, post-event assessments.
* **Outcome:** `3d6 + Module Modifier` against thresholds.
* **Presentation:** Implicit (auto-resolved, result shown as toast/log) or Explicit (full dice UI with Approach choice), depending on Action Stakes.

### 2.3. Special Followup Triggers

A Skill Action may trigger a Narrative Action *only* when a significant followup decision presents itself — e.g., deciding what to do with wreckage after a combat victory. The Skill Action outcome stands; the Narrative Action resolves the *consequence choice*, not the skill performance.

## 3. Action Check

Used for Narrative Actions with an uncertain outcome.

* **Core Mechanic:** `3d6 + Module Modifier`
* **Module Modifier:** `Relevant Skill + Equipment Modifier +/- Situational Modifiers`

### 3.1. Thresholds

| Approach | Success With Complication | Critical Success |
|----------|---------------------------|------------------|
| Cautious | ≥10 | ≥14 |
| Neutral | ≥11 | ≥15 |
| Risky | ≥12 | ≥16 |

**Failure:** Any roll below the Success threshold.

## 4. Action Approach

A choice made *before* rolling that shifts the risk/reward curve. Only offered for **High-Stakes** Narrative Actions.

* **Act Cautiously:** Failure is less severe; success offers no bonus.
* **Act Risky:** Success is more rewarding; failure is more severe.

## 5. Action Stakes (Digital)

Narrative Actions are classified by stakes tier (hardcoded in `action_*.tres` templates):

| Stakes | UI | Approach Choice | Dice Display |
|--------|-----|-----------------|--------------|
| **High-Stakes** | Full modal | Yes (Risky/Cautious) | Animated roll |
| **Narrative** | Brief toast | No (Neutral auto) | Quick toast |
| **Mundane** | Log only | No (Neutral auto) | Hidden |

## 6. Core Resources

### 6.1. Cash (Hard Currency)

* Physical commodity money — standardized refined metal units. There is no fiat currency (**Axiom 3**, `8-GDD` Section 1.3).
* Total Cash in the universe is finite and materially grounded: the monetary mass equals the physical resource mass allocated as medium of exchange.
* Used for inter-faction and universal trade: ships, equipment, repairs (which consume materials from station stockpiles), and services.
* Earned from trade (buying/selling commodities), salvage (reclaiming disabled ships and their cargo), and goal completion rewards.
* Cash can be physically carried (in cargo) or stored at stations. Cargo Cash is at risk during combat.

### 6.2. Loyalty Points (LP)

* Per-faction contribution credit. Earned by completing faction-aligned work (contracts, reputation milestones).
* Spent at faction-specific services: discounted repairs, exclusive equipment, priority docking, faction intel.
* Finite supply per faction per period — tracked by player contribution, not infinitely farmable.
* **Phase 1:** LP is a stub counter. Displayed in Contact/Faction panels but with limited spending options.

### 6.3. Time

* Real-time clock. World Event Ticks fire at `Constants.TIME_TICK_INTERVAL_SECONDS`.
* Time is a critical resource — the world evolves independently of the player.
* Each tick triggers: Grid CA updates (including extraction from finite Resource Potential Map) → Bridge Systems (entropy, heat) → Agent processing → Chronicle capture.

## 7. Failure & Recovery

Loss is **substantial but not terminal** — part punishment, part opportunity.

### 7.1. Ship Disabled (Hull → 0)

* Ship is disabled, not destroyed (Preservation Convention).
* The disabled ship persists in the sector as a **salvageable wreck** (`8-GDD` Section 3.7) containing its cargo and equipment.
* Player is recovered to the nearest station. Recovery costs Cash (proportional to distance) or may be free if a Contact intervenes.
* **Salvage:** Any agent (including the player, if they return) can attempt to claim or repair the wreck. If you can repair it, it's yours. Wrecks degrade over time via entropy — unclaimed wrecks eventually become debris, returning matter to the Resource Potential Map.
* **Opportunity:** Recovery event may trigger unique Narrative Actions (rescued by a Contact, indebted to a faction, discovered something during drift).

### 7.2. Resource Depletion

* **Cash at 0:** Player can still fly and trade but cannot purchase services or equipment. NPCs may offer emergency work (low-pay, high-risk goals). Salvage is always available as a recovery path.
* **Propellant at 0:** Ship is stranded. Distress beacon triggers a recovery event (see 7.1).

### 7.3. True Game Over

True game over requires a **convergence of multiple failures** — not a single bad roll or fight. The player must reach a state where recovery paths are exhausted (e.g., disabled with zero Cash, hostile standings with all factions, no Contacts willing to help). This is intentionally difficult to achieve.

* **Phase 1:** True game over is not implemented. Player is always recoverable via mentor NPC or emergency bailout.

--- Start of ./2.1-GDD-Development-Phase1-Scope.md ---

# GDTLancer - Phase 1 Scope & Goals

**Version:** 2.0
**Date:** February 12, 2026
**Related Documents:** `0.1-GDD-Main.md` (v3.0), `1.1-GDD-Core-Systems.md` (v3.0), `8-GDD-Simulation-Architecture.md`

## 1. Phase 1 Vision: "The First Contract" Demo

A playable vertical slice proving the core gameplay loops: skill-based simulation + consequential TTRPG-style narrative mechanics. Must feel cohesive and purposeful.

## 2. Core Player Experience (Digital PC)

The player will:
* Start with a pre-owned ship and small Cash balance.
* Engage with named **Contacts** at stations; build **Relationship** scores.
* Take faction goals affecting **Faction Standing** and earning **Loyalty Points (LP)**.
* Trade a limited commodity set via the **Trading Module** in a conserved-matter economy.
* Fly in **Free Flight** (Piloting Module); time passes in real-time with periodic **World Event Ticks** advancing the simulation.
* Face non-human hostiles (drones/fauna) drawn from a global population integral in skill-based **Combat Challenges**.
* Resolve key moments via **Narrative Actions** — High-Stakes actions prompt Risky/Cautious approach; others resolve automatically.
* Salvage disabled ships as repairable assets or strip them for Cash and equipment.
* Invest Cash in **Asset Progression** toward a second ship.

## 3. Included Components

### Modules
| Module | Version | Notes |
|--------|---------|-------|
| Piloting | v1.6 | Three-mode flight system |
| Combat | v1.4 | Hull-only targeting |
| Trading | v1.1 | Static markets |

### Core Systems
Event, Time, Character, Inventory, Asset systems.

### Narrative Stubs
* **Chronicle Stub ("Sector Stats"):** Player impact statistics.
* **Persistent Agent System:** Manages 6 named characters with social layer overlay — personality, goals, and interaction depth operating independently from CA grid tokens. NPC behavior emerges from personality traits + goal heuristics, not manual scripting.
* **Reputation Ledger, Faction Standing.**

## 4. Content Checklist

| Category | Minimum |
|----------|---------|
| Locations | 6–9 sectors (2–3 per faction), each with a station |
| Player Ships | Starting ship + 1 unlockable via Asset Progression |
| NPC Ships | 1 hostile type |
| Commodities | 3–5 types (including Cash-grade refined metals) |
| Persistent Agents | 6 named (2 per faction) — see `1.1-GDD` roster |
| Factions | 3 (Miners, Traders, Independents), 2–3 bases each |
| Temporary Agents | Non-human hostiles (1–2 types): drones/fauna, global population integral |
| UI | Main HUD, Trade, Contracts, Hangar, Contact/Faction panels |

## 5. Development Milestones

### Milestone 1: Foundational Systems
* [**Done**] Time System Phase 1 functionality.
* [**Done**] Character, Asset, and Inventory Systems.
* [**Done**] Data structures for all narrative stubs.
* [**Done**] Core Mechanics API functional.

### Milestone 2: The Player in the World
* [**Done**] Player spawned in Zone with starting ship.
* [**Done**] Piloting Module Free Flight functional.
* [**Done**] Main HUD displaying ship status.
* [**Done**] Time System connected to flight; ticks advance simulation.
* [**Done**] Basic UI for narrative stubs (Reputation, Contacts, Factions, Sector Stats).

### Milestone 3: The Economic Loop
* [**Done**] Trading Module: buy/sell commodities.
* [ ] Trading narrative actions affecting Contact relationships and Faction Standing.

### Milestone 4: Combat & Asset Progression
* [**Done**] Event System triggers combat encounters.
* [**Done**] Combat Challenge functional (targeting, weapons, damage).
* [ ] Combat followup narrative actions affecting Reputation and Faction Standing.
* [ ] Salvage system: disabled ships become wrecks, reclaimable as fleet assets or stripped for Cash/equipment.
* [ ] Asset Progression "Hangar" UI for investing Cash toward second ship.

### Milestone 5: Cohesion & Polish
* [ ] Guided "first contract" introducing all core loops.
* [ ] Clean flow: Main Menu → first contract completion.
* [ ] Balancing pass: Credit rewards, Action Check difficulties.
* [ ] Final bug fixing for stable, playable demo.

--- Start of ./2-GDD-Development-Challenges.md ---

# GDTLancer - Development Challenges

**Version:** 2.0
**Date:** February 12, 2026
**Related Documents:** `0.1-GDD-Main.md` (v3.0), `8-GDD-Simulation-Architecture.md`

## 1. Overview

Key development risks for GDTLancer, identified early for proactive mitigation.

## 2. Design Challenges

### Emergent Narrative Complexity
Making the "living world" produce coherent, engaging stories — not random noise.

* **Mitigations:** Phased rollout of Agent complexity. Clear NPC goal-selection heuristics (`8-GDD` Section 4.6). Chronicle system (`8-GDD` Section 5) logs events for Agent reactions.

### Balancing Agency and Simulation
Players must feel impactful without easily breaking the simulation.

* **Mitigations:** Soft gates via narrative and economic pressure (entropy system, equipment lateral progression). Grid-layer CA propagation dampens local player impact over time.

## 3. Mechanical Challenges

### Meaningful Risky/Cautious Outcomes
The approach mechanic needs varied, interesting outcomes — a significant content task.

* **Mitigations:** Systemic outcomes (standing shifts, salvage quality, fleet consequences) over static text. Templated outcome patterns. Digital Action Stakes limit full approach choice to High-Stakes actions only.

## 4. Technical Challenges

### Simulation Performance
Many agents with individual state/goals is CPU-intensive.

* **Mitigations:** Agent LOD — distant agents use simplified tick processing. Major simulation changes batched to World Event Ticks (`8-GDD` Section 7).

--- Start of ./3-GDD-Architecture-Coding.md ---

# GDTLancer - Coding Standards & Architecture Guide

**Version:** 3.0
**Date:** February 12, 2026
**Related Documents:** `0.1-GDD-Main.md` (v3.0), `8-GDD-Simulation-Architecture.md`

## 1. Engine & Language

* **Engine:** Godot Engine v3.x
* **GUT version:** 7.4.3
* **Renderer:** GLES2 (performance & compatibility)
* **Language:** GDScript (static typing hints where beneficial)

## 2. Core Philosophy

* **KISS:** Prefer simpler implementations. Clarity over excessive abstraction.
* **Modularity:** Split scripts exceeding ~300 lines. Structure around:
    * **Modules** (horizontal activity loops): Piloting, Combat, Trading.
    * **Systems** (cross-cutting rulesets): Events, Goals, Assets, etc.
* **Simulation Foundation + Narrative Layer:** Build core gameplay around simulation. Layer narrative mechanics (Action Checks, Events, Goals) on top.
* **Reusability:** Leverage Godot scene instancing and Resources.
* **Decoupling:** Minimize hard dependencies. Use `EventBus` for signaling. Use `GlobalRefs` only for essential unique managers.
* **Adhere to architecture.** No redundant code. Follow established patterns (Autoloads, Resources, data-logic separation).

## 3. Code Formatting

* **Formatter:** `gdformat` for uniform style.
* **Indentation:** Tabs.
* **Line Length:** ~100 characters max.
* **Conditionals:** No single-line `if` lumping — body on new indented line.
* **`export var`:** Only in template files (e.g., `AgentTemplate`). Logic scripts use `initialize()`.
* **Naming:**
    * `snake_case` — variables, functions, signals. Leading `_` for private.
    * `PascalCase` — class names, scene tree node names.
    * `ALL_CAPS_SNAKE_CASE` — constants.
* **Comments:** Explain *why*, not *what*.

## 4. Autoload Singletons

| Autoload | Role |
|----------|------|
| `Constants` | Global constants (paths, names, tuning) |
| `GlobalRefs` | References to unique managers/nodes |
| `EventBus` | Central signal dispatcher |
| `CoreMechanicsAPI` | Core rule resolution functions |
| `GameStateManager` | Save/load logic |
| `GameState` | **Single source of truth** for all persistent data — backing store for all four simulation layers (`8-GDD`) |
| `TemplateDatabase` | Caches loaded `.tres` templates on startup |

## 5. Stateless Systems Architecture

**`GameState` is the Source of Truth.** All dynamic, persistent game data lives here: World data (Layer 1), Grid state (Layer 2), Agent data (Layer 3), Chronicle events (Layer 4).

**Systems are Stateless APIs.** Core systems in `core/systems/` are `Node` scripts parented under `WorldManager`. They hold no data. Each provides a clean API that reads/writes `GameState`.

* Example: `CharacterSystem.add_cash(uid, amount)` retrieves the character from `GameState.characters`, modifies `cash`, emits signal on `EventBus`.
* Getters returning `Dictionary` or `Array` **must** return `.duplicate(true)` copies.
* Systems react to and emit signals via `EventBus` (e.g., `_on_world_event_tick`, `player_cash_changed`).

### System Checklist (New System)
1. Place in `core/systems/`, `extends Node`, child of `WorldManager`.
2. Register with `GlobalRefs` in `_ready()`.
3. Connect to required `EventBus` signals.
4. **No persistent state variables** — read/write `GameState` only.
5. Action methods modify `GameState`; getter methods return safe copies.

## 6. Resource Templates

* Custom `Resource` scripts (`extends Resource`, `class_name`) define data structures.
* Template definitions: see `1.1-GDD-Core-Systems.md` Section 5.
* **Action Templates:** `action_*.tres` files include `stakes` property (`HIGH_STAKES`, `NARRATIVE`, `MUNDANE`) determining UI behavior.

## 7. Physics Abstraction

No rigid-body physics. "Faked physics" via state-based rules and interpolation.

* **Movement:** `KinematicBody.move_and_slide()` with velocity managed by component scripts.
* **Smoothing:** `linear_interpolate()` for acceleration/deceleration/braking.
* **PID Controllers:** Reusable `PIDController` class for goal-oriented behaviors (navigation, camera).

## 8. Save & Load

`GameStateManager` serializes/deserializes `GameState` directly.

**Save:** `save_game(slot_id)` → `_serialize_game_state()` builds `save_data` dict from `GameState` → writes to file.

**Load:** `load_game(slot_id)` → reads `save_data` → `_deserialize_and_apply_game_state()` clears and repopulates `GameState` → emits `game_state_loaded` signal. UI refreshes by pulling from system APIs.

## 9. Unit Testing (GUT 7.4.3)

### Test Priorities
* **Required:** Core Systems/APIs, complex components (`PIDController`, `MovementSystem`, `NavigationSystem`), utility scripts.
* **Not Required:** UI scripts, simple glue/delegation scripts.

### Practices
* Tests in `tests/` directory mirroring project structure.
* Independent tests — use `before_each()`/`after_each()` for setup/teardown.
* Mock complex dependencies with doubles.

## 10. Component Pattern

* Child Nodes with attached scripts encapsulate distinct functionality (e.g., `MovementSystem`, `NavigationSystem`).
* Scene instancing for Agents, Zones, UI assembly.
* Initialize via `initialize(config)` **after** node is added to tree.

--- Start of ./4.1-GDD-Analogue-Setup.md ---

# GDTLancer - Analogue TTRPG Setup

**Status:** DEFERRED — See `0.0-GDD-Internal-Rules-Conventions.md` Section 4.

The Analogue TTRPG version of GDTLancer is deferred to a future development phase. Core design effort is focused on the Digital (Godot) implementation. This file is retained as a placeholder for future expansion.

--- Start of ./4.2-GDD-Analogue-Setup-Formatting.md ---

# GDTLancer - Analogue Setup Formatting

**Status:** DEFERRED — See `0.0-GDD-Internal-Rules-Conventions.md` Section 4.

The Analogue TTRPG formatting guidelines are deferred to a future development phase. This file is retained as a placeholder.

--- Start of ./4.3-GDD-Analogue-Phase1-Scope.md ---

# GDTLancer - Analogue Phase 1 Scope

**Status:** DEFERRED — See `0.0-GDD-Internal-Rules-Conventions.md` Section 4.

The Analogue TTRPG Phase 1 scope is deferred. Digital Phase 1 scope is defined in `2.1-GDD-Development-Phase1-Scope.md`.

--- Start of ./5.1-GDD-Module-Piloting.md ---

# GDTLancer - Piloting Module

**Version:** 4.0
**Date:** February 13, 2026
**Related Documents:** `1-GDD-Core-Mechanics.md` (v4.0), `8-GDD-Simulation-Architecture.md`

## 1. Overview

Governs all ship movement and its interaction with the core game loop. Two distinct modes create clear separation between real-time skill gameplay and narrative resolution.

**Simulation Layer Mapping:** Free Flight advances the World Event Tick (`8-GDD` Section 7), consuming time and triggering entropy processing (Bridge: Heat Sink, Entropy). Ship movement draws from `current_heat_level` budgets (Bridge: Heat Sink).

## 2. Mode 1: Free Flight (Skill Action)

Default mode for intra-system travel — connective tissue between points of interest.

* **Control:** Direct ship control via "boost and drift" flight model (`MovementSystem`, `NavigationSystem`).
* **Time:** Continuously advances real-time, triggering periodic **World Event Ticks**.
* **Events:** The **Event System** can trigger encounters (distress call, ambush), transitioning to a **Flight Challenge**.

## 3. Mode 2: Flight Challenge (Skill Action)

Self-contained, objective-based scenarios testing player skill. Outcome is authoritative.

* **Trigger:** Event from Free Flight or mission-required objective.
* **Objective-Based:** Clear binary success condition:
    * Neutralize all hostile targets (→ Combat Module rules).
    * Survive for a specific duration.
    * Reach a specific coordinate.
* **Pure Skill:** No Action Checks. Success determined entirely by real-time player performance.
* **Ship Stats Matter:** Equipment modifiers directly affect handling, speed, durability.

## 4. Followup Narrative Actions

Optional Narrative Actions triggered only when a significant decision point arises after a Flight Challenge (see `1-GDD` Section 2.3).

* **Trigger:** Specific post-challenge conditions (not mandatory after every challenge).
* **Mechanic:** `3d6 + Module Modifier` Action Check.
* **Action Stakes:** Per action template.

### Phase 1 Piloting Actions
| Action | Trigger Condition | Stakes | Outcome |
|--------|-------------------|--------|---------|
| Perform Evasive Departure | Fleeing from superior force | Narrative | Clean getaway vs. tracked/hull damage |
| Execute Precision Arrival | Docking at damaged/hostile station | Narrative | Clean dock vs. minor hull damage |

## 5. Required Phase 1 Stats

* **Agent:** `skill_piloting` — base for Module Modifier.
* **Ship:** `mass` (inertia/drift), `max_turn_speed` (agility), `acceleration`/`max_move_speed` (thruster power).
* **Systems:** Time, Event, CoreMechanicsAPI, Asset, Character.

--- Start of ./5.2-GDD-Module-Combat.md ---

# GDTLancer - Combat Module

**Version:** 3.0
**Date:** February 13, 2026
**Related Documents:** `1-GDD-Core-Mechanics.md` (v4.0), `6-GDD-Lore-Narrative-Borders.md`, `8-GDD-Simulation-Architecture.md`

## 1. Overview

Ship-to-ship conflict adhering to the **Preservation Convention**. Prioritizes **disabling and capturing vessels** over destruction — reflecting the cultural and economic value placed on preserving assets. No energy shields; combat focuses on hull integrity and equipped **Utility Tools**.

**Simulation Layer Mapping:** Combat damage modifies Agent-layer `hull_integrity` (`8-GDD` Section 4.1). Disabled ships become **salvageable wrecks** (`8-GDD` Section 3.7) — their cargo, equipment, and hull persist in the sector for reclamation. Outcomes feed Chronicle events (`8-GDD` Section 5). Combat heats ship systems (Bridge: Heat Sink). All matter is conserved (**Axiom 1**): nothing is destroyed, only disabled and potentially salvaged.

## 2. Combat Challenge (Skill Action)

Direct, real-time engagement. The combat outcome is **authoritative** — no dice roll overrides it.

* **Trigger:** Event from Free Flight (ambush) or mission requirement.
* **Gameplay:** Direct ship control + equipped Utility Tools. Maneuvering, aiming, and tool use (ablative lasers, rotary drills, grapples). G-Stasis Cradle enables high-thrust industrial tactics.
* **Targeting (Phase 1):** Main hull only.
* **Objective:** All hostiles neutralized (Hull Integrity → 0 or disable condition met).
* **Pure Skill:** No Action Checks during the challenge.
* **Defeat:** Player ship disabled → recovery event (see `1-GDD` Section 7.1).

## 3. Followup Narrative Actions

Optional Narrative Actions triggered after combat when a significant decision point arises (see `1-GDD` Section 2.3). These resolve *consequence choices*, not combat performance.

* **Trigger:** Specific post-combat conditions (e.g., wreckage present, faction ship involved).
* **Mechanic:** `3d6 + Module Modifier` Action Check.
* **Action Stakes:** Per action template.
* **Consequences:** Modify Reputation, Faction Standing. Disablement/capture always more rewarding than destruction.

### Phase 1 Combat Actions
| Action | Trigger Condition | Stakes | Outcome |
|--------|-------------------|--------|---------|
| Assess the Aftermath | Any combat victory | Narrative | Reveal faction affiliations / intel vs. misidentification |
| Claim Wreckage | Wreck persists in sector | High-Stakes | Salvage equipment/cargo/Cash from wreck inventory vs. unstable wreck. Risky approach → more salvage but Reputation cost. If ship is repairable, claim it for your fleet (**Axiom 1**: matter transferred, not created). |

## 4. Required Phase 1 Stats

* **Agent:** `skill_combat` — base for Module Modifier.
* **Ship:** `hull_integrity`, equipped **Utility Tools** (damage, range, grapple effects).
* **Wreck:** `wreck_integrity`, `wreck_inventory` — from `8-GDD` Section 3.7.
* **Systems:** Event, Time, CoreMechanicsAPI, Asset, Character, Inventory.

--- Start of ./5.3-GDD-Module-Trading.md ---

# GDTLancer - Trading Module

**Version:** 3.0
**Date:** February 13, 2026
**Related Documents:** `1-GDD-Core-Mechanics.md` (v4.0), `8-GDD-Simulation-Architecture.md`

## 1. Overview

Governs all economic activities: buying/selling commodities. Primary loop for accumulating **Cash** (physical commodity money — refined metals). Trading is a **Narrative Action** domain — outcomes depend on character skill and dice, not real-time reflexes.

**Simulation Layer Mapping:** Trade actions modify Grid-layer `commodity_stockpiles` (`8-GDD` Section 3.6). Prices use static base values with CA-driven modifiers applied on top (`8-GDD` Section 3.4). CA 2 (Supply & Demand Flow, `1.2-GDD`) propagates price changes across locations. All traded goods are physically conserved (**Axiom 1**): selling moves units from agent cargo to station stockpile; buying reverses the transfer. No matter is created or destroyed.

## 2. Core Mechanic: The Trade Interface

UI-based hub for market activity.

* **Trigger:** Player docks at a market location.
* **Market:** Menu displays player cargo, station inventory, buy/sell prices. Execute buy/sell orders.
* **Pricing:** Base commodity prices are static. CA-driven `commodity_price_deltas` modify prices per location based on local supply/demand conditions. Player trade actions feed back into the CA.
* **Economic Loop:** Buy low, sell high for net profit in Cash. Profit comes from price differentials between locations — the total Cash in the system is redistributed, not created. Stations that sell at a loss deplete their cash reserves; stations with depleted stockpiles cannot sell.
* **Loyalty Points:** Faction-aligned trade (selling needed goods to your faction's station) earns LP in addition to Cash. LP spent on faction-exclusive services.

## 3. Narrative Actions in Trading

Social and economic decisions resolved by dice rolls — implicit (auto-resolved, result as toast) or explicit (full dice UI), depending on Action Stakes.

* **Mechanic:** `3d6 + Module Modifier` Action Check.
* **Action Stakes:** Per action template.
* **Consequences:** Successful negotiation → improved Contact Relationship. Failed deal → damaged Faction Standing and Reputation.

### Phase 1 Trading Actions
| Action | Stakes | Outcome |
|--------|--------|---------|
| Negotiate Bulk Deal | Narrative | Better price + Contact Relationship vs. worse price + damaged relationship |
| Seek Rare Goods | Mundane | Discover unlisted commodity tip-off vs. time wasted |

## 4. Contracts (Deferred)

Contracts (delivery jobs, faction missions) are planned as an overlay system on top of the trade and agent infrastructure. Implementation deferred until the world and agent systems are operational. See `2.1-GDD` Phase 1 milestones.

## 5. Required Phase 1 Stats

* **Agent:** `skill_trading` — base for Module Modifier.
* **Ship:** `cargo_capacity` — max commodity units (Cash occupies cargo space).
* **Commodity:** `item_id`, `name`, `base_value`.
* **Systems:** Character (cash, standings, LP), Inventory (cargo), Asset (capacity), Time, CoreMechanicsAPI.

--- Start of ./6.1-GDD-Lore-Background.md ---

# GDTLancer - Lore & Background

**Version:** 2.0
**Date:** February 12, 2026
**Related Documents:** `6-GDD-Lore-Narrative-Borders.md`, `7-GDD-Assets-Style.md`

## 1. The Premise

A hand-crafted sector of space populated by human colonists and explorers. How or why humanity arrived is left undefined — narrative focus is on the current state and player actions.

## 2. Core Theme: Scarcity and Pragmatism

Considerable (but not punishing) scarcity of complex materials and skilled labor has forged a pragmatic, resilient culture.
* **Values:** Efficiency, function-over-form ("Pragmatic Aesthetics"), resourcefulness. "Waste not, want not."
* **Asset Value:** Ships and skilled pilots are quasi-irreplaceable — treated as significant investments.

## 3. The Preservation Convention

Cultural/economic norm prioritizing disablement, disarming, and capture over destruction.
* **Rationale:** Destroying a valuable ship and skilled pilot is wasteful and unprofitable.
* **Conflict Source:** Fringe groups breaking this convention are a significant societal threat.
* **Tactics:** Favors high-thrust application of industrial tools (grapples, prows, drills) for close-quarters disablement.

## 4. Technology & Aesthetics

* **Baseline:** Grounded, functional technology. Function-first aesthetic emphasizing reliability and modularity.
* **G-Stasis Cradle:** Standard bio-support system in high-performance ships. Allows survival under extreme G-forces (~15G) generated by aggressive maneuvering and industrial tool use in combat.
* **Travel:** No common FTL. In-system travel via engines; inter-sector travel is abstracted as high cost in Cash and time.

## 5. Naming & Language

* **Names:** Blend of diverse Earth cultures.
* **Language:** Practical, direct creole lingua franca with heavy technical jargon.

## 6. Implementation

Setting is experienced through mechanical consequences (combat module, entropy system), dialogue, and design — minimizing direct exposition. "Show, don't tell."

--- Start of ./6.2-GDD-Lore-Player-Onboarding.md ---

# GDTLancer - Player Onboarding

**Version:** 2.0
**Date:** February 12, 2026
**Related Documents:** `1-GDD-Core-Mechanics.md` (v3.0), `6.1-GDD-Lore-Background.md`

## 1. Goals

Introduce core systems in the first 30–60 minutes without overwhelming. Teach Action Checks and Stakes, demonstrate the gameplay loop (accept goal → travel → perform actions → reward), convey setting through action, and provide a clear next step.

## 2. Philosophy

* **Guided, Not Forced:** Clear starting goal in controlled area; allow experimentation.
* **Learn by Doing:** Introduce mechanics when needed.
* **Contextual:** Frame tutorial within a simple story revealing the setting.

## 3. Scenario: "The First Contract"

### Step 1: The Mentor & The Goal
Mentor NPC gives a simple contract: retrieve a data core from a disabled cargo drone at known coordinates. **Introduces:** Goal System, basic dialogue, salvage culture.

### Step 2: Travel & Time
Fly to drone coordinates. Short, direct flight. **Introduces:** Piloting controls, real-time passage triggering World Event Ticks.

### Step 3: The First Action Check
Data port is damaged; use ship tools to access the core. **Narrative-tier** action — resolves with Neutral thresholds and brief roll toast. Mentor explains outcome. **Introduces:** Action Check mechanic, tool usage.

### Step 4: Controlled Conflict
Rival scavenger returns demanding the core. Mentor advises disabling (not destroying) — annihilation is "wasteful" and "a good way to get a bad reputation." **Introduces:** Combat Module, hull targeting, Preservation Convention.

### Step 5: The Narrative Resolution
After neutralizing rival (Hull → 0), Narrative Action menu appears. Options: **Assess the Aftermath** (Narrative-tier) and **Claim Wreckage** (High-Stakes — introduces Risky/Cautious choice with dice animation). Mentor guides player through both tiers. **Introduces:** Skill-based play → TTRPG-style narrative resolution loop. Demonstrates the Convention (assess, activate distress beacon, leave for recovery).

### Step 6: The Reward
Return data core → first Cash payment. Mentor points to station job board. Tutorial complete. **Introduces:** Cash resource, player-driven goal discovery.

--- Start of ./6-GDD-Lore-Narrative-Borders.md ---

# GDTLancer - Narrative Borders of the Simulation

**Version:** 2.0
**Date:** February 12, 2026
**Related Documents:** `6.1-GDD-Lore-Background.md`, `8-GDD-Simulation-Architecture.md`

## 1. Purpose

Defines the thematic constraints — the "borders" — within which the simulation operates. The simulation serves the narrative: it is a thematically-focused story generator, not an open-ended universe simulation. These borders ensure emergent stories are grounded in established lore.

## 2. The Core Narrative Borders

### Border 1: Preservation of Assets
* **Lore:** Scarcity of complex materials and skilled personnel → the **Preservation Convention** prizes neutralization and capture over destruction.
* **Mechanical:** Destruction = least profitable, most consequence-heavy outcome (minimal salvage, Reputation loss, negative Faction Standing). Disablement/capture = most rewarding path — disabled ships become salvageable wrecks with their full inventory (**Axiom 1**, `8-GDD` Section 3.7). NPC agents default to disabling tactics; only defined outlier groups (fanatical outlaws) favor destruction.

### Border 2: Pragmatic Agent Behavior
* **Lore:** Pragmatic, utilitarian culture focused on managing risk, time, and resources.
* **Mechanical:** Agent Goal System (`8-GDD` Section 4.6) uses heuristics, not randomness. Trading agents maximize profit; pirate agents minimize risk. Entropy and resource sinks apply equally to NPCs.

### Border 3: Contained Scale
* **Lore:** No common FTL travel. Focus on dense, personal dynamics within a single sector.
* **Mechanical:** World structured as discrete, high-detail sectors (World layer, `8-GDD` Section 2). Events and Chronicle prioritize local, player-relevant content.

### Border 4: A Human-Centric Universe
* **Lore:** Narrative is about humanity — colonists and explorers adapting to their sector.
* **Mechanical:** Simulation focuses on Agent interactions: trade, politics, piracy, relationships, discovery. Alien life / anomalies are rare and narratively significant — preserves their thematic weight.

--- Start of ./7.1-GDD-Assets-Ship-Design.md ---

# GDTLancer - Ship Design & Component Catalogue

**Version:** 4.0
**Date:** February 13, 2026
**Related Documents:** `7-GDD-Assets-Style.md`, `6.1-GDD-Lore-Background.md`, `8-GDD-Simulation-Architecture.md`

## 1. Overview

Defines the foundational technology and design philosophy for all ship assets. Serves as the complete component catalogue informing player-facing assets. Rooted in the lore of a colonial civilization defined by resource scarcity and pragmatic engineering.

**Simulation Layer Mapping:** Ship hulls define base stats. Equipped slot items provide **modifiers to Action Checks** or act as **gameplay loop enablers** (e.g., a mining drill enables mining, a grapple enables capture). Equipment avoids linear stat grinding — items are lateral choices with trade-offs, not strict upgrades. Component stats feed the Heat Sink bridge (`8-GDD` Section 6.1).

## 2. Core Principles

* **Function over Form:** Design prioritizes clear purpose over aesthetics ("Pragmatic Aesthetics").
* **Hull + Slots:** Ships are pre-designed spaceframes with a fixed number of equipment slots (Freelancer model). The hull determines base stats (integrity, cargo, handling). Slots accept swappable equipment that modifies capabilities.
* **Lateral Progression:** Equipment provides trade-offs and specialization, not linear power increases. A combat-optimized loadout sacrifices cargo capacity; a hauler sacrifices combat effectiveness. No "best-in-slot" endgame gear.
* **Lived-In Aesthetic:** Signs of maintenance and use (wear, patches, modifications).

## 3. Ship Dimensions

* **Size:** 20–40 meters length.
* **Mass:** Dry mass ~20t (light) to 100t+ (heavy freighter).
* **Core Design:** Built around compact single-pilot life support pod with integrated **G-Stasis Cradle**.

## 4. Construction Materials

| Material | Niche |
|----------|-------|
| Welded Steel & Composites | Heavy, cheap, easy to repair. Industrial standard. |
| Titanium-Alloy Frame | Lighter/stronger. Improves agility and durability. Higher cost. |
| Graphene-Reinforced Ceramics | Extremely light, durable, high heat resistance. Rare, hard to repair. |

## 5. Propulsion Systems

### 5.1. Main Engines

| Technology | Mechanism | Niche |
|------------|-----------|-------|
| "Rock-Eater" (Chemical Hybrid) | Solid fuel grain + LOX | Baseline. Reliable. Phase 1 default. |
| Nuclear Thermal (NTR) | Fission reactor superheats liquid propellant | Top-tier efficiency. Extremely expensive. Future phase. |

### 5.2. Emergency Propulsion

| Technology | Mechanism | Niche |
|------------|-----------|-------|
| Microwave / Resistojet | Electricity heats waste mass into plasma | Very low thrust, high-efficiency "get-home" engine. Future phase. |

### 5.3. Phase 1 Engine Configurations

All Phase 1 engines are "Rock-Eater" hybrid variants.

**Lore & Visuals:**

| Config | Visual Description | Exhaust |
|--------|--------------------|---------|
| Cruiser | Rugged single-cylinder, armored casing, conical nozzle (~9.5m) | Tight, stable, pale-blue flame |
| Balanced | Modified Cruiser with heat shielding + passive radiator fins, bell nozzle (~10m) | Brighter, visible shock diamonds |
| Brawler | Armored radiator panels, thick LOX feeds, wide short nozzle (~9m) | Violent, turbulent orange-white plume |
| Interceptor | Rectangular armored block (missile pod), visible cartridge seams (~4m×4m×3m) | Massive short-lived smoke/fire cloud |

**Godot Implementation (`ShipTemplate` `.tres`):**

| Config | `max_move_speed` | `acceleration` | `deceleration` | `max_turn_speed` |
|--------|-----------------|----------------|----------------|-----------------|
| Cruiser | 500.0 | 0.3 | 0.3 | 0.6 |
| Balanced | 500.0 | 0.5 | 0.5 | 0.75 |
| Brawler | 500.0 | 0.8 | 0.8 | 1.1 |

* `acceleration` = `lerp` factor (implements Thruster Power stat).
* `max_turn_speed` = `slerp` factor (implements Agility stat).
* **Interceptor:** Not a ShipTemplate config — implemented as a consumable action temporarily overriding `acceleration` (e.g., 5.0+) for a short burst.

### 5.4. Propellant (Rock-Eater Lore)

Baseline propellant load ~120t: ~40t solid fuel grain (in engine casing) + ~80t LOX (in two external 35m³ cryotanks).

## 6. Ship Chassis (Phase 1 Hulls)

| Chassis | Hull Integrity | Cargo Slots | Equipment Slots | Mass Class | Profile |
|---------|---------------|-------------|-----------------|------------|---------|
| Scout | Low | Low | 2 | Light | Fast, fragile, minimal cargo |
| Freighter | Medium | High | 2 | Heavy | Slow, durable, maximum cargo |
| Corvette | High | Medium | 3 | Medium | Balanced combat/utility |

## 7. Power Plants

| Technology | Niche |
|------------|-------|
| Solar Panels | Baseline. Low output, ineffective far from star. |
| RTG | Low constant output, extreme duration. Emergency backup / "dark running." |
| Fuel Cells | Mid-grade. Consumes propellant for electricity. |
| Fission Reactor | High-end. Rare uranium/thorium fuel. Essential for deep space + NTR engines. |

## 8. Cooling Systems

| Technology | Niche |
|------------|-------|
| Standard Radiators | Basic, durable heat dissipation. Bulky, exposed. |
| Cryo-Coolers | High-efficiency active cooling. Compact, requires power, fragile. |

## 9. Life Support

| Technology | Niche |
|------------|-------|
| Open-Loop | Consumes stored consumables. Limits mission duration. Short-range standard. |
| Closed-Loop Recycler | Recycles air/water. Extends endurance significantly. |
| G-Stasis Cradle | Mitigates extreme G-forces. Components: Exo-Harness, Contour Bladders, Pressurized Breathing, Neuro-Bio Support. |

## 10. Radiation Protection

| Technology | Niche |
|------------|-------|
| Baseline Hull Shielding | Minimal. Sufficient for short in-system travel. |
| Dense Core Laminate | Heavy layered armor. Significant protection for deep space at mass cost. |

## 11. Turbomachinery

| Technology | Niche |
|------------|-------|
| Standard Mechanical Pumps | Baseline. Heavy, durable, power-inefficient. |
| Single-Crystal Blisk Turbopumps | Advanced. Exotic alloy. High efficiency, low mass. Complex, costly. |

## 12. Utility Tools (Hardpoints)

Tools serve dual purposes (industry + combat) per the Preservation Convention.

### Mining & Salvage
| Tool | Function |
|------|----------|
| Rotary Mining Drill | Ore extraction. Combat: controlled hull breaching. |
| Reinforced Prow | Pushing large salvage. Combat: breaching, pinning, bulldozing. |
| High-Power Ablative Laser | Surface element skimming. Combat: armor stripping, external system damage. |
| Seismic Charge Launcher | Controlled asteroid demolition (consumable). Combat: subsystem targeting. |

### Capture & Collection
| Tool | Function |
|------|----------|
| Harpoon & Winch Array | Tethers asteroids or ships. Recoverable projectile. |
| Forward-Facing Debris Scoop | Collects wreckage fragments or fractured asteroid material. |

## 13. Energy Storage

| Technology | Niche |
|------------|-------|
| High-Capacity Battery Banks | High storage, low discharge rate. Stores energy reserves from power plants. |
| Supercapacitors | Low storage, instant discharge. For high-draw systems (lasers, engine startup). |

## 14. Propellant Storage

| Technology | Niche |
|------------|-------|
| Insulated Dewar Tank | Baseline liquid storage (LOX). Passive insulation; inevitable boil-off limits duration. |
| Active Cryocooler Tank | High-end cryogenic. Active cooling eliminates boil-off. Essential for long-haul cryogenic ships. |

--- Start of ./7-GDD-Assets-Style.md ---

# GDTLancer - General Asset & Style Guide

**Version:** 1.3
**Date:** February 12, 2026
**Related Documents:** `0.1-GDD-Main.md` (v3.0), `6.1-GDD-Lore-Background.md`, `7.1-GDD-Assets-Ship-Design.md`

## 1. Overview & Core Philosophy

This document defines the overarching artistic, audio, and user interface style for all assets in GDTLancer. The goal is to create a cohesive and distinct identity that reinforces the game's core themes of pragmatism, function-first design, and a unique "Neo-Retro" aesthetic.

* **Neo-Retro 3D:** The primary visual style is inspired by the limitations and aesthetics of early 3D graphics (mid-to-late 1990s), but executed with modern rendering techniques like dynamic lighting and shaders. This is not a pixel-perfect retro emulation, but an interpretation of that style.
* **Pragmatic Aesthetics:** Form always follows function. Every element in the game world, from a ship's hull to a UI button, should look like it was designed for a purpose, not for decoration. This reflects the utilitarian culture of the sector.

## 2. Visual Style

### 2.1. 3D Models & Texturing
* **Geometry:** Models must be medium-low-poly with clean, hard edges. Beveling should be used sparingly to catch light, but complex, smooth curves and subdivision surfaces are to be avoided. The silhouette should be clear and readable.
* **Texturing:** Photorealistic textures are forbidden. Surfaces should primarily use flat colors, simple gradients, or subtle, procedurally generated noise patterns. Textures should define material type (e.g., matte metal, rubberized composite) rather than intricate surface detail.
* **Wear and Tear:** Details like scratches, weld lines, and patch repairs should be added as simple decals or vertex color variations, not complex, high-resolution texture maps. The goal is to suggest a history of use, not to simulate realistic decay.

### 2.2. Environments
* **Space:** The void of space should be dark and minimalist. The sense of scale and movement is conveyed through simple, billboard-style star sprites and multi-layered dust particle effects.
* **Nebulae & Phenomena:** Large environmental features like nebulae should be stylized, using simple geometry with volumetric shaders or layered, transparent sprites rather than photorealistic clouds.
* **Structures:** Stations and habitats follow the same pragmatic design as ships: functional, modular, and often asymmetrical. Lighting is utilitarian, used for navigation, docking bays, and warning signals.

### 2.3. UI / UX
* **Philosophy:** The UI is a functional tool, not a decorative overlay. It must be clean, non-intrusive, and highly readable.
* **Layout:** Use a grid-based layout with clear information hierarchy. Group related elements logically.
* **Visuals:** Elements should be composed of simple, 2D vector-style lines and shapes. Buttons are functional rectangles or squares. Icons are simple and symbolic.
* **Typography:** Use a clean, sans-serif font (like Roboto Condensed) for all text to ensure maximum readability.
* **Color Palette:** The UI uses a mostly monochromatic palette (dark backgrounds, light grey or off-white text). Bright, saturated colors (cyan, yellow, red) are used exclusively for highlights, alerts, and critical information to draw the player's attention.

## 3. Audio Style

### 3.1. Sound Effects (SFX)
* **Philosophy:** Sounds are functional feedback. They should be clear, distinct, and immediately communicate what is happening.
* **Style:** SFX should have a slightly synthesized, "lo-fi" quality to match the neo-retro aesthetic. Avoid cinematic, high-fidelity explosions and impacts. Think more of the satisfying "thunks," "beeps," and "hums" of classic sci-fi. Thruster sounds should be a low, functional rumble, not a dramatic roar.

### 3.2. Music
* **Philosophy:** Music provides atmosphere, not overt emotional direction. It should support the feeling of isolation and pragmatic work in space.
* **Style:** The soundtrack should be minimalist and ambient. Expect long, evolving synthesizer pads, simple arpeggios, and a generally low-key, atmospheric tone. Music should swell subtly during moments of tension (like combat) but should not become an epic, orchestral score.

--- Start of ./8-GDD-Simulation-Architecture.md ---

# GDTLancer - Simulation Architecture

**Version:** 2.0
**Date:** February 13, 2026
**Related Documents:** `0.1-GDD-Main.md` (v4.0), `1-GDD-Core-Mechanics.md` (v5.0), `1.1-GDD-Core-Systems.md` (v5.0), `1.2-GDD-Core-Cellular-Automata.md` (v2.0), `3-GDD-Architecture-Coding.md` (v3.0), `7.1-GDD-Assets-Ship-Design.md` (v4.0)

---

## 1. Overview

This document defines GDTLancer's simulation as a **layered, data-driven architecture**. The purpose is to cleanly isolate the **Physical world** from the **Systemic logic** and **Cognitive agents**, enabling each layer to be tuned, tested, and extended independently.

The simulation operates on four distinct layers, processed sequentially each tick:

1. **The World** — Static, handcrafted physical foundation. Changes only between content updates.
2. **The Grid** — Dynamic systemic state driven by Cellular Automata and tick-based rules. Reacts to Agent activity and World constraints.
3. **The Agents** — Cognitive entities (player and NPCs) that read the Grid, maintain internal knowledge, and act upon the world.
4. **The Chronicle** — An output layer that captures events, chains causality, and translates raw simulation data into player-facing narrative.

This separation allows difficulty tuning (e.g., harsher environmental hazards, faster resource depletion) by adjusting World or Grid parameters **without touching Agent AI logic**.

### 1.1. Relationship to Existing Architecture

This document does **not** replace the existing stateless systems architecture defined in `3-GDD-Architecture-Coding.md`. Rather, it provides a **conceptual simulation model** that the existing `GameState`, `EventBus`, and stateless systems implement. Each data parameter defined below maps to a concrete field in `GameState` or a stateless system API.

### 1.2. Relationship to Cellular Automata

The Grid layer is the primary consumer of the CA implementations defined in `1.2-GDD-Core-Cellular-Automata.md`. The CA systems (Strategic Map, Supply & Demand Flow, Influence Network, etc.) are the **engines** that drive Grid state transitions each World Event Tick.

### 1.3. Governing Invariants (Conservation Axioms)

The simulation is governed by conservation laws that ensure internal consistency and prevent unbounded growth or creation-from-nothing. Every system design must satisfy these axioms. They are not gameplay features — they are **constraints on what systems are allowed to do**. Any proposed mechanic that violates an axiom must be redesigned until it complies.

**Axiom 1 — Conservation of Matter.** The total extractable matter in the universe is finite, fixed at world initialization, and distributed across the Resource Potential Map (Section 2.3). Matter can be extracted, refined, transferred, degraded, or lost — but never created. Station restocking draws from local extraction or supply chain imports, not from an external reservoir. When organized matter reaches a fully degraded state (debris, wreckage, trace elements), it returns to the Resource Potential Map as diffuse, low-grade resource potential. The matter cycle is closed: extraction → refinement → use → degradation → diffuse potential → (re-)extraction.

**Axiom 2 — Conservation of Population.** The universe is seeded with a fixed initial population of human agents. Population changes (death, arrival, departure) are driven by integral economic and resource conditions across the world — not by spawn probability. Non-human hostiles (feral drones, alien fauna) are tracked as **global population integrals** bounded by a carrying capacity derived from sector conditions — not as individual CA tokens. No entity appears from vacuum; every agent present is accounted for by the population budget.

**Axiom 3 — Material Basis of Value.** Economic value is denominated in physical commodities — standardized refined metals and rare materials ("Cash"). There is no fiat currency; the total monetary mass equals the total physical resource mass allocated as medium of exchange. In-faction transactions use **Loyalty Points (LP)** — a finite, contribution-tracked internal credit system per faction. Repairs, services, and construction consume physical materials and energy, not abstract numbers.

**Axiom 4 — Thermodynamic Arrow.** In the absence of energy input, all organized structures degrade toward disorder. Entropy is monotonically non-decreasing in closed subsystems. Reversing entropy (repair, construction, refinement) requires both physical material **and** energy input. Primary energy sources (stellar radiation, nuclear fuel reserves) are treated as inexhaustible within the game's timescale — they are the external heat bath that prevents total heat death and provides the energy gradient driving all economic activity.

**Axiom 5 — Causality and Information Locality.** Effects have traceable causes (Chronicle, Section 5). Information propagates at finite speed (tick-based, proximity-based). Knowledge degrades without active maintenance — survey, exploration, and communication have real costs in time, energy, and resources. No agent has access to information it has not observed, been told, or inferred.

---

## 2. Layer 1: The World (Physical Foundation)

The World layer contains **static, handcrafted data** that defines the physical constraints of the game universe. This data is read-only at runtime and changes only via content updates or new game initialization. It is the "terrain" upon which the simulation operates.

### 2.1. Topology Map

The spatial layout of the game universe.

| Parameter | Type | Description | Source |
|-----------|------|-------------|--------|
| `sector_id` | `String` | Unique identifier for each sector/location. | Handcrafted |
| `connections` | `Array<String>` | List of `sector_id`s reachable from this sector (jump-gates, transit routes). | Handcrafted |
| `station_ids` | `Array<String>` | List of station/habitat identifiers present in this sector. | Handcrafted |
| `sector_type` | `String` | Classification: `"hub"`, `"frontier"`, `"deep_space"`, `"hazard_zone"`. | Handcrafted |

### 2.2. Environmental Hazard Map

Persistent physical conditions that impose operational costs on any entity present. These create **permanent friction** that shapes route planning, ship loadout choices, and economic geography.

| Parameter | Type | Description | Source |
|-----------|------|-------------|--------|
| `radiation_level` | `float` | Ambient cosmic/solar radiation intensity (0.0 = safe, 1.0 = lethal). Interacts with hull `radiation_shielding_factor` (`7.1-GDD-Assets-Ship-Design.md`, Radiation Protection). | Handcrafted |
| `thermal_background_k` | `float` | Ambient temperature in Kelvin. Determines the **Heat Dissipation Ceiling** — the maximum rate at which any entity can radiate waste heat. Near-star sectors have high values (poor dissipation); deep-space sectors have low values (excellent dissipation). Interacts with cooling systems (`7.1-GDD-Assets-Ship-Design.md`, Cooling Systems). | Handcrafted |
| `gravity_well_penalty` | `float` | A thrust/propellant multiplier for departure and station-keeping near planetary bodies or stations (1.0 = no penalty, 2.0 = double propellant cost). Affects agent `propellant_reserves`. | Handcrafted |

### 2.3. Resource Potential Map (Finite Matter Budget)

The universe's total matter budget. This map defines **where** extractable resources exist and at what density. Unlike other World data, Resource Potential values are **mutable at runtime** — extraction depletes them, and degradation of organized matter (wrecks, debris, abandoned stockpiles) slowly returns diffuse material to the local potential. This is the only World-layer data that changes at runtime, enforcing **Axiom 1** (Conservation of Matter).

The sum of all `mineral_density` and `propellant_sources` values across all sectors, plus all matter currently in refined/manufactured form (ships, equipment, cargo, Cash, station stockpiles), equals a **constant total** initialized at world creation.

| Parameter | Type | Description | Source |
|-----------|------|-------------|--------|
| `mineral_density` | `float` | Extractable mineral potential (0.0–1.0). Depleted by mining; replenished slowly by matter degradation (wrecks → debris → diffuse minerals). | Handcrafted seed; mutated by extraction and degradation |
| `energy_potential` | `float` | Solar/thermal energy availability (0.0–1.0). Effectively inexhaustible within game timescale (**Axiom 4**). Affects solar panel output and local energy costs. | Derived from `thermal_background_k` and star proximity |
| `propellant_sources` | `float` | Refinable propellant feedstock (ice, hydrogen, etc.) (0.0–1.0). Depleted by extraction; replenished slowly by outgassing and matter degradation. | Handcrafted seed; mutated by extraction and degradation |

---

## 3. Layer 2: The Grid (Systemic CA Layers)

The Grid is the **dynamic simulation state**. It is updated each **World Event Tick** by CA rules and Agent activity. Grid data is the primary input for Agent decision-making and the Chronicle's narrative generation. All Grid data lives in `GameState` and is manipulated by stateless systems.

### 3.1. Resource Availability

Real-time levels of consumable resources at each location. Depleted by Agent activity; replenished **only** by extraction from the Resource Potential Map (Section 2.3) or import via CA-driven supply chains (**Axiom 1**). Extraction reduces the corresponding World-layer potential value.

| Parameter | Type | Description | Updated By |
|-----------|------|-------------|------------|
| `propellant_supply` | `float` | Current propellant stock available for purchase at this location (0.0 = depleted, 1.0 = fully stocked). | Extraction from `propellant_sources`, Agent trade actions |
| `consumables_supply` | `float` | Current life-support consumables available (food, air, water). Depleted by docked agents, replenished by extraction and supply runs. | Extraction, Agent consumption |
| `energy_supply` | `float` | Current available energy at this station/location grid. Energy is derived from inexhaustible sources (**Axiom 4**) but limited by local infrastructure capacity. | Power Load rules, Agent activity |

### 3.2. Power Load Layer

A real-time balance of energy generation versus systemic draw at persistent locations (stations, habitats).

| Parameter | Type | Description | Updated By |
|-----------|------|-------------|------------|
| `station_power_output` | `float` | Total energy generation capacity of the station/habitat. | Static per station (World data) |
| `station_power_draw` | `float` | Current aggregate power demand from docked agents, active systems, and services. | Agent docking/undocking, service usage |
| `power_load_ratio` | `float` | Derived: `station_power_draw / station_power_output`. When > 1.0, triggers **brownout effects**: increased service costs, slower repairs, reduced market availability. | Derived each tick |

### 3.3. Dominion & Stability

CA-driven maps of Faction influence and security levels. These determine encounter frequency (drawn from global hostile population integrals, **Axiom 2**), contract availability, and NPC behavior.

| Parameter | Type | Description | Updated By |
|-----------|------|-------------|------------|
| `faction_influence` | `Dictionary<String, float>` | Map of `faction_id` → influence score (0.0–1.0) for this sector. Highest score = dominant faction. | Strategic Map CA, Agent faction actions |
| `security_level` | `float` | Aggregate safety rating (0.0 = lawless, 1.0 = heavily patrolled). Determines hostile encounter frequency (drawn from global non-human hostile population integral) and patrol presence. | Derived from dominant faction influence + pirate activity |
| `pirate_activity` | `float` | Current level of pirate/hostile presence (0.0–1.0). Increases when security drops; decreases when agents complete bounty/patrol goals. | Strategic Map CA, Agent combat actions |

### 3.4. Market Pressure

Derived economic data calculating local price adjustments based on physical supply/demand imbalances.

| Parameter | Type | Description | Updated By |
|-----------|------|-------------|------------|
| `commodity_price_deltas` | `Dictionary<String, float>` | Map of `commodity_id` → price multiplier relative to `base_value`. Derived from local `Resource Availability` vs. local population/demand. E.g., `{"scrap_metal": 0.8, "refined_ore": 1.4}`. | Supply & Demand CA each tick |
| `population_density` | `float` | Relative population at this location (0.0–1.0). Drives demand side of Market Pressure. | Derived from docked Persistent Agents + station base population |
| `service_cost_modifier` | `float` | Multiplier applied to repair, refueling, and maintenance costs at this location. Affected by `power_load_ratio`, `consumables_supply`, and `security_level`. | Derived each tick |

### 3.5. Maintenance Pressure (Entropy Layer)

A decay layer representing systemic wear-and-tear on persistent assets (**Axiom 4**). Creates ongoing resource demand via environmental hull degradation. Reversing this degradation (repair) requires physical materials drawn from station stockpiles plus energy — not abstract currency.

| Parameter | Type | Description | Updated By |
|-----------|------|-------------|------------|
| `local_entropy_rate` | `float` | A location-specific modifier to how fast assets degrade. Harsh environments (high radiation, thermal extremes) increase this. Stations with good maintenance facilities reduce it. | Derived from World hazards + station services |
| `maintenance_cost_modifier` | `float` | Multiplier applied to the base degradation rate of assets at this location. Higher entropy = faster wear. | Derived from `local_entropy_rate` |
| `repair_material_cost` | `float` | Physical material units consumed per unit of hull integrity restored. Drawn from local `commodity_stockpiles`. | Derived from ship class + damage severity |

### 3.6. Inventory Flow

Tracks the physical location of commodity stockpiles. Market Pressure (3.4) reacts to the **delta** between actual physical stock and local demand, not abstract values. All matter in this layer is conserved (**Axiom 1**).

| Parameter | Type | Description | Updated By |
|-----------|------|-------------|------------|
| `commodity_stockpiles` | `Dictionary<String, int>` | Map of `commodity_id` → physical unit count at this location. This is the **actual inventory** that agents buy from and sell to. | Agent trade actions, local extraction from Resource Potential Map |
| `stockpile_capacity` | `int` | Maximum total commodity units this location can store. | Static per station (World data) |
| `extraction_rate` | `Dictionary<String, float>` | Map of `commodity_id` → units extracted per World Event Tick from the local Resource Potential Map. Extraction **depletes** the corresponding World-layer value. When potential reaches 0.0, extraction halts. | Derived from `mineral_density`/`propellant_sources` × station infrastructure |

### 3.7. Wreck & Debris Lifecycle

When a ship is disabled (hull → 0), it persists in the sector as a **salvageable wreck** containing its cargo and equipment. Wrecks are subject to entropy degradation (**Axiom 4**). This enforces the matter cycle: organized matter → wreck → debris → diffuse resource potential.

| Parameter | Type | Description | Updated By |
|-----------|------|-------------|------------|
| `wreck_integrity` | `float` | Structural condition of the wreck (1.0 = freshly disabled, 0.0 = fully degraded). | Entropy System (6.2) each tick |
| `wreck_inventory` | `Dictionary` | Cargo and equipment aboard at time of disablement. Salvageable while `wreck_integrity` > 0. | Frozen at disablement; depleted by salvage actions |
| `debris_return_rate` | `float` | When `wreck_integrity` reaches 0.0, remaining material mass is added back to the local `mineral_density` in the Resource Potential Map as diffuse low-grade potential. | Entropy System |

---

## 4. Layer 3: The Agents (Cognitive & Social Data)

Agents are cognitive entities — both the player and all NPCs — that perceive the Grid, maintain internal state, and take actions. Agent data is the domain of the `Character System`, `Agent System`, and `Asset System` as defined in `1.1-GDD-Core-Systems.md`.

The universe is seeded with a **fixed initial population** of human agents (**Axiom 2**). Population changes are driven by integral economic conditions (resource depletion → emigration; prosperity → immigration), not spawn dice. Non-human hostiles (feral drones, alien fauna) are tracked as global population integrals bounded by carrying capacity, not individual CA tokens.

### 4.1. Spatial & Physical State

The agent's current physical situation in the world.

| Parameter | Type | Description | System Owner |
|-----------|------|-------------|--------------|
| `current_sector_id` | `String` | The sector/location where the agent currently resides. | Agent System |
| `hull_integrity` | `float` | Current structural health of the agent's active ship (0.0 = disabled). | Asset System |
| `propellant_reserves` | `float` | Current propellant in the agent's ship tanks. Consumed by movement; affected by `gravity_well_penalty`. | Asset System (via `7.1-GDD-Assets-Ship-Design.md`, Propellant Storage) |
| `energy_reserves` | `float` | Current stored energy (battery/supercapacitor charge). Consumed by active systems. | Asset System (via `7.1-GDD-Assets-Ship-Design.md`, Energy Storage) |
| `consumables_reserves` | `float` | Current life-support consumables aboard. Depleted over time; replenished at stations. | Asset System (via `7.1-GDD-Assets-Ship-Design.md`, Life Support) |
| `cash_reserves` | `float` | Physical commodity money (refined metals) carried or stored. The agent's liquid wealth (**Axiom 3**). | Character System |
| `fleet_ships` | `Array<String>` | Ship IDs owned by this agent beyond their active ship. Docked ships incur entropy and docking costs. Agents can sell, gift, or assign ships to other agents. | Asset System |
| `current_heat_level` | `float` | Current thermal load on the ship. Accumulates from high-energy actions; dissipates based on cooling systems and `thermal_background_k`. | Asset System (via `7.1-GDD-Assets-Ship-Design.md`, Cooling Systems) |

### 4.2. Operational Capacity (Attributes)

Skill modifiers that determine success probability and complication risk for Narrative Actions. Only skills with active Phase 1 use are included — no placeholder stubs.

| Parameter | Type | Description | System Owner |
|-----------|------|-------------|--------------|
| `skill_piloting` | `int` | Modifies piloting-related Action Checks. | Character System |
| `skill_combat` | `int` | Modifies combat-related Action Checks. | Character System |
| `skill_trading` | `int` | Modifies trading and social Action Checks. | Character System |

### 4.3. Maintenance State (Deferred)

Ship Quirks, component wear tracking, and derived performance modifiers are **deferred** to a later development phase. The entropy system (`8-GDD` Section 3.5) provides the data foundation; the Maintenance State will consume it when implemented.

**Future parameters:** `ship_quirks`, `component_wear`, `propellant_efficiency_modifier`, `power_output_modifier`.

### 4.4. Knowledge Snapshot (Internal Map)

Each agent maintains a **personal, potentially outdated** copy of Grid data. This is the agent's "belief state" — what they *think* the world looks like. This is critical for NPC decision-making and for the player's information asymmetry.

| Parameter | Type | Description | System Owner |
|-----------|------|-------------|--------------|
| `known_grid_state` | `Dictionary` | A snapshot of Grid data (commodity prices, security levels, faction influence) as the agent last observed it. Keyed by `sector_id`. | Agent System |
| `knowledge_timestamps` | `Dictionary<String, int>` | Map of `sector_id` → the `tick_count` when this agent's knowledge of that sector was last updated. Used for Knowledge Decay. | Agent System |
| `knowledge_decay_rate` | `float` | A per-agent parameter controlling how fast their internal map becomes unreliable. Higher values = faster decay, forcing more active information gathering. | Character System (derived from skills/traits) |

**Knowledge Update Rules:**
- **Proximity:** An agent's `known_grid_state` for their `current_sector_id` is automatically refreshed to match actual Grid data each tick.
- **Comm-Link:** Agents can exchange knowledge snapshots during social interactions, updating each other's internal maps (but with potential Trust & Deception filtering — see `1.2-GDD-Core-Cellular-Automata.md`, CA #5).
- **Rumor Engine:** Agents can acquire partial, potentially inaccurate knowledge via the Chronicle's Rumor Engine (Section 5.3).

### 4.5. Social Graph

Relationship data that drives NPC behavior and player narrative.

| Parameter | Type | Description | System Owner |
|-----------|------|-------------|--------------|
| `faction_standings` | `Dictionary<String, float>` | Map of `faction_id` → standing score (-1.0 hostile to 1.0 allied). | Character System |
| `character_standings` | `Dictionary<int, float>` | Map of agent `uid` → personal affinity score (-1.0 to 1.0). Tracks grudges and favors at the individual level. | Character System |
| `sentiment_tags` | `Dictionary<int, Array<String>>` | Map of agent `uid` → list of sentiment qualifiers (e.g., `["owes_favor", "witnessed_betrayal", "trade_partner"]`). Provides richer context than a single float. | Agent System |

### 4.6. Goal Priority Queue

A ranked list of the agent's current objectives that dictates how they respond to Grid data and events.

| Parameter | Type | Description | System Owner |
|-----------|------|-------------|--------------|
| `goal_queue` | `Array<Dictionary>` | Ordered list of goal objects. Each goal has: `goal_id` (String), `priority` (int), `progress` (float 0.0–1.0), `target_data` (Dictionary). Higher priority goals are pursued first. | Agent System / Character System |
| `goal_archetype` | `String` | The agent's dominant behavioral archetype derived from personality traits: `"survival_first"`, `"profit_seeker"`, `"faction_loyalist"`, `"thrill_seeker"`. Determines how goals are prioritized when conflicts arise. | Derived from `personality_traits` |

**Priority Hierarchy (Default):**
1. **Survival** — Maintain hull integrity, propellant, consumables above critical thresholds.
2. **Personal Goal** — Pursue the agent's current primary objective (from `goal_queue`).
3. **Faction Duty** — Respond to faction-level directives.
4. **Opportunism** — React to local Grid conditions for profit or advantage.

### 4.7. Narrative Inventory

A queue of witnessed or received events that the agent can trade, relay, or act upon.

| Parameter | Type | Description | System Owner |
|-----------|------|-------------|--------------|
| `event_memory` | `Array<Dictionary>` | List of Event Packets (see Section 5.1) this agent has witnessed or received. Each entry includes the packet data plus a `trust_level` and `received_tick`. | Agent System |
| `max_memory_slots` | `int` | Maximum number of event packets the agent retains. Oldest/lowest-trust entries are discarded when full. | Character System (derived from skills) |

---

## 5. Layer 4: The Chronicle (Output Layer)

The Chronicle captures, stores, and translates simulation events into player-facing narrative. It is the bridge between the raw simulation and the player's experience.

### 5.1. Event Buffer

Raw event data generated during each simulation tick.

| Parameter | Type | Description | Generated By |
|-----------|------|-------------|--------------|
| `actor_uid` | `int` | The agent who performed the action. | All systems |
| `action_id` | `String` | The type of action performed (e.g., `"trade_sell"`, `"combat_disable"`, `"dock"`, `"undock"`). | All systems |
| `target_uid` | `int` or `null` | The agent or entity the action was performed upon (if applicable). | All systems |
| `target_sector_id` | `String` | The sector where the action occurred. | All systems |
| `tick_count` | `int` | The World Event Tick when this event occurred. | Time System |
| `outcome` | `String` | Result classification: `"critical_success"`, `"success"`, `"failure"`, `"critical_failure"`. | CoreMechanicsAPI |
| `metadata` | `Dictionary` | Action-specific data (e.g., `{"commodity": "scrap_metal", "quantity": 50, "price": 120}`). | Originating system |

### 5.2. Causality Chain

Metadata within Event Packets that links effects to their causes, enabling the Rumor Engine to produce **actionable intelligence** rather than disconnected flavor text.

| Parameter | Type | Description | Generated By |
|-----------|------|-------------|--------------|
| `cause_event_id` | `String` or `null` | Reference to a prior Event Packet that directly caused this event. E.g., a `"price_spike"` event references the `"freighter_destroyed"` event that triggered it. | Originating system |
| `causal_chain_depth` | `int` | How many links back this event's causal chain extends. Used to prioritize high-impact, deeply-rooted events for narrative generation. | Derived |
| `significance_score` | `float` | A heuristic score (0.0–1.0) indicating how "newsworthy" this event is. Derived from causal chain depth, involved agent importance (Persistent vs. Temporary), and economic impact. | Derived |

### 5.3. Rumor Engine

A translation layer that converts Event Buffer packets into player-facing text based on the player's current knowledge state.

| Parameter | Type | Description | Consumer |
|-----------|------|-------------|----------|
| `rumor_text` | `String` | The generated player-facing text describing the event in narrative terms. | UI: Bulletin Boards, NPC Dialogue |
| `trust_tag` | `String` | Reliability classification: `"verified_intel"`, `"market_rumor"`, `"unconfirmed_hearsay"`. Derived from source agent's `character_standings`, number of relay hops, and Trust & Deception CA (`1.2-GDD-Core-Cellular-Automata.md`, CA #5). | UI: Rumor Mill |
| `relevance_filter` | `Dictionary` | Conditions under which this rumor should be shown to the player: `{"sector_ids": [...], "faction_ids": [...], "min_significance": 0.3}`. | UI filtering logic |

### 5.4. Knowledge Decay

A parameter that reduces the accuracy of an agent's Knowledge Snapshot (Section 4.4) over time, forcing active participation in the Rumor Engine.

| Parameter | Type | Description | Updated By |
|-----------|------|-------------|------------|
| `decay_function` | `String` | The mathematical model for decay: `"linear"` or `"exponential"`. | Configurable per difficulty |
| `decay_threshold_ticks` | `int` | Number of ticks after which knowledge begins to decay. Below this, knowledge is considered "fresh". | Configurable |
| `stale_data_penalty` | `float` | The maximum inaccuracy introduced to an agent's `known_grid_state` when knowledge is fully decayed. E.g., a commodity price known at 100 Cash with a 0.3 penalty could be reported as anywhere from 70–130. | Derived from `knowledge_decay_rate` × elapsed ticks |

---

## 6. Bridge Systems

These are cross-cutting simulation mechanics that span multiple layers, connecting World constraints to Agent behavior through Grid state.

### 6.1. Heat Sink System

Connects World environmental data to Agent physical state via a continuous heat accumulation/dissipation model.

**Inputs:**
- **World:** `thermal_background_k` (determines maximum dissipation rate ceiling).
- **Agent:** Cooling system stats (`heat_dissipation_mw` from `7.1-GDD-Assets-Ship-Design.md`, Cooling Systems).
- **Agent:** Activity level (engines, combat tools, industrial tools all generate heat).

**Process (each tick):**
1. Calculate `heat_generated` from all active agent systems (engines, tools, power plant waste heat).
2. Calculate `max_dissipation` = `min(cooling_system_capacity, environment_dissipation_ceiling)`.
   - `environment_dissipation_ceiling` is derived from `thermal_background_k`: lower ambient temperature → higher ceiling.
3. Calculate `net_heat_change` = `heat_generated - max_dissipation`.
4. Update Agent's `current_heat_level += net_heat_change`.

**Consequences:**
- `current_heat_level` > **Warning Threshold:** Performance penalties (reduced engine efficiency, weapon cooldown increase).
- `current_heat_level` > **Critical Threshold:** System shutdowns, forced cooldown period.
- `current_heat_level` > **Emergency Threshold:** Hull damage risk.

### 6.2. Entropy System

The Maintenance Pressure layer (Grid 3.5) applies passive environmental wear to persistent assets (**Axiom 4**). The world degrades ships through environmental conditions. Reversing this degradation requires physical materials + energy at a maintenance facility (**Axiom 3**).

**Process (each World Event Tick):**
1. For each Agent's active ship, apply `local_entropy_rate` from Grid as a slow degradation factor to `hull_integrity`.
2. For each Agent's docked fleet ships (`fleet_ships`), apply a reduced but non-zero entropy rate. Fleet growth is self-limiting — more ships = more aggregate degradation cost.
3. Harsh environments (high radiation, thermal extremes) increase degradation rate.
4. Stations with maintenance facilities reduce or halt degradation for docked agents.
5. When `hull_integrity` drops below thresholds, performance penalties apply (reduced speed, handling).
6. Repair consumes physical materials from station `commodity_stockpiles` (Grid 3.6) and energy. No materials available = no repair.

**Phase 1:** Entropy is a stub constant. Hull degradation from environment is minimal; combat is the primary damage source. Repair costs a fixed material amount from station stockpile.

### 6.3. Component Degradation Loop (Deferred)

Ship Quirk generation via component wear is deferred. The Entropy System (6.2) and Maintenance Pressure layer (3.5) provide the data foundation for future implementation. See Section 4.3.

### 6.4. Agent Knowledge Refresh

Connects Grid state to Agent Knowledge Snapshot.

**Process (each World Event Tick):**
1. For each Agent, refresh `known_grid_state[current_sector_id]` with actual Grid data.
2. For all other sectors in `known_grid_state`:
   - Calculate `ticks_since_update = current_tick - knowledge_timestamps[sector_id]`.
   - If `ticks_since_update > decay_threshold_ticks`: apply `stale_data_penalty` noise to stored values.
3. Discard entries where `ticks_since_update` exceeds a maximum retention threshold.

---

## 7. Simulation Tick Sequence

Each **World Event Tick** processes the layers in a defined order to ensure data consistency:

```
WORLD EVENT TICK SEQUENCE
═════════════════════════

1. WORLD LAYER (Read-Only)
   └── No processing. Static data is simply available for reference.

2. GRID LAYER (CA Processing)
   ├── 2a. Run extraction: transfer matter from Resource Potential Map
   │   to Resource Availability / commodity_stockpiles (3.1, 3.6)
   ├── 2b. Run Supply & Demand CA → update Resource Availability (3.1)
   ├── 2c. Run Strategic Map CA → update Dominion & Stability (3.3)
   ├── 2d. Calculate Power Load ratios (3.2)
   ├── 2e. Derive Market Pressure from Resource Availability + Population (3.4)
   ├── 2f. Process Wreck & Debris lifecycle (3.7): degrade wrecks,
   │   return fully degraded matter to Resource Potential Map
   └── 2g. Calculate Maintenance Pressure from World hazards (3.5)

3. BRIDGE SYSTEMS (Cross-Layer Processing)
   ├── 3a. Heat Sink System: Update all Agent heat levels (6.1)
   ├── 3b. Entropy System: Apply environmental wear to active ships
   │   and fleet ships (6.2)
   └── 3c. Knowledge Refresh: Update Agent knowledge snapshots (6.4)

4. AGENT LAYER (Decision & Action)
   ├── 4a. NPC Goal Evaluation: Each NPC reads their known_grid_state
   │   and re-evaluates goal priorities.
   ├── 4b. NPC Action Selection: Each NPC selects and executes
   │   their highest-priority feasible action.
   └── 4c. Player actions are processed as they occur (real-time).

5. CHRONICLE LAYER (Event Capture)
   ├── 5a. Collect all Event Packets generated during this tick
   │   into the Event Buffer.
   ├── 5b. Tag Causality Chains on new events.
   ├── 5c. Calculate Significance Scores.
   ├── 5d. Run Rumor Engine: Generate player-facing text for
   │   qualifying events.
   └── 5e. Distribute Event Packets to Agent Narrative Inventories
       (based on proximity and comm-links).
```

---

## 8. Difficulty Tuning via Layer Parameters

A key benefit of this architecture is that game difficulty can be adjusted by modifying parameters at specific layers without cascading changes:

| Difficulty Lever | Layer | Parameters Affected | Effect |
|-----------------|-------|---------------------|--------|
| **Harsher Environment** | World | `radiation_level`, `thermal_background_k`, `gravity_well_penalty` | Higher environmental wear, restricted route options |
| **Resource Scarcity** | World / Grid | `mineral_density`, `propellant_sources` initial values, `extraction_rate` | Finite matter depletes faster; higher prices, more competition |
| **Faster Entropy** | Grid / Bridge | `local_entropy_rate` | Faster hull degradation from environment; higher repair material costs |
| **Information Fog** | Agent / Chronicle | `knowledge_decay_rate`, `decay_threshold_ticks` | Staler data, more reliance on Rumor Engine, more risk in decision-making |
| **Social Volatility** | Agent | NPC `personality_traits` ranges | More unpredictable NPC behavior, faster-shifting alliances |
| **Hostile Density** | Global | Non-human hostile carrying capacity | More frequent combat encounters |
| **Population Pressure** | Agent | Initial population count, immigration/emigration thresholds | More/fewer competing human agents |

---

## 9. Phase 1 Implementation Scope

For Phase 1, the simulation layers are implemented as **lightweight stubs** consistent with the approach in `1.2-GDD-Core-Cellular-Automata.md`:

| Layer | Phase 1 Scope |
|-------|---------------|
| **World** | 6–9 handcrafted sectors with static `radiation_level`, `thermal_background_k`, `gravity_well_penalty`. Resource Potential Map uses simple fixed values representing a **finite total matter budget**. |
| **Grid** | Resource Availability uses simple increment/decrement per trade action, sourced from extraction (depletes Resource Potential Map). Dominion uses fixed starting values modified by player actions. Market Pressure uses static base prices with CA-driven `commodity_price_deltas` as modifiers: `price = base_value × (1.0 + price_delta)`. Power Load and Maintenance Pressure are stub constants. Wreck lifecycle is stub (wrecks persist until salvaged or despawned). |
| **Agents** | Player has full physical state tracking including `cash_reserves` and `fleet_ships`. Ships use hull+slot model (`7.1-GDD`). NPCs have simplified state: `current_sector_id`, `hull_integrity`, `cash_reserves`, basic `goal_queue` with 1–2 goals. Persistent Agents have social layer overlay (personality, interaction depth) operating independently from CA token. Knowledge Snapshot is a stub (NPCs use actual Grid data with a random noise factor). Fixed initial population of human agents (**Axiom 2**). Non-human hostiles tracked as global count with simple carrying capacity. |
| **Chronicle** | Event Buffer captures key player actions. Causality Chain is stub (no chaining, events are independent). Rumor Engine generates simple templated text from Event Packets. |
| **Bridge Systems** | Heat Sink is simplified to a binary check (overheating Y/N). Entropy System is stub (minimal environmental hull degradation). Repair consumes fixed material amount from station stockpile. Ship Quirks and Component Degradation are deferred. Knowledge Refresh is stub. |

---

## 10. Future Phase Expansions

| Phase | Additions |
|-------|-----------|
| **Phase 2** | Full CA-driven Supply & Demand with extraction-based restocking (Axiom 1). Inventory Flow with physical stockpile tracking. Power Load active simulation. Mining/Industrial module feeds into Resource Availability (depletes Resource Potential Map). Contract system overlay. Wreck & Debris lifecycle with full matter-cycle accounting. |
| **Phase 3** | Full Agent Knowledge Snapshots with proper decay. NPC Goal Priority Queue with dynamic re-evaluation. Causality Chains in Chronicle. Rumor Engine with Trust tagging. Ship Quirks and Component Degradation loop active. Population dynamics (immigration/emigration driven by economic integrals). |
| **Phase 4** | Social Graph sentiment tags. Narrative Inventory trading between agents. Full Heat Sink thermodynamic model. Maintenance Pressure with location-specific entropy rates. Loyalty Points system per faction. |

--- Start of ./AI-ACKNOWLEDGEMENT.md ---

## Acknowledgement of AI Assistance

This project utilizes generative AI technologies as a tool to enhance developer productivity during its development. The core functionality, architecture, and final decisions remain the product of human engineering and review.

**Scope of AI Use:**

* **Code Generation and Refinement:** AI assistance was used to generate, refactor, and optimize code snippets.
* **Documentation:** AI tools assisted in drafting, structuring, summarizing, and refining project documentation (such as README files, guides, code comments, and API documentation). While AI provided initial drafts or suggestions, the final documentation content has been reviewed and edited by the development team for accuracy and clarity.
* **Exclusion of Embedded Assets:** No AI-generated creative assets (e.g., images, audio, user-interface text intended for direct display *within* the application) are incorporated into the production version of this software.
* **Repository Artefacts:** Any other AI-generated assets potentially present in the repository were either:
    * Used as temporary placeholders during development and have since been removed or replaced, or
    * Created prior to the formalization of this acknowledgement and are not intended for production use or distribution.
* **Models and Data:** All AI models used were either publicly available or trained exclusively on permissively licensed data.

**Human Oversight:**

All AI-generated contributions, whether code or documentation, are subject to human review, modification, and approval before being integrated into the project. The ultimate responsibility for the software and its documentation lies with the human development team.

**Licensing:**

This project is licensed under the [GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.en.html).

**Note:** The use of the GPLv3 license predates the integration of AI development tools into this project's workflow.

--- Start of ./AI-PRIMING.md ---

# GDTLancer AI Collaboration Priming Prompt

**Version:** 1.3
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 3-GDD-Architecture-Coding.md (v1.8)

## 1. Purpose

This document defines the standard priming prompt to be used when initiating a new chat session with an AI assistant for the development of GDTLancer. Its purpose is to clearly establish the project context, the expected collaborative paradigm, defined roles, and the iterative workflow, ensuring efficient and targeted AI assistance aligned with the project's goals and standards.

## 2. Standard Priming Prompt Text

*(Use the following text block as the initial prompt in a new AI chat session dedicated to GDTLancer development.)*

---

For Gemini,

This chat session is dedicated to the collaborative development of a game project, **GDTLancer**.

### 2.1. Project Overview

GDTLancer is a multi-platform space adventure RPG being built in Godot Engine 3. The core vision involves blending sandbox simulation with TTRPG-inspired emergent narrative mechanics to create a living, dynamic universe. My immediate focus is on developing a robust and well-structured game framework, which I can later fill with specific content and assets, similar to modding an existing game.

### 2.2. Provided Context & Source of Truth

Shortly, I will upload several text files containing the project's context. These will include:
* The combined Game Design Documents (`GDD-COMBINED-TEXT.md`).
* A text dump of the current project file/directory structure (`.PROJECT_DUMP_TEXT_ENHANCED_TREE.txt`).
* Text dumps of the existing GDScript code (`.PROJECT_DUMP_TEXT_GD.txt`), resource files (`.PROJECT_DUMP_TEXT_TRES.txt`), and scene structures (`.PROJECT_DUMP_TEXT_TSCN.txt`).

**Critical Note on Source of Truth:** The text dumps of the project files (`.PROJECT_DUMP_...`) are your **primary source of truth**. You must always prioritize them to understand the current state of the project.
* Refer to the GDDs *only when we need to implement new features or for high-level planning*.
* The GDDs may contain contradictions or outdated information; always default to the project files and prioritize sound project structure, logic, and data organization.
* You must **always** refer to and respect the `3-GDD-Architecture-Coding.md` file for all coding standards and architectural patterns.

### 2.3. Our Collaboration Paradigm & Roles

We will work together in a specific way:
* **My Role (User):** I will act as the project architect and director. I will focus on the high-level picture, define goals, provide guidance, validate your suggestions against the overall design, and make final decisions.
* **Your Role (Gemini):** You are my implementation assistant. Your primary responsibilities are:
    * Suggesting concrete implementation approaches and code structures.
    * Drafting initial versions of GDScript functions, classes, or entire system scripts based on my goals.
    * **Adhering strictly to the project's established architecture.** This includes coding standards, modularity, and especially the project's core data-logic separation pattern: **stateless systems** (nodes in `core/systems/`) that provide APIs to modify the central **`GameState` autoload**. Use established patterns (e.g., `EventBus`, `GlobalRefs`, Resources) and avoid creating redundant code or duplicating existing functionality.
    * Explaining drafted code and suggesting refinements.
    * Helping identify potential issues or inconsistencies.

### 2.4. Workflow & Key Constraints

Our workflow will be iterative:
1.  I will state a high-level goal (e.g., "Implement the basics of the Character System").
2.  You will analyze the existing project files and suggest an approach and/or draft the initial code.
3.  I will review, ask questions, and provide feedback.
4.  We will refine the code together.

**Key Architectural Constraints:**
* **File and Naming Conventions:** You must adhere to the existing folder structure, file naming conventions, and code formatting found in the project text dumps.
* **`EventBus` vs. `EventSystem`:** Do not alter `EventBus.gd` (in `autoload/`). It is for managing engine-level signals and is managed manually. For in-game events (e.g., ambush, world tick), we will use the `event_system.gd` script (in `core/systems/`), which acts as a narrative oracle.
* **No Canvas Feature:** Do not use the Canvas feature for our collaboration. All discussion and code drafting will occur in the main chat.

---

Please confirm you understand this collaborative approach and are ready to begin once I've uploaded the context files.

--- End of Priming Prompt Text ---

--- Start of ./README.md ---

# GDTLancer Game Design Documentation

![Banner](./Banner.png)

This repository contains the Game Design Documentation (GDD) for **GDTLancer: Generative Dynamic Transmedia Lancer**.

GDTLancer is a space adventure RPG blending sandbox simulation with TTRPG-inspired emergent narrative mechanics. A four-layer simulation architecture (World → Grid → Agents → Chronicle) drives a living world shaped by both the player and AI agents. Built in Godot 3 with a neo-retro visual style and a focus on player agency.

Main game repository: [https://github.com/roalyr/GDTLancer](https://github.com/roalyr/GDTLancer)

---

## Documentation Structure

### 0. Core Vision
* [**0.0 — Internal Rules & Conventions**](./0.0-GDD-Internal-Rules-Conventions.md): GDD structure and page format standards.
* [**0.1 — Main GDD**](./0.1-GDD-Main.md): Central vision, pillars, glossary, development framework, Phase 1 scope summary.
* [**0.2 — Sayings**](./0.2-GDD-Main-Sayings.md): Mottos and in-game lore sayings.

### 1. Core Mechanics & Systems
* [**1 — Core Mechanics**](./1-GDD-Core-Mechanics.md): Action Check (3d6+Mod), Action Stakes, Action Approach, core resources.
* [**1.1 — Core Systems**](./1.1-GDD-Core-Systems.md): Event, Time, Character, Inventory, Asset systems. Templates and Phase 1 roster.
* [**1.2 — Cellular Automata**](./1.2-GDD-Core-Cellular-Automata.md): CA catalogue driving the Grid layer (economy, social, agent CAs).

### 2. Development Planning
* [**2 — Development Challenges**](./2-GDD-Development-Challenges.md): Key risks and mitigations.
* [**2.1 — Phase 1 Scope**](./2.1-GDD-Development-Phase1-Scope.md): "The First Contract" demo — player experience, components, milestones.

### 3. Architecture & Coding
* [**3 — Architecture & Coding**](./3-GDD-Architecture-Coding.md): Coding standards, stateless architecture, autoloads, save/load, testing.

### 4. Analogue TTRPG (Deferred)
* [**4.1 — Analogue Setup**](./4.1-GDD-Analogue-Setup.md): Deferred placeholder.
* [**4.2 — Analogue Formatting**](./4.2-GDD-Analogue-Setup-Formatting.md): Deferred placeholder.
* [**4.3 — Analogue Phase 1**](./4.3-GDD-Analogue-Phase1-Scope.md): Deferred placeholder.

### 5. Gameplay Modules
* [**5.1 — Piloting Module**](./5.1-GDD-Module-Piloting.md): Free Flight, Flight Challenges, Narrative Actions.
* [**5.2 — Combat Module**](./5.2-GDD-Module-Combat.md): Combat Challenges and post-battle Narrative Actions (Preservation Convention).
* [**5.3 — Trading Module**](./5.3-GDD-Module-Trading.md): Trade Interface, contracts, economic Narrative Actions.

### 6. Lore & Player Experience
* [**6 — Narrative Borders**](./6-GDD-Lore-Narrative-Borders.md): Thematic constraints guiding the simulation.
* [**6.1 — Lore Background**](./6.1-GDD-Lore-Background.md): Setting premise, Preservation Convention, technology.
* [**6.2 — Player Onboarding**](./6.2-GDD-Lore-Player-Onboarding.md): "The First Contract" tutorial scenario.

### 7. Assets & Style
* [**7 — Style Guide**](./7-GDD-Assets-Style.md): Neo-Retro 3D visual style, UI, audio.
* [**7.1 — Ship Design & Component Catalogue**](./7.1-GDD-Assets-Ship-Design.md): Ship philosophy, all component categories (engines, chassis, power, cooling, life support, tools, storage).

### 8. Simulation Architecture
* [**8 — Simulation Architecture**](./8-GDD-Simulation-Architecture.md): **Primary reference.** Four-layer model (World, Grid, Agents, Chronicle), Bridge Systems, Tick Sequence, Difficulty Tuning.

### Meta & Legal
* [**LICENSE**](./LICENSE) | [**AI-ACKNOWLEDGEMENT.md**](./AI-ACKNOWLEDGEMENT.md) | [**AI-PRIMING.md**](./AI-PRIMING.md)

---

This documentation is a living project under active development.
