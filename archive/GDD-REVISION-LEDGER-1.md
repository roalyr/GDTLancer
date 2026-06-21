<!--
PROJECT: GDTLancer
MODULE: GDD-REVISION-LEDGER.md
STATUS: [Level 2 - Implementation]
OWNER: developer
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; TRUTH_PROJECT.md § Session Logging Boundary; TRUTH_SIMULATION-GRAPH.md §0; TRUTH_SIMULATION-GRAPH.md §6.3; TRUTH_SIMULATION-GRAPH.md §8.3; TRUTH_SIMULATION-GRAPH.md §8.4; TACTICAL_TODO.md TASK_2; commodity_classification_architecture.md
LOG_REF: 2026-06-20 20:31:00
-->

# GDD Revision Ledger - GDTLancer (Archived)

Purpose: This file stores archived entries of the GDD Revision Ledger that have already been implemented in the codebase.

## Entry Schema

For each revision entry, use the same fields:

- `Domain`
- `Live Reality`
- `Frozen / Legacy Tension`
- `Approved Direction`
- `Status`
- `Blocked By`
- `Evidence`

## Approved Revisions

### REV_001: Qualitative Simulation Substrate

- Domain: Simulation substrate
- Live Reality: The authoritative runtime is the qualitative tag and bounded-occurrence loop described in `TRUTH_SIMULATION-GRAPH.md §0` and implemented in `WorldLayer`, `GridLayer`, `BridgeSystems`, `ContractGenerationSystem`, and `AgentLayer`.
- Frozen / Legacy Tension: Large portions of `TRUTH_SIMULATION-GRAPH.md` Sections 1 through 5 still describe the older numeric stockpile, price, and matter-conservation model as if it were live.
- Approved Direction: Future design and implementation work must treat the qualitative runtime as canonical unless a dedicated architecture program explicitly reopens the substrate. Do not reintroduce numeric economy or matter-accounting requirements into the live GDScript core by drift.
- Status: Approved direction
- Blocked By: None
- Evidence: `TRUTH_SIMULATION-GRAPH.md §0`; `src/core/simulation/world_layer.gd`; `src/core/simulation/grid_layer.gd`; `src/core/simulation/bridge_systems.gd`; `src/core/simulation/contract_generation_system.gd`; `src/core/simulation/agent_layer.gd`

### REV_002: Near-Term World Topology Doctrine

- Domain: World structure and dockables
- Live Reality: The runtime world graph is flat `world_topology[sector_id]` data, and the current scene-loading seam injects only the first station id for a sector.
- Frozen / Legacy Tension: The design discussion is moving toward richer spatial hierarchy and potentially more station or faction fidelity than the current flat-sector model supports.
- Approved Direction: Near-term shipping doctrine remains one sector, one dockable or service hub. Social or factional differentiation must not be forced by immediate multi-dockable sector work.
- Status: Approved direction
- Blocked By: Later topology program if hierarchy is reopened
- Evidence: `src/core/simulation/world_layer.gd` (`station_ids: [location_id]`); `src/core/systems/sector_loader.gd` (`station_ids[0]`); `database/definitions/location_template.gd`

### REV_003: Human Conflict Doctrine

- Domain: Combat and threat model
- Live Reality: The current affinity-driven interaction seam allows direct agent attacks whenever tag scores exceed the attack threshold, including pirate-on-pirate cases, and lethal outcomes still occur in human-human encounters.
- Frozen / Legacy Tension: The desired setting direction now treats a tiny interdependent human population as too valuable for routine lethal internal warfare.
- Approved Direction: Human conflict should evolve toward mostly non-lethal pressure, sabotage, coercion, corruption, staged accidents, and other indirect confrontation. Lethal combat should concentrate primarily in external hostile forces such as alien or drone threats.
- Status: Approved direction
- Blocked By: None
- Evidence: `src/core/simulation/agent_layer.gd::_resolve_agent_interaction()`; `src/core/simulation/affinity_matrix.gd`; `TACTICAL_TODO.md` current goal `Faction And Interaction Doctrine Refactor`; user-approved setting direction 2026-05-30

### REV_004: Lawful / Unlawful Economy Separation

