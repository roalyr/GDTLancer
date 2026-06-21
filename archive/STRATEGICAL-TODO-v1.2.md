<!--
PROJECT: GDTLancer
MODULE: STRATEGICAL-TODO.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 1–4; TRUTH_SIMULATION-GRAPH.md § 0; GDD-REVISION-LEDGER.md § Approved Revisions
LOG_REF: 2026-06-21 00:43:00
-->

# GDTLancer — Consolidated Master Design Directive

**Version:** 1.2  
**Date:** 2026-06-22  
**Status:** Draft — Revised  
**Purpose:** Unified design synthesis that (a) supersedes the frozen combined GDD text, (b) stages new GDD Revision Ledger entries, and (c) identifies specific truth file sections that must be updated or replaced to align with the live directive.

## Changelog
- **v1.2** (2026-06-22): Integrated Solo TTRPG and Emergent Narrative pivot (REV_015); removed Contract Boards; framed Morale as narrative consequence.
- **v1.1** (2026-06-20): Initial synthesis pass; added REV_009–REV_014; adopted as STRATEGICAL-TODO.md.
- **v1.0** (2026-06-20): First draft.

---

> [!IMPORTANT]
> This document is an **architect-owned staging surface**. It does not replace `TACTICAL_TODO.md` or `SESSION-LOG.md`. Individual directives become actionable only after they are promoted into the GDD Revision Ledger and wired into implementation milestones.

---

## 0. Scope & Authority

This blueprint synthesizes the core systems, universe topology, and interface framework into a unified, high-leverage development contract. It treats the digital substrate not as an open-ended world simulation, but as an **explicit, highly responsive digital board game and automated rulebook partner** that delivers a **Solo TTRPG Experience** focused on emergent narrative.

### 0.1 Relationship to Existing Truth Files

