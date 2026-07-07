<!--
PROJECT: GDTLancer
MODULE: TRUTH_RULEBOOK.md
STATUS: [Level 1 - Core Truth] DRAFT
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_GAME-LOOP-VISION.md; TRUTH_LORE-CONSTRAINTS.md
LOG_REF: 2026-07-01
-->

# GDTLancer — Solo TTRPG Rulebook

**Version:** 0.1 (Draft)
**Date:** 2026-07-01
**Status:** Draft — Pending Playtest Validation

---

## 0. How to Use This Document

This rulebook serves two purposes:

1. **Play rules.** Everything needed to run a solo GDTLancer session with an LLM companion acting as GM, world simulator, and mechanics executor.
2. **Design validation instrument.** Each section includes `[DESIGN INTENT]` and `[FEEDBACK]` annotations. During play, log observations against these prompts. Feedback maps directly to digital implementation components and future STRATEGICAL-TODO entries.

**Session setup:** Player and LLM-GM share this rulebook as context. The LLM-GM maintains the World State, narrates in jargon creole voice, executes dice mechanics, and tracks the Chronicle. The player declares intent and makes Approach choices.

**Dice:** 3d6 (sum of three six-sided dice). Roll digitally or physically; LLM-GM can simulate. Oracle tables use 2d6 (d6×d6).

**Oracle tables:** TRUTH-ORACLES.md provides keyword tables for creative prompts (goal creation, NPC concerns, event seeds). **Asking an oracle is a free action** — no game action consumed, no World Clock advance. Available whenever narrative input is needed.

**Session log:** All play output doubles as a playtest transcript. The LLM-GM should flag moments where mechanics produce unexpected or flat results.

---

## 1. Setting Contract

The world is a **low-population colonial frontier**. No empires, no corporations, no navies. Communities are small clans and families anchored to isolated stations. Starships are rare, complex, culturally revered installations — not personal cars. Pilots are a scarce, high-status class. Space travel is an expedition, not a commute.

The player is an **embedded clan member** — a peer agent within a named community, not a manager or outsider. Progression is measured by community health and social standing, not gear scores or personal wealth accumulation.

**Voice:** All narration uses the jargon creole — grounded, nautical, logbook-like. "Burn-water" not "fuel." "Drift-hours" not "travel time." "The vessel" not "your ship." No cinematic drama. A tired station clerk's report, not a blockbuster screenplay.

> `[DESIGN INTENT]` The setting contract exists to prevent genre drift during play. If the LLM-GM or player introduces institutional factions, trivial travel, or power-fantasy framing, the session has violated the Three Pillars (TRUTH_LORE-CONSTRAINTS.md).
>
> `[FEEDBACK]` Did the setting contract feel constraining or generative? Did the jargon creole produce atmosphere or friction? Were there moments where the voice broke?

---

## 2. Character Sheet

The player character has four **tracks**, a set of **bonds**, and one or more **goals**.

### 2.1 Tracks

Each track has a **tier** (qualitative state) and a **progress counter** (0–10). When progress fills (10) or empties (0), the tier shifts up or down and progress resets to 5.

| Track | Tiers (low → high) | Starting Value |
|---|---|---|
| **Health** | CRITICAL → INJURED → FIT → PEAK | FIT / 5 |
| **Wealth** | DESTITUTE → BROKE → POOR → COMFORTABLE → WEALTHY | POOR / 5 |
| **Morale** | MUTINOUS → LOW → STEADY → HIGH → INSPIRED | STEADY / 5 |
| **Supplies** | EMPTY → SCARCE → ADEQUATE → STOCKED → SURPLUS | ADEQUATE / 5 |

**Tier effects on rolls:** Each track contributes a modifier to action checks (§3):
- Bottom tier: −2
- Second tier: −1
- Middle tier: 0
- Fourth tier: +1
- Top tier: +2

**Named impact rule:** Every track change must name who in the community is affected. Tracks measure community state, not personal score. "Korr's intake crew has what they need — standing among dock families improved" not "Wealth +1." This prevents track increments from feeling like task rewards.