- Domain: Trade, legality, and faction economics
- Live Reality: Peer `agent_trade` is a qualitative cargo handoff (`LOADED` / `EMPTY`) without cargo provenance, reputation, or lawful/unlawful market routing. Sector legality is currently only a tag and affinity influence seam.
- Frozen / Legacy Tension: The emerging setting now wants clearer lawful or unlawful distinctions and eventually more explicit social or factional context than the present generic trade logic provides.
- Approved Direction: Do not solve lawful versus unlawful trade by immediately adding multiple dockables per sector. First design a later social-simulation milestone around faction tags, cargo provenance, trade gating, and legal or illegal interaction rules within the existing one-sector-one-dockable world model.
- Status: Approved direction
- Blocked By: None
- Evidence: `src/core/simulation/agent_layer.gd::_bilateral_trade()`; `src/core/simulation/affinity_matrix.gd`; `TRUTH_SIMULATION-GRAPH.md §8.3`; `TRUTH_SIMULATION-GRAPH.md §8.4`; `TACTICAL_TODO.md` current goal `Faction And Interaction Doctrine Refactor`

### REV_005: Hierarchical Universe Topology Program

- Domain: Large-scale universe structure
- Live Reality: The world graph, route building, contract sourcing, sector loading, and docking assumptions all currently depend on a flat sector graph with sector-level templates.
- Frozen / Legacy Tension: The desired future setting requires nesting star, planetary, and sub-planetary sectors, which is a much larger architectural shift than the current live model.
- Approved Direction: Establish a nested 4-tier hierarchy (Stellar Systems -> Planets -> Moons -> Deep Space) where every sector represents exactly one dockable Point of Interest (POI). This hierarchy is entirely designer-authored as a flat graph, requiring no parent/child code schema pointers. To maximize simplicity, `location_type` and `sector_type` will consolidate into a single unified `sector_type` field containing celestial roles (`star`, `planet`, `moon`, `field`, `deep_space`), which implicitly represent development and security tiers. Transit jump cutscenes and Star-level catastrophe lockdowns resolve statically using these consolidated parameters.
- Status: Concept approved
- Blocked By: None
- Evidence: `database/definitions/location_template.gd`; `src/core/simulation/world_layer.gd`; `src/core/systems/sector_loader.gd`; `src/core/simulation/agent_layer.gd`

### REV_006: Commodity Classification Registry and Tag-Governed Seeding

- Domain: Economy and Commodity Classification
- Live Reality: The Commodity Classification Registry (`Constants.COMMODITY_CLASSIFICATION`) maps quantitative goods to their qualitative categories. Procedural stations seed their markets as a direct projection of sector tags (`POOR`/`ADEQUATE`/`RICH` levels) using template `base_value` multipliers and a standard sell price fraction.
- Frozen / Legacy Tension: Legacy procedural seeding used static commodity listings and hardcoded prices/quantities, completely decoupled from qualitative tags.
- Approved Direction: Build a strict one-way authority where qualitative economy tags govern quantitative station market generation. Quantitative inventory state acts as a local projection of tags and does not feed back to qualitative simulation.
- Status: Approved direction
- Blocked By: None
- Evidence: `commodity_classification_architecture.md`; `src/autoload/Constants.gd`; `src/core/simulation/agent_layer.gd`

### REV_007: Dual-Economy (Electronic Credits vs Physical Specie)

- Domain: Economy and Currency
- Live Reality: The economy operates on a dual-currency system. Electronic credits are character-profile integers: abstract, trust-bound, not counted in `TOTAL_MATTER`, clamped at a minimum of zero during subtraction in `CharacterSystem`. Physical specie (`commodity_specie`) is a cargo commodity occupying inventory slots, counted in `TOTAL_MATTER`, physically represented as dense inert metal (e.g. refined iridium discs, platinum ingots, or neutronium-alloy tokens) that is universally accepted because it requires no institutional trust. Hauling specie always has an opportunity cost in lost trade capacity.
- Frozen / Legacy Tension: Legacy documents described credits and specie interchangeably or assumed credits were matter-backed, whereas the live simulation treats credits as electronic trust-based ledger entries and specie as a physical commodity subject to matter conservation.
- Approved Direction:
  - Credits remain outside `TOTAL_MATTER` unconditionally. Never count credits in the matter axiom.
  - Any credit subtraction clamps to a minimum of `0`; negative credit balances are forbidden.
  - Credits are faction-scoped promissory notes. The fiction of "faction-specific credits" is produced by trust routing, not separate ledgers.
  - Credit trust follows faction presence. If a faction has no active `STATION`-tagged sectors, its allied agents can no longer perform credit transactions; isolation is emergent, not hard-coded.
  - Factionless agents (no faction tag) transact in specie only, unconditionally.
