<!--
PROJECT: GDTLancer
MODULE: TRUTH_PROHIBITED-SEAMS.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md
LOG_REF: 2026-07-24
-->

# GDTLancer - Banned Features List

This list tracks features and rules explicitly banned from the board game design to maintain focus.

## 1. No Trading Simulators
- **Rule:** No buying/selling goods for profit on market spreadsheets.
- **How it's built:** The economy uses 0-10 resource tracks (Wealth, Supplies) altered by Action Checks and Impact Cards.

## 2. No 3D On-Foot Navigation
- **Rule:** The game will not feature 3D characters walking around.
- **How it's built:** Mode B uses a 2D board with illustrated scenes (Layered Depth Mat) and sprite-based NPCs. All social and strategic gameplay occurs here.

## 3. No System-Written Stories
- **Rule:** The engine never writes prose or dialogue.
- **How it's built:** The system only outputs board state, tags, and Impact Cards. The player provides the narrative imagination.

## 4. No Unbound Background Economy
- **Rule:** The game does not simulate an invisible, dynamic economy. 
- **How it's built:** World changes are primarily player-driven via the Board Action Loop. However, the **World Clock** can apply systemic sector pressure (e.g., gradually draining a track over time), forcing the player to react.

## 5. No Base Building
- **Rule:** The player cannot design or place station modules.
- **How it's built:** The 2D board layouts are fixed representations of the community.

## 6. No Loot Grinding or Number Scaling
- **Rule:** No leveled gear or rarity tiers.
- **How it's built:** Upgrades function as Cards with specific tags and mechanical trade-offs, not scaling modifiers.

## 7. No Instant Communication
- **Rule:** Information takes time to travel.
- **How it's built:** Delayed interactions are processed via World Clock ticks.

## 8. No Lethal Human Combat
- **Rule:** Human ships do not fight to the death. Pilots are rare and valuable — blowing them up makes no survival sense.
- **How it's built:** Human NPCs yield or retreat when losing. Player defeat leads to social consequences, not "Game Over."

## 9. No Random Map Generation
- **Rule:** The overarching map of star systems is fixed.
- **How it's built:** Sector connections are static, even if internal nodes or tags change dynamically.