> `[DESIGN INTENT]` Four tracks, not more. Each represents a distinct pressure axis: physical, economic, social, logistical. The tier names must be evocative enough to narrate from directly ("You're BROKE and your crew is LOW").
>
> `[FEEDBACK]` Are four tracks the right number? Did any track feel redundant or missing? Did tier transitions happen at a satisfying pace — too fast, too slow? Did the progress counter (0–10) feel granular enough?
>
> `[IMPL NOTE]` Maps to: `PlayerShipState` metrics, `CoreMechanicsAPI` modifier calculation, HUD display tiers.

### 2.2 Bonds

Bonds are named relationships with specific NPCs. Each bond has:
- **Name** and **role** (mentor, kin, ally, rival, debtor, etc.)
- **Strength:** FRAGILE → STABLE → DEEP (affects narrative options and modifier, see §3.2)
- **Home sector** (where this person is based)
- **NPC narrative goals** (optional, player-authored — see below)

Start with **3 bonds** — at least one kin, one professional ally, one from a different clan/faction. The LLM-GM names them and establishes their context.

**Bond shifts:** Bonds strengthen when you act in the NPC's interest or fulfill promises. Bonds weaken when you break trust, abandon them under pressure, or harm their community. A FRAGILE bond that weakens further is **severed** — the NPC becomes hostile or indifferent.

**NPC narrative goals:** The player may author narrative goals for any bonded NPC at any time. These are not system-tracked like player goals — they are simple checkboxes with optional mechanical tags.

Format:
- **Goal statement** — one sentence: what the NPC wants.
- **Mechanical tags** (optional) — keywords that modify the NPC's role in the simulation (e.g., `exploration`, `prosperity`, `security`). Tags influence how the World Clock processes that NPC's off-screen actions and what hooks emerge from them.
- **Status** — ☐ open / ☑ completed. Checked when the player judges it resolved, typically surfaced during the next interaction with the NPC.

NPC goals are not mandatory. The player writes them when it feels right — when a deep interaction demands nuance, or when the NPC's motivations become narratively important. This is player authorship, not bookkeeping.

**Consequences of NPC goal completion:** When an NPC goal is checked, the system may apply consequences: NPC relocates, bond context shifts, new community forms, sector tags change. These are resolved narratively at the next interaction.

**Player authorship rights:** The player may write or modify narrative elements for any bonded NPC: backstory, ambitions, personal history, family context. This is always available — not gated by bond strength. Deeper bonds simply provide more context for meaningful contributions.

> `[DESIGN INTENT]` Bonds are the progression spine. NPC narrative goals give the player a reason to care about NPCs beyond mechanical utility. Player authorship makes bonds feel personal — the player invests narrative effort, which deepens engagement. Checkbox-style tracking prevents feature creep. Mechanical tags bridge narrative and simulation without requiring complex evaluation.
>
> `[FEEDBACK]` Did bonds drive decisions? Did NPC goals feel worth authoring? Did mechanical tags produce visible simulation effects? Was there a moment where authoring an NPC's goal changed how you played?
>
> `[IMPL NOTE]` Maps to: `AffinityMatrix`, sub-agent relationship tags, NPC goal checkbox UI, tag-to-simulation bridge, chronicle bond-state display.

### 2.3 Goals

Goals are long-term objectives declared by the player. They give direction without prescribing action. No one assigns them — the player decides what matters.

Each goal has:
- **Statement** — one plain sentence: what the player intends to achieve. May be written freely or composed using oracle cues (TRUTH-ORACLES.md).
- **Anchor** (optional) — a bond, community, or sector this goal is tied to. If set, the system highlights when an action touches the anchor.
- **Progress** — a track (0–10). The **player** judges whether an action advanced the goal. The system does not auto-evaluate.
- **Rank** — scope and difficulty.
  - MINOR (progress +2 per self-evaluated advance) — achievable within a session.
  - MAJOR (progress +1 per self-evaluated advance) — spans multiple sessions.
  - EPIC (progress +1, only on Strong Success or Breakthrough actions) — campaign-defining.

**Declaration:** At character creation, declare at least one MAJOR or EPIC goal. Additional goals may be declared at any time during play.

**Progress evaluation — prompted reflection:**
- At each World Clock tick, the system checks: has the player acted on this goal's anchor (or on actions the player considers relevant)?
- If yes, the system prompts: *"Goal progress? Advance, hold, or revise."*
- **Cooldown:** A goal cannot be evaluated more than once per 2 ticks. This prevents trivial incrementing.
- **Not mandatory.** The player may skip the prompt. Goals are self-paced.
- If no anchor is set, the system prompts at tick intervals without anchor-matching (plain reminder).

