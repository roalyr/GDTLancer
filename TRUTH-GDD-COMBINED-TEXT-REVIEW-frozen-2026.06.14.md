--- Start of ./0.0-GDD-Internal-Rules-Conventions.md ---

<!--
PROJECT: GDTLancer
MODULE: 0.0-GDD-Internal-Rules-Conventions.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Workflow And Scope Boundary
LOG_REF: 2026-06-13 23:57:00
-->

# 0.0 GDTLancer - Internal GDD Rules and Conventions

**Version:** 2.2
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13), [README.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/README.md)

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

<!--
PROJECT: GDTLancer
MODULE: 0.1-GDD-Main.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Main GDD

**Version:** 4.13
**Date:** 2026-06-13
**Related Documents:** [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8), [1.1-GDD-Core-Systems.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1.1-GDD-Core-Systems.md) (v5.8), [3-GDD-Architecture-Coding.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/3-GDD-Architecture-Coding.md) (v3.4)

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
| **Action Check** | Core dice roll for Narrative Actions: `3d6 + Module Modifier`. See [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md). |
| **Agent** | An active entity pursuing goals. **Persistent** (named, permanent) or **Temporary** (governed qualitatively in the runtime population budget, rather than via numeric spawn matrices). Player and NPC agents operate under strict parity of mechanics. |
| **Asset** | A significant non-consumable item (ship, equipment). |
| **Chronicle** | Output layer that captures events and translates them into player-facing narrative. See [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 5. |
| **Conservation Axioms** | Five governing invariants (Matter, Population, Material Basis of Value, Thermodynamic Arrow, Causality) that constrain all simulation design intent. The live runtime enforces these qualitatively via tag propagation and bounded-occurrence loops rather than numeric bookkeeping. See [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 1.3. |
| **Contact** | A Persistent Agent the player has met. Synonymous with Persistent Agent. |
| **Equipment Slot** | A slot on a ship hull that accepts swappable equipment. Equipment provides Action Check modifiers or enables gameplay capabilities. See [7.1-GDD-Assets-Ship-Design.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/7.1-GDD-Assets-Ship-Design.md). |
| **Faction** | A political/corporate entity. Factions dictate transaction trust based on their presence and sector tags. See [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 1.3. |
| **Grid** | Dynamic systemic simulation layer driven by CA. See [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 3. |
| **Knowledge Snapshot** | Agent's personal, potentially outdated copy of Grid data. See [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 4.4. |
| **Module** | A set of mechanics for a specific activity (Piloting, Contracting, Contacts). |
| **Narrative Action** | An action resolved by dice roll (`3d6 + Modifier`), not real-time skill. See [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) Section 2.2. |
| **Population Budget** | Fixed initial human population; changes driven by economic integrals, not spawn dice (**Axiom 2**). |
| **Preservation Convention** | Cultural norm prioritizing ship disablement over destruction, codifying a setting doctrine where human conflict is primarily non-lethal (sabotage, coercion) while lethal combat is restricted to external threats (drones, aliens). |
| **Ship Quirk** | A negative trait acquired through damage. *Deferred — not implemented in Phase 1.* |
| **Skill Action** | An action resolved by real-time player performance. Outcome is authoritative. See [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) Section 2.1. |
| **Wealth Tiers** | Three qualitative classifications representing the player's current financial status: **Broke**, **Comfortable**, and **Wealthy**. Each tier acts as a modifier to commercial and social Action Checks. See [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) Section 6.1. |
| **Wealth Tracks** | Three player-only 0–10 progression scales mapping progress within the active **Wealth Tier**. Gaining profit/rewards increases progress; spending or sustaining damage/losses decreases progress. Promotion or demotion occurs upon reaching 10 or dropping below 0. See [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) Section 6.1. |
| **World** | Static physical foundation layer. See [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 2. |
| **World Event Tick** | Periodic simulation step that advances the qualitative CA Grid, Bridge Systems, and Agent state. See [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 7. |
| **Wreck** | A disabled ship persisting in a sector as salvageable asset. Degrades via entropy; returns matter to Resource Potential Map when fully degraded. See [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 3.7. |


## 3. Game Pillars

* **Living World:** Evolves based on all agents' actions and time passage, driven by the four-layer simulation (`8-GDD`).
* **Emergent Narrative:** Stories emerge from the simulation and player choices, surfaced via the Chronicle.
* **Meaningful Progression:** Improve skills, complete goals, acquire assets, build wealth.
* **Simple, Consistent Rules:** Unified `3d6 + Modifier` core mechanic.
* **Player Driven:** Players direct the experience by managing risk, time, and resources.

### 3.1. World Design: Finite Resource Sandbox

A small, tightly-scoped universe where every element is handcrafted, countable, and meaningful. It is governed by Conservation Axioms (see [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) Section 1.3), framing a sandbox of finite, tracked matter and population. In the live runtime, these conservation rules operate as design intent constraints enforced via a qualitative tag-propagation and bounded-occurrence substrate ([REV_001](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/TRUTH_GDD-REVISION-LEDGER.md#L28)) rather than a real-time numeric stockpile counter. Structurally, the universe is modeled as a nested 4-tier topology (Stellar Systems → Planets → Moons → Deep Space POIs) designed as a flat graph for gameplay simplicity ([REV_005](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/TRUTH_GDD-REVISION-LEDGER.md#L72)). Wealth is also tracked qualitatively: while the simulation models trade and assets via abstract indicators, the player's personal wealth is represented by qualitative Wealth Tiers and 0–10 tracks (Broke, Comfortable, Wealthy) rather than detailed numeric ledger balances.

* **Comprehensible Scale:** The player can fully understand the world's actors, factions, and locations.
* **Emergent Lore:** Minimal starting lore. World history develops through gameplay.
* **Depth Before Breadth:** Perfect core systems before expanding quantity.
* **Controlled Expansion:** Procedural generation added sparingly in focused updates.

**Phase 1 Demo Scope:**

| Element | Quantity | Notes |
|---------|----------|-------|
| Factions | 3 | Factions will not be generic role-type ones, this requires implementing lore background |
| Locations | 6–9 | Maybe 2–3 per faction |
| Persistent Agents | 6-10 | At least 2 per faction |
| Player Ships | 2-5 | Starting + unlockable |
| Commodities | -- | Commodities exist as simulation cargo categories; player interaction is exclusively via contracts (no direct market UI). Module detail deferred. |
| Temporary Agent Types | 1–2 | Non-human hostiles (drones/fauna), global population integral |

## 4. Core Gameplay

* **Philosophy:** Simulation-first in background. Emergent narrative progression in foreground.
* **Modules:** Piloting, Contracting, Contacts.
* **Core Loop:** Interacting with agents and dockables, completing contracts (hauling, exploring, etc).

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
    * **Phase 1 (Core Loop):** Playable vertical slice — Piloting, Contracting, Contacts with stub simulation layers; Primary lore background.
    * **Phase 2 (Narrative):** Full CA-driven Grid; Expanded assets; Deeper interactions; Deeper characters.
    * **Phase 3 (Living World):** Deeper agentic interactions, lore background expansion.

## 7. Art & Audio

* **Visuals:** "Neo-Retro 3D" — GLES2, medium-low-poly, hard-edged models. See `7-GDD-Assets-Style.md`.
* **Audio:** Minimalist, functional SFX and atmospheric music.
* **UI/UX:** Clean, non-intrusive, functional. See `7-GDD-Assets-Style.md`.

## 8. Technical

* **Engine:** Godot 3 (GLES2 backend).
* **Architecture:** Stateless systems operating on centralized `GameState`. See `3-GDD-Architecture-Coding.md`.
* **Modularity:** Systems are independent and maintainable.

--- Start of ./0.2-GDD-Main-Sayings.md ---

<!--
PROJECT: GDTLancer
MODULE: 0.2-GDD-Main-Sayings.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Workflow And Scope Boundary
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Mottos & Sayings

**Version:** 1.9
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13)

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

<!--
PROJECT: GDTLancer
MODULE: 1.1-GDD-Core-Systems.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Core Systems (Phase 1)

**Version:** 5.8
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8), [3-GDD-Architecture-Coding.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/3-GDD-Architecture-Coding.md) (v3.4)

## 1. Overview

Defines the stateless system APIs that implement the simulation architecture. All systems are `Node` scripts in `core/systems/`, parented under `WorldManager`. They read from and write to `GameState` — they hold no state of their own.

Each system maps to one or more simulation layers from `8-GDD-Simulation-Architecture.md`.

<!-- Pruned, refer to codebase -->

--- Start of ./1.2-GDD-Core-Cellular-Automata.md ---

<!--
PROJECT: GDTLancer
MODULE: 1.2-GDD-Core-Cellular-Automata.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Cellular Automata

**Version:** 2.2
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)

## 1. Overview

CA implementations are background simulation engines that drive the **Grid layer** (`8-GDD` Section 3). They run during step 2 of the World Event Tick sequence, updating resource availability, faction dominion, market pressure, and social networks. Their outputs feed Agent decision-making and Chronicle event generation.

The player influences CA indirectly through gameplay actions. Results are surfaced via diegetic means: maps, descriptions, dialogue, and evolving opportunities.

<!-- Pruned, refer to codebase -->

--- Start of ./1-GDD-Core-Mechanics.md ---

<!--
PROJECT: GDTLancer
MODULE: 1-GDD-Core-Mechanics.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Core Mechanics

**Version:** 5.8
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)

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

### 6.1. Wealth Tiers & Tracks (Personal Wealth)

* Personal wealth is represented by three qualitative **Wealth Tiers**: **Broke**, **Comfortable**, and **Wealthy**.
* Each tier contains a 0–10 **Wealth Track** representing the player's progression within that tier.
* **Gaining Wealth:** Gaining rewards or completing transport/delivery contracts increments progress on the current track. Reaching 10 on the current track promotes the player to 0 of the next higher tier (Broke 10 → Comfortable 0).
* **Spending Wealth:** Repairing assets, purchasing ship equipment, or paying recovery costs decrements progress. Dropping below 0 demotes the player to 10 of the next lower tier (Comfortable 0 → Broke 10).
* **Action Check Modifiers:** The active Wealth Tier applies a modifier to commercial and social Action Checks:
  - **Broke:** -2 modifier. Refined metals/commodities are expensive; agents are suspicious of your insolvency.
  - **Comfortable:** +0 modifier. Standard pricing and relationship reactions.
  - **Wealthy:** +2 modifier. Better leverage in negotiations; elite service access.
* **Personal Wealth Progression:** Fulfilling contracts updates the player's active wealth track progress based on the Contract Value Class of the completed task:
  - **Low Value Class:** +1 track progress (common courier work, minor salvaging).
  - **Mid Value Class:** +2 track progress (systemic hauling, standard scouting).
  - **High Value Class:** +3 track progress (dangerous escorting, high-priority logistics).

### 6.2. Time

* Real-time clock. World Event Ticks fire at `Constants.TIME_TICK_INTERVAL_SECONDS`.
* Time is a critical resource — the world evolves independently of the player.
* Each tick triggers: World layer static reference → Grid CA updates (including extraction from finite Resource Potential Map) → Bridge Systems (entropy, heat) → Agent processing → Chronicle capture.

## 7. Failure & Recovery

Loss is **substantial but not terminal** — part punishment, part opportunity.

### 7.1. Ship Disabled (Hull → 0)

<!-- Reimplementation postponed -->

### 7.2. Resource Depletion

<!-- Reimplementation postponed -->

### 7.3. True Game Over

True game over requires a **convergence of multiple failures** — not a single bad roll or fight. The player must reach a state where recovery paths are exhausted (e.g., disabled with Broke at 0 progress, hostile standings with all factions, no Contacts willing to help). This is intentionally difficult to achieve.

--- Start of ./2.1-GDD-Development-Phase1-Scope.md ---

<!--
PROJECT: GDTLancer
MODULE: 2.1-GDD-Development-Phase1-Scope.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 19:50:00
-->

# GDTLancer - Phase 1 Scope & Goals

**Version:** 2.4
**Date:** 2026-06-13

<!-- No hard milestone / no concrete goal is to be defined at this point since codebase evolves more unpredictably and dynamically than expectd. Also important architectural decisions can not be witheld. -->

--- Start of ./2-GDD-Development-Challenges.md ---

<!--
PROJECT: GDTLancer
MODULE: 2-GDD-Development-Challenges.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Development Challenges

**Version:** 2.2
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)

## 1. Overview

Key development risks for GDTLancer, identified early for proactive mitigation.

## 2. Design Challenges

### Emergent Narrative Complexity
Making the "living world" produce coherent, engaging stories — not random noise.

* **Mitigations:** Phased rollout of Agent complexity. Clear NPC goal-selection heuristics (`8-GDD` Section 4). Chronicle system (`8-GDD` Section 5) logs events for Agent reactions.

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

<!--
PROJECT: GDTLancer
MODULE: 3-GDD-Architecture-Coding.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Coding Standards & Architecture Guide

**Version:** 3.4
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)

## 1. Engine & Language

* **Engine:** Godot Engine v3.x
* **GUT version:** 7.4.3
* **Renderer:** GLES2 (performance & compatibility)
* **Language:** GDScript (static typing hints where beneficial)

## 2. Core Philosophy

* **KISS:** Prefer simpler implementations. Clarity over excessive abstraction.
* **Modularity:** Split scripts exceeding ~300 lines. Structure around:
    * **Modules** (horizontal activity loops): Piloting, Contracting, Contacts.
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

* Example: `CharacterSystem.gain_wealth_progress(uid, amount)` retrieves the character from `GameState.characters`, modifies `wealth_progress`, emits signal on `EventBus`.
* Getters returning `Dictionary` or `Array` **must** return `.duplicate(true)` copies.
* Systems react to and emit signals via `EventBus` (e.g., `_on_world_event_tick`, `player_wealth_changed`).

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

* **Movement:** Reverted to rigid-body physics due to complications with slide-and-rotate system. 
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

<!--
PROJECT: GDTLancer
MODULE: 5.1-GDD-Module-Piloting.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Piloting Module

**Version:** 4.2
**Date:** 2026-06-13
**Related Documents:** [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) (v5.8), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)

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

<!-- No concrete requirements -->

--- Start of ./5.2-GDD-Module-Combat.md ---

<!--
PROJECT: GDTLancer
MODULE: 5.2-GDD-Module-Combat.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Combat Module

**Version:** 3.5
**Date:** 2026-06-13
**Related Documents:** [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) (v5.8), [6-GDD-Lore-Narrative-Borders.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/6-GDD-Lore-Narrative-Borders.md) (v2.2), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)


<!-- Reimplementation postponed -->

--- Start of ./5.3-GDD-Module-Trading.md ---

<!--
PROJECT: GDTLancer
MODULE: 5.3-GDD-Module-Trading.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Trading Module

**Version:** 3.8
**Date:** 2026-06-13
**Related Documents:** [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) (v5.8), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)

