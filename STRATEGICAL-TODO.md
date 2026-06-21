<!--
PROJECT: GDTLancer
MODULE: STRATEGICAL-TODO.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 1–4; TRUTH_SIMULATION-GRAPH.md § 0
LOG_REF: 2026-06-22 00:48:00
-->

# STRATEGICAL TODO: Playable MVP Core

## CURRENT PHASE: MVP Core Implementation
- **STRATEGIC_SCOPE**: Deliver a 1-hour playable MVP validating the "Human-Scale Frontier" philosophy by providing a true Solo TTRPG Experience. Focus strictly on emergent narrative gameplay driven by the 4-layer simulation, discarding traditional contract boards for organic encounters.
- **TRUTH_RELIANCE**: `TRUTH_MVP_CORE.md`, `TRUTH_GAME-LOOP-VISION.md`, `TRUTH_SIMULATION-GRAPH.md`
- **STRATEGIC_CONSTRAINTS**: Do not build procedural prose generation. Keep sub-agents as simple narrative anchors for the first iteration. Do not build linear hand-crafted missions.

## TACTICAL_MILESTONES

- [ ] **MILESTONE_17: Diverse Narrative Tasks & Interactions**
  - **Description**: Add narrative task stubs (mediating disputes, rescuing personnel, sabotage, anomalies) via static `.tres` templates instead of trading contracts. Ensure the environment applies pressure, not just mechanical math.

- [ ] **MILESTONE_18: Sub-Agent Narrative Morale & Mutiny Events**
  - **Description**: Wire sub-agent morale drops to specific narrative consequences. If aggregate Morale drops to 0, trigger a Mutiny story beat that must be resolved through dialogue or a high-stakes action roll rather than simple lockout.

- [ ] **MILESTONE_19: Environmental Pressure & Narrative Context**
  - **Description**: Bind `GridLayer` dynamic mutations (e.g., `CONTESTED` security, `HARSH` environment) to alter the narrative templates presented during Mode B. Allow background simulation shifts to be visible via non-intrusive Event Notification Toasts while in Mode A.

- [ ] **MILESTONE_20: Emergent Outcomes Validation (The MVP Playtest)**
  - **Description**: Ensure the outcomes of 3d6 rolls organically ripple outward (e.g., failed negotiations blocking docking rights, forcing relocation). Validate that 1 hour of meaningful play is achievable using the emergent rules engine.
