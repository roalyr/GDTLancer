<!--
PROJECT: GDTLancer
MODULE: GDD-REVISION-LEDGER.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: STRATEGICAL-TODO.md
LOG_REF: 2026-06-20 19:13:27
-->

# GDD Revision Ledger - GDTLancer

Purpose: This file is the architect-owned staging surface for approved live-vs-frozen doctrine changes. It does not replace `TACTICAL_TODO.md`, and it does not retroactively rewrite frozen truth docs in place. Each approved entry exists to keep future milestones aligned with the live codebase and the intended setting direction until a later truth or GDD rewrite formalizes it.

## Ledger Rules

- **Only Unimplemented Revisions:** The active root-level ledger (`GDD-REVISION-LEDGER.md`) must only contain revisions that are not yet implemented in code.
- **Archival Policy:** Once a milestone implements a set of revisions, those revisions are moved to an archived ledger file under `/archive/` (e.g. [archive/GDD-REVISION-LEDGER-1.md](archive/GDD-REVISION-LEDGER-1.md)), and are removed from this active ledger to avoid duplication and bloat.

## Entry Schema

For each revision entry, use the same fields:

- `Domain`
- `Live Reality`
- `Frozen / Legacy Tension`
- `Approved Direction`
- `Status`
- `Blocked By`
- `Follow-on Owners`
- `Evidence`

## Approved Revisions

> [!NOTE]
> **Active Ledger Only:** This file contains only revisions that are not yet implemented in code (starting from `REV_009`). Previously implemented revisions (`REV_001` through `REV_008`) have been moved to the archived ledger: [archive/GDD-REVISION-LEDGER-1.md](archive/GDD-REVISION-LEDGER-1.md).


### REV_009: Two-Speed Macro UX Contract

- Domain: UI/UX Architecture
- Live Reality: The current UI is a single-mode flight HUD with popup panels for station/NPC interaction. There is no formal mode separation, no full-screen Chronicle View, and no pause-on-interact contract.
- Frozen / Legacy Tension: The frozen GDD describes a modular UI but does not formalize the two-speed separation or the content delivery pipeline.
- Approved Direction: Formalize two mutually exclusive full-screen modes: Mode A (Kinetic Board — flight, real-time, ticking) and Mode B (Chronicle View — paused, grid-based 2D, narrative). Mode transitions are hard cuts, not overlays. Mode B pauses the simulation clock entirely.
- Status: Approved direction
- Blocked By: None
- Follow-on Owners: Chronicle View architecture program; UI milestone sequence (Milestone 10)
- Evidence: STRATEGICAL-TODO.md §2; `src/core/ui/main_hud/main_hud.gd`; `src/core/ui/interaction_window.gd`

### REV_010: Hardened Narrative Content Delivery

- Domain: Content Pipeline and Chronicle
- Live Reality: There is no narrative content delivery system. NPC interaction surfaces a trade panel with raw data. No hand-authored narrative templates exist.
- Frozen / Legacy Tension: The frozen GDD describes a Chronicle layer (Layer 4) for event capture and narrative, but the implementation model is unspecified.
- Approved Direction: Narrative prose is not procedurally generated. The local sector's Grid layer tags are combined into a deterministic key string that queries a static, hand-authored directory of `.tres` resource templates. Content is authored in the sector's practical jargon creole. This enforces authored quality and prevents LLM or procedural text generation from entering the player-facing narrative layer.
- Status: Approved direction
- Blocked By: REV_009
- Follow-on Owners: Content pipeline milestone (Milestone 11)
- Evidence: STRATEGICAL-TODO.md §2.2

### REV_011: Sub-Agent Data Layer

