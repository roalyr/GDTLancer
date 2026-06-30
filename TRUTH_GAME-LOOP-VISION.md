<!--
PROJECT: GDTLancer
MODULE: TRUTH_GAME-LOOP-VISION.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_SIMULATION-GRAPH.md § 0. Implementation Reality
LOG_REF: 2026-06-20 19:13:27
-->

# GDTLancer - Game Loop & TTRPG Simulation Vision

**Version:** 1.0
**Date:** 2026-06-15
**Status:** Approved Architectural Vision

---

## 1. Core Philosophy: The Human-Scale Frontier

The game design operates under the **Rulebook-First Principle** (see [TRUTH_PROJECT.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_PROJECT.md)): the core simulation rules, mechanics, and progression paths are canonically defined in the solo tabletop rulebook, [TRUTH_RULEBOOK.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_RULEBOOK.md). The digital loop is designed to automate and manifest these rules.

To build a meaningful TTRPG-style simulation, we must align the game rules with the setting's social and physical reality. Rather than a vast, generic space game, GDTLancer focuses on a low-population, sector-autonomous colonial frontier.

```mermaid
graph TD
    A["Colonial Frontier Setting"] --> B["Credit-Barter Dual Economy"]
    A --> C["Non-Trivial Space Travel (Expeditions)"]
    A --> D["Sectors as Clan/Family Residences"]
    
    C --> E["Logistical Planning, Crew & Team Focus"]
    C --> F["Extremely Rare Space Combat"]
    
    D --> G["Versatile Community-Embedded Agents"]
    D --> H["Bonded Agents (Pre-existing Social Ties)"]
```

### 1.1 The Credit-Barter Dual Economy
Without centralized empires or instantaneous galactic banking, the economy functions on a local, dual-layer system:
* **Electronic Credits:** Localized ledger balances representing trust and reputation. Communities issue credit to individuals they trust. Credits are used for transactions between people who share trust — typically those working at the same anchorage or with established history together.
* **Barter:** When trading across faction borders, with unaligned groups, or in spaces lacking infrastructural networks, transactions revert to direct commodity exchange (fuel, raw materials, tech components).

### 1.2 Space Travel & Flight: Logistical Weight, Arcade-Style Action
Space travel carries narrative and logistical weight, but the physical controls remain approachable:
* **Arcade Flight Mechanics:** Flight itself is arcadey and direct. We prioritize how it *feels* to fly the ship, focusing on narrative momentum and accessibility rather than imposing strict simulator physics or complex piloting challenges. 
* **Logistical Expeditions:** The "non-triviality" of travel lives in the preparation and logistics, not in the cockpit. Navigating the void requires coordinating with crew, managing fuel and supplies, and planning routes between stations.
* **Exceptional Combat:** Because resources, ships, and lives are irreplaceable in a low-population sector, space combat is an absolute last resort. Most interactions resolve through negotiation, evasion, or logistical outmaneuvering.

### 1.3 Clans, Families, and Versatile Communities
Sectors are not sterile outposts populated by single-role agents. They are the homes of persistent communities, families, clans, and localized coalitions:
* **Multi-Faceted Factions:** Factions are social groups and alliances with internal structures, histories, and cultural identities rather than corporate monoliths.
* **Versatile Agents:** Instead of hard-coded roles (like "Miner" or "Trader"), agents are residents with social obligations. While they may have primary duties (e.g., maintenance, navigation), they are versatile members of their community who adapt to survive.

---

## 2. Starting Conditions & Social Anchors

The player begins the game fully embedded in this social reality. Rather than starting as a blank slate or a colony manager, the player is an individual actor within a tight-knit community.

### 2.1 The Embedded Clan Member
The player is a first-class agent with the exact same magnitude of authority as NPC agents:
* **Not a Colony Manager:** The player does not build structures or manage the colony's layout (Dwarf Fortress style). Instead, they play as an individual agent acting in their own interest, yet deeply tied to a community.
* **A Peer Among Peers:** The relationship to the starting community feels like being part of a small clan of people you know by name. You share a home base, pool resources for big ventures, and look out for one another, but you answer for your own actions and choices — as the designated vessel operator when the community assigns you the mission.
* **Bonded Agents:** The player starts with deep, pre-existing social links to specific characters in the sector (family members, close allies, or mentors). These bonded agents are not tutorial prompts; they are persistent characters the player can talk to, interact with, and rely on for physical or emotional support. They act as the player's primary anchor in the game world.

---

## 3. Win & Loss States: Narrative-Social Stakes

Victory and defeat are defined in TTRPG terms, focusing on social stability and community survival.

