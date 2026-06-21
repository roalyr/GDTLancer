<!--
PROJECT: GDTLancer
MODULE: TRUTH_PROHIBITED-SEAMS.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
LOG_REF: 2026-06-21 13:06:00
-->

# GDTLancer - Prohibited Seams Registry

This registry tracks systems, features, and mechanics that are explicitly banned from implementation. Its purpose is to enforce scope discipline and prevent feature creep into generic space-sim tropes.

## 1. No Speculative Market Trading (Contracts Only)
- **Rule:** The player must not have access to a direct buy/sell trade interface or speculative market at stations. 
- **Implementation Constraint:** All player-initiated cargo hauling and resource transfers are governed exclusively by Contracts. To enforce this and prevent numeric optimization, the UI must never surface raw credit integers; contract payouts instead increment or decrement the qualitative 0–10 Wealth Track based on Contract Value Classes.
- **Rationale:** Strongly enforces scope limits and prevents the game from devolving into a spreadsheet-driven "buy low, sell high" trading simulator. The player is a contractor executing missions for communities, not an independent trade merchant.

## 2. No 3D On-Foot Navigation
- **Rule:** The project must not model 3D player avatars, station interiors, or space-legs systems.
- **Implementation Constraint:** All station-side community interactions and sub-agent management are executed exclusively through the high-fidelity, grid-aligned 2D menus of the Chronicle View.
- **Rationale:** Preserves the two-speed macro UX contract (Kinetic Board vs. Chronicle View) and prevents endless scope expansion into character controllers and level design.

## 3. No Procedural Narrative Generation
- **Rule:** The game must never utilize runtime procedural prose generators, LLMs (Large Language Models), or generative AI to synthesize dialogue, descriptions, or chronicle events.
- **Implementation Constraint:** Narrative text is drawn from static, hand-authored `.tres` template resources and resolved deterministically using tag-based keys.
- **Rationale:** Ensures that the player-facing prose strictly adheres to the low-tech, nautical "jargon creole" and community-centric atmosphere, preventing the dilution of tone that comes with procedural or generative text.

## 4. No Colony Construction or Base Building
- **Rule:** The player must not be given mechanics to construct, modify, or layout station modules, anchorage components, or planetary bases.
- **Implementation Constraint:** Sector topology and station assets are either designer-authored statically or mutated solely through systemic event ticks of the background cellular automaton (CA) simulation.
- **Rationale:** Preserves the core design pillar of the player as an individual peer agent operating within a community, rather than an omniscient, god-mode manager.

## 5. No Linear Equipment or Tiered Loot Progression
- **Rule:** Ship and character equipment/tools must not follow numeric power progression models (item rarity levels, stat scaling, tier levels, or gear scores).
- **Implementation Constraint:** Ship tools, upgrades, and modules are lateral utility components (e.g., adding a mining laser enables mining but sacrifices cargo capacity or power). Assets function as keys to specific gameplay features, roll modifiers, and/or narrative elements rather than linear stat-upgrades.
- **Rationale:** Keeps progression focused on community relationships, qualitative wealth tracks, and utility-based gameplay access rather than numerical equipment optimization loops.

## 6. No Real-Time Cross-Sector Communication
- **Rule:** The game must not feature instantaneous cross-sector communications (FTL comms, global chat boards, instant mail).
- **Implementation Constraint:** Communications, trade gossip, and sector news must propagate at physical transport speeds (relayed via ship jumps or simulated arrival/departure ticks).
- **Rationale:** Reinforces the logistical weight of space travel and the acute sense of isolation, making the arrival of news or messages a meaningful event.

## 7. No Lethal Peer-to-Peer Human Ship Combat
- **Rule:** Human ship-to-ship combat must prioritize disablement and capture over vaporization or character death (the "Preservation Convention").
- **Implementation Constraint:** Combat systems must enforce ship disablement states. Human NPCs will yield or retreat rather than fight to the death, and player defeat leads to salvage, rescue, or social penalties rather than a game-over death screen. Destructive lethal combat is restricted to non-human targets (drones, anomalies).
- **Rationale:** Aligns with the Lore constraint that human pilots and vessels are rare, culturally revered assets too valuable to casually destroy. Any human ship-to-ship combat that does occur must be highly rare and narratively reasoned.

## 8. No Dynamic Sector Graph Generation
- **Rule:** The star systems and sector connections (the world map graph) must remain static and manual.
- **Implementation Constraint:** Star-planet-moon jumps are defined in designer-authored layout resources and cannot sprout or decay dynamically at runtime. Exploration is restricted to spawning temporary, in-sector POIs (derelicts, anomalies).
- **Rationale:** Prevents infinite scope creep in procedural map generation, route-finding code, and UI map display bugs.


## Architect Policy for Future Seams
- Future prohibited seams may only be added to this registry via explicit Architect directive (e.g., an approved `REV_XXX` entry in the GDD Revision Ledger).
- Developers and Verificators may not add entries to this list.