- Status: Approved direction
- Blocked By: None
- Evidence: `TRUTH_SIMULATION-GRAPH.md §2.2.1` and `§8.1`; `src/core/systems/character_system.gd` (`subtract_credits`); `src/autoload/GameState.gd`; `dual_economy_design_draft.md` (approved 2026-06-11)

### REV_008: Trust-Gated Credit vs Specie Transaction Routing

- Domain: Economy, Agent Interaction, and Faction Trust
- Live Reality: All current agent-to-agent and agent-to-station transactions mutate `credits` directly regardless of faction relationship. There is no routing logic that selects between credits and specie based on affinity.
- Frozen / Legacy Tension: The approved dual-economy doctrine (REV_007) requires that credits be accepted only when faction trust is sufficient. The live code does not yet enforce this.
- Approved Direction: Use `affinity_matrix.compute_affinity(payer_tags, payee_tags)` as the trust resolver. A single constant `CREDIT_TRUST_THRESHOLD` in `Constants.gd` defines the minimum affinity score for credit acceptance. Above or equal → credits. Below → specie. Factionless (either party has no faction tag) → specie unconditionally. No separate credit ledgers per faction. No exchange rate mechanics. The fiction of faction-scoped credits emerges from routing alone.
- Status: Approved direction
- Blocked By: None
- Evidence: `dual_economy_design_draft.md` §3 and §5 (approved 2026-06-11); `src/core/simulation/affinity_matrix.gd` (`compute_affinity`); `src/core/simulation/agent_layer.gd` (`_bilateral_trade`, `_attempt_npc_market_buy`, `_attempt_npc_market_sell`); `src/autoload/Constants.gd`

### REV_011: Sub-Agent Data Layer

- Domain: Agent Architecture
- Live Reality: The runtime models agents as `Agent == Ship == Captain`. There is no sub-entity layer for crew, personnel, or station populations.
- Frozen / Legacy Tension: `TRUTH_GAME-LOOP-VISION.md § 1.3` describes "Versatile Agents" and clan/family community dynamics but provides no implementation model.
- Approved Direction: Introduce a data-only sub-agent layer: basic data sub-arrays parented under primary dockable or ship-agent entities. Phase 1 — sub-agents hold no simulation logic, do not participate in the tick, and cannot independently resolve Action Checks; they carry individual Morale values that are aggregated into the parent's Morale modifier. Phase 2 (future milestone) — sub-agents participate on par with primary agents in the social simulation layer (relationships, knowledge graph, inter-agent trust) and carry their own Health, Wealth, and Morale stats. Sub-agent transfers are handled through a defined API: `sub_agent_transfer(sub_agent_id, from_host_id, to_host_id)` with the sub-agent's Morale adjusted as a consequence of the transfer.
- Status: Implemented in Milestone 8.
- Blocked By: None
- Evidence: `src/core/simulation/agent_layer/agent_sub_agents.gd`; `src/core/simulation/agent_layer.gd`; `src/autoload/Constants.gd`; `src/tests/core/simulation/test_agent_layer.gd`

### REV_012: Morale Stat & Crew Morale System

- Domain: Core Mechanics and Agent State
- Live Reality: The agent state tracks Health (`condition_tag`) and Wealth (`wealth_tier` + `wealth_progress`). There is no Morale or Supplies macro stat.
- Frozen / Legacy Tension: No prior truth file defines these stats. The frozen GDD tracks Health and Wealth only.
- Approved Direction: Add two new macro stat categories to the Core Resource Matrix: Supplies (logistics consumables as a qualitative tag, not a numeric inventory) and Morale (crew morale as individual per-sub-agent values aggregated to a bounded ship/station-level score). Individual Morale decays with prolonged high-entropy exposure and sub-agent neglect; the aggregate is used as the Action Check modifier. A ship/station aggregate Morale of 0 triggers mutiny or operational strike, representing a hard defeat condition. Morale decay uses a threshold-gated step function: individual values only decay after a configurable number of consecutive ticks above an entropy threshold, defined in `Constants.gd` alongside existing modifier dictionaries.
- Status: Implemented in Milestone 9.
- Blocked By: REV_011
- Evidence: `src/autoload/Constants.gd`; `src/autoload/CoreMechanicsAPI.gd`; `src/core/simulation/agent_layer.gd`; `src/core/simulation/agent_layer/agent_sub_agents.gd`; `src/tests/core/simulation/test_agent_layer.gd`; `src/tests/autoload/test_core_mechanics_api.gd`

