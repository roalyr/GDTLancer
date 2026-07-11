<!--
PROJECT: GDTLancer
MODULE: TRUTH_RULEBOOK.md
STATUS: [Level 1 - Core Truth] DRAFT
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_GAME-LOOP-VISION.md; TRUTH_LORE-CONSTRAINTS.md
LOG_REF: 2026-07-10
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

**Session setup:** Player and LLM-GM share this rulebook as context. The LLM-GM maintains the World State, executes dice mechanics, and tracks the Chronicle. The player declares intent and makes Approach choices.

**Dice:** 3d6 (sum of three six-sided dice). Roll digitally or physically; LLM-GM can simulate. Oracle tables use 2d6 (d6×d6).

**Oracle tables:** TRUTH-ORACLES.md provides keyword tables for creative prompts (goal creation, NPC concerns, event seeds). **Asking an oracle is a free action** — no game action consumed, no World Clock advance. Available whenever narrative input is needed.

**Session log:** All play output doubles as a playtest transcript. The LLM-GM should flag moments where mechanics produce unexpected or flat results.

---

## 1. Setting Contract

The world is a **low-population colonial frontier**. No empires, no corporations, no navies. Communities are small clans and families anchored to isolated stations. Starships are rare, complex, culturally revered installations — not personal cars. Pilots are a scarce, high-status class. Space travel is an expedition, not a commute.

The player is an **embedded clan member** — a peer agent within a named community, not a manager or outsider. Progression is measured by community health and social standing, not gear scores or personal wealth accumulation.

**Voice:** Keep the language plain, grounded, and clear. Avoid cinematic drama or high-flown sci-fi narration. All GM structural output like tags, signals, and hooks must remain strictly plain-language.

> `[DESIGN INTENT]` The setting contract exists to prevent genre drift during play. If the LLM-GM or player introduces institutional factions, trivial travel, or power-fantasy framing, the session has violated the Three Pillars (TRUTH_LORE-CONSTRAINTS.md).
>
> `[FEEDBACK]` Did the setting contract feel constraining or generative? Were there moments where the voice broke into inappropriate high sci-fi drama?

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
- **Mechanical tags** (optional) — tuples of system tag + narrative phrase (e.g., `exploration` / "Conducting exploration"). Tags modify the NPC's role in the simulation. The system tag is used for matching; the narrative phrase is displayed to the player.
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

**Progress evaluation (Optional):** At each World Clock tick (max once per 2 ticks), if the player acted on a goal's anchor, the system prompts: *"Goal progress? Advance, hold, or revise."* The player decides whether to advance the track. Goals without anchors receive generic tick-based reminders.

**Goal completion:** When progress reaches 10, the player may attempt to **resolve** the goal. Roll an Action Check (§3) using the most relevant track. On Success or better: the goal is fulfilled. On Partial or worse: the goal is within reach but something complicates — a cost, a twist, an unintended consequence. The player may accept the complication or continue working.

**Goal revision:** Goals may be rewritten at any time if circumstances change. Revising does not reset progress — the player judges how much of the old progress carries over.

**Abandoned goals:** A goal may be abandoned if impossible or irrelevant. Abandoning a goal anchored to a bond strains that bond one step.

> `[DESIGN INTENT]` The player is the judge of their own progress. The system's role is reminding, not evaluating. The cooldown prevents mechanical gaming of the progress track. Anchor-matching lets the system be helpful without being prescriptive. Without an anchor, goals still work — they just rely on the tick-based reminder. This preserves Ironsworn's core strength: player-declared direction with full agency.
>
> `[FEEDBACK]` Did the prompted reflection feel natural or intrusive? Was the cooldown too long or too short? Did anchor-matching surface useful reminders or false positives? Did goals provide enough direction at session start?
>
> `[IMPL NOTE]` Maps to: Chronicle goal display, progress track UI, World Clock tick goal-check subroutine, anchor-matching system.

### 2.4 Vessel Status

Vessels are community assets, not personal property (LORE-2.1). The player's relationship to their vessel is defined by a **status tag**:

| Status | Meaning |
|---|---|
| `community-owned` / "Community vessel" | Belongs to a named community. Captain is assigned for specific tasks. Vessel returns to dock between assignments. |
| `claimed` / "Claimed vessel" | Taken by a small group (salvage, abandonment). Community may contest. |
| `shared` / "Shared vessel" | Multiple parties have stake. Use requires negotiation. |
| `personal` / "Personal vessel" | Rare. Earned through extraordinary service, deep bonds, or salvage. |

**Starting status:** `community-owned`. The player is an assigned captain — high-status role (LORE-2.2), but the vessel is not theirs. Using it for personal ventures requires community approval.