| Truth File | Relationship | Action Required | Status |
|---|---|---|---|
| [TRUTH_GAME-LOOP-VISION.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_GAME-LOOP-VISION.md) | **Superseded in part.** §1–§4 remain compatible but are narrower than this directive. | Extend with §1 (Two-Speed UX), §4 (Sub-Agent Layer), §5 (Prohibited Seams). | ✅ Done |
| [TRUTH_SIMULATION-GRAPH.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_SIMULATION-GRAPH.md) | **§0 remains authoritative.** §1–§5 are already archived. §6+ live. | Add §3 (Universe Partitioning) directives into a new topology section or as addendum to §6. | ✅ Done |
| [GDD-REVISION-LEDGER](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md) | **Extended.** New REV entries staged below. | Create new active `GDD-REVISION-LEDGER.md` with entries REV_009–REV_014. | ✅ Done |
| [TRUTH_PROJECT.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_PROJECT.md) | **Compatible.** Agent Parity Principle directly reinforced by §1.3 below. | No changes required. | ✅ Done |
| [TRUTH_CONTENT-CREATION-MANUAL.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_CONTENT-CREATION-MANUAL.md) | **Extended.** §2.3 (Hardened Content Delivery) introduces a `.tres` template directory contract. | Add content authoring section for Chronicle narrative template directory. | ✅ Done |
| [MODEL-CASCADE-PROTOCOL.md](file:///home/roalyr/Software_archive/Games/GDTLancer/MODEL-CASCADE-PROTOCOL.md) | **Compatible.** Linked read path should include this file when approved. | Add to `LINKED READ PATH` under "Load when the active task requires it". | ✅ Done |
| [Frozen GDD Combined Text](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH-GDD-COMBINED-TEXT-REVIEW-frozen-2026.06.14.md) | **Fully superseded** as design intent. Retained only as historical archive. | No changes; remains frozen. | ✅ Done |

---

## 1. Core Philosophy & Deconstructed Naivety

To prevent systemic drift into a stereotypical space sim, the project discards loose, unbounded procedural prose in favor of a **hardcoded contract between user input and systemic reaction**.

> [!NOTE]
> Cross-reference: [TRUTH_PROJECT.md § Agent Parity Principle](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_PROJECT.md#L23). The guardrails below are the mechanical expression of that principle.

### 1.1 Agency Over Stakes

The player does not possess unbounded narrative freedom; they possess **explicit choice over the stakes**. The system offers hardcoded mechanical Action Approaches (Cautious vs. Risky), while the underlying simulation layers dictate highly contextual consequences.

* **Cautious Approach:** Lower variance, constrained upside, reduced risk of catastrophic failure.
* **Risky Approach:** Higher variance, greater upside, but systemic consequences for failure amplified by current Health/Wealth/Morale state.

### 1.2 Transparent Rules Engine

The 4-layer simulation remains hidden underneath, but the **mathematical rules governing its transitions are fully exposed to the player**. The game provides explicit mechanical feedback (e.g., displaying exactly how a Wealth Tier status maps to a −2 or +2 Action Check modifier) so players can reason strategically.

* **Relates to live code:** [CoreMechanicsAPI.perform_action_check()](file:///home/roalyr/Software_archive/Games/GDTLancer/src/autoload/CoreMechanicsAPI.gd) already exposes `wealth_modifier` and `health_modifier` in its return dictionary. This directive formalizes that the UI must surface these values to the player during the Chronicle View.

### 1.3 Systemic Parity Guardrail

The player operates under **identical world mechanics** as NPC agents. If an NPC fails an action check or succumbs to local entropy, they degrade down a status tag or drop an asset exactly like the player, with the Chronicle layer resurfacing these systemic failures as localized rumors.

* **Canonical anchor:** [TRUTH_PROJECT.md § Agent Parity Principle](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_PROJECT.md#L23)
* **Live enforcement:** [agent_layer.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/simulation/agent_layer.gd) — shared player/NPC delivery logic already enforces this for contracts. This directive extends the parity requirement to all future Action Check surfaces and consequence pipelines.

---

## 2. The Two-Speed Macro UX Blueprint

The game loop transitions sequentially between two full-screen interfaces that never bleed into each other, satisfying distinct playstyles through a clear structural separation.

```
PLAYER ACTION (Intent + Approach)  ──► Choose Cautious/Risky based on visible data
               │
               ▼
THE HARD SUBSTRATE (Rules Engine)  ──► 3d6 + Mod resolves against Grid/Agent data
               │
               ▼
THE CONCRETE OUTPUT (The Log)      ──► Absolute systemic changes, framed in text
```

### 2.1 Mode A: The Kinetic Board (Tactile Simulation)

When flying, the player interacts directly with physical mechanics in a full-screen, minimalist, neo-retro 3D view.

| Aspect | Specification |
|---|---|
| **Focus** | Spatial navigation challenges, manual flight control, and direct handling of ship parameters like heat and hull tolerances. |
| **Substrate Ticks** | Every second spent drifting or boosting advances the real-time clock, firing World Event Ticks that process background CA loops and mutate Grid resource tags. The tick rate and sub-tick granularity (per-tick resolution steps) are defined in constants and can be scaled independently later. |
| **UX Contract** | Completely clean and non-intrusive telemetry. Text logs, lore descriptions, and narrative choices are **entirely suppressed** during flight to preserve kinetic momentum. |

* **Live anchor:** [simulation_engine.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/simulation/simulation_engine.gd) — owns tick order and system handoff.
* **UI anchor:** [main_hud.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/ui/main_hud/main_hud.gd) — flight HUD overlay, currently the only active Mode A surface.

### 2.2 Mode B: The Chronicle View (The Interactive Sheet)

The moment the player interacts with an NPC, docks at infrastructure, opens the character sheet, opens the star map, or triggers a post-challenge consequence choice, the 3D rendering fades entirely into a full-screen, grid-based 2D layout.

| Aspect | Specification |
|---|---|
| **Focus** | Time is **completely paused**, transforming the interface into a meditative digital board game environment focused on narrative interactions. |
| **UX Surfaces** | Chronicle Log, interaction panes, character sheets, 0–10 Wealth Track boxes, and a dedicated dice tray area (visual design deferred). **There is no Contract Board**; tasks emerge organically from dialogue and environmental events. |
| **Hardened Content Delivery** | Narrative prose is **not generated procedurally**. Context is fetched **on demand** to avoid overwhelming the player: the default context is the local sector's Grid layer tags; the player can additionally pull character context, average sub-agent crew context, or a specific individual sub-agent context when they choose to interact with that sub-agent. Each context maps to a deterministic key string that queries a static, hand-authored directory of `.tres` resource templates written in the sector's practical jargon creole. |

* **Partial live anchor:** [interaction_window.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/ui/interaction_window.gd) is the designated root holder for Mode B. It currently scaffolds station-side NPC interaction; it will be expanded into the full Chronicle View system, with all sub-panels (trade, character sheet, map, dice tray, sub-agent view) mounted within it. [npc_trade_panel.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/ui/npc_trade_panel/npc_trade_panel.gd) becomes one such sub-panel.

> [!WARNING]
> The Chronicle View is a **new major system** not yet implemented. It will require its own architecture program, milestone sequence, and truth file updates before entering active development.

---

## 3. Universe Partitioning & The Infrastructure Graph

The game map is managed as a strict **manually authored graph** where space is modeled as a series of connected operational islands, rather than a continuous, empty coordinate-based void. The space graph itself is fixed: Star → Planet → Moon. Dynamic content lives **within** each sector node, not at the graph level.

```
 [ HAND-CRAFTED GRAPH — FIXED ]
  Star ──► Planet ──► Moon
            │            │
            └── POIs      └── POIs
       (spawned within        (spawned within
        sector space)          sector space)
```

* **Cross-reference:** [GDD-REVISION-LEDGER REV_005: Hierarchical Universe Topology](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md#L72) — this directive narrows and settles the approved 4-tier hierarchy: the inter-sector graph is fully manual; exploration mechanics are deferred for later rework.

### 3.1 The Structural Equation

One sector equals exactly one dockable infrastructure node. Sectors exist exclusively around operational installations, matching a TTRPG focus where maps track only active points of interest, friction, and choices.

* **Live enforcement:** [REV_002](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md#L39) — "Near-term shipping doctrine remains one sector, one dockable or service hub."
* **Live anchor:** `world_topology[sector_id]` in [world_layer.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/simulation/world_layer.gd); `station_ids[0]` in [sector_loader.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/systems/sector_loader.gd).

### 3.2 In-Sector POI Spawning

Each sector contains sufficient playable 3D volume to host multiple Points of Interest (POIs) — derelicts, resource deposits, anomalies, temporary outposts — without requiring new nodes on the space graph. POIs are spawned within the sector's 3D space and tracked as local simulation objects rather than as first-class graph nodes.

* **Live anchor:** [location_template.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/database/definitions/location_template.gd) — canonical location/resource schema defines the sector baseline.
* **Bootstrap:** [world_generator.gd::_load_locations()](file:///home/roalyr/Software_archive/Games/GDTLancer/src/scenes/game_world/world_manager/world_generator.gd) — live bootstrap path for authored content.

> [!NOTE]
> The exploration mechanics that interact with in-sector POIs (prospecting, scanning, derelict boarding) are deferred for a dedicated later rework milestone. The graph topology itself is settled as manual.

---

## 4. The Core Agent Matrix & Sub-Agent Software

To keep implementation locked down while preserving a human-centric focus, the underlying codebase architecture enforces a strict **`Agent == Ship == Captain`** structural execution. Interpersonal depth is introduced purely via a lightweight, narrative-only **Sub-Agent Layer**.

* **Cross-reference:** [TRUTH_GAME-LOOP-VISION.md § 1.3](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_GAME-LOOP-VISION.md#L46) — Clans, Families, and Versatile Communities. This directive formalizes the implementation approach for that vision.

### 4.1 The Sub-Agent Layer

| Aspect | Specification |
|---|---|
| **Data Structure** | Basic data sub-arrays parented under primary dockable or ship-agent entities, tracking individual personnel, station populations, or crew actors. |
| **Gameplay Impact** | These actors hold no direct simulation logic, but they can be transferred between hosts. They act as narrative gatekeepers, enabling or restraining parent actions through explicit dialogue, localized approval triggers, and crew alignment checks in the 2D Chronicle menus. Future milestone: sub-agents participate on par with primary agents in the social simulation layer (relationships, knowledge graph, inter-agent trust). |
| **Implementation Constraint** | Sub-agents are **data-only** in Phase 1. They do not participate in the simulation tick, do not hold cargo, and do not resolve Action Checks independently. They modify the parent agent's Morale stat and can gate or unlock parent-level actions. Future milestone: sub-agents carry their own Health, Wealth, and Morale stats, enabling full social simulation parity. |

### 4.2 The Core Resource Matrix

The status of a ship-commander entity is tracked via four distinct, high-level macro categories. Each category functions as a separate systemic barrier that directly informs the character sheet and rules resolution.

| Stat Tag | Domain | Description | Live Code Anchor |
|---|---|---|---|
| **Health** | Hardware | Physical hull integrity and bridge system structural tolerances. | `condition_tag` in agent state; `CONDITION_MODIFIERS` in [Constants.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/autoload/Constants.gd) |
| **Wealth** | Leverage | Qualitative 3-tier standing (Broke, Comfortable, Wealthy) that determines transaction trust and commercial modifiers. | `WEALTH_TIERS`, `WEALTH_MODIFIERS` in [Constants.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/autoload/Constants.gd); [character_system.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/systems/character_system.gd) |
| **Supplies** | Logistics | The overarching category for all operational and survival consumables (propellant, life support packings, ammo, and components). | Partially modeled via cargo tags; requires formalization. |
| **Morale** | Human | Tracks the psychological alignment, crew fatigue, and structural authority of the sub-agent community aboard the machine. Tracked as individual values per sub-agent, with an average Morale score aggregated at the ship or station level and used as the Action Check modifier. | **Not yet implemented.** New system required. |

### 4.3 The Morale Mechanical Loop

Morale tracks the human software. It cannot be directly bought with Wealth or patched with Supplies. Each sub-agent carries an individual Morale value; the ship or station aggregates these into an average Morale score that acts as the macro Action Check modifier for crew-dependent narrative rolls. If a captain ignores sub-agent needs or traps them in high-entropy sectors across too many World Event Ticks, individual Morale values decay and the aggregate score falls. **Morale must not be a perpetual mechanical grind. Drops in morale trigger specific narrative consequences (e.g., crew ultimatums). If the aggregate Morale drops to 0, it triggers a narrative mutiny story beat** that must be resolved, rather than a simple mechanical lock-out.

> [!IMPORTANT]
> Morale is the primary mechanical expression of [TRUTH_GAME-LOOP-VISION.md § 3.2 Defeat Conditions](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_GAME-LOOP-VISION.md#L73) — specifically "Social Ostracization" and "Community Disintegration".

---

## 5. Strict Scope Realignment: Prohibited Seams

To prevent feature creep, the following space-sim systems are **explicitly banned** from implementation.

### 5.1 No Speculative Market Displays

The player character sheet avoids tracking granular numeric ledger currency. Transaction settlement increments or decrements the qualitative 0–10 tracks based entirely on explicit Contract Value Classes.

* **Reinforces:** [REV_001 (Qualitative Simulation Substrate)](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md#L28) and [REV_007 (Dual Economy)](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md#L94).
* **Implication:** Any future UI work that surfaces trade mechanics to the player must use Wealth Track increments and Contract Value Classes, never raw credit integers.

### 5.2 No 3D On-Foot Navigation

The project completely avoids modeling 3D avatars, station interiors, or space-legs systems. All station-side community interaction and sub-agent management are executed through high-fidelity, grid-aligned 2D menus.

* **Relates to:** Mode B (Chronicle View) defined in §2.2 above.

---

## 6. Staged GDD Revision Ledger Entries

The following entries are staged for promotion into a new active `GDD-REVISION-LEDGER.md` once this directive is approved. They follow the schema established in [GDD-REVISION-LEDGER-1.md § Entry Schema](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md#L13).

- **REV_009: Two-Speed Macro UX Contract** (Promoted to ledger [x]; Implemented in code [ ] via Milestone 10)
- **REV_010: Hardened Narrative Content Delivery** (Promoted to ledger [x]; Implemented in code [x] via Milestone 11)
- **REV_011: Sub-Agent Data Layer** (Promoted to ledger [x]; Implemented in code [x] via Milestone 8)
- **REV_012: Morale Stat & Crew Morale System** (Promoted to ledger [x]; Implemented in code [ ] via Milestone 9)
- **REV_013: Manual Space Graph & In-Sector POI Doctrine** (Promoted to ledger [x]; Implemented in code [ ] via Milestone 12)
- **REV_014: Prohibited Seams Registry** (Promoted to ledger [x]; Implemented in code [ ] via Milestone 14)
- **REV_015: Solo TTRPG & Emergent Narrative Pivot** (Promoted to ledger [ ]; Implemented in code [ ] via future milestone)

---

### REV_009: Two-Speed Macro UX Contract

- **Domain:** UI/UX Architecture
- **Live Reality:** The current UI is a single-mode flight HUD with popup panels for station/NPC interaction. There is no formal mode separation, no full-screen Chronicle View, and no pause-on-interact contract.
- **Frozen / Legacy Tension:** The frozen GDD describes a modular UI but does not formalize the two-speed separation or the content delivery pipeline.
- **Approved Direction:** Formalize two mutually exclusive full-screen modes: Mode A (Kinetic Board — flight, real-time, ticking) and Mode B (Chronicle View — paused, grid-based 2D, narrative). Mode transitions are hard cuts, not overlays. Mode B pauses the simulation clock entirely.
- **Status:** Staged — pending approval
- **Blocked By:** None
- **Follow-on Owners:** Chronicle View architecture program; UI milestone sequence
- **Evidence:** This directive §2; [main_hud.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/ui/main_hud/main_hud.gd); [interaction_window.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/ui/interaction_window.gd)

---

### REV_010: Hardened Narrative Content Delivery

- **Domain:** Content Pipeline and Chronicle
- **Live Reality:** There is no narrative content delivery system. NPC interaction surfaces a trade panel with raw data. No hand-authored narrative templates exist.
- **Frozen / Legacy Tension:** The frozen GDD describes a Chronicle layer (Layer 4) for event capture and narrative, but the implementation model is unspecified.
- **Approved Direction:** Narrative prose is not procedurally generated. The local sector's Grid layer tags are combined into a deterministic key string that queries a static, hand-authored directory of `.tres` resource templates. Content is authored in the sector's practical jargon creole. This enforces authored quality and prevents LLM or procedural text generation from entering the player-facing narrative layer.
- **Status:** Staged — pending approval
- **Blocked By:** REV_009 (Chronicle View must exist before narrative delivery can be surfaced)
- **Follow-on Owners:** Content pipeline milestone; [TRUTH_CONTENT-CREATION-MANUAL.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_CONTENT-CREATION-MANUAL.md) update
- **Evidence:** This directive §2.2

---

### REV_011: Sub-Agent Data Layer

- **Domain:** Agent Architecture
- **Live Reality:** The runtime models agents as `Agent == Ship == Captain`. There is no sub-entity layer for crew, personnel, or station populations.
- **Frozen / Legacy Tension:** [TRUTH_GAME-LOOP-VISION.md § 1.3](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_GAME-LOOP-VISION.md#L46) describes "Versatile Agents" and clan/family community dynamics but provides no implementation model.
- **Approved Direction:** Introduce a data-only sub-agent layer: basic data sub-arrays parented under primary dockable or ship-agent entities. Phase 1 — sub-agents hold no simulation logic, do not participate in the tick, and cannot independently resolve Action Checks; they carry individual Morale values that are aggregated into the parent's Morale modifier. Phase 2 (future milestone) — sub-agents participate on par with primary agents in the social simulation layer (relationships, knowledge graph, inter-agent trust) and carry their own Health, Wealth, and Morale stats. Sub-agent transfers are handled through a defined API: `sub_agent_transfer(sub_agent_id, from_host_id, to_host_id)` with the sub-agent's Morale adjusted as a consequence of the transfer.
- **Status:** Staged — pending approval
- **Blocked By:** None (data layer can be scaffolded independently of UI)
- **Follow-on Owners:** Agent architecture milestone; Morale system milestone (REV_012)
- **Evidence:** This directive §4.1; [agent_layer.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/simulation/agent_layer.gd); [TRUTH_GAME-LOOP-VISION.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_GAME-LOOP-VISION.md)

---

### REV_012: Morale Stat & Crew Morale System

- **Domain:** Core Mechanics and Agent State
- **Live Reality:** The agent state tracks Health (`condition_tag`) and Wealth (`wealth_tier` + `wealth_progress`). There is no Morale or Supplies macro stat.
- **Frozen / Legacy Tension:** No prior truth file defines these stats. The frozen GDD tracks Health and Wealth only.
- **Approved Direction:** Add two new macro stat categories to the Core Resource Matrix: **Supplies** (logistics consumables as a qualitative tag, not a numeric inventory) and **Morale** (crew morale as individual per-sub-agent values aggregated to a bounded ship/station-level score). Individual Morale decays with prolonged high-entropy exposure and sub-agent neglect; the aggregate is used as the Action Check modifier. A ship/station aggregate Morale of 0 triggers mutiny or operational strike, representing a hard defeat condition. Morale decay uses a **threshold-gated step function**: individual values only decay after a configurable number of consecutive ticks above an entropy threshold, defined in `Constants.gd` alongside existing modifier dictionaries.
- **Status:** Staged — pending approval
- **Blocked By:** REV_011 (sub-agent layer must exist for Morale to have per-actor values to track)
- **Follow-on Owners:** Constants.gd extension; CoreMechanicsAPI modifier integration (same pattern as health/wealth modifiers); agent state serialization
- **Evidence:** This directive §4.2–§4.3; [Constants.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/autoload/Constants.gd) (`CONDITION_MODIFIERS`, `WEALTH_MODIFIERS` as precedent patterns)

---

### REV_013: Manual Space Graph & In-Sector POI Doctrine

- **Domain:** World Topology and Simulation
- **Live Reality:** The world graph is static after bootstrap, built from authored `location_template` resources. [REV_005](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md#L72) approved the nested 4-tier hierarchy concept.
- **Frozen / Legacy Tension:** The prior draft staged dynamic deep-space sector sprouting, but this conflicts with a clean, predictable graph and defers exploration mechanics indefinitely.
- **Approved Direction:** The inter-sector space graph is permanently **manual**: Star → Planet → Moon connections are hand-authored and do not change at runtime. Dynamic content lives **inside** each sector as in-sector POIs (derelicts, deposits, anomalies, temporary outposts) spawned within the sector's 3D volume. POIs are local simulation objects, not graph nodes. Exploration mechanics that interact with in-sector POIs are deferred for a dedicated rework milestone.
- **Status:** Staged — pending approval
- **Blocked By:** None
- **Follow-on Owners:** World topology implementation milestone; in-sector POI spawn system; exploration rework (deferred)
- **Evidence:** This directive §3; [world_layer.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/src/core/simulation/world_layer.gd); [location_template.gd](file:///home/roalyr/Software_archive/Games/GDTLancer/database/definitions/location_template.gd)

---

### REV_014: Prohibited Seams Registry

- **Domain:** Scope Control
- **Live Reality:** There is no formal registry of explicitly banned feature categories. Scope control relies on `TACTICAL_TODO.md` contract boundaries and architect judgment.
- **Frozen / Legacy Tension:** The frozen GDD includes various feature descriptions (ship modules, detailed market UIs, equipment crafting) that are now out of scope but not formally prohibited.
- **Approved Direction:** Establish a permanent, truth-level prohibited seams list. Initial entries: (1) No speculative market displays — player-facing trade uses Wealth Track increments and Contract Value Classes, never raw credit integers; (2) No 3D on-foot navigation — all station-side interaction is 2D grid-aligned Chronicle View menus. Future prohibited seams are added to this registry by architect directive only.
- **Status:** Staged — pending approval
- **Blocked By:** None
- **Follow-on Owners:** TRUTH_PROJECT.md or new TRUTH_PROHIBITED-SEAMS.md
- **Evidence:** This directive §5

---

### REV_015: Solo TTRPG & Emergent Narrative Pivot

- **Domain:** Core Gameplay Loop & UI
- **Live Reality:** Previous designs assumed "contracts" as mechanical tasks picked from a board, and morale as a numerical modifier/lockout.
- **Frozen / Legacy Tension:** The project risks feeling like a mechanical spreadsheet rather than a living world if tasks are just picked from a menu.
- **Approved Direction:** Shift fully to a Solo TTRPG experience. The environment applies pressure (via GridLayer tags), and the player defines their goals. Remove the "Contract Board" concept entirely; tasks and opportunities emerge organically from interacting with actors or reacting to environmental events. Morale drops trigger narrative consequences and story beats (e.g., mutiny standoffs) rather than flat mathematical grinding. No linear hand-crafted missions.
- **Status:** Staged — pending approval
- **Blocked By:** None
- **Follow-on Owners:** UI milestone sequence (Chronicle View); NarrativeSystem
- **Evidence:** MVP_CORE_IMPLEMENTATION_PROPOSAL.md

---

## 7. Truth File Update Plan

When this directive is approved, the following truth file updates should be executed as a single architect-owned milestone:

- [x] **7.1 Create New Active GDD-REVISION-LEDGER.md**
- [x] **7.2 Extend TRUTH_GAME-LOOP-VISION.md**
- [x] **7.3 Extend TRUTH_SIMULATION-GRAPH.md**
- [x] **7.4 Extend TRUTH_CONTENT-CREATION-MANUAL.md**
- [x] **7.5 Update MODEL-CASCADE-PROTOCOL.md**

---

### 7.1 Create New Active GDD-REVISION-LEDGER.md

- Copy archived [GDD-REVISION-LEDGER-1.md](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md) entries REV_001–REV_008 into a new root-level `GDD-REVISION-LEDGER.md`.
- Append REV_009–REV_014 from §6 above.
- Update the Follow-on Milestone Order.

### 7.2 Extend TRUTH_GAME-LOOP-VISION.md

- Add a new §5: "Two-Speed Macro UX Contract" summarizing Mode A / Mode B.
- Add a new §6: "Prohibited Seams" summarizing the banned feature list.
- Add a new §7: "Sub-Agent Layer & Morale" summarizing the crew morale system vision.

### 7.3 Extend TRUTH_SIMULATION-GRAPH.md

- Add a new section (or append to §6) documenting the Manual Space Graph doctrine and In-Sector POI Spawning as the settled topology model. Mark the former agentic-sprouting concept as **superseded**.

### 7.4 Extend TRUTH_CONTENT-CREATION-MANUAL.md

- Add a new section documenting the `.tres` narrative template directory structure, key-string generation rules, and jargon creole authoring guidelines.

### 7.5 Update MODEL-CASCADE-PROTOCOL.md

- Add `GDD-MASTER-DESIGN-DIRECTIVE.md` (or its promoted successor) to the `LINKED READ PATH` under "Read only when the active task requires it".

---

## 8. Follow-on Milestone Order (Proposed)

### Completed Milestones (Reference)

Milestones 1–6 are documented in [GDD-REVISION-LEDGER-1.md](archive/GDD-REVISION-LEDGER-1.md).  
Summary: REV_001 (Qualitative Substrate) → REV_008 (Trust-Gated Routing). All approved and implemented.

---

This extends the milestone order from [GDD-REVISION-LEDGER-1.md § Follow-on Milestone Order](file:///home/roalyr/Software_archive/Games/GDTLancer/archive/GDD-REVISION-LEDGER-1.md#L121):

| # | Done | Milestone | Depends On | REV Entry |
|---|---|---|---|---|
| 7 | [x] | Truth File Alignment Pass | Approval of this directive | All |
| 8 | [x] | Sub-Agent Data Layer Scaffold | Milestone 7 | REV_011 |
| 9 | [x] | Morale & Supplies Stat Integration | Milestone 8 | REV_012 |
| 10 | [x] | Chronicle View Architecture | Milestone 7 | REV_009 |
| L1 | [x] | Lore Conformance Gate | Milestones 8, 9, 10, 12 | NEW |
| 11 | [x] | Hardened Narrative Content Pipeline | Milestone L1, Milestone 10 | REV_010 |
| 12 | [x] | Manual Space Graph & In-Sector POI System | Milestone 7 | REV_013 |
| 13 | [x] | Hierarchical Universe Topology Formalization | Milestone L1, Milestone 12 | REV_005 |
| 14 | [x] | Prohibited Seams Registry Formalization | Milestone L1, Milestone 7 | REV_014 |
| 15 | [x] | Chronicle View UI Scaffold & TTRPG Pivot | Milestone 14 | REV_015 |
| 16 | [x] | 3d6 Action Tray UI & Mechanics | Milestone 15 | REV_015 |

> [!TIP]
> Milestones 8–9 (agent data) and 10–11 (UI) can proceed in parallel once the truth alignment pass (Milestone 7) is complete. Milestone 12 (space graph) is independent and can also run in parallel.

---

## 9. Design Question Log

The following questions are recorded here for traceability:

### Resolved

1. **Morale Decay Rate:** ✅ **Resolved — threshold-gated step function.** Individual Morale only decays after a configurable number of consecutive ticks above an entropy threshold. Threshold constant defined in `Constants.gd`. Linear-per-tick decay is rejected.

2. **Cautious vs. Risky Approach Mechanics:** ✅ **Resolved — mixed model.** Approach is a binary toggle on most Action Checks. Certain categories are **locked to Risky** by rule (e.g., emergency actions, high-stakes confrontations). The locked set is defined as a constant or annotation on the action type, not determined at runtime.

3. **Narrative Template Key Format:** ✅ **Resolved — sub-folder hierarchy preferred.** Given the target volume of tag combinations, template lookup uses a **sub-folder directory structure** rather than a flat key string, with leaf files named by the terminal dimension (e.g., `templates/{sector_type}/{economy_tag}/{security_tag}/{event_type}.tres`). This is more ergonomic for authors and avoids combinatorial filename bloat.

4. **Frontier Decay Timeline:** ✅ **Superseded.** Dynamic sector graph sprouting and decay is no longer part of the design. In-sector POI spawning replaces this concept. No decay timeline constant is needed at the graph level.

5. **Sub-Agent Transfer Rules:** ✅ **Resolved — API-defined transitions.** Transfers are handled by a dedicated API: `sub_agent_transfer(sub_agent_id, from_host_id, to_host_id)`. Specific transfer interaction types (voluntary, forced, rescue, etc.) are described by the calling context, not encoded in the API itself. The sub-agent's `morale` value changes as a consequence of the transfer; the magnitude is defined in constants.

### Open

*(None currently)*