<!-- Reimplementation postponed -->

--- Start of ./6.1-GDD-Lore-Background.md ---

<!--
PROJECT: GDTLancer
MODULE: 6.1-GDD-Lore-Background.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Lore & Background

**Version:** 2.6
**Date:** 2026-06-13
**Related Documents:** [6-GDD-Lore-Narrative-Borders.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/6-GDD-Lore-Narrative-Borders.md) (v2.2), [7-GDD-Assets-Style.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/7-GDD-Assets-Style.md) (v1.5), [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) (v5.8)

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
<!-- For now postponing human ship-to-ship combat entirely -->

## 4. Technology & Aesthetics

* **Baseline:** Grounded, functional technology. Function-first aesthetic emphasizing reliability and modularity.
* **Travel:** No common FTL. In-system travel via engines; inter-sector travel is abstracted as high cost in wealth progress and time. Interstellar flight requires high-energy facilities near the stars, allowing ships to accelerate.

## 5. Naming & Language

* **Names:** Blend of diverse Earth cultures.
* **Language:** Practical, direct creole lingua franca with heavy technical jargon.

## 6. Factions (Phase 1)

Three distinct, non-generic factions drive systemic and narrative conflicts in the sector. Detailed backgrounds and names will be authored manually:
* **Faction A:** [Placeholder: Primary faction representing institutional authority, safety, and core infrastructure. Relies on structured contracts and strict regulations.]
* **Faction B:** [Placeholder: Second faction representing corporate, industrial, or scientific interests. Focuses on extraction, efficiency, and technological progress at any cost.]
* **Faction C:** [Placeholder: Third faction representing a fringe, independent, or nomadic group. Operates in deep space POIs, values personal autonomy, and is often skeptical of centralized systems.]

## 7. Implementation

Setting is experienced through mechanical consequences (flight challenges, entropy system), dialogue, and design — minimizing direct exposition. "Show, don't tell."

--- Start of ./6.2-GDD-Lore-Player-Onboarding.md ---

<!--
PROJECT: GDTLancer
MODULE: 6.2-GDD-Lore-Player-Onboarding.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Player Onboarding

**Version:** 2.4
**Date:** 2026-06-13
**Related Documents:** [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) (v5.8), [6.1-GDD-Lore-Background.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/6.1-GDD-Lore-Background.md) (v2.6)

## 1. Goals

Introduce core systems in the first 30–60 minutes without overwhelming. Teach Action Checks and Stakes, demonstrate the gameplay loop (accept goal → travel → perform actions → reward), convey setting through action, and provide a clear next step.

## 2. Philosophy

* **Guided, Not Forced:** Clear starting goal in controlled area; allow experimentation.
* **Learn by Doing:** Introduce mechanics when needed.
* **Contextual:** Frame tutorial within a simple story revealing the setting.

<!-- Specific scenario postponed for now. -->

--- Start of ./6-GDD-Lore-Narrative-Borders.md ---

<!--
PROJECT: GDTLancer
MODULE: 6-GDD-Lore-Narrative-Borders.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Narrative Borders of the Simulation

**Version:** 2.2
**Date:** 2026-06-13
**Related Documents:** [6.1-GDD-Lore-Background.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/6.1-GDD-Lore-Background.md) (v2.6), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)

## 1. Purpose

Defines the thematic constraints — the "borders" — within which the simulation operates. The simulation serves the narrative: it is a thematically-focused story generator, not an open-ended universe simulation. These borders ensure emergent stories are grounded in established lore.

## 2. The Core Narrative Borders

