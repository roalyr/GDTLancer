<!--
PROJECT: GDTLancer
MODULE: TRUTH_PROHIBITED-SEAMS.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_RULEBOOK.md; TRUTH_GAME-LOOP-VISION.md
LOG_REF: 2026-07-13
-->

# GDTLancer - Banned Features List

This list tracks features and rules that are explicitly banned from the game. This keeps the project focused and prevents it from turning into a generic space simulator.

## 1. No Trading Simulators
- **Rule:** The player cannot buy and sell goods for profit on a market screen.
- **How it's built:** The game does not show money as a number. The economy only uses 0-10 resource tracks (like Wealth and Supplies) that change through game events.
- **Why:** To prevent the game from becoming a spreadsheet about trading cargo.

## 2. No Walking Around
- **Rule:** The game will not have 3D characters walking around stations or planets.
- **How it's built:** All station activities (talking to people, managing goals) happen entirely through 2D menus.
- **Why:** Keeps the project simple and avoids the massive amount of work needed for 3D level design and character animation.

## 3. No System-Written Stories
- **Rule:** The game engine must never write paragraphs of story text, dialogue, or descriptions.
- **How it's built:** The engine only gives data (numbers, tags, and menus). The player writes the actual story using the Narrative Template Logbook.
- **Why:** Making the engine write story text leads to boring, repetitive reading. The game provides the rules; the player writes the story.

## 4. No Background Economy Simulations
- **Rule:** The game does not simulate an invisible economy where NPCs trade and change the world while the player is away.
- **How it's built:** The world only changes because of the player. Communities lose resources only if the player fails a mission or if the player spends time traveling.
- **Why:** Invisible background changes confuse players. Changes to the world should feel like direct results of the player's actions.

## 5. No Base Building
- **Rule:** The player cannot build, design, or place station modules or planetary bases.
- **How it's built:** The map and stations are pre-built. 
- **Why:** The player is just a pilot trying to survive in a community, not a god-like manager.

## 6. No Loot Grinding or Number Scaling
- **Rule:** Ship parts and character gear do not have levels, rarities, or increasing stats (like "Level 5 Laser" or "Epic Shields").
- **How it's built:** Upgrades give you new abilities but always have a trade-off (e.g., adding a mining laser takes up cargo space).
- **Why:** Keeps the focus on surviving and helping communities, rather than endlessly grinding for bigger numbers.

## 7. No Instant Communication
- **Rule:** Characters cannot talk instantly across different star systems.
- **How it's built:** Messages take time to travel. It takes 1 tick of the World Clock per sector for a message to arrive.
- **Why:** Makes space feel huge and lonely.

## 8. No Battles to the Death Against Humans
- **Rule:** Human ships do not fight to the death and do not blow each other up.
- **How it's built:** Human NPCs will run away or surrender when losing. If the player loses, they are salvaged or face social consequences, rather than getting a "Game Over" screen.
- **Why:** In this setting, ships and pilots are rare and valuable. Blowing them up makes no sense for survival.

## 9. No Random Map Generation
- **Rule:** The map of star systems and jump routes must be completely fixed.
- **How it's built:** Sector connections are static. The game can spawn temporary points of interest inside a sector, but the map itself does not change.
- **Why:** Prevents the code from becoming too complicated with endless random map generation.

---

## Rules for Adding to This List
- Only the Architect can add new banned features to this list.
- Developers and Testers cannot add to this list.
