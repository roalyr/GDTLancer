<!--
PROJECT: GDTLancer
MODULE: PLAYTEST-CHRONICLE.md
STATUS: [Level 2 - Design Validation]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: If asked to run or resume the playtest, read this file fully before acting. This file is the single source of truth for the session state and GM procedure. Do not improvise mechanics — apply the rules exactly as specified in TRUTH_RULEBOOK.md. Log every GM observation in the Design Observations section. CRITICAL: The GM role is a board-state reporter, not a storyteller. Every output must be tables and one-line signals only. Prose narration, scene-setting, and NPC dialogue are PROHIBITED in all GM output.
TRUTH_LINK: TRUTH_RULEBOOK.md; TRUTH_LORE-CONSTRAINTS.md; TRUTH_MVP_CORE.md; TRUTH_CONTENT-CREATION-MANUAL.md §9
LOG_REF: 2026-07-10 01:57:00
-->

# GDTLancer — Playtest Chronicle

**Purpose:** MILESTONE_19_B — Tabletop playtest validation of TRUTH_RULEBOOK.md mechanics.
**Goal of this test:** Determine whether the rulebook procedures (tracks, bonds, world clock, cautious/risky split, sector tags, encounter sources) produce *moments where emergent narrative pressure arises naturally from the system*, without the GM writing fiction. The system provides cues. The player declares intent and approach. The GM executes rules and logs design observations.
**Session Date:** 2026-07-01
**Status:** In Progress — Resumed after mid-session design review. TRUTH_RULEBOOK.md revised (§2.1, §4.1, §4.2, §12, §13). Corrections applied from Action 4 onward.

---

## AGENT RESUME INSTRUCTIONS

> **THIS SECTION IS THE ONLY AUTHORITATIVE PROCEDURE FOR THE GM ROLE. All steps are mandatory. Deviation is an error, not a stylistic choice.**

When asked to resume or run this playtest, do the following in order:

1. **Read this file fully.** It contains all current state. Do not rely on conversation history.
2. **Read TRUTH_RULEBOOK.md.** All procedures must be applied exactly as written. Cross-reference section numbers when making rulings.
3. **Read TRUTH_LORE-CONSTRAINTS.md and TRUTH_CONTENT-CREATION-MANUAL.md §9.** Use jargon creole only in flavor text. GM cues use plain language.
4. **Identify the current phase** from `SESSION STATE` below and the last entry in `THE CHRONICLE`.
5. **Present board state only — never scenes, narration, or dialogue.** The GM role is a mechanical board-state reporter. Output is tables, one-line signals, and structured field lists. Nothing else.
6. **Wait for the player to declare intent** (per §12 Step 2a). Then execute the procedure mechanically and log the result.
7. **After every action, append** a `[GM NOTE]` to `DESIGN OBSERVATIONS` if the procedure produced an unexpected result, a flat result, a design question, or a notable emergent moment.
8. **Update all state fields** in this file after every action.
9. **After every 2 actions**, execute the World Clock tick procedure (§6) and update `WORLD STATE`.
10. **At session end**, complete `SESSION DEBRIEF` and update STRATEGICAL-TODO.md and SESSION-LOG.md.
11. **Cue format reference (mandatory — no substitutions):**
    - Location: one line (sector name + tags)
    - Present: NPC name · role · bond strength
    - Signal: what the NPC/situation implies in one plain sentence — no adjectives, no emotion, no interpretation beyond the tag or track state
    - Hooks: markdown table with destination, one-word pressure
    - Prompt: `"What does [character] do?"`
12. **Oracle rolls must be unbiased.** Run `python3 -c "import random; print(random.randint(1,6), random.randint(1,6))"` or equivalent RNG. Never hand-pick results to fit the narrative. The oracle's value is in producing unexpected cues. Bias-corrected reroll is mandatory if GM realizes a result was hand-picked.

---

### FORBIDDEN OUTPUT — THE GM MUST NEVER PRODUCE ANY OF THE FOLLOWING

These are binding prohibitions. Violation means the output must be discarded and regenerated in the correct format.

| Category | Forbidden | Permitted substitute |
|---|---|---|
| Scene narration | "The docking bay smells of rust and old fuel. A lone figure moves through the shadows." | `Elace Station · MODERATE · PATROLLED · STANDARD` |
| NPC dialogue | "Maeve looks up and says: 'We can't afford this venture, Silas.'" | `Signal: Maeve — community resources low. Elders cautious.` |
| NPC emotion prose | "Vera seems tired and grateful, though worry lines her face." | `Vera · Out-Clan · STABLE` + `Signal: Delivery received. Shift resumes.` |
| Descriptive atmosphere | "Outside the viewport, the stars drift slowly past like scattered salt." | *(omit entirely — atmosphere is player imagination)* |
| Summarizing narrative | "After a long flight, Silas finally arrives at Korr Anchorage, worn but determined." | `Action result: Travel complete. Korr Anchorage — Moon · DEPLETED · CONTESTED · HARSH.` |
| Editorializing | "This was a meaningful moment — Silas proved his worth to the community." | `[GM NOTE: Track shift. Named impact: Dallen's family supplied.] Wealth [5/10] → [6/10].` |
| Invented NPC thoughts | "Kaelen must be worried by now — he's sent two messages." | `M1 in transit. Kaelen: 2 unacknowledged tight-beams. Orin's Reach: Security CONTESTED.` |
| GM-authored backstory | "Vera grew up on Korr and knows every vent shaft personally." | *(player authors NPC backstory — §2.2. GM does not.)* |
| Jargon-injected cues | "The burn-water reserves are running thin in the lower-decks of the scow." | `Supplies: ADEQUATE [2/10]. Note: HARSH environment drain active.` |
| Prescriptive player guidance | "You should probably head to Veyra Hub — the parts are more likely to be there." | *(present hooks with tags; never recommend action)* |

**Self-check before every output:** Before writing any response, the agent must verify:
- [ ] Does this output contain any continuous prose sentences describing scene, mood, or atmosphere? → STRIP.
- [ ] Does this output contain NPC dialogue (quoted speech)? → STRIP.
- [ ] Does this output contain adjectives describing an NPC's emotional state written as narration? → STRIP.
- [ ] Does this output contain GM-invented backstory or interpretation of NPC intent? → STRIP.
- [ ] Does this output contain oracle results that were not generated by RNG? → REROLL.
- [ ] Does this output use jargon creole in cue fields (not flavor-text)? → REPLACE with plain language.

If all six checks pass, the output is valid. If any fail, regenerate.

---

## SESSION STATE

```
PHASE:            Encounter Phase (§4.2)
CURRENT_PHASE:    Elace Station — Exploring on foot
LOCATION:         Elace Station
WORLD_CLOCK:      5 actions / 2 ticks (action 1 of 2 in cycle)
ACTIONS_TO_TICK:  1
NEXT_STEP:        Player interprets exploration cues and declares next action
```

---

## CHARACTER SHEET

```
NAME:   Silas
VESSEL: The Oar (worn utility scow)
        Status: community-owned / "Community vessel" — assigned to Elace Station
        Role:   Silas is assigned captain, not owner
        Availability: ASSIGNED / ON-DUTY — cleared for venture to Orin's Reach
        Note: Vessel and crew are now in player context
TOOL:   Reinforced Hull (aboard The Oar — not accessible when off-duty)
        - Effect: Ignore first HARSH environment penalty per sector
        - Trade-off: -1 to maneuver checks

TRACKS:
  Health:   FIT       [5/10]  Modifier: 0
  Wealth:   POOR      [5/10]  Modifier: 0  (-1 elder complication)
  Morale:   STEADY    [5/10]  Modifier: 0
  Supplies: ADEQUATE  [2/10]  Modifier: 0  (-1 transit Korr→Elace)

BONDS:
  1. Maeve   | Kin                | STABLE (+0) | Home: Elace Station
     NPC GOALS:
       ☐ Establish a new outpost in unexplored space
         Tags: exploration / "Conducting exploration"
               prosperity / "Seeking prosperity"
       ☐ Start a family-clan at the new settlement
     On completion: Maeve relocates to new sector. Bond context shifts.
  2. Kaelen  | Professional Ally  | STABLE (+0) | Home: Orin's Reach
  3. Vera    | Out-Clan Contact   | STABLE (+0) | Home: Korr Anchorage

CREW (assigned to The Oar — off-duty, at Elace dock):
  Jonas  (Navigator)    — STEADY — at station
  Rhea   (Mechanic)     — STEADY — at station
  Marek  (Cargo Hand)   — STEADY — at station
  Note: Crew may be reassigned to another captain while player is off-duty

GOALS:
  1. Help Maeve establish a new outpost in unexplored space
     Anchor: Maeve (Kin)
     Rank:   EPIC
     Progress: [0/10]
     Cooldown: 0 ticks (eligible for evaluation)

MESSAGE QUEUE:
  | ID | To     | Sent  | Arrives | Subject                          | Status  |
  | M1 | Kaelen | Tick 2| Tick 4  | Outpost venture — need support   | PENDING |
  Note: Elace → Orin's Reach = 2 sectors = 2 ticks transit
```

