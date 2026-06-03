<!--
PROJECT: GDTLancer
MODULE: GDD-REVISION-LEDGER.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; TRUTH_PROJECT.md § Session Logging Boundary; TRUTH_SIMULATION-GRAPH.md §0; TRUTH_SIMULATION-GRAPH.md §6.3; TRUTH_SIMULATION-GRAPH.md §8.3; TRUTH_SIMULATION-GRAPH.md §8.4
LOG_REF: 2026-06-03 19:48:31
-->

# GDD Revision Ledger - GDTLancer

Purpose: This file is the architect-owned staging surface for approved live-vs-frozen doctrine changes. It does not replace `TACTICAL_TODO.md`, and it does not retroactively rewrite frozen truth docs in place. Each approved entry exists to keep future milestones aligned with the live codebase and the intended setting direction until a later truth or GDD rewrite formalizes it.

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

### REV_001: Qualitative Simulation Substrate

- Domain: Simulation substrate
- Live Reality: The authoritative runtime is the qualitative tag and bounded-occurrence loop described in `TRUTH_SIMULATION-GRAPH.md §0` and implemented in `WorldLayer`, `GridLayer`, `BridgeSystems`, `ContractGenerationSystem`, and `AgentLayer`.
- Frozen / Legacy Tension: Large portions of `TRUTH_SIMULATION-GRAPH.md` Sections 1 through 5 still describe the older numeric stockpile, price, and matter-conservation model as if it were live.
- Approved Direction: Future design and implementation work must treat the qualitative runtime as canonical unless a dedicated architecture program explicitly reopens the substrate. Do not reintroduce numeric economy or matter-accounting requirements into the live GDScript core by drift.
- Status: Approved direction
- Blocked By: None
- Follow-on Owners: Future truth-rewrite milestone; future architect passes that touch simulation doctrine
- Evidence: `TRUTH_SIMULATION-GRAPH.md §0`; `src/core/simulation/world_layer.gd`; `src/core/simulation/grid_layer.gd`; `src/core/simulation/bridge_systems.gd`; `src/core/simulation/contract_generation_system.gd`; `src/core/simulation/agent_layer.gd`

### REV_002: Near-Term World Topology Doctrine

- Domain: World structure and dockables
- Live Reality: The runtime world graph is flat `world_topology[sector_id]` data, and the current scene-loading seam injects only the first station id for a sector.
- Frozen / Legacy Tension: The design discussion is moving toward richer spatial hierarchy and potentially more station or faction fidelity than the current flat-sector model supports.
- Approved Direction: Near-term shipping doctrine remains one sector, one dockable or service hub. Social or factional differentiation must not be forced by immediate multi-dockable sector work.
- Status: Approved direction
- Blocked By: Later topology program if hierarchy is reopened
- Follow-on Owners: Future topology architecture milestone; future content/bootstrap milestone
- Evidence: `src/core/simulation/world_layer.gd` (`station_ids: [location_id]`); `src/core/systems/sector_loader.gd` (`station_ids[0]`); `database/definitions/location_template.gd`

### REV_003: Human Conflict Doctrine

- Domain: Combat and threat model
- Live Reality: The current affinity-driven interaction seam allows direct agent attacks whenever tag scores exceed the attack threshold, including pirate-on-pirate cases, and lethal outcomes still occur in human-human encounters.
- Frozen / Legacy Tension: The desired setting direction now treats a tiny interdependent human population as too valuable for routine lethal internal warfare.
- Approved Direction: Human conflict should evolve toward mostly non-lethal pressure, sabotage, coercion, corruption, staged accidents, and other indirect confrontation. Lethal combat should concentrate primarily in external hostile forces such as alien or drone threats.
- Status: Active implementation slice
- Blocked By: Current milestone `Faction And Interaction Doctrine Refactor`
- Follow-on Owners: Current interaction milestone; future combat rebuild milestone
- Evidence: `src/core/simulation/agent_layer.gd::_resolve_agent_interaction()`; `src/core/simulation/affinity_matrix.gd`; `TACTICAL_TODO.md` current goal `Faction And Interaction Doctrine Refactor`; user-approved setting direction 2026-05-30

### REV_004: Lawful / Unlawful Economy Separation

- Domain: Trade, legality, and faction economics
- Live Reality: Peer `agent_trade` is a qualitative cargo handoff (`LOADED` / `EMPTY`) without cargo provenance, reputation, or lawful/unlawful market routing. Sector legality is currently only a tag and affinity influence seam.
- Frozen / Legacy Tension: The emerging setting now wants clearer lawful or unlawful distinctions and eventually more explicit social or factional context than the present generic trade logic provides.
- Approved Direction: Do not solve lawful versus unlawful trade by immediately adding multiple dockables per sector. First design a later social-simulation milestone around faction tags, cargo provenance, trade gating, and legal or illegal interaction rules within the existing one-sector-one-dockable world model.
- Status: Active implementation slice
- Blocked By: Current milestone `Faction And Interaction Doctrine Refactor`
- Follow-on Owners: Current interaction milestone; future social and economic simulation milestone
- Evidence: `src/core/simulation/agent_layer.gd::_bilateral_trade()`; `src/core/simulation/affinity_matrix.gd`; `TRUTH_SIMULATION-GRAPH.md §8.3`; `TRUTH_SIMULATION-GRAPH.md §8.4`; `TACTICAL_TODO.md` current goal `Faction And Interaction Doctrine Refactor`

### REV_005: Deferred Hierarchical Universe Program

- Domain: Large-scale universe structure
- Live Reality: The world graph, route building, contract sourcing, sector loading, and docking assumptions all currently depend on a flat sector graph with sector-level templates.
- Frozen / Legacy Tension: The desired future setting may move toward star sectors, planetary sectors, and sub-planetary sectors, which is a much larger architectural shift than the current live model.
- Approved Direction: Defer any star, planetary, or sub-planetary hierarchy rebuild until after doctrine alignment and social-simulation direction are stable. Treat hierarchy as a later standalone architecture program, not as a local tweak or a prerequisite for the next milestone.
- Status: Deferred program
- Blocked By: Doctrine stabilization; future topology architecture planning
- Follow-on Owners: Future hierarchy and topology program
- Evidence: `database/definitions/location_template.gd`; `src/core/simulation/world_layer.gd`; `src/core/systems/sector_loader.gd`; `src/core/simulation/agent_layer.gd`

## Follow-on Milestone Order

1. `Universe Doctrine Alignment Ledger` — create this ledger and wire it into the architect workflow.
2. `Faction And Interaction Doctrine Refactor` — define faction tags, lawful or unlawful interaction policy, cargo provenance, and non-lethal human conflict rules without rebuilding topology.
3. `Lawful / Unlawful Market Simulation` — implement the approved social and economic rules inside the existing flat sector model if the prior milestone stabilizes them.
4. `Hierarchical Universe Topology Program` — revisit star, planetary, and sub-planetary structure only after the doctrine and social-simulation seams are coherent.

## Usage Notes

- This file is an architect and design staging surface, not the active implementation queue.
- `TACTICAL_TODO.md` remains the only active sprint contract.
- When a later milestone formalizes one of these entries, keep the ledger entry and link the implementation milestone rather than deleting the revision record.