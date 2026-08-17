<!-- PROJECT: GDTLancer -->
# Strategic Roadmap

## Current Phase
GDTLancer is a **hybrid tactical and social board game** built in Godot 3.6 with two modes of play.

**Mode A** is a real-time 3D flight environment — a hand-crafted, visual-archaeological canvas where storytelling occurs through geometry, derelicts, wear, and shadow. The Cinematic Space Camera (dynamic FOV, drift-lag, thruster vibration) communicates mass and scale organically.

**Mode B** is a 2D tactical and social interface. The player manages a **Ship Tableau** (slotted Module Cards defining capabilities), a **Card Collection** (scrollable inventory of Field Cards, Possessions, Consumables), and **Companions** (3-5 per ship, authored dialogue, persistent bond tracks). Resolution is **card-based throughout** — no dice. External encounters spawn **Contextual Boards** (Exploration: branching card path; Social: dialogue + card exchange). The persistent **Ship Interior** is always accessible for downtime and companion bonding.

The world is a one-way frontier: a vast network of precursor ruins accessed via a one-way gate, with progressive spatial scaling (difficulty scales geometrically with depth). Progression is lateral (expanded mechanical verbs via Asset Cards, not numerical inflation). See TRUTH_GAME-LOOP-VISION.md and TRUTH_EXPLORATION-PILLARS.md.

---

## Completed Milestones

### M20: Simulation Rework (Event-Driven) [x]
Replace the old cellular automata with an event-driven World Clock system.

### M21: Board Mechanics Core (The Kernel) [x]
Implement board action loop and minimum viable mechanical kernel. *(Note: This used 3d6 — superseded by card-based resolution. Legacy code to be refactored.)*

### M22: Mode B UI — Board Interface [x]
Mode A ↔ Mode B transition system and base board interface.

### M23: Impact Card Tables (Data-Driven Outcomes) [x]
Data-driven outcome tables for board mutation.

### M24: NPC & Bond System [x]
NPC tokens, bond strength, tag-driven board presence.

### M25: Community & Sector Interaction [x]
Community presence, sector arrival/departure, hook generation.

### M26: Art Pipeline — Mode A Environment [x]
Hand-crafted Mode A 3D environment assets.

### M27: Art Pipeline — Mode B Visual Style [x]
Base Mode B board visual language.

### M28: Asset Card Library (Lateral Progression Corpus) [x]
Core set of Asset Cards as lateral verb expanders.

### M29: Playable Board Game MVP [x]
Integration of M20–M28 into a 1-hour playable session.

---

## Active & Upcoming Milestones

### M30: Card System Refactor (Collection Model)
Replace the 3d6 action loop with a card-based resolution system throughout Mode B.
- Refactor the Board Action Loop: remove 3d6 checks, replace with card-driven resolution.
- Implement the **Collection** model: scrollable inventory panel showing all cards organized by type.
- Enforce **card types**: Module Cards (ship-only, never enter board play), Field Cards, Possessions, Consumables.
- Enforce **one-place rule**: a card slotted into the Ship Tableau is removed from the Collection.
- Implement **Junk cards** as universal crafting fuel and trade fodder.
- Implement **tag-pairing crafting**: visual UI hints when compatible cards are in collection; failed combinations produce junk/scrap.
- Permit small quantitative modifiers (+1, +2) on cards where balancing requires them.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M21, M28
- Done criteria: No 3d6 rolls occur anywhere in Mode B. All resolution is card-driven. Collection panel functional.

---

### M31: Ship Tableau System
Implement the slotted ship capability system.
- ~5 functional slots per ship (start with 4 + 1 unlockable for testing).
- Each slot accepts one Module Card. Filled slot = capability present. Empty slot = capability absent.
- Ship with no minimum operational modules = treated as derelict hull (no Mode A capabilities).
- New slots unlock as unique progression rewards per vessel type.
- Legacy marker accumulation on slots over time. Marker mechanical effects **[TBD — pending degradation mechanic]**.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M30
- Done criteria: Ship tableau renders, Module Cards slot/unslot correctly, capability states propagate.