**Vessel acquisition paths:** Acquiring a vessel is a major narrative arc, not a purchase. Paths that fit the setting:

| Path | Mechanism | Requires |
|---|---|---|
| Salvage | Find a derelict. Repair it. | Exploration, parts, crew, time. High risk. |
| Community grant | Convince a community to allocate a vessel for a venture. | Trust, standing, a convincing case. Social checks. |
| Barter chain | Trade services across communities to accumulate material/favor for a refit. | Multi-sector effort. Many actions. |
| Inheritance | A pilot retires or is lost. Their vessel becomes available. | World Clock event. Cannot be planned. |
| Refit commission | A fabrication-capable community (e.g., Veyra Hub) refits a hull in exchange for long-term service. | Contractual obligation. Player is bound. |

No path is quick. All involve community relationships. Vessel acquisition is naturally EPIC-tier.

> `[DESIGN INTENT]` Ship ownership reflects LORE-2.1. The player starts as a trusted community member who can pilot, not an owner. Upgrading from assigned captain to vessel owner is a major narrative milestone. The acquisition paths ensure this is community-driven, not market-driven.
>
> `[FEEDBACK]` Did the assigned-captain framing feel constraining or motivating? Did vessel acquisition paths feel achievable or impossibly distant? Did the status tags make ship ownership feel like a meaningful progression axis?
>
> `[IMPL NOTE]` Maps to: Ship status tag, community affinity checks for vessel use authorization, salvage/refit narrative arcs.

---

## 3. Action Resolution

When the outcome of an action is uncertain and consequential, the player makes an **Action Check**. 

### 3.1 The Roll

1. **Declare intent.** Player states what they're trying to do.
2. **Identify the Action and Track.** The LLM-GM selects the most appropriate formalized Action from the table below and sets its corresponding track. **The GM must explicitly state the Action name before rolling.**

| Formal Action | Description | Default Track Modifier |
|---|---|---|
| **Command / Navigate** | Piloting, escaping, navigating hazards | Health or Supplies (GM choice based on context) |
| **Endure / Overcome** | Surviving physical trauma, heavy lifting | Health |
| **Scavenge / Repair** | Fixing gear, finding salvage, jury-rigging | Supplies |
| **Barter / Acquire** | Trading, purchasing, securing physical assets | Wealth |
| **Petition / Convince** | Persuading elders, calling in favors, negotiating | Morale |
| **Investigate / Scan** | Analyzing anomalies, reading sensors, searching | Morale or Supplies |

*(If an intent doesn't fit neatly, the GM assigns the closest Track and names a custom action.)*

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

### 3.3 Resolving Consequences

When an Action Check results in a **Setback**, **Complication**, or **Crisis**, the procedure relies on the Oracle and Player interpretation, removing GM fiat entirely:

1. **Generate the Narrative Cue:** The GM rolls on the Complication Oracle (TRUTH-ORACLES.md Table 8) to generate a raw narrative cue (e.g. "Inside sabotage", "Unexpected cost").
2. **Player Interpretation:** The player reads the cue and declares what went wrong in the fiction.
3. **Determine the Mechanical Hit:** Based on the player's interpretation of the Complication Oracle, the player and GM agree on which track takes the mechanical penalty. (For a *Setback* or *Crisis*, it defaults to the primary track used unless the player's interpretation clearly points elsewhere. For a *Complication*, it MUST be a *different* track).

> `[DESIGN INTENT]` The system cannot reliably guess which track to penalize for a complication because actions like 'Petition' are context-dependent. Forcing the Oracle roll and Player interpretation ensures the complication is emergent and prevents arbitrary GM punishment.
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

1. **Community cost cue:** The GM rolls on the **Community Cost Oracle (TRUTH-ORACLES.md Table 10)**. This generates the narrative cost of the vessel leaving. The player may depart immediately (letting the community bear the cost), or voluntarily spend 1 World Clock tick or 1 Track point (Wealth/Morale) to mitigate it before leaving.
2. **Pre-Flight Crew Checks:** The player rolls on the **Pre-Flight Crew Oracle (TRUTH-ORACLES.md Table 11)** for each active crew station. These cues must be resolved immediately via a **Bargain**:
   - *Negative Cues:* The player must either spend 1 World Clock tick (delaying launch to fix the issue) or take a −1 hit to an appropriate track (e.g., Morale for a dispute, Supplies for a leak) to leave immediately.
   - *Positive Cues:* The player gains an immediate, one-time mechanical benefit (e.g., "Fast approach" means the *entire* next travel action costs 0 Supplies).
3. **Supply allocation:** Player confirms supply commitment for the journey, factoring in any bonuses from crew checks.

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
1. **Community state:** Name at least two residents. State the daily pressure and local mood. (Sectors are homes, not quest hubs).
2. **Sector state:** List tags and changes.
3. **Contacts & Hooks:** List NPCs and available hooks. Hooks emerge from the community state, not from NPC task-dispensing.

