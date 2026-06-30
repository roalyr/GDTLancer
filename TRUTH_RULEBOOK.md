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

**Dice:** 3d6 (sum of three six-sided dice). Roll digitally or physically; LLM-GM can simulate.

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

The player character has four **tracks** and a set of **bonds**.

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

Start with **3 bonds** — at least one kin, one professional ally, one from a different clan/faction. The LLM-GM names them and establishes their context.

**Bond shifts:** Bonds strengthen when you act in the NPC's interest or fulfill promises. Bonds weaken when you break trust, abandon them under pressure, or harm their community. A FRAGILE bond that weakens further is **severed** — the NPC becomes hostile or indifferent.

> `[DESIGN INTENT]` Bonds are the progression spine. They should feel like the most important thing on the character sheet — more than wealth, more than health. Losing a bond should sting. Deepening one should feel earned.
>
> `[FEEDBACK]` Did bonds drive decisions? Were 3 starting bonds enough to create tension? Did bond shifts feel earned or arbitrary? Was there a moment where a bond mattered more than a track?
>
> `[IMPL NOTE]` Maps to: `AffinityMatrix`, sub-agent relationship tags, chronicle bond-state display.

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

The player declares a destination and the LLM-GM narrates transit. During travel:
- **Supplies tick down.** −1 progress per sector traversed.
- **Morale may tick down.** −1 progress if traversing HARSH or CONTESTED sectors.
- **Encounter chance.** LLM-GM rolls 1d6: on 1–2, an encounter occurs in transit (distress signal, debris field, hostile patrol, anomaly). Resolve via Action Check or narrative choice.
- **World Clock advances** (§6).

No detailed piloting mechanics in tabletop. Travel is narrated, not simulated.

> `[FEEDBACK]` Did travel feel consequential or like dead time? Was the supply/morale drain rate about right? Did transit encounters add texture or feel like interruptions?
>
> `[IMPL NOTE]` Maps to: Mode A flight, tick-driven metric decay, POI encounter system.

### 4.2 Encounter Phase (Mode B equivalent)

When the player arrives at a sector or triggers an encounter, play pauses for interaction. The LLM-GM presents the situation using sector tags (§5) and the player acts.

**Encounter sources:**
- **Character interaction.** The LLM-GM voices an NPC. Tasks emerge organically from conversation — a stressed station manager needs cargo, a clan elder requests mediation, a stranded crew begs for rescue. **There is no quest board.**
- **Environmental event.** Sector tags trigger forced situations — hull breach in HARSH environment, supply seizure in CONTESTED security, outbreak in DECLINING colony.
- **Bond event.** A bonded NPC reaches out (if in same or adjacent sector) — warning, request, offer, or confrontation.

After resolution: update tracks, bonds, and Chronicle (§10). Player may continue interacting or undock to Travel Phase.

> `[FEEDBACK]` Did encounters feel organic or forced? Did the "no quest board" approach produce enough direction? Were bond events frequent enough to matter?
>
> `[IMPL NOTE]` Maps to: Mode B InteractionWindow, narrative template resolution, GridLayer tag → template mapping.

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
   - Home sector, starting situation

2. PLAY LOOP
   a. Declare intent (travel / interact / act)
   b. LLM-GM narrates using sector tags and voice
   c. Action Check if needed (§3)
   d. Update tracks, bonds, chronicle
   e. Every 2 actions → World Clock tick (§6)
   f. Check mutiny threshold, warnings
   g. Repeat

3. SESSION END
   - Session Debrief (state + feedback)
   - Chronicle = playtest transcript
```

---

## 13. LLM-GM Guidelines

- **Narrate in jargon creole.** Refer to Lore Lexicon (TRUTH_CONTENT-CREATION-MANUAL.md §9).
- **No institutions.** No corporations, empires, navies, trade authorities.
- **NPCs are people.** Named, with families and motivations. Mostly non-pilots.
- **Tasks emerge.** No quest lists. Problems surface through dialogue and pressure.
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
