<!-- PROJECT: GDTLancer -->
# Strategic Roadmap

## Current Phase
The game is transitioning from a solo TTRPG with an LLM GM to a 2D digital board game built in Godot 3.6. It serves as an automated playing board with two roles: Machine (state, dice, tracks, world clock, tags, board layout) vs Player (narrative imagination). The board action loop follows: Target Node -> Action Assembly -> Action Check -> Board Mutation.

## Milestones

### M20: Simulation Rework (Event-Driven)
Replace the old cellular automata with an event-driven World Clock system.
- Replace the old Freelancer-shaped cellular automata with an event-driven World Clock system.
- Sector tracks change from player actions and World Clock consequences, not invisible background math.
- Vessel Layer: vessels as tracked entities with routines, positions, NPC assignments.
- This is a prerequisite for all board game mechanics.
- Dependencies: None
- Done criteria: System is fully event-driven with basic vessels tracking correctly

### M21: Board Mechanics Core (The Kernel)
Implement the board action loop and minimum viable mechanical kernel.
- Implement the board action loop: Target → Assemble → Check → Mutate.
- 4 player tracks (Health, Wealth, Morale, Supplies) with tier system (0-10 progress, tier shifts).
- 3d6 action check with Cautious/Risky approach split.
- Impact Cards system (Advantage/Disadvantage drafting from oracle tables).
- Tags on board nodes.
- World Clock tick-triggering.
- This is the minimum viable mechanical kernel.
- Dependencies: M20
- Done criteria: Actions can be assembled and resolved with 3d6 impacting tracks

### M22: Mode B UI — Layered Depth Mat
Implement the 2D scene board with illustrated backgrounds and paper-doll NPCs.
- Implement the 2D scene board (Zone B) with illustrated backgrounds.
- Paper-doll NPC sprite system (base poses × heads × torso overlays, grayscale, room-lighting shaders).
- Slot anchor system for compartments (3-5 NPCs per scene).
- Zone A (status bar) and Zone C (action tray) with black backgrounds and HUD-style elements.
- Mode A ↔ Mode B transition system.
- Dependencies: M21
- Done criteria: Transitions between Mode A and Mode B work smoothly with proper layout

### M23: Oracle Integration
Integrate oracle tables as data-driven context generators.
- Wire oracle tables as data-driven context generators within the action resolution pipeline.
- Oracle rolls produce Impact Card options (Advantage/Disadvantage lists).
- Complication and Opportunity oracle entries mapped to concrete board mutations.
- Oracle tables as .tres resources (reuse archived data).
- Dependencies: M21
- Done criteria: Oracle properly provides data-driven context mapping to impact cards

### M24: NPC & Bond System
Add NPC tags, bond strengths, and their visual presence.
- NPC cards with tags, bond strength (FRAGILE/STABLE/DEEP).
- NPC visual presence in Mode B scenes (paper-doll composited sprites).
- Bond-based modifiers to action checks.
- NPC-initiated notifications via World Clock.
- Tight-beam communication system (delayed messages).
- Dependencies: M21, M22
- Done criteria: NPCs have stats that impact checks and properly show in Mode B UI

### M25: Community & Sector Interaction
Integrate community presence and sector interactions.
- Community presence in sectors (named residents, mood, daily pressure — visual on board).
- Sector arrival/departure sequences with weight.
- Hook generation from board state (not hand-authored quest lists).
- Environmental events from sector track degradation.
- Dependencies: M24
- Done criteria: Interacting with sectors generates relevant hooks and triggers events

### M26: Art Pipeline — NPC Sprites
Produce NPC grayscale sprite assets.
- Produce the 25-55 grayscale sprite assets (5 poses × 2-3 body types, 5-10 heads × 2-3 orientations, 5-10 torso overlays).
- Lore-accurate zero-g styling (NBP poses, tethers, functional gear).
- Room-lighting shader for scene integration.
- Dependencies: M22
- Done criteria: All base NPC sprites and components generated and integrated into the paper-doll system

### M27: Art Pipeline — Location Backgrounds
Produce dithered location background art.
- Produce location background art (dithered, 16-colour, 1-point perspective interiors).
- Zero-g architecture (no floor/ceiling, handrails on all surfaces).
- Scope TBD based on sector count.
- Dependencies: M22
- Done criteria: Base set of dithered 16-colour location backgrounds completed

### M28: Playable Board Game MVP
Integrate previous milestones into a 1-hour playable session.
- Integration milestone: wire M20-M27 into a playable 1-hour session.
- Player can dock, interact with NPCs on the board, take actions, see consequences.
- Mode A flight → Mode B board transitions work end-to-end.
- World Clock applies pressure over time.
- Validation: manual playtest.
- Dependencies: M20, M21, M22, M23, M24, M25, M26, M27
- Done criteria: Manual playtest of 1-hour session validates gameplay loop works smoothly
