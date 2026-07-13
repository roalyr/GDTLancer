<!--
PROJECT: GDTLancer
MODULE: TRUTH_RULEBOOK.md
STATUS: [Level 1 - Core Truth] DRAFT
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md; TRUTH_GAME-LOOP-VISION.md; TRUTH_LORE-CONSTRAINTS.md
LOG_REF: 2026-07-14
-->

# GDTLancer — Rulebook

**Version:** 0.2 (Draft)
**Date:** 2026-07-14
**Status:** Draft — Pre-Playtest 2

---

## 0. How to Use This Document

This rulebook defines the game's mechanics. It has two layers:

1. **Game Rules.** How the system handles actions, dice rolls, and the game world.
2. **Design Notes.** `[DESIGN INTENT]` and `[FEEDBACK]` blocks explain why rules exist.

**How it works:** The game is a **deterministic automated board**. The system tracks the world state, rolls the dice, looks up results in tables, and presents option lists. The player makes choices from those lists and writes the story.

There is no Game Master. The system provides data. The player provides narrative.

**Dice:** 3d6 (three six-sided dice added together) for action checks. Oracle tables use 2d6 (one die picks the row, the other picks the column).

**Oracle tables:** TRUTH-ORACLES.md contains the game's lookup tables. Each table entry has pre-authored mechanical options. Using an oracle is always free and does not advance the World Clock.

---

## 1. Setting Rules

The game is set on a **small, isolated frontier**. There are no empires, no giant corporations, and no space navies. People live in small groups on lonely stations. Spaceships are rare, complicated, and highly valued — not personal cars. Pilots are rare and respected. Traveling through space is difficult and dangerous.

The player is a **member of a community**. You are not an outsider or a god-like manager. You progress by helping your community survive, not by collecting loot or hoarding money.

**Voice:** Keep the language simple and realistic. No over-the-top sci-fi drama. All system output must be clear and direct.

> `[DESIGN INTENT]` These rules stop the game from turning into a generic space adventure. The game must feel grounded.

---

## 2. Character Sheet

The player character has four **tracks**, a set of **bonds**, and one or more **goals**.

### 2.1 Tracks

Each track has a **tier** (a word describing the state) and a **progress counter** (0–10). When progress reaches 10, the tier shifts up and progress resets to 5. When progress reaches 0, the tier shifts down and progress resets to 5.

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

**Named impact rule:** Every track change must name who in the community is affected. Tracks measure community state, not just a personal score. Example: "Korr's intake crew has what they need — standing among dock families improved" not just "Wealth +1."

> `[DESIGN INTENT]` Four tracks, not more. Each represents a distinct pressure axis: physical, economic, social, logistical. Tier names must be clear enough to narrate from directly ("You're BROKE and your crew is LOW").
>
> `[FEEDBACK]` Are four tracks the right number? Did any track feel redundant or missing? Did tier transitions happen at a good pace? Did the progress counter (0–10) feel detailed enough?

### 2.2 Bonds

Bonds are named relationships with specific NPCs. Each bond has:
- **Name** and **role** (mentor, kin, ally, rival, debtor, etc.)
- **Strength:** FRAGILE → STABLE → DEEP (affects roll modifiers, see §3.2)
- **Home sector** (where this person is based)
- **NPC goals** (optional, player-authored — see below)

Start with **3 bonds** — at least one kin, one professional ally, one from a different group.

**Bond shifts:** Bonds strengthen when you act in the NPC's interest or fulfill promises. Bonds weaken when you break trust, abandon them under pressure, or harm their community. A FRAGILE bond that weakens further is **severed** — the NPC becomes hostile or indifferent.

**NPC goals:** The player may write goals for any bonded NPC at any time using the **Narrative Logbook** (see §4.3). The player selects nodes to build the goal:
`[NPC Name] intends to [Action Node] [Target Node] in order to [Motivation Node].`
- **Machine-Readable:** The selected nodes create system tags (e.g., `exploration`, `securing-resources`) that anchor the NPC's future actions.
- **Status:** Open/Resolved. Checked when the player judges it resolved during interaction.

NPC goals are not mandatory. The player writes them when it feels right. This is player authorship, not bookkeeping.