---

## WORLD STATE

### Sector Map

| Sector | Type | Economy | Security | Environment | Status |
|---|---|---|---|---|---|
| Elace Station | Planet | MODERATE | PATROLLED | STANDARD | Active — Player Location |
| Korr Anchorage | Moon | DEPLETED | CONTESTED | HARSH | Active · Economy degraded (Tick 1) |
| Veyra Hub | Star | RICH | SECURE | HOSPITABLE | Active |
| The Scatter | Field | DEPLETED | LAWLESS | HARSH | Active |
| Orin's Reach | Deep Space | POOR | CONTESTED | STANDARD | Active — Security degraded (Tick 2) |

> `[OPEN DESIGN QUESTION]` Adjacency/routing topology is undefined in §5.2. For this session, assumed linear route: Elace → Orin's Reach → Korr Anchorage. Veyra Hub and The Scatter are branch destinations. This assumption must be validated by the architect and formalized in a future rulebook revision.

### Active Narrative Template

```
LOCATION:  Elace Station (Planet / MODERATE / PATROLLED / STANDARD)
TEMPLATE:  database/registry/narrative_templates/default.tres
TITLE:     "Broad-band Static"
BODY:      "The watchkeep reports no active signals. Only the hum of hull-sweat
            and low-tech radio static on the regional channel."
```

---

## THE CHRONICLE

### Tick 0 — Session Open

**World Clock:** 0 actions / 0 ticks.

**Setup confirmed per §12 Step 1:**
- Map: 5 sectors, tags as above.
- Character: tracks at starting values, 3 bonds, Reinforced Hull tool, 3 crew all STEADY.
- Home sector: Elace Station. Starting situation: two active hooks.