**Goal completion:** When progress reaches 10, the player may attempt to **resolve** the goal. Roll an Action Check (§3) using the most relevant track. On Success or better: the goal is fulfilled. On Partial or worse: the goal is within reach but something complicates — a cost, a twist, an unintended consequence. The player may accept the complication or continue working.

**Goal revision:** Goals may be rewritten at any time if circumstances change. Revising does not reset progress — the player judges how much of the old progress carries over.

**Abandoned goals:** A goal may be abandoned if impossible or irrelevant. Abandoning a goal anchored to a bond strains that bond one step.

> `[DESIGN INTENT]` The player is the judge of their own progress. The system's role is reminding, not evaluating. The cooldown prevents mechanical gaming of the progress track. Anchor-matching lets the system be helpful without being prescriptive. Without an anchor, goals still work — they just rely on the tick-based reminder. This preserves Ironsworn's core strength: player-declared direction with full agency.
>
> `[FEEDBACK]` Did the prompted reflection feel natural or intrusive? Was the cooldown too long or too short? Did anchor-matching surface useful reminders or false positives? Did goals provide enough direction at session start?
>
> `[IMPL NOTE]` Maps to: Chronicle goal display, progress track UI, World Clock tick goal-check subroutine, anchor-matching system.

---

## 3. Action Resolution

When the outcome of an action is uncertain and consequential, the player makes an **Action Check**.

### 3.1 The Roll

1. **Declare intent.** Player states what they're trying to do.
2. **LLM-GM sets the relevant track.** Which track's modifier applies (Health for physical, Wealth for trade, Morale for social/crew, Supplies for logistical).
3. **Choose Approach:**
   - **Cautious:** Safer. Narrow outcome band. Success is modest; failure is a setback, not a disaster.
   - **Risky:** Dangerous. Wide outcome band. Success is substantial; failure is severe.
4. **Roll 3d6 + Track Modifier.**
5. **Resolve against outcome bands:**

| Roll Total | Cautious Outcome | Risky Outcome |
|---|---|---|
| 3–6 | **Setback.** Minor complication. Progress −1 on relevant track. | **Crisis.** Severe consequence. Tier drop or bond strain. Progress −3. |
| 7–10 | **Partial.** Achieve part of the goal, but at a cost. Progress ±0. | **Complication.** Get what you wanted, but something else breaks. Progress −1 on a *different* track. |
| 11–14 | **Success.** Clean result. Progress +1. | **Success.** Clean result. Progress +2. |
| 15–18 | **Strong Success.** Better than expected. Progress +2. Narrative opportunity opens. | **Breakthrough.** Exceptional result. Progress +3. Bond strengthens or new opportunity. |

### 3.2 Situational Modifiers

Beyond the primary track modifier, the LLM-GM may apply:
- **Bond modifier:** +1 if a DEEP bond is directly relevant. +0 for STABLE. −1 if a severed bond works against you.
- **Sector tag modifier:** +1 if sector conditions favor the action. −1 if conditions oppose.
- **Tool modifier:** +1 if the player has a relevant lateral tool (§9). Tools are keys, not power multipliers.

**Cap:** Total modifier cannot exceed +4 or fall below −4.

> `[DESIGN INTENT]` The 3d6 bell curve concentrates results around 10–11. The Cautious/Risky split is the central player decision — it should never be obvious which to pick. Modifiers should feel legible, not opaque.
>
> `[FEEDBACK]` Did the Cautious/Risky choice feel like a real dilemma or was one always better? Were outcome bands producing varied narrative results? Did the modifier stack feel transparent? Was the math quick enough to not break immersion?
>
> `[IMPL NOTE]` Maps to: `CoreMechanicsAPI.action_check()`, ActionTray UI (3d6 display + modifier breakdown + approach toggle).

---

## 4. The Game Loop

Play alternates between two phases.

### 4.1 Travel Phase (Mode A equivalent)

Travel is an expedition, not a commute. The player declares a destination. Before departure, the system enforces weight.

