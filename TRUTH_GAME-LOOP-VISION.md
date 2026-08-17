<!--
PROJECT: GDTLancer
MODULE: TRUTH_GAME-LOOP-VISION.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context
LOG_REF: 2026-08-17
-->

# GDTLancer - Game Loop Vision

**Version:** 4.0
**Date:** 2026-08-17
**Status:** Approved Architectural Vision (Hybrid Tactical & Social Board)

---

## 1. Core Philosophy

GDTLancer marries a **2D tactical board** with **authored narrative**. Two distinct roles:
- **The Machine:** Handles card-based resolution, visual tags and tokens, clocking, board layout, authored NPC dialogue, and the event system.
- **The Player:** Navigates the spatial environment (Mode A), manages the tactical board and card collection (Mode B), and bonds with companions. The player is a **silent protagonist** — their voice lives in the player's imagination. A detached **narrator's voice** punctuates major events.

**Crucial constraints:**
- **Authored Dialogue:** NPCs feature hand-written dialogue via a two-layer system (modular phrase library + authored vignettes). The *universe itself* (the void, the ruins) never generates prose; it relies on visual storytelling.
- **Visual impact over text for mechanics.** World state changes are reflected visually via tags and tokens.
- **Implicit Goals.** Goals are mechanically implicit. No formal declaration or rating.

---

## 2. The Card System

Resolution and interaction are **card-based throughout Mode B.** Dice are not used.

### Card Types
- **Module Cards:** Ship-only. Slotted into the ship tableau. Never enter board play.
- **Field Cards:** Used on contextual boards (exploration, social encounters).
- **Possessions:** Gifts, personal items, crafting materials. Used in companion bonding and barter.
- **Consumables:** Single-use items expended on boards or during ship events.

### Card Economy
- The player's cards form a **collection** (not a deck). All cards are visible in a scrollable inventory panel, organized by type.
- **Cards exist in one place at a time.** Slotted into the ship = not in collection. In collection = not slotted.
- **Acquisition:** Spatial collectibles (Mode A), barter/trade with NPCs, crafting, companion gifts, board rewards. Basic assets are available via trade (functional society provides baseline access).
- **Asset Cards can degrade, break, and require repair**, making the ship's physical decay tangible. **[TBD]** Degradation mechanic needs dedicated design pass.
- **Junk cards are universal crafting fuel.** Never truly worthless — used as base cost for crafting and as trade fodder.
- **Card crafting:** Tag-pairing system with visual UI hints. Failed combinations produce scrap/junk. **[TBD]** Full rules require degradation mechanic first.
- Small, easily comprehensible quantitative modifiers (+1, +2) are permitted on cards where balancing requires them.

---

## 3. Two Modes of Play

### Mode A: 3D Flight
- Focuses on real-time 3D flight and spatial navigation between nodes.
- Acts as a **Visual Archaeological Canvas** where storytelling relies on environmental geometry, wear, and derelicts. (No detached text logs or encyclopedia pop-ups).
- **Cinematic Space Camera:** Utilizes dynamic FOV, drift-to-turn lag, and thruster vibration to communicate mass, velocity, and scale without a ground reference.
- **Diegetic Minimalist UI:** Explicitly requires functional, in-world dashboard instruments to make piloting mechanically engaging. Pure "zero-HUD" is prohibited.
- **Sector Travel Clock:** The global World Clock advances **only when the player completes a 3D sector travel**.

### Mode B: Tactical & Social Board

Mode B has **two entry types:**
1. **Ship Interior (always accessible).** Dedicated HUD button in Mode A. Provides: ship tableau management, companion interaction/downtime, collection browsing, chronicle review. This is the player's persistent home.
2. **External Boards (contextual).** Triggered by "Interact" button near world objects in Mode A. Spawns a contextual board. When resolved, player returns to ship interior, not directly to Mode A.

**Exit:** Dismissal prompt from ship interior. Player chooses when to return to Mode A.

#### The Ship Tableau
- ~5 functional slots per ship. Each slot accepts one Module Card.
- Filled slot = capability present. Empty slot = capability missing. Ship without minimum operational modules = derelict hull.
- New slots unlock as progression rewards per vessel type.
- Legacy markers accumulate on slots over time. **[TBD]** Marker effects pending degradation mechanic.

#### Contextual Boards
- **Exploration Boards:** Self-contained mini-games for ruins, derelicts, salvage sites. Branching card path (left-to-right progression, lane shifts for branching, depth = challenge). Push-your-luck structure.
- **Social Boards:** NPC encounters via dialogue tree + contextual card prompts (gifts, actions). Each NPC has their own inventory for direct barter via card exchange spread.
- **Hazards are NOT a separate board type.** They are emergent events within other boards or the ship interior.
- **Per-Board-Session Clock:** Resets to Tick 0 on entry, +1 per action.
- Board chaining permitted when context demands it. Anti-loop rules required.
- **[TBD]** Board visual language. **[TBD]** Full mechanics per board type.

#### Companion System
- **3-5 companions per ship.** Ships designed around this number.
- **Bond tracks advance through player action only. No decay.**
- **Bonds expand gameplay options** (new card interactions, board strategies, contextual triggers), not just numerical bonuses.
- **Companions are not bound to the player's ship.** NPCs can transfer between ships/stations. Bonds are persistent and tied to the companion.
- **Companions can die.** Death produces a **Memorial Card** — no immediate mechanical use. Late-game lore may offer transformation.
- **Branching arcs:** 2-3 major branch points per companion. Contextual dialogue triggers gate content behind conditions.
- **NPC Interaction Architecture (Two Layers):**
  - **Layer 1 (Modular Base):** Universal phrase library filtered by personality tags, mood, and bond level. Works on every NPC. Handles routine dialogue, fallback, and getting-to-know-you.
  - **Layer 2 (Vignettes):** Hand-written scenes triggered at conditions (bond thresholds, shared experiences, specific events). Every NPC has at least one (introduction). Depth varies by NPC.
  - **Shared Experience Vignettes:** Authored once, applicable to any NPC present during the triggering event. Fills depth for NPCs with fewer unique vignettes.

#### Event System
- **Curated event pool** with semi-random draw order. Events are authored, not generated.
- Pool composition shifts based on sector, ship state, companion arcs, narrative progress.
- Events consumed on use. Pool replenishes on entering a new sector.

#### Difficulty & Failure
- **Modular friction parameters** (degradation speed, event intensity) adjustable without penalty. Higher challenge produces richer salvage organically as a consequence of depth, not a toggle.
- **Failure cascade:** Mode B failures (broken modules, low morale, companion loss) degrade Mode A capabilities. Game-over only occurs in Mode A when the ship can no longer physically function.

---

## 4. Hooks, Collectibles, and Communities

- **Spatial Qualitative Collectibles:** Discoveries are tied directly to spatial coordinates (geometric anchors) in Mode A, translating into Asset Cards for Mode B.
- **Hooks from Board State:** Missions and opportunities arise naturally from tags and tokens, not from exclusive quest boards or numeric progress tracks.
- **Integration:** Communities are integral to the setting, but the loop fully supports **loner roleplay** as a viable path.
