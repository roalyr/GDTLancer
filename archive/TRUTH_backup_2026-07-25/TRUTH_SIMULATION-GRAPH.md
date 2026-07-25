<!--
PROJECT: GDTLancer
MODULE: TRUTH_SIMULATION-GRAPH.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md
LOG_REF: 2026-07-24
-->

# GDTLancer - Simulation Rules

**Version:** 3.0
**Date:** 2026-07-24
**Status:** Approved (Digital Board Game Refactor)

---

## 1. The World Clock (Core Engine)

The simulation is strictly event-driven. Time moves forward in discrete "Ticks."
- **Tick Triggers:** Major actions (travel, significant Board Action Loops) advance the clock.
- **Tick Resolution:** When the clock advances, the system processes delayed events, vessel movements, and applies **sector pressure** (e.g., slowly decaying a community track to force player intervention).
- **Player-Driven Primary:** Beyond clock pressure, the board state mutates directly in response to the player's Action Checks and chosen Impact Cards.

---

## 2. The Simulation Layers

The game rules are divided into three clear layers that define the board state.

### Layer 1: The Map
- The physical layout of star systems and jump routes.
- **Rule:** Static and fixed. Dictates the time cost (Ticks) required to travel between nodes.

### Layer 2: The Board State
- Tracks the health of a sector using 0-10 tracks (Wealth, Security, Morale, Supplies) and active Tags.
- **Rule:** Sector tracks change primarily from player actions (Impact Cards) but **can also change from World Clock pressure**.
- Tags provide mechanical hooks for Action Assembly and dictate available opportunities.

### Layer 2.5: The Vessel Layer
- A streamlined registry tracking active vessels.
- **Rule:** Vessels move between map nodes on World Clock ticks. NPC availability on the 2D board is intrinsically linked to their vessel's current location, unless they are permanent station residents.

### Layer 3: The Social Web
- The network of named NPCs (represented by up to 1,500 sprite variations) and their relationships.
- **Rule:** NPCs do not simulate complex background lives. Their states, tags, and availability are updated via the World Clock and direct player interactions on the board.