- Domain: Agent Architecture
- Live Reality: The runtime models agents as `Agent == Ship == Captain`. There is no sub-entity layer for crew, personnel, or station populations.
- Frozen / Legacy Tension: `TRUTH_GAME-LOOP-VISION.md § 1.3` describes "Versatile Agents" and clan/family community dynamics but provides no implementation model.
- Approved Direction: Introduce a data-only sub-agent layer: basic data sub-arrays parented under primary dockable or ship-agent entities. Phase 1 — sub-agents hold no simulation logic, do not participate in the tick, and cannot independently resolve Action Checks; they carry individual Morale values that are aggregated into the parent's Morale modifier. Phase 2 (future milestone) — sub-agents participate on par with primary agents in the social simulation layer (relationships, knowledge graph, inter-agent trust) and carry their own Health, Wealth, and Morale stats. Sub-agent transfers are handled through a defined API: `sub_agent_transfer(sub_agent_id, from_host_id, to_host_id)` with the sub-agent's Morale adjusted as a consequence of the transfer.
- Status: Approved direction
- Blocked By: None
- Follow-on Owners: Agent architecture milestone (Milestone 8)
- Evidence: STRATEGICAL-TODO.md §4.1; `src/core/simulation/agent_layer.gd`

### REV_012: Morale Stat & Crew Morale System

- Domain: Core Mechanics and Agent State
- Live Reality: The agent state tracks Health (`condition_tag`) and Wealth (`wealth_tier` + `wealth_progress`). There is no Morale or Supplies macro stat.
- Frozen / Legacy Tension: No prior truth file defines these stats. The frozen GDD tracks Health and Wealth only.
- Approved Direction: Add two new macro stat categories to the Core Resource Matrix: **Supplies** (logistics consumables as a qualitative tag, not a numeric inventory) and **Morale** (crew morale as individual per-sub-agent values aggregated to a bounded ship/station-level score). Individual Morale decays with prolonged high-entropy exposure and sub-agent neglect; the aggregate is used as the Action Check modifier. A ship/station aggregate Morale of 0 triggers mutiny or operational strike, representing a hard defeat condition. Morale decay uses a **threshold-gated step function**: individual values only decay after a configurable number of consecutive ticks above an entropy threshold, defined in `Constants.gd` alongside existing modifier dictionaries.
- Status: Approved direction
- Blocked By: REV_011
- Follow-on Owners: Constants.gd extension; CoreMechanicsAPI modifier integration; agent state serialization (Milestone 9)
- Evidence: STRATEGICAL-TODO.md §4.2–§4.3; `src/autoload/Constants.gd`

### REV_013: Manual Space Graph & In-Sector POI Doctrine

- Domain: World Topology and Simulation
- Live Reality: The world graph is static after bootstrap, built from authored `location_template` resources. REV_005 approved the nested 4-tier hierarchy concept.
- Frozen / Legacy Tension: The prior draft staged dynamic deep-space sector sprouting, but this conflicts with a clean, predictable graph and defers exploration mechanics indefinitely.
- Approved Direction: The inter-sector space graph is permanently **manual**: Star → Planet → Moon connections are hand-authored and do not change at runtime. Dynamic content lives **inside** each sector as in-sector POIs (derelicts, deposits, anomalies, temporary outposts) spawned within the sector's 3D volume. POIs are local simulation objects, not graph nodes. Exploration mechanics that interact with in-sector POIs are deferred for a dedicated rework milestone.
- Status: Approved direction
- Blocked By: None
- Follow-on Owners: World topology implementation milestone (Milestone 12)
- Evidence: STRATEGICAL-TODO.md §3; `src/core/simulation/world_layer.gd`; `database/definitions/location_template.gd`

### REV_014: Prohibited Seams Registry

- Domain: Scope Control
- Live Reality: There is no formal registry of explicitly banned feature categories. Scope control relies on `TACTICAL_TODO.md` contract boundaries and architect judgment.
- Frozen / Legacy Tension: The frozen GDD includes various feature descriptions (ship modules, detailed market UIs, equipment crafting) that are now out of scope but not formally prohibited.
- Approved Direction: Establish a permanent, truth-level prohibited seams list. Initial entries: (1) No speculative market displays — player-facing trade uses Wealth Track increments and Contract Value Classes, never raw credit integers; (2) No 3D on-foot navigation — all station-side interaction is 2D grid-aligned Chronicle View menus. Future prohibited seams are added to this registry by architect directive only.
- Status: Approved direction
- Blocked By: None
- Follow-on Owners: Milestone 14
- Evidence: STRATEGICAL-TODO.md §5


## Usage Notes

- This file is an architect and design staging surface, not the active implementation queue.
- `TACTICAL_TODO.md` remains the only active sprint contract.
- When a later milestone formalizes one of these entries, keep the ledger entry and link the implementation milestone rather than deleting the revision record.

