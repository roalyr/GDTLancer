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
- **The Machine:** Handles the raw 3d6 dice rolls, visual tags and tokens, per-board-session clocking, sector travel clocking, and board layout.
- **The Player:** Provides 100% of the narrative imagination. The system provides visual cues and mechanical impact; the player imagines the fiction.

**Crucial constraints:**
- **No system-generated prose.** The engine outputs tags, tokens, raw numeric dice totals, and state changes. It never writes story text.
- **Visual impact over text.** Changes to the world are reflected visually on the board via tags and tokens (numeric 0-10 progress tracks and TTRPG action check math are purged).
- **Implicit Goals.** Goals are mechanically implicit. The player works toward them on the board without formal declaration or rating.

---

## 2. The Board Action Loop

All interactions on the 2D board follow a strict loop:

1. **Target Node:** The player selects an interactive node on the board (e.g., an NPC token, a vessel, a terminal).
2. **Action Assembly:** The player selects a single applicable **Asset Card** (tools, situational gear, tags, or statuses). Only one card can be selected at a time. Asset Cards act as lateral verb expanders rather than stat buffs.
3. **Raw 3D6 Dice Roll:** The system rolls 3D6 and outputs the raw numeric dice total. (TTRPG difficulty math, success/failure margin checks, and risky/cautious approaches are purged).
4. **Board Mutation:** The player resolves outcomes, mutating the board state (e.g., altering tags, mutating tokens, or updating target states).

---

## 3. Two Modes of Play

### Mode A: 3D Flight
- Focuses on real-time 3D flight and spatial navigation between nodes.
- Acts as a **Visual Archaeological Canvas** where storytelling relies on environmental geometry, wear, and derelicts. (No detached text logs or encyclopedia pop-ups).
- **Sector Travel Clock:** The global World Clock advances **only when the player completes a 3D sector travel**.
- Uses the **Command Glass** for system overlays and minimal HUD.

### Mode B: 2D Board
- The primary strategic and social interface featuring **Contextual Board Sub-Types**:
  - **Station Tabletop Interface** (docking & station interactions).
  - **Vessel & Crew Tabletop Interface** (character, NPC crew, and vessel management).
  - **Stellar Survey & Prospecting Board** (celestial body exploration & prospecting).
- **Per-Board-Session Clock:** Each board maintains its own session clock that **resets to Tick 0 when opened** and increments by +1 per action execution/dice roll.
- Utilizes clean 2D board game conventions (tokens, visual tag readouts, asset cards, raw 3D6 dice rolls).
- NPCs are tracked by name, tags, and board state, represented via board tokens rather than complex paper-doll sprite systems.

---

## 4. Hooks and Communities

- **Hooks from Board State:** Missions and opportunities arise naturally from the board's tags and tokens, not from exclusive quest boards or numeric progress tracks.
- **Integration:** Communities are integral to the setting, but the loop fully supports **loner roleplay** as a viable path.