### 3.1 Victory Conditions (Social Harmony & Stability)
* **Community Cohesion:** Successfully securing your community's long-term survival by establishing reliable barter routes with neighboring clans.
* **Conflict Resolution:** Mediating or resolving a long-standing dispute between your family and a rival sector clan, securing a stable alliance.
* **Social Integration:** Building strong bonds with your crew and neighboring agents, forming a resilient network that can withstand sector crises.

### 3.2 Defeat Conditions (Ostracization & Collapse)
* **Social Ostracization:** Losing the trust of your community or your bonded agents through selfish behavior, leading to exile or abandonment.
* **Community Disintegration:** The collapse of your home community's station infrastructure due to failed logistical planning, forcing the surviving members to scatter.
* **Logistical Stranding:** Becoming stranded in the deep void with an unrepairable ship, an exhausted crew, and no credit or barter options left, leading to an eventual rescue that strips you of your assets and social standing.

---

## 4. Agent Simulation & Social Loop

In this framework, the cognitive layer of the simulation focuses on relationships and community needs rather than mindless economic CA steps.

### 4.1 Relationship-Driven Decisions
NPC goals are derived from their family affiliations, personality traits, and standings with other agents:
* **Community Protection:** Agents prioritize securing basic survival goods (water, fuel) for their home sectors.
* **Reciprocity and Grudges:** If the player or another agent assists a clan member, the community becomes more willing to trade on trust — accepting your word as good, offering help unprompted. Conversely, harming or disrupting an agent creates a persistent grudge that restricts access to local station services.
* **Bond Maintenance:** Bonded agents will actively try to support the player, checking in during long voyages, offering shelter during crises, or warning them of local sector hazards.

---

## 5. Two-Speed Macro UX Contract

To satisfy both kinetic and tactical playstyles, the macro loop segregates flight and interface-based interaction into two mutually exclusive, paused-or-ticking screen states.

### 5.1 Mode A: The Kinetic Board (Flight Mode)
- **Focus:** Real-time navigation, physics-based piloting, and handling of basic mechanical heat/hull limits.
- **HUD telemetry:** Telemetry is minimal and non-intrusive. Narrative prose, logs, trade widgets, and dialogue overlays are completely suppressed.
- **Time/Simulation:** Time flows continuously, firing World Event Ticks to advance the background qualitative cellular automaton (CA) simulation.

### 5.2 Mode B: The Chronicle View (TTRPG Sheet Mode)
- **Focus:** Paused, menu-driven 2D interfaces for trade, character standing, active contracts, and sub-agent management.
- **Time/Simulation:** The simulation clock is fully paused, transforming the game into a meditative tabletop board game.
- **Content pipeline:** Narrative text is hand-authored, resolving tag-based context keys against static `.tres` template folders. Procedural prose generation is forbidden.

---

## 6. Prohibited Seams (Scope Limits)

To prevent feature creep, the following space-simulator features are strictly prohibited from implementation:

- **No speculative market displays:** Transactions increment/decrement 0–10 wealth tracks based on qualitative Contract Value Classes. Surfacing raw credit integers to the player during trade is banned.
- **No 3D on-foot navigation:** No player avatars, station interiors, or space-legs systems. All community interactions are resolved via the grid-aligned 2D menus of the Chronicle View.

---

## 7. Sub-Agent Layer & Morale

The social dimension of GDTLancer is modeled not by scaling the primary ship simulation, but by parenting a lightweight, qualitative human software layer under primary agent entities.

### 7.1 Data-Only Sub-Agent Structs
- **Structure:** Personnel, station populations, or crew members exist as basic data sub-arrays inside parent ship or station agents.
- **Role:** Sub-agents do not independently process simulation ticks, carry cargo, or resolve checks. They function as narrative gatekeepers, enabling or gating parent choices through relationship standing or specialized commerce roles.
- **Transfers:** Transfers of personnel are managed via the dedicated API `sub_agent_transfer(sub_agent_id, from_host_id, to_host_id)`, with morale adjusted as a consequence of the transfer.

### 7.2 The Morale Loop & Defeat Conditions
- **Stat tracking:** Sub-agents track individual Morale stats. The parent ship or station aggregates these into an average crew Morale score used as the modifier for crew-dependent checks.
- **Decay:** Morale decays deterministically when the parent agent spends prolonged periods in high-entropy sectors or ignores crew needs. Morale decay is a threshold-gated step function defined in constants.
- **Defeat:** If the aggregate Morale of the player's vessel drops to 0, it triggers an immediate crew strike or mutiny, ending the voyage as a hard defeat condition.