**Consequences of NPC goal completion:** When an NPC goal is checked, the system may apply consequences: NPC relocates, bond context shifts, new community forms, sector tags change. These are resolved at the next interaction.

> `[DESIGN INTENT]` Bonds are the progression spine. NPC goals give the player a reason to care about NPCs beyond mechanical use. Player authorship makes bonds feel personal.
>
> `[FEEDBACK]` Did bonds drive decisions? Did NPC goals feel worth writing? Did mechanical tags produce visible effects?

### 2.3 Goals

Goals are long-term objectives declared by the player. They give direction without prescribing action. No one assigns them — the player decides what matters.

Each goal has:
- **Statement** — one plain sentence: what the player intends to achieve. May be written freely or composed using oracle cues (TRUTH-ORACLES.md).
- **Anchor** (optional) — a bond, community, or sector this goal is tied to. If set, the system highlights when an action touches the anchor.
- **Progress** — a track (0–10). The **player** judges whether an action advanced the goal. The system does not auto-evaluate.
- **Rank** — scope and difficulty.
  - MINOR (progress +2 per self-evaluated advance) — achievable within a session.
  - MAJOR (progress +1 per self-evaluated advance) — spans multiple sessions.
  - EPIC (progress +1, only on Success during Risky actions) — campaign-defining.

**Declaration:** At character creation, declare at least one MAJOR or EPIC goal. Additional goals may be declared at any time during play.

**Progress evaluation (Optional):** At each World Clock tick (max once per 2 ticks), if the player acted on a goal's anchor, the system prompts: *"Goal progress? Advance, hold, or revise."* The player decides whether to advance the track. Goals without anchors receive generic tick-based reminders.

**Goal completion:** When progress reaches 10, the player may attempt to **resolve** the goal. Roll an Action Check (§3) using the most relevant track. On Success: the goal is fulfilled. On Partial: the goal is within reach but something complicates — a cost, a twist, an unintended consequence. The player may accept the complication or continue working.

**Goal revision:** Goals may be rewritten at any time if circumstances change. Revising does not reset progress — the player judges how much of the old progress carries over.

**Abandoned goals:** A goal may be abandoned if impossible or irrelevant. Abandoning a goal anchored to a bond strains that bond one step.

> `[DESIGN INTENT]` The player is the judge of their own progress. The system's role is reminding, not evaluating. The cooldown prevents gaming the progress track.
>
> `[FEEDBACK]` Did the prompted reflection feel natural or intrusive? Was the cooldown too long or too short? Did goals provide enough direction at session start?

### 2.4 Vessel Status

Vessels are community assets, not personal property (LORE-2.1). The player's relationship to their vessel is defined by a **status tag**:

| Status | Meaning |
|---|---|
| `community-owned` | Belongs to a named community. Captain is assigned for specific tasks. Vessel returns to dock between assignments. |
| `claimed` | Taken by a small group (salvage, abandonment). Community may contest. |
| `shared` | Multiple parties have stake. Use requires negotiation. |
| `personal` | Rare. Earned through extraordinary service, deep bonds, or salvage. |

**Starting status:** `community-owned`. The player is an assigned captain — high-status role (LORE-2.2), but the vessel is not theirs. Using it for personal ventures requires community approval.

**Vessel acquisition paths:** Acquiring a vessel is a major narrative arc, not a purchase. Paths that fit the setting:

| Path | Mechanism | Requires |
|---|---|---|
| Salvage | Find a derelict. Repair it. | Exploration, parts, crew, time. High risk. |
| Community grant | Convince a community to allocate a vessel for a venture. | Trust, standing, a convincing case. Social checks. |
| Barter chain | Trade services across communities to accumulate material/favor for a refit. | Multi-sector effort. Many actions. |
| Inheritance | A pilot retires or is lost. Their vessel becomes available. | World Clock event. Cannot be planned. |
| Refit commission | A group with fabrication capability refits a hull in exchange for long-term service. | Contractual obligation. Player is bound. |

No path is quick. All involve community relationships. Vessel acquisition is naturally EPIC-tier.

> `[DESIGN INTENT]` Ship ownership reflects LORE-2.1. The player starts as a trusted community member who can pilot, not an owner.
>
> `[FEEDBACK]` Did the assigned-captain framing feel constraining or motivating? Did vessel acquisition paths feel achievable or impossibly distant?