### REV_009: Two-Speed Macro UX Contract

- Domain: UI/UX Architecture
- Live Reality: The current UI is a single-mode flight HUD with popup panels for station/NPC interaction. There is no formal mode separation, no full-screen Chronicle View, and no pause-on-interact contract.
- Frozen / Legacy Tension: The frozen GDD describes a modular UI but does not formalize the two-speed separation or the content delivery pipeline.
- Approved Direction: Formalize two mutually exclusive full-screen modes: Mode A (Kinetic Board — flight, real-time, ticking) and Mode B (Chronicle View — paused, grid-based 2D, narrative). Mode transitions are hard cuts, not overlays. Mode B pauses the simulation clock entirely.
- Status: Implemented in Milestone 10.
- Blocked By: None
- Evidence: `GDD-MASTER-DESIGN-DIRECTIVE.md` §2; `src/autoload/GameState.gd`; `src/autoload/EventBus.gd`; `src/core/ui/main_hud/main_hud.gd`; `src/core/ui/interaction_window/interaction_window.gd`; `src/core/ui/npc_trade_panel/npc_trade_panel.gd`; `src/tests/core/ui/test_chronicle_view_transitions.gd`

### REV_013: Manual Space Graph & In-Sector POI Doctrine

- Domain: World Topology and Simulation
- Live Reality: The world graph is static after bootstrap, built from authored `location_template` resources. REV_005 approved the nested 4-tier hierarchy concept.
- Frozen / Legacy Tension: The prior draft staged dynamic deep-space sector sprouting, but this conflicts with a clean, predictable graph and defers exploration mechanics indefinitely.
- Approved Direction: The inter-sector space graph is permanently **manual**: Star → Planet → Moon connections are hand-authored and do not change at runtime. Dynamic content lives **inside** each sector as in-sector POIs (derelicts, deposits, anomalies, temporary outposts) spawned within the sector's 3D volume. POIs are local simulation objects, not graph nodes. Exploration mechanics that interact with in-sector POIs are deferred for a dedicated rework milestone.
- Status: Implemented in Milestone 12.
- Blocked By: None
- Evidence: STRATEGICAL-TODO.md §3; `src/core/simulation/world_layer.gd`; `database/definitions/location_template.gd`

### REV_010: Hardened Narrative Content Delivery

- Domain: Content Pipeline and Chronicle
- Live Reality: There is no narrative content delivery system. NPC interaction surfaces a trade panel with raw data. No hand-authored narrative templates exist.
- Frozen / Legacy Tension: The frozen GDD describes a Chronicle layer (Layer 4) for event capture and narrative, but the implementation model is unspecified.
- Approved Direction: Narrative prose is not procedurally generated. The local sector's Grid layer tags are combined into a deterministic key string that queries a static, hand-authored directory of `.tres` resource templates. Content is authored in the sector's practical jargon creole. This enforces authored quality and prevents LLM or procedural text generation from entering the player-facing narrative layer.
- Status: Implemented in Milestone 11.
- Blocked By: REV_009
- Evidence: STRATEGICAL-TODO.md §2.2

### REV_014: Prohibited Seams Registry

- Domain: Scope Control
- Live Reality: There is no formal registry of explicitly banned feature categories. Scope control relies on `TACTICAL_TODO.md` contract boundaries and architect judgment.
- Frozen / Legacy Tension: The frozen GDD includes various feature descriptions (ship modules, detailed market UIs, equipment crafting) that are now out of scope but not formally prohibited.
- Approved Direction: Establish a permanent, truth-level prohibited seams list. Initial entries: (1) No speculative market displays — player-facing trade uses Wealth Track increments and Contract Value Classes, never raw credit integers; (2) No 3D on-foot navigation — all station-side interaction is 2D grid-aligned Chronicle View menus. Future prohibited seams are added to this registry by architect directive only.
- Status: Implemented in Milestone 14.
- Blocked By: None
- Evidence: STRATEGICAL-TODO.md §5