### Border 1: Preservation of Assets
* **Lore:** Scarcity of complex materials and skilled personnel → the **Preservation Convention** prizes neutralization and capture over destruction.
* **Mechanical:** Destruction = least profitable, most consequence-heavy outcome (minimal salvage, Reputation loss, negative Faction Standing). Disablement/capture = most rewarding path — disabled ships become salvageable wrecks with their full inventory (**Axiom 1**, `8-GDD` Section 3.7). NPC agents default to disabling tactics; only defined outlier groups (fanatical outlaws, rogue fauna, etc) favor destruction.

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

<!--
PROJECT: GDTLancer
MODULE: 7.1-GDD-Assets-Ship-Design.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001, REV_007
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Ship Design & Component Catalogue

**Version:** 4.3
**Date:** 2026-06-13
**Related Documents:** [7-GDD-Assets-Style.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/7-GDD-Assets-Style.md) (v1.5), [6.1-GDD-Lore-Background.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/6.1-GDD-Lore-Background.md) (v2.6), [8-GDD-Simulation-Architecture.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/8-GDD-Simulation-Architecture.md) (v2.8)

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

<!--
PROJECT: GDTLancer
MODULE: 7-GDD-Assets-Style.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - General Asset & Style Guide

**Version:** 1.5
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13), [6.1-GDD-Lore-Background.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/6.1-GDD-Lore-Background.md) (v2.6), [7.1-GDD-Assets-Ship-Design.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/7.1-GDD-Assets-Ship-Design.md) (v4.3)

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

<!--
PROJECT: GDTLancer
MODULE: 8-GDD-Simulation-Architecture.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_GDD-REVISION-LEDGER.md § REV_001
LOG_REF: 2026-06-13 23:57:00
-->

# GDTLancer - Simulation Architecture

**Version:** 2.8
**Date:** 2026-06-13
**Related Documents:** [0.1-GDD-Main.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/0.1-GDD-Main.md) (v4.13), [1-GDD-Core-Mechanics.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1-GDD-Core-Mechanics.md) (v5.8), [1.1-GDD-Core-Systems.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1.1-GDD-Core-Systems.md) (v5.8), [1.2-GDD-Core-Cellular-Automata.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/1.2-GDD-Core-Cellular-Automata.md) (v2.2), [3-GDD-Architecture-Coding.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/3-GDD-Architecture-Coding.md) (v3.4), [7.1-GDD-Assets-Ship-Design.md](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/7.1-GDD-Assets-Ship-Design.md) (v4.3)

---

## 1. Overview

This document defines GDTLancer's simulation as a **layered, data-driven architecture**. The purpose is to cleanly isolate the **Physical world** from the **Systemic logic** and **Cognitive agents**, enabling each layer to be tuned, tested, and extended independently.

The simulation operates on four distinct layers, processed sequentially each tick:

1. **The World** — Static, handcrafted physical foundation. Changes only between content updates.
2. **The Grid** — Dynamic systemic state driven by Cellular Automata and tick-based rules. Reacts to Agent activity and World constraints.
3. **The Agents** — Cognitive entities (player and NPCs) that read the Grid, maintain internal knowledge, and act upon the world.
4. **The Chronicle** — An output layer that captures events, chains causality, and translates raw simulation data into player-facing narrative.

This separation allows difficulty tuning (e.g., harsher environmental hazards, faster resource depletion) by adjusting World or Grid parameters without touching Agent AI logic.

### 1.1. Relationship to Existing Architecture

This document provides the **conceptual simulation model** that the game systems and save state implement. It represents the design intent mapping of how the environment, economic layers, characters, and narrative chronicle interact dynamically.

### 1.2. Relationship to Cellular Automata

The Grid layer is the primary consumer of the Cellular Automata (CA) systems. The CA networks (strategic maps, supply and demand flows, social networks) are the systemic engines driving Grid transitions each simulation tick.

### 1.3. Governing Invariants (Conservation Axioms)

The simulation is governed by conservation laws that ensure internal consistency and prevent unbounded growth or creation-from-nothing. These axioms act as strict constraints on system design:

* **Axiom 1 — Conservation of Matter:** The total extractable matter in the universe is finite, fixed at world initialization, and distributed across the resource maps. Matter cycle is closed: extraction → refinement → use → degradation → diffuse potential → re-extraction. Organized matter (wrecks, debris) degrades back into raw potential.
* **Axiom 2 — Conservation of Population:** The universe is seeded with a fixed initial human population. Changes (immigration, emigration, death) are driven by economic and resource conditions, not spawn probability. Hostiles (drones, fauna) are tracked via global population integrals capped by carrying capacity.
* **Axiom 3 — Material Basis of Value:** Economic value is represented qualitatively, mapping character wealth to social and economic status: player wealth is tracked via three qualitative Wealth Tiers (Broke, Comfortable, Wealthy) with associated tracks, while NPCs use status tags (POOR, ADEQUATE, RICH) for accounting. Transactions settle via ledger entries that consume physical materials and energy, not virtual bank balances.
* **Axiom 4 — Thermodynamic Arrow:** Reversing entropy (repairs, construction) requires both physical materials and energy inputs. Structures and ships passively degrade over time without active maintenance. Primary energy sources (stellar radiation, nuclear fuels) act as the external gradient driving economic activity.
* **Axiom 5 — Causality and Information Locality:** Effects have traceable causes. Information propagates locally (no instant global knowledge), and internal knowledge snapshots decay and become stale without active maintenance.