### 2.5 Temporary Tags

A Temporary Tag is a status effect gained from an Advantage option or imposed by a Disadvantage option (e.g., `Undetected`, `Security Bypass`, `Compromised`).

- **Mechanical Function:** A tag changes the player's situation. It can bypass a restriction, allow an action that would normally need a roll, or force a complication on an otherwise safe action.
- **Duration:** Tags expire when their narrative condition is met or broken. For example, `Undetected` lasts until the player takes a loud action or leaves the sector.
- **Tracking:** Temporary tags are listed in the system's current state output and cleared when no longer relevant.

---

## 3. Action Resolution

When the outcome of an action is uncertain and consequential, the player makes an **Action Check**.

### 3.1 The Roll

1. **Declare intent.** Player states what they're trying to do.
2. **Identify the Action and Track.** The system selects the most appropriate action from the table below and sets its corresponding track. **The system must show the Action name before rolling.**

| Action | Description | Default Track Modifier |
|---|---|---|
| **Command / Navigate** | Piloting, escaping, navigating hazards | Health or Supplies (system picks based on context) |
| **Endure / Overcome** | Surviving physical trauma, heavy lifting | Health |
| **Scavenge / Repair** | Fixing gear, finding salvage, jury-rigging | Supplies |
| **Barter / Acquire** | Trading, purchasing, securing physical assets | Wealth |
| **Petition / Convince** | Persuading elders, calling in favors, negotiating | Morale |
| **Investigate / Scan** | Analyzing anomalies, reading sensors, searching | Morale or Supplies |

