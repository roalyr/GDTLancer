# GDTLancer Mechanics Rework Backlog

This document tracks mechanical design notes and feedback collected during TUI playtesting. These items are slated to be addressed during the upcoming mechanical rework phase.

## 1. Action Modifiers & Bond Prompts
**Feedback:** Not every action should have a bond modifier prompt.
**Current State:** The TUI generically prompts for a Bond modifier (Deep/Severed) before every single action roll regardless of context.
**Future Implementation:** 
- Restrict bond prompts to social actions (e.g. `convince`, `petition`) or actions where a bond is narratively linked. 
- Alternatively, require the player to explicitly choose "Invoke Bond" from the main action menu rather than forcing it into the generic flow for things like `scan` or `navigate` where relationships don't mechanically apply.

## 2. Conversation Topic Matrix (The "Oracle -> Mechanics" Bridge)
**Feedback:** When back to improving mechanics, consider that all parts of dialogue have mechanical resolutions. (e.g. "A warning" -> what mechanical outcome? "A skill" -> should have a mechanical part to outcome).
**Current State:** Conversations roll a Seed (e.g., "A warning", "A skill") and a Disposition. Currently, the TUI offers 4 generic mechanical outcomes (Gain Intel, Gain Common Cause, Lose Morale, Nothing) regardless of the specific Seed rolled.
**Future Implementation:** 
- The Conversation Seed should directly dictate the available mechanical stakes. 
- *Example:* If the Seed is "A warning", the outcome options should mechanically reflect avoiding danger (e.g., "Take heed: Gain +1 to next Cautious roll" or "Ignore it: Sector Security drops by 1").
- *Example:* If the Seed is "A skill", the outcome options should reflect training or tools (e.g., "Learn from them: Gain temporary Tool tag").
- **Action Item:** Create a predefined matrix/dictionary that maps the 12 conversation seeds to specific mechanical outcomes instead of using generic options.

## 3. Advanced Hook Resolution Options
**Feedback:** Hook resolutions currently drop the player into a generic action prompt.
**Current State:** Resolved in TUI by explicitly forcing a choice between "Resolve with Action" or "Dismiss".
**Future Implementation:** 
- Expand Hooks to have multiple defined *paths* to resolution (e.g., "Resolve via Violence (Requires 'command')", "Resolve via Subterfuge (Requires 'investigate')").
- The Hook generation logic could be updated to explicitly dictate which 1 or 2 Actions are valid to resolve it, rather than leaving the cognitive load on the player to pick a valid action from the master list.

## 4. Custom Narrative Logs Integration
**Current State:** TUI log inputs were previously capped at 80 characters (now expanded to 500).
**Future Implementation:** If players want to write multi-paragraph journal entries, the standard `curses` input line is still limiting. We could implement an integration where selecting a "Long Log" option temporarily drops the player into their default terminal editor (like `nano` or `vim`) via `curses.def_shell_mode()`, allows them to write a full markdown entry, and pulls it back into the Chronicle upon closing.

## 5. Hook Generation Chaining
**Feedback:** Hook resolution immediately triggers a new hook, effectively producing a never-ending chain of tasks. This should be addressed.
**Current State:** Generating Sector Hooks likely replaces resolved hooks or triggers immediately upon resolution/time advancement, leading to task fatigue.
**Future Implementation:** Implement a cooldown on hook generation or tie new hook generation strictly to specific events (e.g. entering a new sector, specific conversation outcomes, or explicitly spending time "Gathering Rumors") so the player isn't buried in an infinite treadmill of immediate tasks.

## 6. Bond Numeric Progress
**Feedback:** Bonds should clearly show numeric progress and not just tiers.
**Current State:** Bonds currently advance via strict tier increments ("SEVERED", "FRAGILE", "STABLE", "DEEP"). Tiers change instantly on a single `+1` or `-1` hit.
**Future Implementation:** Add an underlying numeric track to Bonds (similar to the 0-10 Player Tracks). This will allow for smaller positive or negative narrative hits to accumulate gradually over time, rather than a single complication causing a Bond to completely shift from "STABLE" to "FRAGILE" instantly.

## 7. Tool Applicability & Risking Bonds
**Feedback:** Just like not all actions should prompt for a bond as a modifier, the same should apply to tools. Additionally, if switching to a numeric bond track, players could put a specific "unit" of a bond at stake on an action check.
**Current State:** The TUI generically prompts for any tool from your inventory before every action.
**Future Implementation:** 
- **Tool Applicability:** Not all actions are compatible with all tools (e.g. using a "Survey array" to `convince` a guard). We need to map which actions are valid for specific tool tags. This will require thorough tool content writing and ambiguity resolution to ensure tools feel mechanically distinct and narratively cohesive.
- **Bond Stakes:** With a numeric bond track (see point #6), a player could explicitly wager a point of Bond strength to gain a modifier on an action check, risking the relationship mechanically rather than just passively receiving a buff from it.

## 8. Multidimensional Oracle & Tag Mapping
**Feedback:** When reworking oracle maps, make sure not to forget about tags. The Oracle becomes a multidimensional complex tree, so working with it might require special approaches to ensure good mapping between entities.
**Future Implementation:** 
- The procedural Oracle outputs shouldn't exist in a vacuum. A complication or opportunity generated by the Oracle needs to "know" about the player's active tags, the sector's properties, and available tools. 
- Because the Oracle is expanding from simple tables into a heavily interconnected graph of possibilities (Actions -> Tags -> Bonds -> Consequences), we should explore a dedicated data structure (like a weighted entity-component matrix) for generating context-aware outcomes rather than relying on flat random lists.