**Pre-departure (mandatory before undocking):**
1. **Community cost cue.** LLM-GM states what the current sector loses when the player leaves. Name a specific person or task left undone. Even one line: "Maeve's seal-checks go unfinished while you're gone."
2. **Crew consent cue.** Each crew member's reaction is surfaced — not as a roll, but as a cue. "Jonas notes the route crosses contested space. Rhea asks whether there are spare parts at the destination." The player sees the crew as people weighing the decision.
3. **Supply allocation.** Player confirms supply commitment for the journey. This is not automatic — the player chooses how much to allocate, knowing the cost.

**During travel:**
- **Supplies tick down.** −1 progress per sector traversed.
- **Morale may tick down.** −1 progress if traversing HARSH or CONTESTED sectors.
- **Encounter chance.** LLM-GM rolls 1d6: on 1–2, an encounter occurs in transit (distress signal, debris field, hostile patrol, anomaly). Resolve via Action Check or narrative choice.
- **World Clock advances** (§6).

No detailed piloting mechanics in tabletop. Travel is narrated, not simulated. But the departure must feel like a decision with community weight.

> `[DESIGN INTENT]` The pre-departure steps exist to enforce LORE-2.3 (Weight of Travel). Skipping them collapses travel into commuting. The crew consent cue reinforces that the vessel is a shared community asset, not a personal car.
>
> `[FEEDBACK]` Did travel feel consequential or like dead time? Was the supply/morale drain rate about right? Did transit encounters add texture or feel like interruptions? Did the pre-departure sequence add weight or feel like busywork?
>
> `[IMPL NOTE]` Maps to: Mode A flight, tick-driven metric decay, POI encounter system, pre-launch UI confirmation panel.

### 4.2 Encounter Phase (Mode B equivalent)

When the player arrives at a sector or triggers an encounter, play pauses for interaction.

**Arrival sequence (mandatory on entering a sector):**
1. **Community first.** Before any hooks or action options, present the community. Name at least one non-bonded resident. State the daily pressure. Convey the local mood. The player must see this as a place where people live, not a quest hub.
2. **Sector state.** Present tags and any changes since last visit.
3. **Available contacts.** List bonded and non-bonded NPCs present. Hooks emerge from the community state, not from NPC task-dispensing.

**Encounter sources:**
- **Character interaction.** NPCs surface concerns through their community context — a stressed intake worker mentions failing equipment, a dock family asks after a missing relative, a crew member from another vessel shares news. **There is no quest board.** The LLM-GM presents cues, not dialogue.
- **Environmental event.** Sector tags trigger forced situations — hull breach in HARSH environment, supply seizure in CONTESTED security, outbreak in DECLINING colony.
- **Bond event.** A bonded NPC reaches out (if in same or adjacent sector) — warning, request, offer, or confrontation.

**Hook chain prohibition:** A resolved hook cannot produce a follow-up hook from the same NPC in the same encounter. New hooks emerge from: the community state at the next World Clock tick, a different NPC, an environmental event, or an off-screen NPC action. This prevents quest-chain patterns.

After resolution: update tracks with named community impact (§2.1), bonds, and Chronicle (§10). Player may continue interacting or undock to Travel Phase.

> `[DESIGN INTENT]` The arrival sequence enforces LORE-1.2 (Hyper-Localized Communities). Without it, sectors collapse into delivery terminals. The hook chain prohibition prevents LORE-3.3 violations — progression must come from community state, not NPC task dispensing.
>
> `[FEEDBACK]` Did encounters feel organic or forced? Did the "no quest board" approach produce enough direction? Were bond events frequent enough to matter? Did the community-first arrival make sectors feel like homes?
>
> `[IMPL NOTE]` Maps to: Mode B InteractionWindow, narrative template resolution, GridLayer tag → template mapping, community-state display panel.

### 4.3 Free Actions and NPC Interaction

Not everything costs an action. The distinction:

| Free (no clock advance) | Costs an action |
|---|---|
| Inspect NPC state (tags, goals, signals) | Commit to a hook |
| Write narrative log entries | Travel to another sector |
| Modify NPC tags to reflect narrative | Resolve an Action Check (§3) |
| Ask oracle (TRUTH-ORACLES.md) | Any intent with uncertain/consequential outcome |
| Read system signals | |
| Talk to NPCs (narrative authorship) | |

