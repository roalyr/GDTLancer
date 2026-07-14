# Python Sandbox — UX & Narrative Smoothness Analysis

**Scope:** [main.py](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/main.py), [models.py](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/models.py), [oracles.py](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/oracles.py), [epic_session.py](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/epic_session.py), [chronicle.md](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/chronicle.md)

---

## Executive Summary

The sandbox successfully implements the core loop (act → oracle → options → chronicle). But the moment-to-moment *feel* is strained because:

1. **The Named Impact callback fires too often and asks the same question every time.** This is the single biggest flow-breaker.
2. **Oracle options look identical across wildly different narrative contexts.** "Supplies -1" after a "Betrayal" feels the same as "Supplies -1" after a "Power outage."
3. **Conversations are stiff because the node system has no oracle integration.** The player types raw strings into an empty prompt with zero guidance.
4. **The chronicle drowns signal in noise.** Named Impact spam makes it unreadable.

The game's *mechanical* skeleton is working. The *narrative emergence* is not — the system produces data, but the data rarely surprises or inspires.

---

## Part 1: UX Friction Points

### F1. The Named Impact Callback Loop (CRITICAL)

Every single track modification triggers [ask_impact_callback](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/main.py#L106-L115):

```
[NAMED IMPACT RULE] Track 'Morale' changed by -1.
Apply to (P)layer or (S)ector? [P/S]: P
Who in the community is affected by this?
> _
```

This fires on **every** option selected. In a Partial outcome, it fires twice (once for Advantage, once for Disadvantage). In travel with crew checks, it can fire 4-6 times before the player even arrives. The epic_session.py handles this by answering "The engineering crew is exhausted but working hard" to every single prompt — that string appears **40+ times** in the chronicle.

**Why it's a problem:**
- It breaks flow. The player is already mid-decision and suddenly has to write a creative justification for a -1 Supplies change.
- The P/S choice is almost always P. The player rarely wants to hit the sector.
- The "who is affected" question is asked in a vacuum — no context about what just happened. The player can't see the oracle result or the option they selected at this point.
- It trains the player to auto-answer with garbage text.

**Recommendation:** Remove the callback from the selection flow entirely. Instead:
- Track changes apply silently to the player by default.
- Sector track changes are computed by the system deterministically (per the revised rulebook).
- The Named Impact entry is generated *by the system* as a post-selection summary (e.g., "Morale -1 → The dock crew at Korr feels the strain"). The player can optionally override this with their own text in the Narrative Logbook.

---

### F2. The Wall of Text on Every Loop

[print_state](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/main.py#L42-L104) dumps **everything** every turn:
- Player tracks (4 lines)
- Tags
- Tools
- Bonds (3+ lines with NPC goals)
- Goals (1+ lines)
- Crew (3 lines)
- Sector status (1 line)
- NPCs (1 line)
- Hooks (2 lines)
- Notifications (0+ lines)
- Command list (14 lines)

That's ~30-35 lines of output **before the player can act**. By T10, the player stops reading it. The command list alone is 14 lines that never changes.

**Recommendation:**
- Show the command list only on first run or on a `help` command.
- Collapse unchanged state. Only print tracks/bonds/crew if they changed since last display.
- Group output into a compact header: `[T5 | Korr | H:FIT(5) W:POOR(4) M:STY(6) S:ADQ(3)]`

---

### F3. Command Syntax is Fragile

The player must type exact commands like:
```
act command cautious 1 2
travel Korr Anchorage
converse Dockmaster Tyra
```

Typos in NPC names or sector names silently fail. Multi-word names require exact spacing. Bond and tool indices are 1-based but not shown in the command help. The player has to count bonds in the display and remember the index.

**Recommendation:** Add numbered menu shortcuts for common selections. E.g., after showing hooks:
```
1: [Boarding Action] Issue concerning Trust and Equipment (Source: Kaelen)
2: [Community Petition] Issue concerning Scarcity and Resource (Source: Voss)
> 1
```

---

### F4. The Conversation Flow is Disconnected

[do_converse](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/main.py#L351-L365) asks three blank prompts with example text:

```
Topic Node (e.g. 'a shortage', 'a rival'):
Outcome Node (e.g. 'tension increased', 'agreement reached'):
Optional Free Text (dialogue/notes):
```

The player gets zero guidance from the system. No oracle cue, no NPC disposition roll, no conversation seed. The Conversation Seed Oracle (36 entries) and NPC Disposition Oracle (6 entries) exist in [oracles.py](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/oracles.py#L89-L103) but are only accessible through `oracle disposition` and `oracle convo` — **separate commands** the player has to know to type before starting the conversation.

**Recommendation:** Integrate oracles directly into the conversation flow:
```
--- CONVERSATION WITH Voss ---
[ORACLE] Topic suggestion: "A shortage" (roll or type your own): _
[ORACLE] NPC Disposition: Frustrated
Outcome Node (e.g. 'tension increased', 'agreement reached'): _
```

---

### F5. Travel Pre-Departure is a Gauntlet

A single `travel` command forces the player through:
1. Community Cost Oracle → pick option → Named Impact × 1-2
2. Crew Check 1 → pick option → Named Impact × 1-2
3. Crew Check 2 → pick option → Named Impact × 1-2
4. Crew Check 3 → pick option → Named Impact × 1-2
5. Transit: Supplies -1 → encounter check
6. Clock advance

With 3 crew, that's **at minimum 8 option selections and 8 Named Impact prompts** before you even see the destination. In the chronicle, a single `travel Korr Anchorage` generates 15-20 log entries.

**Recommendation:**
- Batch crew checks into a single summary: "Crew readiness: Jace (Good), Rin (Issue: Chart data corrupted), Tova (Good). Resolve Rin's issue?" → single option selection.
- Only show Named Impact summary once for the whole travel sequence, not per-option.

---

### F6. No Undo or Confirmation for Irreversible Actions

If the player misclicks an option (enters "1" when they meant "2"), the track change is applied instantly with no confirmation. Bond modifications are irreversible. There's no `undo` command.

---

### F7. Goal Progress is Fully Manual and Unjudged

`goal_advance <idx> <amount>` lets the player type any number. The epic_session.py uses `goal_advance 2 5` repeatedly to instantly max out an EPIC goal. There is no constraint — the player can type `goal_advance 1 10` and immediately resolve it. The system doesn't check whether the player actually did anything related to the goal.

**Recommendation:** Cap advancement per action at the rank-defined rate (+2 for MINOR, +1 for MAJOR, +1 for EPIC on Risky Success only). The system should ask "Did your last action advance this goal?" rather than accepting arbitrary numbers.

---

### F8. Travel Distance is Hardcoded to 1

All destinations are equidistant ([main.py line 319](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/main.py#L319): `distance = 1`). Traveling from Elace Station to New Eden costs the same as traveling to Korr Anchorage. There is no topology — no adjacency map, no route planning, no distance-based cost scaling.

---

### F9. Multi-Word NPC Names Break Message Targeting

`message Overseer Relt subject` parses as `to_npc="Overseer"` and `subject="Relt subject"` because the command splits on spaces and assumes the first arg is the NPC name ([main.py line 462](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/main.py#L462)). Multi-word names silently fail.

---

### F10. Silent Error Swallowing

Four `except: pass` blocks ([lines 279, 285, 517, 530](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/main.py#L279)) swallow all errors. Invalid bond index? Silent. Bad tool index? Silent. Malformed NPC goal? Silent. The player gets no feedback when a command fails.

---

### F11. `oracle` Command is Undocumented

The oracle command exists ([main.py line 543](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/main.py#L543)) but isn't listed in the command reference that prints every turn. The player has to discover it by accident.

---

### F12. No `help` Command

The 14-line command reference prints on every single turn, but there's no `help` command to show it on demand. The player either sees it constantly (visual noise) or never (if condensed display is implemented).

---

## Part 2: Narrative Emergence Problems

### N1. Oracle Options Are Mechanically Identical

Look at the Complication Oracle options:

| Entry | Option 1 | Option 2 | Option 3 |
|---|---|---|---|
| Equipment failure | Supplies -1 | Gain tag: Damaged Hull | Health -1 |
| Betrayal | Morale -1 | Weaken bond | Wealth -1 |
| Micro-debris storm | Health -1 | Supplies -1 | Gain tag: Hull Breach |
| Resource loss | Supplies -1 | Wealth -1 | Gain tag: Rationing |

Every entry is `[Track -1]` or `[Gain tag: X]` or `[Bond shift]`. The *keywords* differ ("Betrayal" vs "Equipment failure") but the *consequences* are structurally identical. After 5 rolls, the player learns: "It doesn't matter what the oracle says — I'm picking between -1 Supplies and -1 Morale again."

**Why this kills emergence:** The oracle keyword ("Betrayal") should inspire the player to imagine a scene. But because the mechanical consequence is always the same shape (-1 to a track), the keyword becomes decoration. The player stops reading the keyword and just reads the options.

**Recommendation:** Diversify the option structures:
- Some entries should offer **choices between tracks AND a conditional tag** (e.g., "Accept `[Gain tag: Pursued]` or sacrifice `[Supplies -2]` to shake them").
- Some entries should have **asymmetric costs** (e.g., one option is -1 but safe, another is -2 but clears a bad tag).
- Some entries should reference **specific NPCs or sector context** (e.g., "If you have a DEEP bond here: `[No cost, bond absorbs it]`").

---

### N2. The "Conversation" Produces No Mechanical Effect

`converse` is a free action that logs a narrative entry. Period. No tags change. No tracks move. No bonds shift. The system doesn't even roll anything. The player talks to Voss, types "agreement reached," and... nothing happens mechanically. The conversation is invisible to the game state.

This means **the Narrative Logbook is disconnected from the game board.** The player writes story, but the story never feeds back into the system. In the chronicle, narrative entries float as isolated quote blocks between mechanical entries that actually changed something.

**Recommendation:** Conversations should optionally generate a lightweight mechanical effect:
- Roll the Disposition Oracle automatically to set a mood modifier.
- Offer a minor oracle-driven option: "Voss is Hopeful. This could strengthen the bond (+1) or provide useful intel (gain tag). Or just log and move on."

---

### N3. Hooks Are Generic and Meaningless

[generate_dynamic_hook](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/oracles.py#L105-L117) produces:
```
Issue concerning Scarcity and Vessel
```

Every hook follows the pattern `Issue concerning [Theme] and [Focus]`. There is no NPC context, no sector context, no consequence preview. The player sees two hooks that both look like "Issue concerning X and Y" and picks one arbitrarily. The hook type (Boarding Action, Community Petition, etc.) is randomly assigned regardless of theme.

**Why this kills emergence:** Hooks are supposed to be the game's primary action source — the reason the player does things. But these hooks tell you nothing. "Issue concerning Trust and Equipment" could mean anything. The player has to invent the entire scenario themselves with no guidance.

**Recommendation:** Hooks should incorporate:
- The NPC provider's current mood and goals.
- The sector's current track values (low Supplies → supply-related hooks).
- A hint about the Action type required (not random assignment).
- An oracle-generated consequence preview (e.g., "Success: Supplies +1 for the sector. Failure: Bond with Voss weakens.")

---

### N4. The Chronicle is Unreadable

The chronicle is ~263 lines for a ~30-turn session. Of those:
- ~40 are "Named Impact [Player]: The engineering crew is exhausted but working hard." (identical)
- ~30 are World Clock advancement notices
- ~20 are track change entries (redundant with Named Impact)
- ~15 are narrative entries (the actual story)

**Signal-to-noise ratio: ~15/263 = 5.7%.** The narrative entries are buried in mechanical spam. Reading the chronicle after a session is tedious rather than rewarding.

**Recommendation:**
- Remove duplicate Named Impact entries (or aggregate them: "T10-T15: Morale held, Supplies dropped from ADEQUATE to SCARCE").
- Suppress World Clock entries unless something interesting happened on that tick.
- Separate the chronicle into two views: **Mechanical Log** (all track changes) and **Narrative Journal** (only narrative entries + major events).

---

### N5. Tags Accumulate Without Meaning

The player gains tags like `Undetected`, `Clear Path`, `Useful Intel`, `Hidden Route` — but these tags have **zero mechanical effect** in the current implementation. No code checks for tag presence. No modifier is applied when a tag is relevant. Tags are just strings in a list.

In the chronicle, the player gains `Unreliable Charts` three separate times (lines 75, 134, 135). Tags stack as duplicates because `remove_tag` requires exact name match and the player has to manually expire them.

**Recommendation:**
- Tags should affect action modifiers (e.g., `Undetected` → +1 to next Scavenge check).
- Prevent duplicate tags.
- Auto-expire tags when their condition is mechanically met (e.g., `Clear Path` expires after the next travel).

---

### N6. NPC Disposition and Context Are Static

NPCs are initialized with a disposition ("Calm", "Worried", "Frustrated") that never changes. NPC moods don't shift based on events, track changes, or bond modifications. Kaelen is "Calm" at T0 and still "Calm" at T41 despite the world changing dramatically around them.

---

### N7. The "Converse with NPC at wrong sector" Problem

The player can `converse Kaelen` anywhere, even if Kaelen's home sector is Elace Station and the player is at The Scatter. The system doesn't check NPC location. In the epic_session.py, the player converses with Kaelen at every single sector they visit — including sectors where Kaelen doesn't exist.

---

### N8. The System Allows Contradictory Narrative

The chronicle's final entry reads:
> "The shipyard is thriving, and the sectors are united. The family-clan stands strong."

But the EPIC goal "Construct an autonomous shipyard at Orin's Reach" **mechanically FAILED** at T24. The system never prevents the player from narrating victory despite mechanical failure. The narrative and the game state are completely disconnected — nothing enforces consistency.

This is philosophically acceptable ("the player is the narrator"), but it means the mechanical layer and the narrative layer might as well be two separate programs.

---

### N9. Silent Bond Deterioration Contradicts Player Narrative

Voss's bond weakens twice (T7 and T13) because NPC notifications expired. But the player's narrative conversations with Voss remain friendly — "Voss celebrates our victory and offers technical aid" at T26. The system-driven bond damage directly contradicts the player-authored story.

Sera's bond also weakens silently at T32 during a `wait 10` command — the player had no opportunity to respond because they were fast-forwarding the clock.

**Root cause:** The tick-delay consequence system punishes inaction, but the punishment is invisible at the moment it happens. The player doesn't realize their bonds are eroding until they check the state display.

---

### N10. Goal Index Shifting Creates Confusion

The epic_session.py script relies on goal indices that shift when goals are removed. "Retrieve old blueprints from Voss's vault" was added as goal index 4, failed at T5, but then at T9 the chronicle says it was fulfilled — because the index shifted after another goal was removed. The chronicle records conflicting outcomes for the same goal.

---

### N11. hook_resolve is a Void

`hook_resolve` marks a hook as resolved and logs it. Nothing else happens — no oracle roll, no option selection, no track change, no consequence. The hook simply vanishes. This means hooks are narrative prompts with zero mechanical weight. The player has no reason to engage with them except as flavor text.

This breaks immersion. If the player is at Korr Anchorage, they should only be able to talk to NPCs listed at that sector.

---

### N8. epic_session.py Masks the UX Problems

The [epic_session.py](file:///home/roalyr/Software_archive/Games/GDTLancer/python_sandbox/epic_session.py) is an automated test script using pexpect. It answers every prompt with pre-scripted responses:
- Every Named Impact prompt: "The engineering crew is exhausted but working hard."
- Every option selection: `1` (always the first option)
- Every P/S choice: `P`
- All conversation nodes: from pre-written arrays

This test proves the engine *runs without crashing*, but it completely hides the UX problems. A human player would:
- Get fatigued by the Named Impact loop by T5
- Stop reading option lists by T10 (because they all look the same)
- Skip narrative logbook entries by T15 (because they don't affect the game)
- Feel the chronicle is useless by T20

The test script's uniform inputs create a chronicle that *looks* complete but is narratively hollow — every conversation ends in "agreement reached," every impact is the same sentence, every option is #1.

---

## Part 3: What's Actually Working

| Feature | Why it works |
|---|---|
| **The core action loop** | Roll → oracle → pick from list → apply. Clean, fast, no ambiguity. |
| **Tier track system** | The 0-10 progress counter with named tier shifts is satisfying. Seeing "ADEQUATE → SCARCE (Shifted)" is a clear, dramatic signal. |
| **Travel weight** | Pre-departure + supply drain + encounter chance = real cost. Travel doesn't feel trivial. |
| **Clock-driven events** | Messages arriving, notifications expiring, goal reminders — the clock creates genuine time pressure. |
| **Defeat conditions** | All working: stranded, exiled, home collapsed. Actual danger exists. |
| **Chronicle as markdown** | Writing to a .md file with proper formatting is a good idea. The structure is right even if the content is noisy. |
| **Crisis doubling** | Risky extremes (3-5 and 16-18) overriding modifiers creates real stakes for the Cautious/Risky decision. |
| **Notification expiry system** | Tick-delay consequences for inaction are a solid mechanic — just needs visibility. |

---

## Part 4: Priority Fixes for Narrative Smoothness

| # | Fix | Impact on Narrative |
|---|---|---|
| 1 | **Kill the Named Impact callback.** Track changes are silent. System generates the impact text. Player overrides optionally in the logbook. | Eliminates the #1 flow-breaker. Cuts 40+ identical prompts per session. |
| 2 | **Integrate oracles into conversation flow.** Auto-roll Disposition + Conversation Seed when conversation starts. Give conversations an optional lightweight mechanical effect. | Conversations become guided, surprising, and mechanically relevant. |
| 3 | **Diversify oracle option structures.** Asymmetric costs, conditional bonuses, NPC-aware options. | Options feel different from each other. Player reads the keyword. |
| 4 | **Make hooks context-aware.** Use sector tracks + NPC goals to generate specific, grounded hooks. Wire `hook_resolve` to trigger an Action Check. | Hooks become reasons to act, not random labels. Resolving them has consequences. |
| 5 | **Give tags mechanical weight.** Check for tag presence in modifier calculation. Prevent duplicates. Auto-expire when conditions are met. | Tags become meaningful choices instead of ignored strings. |
| 6 | **Split the chronicle.** Mechanical log vs narrative journal. Aggregate repetitive entries. | The story becomes readable. The player wants to re-read it. |
| 7 | **Batch travel prompts.** Single crew readiness summary instead of 3 individual checks. | Travel becomes one decision point, not a gauntlet of 8 prompts. |
| 8 | **Constrain goal advancement.** System-enforced rate limits based on rank. Use stable IDs instead of shifting indices. | Goals become earned achievements, not typed numbers. Index confusion eliminated. |
| 9 | **Make notification consequences visible.** Warn the player 1 tick before expiry. Show the consequence preview. | Bond deterioration becomes a conscious choice (inaction), not an invisible punishment. |
| 10 | **Validate NPC location for conversations.** Only allow `converse` with NPCs at the current sector. | Eliminates the immersion-breaking phantom conversations. |
