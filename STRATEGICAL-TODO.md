<!-- PROJECT: GDTLancer -->
# Strategic Roadmap

## Current Phase
GDTLancer is a **2D digital board game** built in Godot 3.6 with two modes of play. **Mode A** is a real-time 3D flight environment — a hand-crafted, visual-archaeological canvas where storytelling occurs through geometry, derelicts, wear, and shadow. **Mode B** is a 2D board interface using simple board game conventions (tokens, grids, tracks, cards, dice rolls). The board action loop follows: **Target Node → Asset Cards → 3d6 Check → Board Mutation (Impact Cards)**. Progression is lateral (expanded mechanical verbs via Asset Cards) not numerical. Exploration is motivated by relational necessity, not glory. The design is structured around 10 Exploration Pillars (see TRUTH_EXPLORATION-PILLARS.md).

---

## Milestones

### M20: Simulation Rework (Event-Driven) [x]
Replace the old cellular automata with an event-driven World Clock system.
- Replace the old Freelancer-shaped cellular automata with an event-driven World Clock system.
- Sector tracks change from player actions and World Clock consequences, not invisible background math.
- Vessel Layer: vessels as tracked entities with routines, positions, NPC assignments.
- This is a prerequisite for all board game mechanics.
- Dependencies: None
- Done criteria: System is fully event-driven with basic vessel tracking correct.

---

### M21: Board Mechanics Core (The Kernel) [x]
Implement the board action loop and minimum viable mechanical kernel.
- Implement the board action loop: Target Node → Asset Cards → 3d6 Check → Board Mutation.
- 4 player progress tracks (Health, Wealth, Morale, Supplies) with tier system (0-10, tier shifts at thresholds).
- **Asset Cards** as the primary interaction medium: cards expand what the player *can do* (traversal options, interaction unlocks, survival capabilities) rather than inflating numerical stats.
- 3d6 action check modified by applicable Asset Card tags and current track states.
- **Impact Cards** system: Advantage/Disadvantage outcomes chosen by player, instantly mutating board state.
- Tags on board nodes as mechanical hooks for action assembly.
- World Clock tick-triggering from major actions.
- Dependencies: M20
- Done criteria: Actions can be assembled via Asset Cards and resolved with 3d6 impacting tracks.

---

### M22: Mode B UI — Board Interface [x]
Implement the 2D board interface using simple board game conventions.
- Mode B interface using tokens, grids, track displays, card areas, and dice roll feedback.
- No illustrated depth-mat scenes or paper-doll sprite systems — NPC presence represented via named tokens with tags.
- Zone layout TBD (to be defined when board design is finalised).
- Mode A ↔ Mode B transition system.
- Dependencies: M21
- Done criteria: Mode A and Mode B transitions work smoothly; player can interact with the board.

---

### M23: Impact Card Tables (Data-Driven Outcomes) [x]
Implement data-driven outcome tables for board mutation.
- Impact Card outcome pools as data-driven .tres resources.
- Advantage/Disadvantage card pools keyed by context tags (sector, NPC relationship, track state).
- Complication and Opportunity entries mapped to concrete board mutations (track deltas, tag changes, node state changes).
- No oracle free-text generation — tables produce mechanical tags and state deltas only.
- Dependencies: M21
- Done criteria: Board mutations are driven by contextual outcome tables, not hardcoded logic.

---

### M24: NPC & Bond System [x]
Add NPC tags, bond strengths, and their presence as board tokens.
- NPC tokens with tag sets, bond strength (FRAGILE/STABLE/DEEP), and status flags.
- Bond-based modifiers to 3d6 action checks.
- Bond ties to community stewardship: NPC vulnerabilities and relational hooks surface via board state, not quest boards.
- NPC-initiated notifications via World Clock (delayed events, not instant pings).
- Tight-beam communication system (delayed messages, travel-time cost in Ticks).
- Dependencies: M21, M22
- Done criteria: NPCs have tag-driven stats that impact checks and manifest as board tokens.

---

### M25: Community & Sector Interaction [x]
Integrate community presence and sector-level interactions.
- Community presence in sectors: named residents, mood tags, daily pressure visible on board.
- Sector arrival/departure sequences with logistical weight (resource cost, World Clock Ticks).
- Hook generation from board state and track degradation — no hand-authored quest lists.
- Environmental events from sector track thresholds (Pillar 4: Anomalous events at outer-margin nodes).
- **Dangling Carrot implementation:** outer-margin nodes defined as mechanically locked; their visual presence in Mode A is established early. Specific Asset Cards or community conditions required for access.
- Dependencies: M24
- Done criteria: Interacting with sectors generates relevant hooks; outer-margin nodes are correctly gated.

---

### M26: Art Pipeline — Mode A Environment (Hand-Crafted Space) [x]
Produce Mode A 3D environment assets — the visual archaeological canvas.
- All Mode A structures (derelicts, abandoned solar arrays, decaying orbits) placed by hand; no procedural asset scattering.
- Assets convey history, tragic events, and spatial function through geometry, wear, and shadow — no floating text labels or in-world pop-ups.
- Early-game sector designed for claustrophobic containment (Pillar 5: Graduated Spatial Radius).
- Outer-margin nodes visually striking from a distance but mechanically locked (Pillar 4: Dangling Carrot).
- Anomalous outer-margin assets must be visually dissonant with the industrial baseline — no explanatory tags.
- Scope: core sector + 1 outer-margin teaser node.
- Dependencies: M22
- Done criteria: Core sector flyable, hand-placed, visually readable; outer-margin node visible and locked.

---

### M27: Art Pipeline — Mode B Visual Style [x]
Define and produce the base Mode B board visual language.
- Establish art direction for the simple 2D board (tokens, track displays, card UI).
- Style TBD pending board layout finalisation (M22).
- Lore-accurate visual vocabulary: zero-g references, industrial aesthetic, no corporate or military iconography.
- Dependencies: M22
- Done criteria: Base Mode B visual style defined and implemented for at least one location.

---

### M28: Asset Card Library (Lateral Progression Corpus) [x]
Define and implement the base set of Asset Cards as lateral expanders.
- Asset Cards expand mechanical verbs: traversal, anchoring, survival, interaction — not stat numbers.
- **Modification cards** (Transhumanism, Pillar 9): must carry explicit trade-off tags (what is gained, what is surrendered). No pure-bonus modification cards.
- Early-game cards constrain the player to a small operational radius. Late-game cards expand the Graduated Spatial Radius.
- Cards are physical board objects — visual design must communicate function at a glance.
- Dependencies: M21, M25
- Done criteria: Core card set implemented, trade-off tags present on all modification-type cards.

---

### M29: Playable Board Game MVP
Integrate all milestones into a 1-hour playable session.
- Integration milestone: wire M20–M28 into a playable 1-hour session.
- Player can dock, interact with NPCs on the board via Asset Cards, take 3d6 action checks, see board mutations.
- Mode A flight → Mode B board transitions work end-to-end.
- World Clock applies sector pressure over time (resource drain, NPC availability shifts).
- Outer-margin node visible in Mode A but inaccessible — player has clear long-term objective.
- Validation: manual playtest.
- Dependencies: M20, M21, M22, M23, M24, M25, M26, M27, M28
- Done criteria: Manual playtest of 1-hour session confirms lateral progression loop, community hooks, and Mode A visual archaeology all function as intended.