**NPC interaction model:** The system provides board state (NPC card, tags, signals). The player provides narrative (what was discussed, what changed). The interaction screen has three areas:
1. **NPC card** — portrait, name, role, bond, tags (editable inline).
2. **Signal feed** — system-generated one-line cues from simulation state. Read-only.
3. **Player log** — append-only text field for player-authored narrative notes. Persists across sessions.

When narrative demands a mechanical change, the player edits NPC tags directly. Changes propagate to simulation immediately.

**NPC-initiated interaction:** NPCs may proactively seek the player. This is triggered by the World Clock:
- At each tick, the system evaluates bonded NPCs with active goals or significant state changes.
- If an NPC's situation has shifted (goal-relevant event, tag change, new pressure), the system generates a **seek signal** — a notification that the NPC wants to interact.
- Seek signals appear in the signal feed. They are not forced — the player may respond or ignore.
- Non-bonded NPCs may also generate seek signals if community state warrants it (dock elder raising an issue, stranger arriving).

> `[DESIGN INTENT]` The game is an automated playing board and GM assistant. Simulation puts the world in motion. The player is the narrator. Free actions preserve player agency for narrative authorship without clock pressure. NPC-initiated interactions make the world feel alive without forcing player engagement.
>
> `[FEEDBACK]` Did the free/action split feel natural? Did NPC interaction feel meaningful without mechanical cost? Did NPC-initiated seek signals feel like the world reaching out or like spam?
>
> `[IMPL NOTE]` Maps to: Mode B NPC card UI, tag editor chips, player log text field, signal feed component, World Clock NPC-seek evaluation.

---

## 5. Sector Tags & The World

Each sector has three **tag axes**:

| Axis | Tags |
|---|---|
| **Economy** | RICH · MODERATE · POOR · DEPLETED |
| **Security** | SECURE · PATROLLED · CONTESTED · LAWLESS |
| **Environment** | HOSPITABLE · STANDARD · HARSH · CATASTROPHIC |

Tags shape narration, NPC disposition, available opportunities, and modifiers (§3.2).

### 5.1 Sector Types

- **Star** — system anchor, hub.
- **Planet** — settled, main population.
- **Moon** — outpost, specialized industry.
- **Field** — belts, nebulae, resources.
- **Deep space** — transit, isolation, danger.

### 5.2 Starting Map

For MVP playtest: **5–7 sectors** with pre-defined tags. LLM-GM generates at session start or player provides a prepared map.

Example seed:
- **Elace Station** (Planet, MODERATE / PATROLLED / STANDARD) — home sector.
- **Korr Anchorage** (Moon, POOR / CONTESTED / HARSH) — struggling mining outpost.
- **Veyra Hub** (Star, RICH / SECURE / HOSPITABLE) — prosperous but insular trade hub.
- **The Scatter** (Field, DEPLETED / LAWLESS / HARSH) — dangerous salvage zone.
- **Orin's Reach** (Deep Space, POOR / PATROLLED / STANDARD) — isolated waystation.

> `[FEEDBACK]` Were 5–7 sectors enough for meaningful route choices? Did tag combinations produce distinct sector personalities? Were any combinations narratively flat?
>
> `[IMPL NOTE]` Maps to: WorldLayer topology, GridLayer qualitative tags, LocationTemplate resources.

---

## 6. The World Clock

The world is not static. After every **2 player actions**, the LLM-GM advances the World Clock one tick.

**On each tick:**
1. **Shift one sector tag** one step toward pressure (economies decline, security degrades, environments worsen) — unless player or NPC actions have stabilized it.
2. **NPC agents act.** One or two NPCs take an off-screen action. LLM-GM narrates briefly as gossip or observation.
3. **Passive drain.** If the player is in a hostile sector, −1 to relevant progress tracks.

**Stabilization:** If the player's recent actions directly supported a sector (delivered supplies, mediated dispute), the LLM-GM may hold or improve that sector's tags.

**Catastrophe:** If any sector reaches DEPLETED + LAWLESS + CATASTROPHIC, it becomes **DISABLED** — no docking, no recovery without extraordinary effort.