---

### M32: Degradation Mechanic
Define and implement the card degradation and repair lifecycle.
- Cards degrade under stress (use in high-risk contexts). Degraded cards have reduced effectiveness.
- Fully broken cards become Junk. Junk can be crafted or traded.
- Repair actions restore cards using Junk or specific Possession cards.
- Module Cards in tableau can degrade, removing ship capabilities until repaired.
- Legacy markers on Ship Tableau slots reflect accumulated repair history.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M31, M30
- Done criteria: Card degradation lifecycle (fresh → degraded → broken → junk → repaired) fully functional.

---

### M33: Contextual Board — Exploration
Implement the Exploration Board as a branching card-path mini-game.
- Left-to-right branching path of face-down cards. Lane shifts represent branches.
- Player flips one card at a time. Each flip reveals a reward, hazard, or choice.
- Depth (how far along the path) determines challenge and reward richness.
- Player can retreat at any step, keeping cards already found (push-your-luck).
- Board chaining permitted (exploration triggers social encounter) with anti-loop rules.
- Entry via "Interact" HUD button in Mode A (proximity/line-of-sight to trigger object).
- Per-Board-Session Clock resets to Tick 0 on entry, +1 per action.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M30, M31
- Done criteria: Exploration board spawns from Mode A interaction, resolves via card path, returns to Ship Interior.

---

### M34: Contextual Board — Social & Barter
Implement the Social Board and NPC barter system.
- **Barter:** Card exchange spread. NPC inventory exposed. Player drags cards to propose exchange. NPC accepts/counters based on tags and mood.
- **Dialogue:** Two-layer architecture:
  - **Layer 1 (Modular Base):** Universal phrase library filtered by personality tags, mood, and bond level. Handles routine dialogue, fallback, and getting-to-know-you for all NPCs.
  - **Layer 2 (Vignettes):** Hand-written scenes triggered by conditions (bond thresholds, shared experiences, specific events, card gifts). Every NPC has at minimum: introduction vignette + 1 mid-bond + 1 cap moment.
  - **Shared Experience Vignettes:** Authored once, applicable to any NPC present during the triggering event.
- Dialogue enriched by contextual card prompts: player can play cards (gifts, actions) at appropriate moments to shift NPC mood tags or unlock options.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M30, M24
- Done criteria: NPC inventory visible for barter. Dialogue resolves via modular library with vignettes firing at correct triggers.

---

### M35: Ship Interior (Persistent Home)
Implement the always-accessible Ship Interior as the persistent Mode B home screen.
- Accessible at any time from Mode A via dedicated HUD button (no trigger object required).
- Contains: Ship Tableau view, Collection (scrollable inventory panel), Companion roster, Chronicle review.
- External Contextual Boards overlay the Ship Interior temporarily; on resolution, player returns here (not directly to Mode A).
- Mode B → Mode A exit via dismissal prompt from Ship Interior.
- Companion downtime initiated from here: player selects a companion and spends Time (clock ticks) or cards to trigger available dialogue.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M22, M31, M34
- Done criteria: Ship Interior accessible at all times. All sub-systems (tableau, collection, companions, chronicle) viewable. Downtime dialogue initiable.

---