*(If an intent doesn't fit neatly, the system assigns the closest Track and names a custom action.)*

3. **Choose Approach:** The choice dictates the stakes, not just the math.
   - **Cautious:** Focuses on damage control. You can never get a high Success (only standard Success), but you can never suffer a Crisis.
   - **Risky:** Pushes the limits. Extreme natural dice rolls (3-5 or 16-18) override your modifiers.

4. **Roll 3d6 + Track Modifier.**

5. **Resolve against outcome bands:**

| Roll Total | Cautious Outcome | Risky Outcome |
|---|---|---|
| **6 or less**<br>*(Natural 3-5 on Risky)* | **Setback.** Minor failure. System rolls **Complication Oracle** → player picks from Disadvantage options. | **Crisis.** Severe failure. System rolls **Complication Oracle** → player picks from Disadvantage options. Tier-triggering track hit. *(Always triggers on natural 3, 4, or 5).* |
| **7–10** | **Partial.** Mixed result. System rolls **both** Opportunity and Complication Oracles → player picks from Advantage options AND Disadvantage options. | **Partial.** Mixed result. System rolls **both** Opportunity and Complication Oracles → player picks from Advantage options AND Disadvantage options. |
| **11–14** | **Success.** Clean result. System rolls **Opportunity Oracle** → player picks from Advantage options. | **Success.** Clean result. System rolls **Opportunity Oracle** → player picks from Advantage options (better options available). |
| **15+**<br>*(Natural 16-18 on Risky)* | **Success.** Clean result. System rolls **Opportunity Oracle** → player picks from Advantage options. *(Cautious caps at standard Success).* | **Success.** Outstanding result. System rolls **Opportunity Oracle** → player picks from Advantage options (best options available). Bond strengthens or new opportunity. *(Always triggers on natural 16, 17, or 18).* |

**How outcomes work:**
- **Success:** The system rolls on an Opportunity Oracle (Table 9A for space, Table 9B for station). The player picks one option from the Advantage list.
- **Partial:** The system rolls on BOTH an Opportunity Oracle AND the Complication Oracle (Table 8). The player picks one Advantage option AND one Disadvantage option. A mixed bag.
- **Setback/Crisis:** The system rolls on the Complication Oracle (Table 8). The player picks one option from the Disadvantage list. On Crisis, the track hit must be large enough to risk a tier change.

### 3.2 Situational Modifiers

Beyond the primary track modifier, the system may apply:
- **Bond modifier:** +1 if a DEEP bond is directly relevant. +0 for STABLE. −1 if a severed bond works against you.
- **Sector tag modifier:** +1 if sector conditions favor the action. −1 if conditions oppose.
- **Tool modifier:** +1 if the player has a relevant tool (§9). Tools are keys, not power multipliers.

**Cap:** Total modifier cannot exceed +4 or fall below −4.

### 3.3 Resolving Outcomes

The result of an Action Check always produces an oracle roll and a list of options for the player.

1. **Roll the Oracle:** Based on the outcome tier:
   - **Success:** Roll on the appropriate Opportunity Oracle (Table 9A for in-space, Table 9B for on-station).
   - **Partial:** Roll on BOTH the Opportunity Oracle AND the Complication Oracle (Table 8).
   - **Setback / Crisis:** Roll on the Complication Oracle (Table 8).

2. **System Shows Options:** Each oracle entry has pre-authored lists of Advantage options and/or Disadvantage options. The system shows the appropriate list(s) to the player. These are concrete, clickable choices — track modifications (+1/-1), temporary tags, or bond shifts.

3. **Player Selects:** The player picks from the provided option lists:
   - On **Success:** Pick one Advantage option.
   - On **Partial:** Pick one Advantage option AND one Disadvantage option.
   - On **Setback/Crisis:** Pick one Disadvantage option. (On Crisis, the disadvantage must include a track hit of -2 or more.)

4. **Narrative Logbook (optional):** The player writes a short entry in the Narrative Logbook to record what happened in their own words. This is saved to the Chronicle.

**All track modifications are applied immediately as free actions.** The player does not type numbers — they select from pre-built options and the system applies the change.

> `[DESIGN INTENT]` Every outcome produces a concrete, clickable menu. There are no dead zones. The Partial outcome is the key innovation: it always gives you something good AND something bad — a forced compromise. The player never has to invent what an oracle cue means mechanically — the system provides the options.
>
> `[FEEDBACK]` Did the Cautious/Risky choice feel like a real dilemma? Did selecting from option lists feel satisfying or restrictive? Did Partial outcomes create interesting trade-offs?

---

## 4. The Game Loop

The game strictly separates mechanical state from narrative interpretation. All interactions follow a fixed flow.

### The Information Flow

1. **System Shows Current State:** The system presents the current state — track values, sector data, NPCs present, available hooks, and short mechanical facts.
2. **Player Acts:** The player reads the current state, declares an intent, and triggers an action (rolling an Action Check if required).
3. **System Shows Option Lists:** Based on the roll outcome, the system rolls on the oracle and presents Advantage and/or Disadvantage option lists from the matching table entry.
4. **Player Selects:** The player picks options from the lists. Track changes are applied immediately.
5. **Player Writes (Optional):** The player writes a short entry in the Narrative Logbook to record what happened. This is saved to the Chronicle.

### What the System Does vs What the Player Does

| System (Deterministic) | Player (Narrative) |
|---|---|
| Roll dice and look up results | Declare intent and choose approach |
| Present the current state (track values, tags, NPCs) | Interpret the current state as a scene |
| Roll on oracle tables | Select from provided option lists |
| Apply track changes from selected options | Write Narrative Logbook entries |
| Advance the World Clock | Author NPC goals and backstory |
| Track bonds, goals, message queue | Decide when to advance goal progress |
| Enforce rules (prohibited outputs, approach caps) | Judge narrative significance |
| Generate hooks from sector data and NPC tags | Decide which hooks to pursue |

Play alternates between two phases.

### 4.1 Travel Phase

Travel is an expedition, not a commute. The player declares a destination. Before departure, the system enforces weight.

**Pre-departure sequence (mandatory before undocking):**

1. **Community cost:** The system rolls on the **Community Cost Oracle (TRUTH-ORACLES.md Table 10)**. The player sees the cost and picks from the options (accept the cost or spend a resource to mitigate it).
2. **Crew checks:** The player rolls on the **Pre-Flight Crew Oracle (TRUTH-ORACLES.md Table 11)** for each active crew station. Each result has pre-authored options:
   - *Disadvantage results:* The player picks: spend 1 World Clock tick (delay launch) OR take a track hit.
   - *Advantage results:* The player picks a one-time benefit (e.g., next travel costs 0 Supplies).
3. **Supply allocation:** Player confirms supply commitment for the journey.

**Travel sequence (per sector traversed):**
1. Supplies −1 progress.
2. Morale −1 progress if traversing a sector with Security below 3 or Environment below 3.
3. Roll 1d6 for encounter: On 1, roll Complication Oracle (hazard). On 2, roll Opportunity Oracle In-Space (find). On 3-6, no encounter.
4. World Clock advances +1.

**Arrival:** The player arrives at the destination sector's **perimeter** (in space, not docked). Docking is a separate action.

No detailed piloting mechanics in tabletop. Travel is narrated, not simulated. But the departure must feel like a decision with weight.

> `[DESIGN INTENT]` The pre-departure steps exist to enforce LORE-2.3 (Weight of Travel). Skipping them collapses travel into commuting.
>
> `[FEEDBACK]` Did travel feel consequential or like dead time? Was the supply/morale drain rate about right? Did transit encounters add texture or feel like interruptions?

### 4.2 Encounter Phase

When the player arrives at a sector or triggers an encounter, play pauses for interaction.

**Arrival sequence:**
1. **Sector current state:** The system lists sector track values, changes, and any perimeter-level data (e.g., blockades, drifting debris).
2. **Player choice:** The player declares an intent to dock at a specific station, land on a planet, or investigate the perimeter. (Docking is a distinct action, usually free unless conditions demand an Action Check.)
3. **Post-Docking (Community State):** Only after docking does the system present the community — naming at least two residents, daily pressure, and local mood — and available contacts/hooks.

**Encounter sources:**
- **Community concerns:** NPCs surface issues based on their tags and goals. (The system provides mechanical data, never dialogue.)
- **Environmental events:** Driven by sector track values (e.g., low Environment track causes a hull breach).
- **Bond events:** Bonded NPCs reach out (if nearby) with warnings or requests.

**Hook types:**
When presenting hooks, the system assigns each a type:
- `Docking Approach`: Transition from perimeter to station. Usually free, unless restricted.
- `Perimeter Investigation`: Scan an object from the vessel. Requires `Investigate/Scan`.
- `Direct Interception`: Pursue or confront another vessel. Requires `Command/Navigate`.
- `Boarding Action`: Physically enter a derelict or hostile structure. Requires `Command/Navigate` or `Endure/Overcome`.
- `Community Petition`: Request aid or sway an NPC. Requires `Petition/Convince`.

**Hook chain prohibition:** A resolved hook CANNOT produce a follow-up hook from the same NPC during the same visit. This prevents endless quest loops.

After resolution: update tracks with named community impact (§2.1), bonds, and Chronicle (§10). Player may continue interacting or undock to Travel Phase.

> `[DESIGN INTENT]` The arrival sequence prevents sectors from feeling like delivery terminals. The hook chain prohibition stops quest-loop patterns.
>
> `[FEEDBACK]` Did encounters feel organic or forced? Did the "no quest board" approach produce enough direction?

### 4.3 Free Actions and NPC Interaction

Not everything costs an action. The distinction:

| Free (no clock advance) | Costs an action (tick-triggering) |
|---|---|
| Read the current state | Commit to a hook |
| Write Narrative Logbook entries | Travel to another sector |
| Modify NPC tags to reflect narrative | Resolve an Action Check (§3) |
| Ask oracle (TRUTH-ORACLES.md) | Any intent with uncertain/consequential outcome |
| Talk to NPCs (narrative authorship) | |
| Send tight-beam messages | |
| Select options from provided lists | |

**NPC interaction model & Narrative Logbook:** The system provides the current state (NPC card, tags, track values). The player provides narrative via the **Narrative Logbook**, combining structural nodes with optional free-text.

1. The system generates a sentence template: `[Player] spoke with [NPC] about [Topic Node] resulting in [Outcome Node].`
2. The player clicks blanks to select contextual oracle keywords or track impacts.
3. **Free Text (Optional):** The player may write a custom note to capture specific dialogue, tone, or personal lore.
4. The entry is logged to the Chronicle, translating structural choices into machine-readable tags while preserving player-authored narrative.

**NPC-initiated interaction:** NPCs may reach out to the player. This is triggered by the World Clock:
- At each tick, the system evaluates bonded NPCs with active goals or significant state changes.
- If an NPC's situation has shifted (goal-relevant event, tag change, new pressure), the system generates a **notification** — the NPC wants to interact.
- Notifications appear in the current state feed. They are not forced — the player may respond or ignore.
- Non-bonded NPCs may also generate notifications if community state warrants it.

**Tick-delay consequences:** If a notification goes unanswered for a defined number of ticks, the system resolves the outcome deterministically (e.g., the NPC's situation worsens, a bond weakens). Inaction is a valid decision, but it has consequences.

> `[DESIGN INTENT]` The game is a deterministic board. The player is the narrator. Free actions preserve player authorship without clock pressure. NPC-initiated notifications make the world feel alive without forcing engagement.
>
> `[FEEDBACK]` Did the free/action split feel natural? Did NPC interaction feel meaningful? Did notifications feel like the world reaching out or like spam?

### 4.4 Tight-Beam Communication

Inter-sector communication uses tight-beams. These are not instant (no FTL communication).

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
  - Cautious/Risky approach applies.
  - Result determines whether the response is favorable, partial, or negative.

**Message Queue format:**

| ID | To | Tick sent | Arrival tick | Subject | Status |
|---|---|---|---|---|---|
| M1 | Kaelen | T2 | T4 | Need help with venture | PENDING |

- Status: PENDING → ARRIVED → RESOLVED
- Multiple messages may be in transit simultaneously. Each is independent.

**Incoming messages (unsolicited):**
- NPCs may send tight-beams to the player without prompting. These are generated by the World Clock when an NPC's state changes significantly.
- Incoming messages arrive as system events at the appropriate tick. The player reads and interprets — no action check for receiving, only for acting on the content.

> `[DESIGN INTENT]` Communication has weight. Sending is easy; getting a useful response takes time and is uncertain.
>
> `[FEEDBACK]` Did the message delay feel like pacing or dead time? Did the action check on reply resolution feel appropriate?

---

## 5. Sector State

Each sector has four **tracks** (0-10 numbers, same scale as player tracks) and a **type**.

### 5.1 Sector Tracks

| Track | What it measures |
|---|---|
| **Wealth** | Economic health of the community |
| **Security** | Safety, patrol presence, threat level |
| **Morale** | Social cohesion, community mood |
| **Supplies** | Physical resources, food, fuel, materials |

Sector tracks are managed by the **deterministic algorithm**. The player does not directly modify sector tracks. Sector tracks change as a result of:
- Player action outcomes (e.g., a successful Barter action may increase the sector's Wealth by +1).
- World Clock consequences (e.g., an unanswered NPC request causes the sector's Morale to drop by -1 after X ticks).
- Travel effects (e.g., removing the vessel from a sector may decrease its Security by -1).

Sector track values affect action modifiers (§3.2): the system checks whether the relevant sector track favors or opposes the player's action.

### 5.2 Sector Types

- **Star** — system anchor, hub.
- **Planet** — settled, main population.
- **Moon** — outpost, specialized industry.
- **Field** — belts, nebulae, resources.
- **Deep space** — transit, isolation, danger.

### 5.3 Starting Map

For playtest: **5–7 sectors** with pre-defined track values. The system generates these at session start or the player provides a prepared map.

Example seed:

| Sector | Type | Wealth | Security | Morale | Supplies |
|---|---|---|---|---|---|
| Elace Station | Planet | 5 | 5 | 5 | 5 |
| Korr Anchorage | Moon | 3 | 3 | 4 | 3 |
| Veyra Hub | Star | 7 | 7 | 6 | 6 |
| The Scatter | Field | 2 | 1 | 3 | 2 |
| Orin's Reach | Deep Space | 3 | 4 | 5 | 4 |

> `[FEEDBACK]` Were 5–7 sectors enough for meaningful route choices? Did track values produce distinct sector personalities?

---

## 6. The World Clock

The World Clock is the game's pacing mechanism. Time does not pass in real-time; it moves in ticks.

**Tick-triggering actions:** The clock advances 1 tick when the player:
- Resolves an Action Check (§3)
- Completes travel to a new sector (1 tick per sector traversed)
- Explicitly waits (free action converted to a tick)

**Free actions do NOT trigger ticks** — reading state, writing logs, talking, sending messages, asking oracles.

**When a tick happens, the system checks:**
- NPC goal progress (anchor matching prompts, max once per 2 ticks)
- NPC notification generation (state changes, requests)
- In-transit message arrival
- Tick-delay consequence resolution (unanswered requests)

**The world changes because of the player.** Sector tracks do not randomly degrade on a timer. They change as a direct result of player action outcomes, player inaction consequences (tick-delay), or travel effects.

---

## 7. Crew & Mutiny

The player's vessel carries **3–5 named crew** (navigator, mechanic, medic, cargo handler). Each has individual morale: HIGH / STEADY / LOW. Aggregate feeds the Morale track (§2.1).

When individual morale drops to LOW, the system applies consequences — refusal, demands, arguments (shown as current state data, not narrated prose).

### 7.1 Mutiny

If the Morale track reaches **MUTINOUS** tier, the crew refuses orders. This is a **story beat**, not a game-over.

**Resolution options:**
- **Negotiate (Cautious, Morale check).** Success: reset to LOW/5. Failure: one crew deserts.
- **Assert authority (Risky, Morale check).** Success: reset to STEADY/5. Failure: full desertion — stranded.
- **Concede.** Accept crew demands (divert, offload, abandon goal). Reset to LOW/5, concession stands.

> `[FEEDBACK]` Did the crew feel like people or a morale meter? Did mutiny feel dramatic or mechanical?

---

## 8. Trade & Economy

**No buy/sell interface.** Trade happens through narrative and action checks.

- **Same-group trade:** Trust-based. Wealth track modifier applies. Success may increase wealth progress.
- **Cross-group trade:** Barter-based. Requires something the other party wants. System sets difficulty.
- **Illicit goods:** Available in low-Security sectors. Higher risk/reward. −1 to social checks in high-Security sectors if discovered.

**Wealth shifts:** Track progress, not numeric credits. Tier transitions are the meaningful moments.

> `[FEEDBACK]` Did qualitative trade feel like meaningful activity or handwaving? Did wealth tier transitions feel impactful?

---

## 9. Equipment & Tools

Equipment provides **lateral access**, not power scaling.

| Tool | Enables | Trade-off |
|---|---|---|
| Mining rig | Extract at Field sectors | −1 cargo capacity |
| Medical kit | +1 to Health checks | Consumes supplies on use |
| Survey array | Detect anomalies/POIs | +1 supply cost per transit |
| Reinforced hull | Ignore first low-Environment penalty per sector | −1 to maneuver checks |
| Comms relay | Bond events from 2 sectors away | Detectable by patrols |

Start with **one tool**. Acquire more through narrative (salvage, trade, reward) — never loot drops.

> `[FEEDBACK]` Did tool choices create interesting trade-offs? Did the lack of upgrades feel liberating or limiting?

---

## 10. The Chronicle

The Chronicle is the session journal, maintained by the system. It records:
- **Events** described in plain language.
- **Track changes** (e.g., Wealth 5→6).
- **Bond shifts** (e.g., "Bond with Kael strengthened to DEEP").
- **World Clock changes** (e.g., "Korr Wealth 3→2").
- **Player goals** (self-declared objectives).
- **Player narrative entries** (from the Narrative Logbook — optional, player-authored).

The Chronicle is generated by a fixed schema. The player may inject their own narrative text at any point, but this is never enforced.

**At session end**, the system appends a **Session Debrief:**
- Final tracks, bonds, world state.
- Key decisions and consequences.
- Responses to `[FEEDBACK]` prompts encountered during play.

> `[DESIGN INTENT]` The Chronicle replaces character sheet review and session notes. Digitally it is Mode B. In tabletop it is the session log.
>
> `[FEEDBACK]` Did the Chronicle feel like a living document or a log dump? Was the debrief useful?

---

## 11. Win & Loss Conditions

No single victory screen. Sessions end by player choice or defeat trigger.

**Victory (across sessions):**
- Active goals fulfilled — especially EPIC goals.
- Community stabilized (home sector tracks held or improved).
- Bonds deepened (at least one DEEP, none severed through neglect).
- Network built (positive standing with an outside group).

**Defeat (immediate):**
- **Stranded:** Supplies track reaches bottom tier in deep space, no reachable sector.
- **Exiled:** All bonds severed, no group offers docking.
- **Crew lost:** Full desertion from failed mutiny.
- **Home collapsed:** Home sector tracks all at bottom tier.

> `[FEEDBACK]` Did victory conditions feel worth pursuing? Did defeat feel dramatic or frustrating?

---

## 12. Quick Reference — Session Flow

```
1. SETUP
   - Map (5–7 sectors with track values)
   - Character (tracks, 3 bonds, 1 tool, 3–5 crew)
   - Declare at least 1 goal (MAJOR or EPIC, community/bond-anchored)
   - Home sector, starting situation
   - Name at least 2 non-bonded community members at home sector

2. PLAY LOOP
   a. System shows current state
   b. Player declares intent (travel / interact / act)
   c. IF TRAVEL: Pre-departure sequence (§4.1)
      - Community cost (oracle roll → pick from options)
      - Crew checks (oracle roll per crew → pick from options)
      - Supply allocation
      - Travel: per sector → Supplies -1, encounter check, World Clock +1
   d. IF ARRIVAL: Community-first sequence (§4.2)
      - Sector current state (track values, changes)
      - Post-docking: community members, mood, hooks
   e. Action Check if needed (§3)
      - Roll 3d6 + modifier → outcome tier
      - System rolls oracle → shows option list(s)
      - Player picks from options → tracks update
   f. Player writes Narrative Logbook entry (optional)
   g. World Clock tick on tick-triggering actions
   h. System checks: NPC notifications, messages, consequences
   i. Repeat

3. SESSION END
   - Session Debrief (state + feedback)
   - Chronicle saved
```

---

## 13. System Output Rules

> **The system is a deterministic board, not a storyteller. Narrative authorship belongs to the player.**

### 13.1 Output Format

The system outputs structured data only:
1. **Header:** Location, Phase, World Clock tick.
2. **Current State:** Short, factual sentences about track values, tags, and NPC presence. No adjectives or emotion.
3. **Option Lists (after Action Check):** Pre-authored Advantage and/or Disadvantage options from the oracle entry. Each option is a clickable mechanical choice.
4. **Hooks:** Table of available actions with types.
5. **Prompt:** Asks the player to: select an option, declare an action, or write a Narrative Logbook entry.

### 13.2 Forbidden Output

If the system produces any of these, the output must be corrected:
1. **Story text:** No paragraphs describing setting, atmosphere, or mood.
2. **NPC dialogue:** No quoted or paraphrased speech.
3. **Invented backstory:** Do not author what an NPC "thinks." The player authors NPC backstory; the system relies on tags and oracles.
4. **Opinions:** No judgment on narrative significance.
5. **Suggestions:** Never suggest or frame which action the player should take.
6. **Hand-picked oracles:** Oracle results MUST be generated via RNG.

### 13.3 System Responsibilities
- **Track Everything:** Every mechanical change (tracks, tags, clock) goes in the Chronicle. Nothing is resolved silently.
- **Maintain the World Clock:** Apply pressure. Let sector tracks change. Do not artificially stabilize sectors.
- **Named Community Impact:** For every track change, state who in the community is affected.

---

## Appendix A: Prohibited Mechanics

From TRUTH_PROHIBITED-SEAMS.md:

**Game Design Constraints:**
1. **No speculative market trading.** Trade is narrative, track-based.
2. **No system-generated story text.** The system outputs data only. The player writes the story.
3. **No colony building.** Player cannot construct or modify stations.
4. **No gear progression.** Tools are lateral. No tiers, no rarity, no scaling.
5. **No FTL communication.** News travels at 1 tick per sector.
6. **No lethal human combat.** Humans yield or retreat, not fight to the death.
7. **No background economy simulation.** The world changes because of the player, not invisible math.

**Code Constraints:**
8. **No 3D on-foot navigation.** All station interaction is through 2D menus.
9. **No dynamic map generation.** Map is fixed.

> `[FEEDBACK]` Did any prohibition block fun? Did any feel unnecessary? Should new prohibitions be added?
