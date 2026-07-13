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

This rulebook is the core design document for the game's mechanics:

1. **Game Rules.** It contains all the rules for how the digital game engine handles actions, dice rolls, and the game world.
2. **Design Notes.** It includes `[DESIGN INTENT]` and `[FEEDBACK]` blocks explaining why rules exist. 

**How it works:** The Game Engine tracks the world state, rolls the dice, and logs events. The player makes choices and writes the story.

**Dice:** The game uses 3d6 (three six-sided dice added together) for major actions. The random tables (Oracles) use 2d6 (rolling a six-sided die twice to pick a row and column).

**Oracle tables:** The `TRUTH-ORACLES.md` file contains random words to generate menus and prompts. Using an oracle is always free and does not advance the game clock.

---

## 1. Setting Rules

The game is set on a **small, isolated frontier**. There are no empires, no giant corporations, and no space navies. People live in small families and clans on lonely stations. Spaceships are rare, complicated, and highly valued industrial machines — not personal cars. Pilots are rare and respected. Traveling through space is difficult and dangerous.

The player is a **member of a community**. You are not an outsider or a god-like manager. You progress by helping your community survive, not by collecting loot or hoarding money.

**Voice:** Keep the language simple and realistic. Do not use over-the-top sci-fi drama. All text from the game engine must be clear and direct.

> `[DESIGN INTENT]` These rules stop the game from turning into a generic space adventure. The game must feel grounded.

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

Start with **3 bonds** — at least one kin, one professional ally, one from a different clan/faction. The Game Engine names them and establishes their context.

**Bond shifts:** Bonds strengthen when you act in the NPC's interest or fulfill promises. Bonds weaken when you break trust, abandon them under pressure, or harm their community. A FRAGILE bond that weakens further is **severed** — the NPC becomes hostile or indifferent.

**NPC narrative goals:** The player may author narrative goals for any bonded NPC at any time using the **Narrative Template Logbook** (see §4.3). Instead of typing open-ended prose, the player selects nodes to compile the goal:
`[NPC Name] intends to [Action Node] [Target Node] in order to [Motivation Node].`
- **Machine-Readable:** The selected nodes translate into system tags (e.g., `exploration`, `securing-resources`) that anchor the NPC's future actions.
- **Status:** Open/Resolved. Checked when the player judges it resolved during interaction.

NPC goals are not mandatory. The player writes them when it feels right — when a deep interaction demands nuance. This is player authorship, not bookkeeping.

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

### 2.5 Temporary Tags

A Temporary Tag is a status effect usually purchased with Advantage Points or incurred via Penalty Points (e.g., `Undetected`, `Security Bypass`, `Compromised`). 

- **Mechanical Function:** A tag alters fictional positioning. It can bypass a narrative restriction, allow an action that would normally be impossible without a roll, or force a complication on an otherwise safe action.
- **Duration:** Tags expire when their narrative condition is met or broken. For example, `Undetected` lasts until the player takes an overt, loud action or leaves the sector.
- **Tracking:** Temporary tags are listed in the GM's Board State output alongside indicators, and cleared when no longer relevant.

---

## 3. Action Resolution

When the outcome of an action is uncertain and consequential, the player makes an **Action Check**. 

### 3.1 The Roll

1. **Declare intent.** Player states what they're trying to do.
2. **Identify the Action and Track.** The Game Engine selects the most appropriate formalized Action from the table below and sets its corresponding track. **The GM must explicitly state the Action name before rolling.**

| Formal Action | Description | Default Track Modifier |
|---|---|---|
| **Command / Navigate** | Piloting, escaping, navigating hazards | Health or Supplies (GM choice based on context) |
| **Endure / Overcome** | Surviving physical trauma, heavy lifting | Health |
| **Scavenge / Repair** | Fixing gear, finding salvage, jury-rigging | Supplies |
| **Barter / Acquire** | Trading, purchasing, securing physical assets | Wealth |
| **Petition / Convince** | Persuading elders, calling in favors, negotiating | Morale |
| **Investigate / Scan** | Analyzing anomalies, reading sensors, searching | Morale or Supplies |