### M36: Companion System
Implement the full companion bond and arc system.
- **Silent protagonist:** Captain has no authored lines. Player selects from response options. Companion always speaks TO the player.
- **Narrator's voice:** Short, authored narrator lines trigger on curated event list: first jump, first bond threshold, first companion death, first anomaly encounter, end-of-run.
- **Bond tracks:** Advance through player action only. No decay. Bond advances unlock new card interactions, board options, and contextual triggers (gameplay options, not only numbers).
- **Companion roster:** 3-5 per ship. Ships are designed around this number.
- **Fluid composition:** Companions can transfer between ships/stations. Bond tracks are persistent and tied to the NPC, not the ship.
- **Branching arcs:** 2-3 major branch points per companion, gated by contextual conditions.
- **Companion death:** Produces a Memorial Card. No immediate mechanical use — represents loss. Late-game lore may offer transformation. **[TBD]** Death ripple effects on other companions and ship state.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M34, M35
- Done criteria: Bond tracks advance correctly. Vignettes fire at threshold conditions. Memorial Cards generated on death. Companion transfer between ships functional.

---

### M37: Event System
Implement the curated authored event pool driving Mode B content delivery.
- **Curated event pool:** authored events (not generated). Semi-random draw order.
- Pool composition shifts based on current sector, ship state, companion arcs, and narrative progress.
- Events consumed on use (not recycled). Pool replenishes on entering a new sector.
- Starting scope: ~30 authored events for the first sector.
- Modular friction parameters (degradation speed, event intensity) adjustable without penalty.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M35, M36
- Done criteria: Event pool draws correctly based on context. Events consumed and replenished per sector. Friction parameters adjustable.

---

### M38: Failure Cascade & Game-Over
Implement the failure cascade between Mode B and Mode A.
- Mode B failures (broken Module Cards, low morale, companion loss) degrade corresponding Mode A capabilities.
- Game-over only triggers in Mode A when the ship cannot physically function (no minimum operational modules, or specific resource depletion).
- No Mode B hard game-over. Failed boards always return player to Ship Interior in a degraded state.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M31, M32, M36
- Done criteria: Module Card breakage correctly removes Mode A capability. Mode A game-over triggers under correct conditions. No Mode B hard fail.

---

### M39: Mode A — Cinematic Space Camera
Implement the Cinematic Space Camera for Mode A.
- Dynamic FOV based on velocity (faster = wider).
- Drift-to-turn lag: camera leads into turns with appropriate delay.
- Thruster vibration: subtle positional noise scaled to thrust output.
- Goal: communicate mass, velocity, and scale without a ground reference. Avoids rigid/robotic feel.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M22
- Done criteria: Camera feels weighty and responsive. Mass and velocity are perceptible without HUD numbers.

---

### M40: Progressive Spatial Scaling & Dual Travel
Implement the world map with progressive spatial scaling and dual travel layers.
- **Local sector travel:** inter-system traversal. World Clock ticks on completion.
- **Interstellar traversal:** travel deeper into the precursor gate network. Distinct from local travel.
- **Progressive Spatial Scaling:** difficulty, environmental risk, and anomaly strangeness scale geometrically with distance from the origin sector.
- Map is static and fixed. Internal node tags change dynamically.
- Origin sector is safe and accessible. Outer-margin nodes are mechanically locked and visually striking from a distance.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M20, M26
- Done criteria: Both travel layers functional. Spatial scaling demonstrable between origin and outer-margin zones.

---

### M41: Playable Vertical Slice (First Full Loop)
Integrate all active milestones into a playable vertical slice demonstrating the complete game loop.
- Player can: fly in Mode A → interact with trigger object → enter Exploration or Social board → resolve via cards → return to Ship Interior → bond with companion → manage Ship Tableau → return to Mode A.
- Degradation lifecycle visible in one session.
- At least one companion has a 3-vignette arc.
- Event pool delivers at least 5 events in one session.
- Failure cascade demonstrable (breaking a module removes a Mode A capability).
- Outer-margin zone visible and locked from origin sector.
- Validation: manual playtest.
- **Asset Creation Reminder:** Create 1 ship model, 1 structure model, 1 character portrait/asset, 1 soundtrack, and a few stars/planets to reduce the asset backlog.
- Dependencies: M30–M40
- Done criteria: Manual playtest confirms end-to-end loop functional and tonally coherent with vision.
