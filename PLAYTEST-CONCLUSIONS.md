<!--
PROJECT: GDTLancer
MODULE: PLAYTEST-CONCLUSIONS.md
STATUS: [Level 2 - Design Validation]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_RULEBOOK.md; PLAYTEST-CHRONICLE.md; TRUTH_LORE-CONSTRAINTS.md
LOG_REF: 2026-07-09
-->

# GDTLancer — Playtest Conclusions (Session 1)

**Source:** 62 design observations from PLAYTEST-CHRONICLE.md
**Date:** 2026-07-09
**Status:** Active — conclusions apply to resumed playtest and inform future milestones

---

## 1. Core Identity (Confirmed)

The playtest confirmed the game's identity through iterative correction:

**The game is an automated playing board + GM assistant.** Simulation puts the world in motion. The player is the narrator. The system provides cues, tracks state, and enforces rules. The player imagines the scenes, authors NPC interactions, and judges their own progress.

This identity has three consequences for all design:

1. **System output must be structural, not narrative.** Tables, tags, one-line signals. No prose, no dialogue, no scene-setting.
2. **Player agency is narrative, not mechanical.** The player writes the story. The system tracks the board.
3. **Complexity lives in the simulation, not the UI.** The player sees a simple board. The simulation runs underneath.

---

## 2. Consolidated Findings

### 2.1 CRITICAL — Community-First Design (Resolved)

*Observations: #16, #17, #18, #19, #20, #21, #22, #23*

**Problem:** The initial play loop collapsed into a freelancer fetch-quest pattern. NPCs were task dispensers. Sectors were delivery terminals. Travel was commuting. Track changes felt like quest rewards.

**Resolution (already applied to rulebook):**
- §4.1: Pre-departure sequence with community cost cue, crew consent, supply allocation
- §4.2: Community-first arrival — named residents, daily pressure, mood before hooks
- §4.2: Hook chain prohibition — no same-NPC follow-up hooks
- §2.1: Named impact rule — track changes must name affected community members
- §13: Cue format only — no scenes, no dialogue, plain language

