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

The simulation is strictly event-driven. Time moves forward in discrete "Ticks" via two distinct clock contexts:
- **Mode A (3D Sector Travel Clock):** Ticks **only when completing 3D sector travel** between nodes.
- **Mode B (Per-Board-Session Clock):** Resets to Tick 0 whenever a contextual board is opened and increments by +1 per action execution.
- **Player-Driven Primary:** Sector degradation tags, track decay, and random environmental event triggers are purged. The world state mutates cleanly in direct response to player actions and physical location. *The clock's pressure is strictly tied to material entropy, wear, and resource drain—serving as mechanical friction, not a biological doom clock.*

---

## 2. The Simulation Layers

The game rules are divided into clear layers that define the board state.

### Layer 1: The Map
- The physical layout of star systems and the interstellar jump network.
- **Rule:** Static and fixed, but organized via **Progressive Spatial Scaling**. Difficulty and environmental risk scale geometrically as the player moves deeper into the network away from the safe origin sector.
- **Dual Travel:** Dictates both the local sector travel clock ticks required to travel between planetary nodes, and the overarching interstellar traversal deeper into the network.

### Layer 2: The Board State
- Tracks sector conditions and asset states via **Visual Tags and Tokens**. (Numeric 0-10 progress tracks are purged).
- **Rule:** Board tags and tokens mutate directly from player actions and contextual interaction boards.
- Tags and tokens provide visual information representation and dictate available opportunities.

### Layer 2.5: The Vessel Layer
- A streamlined registry tracking active vessels.
- **Rule:** Vessels move between map nodes on sector travel clock ticks. NPC availability on the 2D board is intrinsically linked to their vessel's current location, unless they are permanent station residents.

### Layer 3: The Social Web
- The network of named NPCs and their relationships.
- **Rule:** NPCs do not simulate complex background lives. Their states, tags, and availability are updated via the World Clock and direct player interactions.
- **Interaction Architecture:** Two-layer system — a universal modular phrase library (Layer 1) for routine interactions, and authored vignettes (Layer 2) for key moments. Shared experience vignettes apply to any NPC present during a triggering event.
- **Companion bonds** are persistent and tied to the NPC, not the ship. Bond tracks advance through player action only (no decay). NPCs can transfer between ships/stations.