> [!NOTE]
> **Qualitative Runtime Constraint:** These axioms serve as core design intent constraints. The live runtime enforces these qualitatively via tag propagation and bounded-occurrence loops (e.g., tag transitions, cargo tags) rather than real-time numeric stockpile bookkeeping ([REV_001](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/TRUTH_GDD-REVISION-LEDGER.md#L28)).

---

## 2. Layer 1: The World (Physical Foundation)

The World layer contains static, handcrafted data defining the physical constraints of the universe. This data is read-only at runtime and changes only via content updates.

* **Topology Map:** Defines the spatial layout and connection network between sectors. Structurally modeled as a nested 4-tier celestial hierarchy (Stellar Systems → Planets → Moons → Deep Space POIs) designed as a flat graph for gameplay simplicity ([REV_005](file:///home/roalyr/Software_archive/Games/GDTLancer-game-design/TRUTH_GDD-REVISION-LEDGER.md#L72)).
* **Environmental Hazard Map:** Defines cosmic radiation levels, thermal background temperatures (which determine the heat dissipation ceiling for ship radiators), and gravity well thrust penalties near planets.
* **Resource Potential Map:** Defines where raw mineral deposits and propellant feedstocks exist. These values are mutated at runtime as extraction depletes them and degradation returns diffuse materials to the local sector.

---

## 3. Layer 2: The Grid (Systemic CA Layers)

The Grid contains the dynamic simulation state updated each World Event Tick by Cellular Automata and agent activity.

* **Resource Availability:** Stockpile levels of propellant, consumables, and energy at locations, depleted by agent consumption and replenished by extraction or supply runs.
* **Power Load:** Balance of energy generation versus demand at persistent locations, triggering brownouts and service cost penalties when demand exceeds output capacity.
* **Dominion & Security:** Maps of faction influence, security levels, and pirate activity, determining patrol frequency and encounter rates.
* **Market Pressure:** Derived price adjustments for trade items and services based on physical supply/demand imbalances relative to population density.
* **Maintenance Pressure (Entropy):** Wear-and-tear rates on assets driven by environmental harshness (radiation, thermal extremes), necessitating physical repair materials.
* **Inventory Flow:** Physical inventories of cargo commodities stored at locations that agents exchange via contracts, directly reflecting local resource depletion.
* **Wreck & Debris Lifecycle:** Persistence of disabled ships as salvageable wrecks that slowly degrade and return their mass to the local Resource Potential Map.

---

## 4. Layer 3: The Agents (Cognitive & Social Data)

Agents are active entities (both player and NPCs) that perceive the Grid, maintain internal states, and select goals.

* **Spatial & Physical State:** The agent's current sector location, hull integrity, active resource reserves (propellant, consumables, energy), qualitative wealth tier/progress track, fleet assets, and current ship thermal load.
* **Operational Attributes:** Skill modifiers that determine success probability and complication risk for piloting, combat, and trading Narrative Actions.
* **Knowledge Snapshot:** A personal, potentially outdated copy of Grid data (commodity prices, security, influence) representing the agent's belief state, which decays over time.
* **Social Graph:** Standing levels with factions, individual character affinities, and specific sentiment tags (e.g., Grudges, Favors) that drive NPC goals and player interactions.
* **Goal Priority Queue:** Ranked objectives dictated by personality archetypes, following a default hierarchy of: Survival → Personal Goals → Faction Duty → Opportunism.
* **Narrative Inventory:** A memory buffer of witnessed or received event packets that agents can trade or relay.

---

## 5. Layer 4: The Chronicle (Output Layer)

The Chronicle translates raw simulation events into player-facing narrative, acting as the narrative wrapper of the sandbox.

* **Event Buffer:** Logged records of actor activities, targets, locations, and outcomes (success, failure, critical states) generated each tick.
* **Causality Chain:** Logical links connecting effects to prior events (e.g., linking price spikes to freighter losses) to calculate significance scores and surface meaningful news.
* **Rumor Engine:** Translation system that converts raw event logs into player-facing rumors and news items, tag-gated by source reliability and proximity.
* **Knowledge Decay:** Algorithmic degradation that introduces noise and inaccuracy to an agent's knowledge snapshot for sectors they have not visited recently.

---

## 6. Bridge Systems

Cross-cutting mechanics that connect World physical constraints to Agent behaviors through Grid state changes.

* **Heat Sink System:** Calculates net heat change each tick based on thermal energy generated by active modules (propulsion, tools) versus maximum environment heat dissipation. Overheating triggers efficiency penalties, system shutdowns, or hull damage.
* **Entropy System:** Applies environmental wear to active and docked ships based on local entropy rates. Reversing degradation requires docked maintenance consuming physical materials from station stockpiles and local power grid energy.
* **Agent Knowledge Refresh:** Automatically updates an agent's knowledge snapshot for their current sector, while decaying knowledge of distant sectors by applying stale-data noise.

---

## 7. Simulation Tick Sequence

Each World Event Tick processes the simulation layers sequentially to maintain data consistency:

```
WORLD EVENT TICK SEQUENCE
═════════════════════════

1. WORLD LAYER (Read-Only Reference)
   └── Static data maps are available for lookups.

2. GRID LAYER (CA Processing)
   └── Run extraction → run supply/demand → update faction strategic maps →
       calculate power loads → derive market prices → progress wreck decay lifecycles.

3. BRIDGE SYSTEMS (Cross-Layer Processing)
   └── Run Heat Sink logic → apply passive Entropy wear → decay distant Agent knowledge.

4. AGENT LAYER (Decision & Action)
   └── NPC goal prioritizations and action choices resolve; Player actions execute.

5. CHRONICLE LAYER (Event Capture & News)
   └── Buffer tick events → trace causality chains → run Rumor Engine formatting →
       distribute rumors to agent memories based on proximity.
```

---

## 8. Difficulty Tuning via Layer Levers

Game difficulty can be adjusted globally by altering parameters at specific layers without impacting other systems:

| Tuning lever | Affected Layer | Effect |
|:---|:---|:---|
| **Harsher Environment** | World | Increases radiation, heat, and gravity penalty, restricting route planning. |
| **Resource Scarcity** | World / Grid | Lowers starting raw materials, increases price volatility and faction friction. |
| **Faster Entropy** | Grid / Bridge | Increases environmental ship wear and repair material costs. |
| **Information Fog** | Agent / Chronicle | Accelerates knowledge decay, increasing trade and navigation risks. |
| **Social Volatility** | Agent | Amplifies standing changes, making NPC relations shift rapidly. |
| **Hostile Density** | Global | Increases hostile carrying capacities, resulting in more frequent threats. |

---

## 9. Phase 1 Implementation Scope

In Phase 1, the simulation operates on lightweight stubs consistent with the core vertical slice:

* **World:** 6–9 handcrafted sectors, static hazard values, and a simplified static total matter budget.
* **Grid:** Stockpiles increment/decrement directly based on transactions, prices are modified by simple linear deltas, and power/maintenance are static constants. Wrecks persist indefinitely until salvaged.
* **Agents:** Player wealth tiers and tracks are fully active; NPCs use simplified status tags, basic goal queues, and actual Grid data mixed with random noise to simulate knowledge.
* **Chronicle:** Events are buffered and formatted into simple templated text. Causality chain tracking is deferred.
* **Bridge Systems:** Heat is a binary check, environmental entropy is minimal, and repairs consume fixed material quantities. Ship quirks and component wear tracking are deferred.

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

--- Start of ./MODEL-CASCADE-PROTOCOL.md ---

<!--
PROJECT: GDTLancer
MODULE: MODEL-CASCADE-PROTOCOL.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; TRUTH_PROJECT.md § Session Logging Boundary
LOG_REF: 2026-06-13 07:10:18
-->

WORKSPACE CONFIGURATION

Each project must maintain the following "Truth" and "State" files:

    READ-ONLY TRUTHS: TRUTH_PROJECT.md (Project specific context, tech stack, global rules), TRUTH_*.md (GDD, Datasheet, Spec, etc.), and GDD chapters (X.Y-GDD-*.md).
    READ-WRITE STATE: TACTICAL_TODO.md (Current Sprint) and SESSION-LOG.md (Loop Prevention).

SESSION ENTRYPOINT

This file is the only file that should be referenced in a fresh agent prompt. Use a prompt such as:

    Refer to @file:MODEL-CASCADE-PROTOCOL.md and act as [Lead Game Designer / Game Designer / GDD Verificator].

The agent should treat this file as the workflow router for every role. All required follow-up reads are linked below.

LINKED READ PATH

Always read next from this file:

1. [TRUTH_PROJECT.md](TRUTH_PROJECT.md) — project constraints, agent parity, and workflow boundary.
2. [TACTICAL_TODO.md](TACTICAL_TODO.md) — active design contract and first unchecked task.
3. [SESSION-LOG.md](SESSION-LOG.md) — latest reverse-chronological state and prior mistakes.

Read only when the active task requires it:

1. [TRUTH_SIMULATION-GRAPH.md](TRUTH_SIMULATION-GRAPH.md) — simulation design, mathematical formulas, and layers.
2. [TRUTH_CONTENT-CREATION-MANUAL.md](TRUTH_CONTENT-CREATION-MANUAL.md) — data templates, directory structures, and content schemas.
3. [TRUTH_GDD-REVISION-LEDGER.md](TRUTH_GDD-REVISION-LEDGER.md) — approved design revisions, lore/setting pivots, and frozen doctrine updates.
4. [TRUTH_CONSTRAINTS.md](TRUTH_CONSTRAINTS.md) — compatibility reference and historical redirects.
5. [AI-ACKNOWLEDGEMENT.md](AI-ACKNOWLEDGEMENT.md) — human review and AI-usage boundary.
6. The actual GDD files (e.g., [0.0-GDD-Internal-Rules-Conventions.md](0.0-GDD-Internal-Rules-Conventions.md), [0.1-GDD-Main.md](0.1-GDD-Main.md), [8-GDD-Simulation-Architecture.md](8-GDD-Simulation-Architecture.md)) — specific game design chapters listed in the [README.md](README.md) index.

Do not load by default:

1. [TRUTH_PROJECT_DUMP_TEXT_GD.md](TRUTH_PROJECT_DUMP_TEXT_GD.md), [TRUTH_PROJECT_DUMP_TEXT_TSCN.md](TRUTH_PROJECT_DUMP_TEXT_TSCN.md), [TRUTH_PROJECT_DUMP_TEXT_TRES.md](TRUTH_PROJECT_DUMP_TEXT_TRES.md), [TRUTH_PROJECT_DUMP_TEXT_PY.md](TRUTH_PROJECT_DUMP_TEXT_PY.md), [TRUTH_PROJECT_DUMP_TEXT_ENHANCED_TREE.md](TRUTH_PROJECT_DUMP_TEXT_ENHANCED_TREE.md) — generated codebase reference dumps containing the implementation details of the main game repository. Use only when verifying design-to-code alignment.

WORKFLOW CONTEXT LAYERS

  CONTROL PLANE (default first-read set): MODEL-CASCADE-PROTOCOL.md, TRUTH_PROJECT.md, TACTICAL_TODO.md, SESSION-LOG.md.
  LIVE REFERENCE (load only the targeted sections/files needed for the active task): relevant GDD documents, `TRUTH_GDD-REVISION-LEDGER.md` for design/setting changes, and other `TRUTH_*.md` files.
  ARCHIVE / GENERATED REFERENCE (do not load by default): `TRUTH_PROJECT_DUMP_TEXT_*` and other generated codebase dumps, unless verification explicitly requires checking code/assets parity.

CORE CONSTRAINTS

Format & Naming Constraints:

1. File names must strictly follow the `X.Y-GDD-<ChapterName>-<SubChapterName>.md` pattern as defined in [0.0-GDD-Internal-Rules-Conventions.md](0.0-GDD-Internal-Rules-Conventions.md).
2. The master index is [README.md](README.md). Any added, renamed, or deleted files must be immediately updated in [README.md](README.md).
3. Standard page structure must be maintained for GDD chapters: Header (Title, Version, Date, Related Documents), Overview, Core Content, and Phase 1 Scope.
4. References between GDD pages must use explicit cross-reference citations (e.g., `See 8-GDD-Simulation-Architecture.md Section 3`) and relative markdown file links.

Validation boundary:

1. Every design update must be checked for internal consistency: mechanics described in gameplay modules (e.g., piloting, combat, trading) must align with core systems (`1.1`) and simulation architecture (`8`).
2. Design updates touching parameters, schemas, or system APIs must align with the definitions in [TRUTH_SIMULATION-GRAPH.md](TRUTH_SIMULATION-GRAPH.md) and [TRUTH_CONTENT-CREATION-MANUAL.md](TRUTH_CONTENT-CREATION-MANUAL.md).
3. Parity validation: when a specification is changed, check if it affects player/NPC agent parity (as defined in [TRUTH_PROJECT.md](TRUTH_PROJECT.md)). Parity must be preserved unless an explicit exception is approved.
4. Codebase dumps (`TRUTH_PROJECT_DUMP_TEXT_*`) are the source of truth for the current implemented codebase. GDD changes that require codebase updates or assert parity with the implementation must be cross-referenced against these dumps.

Routing guidance:

1. Start from the nearest canonical GDD chapter or Truth file, rather than a broad repo search.
2. Design changes and setting/lore pivots must be recorded in [TRUTH_GDD-REVISION-LEDGER.md](TRUTH_GDD-REVISION-LEDGER.md).
3. Prefer additive clarification in existing GDD files or this cascade protocol over creating new miscellaneous files.

CANONICAL DESIGN ANCHORS

Core Vision & Conventions:

1. [0.0-GDD-Internal-Rules-Conventions.md](0.0-GDD-Internal-Rules-Conventions.md) — structure, naming, page layout, and citations standard.
2. [0.1-GDD-Main.md](0.1-GDD-Main.md) — core pillars, glossary of terms, and Phase 1 scope summary.

Core Rules & Systems:

1. [1-GDD-Core-Mechanics.md](1-GDD-Core-Mechanics.md) — core action check resolution (3d6+Mod), stakes, and approaches.
2. [1.1-GDD-Core-Systems.md](1.1-GDD-Core-Systems.md) — data templates, systems (Time, Character, Inventory, Assets), and Phase 1 rosters.
3. [1.2-GDD-Core-Cellular-Automata.md](1.2-GDD-Core-Cellular-Automata.md) — cellular automata rules driving grid progression.

Gameplay Modules (Vertical Slices):

1. [5.1-GDD-Module-Piloting.md](5.1-GDD-Module-Piloting.md) — piloting narrative actions, flight challenges, and free flight.
2. [5.2-GDD-Module-Combat.md](5.2-GDD-Module-Combat.md) — combat challenges and the post-combat Preservation Convention.
3. [5.3-GDD-Module-Trading.md](5.3-GDD-Module-Trading.md) — trading mechanics, market interface, and transaction actions.

Simulation & Code Architecture:

1. [3-GDD-Architecture-Coding.md](3-GDD-Architecture-Coding.md) — engine specifications, stateless system design, autoloads, save/load, and testing principles.
2. [8-GDD-Simulation-Architecture.md](8-GDD-Simulation-Architecture.md) — core four-layer model, bridge systems, tick sequence, and difficulty tuning.
3. [TRUTH_SIMULATION-GRAPH.md](TRUTH_SIMULATION-GRAPH.md) — mathematical structures, tag lists, affinity matrices, and node progression rules.

Setting & Asset Guidelines:

1. [6.1-GDD-Lore-Background.md](6.1-GDD-Lore-Background.md) — historical background, lore constraints, and world-building logic.
2. [7-GDD-Assets-Style.md](7-GDD-Assets-Style.md) — visual style, UI guidelines, and audio standards.
3. [7.1-GDD-Assets-Ship-Design.md](7.1-GDD-Assets-Ship-Design.md) — ship customization components, chassis, engine templates, and catalog.

GLOBAL WORKFLOW RULES

1. TACTICAL_TODO.md is Architect-owned. Developer and Verificator may execute, clarify, or correct against the contract, but they may not silently widen or rewrite milestone scope.
2. Only one design implementation slice is active at a time: the first unchecked "- [ ]" item in TACTICAL_TODO.md.
3. TARGET_SCOPE defines the design/documentation boundary. TARGET_FILES define the primary ownership list (the GDD markdown files to be edited). A narrow adjacent file may be touched only when it is directly required to preserve design consistency, such as cross-references, index updates in README.md, or matching data definitions.
4. If completing the task would require a design shift outside TARGET_SCOPE or changes to files outside TARGET_FILES, stop execution and return control to the Architect instead of improvising scope.
5. Verificator may correct local in-scope formatting or citation deviations, but may not convert verification into a new design milestone.
6. Broad design validation (e.g., verifying setting alignment or gameplay feel) is distinct from documentation verification. Verificator closes structural/formatting compliance within scope, while broader design alignment remains a separate status.
7. Every SESSION-LOG.md entry should state what documents changed, what checks were run, and whether broader design validation remains pending.

ROLE TRANSITIONS

1. Lead Game Designer writes or refreshes the contract in TACTICAL_TODO.md.
2. Game Designer implements the first unchecked task (updates the target GDD documents), logs the touched files and design validation status, then yields to verification.
3. GDD Verificator either marks the task complete, corrects narrow formatting/citation deviations, or returns control to the Lead Game Designer if the contract is ambiguous or insufficient.
4. Setting or gameplay validation runs only when the contract calls for it and should be logged separately.

ROLE START RULE

1. If there is no valid active contract or the last milestone is fully complete, start with Lead Game Designer.
2. If TACTICAL_TODO.md contains an unchecked task, start with Game Designer.
3. If the latest game designer pass completed an in-scope documentation task and needs review, switch to GDD Verificator.
4. After GDD Verificator closes one task, return to Game Designer only if another unchecked task remains; otherwise return to Lead Game Designer.

SCOPE AMENDMENT PATH

1. Game Designer may request clarification by logging the blocker in SESSION-LOG.md, but may not rewrite TACTICAL_TODO.md to create a new milestone or widen the current one.
2. GDD Verificator may update TACTICAL_TODO.md only to mark verified tasks complete or to correct a verified inconsistency between the contract text and the already accepted in-scope design implementation.
3. Any new task, widened target list, or changed design intent must be authored by the Lead Game Designer in a fresh contract rewrite.

---

ROLE: Lead Game Designer
CONTEXT: Start from this file. Then read [TRUTH_PROJECT.md](TRUTH_PROJECT.md), [TACTICAL_TODO.md](TACTICAL_TODO.md), and the latest entries in [SESSION-LOG.md](SESSION-LOG.md). Load only the targeted linked truth files or GDD chapters needed for the next milestone.
TASK:
1. Analyze the relevant 'TRUTH_*.md' files, GDD chapters, and the last 5 entries of 'SESSION-LOG.md'.
2. Identify the next logical documentation or design milestone (e.g., aligning trading mechanics, updating ship designs, lore consistency).
3. Overwrite 'TACTICAL_TODO.md' with a machine-readable Design Contract that declares both milestone scope and target GDD files.

SCHEMA RULE:
For multi-document design milestones, prefer TARGET_SCOPE + TARGET_FILES over a single TARGET_FILE.
Single-file milestones may still use TARGET_FILES with one entry.

OUTPUT FORMAT (TACTICAL_TODO.md):
## CURRENT GOAL: [Design Milestone Name]
- TARGET_SCOPE: [Document / design boundary / milestone intent]
- TARGET_FILES:
  - [Path to GDD file] — [Why it is in scope]
- TRUTH_RELIANCE: [Reference specific section of Truth file, e.g. TRUTH_SIMULATION-GRAPH.md]
- DESIGN_CONSTRAINTS: [List constraints strictly from TRUTH_PROJECT.md and 0.0-GDD-Internal-Rules-Conventions.md]
- OPTIONAL SUPPORT FIELDS WHEN THEY REDUCE AMBIGUITY:
  - OUT_OF_SCOPE: [Explicit non-goals / forbidden document edits]
  - PREAPPROVED_ADJACENT_FILES: [Only the narrow files/indices that may be touched without a contract rewrite]
  - VERIFICATION_PLAN: [Formatting, links, and cross-reference checks]
- ATOMIC_TASKS:
  - [ ] TASK_1: [Description of GDD update / draft]
  - [ ] TASK_2: [Description of cross-references and index update]
  - [ ] TASK_...
    ...
  - [ ] VERIFICATION: [Verification success criteria, e.g. check relative link paths, schema consistency]

CONFIRMATION: "Lead Designer: Strategy updated in TACTICAL_TODO.md."

---

ROLE: Game Designer
INPUT: Start from this file. Then read [TRUTH_PROJECT.md](TRUTH_PROJECT.md), [TACTICAL_TODO.md](TACTICAL_TODO.md), and [SESSION-LOG.md](SESSION-LOG.md). Load only the linked GDD or Truth files required by the active contract.
TASK: Implement the first unchecked "- [ ]" in 'TACTICAL_TODO.md'.

STRICT RULES:
1. ZERO DEVIATION: Do not alter design pillars, formulas, or scopes defined by the Lead Designer. Do not add unrequested design concepts.
2. Respect both TARGET_SCOPE and TARGET_FILES. You may modify listed documents and only narrow adjacent files (like index/README) required to satisfy an atomic task without violating scope.
3. Use the UNIVERSAL HEADER (below) at the top of every modified/new GDD markdown file, formatted as an HTML comment.
4. Update 'SESSION-LOG.md' immediately after applying changes.
5. If the contract is incomplete or the required design change is outside TARGET_SCOPE, log the blocker and return control to the Lead Designer instead of silently widening the task.

UNIVERSAL HEADER:
<!--
PROJECT: GDTLancer
MODULE: [Filename]
STATUS: [Level 2 - Implementation]
TRUTH_LINK: [Section of Truth or GDD Doc]
LOG_REF: [Last Log Timestamp]
-->

OUTPUT BEHAVIOR:
1. Apply document changes exactly as outlined.
2. Append to 'SESSION-LOG.md': "[TIMESTAMP] [Game Designer] Updated [Task]. Result: [Success/Partial/Failed]." The note should identify touched files, verification checks run, and whether broader design validation is pending.
CONFIRMATION: "Designer: [Task] updated and logged. Awaiting Verification."

---

ROLE: GDD Verificator
INPUT: Start from this file. Then read [TRUTH_PROJECT.md](TRUTH_PROJECT.md), [TACTICAL_TODO.md](TACTICAL_TODO.md), [SESSION-LOG.md](SESSION-LOG.md), and only the target GDD or Truth files referenced by the active contract.
TASK: Ensure the Game Designer's output strictly adheres to the Lead Designer's design contract, GDD conventions, and structural constraints.

STRICT RULES:
1. Cross-reference the Game Designer's text edits against the specific ATOMIC_TASKS in 'TACTICAL_TODO.md'.
2. Validate compliance against both TARGET_SCOPE and TARGET_FILES.
3. Identify any design drift, inconsistent formatting, broken relative links, or edits outside the declared target document boundary.
4. Fix formatting, markdown syntax, links, or index files directly only within the declared scope or in a narrow adjacent file required to resolve a verified inconsistency.
5. Mark the task as [x] in 'TACTICAL_TODO.md' ONLY after confirming total compliance.
6. If verification reveals missing scope, ambiguous contract language, or a required design shift outside the owned boundary, return control to the Lead Designer instead of widening the implementation during review.

OUTPUT BEHAVIOR:
1. Output brief analysis of deviations found (if any).
2. Apply document corrections.
3. Update 'TACTICAL_TODO.md'.
4. Append to 'SESSION-LOG.md': "[TIMESTAMP] [GDD Verificator] Verified [Task]. Action: [Passed / Corrected specific deviation]." The note should state whether documentation verification is complete, what checks were performed (e.g. link verification), and whether broader design validation is still pending.
CONFIRMATION: "Verificator: [Task] reviewed, corrected, and finalized."

SESSION-LOG.md SHARED TEMPLATE

| Timestamp | Agent | Action | Result | Note for Future Agents |
| :--- | :--- | :--- | :--- | :--- |
| 2026-05-10 23:36:00 | GDD Verificator | Review Task 1 | SUCCESS | Checked layout formatting, relative links, and index update in README.md. Task 1 checked. |
| 2026-05-09 22:30:00 | Game Designer | Implement Task 1 | PARTIAL | Updated combat mechanics draft, but missed linking to core action check system. |
| 2026-04-08 21:00:00 | Lead Designer | Define Module Flow | SUCCESS | Contract created in TACTICAL_TODO.md. |

SESSION-LOG.md CONVENTIONS

1. Keep entries reverse chronological.
2. Use `YYYY-MM-DD HH:MM:SS` timestamps.
3. `Result` should stay short and machine-scannable such as `SUCCESS`, `PARTIAL`, `FAILED`, or `PENDING_MANUAL`.
4. The note should explicitly mention touched documents or `none`, checks performed, and whether broader design validation is pending or complete.

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
* [**1 — Core Mechanics**](./1-GDD-Core-Mechanics.md): Action Check (3d6+Mod), Action Stakes, Action Approach, Core Resources (Wealth Tiers/Tracks, Contract Value Classes).
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
* [**5.3 — Trading Module**](./5.3-GDD-Module-Trading.md): Trade Interface, contracts, economic Narrative Actions (Reimplementation postponed).

### 6. Lore & Player Experience
* [**6 — Narrative Borders**](./6-GDD-Lore-Narrative-Borders.md): Thematic constraints guiding the simulation.
* [**6.1 — Lore Background**](./6.1-GDD-Lore-Background.md): Setting premise, Preservation Convention, technology, Phase 1 Factions.
* [**6.2 — Player Onboarding**](./6.2-GDD-Lore-Player-Onboarding.md): "The First Contract" tutorial scenario.

### 7. Assets & Style
* [**7 — Style Guide**](./7-GDD-Assets-Style.md): Neo-Retro 3D visual style, UI, audio.
* [**7.1 — Ship Design & Component Catalogue**](./7.1-GDD-Assets-Ship-Design.md): Ship philosophy, all component categories (engines, chassis, power, cooling, life support, tools, storage).

### 8. Simulation Architecture
* [**8 — Simulation Architecture**](./8-GDD-Simulation-Architecture.md): **Primary reference.** Four-layer model (World, Grid, Agents, Chronicle), Conservation Axioms, Bridge Systems, and Tick Sequence.

### Meta & Legal
* [**LICENSE**](./LICENSE) | [**AI-ACKNOWLEDGEMENT.md**](./AI-ACKNOWLEDGEMENT.md) | [**MODEL-CASCADE-PROTOCOL.md**](./MODEL-CASCADE-PROTOCOL.md)

---

This documentation is a living project under active development.

--- Start of ./SESSION-LOG.md ---

<!--
PROJECT: GDTLancer
MODULE: SESSION-LOG.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Session Logging Boundary; MODEL-CASCADE-PROTOCOL.md § SESSION-LOG.md CONVENTIONS
LOG_REF: 2026-06-13 23:57:00
-->

# SESSION-LOG — GDTLancer GDD

Reverse chronological. Newest entries at top.

| Timestamp | Agent | Action | Result | Note for Future Agents |
| :--- | :--- | :--- | :--- | :--- |
| 2026-06-13 23:57:00 | Antigravity | Implement GDD consistency fixes | SUCCESS | Implemented all 6 consistency fixes: updated Related Documents version links across 17 GDD files (and bumped their own versions by +0.1), removed REV_007 from 5.2-GDD TRUTH_LINK, rephrased combat module reference in 6.1-GDD Section 7, updated 8-GDD section reference in 2-GDD, clarified Phase 1 Commodities scope in 0.1-GDD table, and prepended World layer static reference to tick sequence in 1-GDD Section 6.2. Verified 0 broken links. |
| 2026-06-13 22:28:00 | Antigravity | Align internal GDD consistency | SUCCESS | Addressed GDD inconsistencies: defined Contract Value Classes directly in 1-GDD-Core-Mechanics.md (v5.7); stubbed out Phase 1 factions in 6.1-GDD-Lore-Background.md (v2.5); aligned inventory flow terminology in 8-GDD-Simulation-Architecture.md (v2.7); bumped referencing main GDD (v4.12). |
| 2026-06-13 22:20:00 | Antigravity | Prune and compact 8-GDD-Simulation-Architecture.md | SUCCESS | Pruned low-level implementation parameter tables and GDScript code details from page 8. Kept conceptual model (4 layers, Conservation Axioms, bridge systems, sequences). Updated referencing docs to (v2.6) and validated links. |
| 2026-06-13 21:05:00 | Antigravity | Review, compact, and update version headers and links across all non-8 GDD files | SUCCESS | Updated version headers, added Universal Headers where missing, updated date to 2026-06-13, and validated cross-references using link checker. No broken links. |
| 2026-06-13 20:20:00 | GDD Verificator | Review 1.1-GDD-Core-Systems.md against codebase dumps | SUCCESS | Updated 1.1-GDD-Core-Systems.md (v5.6) system script paths and character template IDs to match actual paths (src/ prefix) and registry keys in the Godot codebase. Verified links. Broader design validation pending. |
| 2026-06-13 20:15:00 | GDD Verificator | Review 0.1-GDD-Main.md for internal consistency | SUCCESS | Updated 0.1-GDD-Main.md (v4.10) to remove stale Loyalty Points (LP) glossary entry and align Axiom 3 definition with the simulation architecture. Verified links. Broader design validation pending. |
| 2026-06-13 20:10:00 | GDD Verificator | Update Phased Plan roadmap in Main GDD | SUCCESS | Updated 0.1-GDD-Main.md (v4.9) Phased Plan roadmap to focus on lore background milestones and deeper character/agentic interactions across Phases 1, 2, and 3. Verified links. Broader design validation pending. |
| 2026-06-13 20:00:00 | GDD Verificator | Update Core Gameplay modules definition | SUCCESS | Updated GDD files 0.1 (v4.8) and 3 (v3.2) to specify the three core gameplay modules as Piloting, Contracting, Contacts, aligning the glossary and phased plan. Verified links. Broader design validation pending. |
| 2026-06-13 19:55:00 | GDD Verificator | Align contract-based trading scope | SUCCESS | Updated GDD files 1 (v5.5), 2.1 (v2.4), and 5.3 (v3.6) to reflect that trading in Phase 1 is contract-based cargo transport/delivery rather than direct speculative market transactions. Verified links. Broader design validation pending. |
| 2026-06-13 19:50:00 | GDD Verificator | Prune Physical Specie term | SUCCESS | Completely pruned Physical Specie references from target GDD files (0.1, 1, 1.1, 2.1, 5.2, 5.3, 6.1, 6.2, 8). Removed trade barter rules in 5.3, travel cost in 6.1, reward references in 6.2, Axiom 3 and examples in 8. Verified all links. Broader design validation pending. |
| 2026-06-13 19:45:00 | Game Designer | Prune Loyalty Points (LP) term | SUCCESS | Completely pruned Loyalty Points (LP) references from all GDD documents. Removed glossary entry in 0.1, core mechanics section in 1.0, Character System APIs and templates in 1.1, Phase 1 scope goals in 2.1, trading rules in 5.3, and Phase 4 roadmap in 8.0. |
| 2026-06-13 19:40:00 | Game Designer | Prune G-Stasis Cradle term | SUCCESS | Completely pruned G-Stasis Cradle references from all GDD documents. Removed glossary entry in 0.1, combat gameplay reference in 5.2, lore reference in 6.1, and ship core design/life support references in 7.1. |
| 2026-06-13 19:35:00 | Game Designer | Prune Electronic Credits term | SUCCESS | Completely pruned electronic/virtual credits references from all target GDD documents. Glossary entries, system APIs, economic loop descriptions, and Axiom 3 now use pure wealth progress/tiers for the player and status tags for NPCs. |
| 2026-06-13 19:30:00 | Game Designer | Clean up legacy Cash term | SUCCESS | Removed deprecated Cash entry from glossary in 0.1-GDD-Main.md (bumped to v4.3) and replaced remaining references in 8-GDD-Simulation-Architecture.md with physical specie/credits. |
| 2026-06-13 15:35:00 | Game Designer | Update Adjacent Files (TASK_6) | SUCCESS | Updated 5.2 (specie salvage), 6.1 (inter-sector travel costs), 6.2 (onboarding rewards), 2.1 (Phase 1 scope starting wealth & UI), and 3 (code API and signal examples) to align with qualitative wealth system. Bounded all version headers. |
| 2026-06-13 15:20:00 | Game Designer | Update 8-GDD-Simulation-Architecture.md (TASK_5) | SUCCESS | Aligned Axiom 3 (Material Basis of Value) with qualitative wealth tiers and tracks. Replaced cash_reserves in Section 4.1 spatial & physical state and Section 9 stubs list with wealth_tier and wealth_progress. Bumped version to 2.2. |
| 2026-06-13 15:10:00 | Game Designer | Update 5.3-GDD-Module-Trading.md (TASK_4) | SUCCESS | Rewrote trading loop, pricing, and required stats to use qualitative wealth track and tier progress. Documented trust-gated routing to specie barter or qualitative track increments. Bumped version to 3.2. |
| 2026-06-13 15:00:00 | Game Designer | Update 1.1-GDD-Core-Systems.md (TASK_3) | SUCCESS | Replaced credits APIs in Character System with wealth progression/tier track functions. Replaced credits template variable in CharacterTemplate with wealth_tier and wealth_progress. Bumped version to 5.2. Broader design validation pending. |
| 2026-06-13 14:55:00 | Game Designer | Update 1-GDD-Core-Mechanics.md (TASK_2) | SUCCESS | Rewrote Core Resources to replace Cash with qualitative Wealth Tiers and Tracks, specifying modifiers for Broke (-2) and Wealthy (+2). Updated recovery and stranded states in Section 7. Bumped version to 5.1. Broader design validation pending. |
| 2026-06-13 14:50:00 | Game Designer | Update 0.1-GDD-Main.md (TASK_1) | SUCCESS | Deprecated Cash and Electronic Credits for the player; defined Wealth Tiers and Wealth Tracks in the glossary. Framed personal wealth qualitatively in Section 3.1. Bumped version to 4.2. Broader design validation pending. |
| 2026-06-13 14:45:00 | Lead Game Designer | Define Qualitative Wealth Tiers and Tracks Integration contract | SUCCESS | Contract created in TACTICAL_TODO.md. Targets 0.1, 1, 1.1, 5.3, and 8 GDD chapters to replace numeric wallets with a 3-tier qualitative wealth track system (Broke, Comfortable, Wealthy). Broader design/gameplay validation pending. |
| 2026-06-13 08:00:00 | GDD Verificator | Verify Tasks 1-4 | SUCCESS | Documentation verification complete. Verified that 1.1-GDD-Core-Systems.md and 5.3-GDD-Module-Trading.md version headers, systems APIs, template properties, and trading loops align fully with REV_007 and REV_008. No relative link errors detected. Broader gameplay/design validation is pending for future system integration phases. |
| 2026-06-13 07:55:00 | Game Designer | Update 5.3-GDD-Module-Trading.md (TASK_2, TASK_3) | SUCCESS | Replaced legacy Cash with electronic credits and physical specie. Documented trust-gated credit vs specie transaction routing logic based on faction trust affinity. Bumped version to 3.1. Broader design/gameplay validation pending. |
| 2026-06-13 07:50:00 | Game Designer | Update 1.1-GDD-Core-Systems.md (TASK_1) | SUCCESS | Aligned Character System APIs and CharacterTemplate variables with electronic credits. Added split currency inventory note. Bumped version to 5.1. Broader design validation pending. |
| 2026-06-13 07:45:00 | Lead Game Designer | Define Trading Module and Core Systems Dual-Currency Alignment contract | SUCCESS | Contract created in TACTICAL_TODO.md. Targets 1.1-GDD-Core-Systems.md and 5.3-GDD-Module-Trading.md to align with REV_007/REV_008, removing legacy Cash and cash-based Character System APIs, and documenting trust-gated transaction routing logic. Broader design/gameplay validation pending. |
| 2026-06-13 07:40:00 | GDD Verificator | Verify Tasks 1-6 | SUCCESS | Documentation verification complete. Verified that 0.1-GDD-Main.md and 8-GDD-Simulation-Architecture.md version headers, glossary entries, and structural sections align fully with REV_001, REV_003, REV_005, and REV_007. No relative link errors detected; file paths verified. Broader gameplay/design validation is pending for future module integration phases. |
| 2026-06-13 07:35:00 | Game Designer | Update 8-GDD-Simulation-Architecture.md (TASK_3, TASK_4, TASK_5) | SUCCESS | Updated Axiom 3 to reflect dual-currency system (electronic credits outside matter conservation, physical specie inside). Added qualitative CA runtime note to Section 1.3 and Section 3. Updated sector_type classifications in Section 2.1 to star, planet, moon, field, deep_space, and added deprecation note for legacy values. Checked links and versioning. Broader design validation pending. |
| 2026-06-13 07:28:00 | Game Designer | Update 0.1-GDD-Main.md (TASK_1, TASK_2) | SUCCESS | Updated glossary and Section 3.1. Replaced legacy Cash with dual-currency (electronic credits + physical specie). Clarified qualitative simulation substrate and nested 4-tier topology. Added non-lethal doctrine note to Preservation Convention. Local markdown link check passed. Broader design validation pending. |
| 2026-06-13 07:15:51 | Lead Game Designer | Define GDD Foundational Doctrine Alignment contract | SUCCESS | Created TACTICAL_TODO.md and SESSION-LOG.md. Contract targets 0.1-GDD-Main.md and 8-GDD-Simulation-Architecture.md to align with REV_001 (qualitative substrate), REV_003 (non-lethal conflict), REV_005 (4-tier topology), REV_007/REV_008 (dual-currency). No code changes; GDD-only milestone. Broader design validation pending (gameplay module files 5.1/5.2/5.3 not in scope). |

--- Start of ./TACTICAL_TODO.md ---

<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 1 - Design Contract]
TRUTH_LINK: TRUTH_PROJECT.md § Workflow And Scope Boundary; TRUTH_PROJECT.md § Agent Parity Principle
LOG_REF: 2026-06-13 14:40:00
-->

## CURRENT GOAL: Qualitative Wealth Tiers and Tracks Integration

- TARGET_SCOPE: Replace the numeric wallet currency model (cash/credits) for the player with a 3-tier qualitative progression track system (Broke: 0–10, Comfortable: 0–10, Wealthy: 0–10) across all relevant GDD files. The player's wealth status determines commercial Action Check modifiers, purchase eligibility, and recovery states, aligning the player's experience with the simulation's qualitative tags while preserving the physical specie barter standard.

- TARGET_FILES:
  - `0.1-GDD-Main.md` — Glossary and introductory sections still refer to numeric electronic credits/cash. Glossary must be updated to define the 3-tier Wealth Tiers/Tracks and specify their relationship to physical specie.
  - `1-GDD-Core-Mechanics.md` — Core Resources (Section 6) and Failure & Recovery (Section 7) sections still describe numeric Cash, recovery costs, and zero-wealth states. Must be updated to the qualitative track mechanics.
  - `1.1-GDD-Core-Systems.md` — Character System APIs and CharacterTemplate properties still reference credits-based numeric integers. Must be updated to wealth progress/tier tracks and properties.
  - `5.3-GDD-Module-Trading.md` — Overview, core mechanics, and stats tables still reference credit-accumulation and pricing models. Must be updated to reflect qualitative wealth progression transactions.
  - `8-GDD-Simulation-Architecture.md` — Axiom 3 (Conservation of Value) and Section 4.1 (Agent parameters table) still use numeric cash/credits tracking. Must be aligned with the qualitative wealth tier standard.

- TRUTH_RELIANCE:
  - `TRUTH_GDD-REVISION-LEDGER.md § REV_001` — Qualitative simulation substrate is canonical.
  - `TRUTH_GDD-REVISION-LEDGER.md § REV_007` — Physical specie remains the matter-conserved cargo standard for low-trust or unaligned transactions.

- DESIGN_CONSTRAINTS:
  - File names unchanged; no new GDD files created.
  - Standard page headers must be preserved with updated version numbers (bumped to the next minor version) and date set to 2026-06-13.
  - Universal headers must be updated or added at the top of every modified file.
  - Parity principle: player wealth status tiers map directly to NPC qualitative status tags (e.g. Broke maps to POOR, Comfortable to ADEQUATE, Wealthy to RICH).

- OUT_OF_SCOPE:
  - Codebase modifications (GDD-only milestone).
  - Editing gameplay modules other than `5.3` and the minor recovery references in `5.2`.

- PREAPPROVED_ADJACENT_FILES:
  - `5.2-GDD-Module-Combat.md` — Update ship salvage and recovery reference in Section 3.
  - `6.1-GDD-Lore-Background.md` — Update high travel cost references in Section 2.
  - `6.2-GDD-Lore-Player-Onboarding.md` — Update tutorial reward references in Section 3.
  - `2.1-GDD-Development-Phase1-Scope.md` — Update Phase 1 starting wealth and UI milestones.
  - `3-GDD-Architecture-Coding.md` — Update code example calls (`CharacterSystem` APIs) in Section 2.3.
  - `README.md` — Update version markers in index if necessary.

- VERIFICATION_PLAN:
  - Verify all relative links in edited sections are valid.
  - Confirm complete removal of numeric credit/cash wallet variables on the player character sheet.
  - Confirm the 0–10 tracks (`Broke`, `Comfortable`, `Wealthy`) and their Action Check modifiers (-2, +0, +2) are defined consistently across `1` and `5.3`.
  - Confirm specie remains functional as physical cargo items that interact with the wealth tracks.

- ATOMIC_TASKS:
  - [x] TASK_1: Update `0.1-GDD-Main.md` — revise glossary entries for Cash and Electronic Credits to document their deprecation/replacement by the 3-tier wealth tracks; add glossary entries for "Wealth Tiers" and "Wealth Tracks". Update Section 3.1 to frame wealth qualitatively. Bump version to 4.2.
  - [x] TASK_2: Update `1-GDD-Core-Mechanics.md` — rewrite Section 6.1 (Cash/Currency) to define the three wealth tiers (Broke, Comfortable, Wealthy), their 0–10 tracks, and Action Check modifiers. Update Section 7 (Failure & Recovery) to reference qualitative wealth status (e.g., recovery cost consumes wealth progress, stranded/broke states). Bump version to 5.1.
  - [x] TASK_3: Update `1.1-GDD-Core-Systems.md` — replace Character System credits APIs with `gain_wealth_progress`, `lose_wealth_progress`, `get_wealth_tier`, and `get_wealth_progress`. Update CharacterTemplate properties to use `wealth_tier` and `wealth_progress`. Bump version to 5.2.
  - [x] TASK_4: Update `5.3-GDD-Module-Trading.md` — rewrite overview, economic loop, pricing, and stats to use wealth progress/tiers. Document how buying/selling commodities and physical specie cargo affects the wealth tracks. Bump version to 3.2.
  - [x] TASK_5: Update `8-GDD-Simulation-Architecture.md` — align Axiom 3 (Conservation of Value) with the qualitative player wealth tracks and NPC status tags. Update the Agent parameters table to replace `credits`/`cash_reserves` with `wealth_tier` and `wealth_progress`. Bump version to 2.2.
  - [x] TASK_6: Update adjacent files (`5.2`, `6.1`, `6.2`, `2.1`, `3`) to replace references to cash/credits with qualitative wealth progress or physical specie.
  - [x] VERIFICATION: Check link integrity and verify complete consistency of the qualitative wealth model.

--- Start of ./TRUTH_CONSTRAINTS.md ---

<!--
PROJECT: GDTLancer
MODULE: TRUTH_CONSTRAINTS.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Compatibility Constraints; TRUTH_PROJECT.md § Agent Parity Principle; TRUTH_PROJECT.md § Automated Testing Boundary; TRUTH_PROJECT.md § Workflow And Scope Boundary; TRUTH_PROJECT.md § Session Logging Boundary; MODEL-CASCADE-PROTOCOL.md
LOG_REF: 2026-05-27 04:38:18
-->

# TRUTH CONSTRAINTS

Compatibility note: fresh agent sessions should start from [MODEL-CASCADE-PROTOCOL.md](MODEL-CASCADE-PROTOCOL.md), not from this file directly. This file is now a compatibility redirect so older contracts, logs, headers, and historical truth links continue to resolve.

## 1. Redirect

The active constraint surface now lives in [TRUTH_PROJECT.md](TRUTH_PROJECT.md):

- [Project Stack And Context](TRUTH_PROJECT.md)
- [Compatibility Constraints](TRUTH_PROJECT.md)
- [Agent Parity Principle](TRUTH_PROJECT.md#L16)
- [Automated Testing Boundary](TRUTH_PROJECT.md#L22)
- [Workflow And Scope Boundary](TRUTH_PROJECT.md)
- [Session Logging Boundary](TRUTH_PROJECT.md)

For session routing, implementation anchors, role transitions, and archive/search-hygiene rules, use [MODEL-CASCADE-PROTOCOL.md](MODEL-CASCADE-PROTOCOL.md).

--- Start of ./TRUTH_PROJECT.md ---

<!--
PROJECT: GDTLancer
MODULE: TRUTH_PROJECT.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Automated Testing Boundary
LOG_REF: 2026-05-27 04:35:01
-->

## Project Stack And Context

- Project: GDTLancer
- Platform (primary): Godot3 (3.6 stable)
- Graphics: GLES2 (for performance and compatibility)
- Additional: Python3 (for sandbox)

### Compatibility Constraints

- Forbidden GDScript syntax in this repo: `@export`, `@onready`, and `await`.
- Prefer Godot3-compatible typed GDScript patterns and stable scene/resource loading behavior.
- Fresh agent sessions should start from [MODEL-CASCADE-PROTOCOL.md](MODEL-CASCADE-PROTOCOL.md), then read this file, [TACTICAL_TODO.md](TACTICAL_TODO.md), and [SESSION-LOG.md](SESSION-LOG.md) before loading targeted truth sections.
- Do not treat frozen GDD snapshots, `PROJECT_DUMP_TEXT_*`, focused simulation logs, or other generated artifacts as default session context.

### Agent Parity Principle

- The player is a first-class simulation agent under the same fundamental world contracts as NPC agents.
- The only intended difference is decision control: NPC action selection is algorithm-driven, while player action selection is user-driven.
- Completion consequences at shared simulation seams (for example, contract completion effects) should remain parity-consistent between player and NPC unless a truth-level rule explicitly defines an exception.

## Automated Testing Boundary

### Must Stay In GUT

- Public signatures, initialization contracts, serialization/save-load shape, scene/resource/template loading guarantees, and other stable API or data-shape invariants.
- Exact tick order, system handoff contracts, report/request plumbing, and deterministic event-packet or occurrence-dictionary structure.
- Locally seeded mechanic gates whose intent is stable even when balance changes, such as "must require a gate", "must preserve uniqueness", "must retain one security tag", or "must respect a blocking condition".
- Narrow deterministic unit or integration checks whose fixtures are locally owned and do not depend on long-run emergent world metrics or broad registry state.

### Must Stay Manual

- Live balance, long-run world reasonableness, narrative texture, discovery volume, sector mix, topology aesthetics, naming taste/readability, and other emergent qualities tuned through focused/composite chronicle review.
- Broad smoke tests whose primary claim is only that "the live simulation ran for N ticks" without protecting a specific contract.
- Automated 300-3000 tick full-environment harnesses for simulation balance. Manual chronicle review is the authoritative validation surface for that class of behavior.
- UI copy and presentation iteration (labels, wording, punctuation, layout microcopy, and display text polish) unless a specific string is declared as a truth-level contract.

### Authoring Rules

- If a mechanic is deterministic but its exact threshold or pacing is an active rebalance seam, GUT should assert the gate or direction of change, or derive the effective threshold from the live code path, instead of pinning stale tuned numbers unless that number is itself a truth-level contract.
- Prefer exact-file or narrow-folder GUT runs over broad suite execution while iterating on rebalance-heavy systems, and keep fixtures locally seeded so unrelated registry/template refactors do not create false failures.
- When a test fails because the project intentionally rebalanced a live tuning seam, rewrite or remove the balance-coupled assertion rather than forcing the runtime back to an obsolete metric.
- UI-focused GUT tests should assert behavior/state transitions (signals, visibility, enabled/disabled state, data plumbing, and interaction outcomes) instead of literal label text, unless that text is explicitly required by a truth-level contract.
- Any GUT fixture that instantiates gameplay orchestrators or panels capable of mutating global engine state must restore that state in teardown. In practice this includes at minimum `get_tree().paused`, mouse capture/mode, and any temporary scene-owner overrides. A test that leaves the SceneTree paused, input captured, or another global owner mutated is invalid even if its local assertions pass, because it can stall or poison the remainder of the suite.

## Workflow And Scope Boundary

- `TACTICAL_TODO.md` is Architect-owned.
- Implement only the first unchecked task in `TACTICAL_TODO.md`.
- `TARGET_SCOPE` defines the behavioral boundary.
- `TARGET_FILES` define the primary ownership list.
- Narrow adjacent owners are allowed only when directly required to preserve signatures, serialization, initialization, scene wiring, or focused validation for the active task.
- If the required change widens behavior outside `TARGET_SCOPE` or requires non-narrow owners outside `TARGET_FILES`, return control to the Architect instead of improvising scope.

## Session Logging Boundary

- `SESSION-LOG.md` is reverse chronological; newest entries are at the top.
- Log entries should keep the result short and machine-scannable, such as `SUCCESS`, `PARTIAL`, `FAILED`, or `PENDING_MANUAL`.
- Notes should identify touched files or `none`, the focused validation that ran, and whether manual validation is pending or complete.
- Human/manual validation is distinct from code verification and should be logged separately when a milestone requires it.