**Validation status:** Partially validated. Post-correction Korr arrival (#22) and environmental hooks (#23) showed improvement. More sector visits needed to confirm the format doesn't become formulaic.

---

### 2.2 HIGH — Player Narrative Authorship Model

*Observations: #4, #6, #8, #25, #32, #37, #38, #42*

**Principle:** The player constructs the narrative mentally from sparse cues. The system never generates prose, dialogue, or scene descriptions. Player authorship includes:
- Writing NPC interaction logs (§4.3)
- Defining NPC goals, backstory, and motivations (§2.2)
- Editing NPC tags to reflect narrative developments (§2.2)
- Declaring goals freely or with oracle seeds (§2.3)

**UX implication:** The game must resist the temptation to generate text. Every piece of generated prose displaces player imagination. The system's job is to present the board state clearly and get out of the way.

**Text register decision (from #8):** Two options were tested — passive voice ("Filters are needed at Korr") and narrator voice ("They ask you to deliver filters"). Both work. Recommendation: use **passive voice for hook/sector cues**, **narrator voice for bond/interpersonal cues**. This creates a natural register distinction without mixing modes.

---

### 2.3 HIGH — Free vs. Consequential Action Split

*Observations: #36, #56, #29*

Actions are divided into two categories:

| Free (no clock advance) | Consequential (costs an action) |
|---|---|
| Inspect NPC state | Commit to a hook |
| Write narrative log entries | Travel to another sector |
| Modify NPC tags | Resolve an Action Check |
| Ask oracle | Any uncertain/consequential intent |
| Read system signals | |
| Talk to NPCs | |
| Send tight-beam messages | |

**Risk:** Free actions could make the World Clock feel irrelevant if the player spends indefinite time on narrative without advancing the clock.

**Mitigation:** Free actions are inherently bounded — they don't produce mechanical progress. The player must eventually commit to a consequential action to advance goals, resolve hooks, or travel. The clock applies pressure through world degradation (#6 World Clock), not through counting free actions.

**Untested:** The cautious/risky approach split (§3) has not been exercised once in the playtest. First test will occur at Tick 4 (Kaelen's reply resolution).

---

### 2.4 HIGH — Goal System (§2.3)

*Observations: #24, #27, #28, #35, #57*

**Design:** Player-declared goals with ranks (MINOR/MAJOR/EPIC). Progress is player-judged, not system-evaluated. System reminds at World Clock ticks via anchor-matching. Cooldown of 2 ticks prevents trivial incrementing.

**What worked:** Oracle cue → goal declaration felt natural. The EPIC goal (outpost venture) immediately created multi-session tension. Unbiased oracle (#51) produced genuine obstacles (community resistance, resource shortage).

**What's untested:**
- Progress evaluation prompts (no tick has occurred since goal was declared)
- Cooldown pacing (is 2 ticks right?)
- Goal resolution roll (progress hasn't reached 10)
- Goal revision or abandonment

---

### 2.5 HIGH — Vessel Ownership & Economy

*Observations: #45, #46, #50, #52, #53, #54, #58*

**Confirmed:** Vessels are community assets (LORE-2.1). Player starts as assigned captain, not owner. The Oar belongs to Elace and is off-duty when no assignment is active.

**Consequence:** The player is grounded when off-duty. Vessel, crew, and tools are not in player context. This naturally creates a two-phase play style:
- **Assigned:** Player has vessel access. Travel and space-based actions available.
- **Station-bound:** Player is on foot. Only social, narrative, and community actions available.

**Five acquisition paths defined:** Salvage, community grant, barter chain, inheritance, refit commission. None are market-driven. All naturally EPIC-tier.

**Unresolved:** The barter/service economy model is undefined. How do communities value things? What obligations can a player take on? What is the first concrete step a POOR player can take toward vessel acquisition?

---

### 2.6 HIGH — NPC System

*Observations: #5, #7, #14, #31, #32, #33, #38, #39, #43, #48*

**NPC Interaction Model (§4.3):**
- Three-area UI: NPC card (portrait, tags as editable chips), signal feed (read-only), player log (append-only)
- Tags as tuples: system tag + narrative phrase
- NPC narrative goals: player-authored checkboxes with optional mechanical tags
- Goal completion triggers consequences (relocation, community change)

**NPC-Initiated Interaction:**
- World Clock evaluates bonded NPCs at each tick
- Generates "seek signals" for NPCs with active goals or state changes
- Not forced — player may respond or ignore

**Unsolved:** What threshold of NPC state change triggers a seek signal? How to prevent seek signals from feeling like spam?

---

### 2.7 MEDIUM — Oracle System

*Observations: #28, #29, #30, #35, #41, #44, #51*

**What works:** Five tables (Action, Theme, Focus, NPC Disposition, Conversation Seed) using d6×d6 or 1d6. Free action. Lore-constrained vocabulary. Oracle seeded goal creation and NPC interaction effectively.

**Critical rule (from #51):** All oracle rolls must use RNG. Hand-picked results defeat the purpose. Unbiased rolls produced dramatically better emergent narrative.

**Oracle UI concept:** Grid of categories. Click cell → word appears. Click again → reroll. Close → reset. No scrolling. Minimal.

**Untested:** Whether 36 entries per table sustain over many sessions or need expansion.

---

### 2.8 MEDIUM — Communication System (§4.4)

*Observations: #55, #59, #60, #61, #62*

**Design:** Send = free. Transit = 1 tick per sector distance. Arrival = system event + oracle + Action Check. Message queue tracks timing and status.

**Natural pacing:** The transit delay forces the player to do other things while waiting. This is good — it prevents communication from collapsing distance.

**Unsolved:**
- Should unread incoming messages affect the World Clock or just accumulate?
- Should there be a cap on simultaneous in-transit messages?
- Is Morale the right track for personal requests to allies?

---

### 2.9 MEDIUM — Mode A / Mode B Transition

*Observations: #9, #10, #11, #12, #13*

These observations concern the digital implementation's kinetic mode (3D flight). Not directly testable in tabletop, but the design principles are:

- Undocking triggers Mode A. Hard mode switch.
- Player flies to a departure point (~5-10 min). Not instant teleport.
- Navigation challenges scale to sector environment tag.
- Two event types: procedural (along path) and reactive (player-triggered in 3D).
- World Clock sub-ticks advance during flight — world doesn't pause.

**Deferred** to digital implementation milestone. Tabletop uses narrative travel abstraction.

---

### 2.10 LOW — Session Setup & Map

*Observations: #1, #2, #3, #47*

- Sector adjacency undefined — need explicit topology
- No "Session Zero" procedure — starting situation was manually constructed
- Bond proximity rule conflicts with session-start hooks
- World state lacks detail on discoverable features (wrecks, resources)

These are all solvable with a session setup checklist that includes adjacency table, starting hook generation, and world feature seeding.

---

### 2.11 LOW — Tool Trade-offs

*Observations: #15*

Reinforced Hull's cost (-1 maneuver) never surfaced because no maneuver check occurred. Invisible costs undercut the lateral tool design.

**Decision needed:** Surface tool trade-offs passively (visible modifier in HUD) or only when triggered?

---

## 3. UI/UX Assessment

### 3.1 Principle: Elegant Simplicity

Every feature must pass: **"Does this require the player to manage something, or does it help them imagine something?"** If the answer is "manage," it must be automated or removed.

### 3.2 Screen Inventory

The playtest identified these distinct UI contexts:

| Screen | Purpose | Complexity |
|---|---|---|
| **Sector View** | Community state, signals, available contacts, hooks | LOW — read-only, table format |
| **NPC Card** | Portrait, tags (editable chips), signal feed, player log | MEDIUM — inline editing, append log |
| **Oracle** | Category grid, click-to-roll | LOW — one interaction pattern |
| **Action Tray** | Available options (A/B/C/D + general talk) | LOW — list with labels |
| **Character Sheet** | Tracks, bonds, goals, message queue, vessel status | MEDIUM — mostly read-only, goals editable |
| **Pre-departure** | Community cost, crew consent, supply allocation | LOW — confirmation sequence |
| **Travel** | Encounter roll, supply tick, World Clock | LOW — automated in digital |
| **Message Queue** | Pending/arrived/resolved messages | LOW — small table |

### 3.3 Synergy Map — What Connects to What

```
Player Log ← Oracle cues ← Oracle Grid
     ↓
NPC Card (tags) → Simulation → World Clock → Seek Signals → Signal Feed
     ↓                                              ↓
Goal Anchor ← Goal Progress Prompt ← World Clock Tick
     ↓
Message Queue ← Tight-beam Send → Transit → Arrival Event → Action Check
```

**Key synergy:** The World Clock is the hub. It drives:
- Sector tag degradation
- NPC off-screen actions (influenced by NPC goal tags)
- Goal progress prompts (anchor-matching)
- Message arrival events
- Seek signal generation

Everything flows through the tick. This is elegant — one clock drives all dynamic behavior.

### 3.4 Feature Creep Risks

| Feature | Risk | Mitigation |
|---|---|---|
| NPC tag editing | Could feel like database management | Keep chips inline on card. No separate editor screen. Max ~5 tags per NPC. |
| Player log | Could become a writing chore | Entirely optional. System never requires specific log content. |
| Message queue | Could grow unwieldy with many NPCs | Cap at ~3 simultaneous messages? Or let digital UI handle it with filters. |
| Goal progress evaluation | Could become a repetitive prompt | Cooldown (2 ticks). Not mandatory. Player can skip. |
| NPC narrative goals | Could proliferate across many NPCs | Only for bonded NPCs. Checkbox-style, not progress-tracked. |
| Oracle tables | Could expand into sprawling reference material | Keep to core tables (5 current). Expand only when play surfaces a gap. |

### 3.5 UX Flow Assessment

**What feels smooth:**
- Oracle → goal creation (cue words → player interpretation → declaration)
- Free action classification (clear boundary: narrative is free, commitment is not)
- Community-first arrival (sector state before hooks)
- Signal feed concept (read-only, system-generated, always visible)

**What feels friction-prone:**
- Switching from "reading board state" to "authoring narrative" — the transition is undefined. When does the player decide to write? What prompts them? In tabletop this is natural conversation; in digital it needs a clear UI affordance.
- Tag editing during interaction — if the player is mid-conversation and realizes they need to change a tag, the edit should be immediate and undoable. No confirmation dialog.
- Message queue tracking in tabletop — a manual table that grows. Digital implementation absorbs this, but tabletop players will need a simple card or sheet format.

---

## 4. Open Questions

### 4.1 Core Mechanics

1. **Cautious/Risky split untested.** The central mechanical decision has not been exercised. First test at Tick 4 (Kaelen reply). Does the choice feel like a real dilemma?
2. **Goal progress pacing.** Is +1 per relevant success right for MAJOR? Is +1 on Strong Success/Breakthrough only right for EPIC? No data yet.
3. **Goal cooldown interval.** 2 ticks between evaluations — too long? Too short? Needs play data.
4. **Track used for ally requests.** Is Morale the right track for personal requests to allies? Should bond strength be a modifier? Or should it be a separate "social" check?

### 4.2 Economy & Ownership

5. **Barter/service economy model undefined.** How do communities value things? What do they trade? What obligations can a player take on? This is foundational but missing.
6. **First step toward vessel acquisition.** What can a POOR player with no vessel actually do to begin the EPIC-tier acquisition process? The system needs at least one visible starting thread.
7. **Vessel reassignment.** If The Oar is reassigned while Silas is off-duty, is this a World Clock event? Can the player contest it? What are the narrative consequences?
8. **Captain assignment authority.** Who grants vessel assignments — community elders? Council? How is this mechanized?

### 4.3 NPC & Communication

9. **Seek signal threshold.** What NPC state change triggers a seek signal? Every tag change? Only significant ones? Need criteria.
10. **Incoming message accumulation.** Should unread messages affect the World Clock (pressure) or just pile up until read?
11. **Simultaneous message cap.** Should there be a limit on in-transit messages? Or let complexity self-regulate?
12. **NPC tag limit.** Maximum tags per NPC? Unlimited risks clutter. 3-5 seems natural.

### 4.4 Simulation Layer

13. **Simulation rework scope.** Current CA is Freelancer-shaped (individual agents, arbitrary trade). Must become group-focused, contract-based, social, community-centric. What is the minimum viable rework?
14. **NPC goal tags → simulation effects.** How do tags like `exploration` actually modify World Clock processing? What off-screen actions do they generate?
15. **Sector creation mechanic.** When a goal involves founding an outpost, the player defines the new sector. Tabletop: player names it and sets tags. Digital: needs a UI form. When does this happen?

### 4.5 Digital Implementation (Deferred)

16. **Mode A departure point.** What is the departure point in lore terms? Nav beacon? Safe distance? Jump corridor?
17. **Mode A navigation events.** What challenges scale to environment tags? HARSH: debris, drag zones, failed beacons. STANDARD: routine clearance. Need a definitive list.
18. **Mode A sub-tick cadence.** Time-based or distance-based? Visible to player or silent?
19. **Mode A → Mode B event bridge.** How does a kinetic action (docking with derelict, scanning object) open a narrative window?
20. **Tool trade-off visibility.** Passive (always visible modifier) vs. triggered (only when relevant)? Invisible costs undercut design intent.
21. **Oracle UI prototype.** Category grid, click-to-roll. Needs validation for speed and mid-interaction usability.

### 4.6 Session Management

22. **Session Zero procedure.** How to generate starting situation? Roll on tables? Auto-trigger bond events? Seed world features?
23. **Sector adjacency.** Need explicit topology — table or diagram. Currently improvised.
24. **Community-first format sustainability.** Does the arrival format become formulaic after many visits? Need variation without losing purpose.
25. **Text register standardization.** Passive voice for hooks, narrator voice for bonds. Confirm and document as a firm rule.

---

## 5. Validated Design Decisions (Locked)

These decisions emerged from play and should not be revisited without new contradicting evidence:

| Decision | Source | Rationale |
|---|---|---|
| Cues, not scenes | #4, #6, #25 | Player imagination > generated prose |
| Community-first arrival | #16, #17, #22 | Sectors must feel like homes |
| No hook chains | #20 | Prevents quest-loop patterns |
| Named impact on tracks | #19 | Track changes = community consequences |
| Pre-departure sequence | #18, #26 | Travel must have weight |
| Player-declared goals | #24, #28 | Full agency, Ironsworn-inspired |
| Player-judged progress | #27 | System reminds, player evaluates |
| Oracle as free action | #29 | Meta-tool, not character action |
| Unbiased oracle rolls (RNG) | #51 | Hand-picked results kill emergence |
| Free NPC interaction | #36 | Narrative authorship is not a cost |
| Tags as tuples | #43 | System tag + display phrase |
| Vessels are community assets | #45 | LORE-2.1, not personal property |
| Player authorship ungated | #42 | Always available, not bond-level locked |

---

## 6. Priority Action Items (When Resuming Playtest)

| Priority | Item | Depends on |
|---|---|---|
| **P0** | Test cautious/risky Action Check (Tick 4, Kaelen reply) | Tick advancement |
| **P0** | Test goal progress evaluation prompt (after 2 ticks since declaration) | World Clock tick |
| **P1** | Define at least one concrete vessel acquisition starting step | Economy model sketch |
| **P1** | Establish sector adjacency topology | Session map |
| **P1** | Test NPC-initiated seek signals at next World Clock tick | Tick advancement |
| **P2** | Sketch barter/service economy primitives | Lore discussion |
| **P2** | Define captain assignment authority | Community structure |
| **P2** | Test community-first arrival at a third sector (avoid formulaic) | Travel action |
| **P3** | Expand oracle tables if current ones feel thin | Extended play |
| **P3** | Design Session Zero procedure | Post-playtest |