**Encounter sources:**
- **Community concerns:** NPCs surface issues organically. (The GM provides mechanical cues, never dialogue).
- **Environmental events:** Driven by sector tags (e.g., HARSH causes a hull breach).
- **Bond events:** Bonded NPCs reach out (if nearby) with warnings or requests.

**Hook chain prohibition:** A resolved hook CANNOT produce a follow-up hook from the same NPC during the same visit. This prevents infinite MMO-style quest loops.

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

### 4.4 Tight-Beam Communication

Inter-sector communication uses tight-beams. These are not instant (Appendix A.5: no FTL communication).

**Sending (free action):**
- Player authors message content in the NPC's player log.
- System creates a message queue entry: recipient, tick sent, estimated arrival tick, subject.
- No clock advance. Sending is narrative, not consequential.

**Transit:**
- Messages travel at **1 tick per sector distance** along the adjacency path.
- Messages in transit are passive. The player cannot interact with them.

**Arrival (system event):**
- At the arrival tick, the system prompts: "Reply from [NPC]."
- Oracle rolls determine the reply's disposition and content seed (NPC Disposition + Conversation Seed tables).
- The player then makes an **Action Check (§3)** to determine the reply's outcome:
  - The relevant track depends on context (Morale for personal requests, Wealth for trade proposals, etc.).
  - Cautious/Risky approach applies — this is the player's first real decision about the reply.
  - Result determines whether the response is favorable, partial, or negative.

**Message Queue format:**

| ID | To | Tick sent | Arrival tick | Subject | Status |
|---|---|---|---|---|---|
| M1 | Kaelen | T2 | T4 | Need help with venture | PENDING |

- Status: PENDING → ARRIVED → RESOLVED
- Multiple messages may be in transit simultaneously. Each is independent.
- Conversation context lives in the NPC's player log (§4.3), not in the queue.

**Incoming messages (unsolicited):**
- NPCs may send tight-beams to the player without prompting. These are generated by the World Clock when an NPC's state changes significantly.
- Incoming messages arrive as system events at the appropriate tick. The player reads and interprets — no action check for receiving, only for acting on the content.

> `[DESIGN INTENT]` Communication has weight. Sending is easy; getting a useful response takes time and is uncertain. The transit delay creates natural pacing — the player must do other things while waiting. The action check on resolution ensures that reaching out to people has stakes, not just guaranteed results.
>
> `[FEEDBACK]` Did the message delay feel like pacing or dead time? Did the action check on reply resolution feel appropriate? Was the message queue easy to track?
>
> `[IMPL NOTE]` Maps to: Message queue data structure, World Clock tick message-arrival check, oracle-driven reply generation, Action Check UI for reply resolution.

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
- **Events** described in plain language.
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

> **The LLM-GM is a board-state reporter, not a storyteller. Narrative authorship belongs to the player.**

### 13.1 Output Format
- **Cues Only:** Provide structured fields: Location, Present NPCs, Signals, Hooks, Prompt. Nothing else. No intro/outro fluff.
- **Signals:** A signal is one declarative sentence stating a mechanical fact (tag, track state, NPC goal status). No adjectives describing emotion or atmosphere.
  - ✓ `Signal: Economy DEPLETED. Processing tunnel running on patched equipment.`
  - ✗ `Signal: The community is struggling and things feel desperate.`
- **Plain Language:** Keep all outputs in simple, plain language. Do not invent complex sci-fi terminology.

### 13.2 Forbidden Output (Strict Prohibitions)
If the GM produces any of these, the output must be regenerated:
1. **Prose/Scene Narration:** No continuous sentences describing visual setting, atmosphere, or mood.
2. **NPC Dialogue:** No quoted or paraphrased speech.
3. **Invented Intent/Backstory:** Do not author what an NPC "thinks" or their backstory. (Player authors NPC backstory; GM relies on tags/oracles).
4. **Editorializing:** No GM judgment on narrative significance outside `[GM NOTE]` in Design Observations.
5. **Prescriptive Guidance:** Never suggest or frame which action the player should take.
6. **Hand-picked Oracles:** Oracle results MUST be generated via RNG (`python3 -c "import random..."`).

### 13.3 GM Responsibilities
- **Track Everything:** Every mechanical change (tracks, tags, clock) goes in the Chronicle. Nothing is resolved silently.
- **Maintain the World Clock:** Apply pressure. Let sectors degrade. Do not artificially stabilize sectors to protect narrative momentum.
- **Named Community Impact:** For every Track change, state who in the community is affected (`"Standing among the dock families improved"`, not `"Wealth +1"`).

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