> `[DESIGN INTENT]` The World Clock is the tabletop GridLayer CA. It ensures pressure without player action. The 2-action cadence means dawdling costs the world.
>
> `[FEEDBACK]` Was 2-action cadence too fast/slow? Did degradation feel like tension or punishment? Did stabilization feel achievable? Did NPC off-screen actions make the world feel alive?
>
> `[IMPL NOTE]` Maps to: GridLayer tick cycle, tag-transition rules, AgentLayer NPC goal processing, Event Notification Toasts.

---

## 7. Crew & Mutiny

The player's vessel carries **3–5 named crew** (navigator, mechanic, medic, cargo handler). Each has individual morale: HIGH / STEADY / LOW. Aggregate feeds the Morale track (§2.1).

When individual morale drops to LOW, the LLM-GM narrates consequences — refusal, demands, arguments.

### 7.1 Mutiny

If Morale track reaches **MUTINOUS** tier, the crew refuses orders. This is a **story beat**, not a game-over.

**Resolution options:**
- **Negotiate (Cautious, Morale check).** Success: reset to LOW/5. Failure: one crew deserts.
- **Assert authority (Risky, Morale check).** Success: reset to STEADY/5. Failure: full desertion — stranded.
- **Concede.** Accept crew demands (divert, offload, abandon goal). Reset to LOW/5, concession stands.

> `[FEEDBACK]` Did the crew feel like people or a morale meter? Did mutiny feel dramatic or mechanical?
>
> `[IMPL NOTE]` Maps to: Sub-agent morale, `is_mutiny_active`, ChronicleLayer `mutiny.tres`, ActionTray mutiny resolution.

---

## 8. Trade & Economy

**No buy/sell interface.** Trade happens through narrative.

- **Same-faction:** Trust-based. Wealth track modifier applies. Success increments wealth progress.
- **Cross-faction:** Barter-based. Requires something the other party wants. LLM-GM sets difficulty.
- **Illicit goods:** Available in LAWLESS/CONTESTED sectors. Higher risk/reward. −1 to social checks in SECURE sectors if discovered.

**Wealth shifts:** Track progress, not numeric credits. Tier transitions are the meaningful moments.

> `[FEEDBACK]` Did qualitative trade feel like meaningful activity or handwaving? Did wealth tier transitions feel impactful?
>
> `[IMPL NOTE]` Maps to: Qualitative wealth system, faction affinity trade gating, commodity provenance tags.

---

## 9. Equipment & Tools

Equipment provides **lateral access**, not power scaling.

| Tool | Enables | Trade-off |
|---|---|---|
| Mining rig | Extract at Field sectors | −1 cargo capacity |
| Medical kit | +1 to Health checks | Consumes supplies on use |
| Survey array | Detect anomalies/POIs | +1 supply cost per transit |
| Reinforced hull | Ignore first HARSH penalty per sector | −1 to maneuver checks |
| Comms relay | Bond events from 2 sectors away | Detectable by patrols |

Start with **one tool**. Acquire more through narrative (salvage, trade, reward) — never loot drops.

> `[FEEDBACK]` Did tool choices create interesting trade-offs? Did the lack of upgrades feel liberating or limiting?
>
> `[IMPL NOTE]` Maps to: Ship tool slots, lateral utility design, roll modifier system.

---

## 10. The Chronicle

The Chronicle is the session journal, maintained by LLM-GM. It records:
- **Events** in jargon creole voice.
- **Track changes** (e.g., Wealth POOR→COMFORTABLE).
- **Bond shifts** (e.g., "Bond with Kael strengthened to DEEP").
- **World Clock changes** (e.g., "Korr economy POOR→DEPLETED").
- **Player goals** (self-declared objectives).

**At session end**, LLM-GM appends a **Session Debrief:**
- Final tracks, bonds, world state.
- Key decisions and consequences.
- Responses to `[FEEDBACK]` prompts encountered during play.

> `[DESIGN INTENT]` The Chronicle replaces character sheet review and session notes. Digitally it is Mode B. In tabletop it is the chat log.
>
> `[FEEDBACK]` Did the Chronicle feel like a living document or a log dump? Was the debrief useful?
>
> `[IMPL NOTE]` Maps to: ChronicleLayer, InteractionWindow tabs, session log format.

---

## 11. Win & Loss Conditions

No single victory screen. Sessions end by player choice or defeat trigger.