**Active scenario hooks (source: §4.2 encounter sources — character interaction + bond event):**
- Hook A (Bond — Vera, Out-Clan, Korr Anchorage): Coolant filters in cargo hold, bound for Korr Anchorage. Community life-support pressure.
- Hook B (Bond — Kaelen, Professional Ally, Orin's Reach): Tight-beam report of a cold-drifting scow near Orin's Reach. Possible salvage.

> `[GM NOTE — SETUP]` The rulebook (§12 Step 1) specifies "Home sector, starting situation" but provides no procedure for generating the starting situation. Both hooks above were constructed by the GM to seed the session. **Design question: Does the rulebook need a "Session Zero" procedure to generate the opening situation from bond events or sector tags procedurally?**

> `[GM NOTE — SETUP]` §2.2 states bond events require the bonded NPC to be "in same or adjacent sector." Neither Kaelen (Orin's Reach) nor Vera (Korr Anchorage) is in the home sector. Strictly speaking, their hooks should not be available at session open unless the GM treats initial setup as exempt from this rule. **Design question: Should starting hooks be exempt from the proximity requirement, or should the session always open with the Kin bond (Maeve, local) as the only available hook?**

---

### Action 1 — Interact: Maeve (Elace Station)

**World Clock:** 1 action / 0 ticks.

**Elace Station**

| Present | Role | Bond |
|---|---|---|
| Maeve | Kin | STABLE |

**Signals:**
- Coolant filters still in cargo. Someone's family works intake at Korr. Backup cooling there is patched, holding — barely.
- Aware of the Kaelen tight-beam. No pressure applied.

**Active hooks:**

| Hook | Destination | Pressure |
|---|---|---|
| A — Vera | Korr Anchorage | Life-support need. Time implied. |
| B — Kaelen | Orin's Reach | Cold-drifting scow. Status unknown. |

*No Action Check required. No tracks changed. No bond shift.*

> `[GM NOTE — ACTION 1]` Third-party stakes (family member at Korr) emerged through NPC signal without GM writing fiction. System working as intended — pressure arose from bond context, not authored drama. Emergence vector confirmed.

> `[GM NOTE — ACTION 1 — PLAYER FEEDBACK]` Player flagged that GM-produced prose and voiced NPC dialogue is counterproductive. Correct output is sparse cues that engage player imagination, not narrated scenes. The player constructs the interaction mentally. GM rewrote the output in cue format. **This is a fundamental revision to §13 LLM-GM Guidelines and the Mode B template design.** See Design Observations #4, #5, #6.

---

### Action 2 — Respond to Maeve: commit to Hook A

**World Clock:** 2 actions / 0 ticks (tick pending).

**Elace Station**

| Present | Role | Bond |
|---|---|---|
| Maeve | Kin | STABLE |

**Decision:** Filters to Korr Anchorage — committed.

| Result | Detail |
|---|---|
| Hook A | Active. Departure committed. |
| Maeve bond | STABLE — holds. Breaking this later strains it. |
| Hook B | Open. Kaelen has sent a second tight-beam. Unacknowledged. |

*No Action Check required. No tracks changed.*

> `[GM NOTE — ACTION 2]` Committing to a hook without a roll is the correct mechanical state — no uncertainty in the decision itself, only in execution. Bond weight is implicit. System is silent here; pressure lives in the player's memory of the commitment. Works as intended.

> `[GM NOTE — ACTION 2 — PLAYER FEEDBACK]` Player described Mode B dialogue window design spec: (1) character portrait area; (2) dedicated prompt/hook area with passive-voice or narrator-voice one-liners — e.g. *"Coolant filters are needed at Korr Anchorage"* or *"They ask you to deliver the filters"*; (3) action option area with labelled choices (A/B/C/D) plus a persistent **general talk** category for interpersonal topics not tied to active hooks. Player offered two acceptable text registers — passive voice (systemic, impersonal) or narrator voice (warmer, implies NPC agency) — and asked which to standardise. See Design Observations #7 and #8.

---

### World Clock — Tick 1

**World Clock:** 2 actions / 1 tick.

| Step | Sector | Tag | Change |
|---|---|---|---|
| Tag shift | Korr Anchorage | Economy | POOR → DEPLETED |
| NPC off-screen | Kaelen (Orin's Reach) | — | Second tight-beam sent. No response yet. |
| Passive drain | — | — | None (Elace Station · STANDARD) |

> `[GM NOTE — TICK 1]` Korr economy degraded while the committed cargo sits in the hold. Pressure increased without player action — World Clock functioning as designed. The second Kaelen message also adds ambient tension without forcing the player's hand. Both effects feel appropriate.

---

**§12 Step 2a — What does Silas do?**

---

### Action 3 — Travel: Elace Station → Korr Anchorage

**World Clock:** 3 actions / 1 tick (action 1 of 2, new cycle).

| Event | Result |
|---|---|
| Supplies drain | ADEQUATE [5/10] → [4/10] |
| HARSH penalty | Waived — Reinforced Hull (first use this sector) |
| Encounter roll | 1d6 = 3 — no encounter in transit |
| World Clock | Action 1 / 2 (post-Tick 1 reset) |

**Arrival: Korr Anchorage (Moon · DEPLETED · CONTESTED · HARSH)**

| Present | Role | Bond |
|---|---|---|
| Vera | Out-Clan Contact | STABLE |

**Signals:**
- Filters in cargo. Intake crew waiting.
- Economy DEPLETED — worse than when departure was committed.
- Security CONTESTED — watchkeep thin and tense.

**Active hooks:**

| Hook | Status | Pressure |
|---|---|---|
| A — Deliver filters to Vera | At destination | Immediate. Economy already DEPLETED. |
| B — Kaelen / Orin's Reach | Open | Second tight-beam unacknowledged. |

*Mode B active at Korr Anchorage.*

> `[GM NOTE — ACTION 3]` Reinforced Hull absorbed the HARSH penalty cleanly — tool trade-off is invisible here (no maneuver check was needed in transit). The tool's cost hasn't surfaced yet; flagging for when a maneuver check occurs. Economy degradation at Korr between commitment and arrival creates meaningful pressure — player chose the right hook at the right time.

> `[GM NOTE — ACTION 3 — PLAYER FEEDBACK]` Player described Mode A design vision for travel. Five observations logged (#9–13).

---

**§12 Step 2a — What does Silas do?**

---

### Action 4 — Deliver filters to Vera (Hook A · Cautious)

**World Clock:** 4 actions / 1 tick (action 2 of 2 · tick follows).

**Roll:** 3d6 = 4 + 3 + 5 = 12 − 1 (modifier) = **11 → Success (Cautious) · Wealth +1**

| Track | Change |
|---|---|
| Wealth | POOR [5/10] → POOR [6/10] (+1) |

| Bond | Change |
|---|---|
| Vera (Out-Clan · STABLE) | Holds. Delivery fulfilled — progress toward DEEP noted. No tier shift. |
| Maeve (Kin · STABLE) | Holds. Commitment kept. |

**Hook A — resolved.**

**New signal from Vera:** Main pump seal on the processing tunnel is failing. Filters bought time. Parts are a separate matter.

**Open hooks:**

| Hook | Status | Pressure |
|---|---|---|
| A — Deliver filters | ✓ Resolved | — |
| A.1 — Pump seal / Korr | New · unconfirmed | Parts needed. Source unknown. |
| B — Kaelen / Orin's Reach | Open | Tight-beam ×2. Unacknowledged. Security now CONTESTED. |

> `[GM NOTE — ACTION 4]` Cautious roll on a −1 modifier still landed Success — the bell curve protected the player. Delivery resolved cleanly. A follow-up hook (pump seal) emerged organically from Vera's signal without GM inventing a quest. Second-order emergence working. The Vera bond is making progress without requiring a dramatic moment — sustained reliability as a bond-building mechanic is functioning.

> `[GM NOTE — ACTION 4 — PLAYER FEEDBACK]` Player described hook resolution as a dialogue option within the Mode B NPC window, not a separate delivery screen. Flow: dock → Mode B opens with Vera → action tray shows task option alongside general talk. Active hooks with the current NPC appear as a highlighted option in the action tray, not a separate UI state. Logging as Design Observation #14.

---

### World Clock — Tick 2

**World Clock:** 4 actions / 2 ticks.

| Step | Sector | Tag | Change |
|---|---|---|---|
| Tag shift | Orin's Reach | Security | PATROLLED → CONTESTED |
| NPC off-screen | Kaelen (Orin's Reach) | — | Unidentified vessel spotted near drifting scow. Word reaching Korr via relay. |
| Passive drain | Korr Anchorage | Supplies | ADEQUATE [4/10] → [3/10] (HARSH environment · Reinforced Hull already spent) |

> `[GM NOTE — TICK 2]` Orin's Reach security degraded while Hook B is unacknowledged — the neglected thread is escalating. Unidentified vessel near the scow adds genuine threat weight without GM authoring danger. World Clock is producing pressure that feels earned, not arbitrary. Supplies are now at [3/10] — approaching SCARCE tier boundary at [0/10] / tier shift. Worth monitoring.

---

**§12 Step 2a — What does Silas do?**

---

### ⚠ MID-SESSION DESIGN REVIEW — Truth Deviation

**Triggered by:** Player feedback after Action 4.
**Severity:** Structural. The play loop has collapsed into a freelancer fetch-quest pattern.

**Diagnosis — what went wrong:**

The session produced the following loop: *Receive hook from NPC → travel to destination → deliver goods → receive next hook from same NPC*. This is the Freelancer/task-runner pattern that the Three Pillars (TRUTH_LORE-CONSTRAINTS.md) exist to prevent.

| Session event | Truth violated | How |
|---|---|---|
| Maeve surfaced hooks as selectable tasks | LORE-1.3 (Human Nucleus) | She functioned as a quest-giver, not as kin with her own life and concerns |
| Travel was a one-roll abstraction | LORE-2.3 (Weight of Travel) | No preparation, no crew input, no logistical sacrifice — commuting |
| Korr Anchorage had no visible community | LORE-1.2 (Hyper-Localized Communities) | Station was a delivery terminal, not a home where people live |
| Wealth +1 for delivery completion | LORE-3.1 (No Gear-Score Grinding) | Track increment as task reward is a fetch-quest reward pattern |
| Hook A.1 appeared from Vera immediately | LORE-3.3 (Community-Centric Progression) | Quest-chain design. Same NPC, same conversation, next errand. |

**Root cause:** The GM procedure (§12 Steps 2a–d) is action→check→track. It contains no community-awareness step. It does not require the GM to present the community, name affected people, surface departure costs, or prevent same-NPC hook chains. The procedure naturally produces task loops because it was designed as a generic action resolution flow.

**Proposed structural corrections (for architect review):**

1. **Community presence requirement (§12 / §13):** Every sector arrival and every action must name at least one non-bonded community member who is affected. The player should always see who else lives here.
2. **Departure-as-community-cost (§4.1):** Leaving a sector should trigger a community cost cue — who loses something when Silas leaves? What is left undone? Even if it's a single line: "Maeve's seal-checks won't get done while you're gone."
3. **Crew consent step (§7 / §4.1):** Before undocking, crew should have a visible reaction. Not a check — a cue. "Jonas notes the route is long. Rhea asks about spare parts." This adds weight without adding rolls.
4. **Arrival = community first, hooks second (§4.2):** When entering a sector, present the community state before any hook options. Who lives here, what's the daily pressure, what's the mood. Hooks emerge from that, not the other way around.
5. **No same-NPC immediate hook chains (§4.2):** A resolved hook cannot produce a follow-up hook from the same NPC in the same encounter. New hooks should emerge from the community state at the next World Clock tick, or from a different source (environmental event, different NPC, off-screen NPC action).
6. **Track changes require named impact (§2.1):** Wealth +1 should not feel like a quest reward. The track shift should be narrated as a community-level change: "Korr's intake crew has what they need. Silas's standing among the dock families improved."

**Session state:** PAUSED pending architect review of corrections. Play may resume with revised GM procedure or continue with corrections applied informally.

---

### RULEBOOK REVISION APPLIED

**TRUTH_RULEBOOK.md updated.** Sections revised: §2.1 (named impact rule), §4.1 (pre-departure sequence), §4.2 (arrival sequence + hook chain prohibition), §12 (community steps in play loop), §13 (cue format, community rules, world and tone).

Session resumes from Hook A resolution at Korr Anchorage. Hook A.1 (pump seal from Vera) is **withdrawn** — it violated the hook chain prohibition. Hooks are re-derived from community state.

---

### Post-Review: Community-First Arrival — Korr Anchorage

*Applying revised §4.2 arrival sequence.*

**World Clock:** 4 actions / 2 ticks.

**Korr Anchorage** (Moon · DEPLETED · CONTESTED · HARSH)

**Community:**

| Name | Role |
|---|---|
| Vera | Out-Clan Contact · STABLE bond |
| Dallen | Intake vent worker. His youngest runs backup cooling shifts. |
| Serin | Dock elder. Manages berth allocation and community stores. |

**Daily pressure:** Processing tunnels running on patched equipment. Economy DEPLETED — community stores low, trade leverage gone. People are rationing. Watchkeep patrols thin. Two scuffles over berth priority this week.

**Mood:** Tense. Grateful for the filters but aware it solved one problem among many.

**Track impact (revised §2.1):** Dallen's family has the filters. Intake pressure eased. Silas's standing among the dock families improved. *(Wealth POOR [5/10] → [6/10] — named impact replaces bare "+1.")*

**Signals:**
- Serin has been asking whether any vessel might run parts from Veyra Hub. The pump seal is community knowledge — not Vera's personal request.
- Vera is relieved but not offering tasks. She's going back to her shift.
- A vessel berthed here last week left without clearing dock fees. Serin is frustrated. The fees were in stored water.

**Open hooks (community-sourced):**

| Hook | Source | Pressure |
|---|---|---|
| Community need — pump seal parts | Serin / community | Parts likely at Veyra Hub (RICH). Not assigned to anyone. |
| Dock-fee dispute — missing vessel | Serin / environmental | Water stores short. Community tension. |
| B — Kaelen / Orin's Reach | Bond event | Tight-beam ×2. Security now CONTESTED. Unknown vessel near scow. |

> `[GM NOTE — POST-REVIEW]` Community-first arrival changes the feel immediately. The player now sees people before hooks. Hooks emerge from Serin (non-bonded elder) and the community situation, not from Vera handing out tasks. The dock-fee dispute is an environmental event that the player didn't cause and doesn't have to solve — but it's visible and creates ambient texture. This is closer to the Three Pillars.

> `[GM NOTE — POST-REVIEW]` Hook A.1 (pump seal from Vera) was the exact quest-chain pattern flagged in the design review. Replacing it with Serin as source changes the dynamic: the community needs something, not one NPC dispensing a follow-up. The player can engage or not. This feels right.

---

**§12 Step 2a — What does Silas do?**

---

### Action 5 — Travel: Korr Anchorage → Elace Station

**§4.1 Pre-departure — Korr Anchorage:**

| Step | Cue |
|---|---|
| Community cost | Serin loses the only vessel at dock. Parts run unresolved. |
| Crew | Jonas: route familiar. Rhea: no concerns. Marek: hold empty. |
| Supplies | ADEQUATE [3/10] → [2/10] (−1 transit). Confirmed. |

**Travel:** 1d6 = 5 — no encounter.

---

### §4.2 Arrival — Elace Station (Planet · MODERATE · PATROLLED · STANDARD)

**World Clock:** 5 actions / 2 ticks.

**Community:**

| Name | Role |
|---|---|
| Maeve | Kin · STABLE |
| Harun | Berth supervisor |

**Mood:** Steady. No crises.

**Signals:**
- Maeve is on the docking ring. Available.
- Harun notes the berth was open — no traffic this week.

**No goal declared.** This is the gap (§2.3). Maeve is the right anchor.

> `[GM NOTE — ACTION 5]` Pre-departure at Korr surfaced Serin losing the only vessel at dock — a community cost cue that makes leaving feel consequential. The revised §4.1 is working. Travel itself is still a single roll; the weight is in the departure, not the transit.

> `[GM NOTE — ACTION 5 — PLAYER FEEDBACK]` Player identified missing goal mechanic. No long-term direction existed. Added §2.3 Goals to rulebook (Ironsworn-inspired, renamed to "goals" for pragmatism). Goals are player-declared, community/bond-anchored, with progress tracks and MINOR/MAJOR/EPIC ranks. This is a structural gap in the original rulebook — without goals, play drifts into reactive task-running.

---

**§2.3 — Goal declaration (free action: oracle consulted)**

**TRUTH_RULEBOOK.md §2.3 revised:** Anchor-based prompted reflection with cooldown. Player judges progress. System reminds at World Clock ticks. Cooldown = 2 ticks between evaluations.

**TRUTH-ORACLES.md created.** Three core tables: Action (36), Theme (36), Focus (36). d6×d6. Free action.

**Oracle rolls:**

| Table | Roll | Result |
|---|---|---|
| Action | 4,4 | **Support** |
| Theme | 1,6 | **Kinship** |
| Focus | 1,2 | **Community** |

**Oracle cue:** Support · Kinship · Community

**Awaiting player: write goal statement using these cues (or reroll / write freely).**

---

### Goal Declaration — Silas

**Oracle cue:** Support · Kinship · Community

**Player declares (free action):**

| Field | Value |
|---|---|
| Statement | Help Maeve establish a new outpost in unexplored space |
| Anchor | Maeve (Kin · STABLE) |
| Rank | EPIC |
| Progress | 0/10 |

**Player authors Maeve's NPC narrative goals (§2.2):**

| Goal | Tags | Status |
|---|---|---|
| Establish a new outpost in unexplored space | `exploration`, `prosperity` | ☐ Open |
| Start a family-clan at the new settlement | | ☐ Open |

On completion: Maeve relocates to the new sector. Bond context shifts. Player defines the new sector (name, type, tags) at that time.

> `[GM NOTE — GOAL DECLARATION]` Oracle cue (Support · Kinship · Community) mapped naturally to the player's intent. The oracle didn't prescribe — it seeded. Player authored Maeve's goals with mechanical tags (exploration, prosperity) that will influence her off-screen World Clock actions. This is the first test of NPC narrative goals and player authorship.

> `[GM NOTE — GOAL DECLARATION]` EPIC rank means progress +1 only on Strong Success or Breakthrough. This goal will take many sessions. The `exploration` tag implies a new sector will eventually need to be defined by the player — this is a deferred implementation feature (sector creation) that can be resolved narratively in tabletop.

---

**Player chooses: talk to Maeve (free action — §4.3)**

---

### NPC Interaction — Maeve (free action, §4.3)

**Rulebook updates applied:** §4.3 added (free actions, NPC interaction model, NPC-initiated interaction). §2.2 revised (NPC narrative goals). TRUTH-ORACLES.md expanded (NPC Disposition + Conversation Seed tables).

**STRATEGIC NOTE:** Simulation layer rework required. Current CA is Freelancer-shaped (individual agents, arbitrary trade). Must become group-focused, contract-based, socially-driven, community-centric. Separate milestone. For now, simulation hooks assumed to be tag-driven and community-oriented.

---

**System provides (board state):**

**NPC Card:**

| Field | Value |
|---|---|
| Maeve | Kin · STABLE · Elace Station |
| Tags | `exploration` · `prosperity` |
| Goals | ☐ Establish outpost · ☐ Start family-clan |

**Signal feed:**
- Bond: STABLE. No strain. No progress.
- Exploration tag active. No viable sector identified.
- Elace economy MODERATE. No immediate pressure to leave.

**Oracle rolls (free action):**

| Table | Roll | Result |
|---|---|---|
| Disposition | 1d6 = 2 | **Hopeful** |
| Conversation Seed | 3,4 | **A proposal** |
| Action | 5,3 | **Request** |
| Theme | 3,2 | **Renewal** |
| Focus | 5,1 | **Vessel** |

**Oracle cue:** Hopeful · A proposal · Request · Renewal · Vessel

**Player log:** *(empty — player writes first entry based on cues)*

> `[GM NOTE — MAEVE INTERACTION]` This is the first test of the NPC interaction model (§4.3). System provided board state and oracle cues. Player now authors the narrative. No system-generated dialogue. No prose. The oracle suggests Maeve is hopeful and wants to propose something about renewing or preparing a vessel. Player interprets.

---

**Player: write your log entry for this interaction. Use the cues or ignore them. Modify Maeve's tags if the narrative demands it.**

---

### Maeve Interaction — continued

**Player interprets oracle cues (Hopeful · A proposal · Request · Renewal · Vessel):**

Maeve proposes acquiring a vessel for the outpost venture. She is hopeful. The topic is vessel renewal — sourcing, claiming, or refitting a ship for the branch-off.

**Problem surfaced:** Neither Silas nor Maeve owns a vessel. The Oar is community-owned (§2.4). Using it for a personal venture requires Elace approval. Acquiring a separate vessel is EPIC-tier.

**Second oracle roll — world state seed (what's out there?):**

| Table | Roll | Result |
|---|---|---|
| Focus | 3,3 | **Wreck** |
| Theme | 4,6 | **Discovery** |
| Action | 2,2 | **Salvage** |
| Conversation Seed | 4,2 | **A route** |

**Oracle cue:** Wreck · Discovery · Salvage · A route

The oracle suggests a salvage path. A wreck exists somewhere. Someone knows a route to it.

**Lore gap identified:** Not enough detail about what vessels exist in the world, how they become available, and what the acquisition process looks like in a credit-less society. §2.4 now defines paths but the specific world state (what wrecks exist, where) needs player authorship.

---

**Board state for player authorship:**

The oracle gave you: Wreck · Discovery · Salvage · A route. Maeve is hopeful and proposing.

You could:
- Author a log entry establishing that Maeve has heard about a wreck (where? from whom?)
- Add a tag to Maeve (e.g., `salvage-lead` / "Has information about a wreck")
- Define a new MINOR goal as a sub-step ("Find and assess the wreck")
- Or take a different direction entirely

**Player log:** *(awaiting your entry)*

---

**Oracle reroll (player flagged bias — used python3 random.randint):**

| Table | Roll | Result |
|---|---|---|
| Action | 2,1 | **Abandon** |
| Theme | 3,2 | **Renewal** |
| Focus | 5,5 | **Debt** |
| Conversation | 4,3 | **A shortage** |
| Disposition | 6 | **Distant** |

**Corrected oracle cue:** Abandon · Renewal · Debt · A shortage · Distant

**Player interpretation:**
- Maeve is distant, not hopeful. Elace cannot support the venture — shortage of resources, community in debt.
- Elders took cautious approach: the gamble of an outpost won't get community backing.
- Maeve believes stagnation is the alternative. A risky approach is needed.
- Neither Silas nor Maeve has a vessel. The Oar is community-owned and currently off-duty (no active assignment = no access).

**Player action: contact Kaelen.**

**Constraint (Appendix A.5):** No FTL communication. Kaelen is at Orin's Reach. Two tight-beams from Kaelen are pending (received earlier). Silas can send a tight-beam response from Elace — but it travels at ship speed. Response time depends on sector distance.

**Question:** Is this a free action or a consequential action?
- Sending a tight-beam = communication = free.
- But: committing to involve Kaelen in the venture = consequential intent. This would advance the clock.

Sending the message is free. The consequences arrive later.

> `[GM NOTE — MAEVE CONCLUSION]` Unbiased oracle produced a radically different tone. "Distant" + "Abandon" + "Debt" + "A shortage" made Maeve pessimistic rather than enthusiastic. This confirms that unbiased rolls produce genuinely emergent narrative — the previous hand-picked results were convergent and predictable. The mismatch between player's goal (outpost) and oracle's cue (stagnation, debt) creates real tension. This is exactly what the oracle should do.

> `[GM NOTE — COMMUNICATION]` Tight-beam communication exists in the world but is not instant (Appendix A.5: no FTL comms). Kaelen sent two tight-beams that arrived previously. Responding is free but the response takes time. This means Kaelen's answer won't arrive this encounter — it's a World Clock event for a future tick. This naturally creates pacing.

> `[GM NOTE — VESSEL OFF-DUTY]` The Oar is docked and off-duty. Silas has no active assignment. The vessel, crew, and tools are not in player context. This is a natural consequence of §2.4 (community-owned). The player is grounded until a new assignment is issued or community approval is obtained.

---

**Tight-beam sent to Kaelen (free action).** Content is player-authored.

**Player: what does Silas say in the tight-beam? And what do you do while waiting for the response?**

**Player chooses: send tight-beam to Kaelen (free action — §4.4)**

---

### Tight-beam M1 — Silas → Kaelen (free action, §4.4)

| Field | Value |
|---|---|
| Recipient | Kaelen (Professional Ally · STABLE · Orin's Reach) |
| Sent | Tick 2 (current) |
| Arrival | Tick 4 (2 sectors transit) |
| Subject | Outpost venture — need support |
| Status | PENDING |

**Player log (Kaelen):** *(player authors the message content here)*

Message queued. Reply arrives at Tick 4. At that tick: oracle rolls disposition + conversation seed, then Action Check for outcome.

**World Clock status:** 5 actions / 2 ticks. 1 action to next tick. Sending was free — tick does not advance.

**Kaelen's pending tight-beams (received earlier, unread):** ×2. Content: Orin's Reach CONTESTED. Unknown vessel. These were received before the outpost conversation — Silas hasn't addressed them yet.

> `[GM NOTE — TIGHT-BEAM M1]` First test of §4.4 message system. Send was free, arrival queued at Tick 4. The 2-tick delay means Silas must do other things at Elace while waiting. This creates natural pacing. The unread tight-beams from Kaelen add context — Silas is responding to someone who already reached out, which makes the communication feel like a relationship, not a cold call.

---

**What does Silas do while waiting?**

Elace Station · Maeve (distant) · Harun at berths · The Oar off-duty · M1 in transit

| Option | |
|---|---|
| Read Kaelen's pending tight-beams | Free · may change message context |
| Talk to Harun | Free · community |
| Explore Elace on foot | Free · community context |
| Request assignment from elders | Consequential · may unlock The Oar |

---

### Free Action — Check Messages

**World Clock:** 5 actions / 2 ticks (no advance — free action).

**Player reads Kaelen's pending tight-beams:**

| Message | Sender | Received | System Tags | Oracle Cue | Player Interpretation |
|---|---|---|---|---|---|
| 1 | Kaelen | Tick 0 | `salvage`, `vessel` | Hopeful · An offer · Observe · Resilience · Tool · Valuable data | Kaelen is hopeful they can succeed in the salvage task, but it will take time with their tools. |
| 2 | Kaelen | Tick 1 | `threat`, `contested` | Worried · A shortage · Request · Trust · Tunnel · Unexpected cost | It took longer than expected to burrow into the wreck, and they are running out of time (shortage) as the sector situation gets tenser. |

**State change:** The Kaelen hooks are now fully parsed. The pressure at Orin's Reach is immediate. Silas's outbound message M1 (asking for Kaelen's help with an outpost venture) is still in transit, arriving Tick 4. Kaelen will receive it while dealing with this CONTESTED situation.

---

### Action 6 — Request Assignment from Elders

**World Clock:** 6 actions / 2 ticks (Tick pending).

**Intent:** Petition elders to use The Oar for a high-risk salvage run to Orin's Reach to assist an out-of-clan ally.
**Track:** Morale (representing community standing/sway) — STEADY [Modifier: +0].
**Approach:** Risky (High stakes, wide outcome band).
**Roll:** 3d6 (4, 3, 2) = 9 + 0 = **9**.
**Result:** 7–10 (Risky) → **Complication.** Get what you wanted, but something else breaks. Progress −1 on a *different* track.

**Resolution:**
- The Oar is **ASSIGNED** to Silas. The vessel and crew (Jonas, Rhea, Marek) enter player context.
- **Complication (Oracle: Unpaid fee):** Demanding the community vessel for a personal task requires a contribution. Silas must pay out of his own pocket, effectively returning what he earned from the previous delivery.
- **Track shift:** Wealth [6/10] → [5/10] (Remains POOR).

---

### World Clock — Tick 3

**World Clock:** 6 actions / 3 ticks.

| Step | Sector | Tag | Change |
|---|---|---|---|
| Tag shift | Orin's Reach | Security | — (Remains CONTESTED for now) |
| NPC off-screen | Kaelen | — | No new messages. |
| Passive drain | — | — | None (Elace Station · STANDARD) |

---

### Pre-departure Bargains

**World Clock:** 6 actions / 3 ticks.
- **Community Cost (`Youth left untutored`):** Player chooses to undock immediately, letting the community bear the cost. No mechanical penalty enforced.
- **Navigator Check (`Dispute over loading`):** Player chooses to spend **1 World Clock Tick** to resolve the dispute peacefully before undocking. This advances the clock.
- **Mechanic Check (`Fast approach identified`):** Transit to Orin's Reach will cost 0 Supplies.

---

### World Clock — Tick 4 (Triggered by Pre-departure delay)

**World Clock:** 6 actions / 4 ticks.

| Step | Sector | Tag | Change |
|---|---|---|---|
| Tag shift | Orin's Reach | Security | — (Remains CONTESTED) |
| NPC off-screen | Kaelen | — | **Message M1 arrives.** Kaelen receives Silas's request for help with an outpost venture, while under CONTESTED pressure. |
| Passive drain | — | — | None (Elace Station · STANDARD) |

---

### Action 7 — Travel Phase (Orin's Reach)

**World Clock:** 7 actions / 4 ticks.

Silas undocks *The Oar* and begins transit.

- **Destination:** Orin's Reach (Deep Space · POOR · CONTESTED · STANDARD)
- **Supply Drain:** 0 Supplies (mitigated entirely by `Fast approach identified` positive cue).
- **Transit Encounter Roll:** 1d6 = 2 (Encounter occurs).
- **Encounter Type:** Opportunity (1d2 = 2).
- **Encounter Oracle:** 1, 5 → `Unclaimed salvage` (Table 9A).

**State Change:** The Oar is in transit. An encounter (`Unclaimed salvage`) occurs along the drift-route before arrival.

---

## DESIGN OBSERVATIONS

*Accumulated GM notes for post-session design review. Each note maps to a rulebook section and a potential STRATEGICAL-TODO entry.*

| # | Source | Section | Observation | Design Question |
|---|---|---|---|---|
| 1 | GM · Setup | §5.2 | Sector adjacency/routing topology undefined. GM must improvise a linear route. | Add explicit adjacency table or diagram to §5. |
| 2 | GM · Setup | §12 Step 1 | No "Session Zero" procedure for generating starting situation. GM constructed both hooks manually. | Add starting situation generation rule — e.g., roll on encounter source table or auto-trigger nearest bond event. |
| 3 | GM · Setup | §2.2 + §4.2 | Bond event proximity rule conflicts with session-start hooks. Non-local bonds cannot trigger bond events, eliminating two of three starting hooks. | Clarify whether session open has a proximity exemption or restrict starting hooks to local bonds only. |
| 4 | Player · Action 1 | §13 | GM narrated scenes and voiced NPC dialogue. Player should construct the interaction mentally from sparse cues. Prose is counterproductive — it replaces player imagination instead of prompting it. | Rewrite §13 LLM-GM Guidelines: cue format only. No scene prose. No NPC dialogue text. Plain words, short sentences. |
| 5 | Player · Action 1 | Mode B UI | Player's first instinct: scan for available NPCs as selectable action options. Mode B must surface local contacts and active hooks proactively, not wait for player to know to ask. | Auto-populate Mode B action tray with local bond contacts + active hooks at session open, ranked by proximity. |
| 6 | Player · Action 1 | §13 + Mode B | Jargon density in GM output feels front-loaded and repulsive, not atmospheric. Lore vocabulary should be ambient — absorbed gradually through context, not injected into every cue. | GM cues use plain language. Jargon/creole reserved for optional flavor text layer only. |
| 7 | Player · Action 2 | Mode B UI | Player specified Mode B dialogue window layout: (a) character portrait area; (b) hook/prompt area with one-line passive or narrator cues; (c) action option area with labelled choices A/B/C/D plus a persistent general-talk option for interpersonal topics not tied to active hooks. | Formalise this three-panel layout as the Mode B dialogue window spec. Add to UI design backlog. |
| 8 | Player · Action 2 | Mode B UI · Text | Two acceptable text registers proposed: passive voice ("Coolant filters are needed at Korr Anchorage") vs. narrator voice ("They ask you to deliver the filters"). Both are concise and scannable. | Decide which register to standardise for prompt text. Consider passive for hook cues, narrator for bond/interpersonal cues. |
| 9 | Player · Action 3 | Mode A / Mode B seam | Undocking triggers Mode A (kinetic 3D). Transition is a hard mode switch. Cargo manifest auto-populates from accepted hook — no manual setup required. UI adapts to kinetic context on switch. | Define the Mode A/B transition trigger precisely: is it the undock action, a confirmation screen, or automatic on departure commit? |
| 10 | Player · Action 3 | Mode A · Travel | Sector-to-sector travel is not instant. Player must physically navigate the vessel from docking vicinity to a departure point in open space (~5–10 min of flight) before the sector-jump becomes available. This prevents teleport-style travel and gives Mode A purpose. | Define what the departure point is in lore terms — e.g. minimum safe distance from station mass, a nav beacon, a jump corridor marker. Must feel organic, not arbitrary. |
| 11 | Player · Action 3 | Mode A · Navigation | Path to departure point should contain navigation challenges scaled to sector environment tag (HARSH = more obstacles/events). Challenges must feel purposeful and lore-consistent — not random filler. Player could not yet specify exact challenge types but flagged they should provide a sense of reasonability. | Design a short list of environment-appropriate navigation events per tag (e.g. HARSH: debris avoidance, atmospheric drag zone, failed beacon; STANDARD: routine clearance, minor congestion). |
| 12 | Player · Action 3 | Mode A · Events | Two types of narrative events during Mode A flight: (a) random/procedural events that pop up along the path; (b) reactive events triggered by specific kinetic player actions in 3D space. Both should bridge Mode A action and Mode B narrative consequences. | Specify trigger conditions for each event type. How does a kinetic action (e.g. docking with a derelict, scanning an object) open a Mode B narrative window? |
| 13 | Player · Action 3 | Mode A · World Clock | World sub-ticks should advance at a slow, reasonable pace during Mode A flight. The clock should not be suspended — the world moves while you fly. | Define sub-tick cadence for Mode A: time-based (every N real seconds) or distance-based (every N units of flight)? Should sub-ticks be visible to the player (HUD indicator) or silent background pressure? |
| 14 | Player · Action 4 | Mode B · Hook resolution | Hook resolution is a dialogue option within the NPC window, not a separate delivery screen. Active hooks with the current NPC appear as a highlighted option in the action tray. No separate UI state required for delivery. | Confirm: hook options in action tray are highlighted/tagged differently from general talk options. Define the visual distinction. |
| 15 | GM · Action 4 | §3 · Tools | Reinforced Hull absorbed the HARSH travel penalty (Action 3) but its cost (−1 maneuver checks) has not surfaced yet — no maneuver check was triggered. Tool trade-off is currently invisible to the player. | Design question: should tool trade-offs surface passively (e.g. visible −1 in HUD) or only when triggered? Invisible costs may undercut the design intent of lateral trade-offs. |
| 16 | **Player · Post-Action 4** | **Three Pillars** | **CRITICAL: Session collapsed into freelancer fetch-quest loop. Receive hook → travel → deliver → next hook. Player does not feel embedded in a community. Travel feels trivial. NPCs are task dispensers.** | **Fundamental revision to §12 play loop and §13 GM guidelines required. See mid-session design review in chronicle.** |
| 17 | Player · Post-Action 4 | LORE-1.2 + LORE-1.3 | Sectors have no visible community. Korr Anchorage was a delivery terminal, not a home. No non-bonded NPCs named. No sense of daily life or local social fabric. | Require community-presence cue at every sector arrival: named non-bonded residents, daily pressures, local mood. |
| 18 | Player · Post-Action 4 | LORE-2.3 + §4.1 | Travel was a one-roll abstraction. No preparation, no crew input, no logistical sacrifice. Felt like commuting. | Add departure-as-community-cost step: crew consent cue, supply allocation, departure consequences for the sector left behind. |
| 19 | Player · Post-Action 4 | LORE-3.1 + §2.1 | Wealth +1 for delivery is a task reward. Track changes should reflect community-level impact, not personal quest completion. | Track changes must name who is affected. "Standing improved among dock families" not "Wealth +1." |
| 20 | Player · Post-Action 4 | §4.2 | Hook A resolved → Hook A.1 appeared from same NPC immediately. Quest-chain pattern. | No same-NPC immediate hook chains. New hooks emerge from community state at next World Clock tick or from a different source. |
| 21 | Player · Post-Action 4 | §12 + §13 | §12 play loop (intent → check → update tracks) has no community-awareness step. It produces task loops by default because it was designed as generic action resolution. | Add required GM output fields: affected community members, departure cost, community state before hooks. Restructure §12 to be community-first. |
| 22 | GM · Post-Review | §4.2 (revised) | Community-first arrival at Korr produced immediate tonal shift. Dallen and Serin (non-bonded) make the station feel like a community. Hooks emerged from Serin and the dock-fee situation, not from Vera. Hook A.1 (same-NPC chain) correctly withdrawn. | Validate that community-first format sustains over multiple sector visits without becoming formulaic. |
| 23 | GM · Post-Review | §4.2 (revised) | Dock-fee dispute (environmental hook) provides ambient texture the player didn't cause. This is the kind of background community pressure that makes sectors feel alive without requiring player engagement. | Confirm environmental hooks as a standard encounter source in the digital implementation. |
| 24 | Player · Action 5 | §2 (new §2.3) | No long-term goal existed. Player had no direction beyond reactive hook-following. Ironsworn-inspired goals mechanic added: player-declared, community-anchored, progress-tracked, ranked MINOR/MAJOR/EPIC. | Validate goal progress pacing in play. Does +1 per relevant success feel right for MAJOR? |
| 25 | Player · Action 5 | §13 | GM output still contains too much generated prose. Player reminder: templates should prompt imagination, not replace it. Keep cues to bare structural minimum. | Further strip GM output. One-line signals. Table format where possible. No descriptive sentences. |
| 26 | GM · Action 5 | §4.1 (revised) | Pre-departure sequence at Korr worked — community cost cue (Serin loses only vessel) added weight. Crew cues were present but flat (no concerns). Crew cues need to sometimes surface friction or questions, not just confirm readiness. | Crew consent cues should occasionally generate tension or information. Consider tying cue content to crew morale state. |
| 27 | Player · Pre-Action 6 | §2.3 (revised) | Goal progress evaluation design explored 5 options (A–E). Option E selected: anchor-based prompted reflection. System highlights anchor-relevant actions, prompts at World Clock ticks. Player judges. Cooldown of 2 ticks prevents trivial incrementing. Falls back to plain reminder (Option B) if no anchor set. | Validate cooldown pacing. Is 2 ticks (4 actions) the right interval? |
| 28 | Player · Pre-Action 6 | §2.3 | Goal declaration can use oracle cues or be written freely. No predefined goal list — full player agency preserved. Oracle provides keyword seeds, player interprets. This maintains Ironsworn's core strength. | Monitor whether oracle-assisted goal creation produces better or worse goals than pure free-form. |
| 29 | Player · Pre-Action 6 | Oracle | Oracle is a free action — no game action consumed, no World Clock advance. This is a meta-tool, not a character action. Prevents oracle use from costing play resources. | Confirm free-action status holds in digital implementation. Oracle button should be always-available, not gated. |
| 30 | Player · Pre-Action 6 | TRUTH-ORACLES.md | Three core tables created (Action, Theme, Focus). 36 entries each, d6×d6. All entries lore-constrained — no military, institutional, or power-fantasy vocabulary. Tables designed for expansion. | First playtest of oracle tables. Do the entries produce useful cues? Which new tables are needed? |
| 31 | Player · Goal declaration | §2.2 (revised) | Player authored NPC narrative goals for Maeve: outpost establishment (exploration, prosperity) and family-clan. Checkbox-style, not progress-tracked. Mechanical tags (exploration, prosperity) will influence World Clock off-screen actions. | Validate that NPC goal tags produce visible simulation effects during World Clock ticks. |
| 32 | Player · Goal declaration | §2.2 (new) | Player authorship of NPC goals emerged as a natural desire when bond interaction deepened. Player wanted to define what Maeve wants — not have the system define it. This is the Ironsworn parallel for NPCs. | Confirm player authorship is always available, not gated. Deeper bonds provide context, not permission. |
| 33 | Player · Goal declaration | §2.2 (new) | NPC goal completion can trigger relocation (Maeve moves to new sector). This changes bond home sector and community composition. A single checkbox can have cascading world-state consequences. | Define the consequence chain for NPC relocation: bond home sector update, community roster change, sector population shift. |
| 34 | Player · Goal declaration | §5 (future) | Player-defined sector creation (exploration mechanic). When a goal involves establishing a new outpost, the player should define the new sector: name, type, tags. This is narratively powerful but mechanically deferred for digital implementation. | Design the sector creation flow for tabletop (player names it, sets initial tags) vs. digital (UI form). |
| 35 | Player · Goal declaration | TRUTH-ORACLES.md | Oracle cue (Support · Kinship · Community) mapped naturally to player's intent. Oracle seeded without prescribing. First successful oracle use. | Track whether oracle-assisted goals produce more or less engagement than pure free-form over multiple declarations. |
| 36 | Player · Maeve interaction | §4.3 (new) | Free/non-free action classification defined. NPC conversation is free (no clock advance). Actions that cost: commit to hook, travel, resolve check, consequential intent. | Validate that free NPC interaction doesn't feel like a loophole or make the clock irrelevant. |
| 37 | Player · Maeve interaction | §4.3 (new) | NPC interaction model: system provides board state (card, tags, signals), player provides narrative (log entries, tag edits). Three-area UI: NPC card, signal feed, player log. | First test of this model. Does it feel natural to author narrative from board state + oracle cues? |
| 38 | Player · Maeve interaction | §4.3 (new) | Player can edit NPC tags inline to reflect narrative developments. Changes propagate to simulation immediately. No forms or menus — tags as editable chips. | Validate inline tag editing UX. Is it simple enough? Does it feel like authorship or bookkeeping? |
| 39 | Player · Maeve interaction | §4.3 (new) | NPC-initiated interactions: World Clock evaluates bonded NPCs with active goals or state changes. Generates "seek signals" in signal feed. Not forced. Player may respond or ignore. | Design the seek signal evaluation criteria. What threshold of state change triggers a seek? |
| 40 | Player · Maeve interaction | Simulation | STRATEGIC: Current simulation is Freelancer-shaped (individual agents, arbitrary trade). Must be reworked to group-focused, contract-based, social, community-centric. Separate milestone. | Create STRATEGICAL-TODO entry for simulation rework. |
| 41 | Player · Maeve interaction | TRUTH-ORACLES.md | Two new tables added: NPC Disposition (1d6, 6 entries) and Conversation Seed (d6×d6, 36 entries). Both produced useful cues for Maeve interaction (Hopeful + A proposal). | Track whether these tables sustain over repeated NPC interactions or need more entries. |
| 42 | Player · Maeve interaction | §2.2 | Player authorship of narrative elements (log entries, NPC tags, backstory) is always available and not gated by bond level. This reinforces the game-as-playing-board model where simulation moves the world and player authors the story. | Confirm this principle holds in digital implementation. No "unlock narrative authorship" gates. |
| 43 | Player · Maeve interaction | §2.2 tags | Tags should be tuples: system tag + narrative phrase. System tag for matching (e.g., `exploration`), narrative phrase for display (e.g., "Conducting exploration"). Prevents cryptic tag names in UI. | Implement tuple format in tag editor. Display narrative phrase on NPC card, system tag in debug/simulation views. |
| 44 | Player · Maeve interaction | TRUTH-ORACLES.md UI | Oracle UI concept: grid of categories. Click cell → word appears. Click again → reroll. Close → reset. Minimal, no scrolling. | Prototype this UI. Validate that it's fast enough for mid-interaction use. |
| 45 | Player · Maeve interaction | §2.4 (new) | Ship ownership formalized. Vessels are community assets (LORE-2.1). Player starts as assigned captain, not owner. The Oar belongs to Elace. Using it for personal ventures requires community approval. | First test: does this framing constrain or motivate? Does it make the player feel embedded or frustrated? |
| 46 | Player · Maeve interaction | §2.4 (new) | Five vessel acquisition paths defined: salvage, community grant, barter chain, inheritance, refit commission. All community-driven, none market-driven. All naturally EPIC-tier. | Validate that at least 2-3 paths feel achievable within campaign scope. |
| 47 | Player · Maeve interaction | Lore gap | World state lacks detail on what vessels/wrecks exist, where they are, and how information about them flows. Oracle rolled Wreck + Salvage + A route — suggesting a salvage path, but the player needs to author the specifics. | Consider: should the session-start map include a "known wreck" seed, or should wrecks be discovered through play? |
| 48 | Player · Maeve interaction | §4.3 NPC-initiated | NPC-initiated interaction concept raised: NPCs proactively seeking player. World Clock evaluates NPC goals + state changes → generates seek signals. Not forced. This is how Maeve would reach out when her exploration tag produces results. | Design: what simulation events trigger a seek signal? Tag change? Goal progress? Timer? |
| 49 | Player · Maeve interaction | Simulation | Simulation rework must address: groups not individuals, contracts not arbitrary trade, social layer, community-centrism. The current Freelancer-shaped CA cannot produce the hooks this session needs. | STRATEGIC: Create formal milestone for simulation rework. Block digital implementation of NPC interaction model until simulation is redesigned. |
| 50 | Player · Maeve interaction | §2.4 + Economy | No universal credits. No direct market access. Vessel acquisition requires community relationships and multi-step barter/service chains. This is a fundamental economic constraint that affects all major player decisions. | Formalize the barter/service economy model. How do communities value things? What do they trade? What obligations can a player take on? |
| 51 | Player · Oracle reroll | TRUTH-ORACLES.md | Player flagged oracle bias. Previous rolls were hand-picked to fit narrative. Reroll using python3 random.randint produced radically different results (Abandon/Renewal/Debt/Shortage/Distant vs. previous Hopeful/Proposal/Request/Renewal/Vessel). Unbiased rolls produce genuinely emergent cues. | MANDATORY: All future oracle rolls must use RNG. Added rule 12 to agent resume instructions. |
| 52 | Player · Maeve interaction | §2.4 | The Oar is off-duty. When player has no active assignment, vessel/crew/tools are not in player context. Player is grounded at station. This is a natural consequence of community ownership. | Formalize vessel availability states: ASSIGNED (player has access), OFF-DUTY (docked, no access), REASSIGNED (given to another captain). |
| 53 | Player · Maeve interaction | Simulation | Captain-ship-crew assignment model: crew are sub-agents transferred to ship when in flight, to station when docked. If vessel is reassigned to another captain, crew may go with vessel or stay at station. Player loses access to crew skills/morale during reassignment. | Design captain-ship binding mechanics. How is assignment granted? By community elders? By request? By emergency? |
| 54 | Player · Maeve interaction | Simulation | Vessel reassignment scenario: community needs The Oar for a supply run while Silas is off-duty. Another captain is assigned. Silas's crew is split or transferred. This creates narrative tension and reinforces that the vessel is not personal property. | Should reassignment be a World Clock event? How does player learn about it? Can player contest it? |
| 55 | Player · Kaelen contact | Appendix A.5 | No FTL communication. Tight-beam exists but travels at ship speed. Sending a message to Kaelen (Orin's Reach) is free but response arrives at a future World Clock tick. Communication creates pacing naturally. | Define tight-beam travel time: 1 tick per sector distance? Fixed delay? Should arrival be a World Clock event? |
| 56 | Player · Kaelen contact | §3 | Player noted: cautious/risky approach modifiers have not been tested yet. These apply to non-free actions (Action Checks). Free actions like NPC interaction and communication don't trigger them. | Track when the first cautious/risky choice occurs. Validate the approach split in actual play. |
| 57 | Player · Maeve interaction | §2.3 | Oracle-driven narrative produced a situation where the EPIC goal (outpost) faces immediate community resistance (shortage, debt, cautious elders). This is good — the goal should feel distant and difficult. The oracle created organic obstacles. | Validate that EPIC goals consistently feel multi-session and difficult without feeling impossible. |
| 58 | Player · Maeve interaction | §2.4 | Player correctly identified that starting POOR + community-owned vessel + no credits = no direct path to vessel acquisition. The economic model must provide indirect paths (service, barter, salvage, social leverage) that feel achievable over time. | Design the first concrete step a POOR player can take toward vessel acquisition. What service/barter is available at Elace? |
| 59 | Player · Kaelen tight-beam | §4.4 (new) | Message system formalized. Sending = free. Transit = 1 tick per sector distance. Arrival = system event + oracle + Action Check. Message queue tracks ID, recipient, timing, subject, status. Conversation context in NPC player log. | First test: does the 2-tick delay (Elace → Orin's Reach) feel like pacing or dead time? |
| 60 | Player · Kaelen tight-beam | §4.4 (new) | Reply resolution uses Action Check with cautious/risky split. This will be the first actual Action Check in the playtest when M1 arrives at Tick 4. The track used depends on context (likely Morale for a personal request to an ally). | Validate: is Morale the right track for ally requests? Should bond strength affect the check? |
| 61 | Player · Kaelen tight-beam | §4.4 (new) | Multiple messages can be in transit. Each independent. Player may send messages to different NPCs simultaneously. Queue grows. This could become hard to track in tabletop — digital implementation handles it naturally. | Design question: should there be a cap on simultaneous messages? Or let complexity emerge? |
| 62 | Player · Kaelen tight-beam | §4.4 (new) | Unsolicited incoming messages (NPC-initiated tight-beams) are generated by World Clock when NPC state changes. These arrive as events. No action check to receive — only to act on content. Kaelen's existing 2 tight-beams are this type. | Clarify: should unread incoming messages affect the World Clock or just accumulate until read? |
| 63 | Player · Wait Phase | §13.1 | Signals attributed to NPCs (e.g., "Harun notes the berth was open") imply an off-screen interaction or dialogue. This violates the "mechanical fact only" rule by implying an NPC action without the player engaging them. | Signals describing ambient community state should be attributed to the environment (e.g., "Berth status: Empty") unless it is a formal NPC-initiated seek signal. |
| 64 | Player · Oracle Check | Simulation | The playtest has surfaced multiple new tags and edge cases for the simulation layer (e.g. `salvage`, `vessel`, `threat`, `contested`). Future analysis of this chronicle must explicitly gather all proposed simulation tags into a consolidated schema. | Create a STRATEGICAL-TODO task to harvest all tags and states from this playtest and formally define their properties in the Simulation Graph documentation. |
| 65 | Player · Oracle Check | Simulation | The `threat` tag when combined with `contested` implies human vs human conflict, risking generic sci-fi combat tropes. | Refine the `threat` tag taxonomy to explicitly align with LORE constraints (e.g., `hostile-scavengers`, `sabotage`, `nav-hazard`) to avoid ambiguous implications of military or institutional conflict. |
| 66 | Player · Action Check | §3.1 | The rulebook lacked a formalized list of "Actions" to map player intent to track modifiers. The GM was deciding via fiat, making it unclear to the player how the system knows what modifier to use. | Updated §3.1 to include a formal Action Table (e.g., Petition/Convince -> Morale) and a rule requiring the GM to explicitly state the Action name before rolling. |
| 67 | Player · Action Check | §3.3 (new) | The player noted that determining *which* track takes a complication and *what* narrative justifies it was purely GM fiat. The system needs to systematize consequences. | Added §3.3 to formalize consequences: GM randomly selects the penalized track (if not logically obvious) and uses the Complication Oracle (Table 8) to generate the narrative wrapper. |
| 68 | Player · Action Check | §3.3 | Player clarified that the system *cannot* reliably guess which track to penalize for context-dependent actions like Petition. Hardcoding default tracks for Complications is flawed. | Revised §3.3: The GM MUST roll the Complication Oracle for *any* consequence. The player then interprets the cue, which determines which track suffers the penalty. GM fiat is entirely removed. |
| 69 | Player · Pre-departure | §4.1 | Player noted that 'Community cost' and 'Crew consent' cues felt like GM-authored prose instead of mechanical prompts. Player also identified 'nav-lane' as a lore violation. | Rewrote §4.1 to proceduralize Pre-departure. Created Community Cost Oracle (Table 10) and Pre-Flight Crew Oracle (Table 11). Added 'nav-lane' to forbidden lexicon in TRUTH_CONTENT-CREATION-MANUAL.md. |
| 70 | Player · Pre-departure | §4.1 | Player selected the "Bargain" resolution for Pre-departure cues but stipulated that effects must be *immediate* (costing ticks or track points) rather than lingering modifiers, to minimize tracking overhead. | Updated §4.1. Pre-flight cues force an immediate "Bargain": spend 1 tick (delay launch) or 1 Track point to resolve negative cues. Positive cues grant immediate one-time benefits (e.g., lower supply cost). |
| 71 | Player · Pre-departure | §4.1 | Player noted that leaving Community Cost cues without mechanical penalties might make them ignorable, but enforcing them could be too punishing (open design question). Player also clarified that positive transit cues (like 'Fast approach') should make the *entire* next travel action free of supply cost to eliminate transit math entirely. | Updated §4.1 to specify that positive transit cues make the entire next travel action cost 0 Supplies. Left Community Cost penalty optional for now, to be reviewed after wider playtesting. |
