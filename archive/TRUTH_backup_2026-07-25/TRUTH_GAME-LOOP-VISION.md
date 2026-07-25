<!--
PROJECT: GDTLancer
MODULE: TRUTH_GAME-LOOP-VISION.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
LOG_REF: 2026-07-24
-->

# GDTLancer - Game Loop Vision

**Version:** 3.0
**Date:** 2026-07-24
**Status:** Approved Architectural Vision (Digital Board Game Refactor)

---

## 1. Core Philosophy: The Automated Playing Board

GDTLancer is a **2D digital board game**, not a story generator or TTRPG. There are two distinct roles in the game:
- **The Machine:** Handles the state, dice math, tracks, the world clock, tags, and board layout.
- **The Player:** Provides 100% of the narrative imagination. The system provides visual cues and mechanical impact; the player imagines the fiction.

**Crucial constraints:**
- **No system-generated prose.** The engine outputs tags, numbers, and state changes. It never writes story text.
- **Visual impact over text.** Changes to the world are reflected visually on the board.
- **Implicit Goals.** Goals are mechanically implicit. The player works toward them on the board without formal declaration or rating.

---

## 2. The Board Action Loop

All interactions on the 2D board follow a strict loop:

1. **Target Node:** The player selects an interactive node on the board (e.g., an NPC sprite, a vessel, a terminal).
2. **Action Assembly:** The player builds their action by combining a Verb, an Approach, and any applicable Cards (tags, items, or statuses).
3. **Action Check (3d6):** The system resolves the action using a 3d6 roll against the current state and applied cards.
4. **Board Mutation:** The outcome generates **Impact Cards** (Advantage/Disadvantage). The player selects their outcomes, instantly mutating the board state (e.g., changing tracks, altering tags, or removing sprites).

*Note: The **Oracle** is not a standalone free-text action. It is an integrated context generator that provides situational tags and parameters within actions and outcomes.*

---

## 3. Two Modes of Play

### Mode A: 3D Flight
- Focuses on real-time 3D flight and spatial navigation between nodes.
- Uses the **Command Glass** for system overlays and minimal HUD.

### Mode B: 2D Board
- The primary strategic and social interface.
- Utilizes the **Layered Depth Mat** to render 2D illustrated scenes.
- **Zones A/C:** HUD-style status bars and action trays on black backgrounds.
- **Zone B:** The central illustrated scene populated by the **Sprite System** (composing up to 1,500 NPC variations from 25-55 grayscale sprites). Capped at 3-5 NPCs per compartment.

---

## 4. Hooks and Communities

- **Hooks from Board State:** Missions and opportunities arise naturally from the board's tags and tracks, not from exclusive quest boards.
- **Integration:** Communities are integral to the setting, but the loop fully supports **loner roleplay** as a viable path.