**Victory (across sessions):**
- Active goals fulfilled — especially EPIC goals.
- Community stabilized (home sector tags held/improved).
- Bonds deepened (at least one DEEP, none severed through neglect).
- Network built (positive standing with an outside faction).

**Defeat (immediate):**
- **Stranded:** Supplies EMPTY in deep space, no reachable sector.
- **Exiled:** All bonds severed, no faction offers docking.
- **Crew lost:** Full desertion from failed mutiny.
- **Home destroyed:** Home sector DISABLED.

> `[FEEDBACK]` Did victory conditions feel worth pursuing? Did defeat feel dramatic or frustrating?

---

## 12. Quick Reference — Session Flow

```
1. SETUP
   - Map (5–7 sectors with tags)
   - Character (tracks, 3 bonds, 1 tool, 3–5 crew)
   - Declare at least 1 goal (MAJOR or EPIC, community/bond-anchored)
   - Home sector, starting situation
   - Name at least 2 non-bonded community members at home sector

2. PLAY LOOP
   a. Declare intent (travel / interact / act)
   b. IF TRAVEL: Pre-departure sequence (§4.1)
      - Community cost cue (who/what is left behind)
      - Crew consent cue (crew reactions)
      - Supply allocation
   c. IF ARRIVAL: Community-first sequence (§4.2)
      - Community state (named residents, daily pressure, mood)
      - Sector tags and changes
      - Available contacts and hooks
   d. LLM-GM presents cues — plain language, no scenes, no dialogue
   e. Action Check if needed (§3)
   f. Update tracks with named community impact, bonds, chronicle
   g. Every 2 actions → World Clock tick (§6)
   h. Check mutiny threshold, warnings
   i. Repeat

3. SESSION END
   - Session Debrief (state + feedback)
   - Chronicle = playtest transcript
```

---

## 13. LLM-GM Guidelines

### 13.1 Presentation Format

- **Cues, not scenes.** Present location, who is present, one-line signals, available actions. Never narrate what happens. Never write NPC dialogue. The player constructs the interaction mentally.
- **Plain language.** Short sentences, easy to parse at a glance. Jargon creole (TRUTH_CONTENT-CREATION-MANUAL.md §9) is reserved for optional flavor text, not injected into every cue.
- **Cue structure:** Location line (sector + tags) → Present NPCs (name · role · bond) → Signals (one plain sentence per NPC/situation) → Hooks table → Prompt.

### 13.2 Community Rules

- **Community is always visible.** Every sector must have named non-bonded residents. Every action must name who in the community is affected. Sectors are homes, not quest hubs.
- **NPCs are people.** Named, with families and motivations. Mostly non-pilots. They do not dispense tasks — they have concerns that the player can choose to engage with.
- **No hook chains from one NPC.** A resolved hook cannot produce a follow-up from the same NPC in the same encounter. New hooks come from community state, different NPCs, environmental events, or World Clock off-screen actions.
- **Track changes have named impact.** "Standing among the dock families improved" not "Wealth +1." Track shifts reflect community-level consequences.

### 13.3 World and Tone

- **No institutions.** No corporations, empires, navies, trade authorities.
- **Tasks emerge from community pressure.** No quest lists. Problems surface through the community's situation, not through NPC dialogue options.
- **Maintain the World Clock.** Track ticks honestly. Apply pressure. Let sectors degrade.
- **Flag design observations.** `[GM NOTE: ...]` when mechanics produce flat or unexpected results.
- **Preservation Convention.** Human violence is non-lethal. Disablement, capture, social penalty — never death.
- **Track everything.** Every change goes in the Chronicle.

---

## Appendix A: Prohibited Mechanics

From TRUTH_PROHIBITED-SEAMS.md, applied to tabletop:

1. **No speculative market trading.** Trade is narrative, qualitative, track-based.
2. **No procedural narrative.** LLM-GM narrates from setting contract and sector tags, not unconstrained improvisation.
3. **No colony building.** Player cannot construct or modify stations.
4. **No gear progression.** Tools are lateral. No tiers, no rarity, no scaling.
5. **No FTL communication.** News travels at ship speed. Bond events require proximity.
6. **No lethal human combat.** Preservation Convention applies.
7. **No dynamic map generation.** Map is fixed for the session.

> `[FEEDBACK]` Did any prohibition block fun? Did any feel unnecessary in tabletop context? Should new prohibitions be added?
