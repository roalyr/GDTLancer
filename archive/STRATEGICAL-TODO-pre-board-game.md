<!--
PROJECT: GDTLancer
MODULE: STRATEGICAL-TODO.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 1–4; TRUTH_SIMULATION-GRAPH.md § 0; TRUTH_RULEBOOK.md
LOG_REF: 2026-07-01 02:41:00
-->

# STRATEGICAL TODO: Playable MVP Core

## CURRENT PHASE: MVP Core Implementation
- **STRATEGIC_SCOPE**: Deliver a 1-hour playable MVP validating the "Human-Scale Frontier" philosophy by providing a true Solo TTRPG Experience. Focus strictly on emergent narrative gameplay driven by the 4-layer simulation, discarding traditional contract boards for organic encounters.
- **TRUTH_RELIANCE**: `TRUTH_RULEBOOK.md`, `TRUTH_MVP_CORE.md`, `TRUTH_GAME-LOOP-VISION.md`, `TRUTH_SIMULATION-GRAPH.md`
- **STRATEGIC_CONSTRAINTS**: Do not build procedural prose generation. Keep sub-agents as simple narrative anchors for the first iteration. Do not build linear hand-crafted missions.

## TACTICAL_MILESTONES

- [x] **MILESTONE_17: Diverse Narrative Tasks & Interactions**
  - **Description**: Add narrative task stubs (mediating disputes, rescuing personnel, sabotage, anomalies) via static `.tres` templates instead of trading contracts. Ensure the environment applies pressure, not just mechanical math.

- [x] **MILESTONE_18: Sub-Agent Narrative Morale & Mutiny Events**
  - **Description**: Wire sub-agent morale drops to specific narrative consequences. If aggregate Morale drops to 0, trigger a Mutiny story beat that must be resolved through dialogue or a high-stakes action roll rather than simple lockout.

- [x] **MILESTONE_19_A: Tabletop Rulebook Definition (Tier 0)**
  - **Description**: Document the canonical game rules, state tracks, action resolution, and world clock in [TRUTH_RULEBOOK.md](file:///home/roalyr/Software_archive/Games/GDTLancer/TRUTH_RULEBOOK.md) to serve as a developer-facing validation instrument and player-facing guide.

- [ ] **MILESTONE_19_B: Tabletop Playtest Validation**
  - **Description**: Conduct a session playtest using the rulebook with an LLM agent acting as GM / companion. Capture structured design feedback directly in the session transcript/Chronicle to validate mechanics, pacing, and TTRPG player experience before completing digital UX implementation.


- [ ] **MILESTONE_19: Total UX Integration & Mechanics Wiring [BLOCKER]**
  - **Description**: We have built mechanics and narrative stubs, but they currently lack player-facing UX. This milestone demands that ALL mechanics (health, wealth, morale, supplies, and action results) are comprehensively wired into the player's direct interaction flow (the `InteractionWindow` and HUD). 
  - **Note**: This milestone is a strict **BLOCKER**. It requires hard, manual runtime verification to pass. It is not limited to the tasks suggested initially; any additional tasks required to achieve a coherent, playable UX where the player can clearly read and react to the simulation state must be added and resolved under this milestone.

- [ ] **MILESTONE_20: Environmental Pressure & Narrative Context**
  - **Description**: Bind `GridLayer` dynamic mutations (e.g., `CONTESTED` security, `HARSH` environment) to alter the narrative templates presented during Mode B. Allow background simulation shifts to be visible via non-intrusive Event Notification Toasts while in Mode A.

- [ ] **MILESTONE_21: Emergent Outcomes Validation (The MVP Playtest)**
  - **Description**: Ensure the outcomes of 3d6 rolls organically ripple outward (e.g., failed negotiations blocking docking rights, forcing relocation). Validate that 1 hour of meaningful play is achievable using the emergent rules engine.