*(If an intent doesn't fit neatly, the GM assigns the closest Track and names a custom action.)*

3. **Choose Approach:** The choice must dictate the narrative stakes, not just the math.
   - **Cautious:** Focuses on damage control. You cap your upside to guarantee safety. You can never get a Breakthrough, but you can never suffer a Crisis.
   - **Risky:** Pushes the limits. The stakes are absolute. Extreme natural dice rolls (3-5 or 16-18) will override your modifiers.

4. **Roll 3d6 + Track Modifier.**

5. **Resolve against outcome bands:**

| Roll Total | Cautious Outcome | Risky Outcome |
|---|---|---|
| **6 or less**<br>*(Natural 3-5 on Risky)* | **Setback.** Minor complication. **−1 Penalty.** | **Crisis.** Severe consequence. Tier drop or World Event. **−3 Penalty.** *(Always triggers on natural 3, 4, or 5).* |
| **7–10** | **Partial.** Achieve part of the goal, but at a minor cost. **±0 Effect.** | **Complication.** Get what you wanted, but something else breaks. **−1 Penalty** on a *different* track. |
| **11–14** | **Success.** Clean result. **+1 Advantage.** | **Success.** Clean result. **+2 Advantage.** |
| **15+**<br>*(Natural 16-18 on Risky)* | **Success.** Clean result. **+1 Advantage.** *(Cautious caps at Success).* | **Breakthrough.** Exceptional result. **+3 Advantage.** Bond strengthens or new opportunity. *(Always triggers on natural 16, 17, or 18).* |

### 3.2 Situational Modifiers

Beyond the primary track modifier, the Game Engine may apply:
- **Bond modifier:** +1 if a DEEP bond is directly relevant. +0 for STABLE. −1 if a severed bond works against you.
- **Sector tag modifier:** +1 if sector conditions favor the action. −1 if conditions oppose.
- **Tool modifier:** +1 if the player has a relevant lateral tool (§9). Tools are keys, not power multipliers.

**Cap:** Total modifier cannot exceed +4 or fall below −4.

### 3.3 Resolving Outcomes

The result of an Action Check produces an immediate mechanical shift, guided by an Oracle cue interpreted by the player.

1. **Roll the Oracle:**
   - On a **Success** or **Breakthrough**, the GM rolls on an **Opportunity Oracle** (Table 9A/9B).
   - On a **Setback**, **Complication**, or **Crisis**, the GM rolls on the **Complication Oracle** (Table 8).
2. **Determine Valid Scope (Mechanical Menu):** The GM acts as a mechanical game board, not a narrator. The GM translates the Oracle Cue into a strict list of 2-3 valid mechanical allocation options. These options must be presented in plain, mechanical terms (e.g., `[+1 to next Command/Navigate Check]`, `[Gain temporary tag: Unmonitored]`, `[Bypass restriction: Docking Queue]`). The GM MUST NOT provide narrative descriptions for these options.
3. **Player Interpretation & Point Consumption:** The player selects from the mechanical menu, consumes their points, and provides the narrative justification via the Narrative Template logbook:
   - **Advantage Points (+1/+2/+3):** The player consumes points to purchase options from the GM's valid scope menu. (e.g., increasing a specific valid track, gaining a modifier, acquiring a temporary tag).
   - **Penalty Points (-1/-3):** The player allocates points to:
     - Decrease a valid Track's progress. (For a *Setback/Crisis*, defaults to primary track. For *Complication*, MUST be a different track).
     - Trigger a World Event (Crisis only): tag shifts toward pressure, or a threat escalates.

> `[DESIGN INTENT]` Tying narrative cues directly to Advantage/Penalty points eliminates tracking "lingering modifiers" while giving encounters immense player-driven utility. Bounding the scope prevents arbitrary allocation (e.g., using a patrol error to heal a broken leg).
>
> `[FEEDBACK]` Did the Cautious/Risky choice feel like a real dilemma? Did scoped Advantage Points make encounters feel rewarding without breaking logic?
>
> `[IMPL NOTE]` Maps to: `CoreMechanicsAPI.action_check()`, ActionTray UI (3d6 display + approach toggle + point allocator constrained by cue scope).

---

## 4. The Game Loop & Information Flow

The game strictly isolates mechanical state from narrative interpretation. All interactions follow a rigid flowchart of information:

### The Information Flowchart
1. **Entry Point (System):** The GM presents **Indicators** — purely mechanical state facts (tags, track states, presence).
2. **Player Acts (Player):** The player reads the Indicators, declares an intent, and triggers an action (rolling an Action Check if required).
3. **System Provides Cues (System):** Based on the roll (Success/Failure) or encounter, the GM rolls on an Oracle and provides a raw cue alongside a **Valid Scope Menu** (a list of valid mechanical targets for Advantage/Penalty points derived from the cue).
4. **Player Interprets & Selects (Player):** The player selects mechanical triggers from the scope menu to spend their points.
5. **Narrative Annotation (Player):** At every stage, the player uses the Narrative Template Logbook's free-text field to author the narrative wrapper. This organically embeds the fiction into the Chronicle schema for future reading, ensuring the system never generates prose.

Play alternates between two distinct mechanical phases.

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
- **Encounter chance.** Game Engine rolls 1d6: on 1–2, an encounter occurs in transit (distress beacon, debris field, hostile patrol, anomaly). Resolve via Action Check or narrative choice.
- **World Clock advances** (§6).

No detailed piloting mechanics in tabletop. Travel is narrated, not simulated. But the departure must feel like a decision with community weight.

> `[DESIGN INTENT]` The pre-departure steps exist to enforce LORE-2.3 (Weight of Travel). Skipping them collapses travel into commuting. The crew consent cue reinforces that the vessel is a shared community asset, not a personal car.
>
> `[FEEDBACK]` Did travel feel consequential or like dead time? Was the supply/morale drain rate about right? Did transit encounters add texture or feel like interruptions? Did the pre-departure sequence add weight or feel like busywork?
>
> `[IMPL NOTE]` Maps to: Mode A flight, tick-driven metric decay, POI encounter system, pre-launch UI confirmation panel.

### 4.2 Encounter Phase (Mode B equivalent)

When the player arrives at a sector or triggers an encounter, play pauses for interaction.

**Arrival sequence (Perimeter vs. Docking):**
When transit completes, the vessel enters the sector perimeter (Mode A). **This is not docking.**
1. **Sector state:** The GM lists sector tags, changes, and any perimeter-level Indicators (e.g., blockades, drifting debris).
2. **Player choice:** The player must declare an intent to dock at a specific station, land on a planet, or investigate the perimeter. (Docking is a distinct action, though usually free unless conditions demand an Action Check).
3. **Post-Docking (Community State):** Only after docking does the GM present the Community (naming at least two residents, daily pressure, and local mood) and available Contacts/Hooks.

**Encounter sources:**
- **Community concerns:** NPCs surface issues organically. (The GM provides mechanical cues, never dialogue).
- **Environmental events:** Driven by sector tags (e.g., HARSH causes a hull breach).
- **Bond events:** Bonded NPCs reach out (if nearby) with warnings or requests.

**Formal Hook Types:**
When presenting Hooks, the GM must assign them a formalized mechanical Type to set expectations. Common types include:
- `Docking Approach`: Intent to transition from Perimeter (Mode A) to Station (Mode B). Usually free, unless restricted.
- `Perimeter Investigation`: Intent to scan an object from the vessel. Requires `Investigate/Scan`.
- `Direct Interception`: Intent to pursue or confront another vessel. Requires `Command/Navigate`.
- `Boarding Action`: Intent to physically enter a derelict or hostile structure. Requires `Command/Navigate` or `Endure/Overcome`.
- `Community Petition`: Intent to request aid or sway an NPC. Requires `Petition/Convince`.

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
| Inspect NPC state (tags, goals, indicators) | Commit to a hook |
| Write narrative log entries | Travel to another sector |
| Modify NPC tags to reflect narrative | Resolve an Action Check (§3) |
| Ask oracle (TRUTH-ORACLES.md) | Any intent with uncertain/consequential outcome |
| Read system indicators | |
| Talk to NPCs (narrative authorship) | |

**NPC interaction model & Narrative Template Logbook:** The system provides board state (NPC card, tags, indicators). The player provides narrative via an **Narrative Template Logbook UI**, combining structural nodes with optional free-text annotation.

1. The system generates a sentence blueprint: `[Player] spoke with [NPC] about [Topic Node] resulting in [Outcome Node].`
2. The player clicks blanks to select contextual Oracle keywords or Track impacts.
3. **Free Text Annotation:** The player may append a custom, free-text note to the log to capture specific dialogue, tone, or personal lore.
4. The hybrid entry is logged to the Chronicle, translating structural choices into machine-readable tags while preserving player-authored narrative.

This provides zero-keystroke input, enforces tone guardrails, and converts narrative directly into simulation data.

**NPC-initiated interaction:** NPCs may proactively seek the player. This is triggered by the World Clock:
- At each tick, the system evaluates bonded NPCs with active goals or significant state changes.
- If an NPC's situation has shifted (goal-relevant event, tag change, new pressure), the system generates a **seek indicator** — a notification that the NPC wants to interact.
- Seek indicators appear in the indicator feed. They are not forced — the player may respond or ignore.
- Non-bonded NPCs may also generate seek indicators if community state warrants it (dock elder raising an issue, stranger arriving).

> `[DESIGN INTENT]` The game is an automated playing board and GM assistant. Simulation puts the world in motion. The player is the narrator. Free actions preserve player agency for narrative authorship without clock pressure. NPC-initiated interactions make the world feel alive without forcing player engagement.
>
> `[FEEDBACK]` Did the free/action split feel natural? Did NPC interaction feel meaningful without mechanical cost? Did NPC-initiated seek indicators feel like the world reaching out or like spam?
>
> `[IMPL NOTE]` Maps to: Mode B NPC card UI, tag editor chips, player log text field, indicator feed component, World Clock NPC-seek evaluation.

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

For MVP playtest: **5–7 sectors** with pre-defined tags. Game Engine generates at session start or player provides a prepared map.

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

## 6. The Causality Engine (World Clock)

Instead of a background simulation that randomly changes things off-screen, the World Clock acts as a **Minimum Necessary Causality Engine**. Its sole purpose is to enforce physical laws (time delays) and frame player consequences.

After every **2 player actions**, the World Clock advances 1 tick.

**Ticks enforce delays:**
- Goal evaluations cooldowns expire.
- Tight-beam messages travel across sectors.
- NPCs arrive at new locations if traveling.

**Ticks DO NOT simulate the world:**
The world does not degrade automatically on a timer. Background simulation is arbitrary and often invisible to the player.

**Event-Driven Degradation:**
Sectors degrade, threats escalate, and NPCs suffer off-screen tragedies *only* as a consequence of player failure. When the player rolls a **Setback** or **Crisis** (Action Check), or via the Complication Oracle, the GM translates that failure into a tangible world event (e.g., *"You fail the repair, and while you're distracted, the Veyra Hub economy finally collapses to DEPLETED."*). 

*The world only gets worse when the player touches it and fails.*

---

## 7. Crew & Mutiny

The player's vessel carries **3–5 named crew** (navigator, mechanic, medic, cargo handler). Each has individual morale: HIGH / STEADY / LOW. Aggregate feeds the Morale track (§2.1).

When individual morale drops to LOW, the Game Engine narrates consequences — refusal, demands, arguments.

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
- **Cross-faction:** Barter-based. Requires something the other party wants. Game Engine sets difficulty.
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

The Chronicle is the session journal, maintained by Game Engine. It records:
- **Events** described in plain language.
- **Track changes** (e.g., Wealth POOR→COMFORTABLE).
- **Bond shifts** (e.g., "Bond with Kael strengthened to DEEP").
- **World Clock changes** (e.g., "Korr economy POOR→DEPLETED").
- **Player goals** (self-declared objectives).

**At session end**, Game Engine appends a **Session Debrief:**
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
   d. Game Engine presents cues — plain language, no scenes, no dialogue
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

## 13. Game Engine Guidelines

> **The Game Engine is a board-state reporter, not a storyteller. Narrative authorship belongs to the player.**

### 13.1 Output Format (The Board State Schema)
- **Cues Only:** Provide structured fields exactly as defined below. No intro/outro fluff.
1. **Header:** Location, Phase, World Clock.
2. **Indicators:** Declarative sentences stating mechanical facts (tags, track state). No adjectives or emotion.
3. **Valid Scope Menu (If pending Action Resolution):** Mechanical buttons translating an oracle cue into spendable options (e.g., `[Buy +1 modifier to next Action] (Cost: 1 pt)`).
4. **Hooks:** Table of destinations and types.
5. **Prompt:** Must clearly ask the player to declare:
   - Mechanical Action (Intent/Point Allocation).
   - Narrative Template Narrative Annotation (Optional free-text to interpret cues/actions).

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
2. **No procedural narrative.** Game Engine narrates from setting contract and sector tags, not unconstrained improvisation.
3. **No colony building.** Player cannot construct or modify stations.
4. **No gear progression.** Tools are lateral. No tiers, no rarity, no scaling.
5. **No FTL communication.** News travels at ship speed. Bond events require proximity.
6. **No lethal human combat.** Preservation Convention applies.
7. **No dynamic map generation.** Map is fixed for the session.

> `[FEEDBACK]` Did any prohibition block fun? Did any feel unnecessary in tabletop context? Should new prohibitions be added?
