--- Start of ./0.0-GDD-Internal-Rules-Conventions.md ---

# 0.0 GDTLancer - Internal GDD Rules and Conventions

**Version:** 1.0
**Date:** October 26, 2025
**Related Documents:** `0.1-GDD-Main.md`, `README.md`

---

## 1. Overview

This document defines the structural conventions and formatting rules used throughout the GDTLancer Game Design Documentation (GDD). Adhering to these rules ensures consistency, clarity, and facilitates the project's **transmedia goals**, particularly the eventual extraction of a standalone Analogue TTRPG ruleset.

---

## 2. GDD Structure & Numeration

The GDD is organized into chapters and sub-chapters using a numerical prefix system, followed by a descriptive name.

* **Format:** `X.Y-GDD-<ChapterName>-<SubChapterName>.md`
    * `X`: Represents the major chapter number (e.g., `1` for Core Mechanics, `5` for Gameplay Modules, `7` for Assets).
    * `Y`: Represents the sub-chapter or specific page number within that chapter (e.g., `7.1` for Ship Design Philosophy, `7.2` for Ship Engines).
    * `GDD`: Standard identifier.
    * `<ChapterName>`/`<SubChapterName>`: Descriptive title using PascalCase or hyphenated lowercase.

* **Example:** `5.1-GDD-Module-Piloting.md` is the first page (`.1`) in the Gameplay Modules chapter (`5`).

* **Ordering:** This system ensures files are sorted logically within the repository filesystem and provides a clear hierarchy. The `README.md` file serves as the master index.

---

## 3. Standard Page Structure

To support the project's goal of eventual separation into Digital (Godot) and Analogue (TTRPG) components, most GDD pages describing specific game elements (like Assets or Modules) **must** follow a standardized section structure:

1.  **Header:**
    * **Page Title:** (`# X.Y GDTLancer - Descriptive Title`)
    * **Metadata:** `Version`, `Date`, `Related Documents` (listing all directly relevant GDD pages by filename).
    * **Separator:** `---`

2.  **Section 1: Overview**
    * **Purpose:** Briefly explain the scope and purpose of the page and the element it describes.
    * **Structure Note:** Explicitly state that the document follows the standard 3-part structure (Lore/Godot/Analogue).

3.  **Section 2: Part 1: Lore & Visuals (or Description / Conceptual)**
    * **Purpose:** Contains all player-facing descriptive text, lore justifications, visual descriptions, and aesthetic notes.
    * **Content:** This section should align with the game's established lore and art style. Use tables for comparisons where appropriate.

4.  **Section 3: Part 2: Godot Implementation (or Digital Implementation)**
    * **Purpose:** Details the specific implementation within the Godot Engine (v3.x).
    * **Content:** Defines `Resource` properties, `AgentTemplate` stats, system interactions, specific GDScript function requirements, data structures, and concrete gameplay values used by the digital version. Should reference relevant code files or architectural patterns.

5.  **Section 4: Part 3: Analogue Implementation**
    * **Purpose:** Describes how the element is represented and functions within the tabletop RPG ruleset.
    * **Content:** Defines abstracted stats, `Asset Difficulty` modifiers, special rules, interactions with core TTRPG mechanics like `Action Checks`, `TU`, `WP`, `FP`, and provides formatting guidance for physical components.

* **Note:** Pages defining high-level concepts (like `0.1-GDD-Main.md`) or purely organizational documents (like this one) may omit the strict Part 1/2/3 structure where it doesn't apply.

---

## 4. Rationale for Structure

This strict separation serves a critical long-term goal:

* **TTRPG Extraction:** Once the Godot project is sufficiently mature, the "Part 2: Godot Implementation" sections can be programmatically or manually removed from the GDD.
* **Result:** The remaining content (Overview, Lore/Visuals, Analogue Implementation) forms the basis of a cohesive and functional rulebook and lore guide for the standalone GDTLancer Analogue TTRPG. This structure minimizes the effort required for this transmedia adaptation.

---

## 5. Citations

* **Requirement:** All GDD pages must use the `` format to cross-reference information from other GDD pages. This ensures traceability and helps maintain consistency.

--- Start of ./0.1-GDD-Main.md ---

# GDTLancer - Main GDD

**Version:** 1.9
**Date:** October 31, 2025
**Author:** Roal-Yr

## 0. Introduction

* **Game Title:** GDTLancer (Working Title)
* **Logline:** A multi-platform space adventure RPG where player and AI actions shape a living world. Blends sandbox simulation with narrative mechanics.
* **Genre:** 3D Space Adventure, RPG, Sandbox, Simulation.
* **Theme:** Emergent stories from a simulated world; pragmatic, function-first sci-fi. Focus on managing risk, time, and resources.
* **Target Audience:** Fans of Space Sims (Elite, Freelancer), Sandbox RPGs (Mount & Blade), and Narrative TTRPGs (Stars Without Number, Ironsworn).
* **Platforms:**
    * Primary Digital: PC (Godot 3).
    * Secondary Digital: Mobile (J2ME-style).
    * Analogue: Standalone TTRPG ruleset.
* **Unique Selling Points:**
    * Emergent stories driven by agent actions.
    * A living world that evolves over time.
    * Play on PC, mobile, or as a tabletop RPG.
    * Unique low-poly 3D art style.
    * Uncover world history through gameplay.

## 1. Glossary

* **Action Approach:** Player's stance (`Act Risky` or `Act Cautiously`) that influences an action's outcome.
* **Action Check:** The core dice roll: `3d6 + Modifier`.
* **Agent:** An active entity pursuing goals (Player or NPC).
* **Asset:** A significant non-consumable item (ship, module, gear).
* **Asset Progression:** A meta-progression system where players invest resources (WP, TU) and complete objectives to acquire new assets.
* **Chronicle:** The system that logs major world events and actions.
* **Contact:** An abstract NPC the player interacts with via menus to gain missions, information, and build relationships.
* **Faction:** A distinct political or corporate entity in the game world with which the player can gain or lose standing.
* **Focus Points (FP):** A resource spent to improve an Action Check result.
* **G-Stasis Cradle:** In-lore tech that allows pilots to survive high-G maneuvers (e.g., rapid acceleration, high-thrust industrial actions).
* **Goal System:** System for tracking Agent objectives.
* **Module:** A set of mechanics for a specific activity (e.g., Combat, Mining).
* **Pragmatic Aesthetics:** Function-first ship design philosophy.
* **Preservation Convention:** The widespread cultural and economic norm of valuing ships and skilled pilots, prioritizing disablement and capture over destruction.
* **Reputation:** A narrative stat tracking the player's professional standing (e.g., "Dependable," "Opportunist").
* **Ship Perk:** A positive trait an asset can acquire as achievements.
* **Ship Quirk:** A negative trait an asset can acquire due to damage or failed actions, often imposing a mechanical penalty.
* **Time Clock:** Tracks time. When full, it triggers a World Event Tick.
* **Time Unit (TU):** An abstract unit of time. Actions cost TUs.
* **Wealth Points (WP):** Abstract resource for major purchases, representing an agent's economic power.
* **World Event Tick:** Triggered by the Time Clock; advances the world simulation state.
* **World State:** All data representing the current status of the game world.

## 2. Game Pillars

* **Living World:** The world evolves based on the actions of all agents and the passage of time.
* **Emergent Narrative:** Stories emerge naturally from the simulation and player choices.
* **Meaningful Progression:** Progress by improving skills, completing goals, acquiring assets, and building wealth.
* **Simple, Consistent Rules:** Core mechanics are unified and easy to learn.
* **Player Driven:** Players direct the experience by managing risks, time, and resources.

## 3. Core Gameplay Design

* **3.1. Philosophy:** A simulation-first design. Players interact with game modules (e.g., Piloting, Combat) and make meaningful choices about risk and resource management.
* **3.2. Gameplay Modules:** Game activities, such as:
    * Piloting & Travel
    * Combat (Ship)
    * Trading
    * Interaction (Social)
    * Mining & Industrial
    * Investigation & Exploration
* **3.3. Core Loop:** Players use modules for activities. Key actions require a check, influenced by the player's chosen risk level (`Risky` / `Cautious`). The outcome affects the world and the player's resources (FP, WP, TU).

## 4. Development Framework

* **4.1. Structure:** Development is organized by Layers (complexity), Modules (activities), and Systems (cross-cutting rules).
* **4.2. Development Layers:**
    * **Layer 1 (Core):** Basic module function and core mechanics.
    * **Layer 2 (Narrative):** Goal/Event systems and narrative outcomes.
    * **Layer 3 (Simulation):** NPC agent simulation and world evolution.
    * **Layer 4 (Legacy):** Faction mechanics and long-term consequences.
* **4.3. Phased Plan:**
    * **Phase 1 (Core Loop):** Establish a playable "vertical slice" of the game. Includes basic Piloting, Combat, and Trading modules and their supporting systems.
    * **Phase 2 (Narrative):** Add Mining/Industrial; integrate Layer 2 systems.
    * **Phase 3 (Living World):** Add Investigation; begin Layer 3 simulation.

## 5. Art & Audio

* **Visuals:** "Neo-Retro 3D" - GLES2 rendering, medium-low-poly, hard-edged models, inspired by early 3D graphics.
* **Audio:** Minimalist, functional sound effects and atmospheric music.
* **UI/UX:** A clean, non-intrusive UI that clearly communicates game state and choices. Easy to learn but provides depth for experienced players.

## 6. Technical

* **Engine:** Godot 3 (Primary), potentially other platforms implementing Analogue verison digitally (j2me).
* **Analogue:** A parallel tabletop RPG design using the same core mechanics.
* **Modularity:** A modular architecture to ensure systems are independent and maintainable.

--- Start of ./0.2-GDD-Main-Sayings.md ---

# GDTLancer - Mottos & Sayings

**Version:** 1.5
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9)

## 1. Purpose

This document lists mottos for the game and in-setting sayings that reflect the pragmatic culture of the sector's colonists. These phrases should inform character dialogue and ambient storytelling.

## 2. Game Motto (Development Ethos)

* **"GDTLancer: Delivered as Designed."**
    *(This is an external motto for the development team, reflecting a commitment to the GDD's scope.)*

## 3. In-Setting Sayings & Mottos

These phrases reflect the pragmatic, resilient, and resourceful culture of the people in this sector, shaped by the challenges of scarcity and exploration.

* "Waste not, want not."
    *(The most common adage, deeply ingrained in the culture.)*

* "Measure the cost, master the consequence."
    *(Reflects a cultural focus on calculated risk-taking.)*

* "Every component has a purpose."
    *(Highlights the importance of efficiency, repair, and modularity.)*

* "A broken tool teaches a lesson."
    *(A practical view on failure as a learning opportunity.)*

* "Skill carves status; action defines worth."
    *(The core of a meritocratic, frontier-style society.)*

* "Good salvage makes good neighbors."
    *(A cynical but common phrase related to resource acquisition.)*

* "The void yields to the prepared."
    *(Emphasizes the value of foresight and expertise.)*

--- Start of ./1.1-GDD-Core-Systems.md ---

# GDTLancer - Core Systems (Phase 1)

**Version:** 1.5
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 5.1-GDD-Module-Piloting.md (v1.6), 5.2-GDD-Module-Combat.md (v1.4), 5.3-GDD-Module-Trading.md (v1.1)

## 1. Overview

This document defines the core, cross-cutting gameplay systems required to support the Phase 1 modules (Piloting, Combat, Trading). The definitions and terminology herein are designed to align with the existing project codebase to ensure consistency between design and implementation. All systems listed are located within the `/core/systems/` directory and are added as children to the `WorldManager` node in `main_game_scene.tscn`.

*Note: The `EventBus` is an autoload script (`autoload/EventBus.gd`) used for managing engine-level signals. It is a core piece of the architecture but is not a gameplay system in the same vein as those listed below.*

## 2. System Definitions

### System 1: Event System
* **Code Reference:** `core/systems/event_system.gd`
* **Core Responsibility:** To act as a narrative and world event "oracle." It generates and triggers in-game events based on the passage of Time Units (TU), player actions, and other dynamic world states. These are high-level gameplay events (e.g., an ambush, a market opportunity, a distress call), not to be confused with low-level engine signals handled by the `EventBus`.

### System 2: Time System
* **Code Reference:** `core/systems/time_system.gd`
* **Core Responsibility:** To manage the passage of abstract game time (`Time Units` or `TU`) and its consequences.
* **Phase 1 Functionality:**
    * Operates on the global `GameState.current_tu` variable.
    * Must provide a function `add_time_units(tu_to_add: int)`.
    * When `GameState.current_tu` reaches `Constants.TIME_CLOCK_MAX_TU`, it must:
        1.  Emit a `world_event_tick_triggered` signal on the `EventBus`.
        2.  Call the `Character System` to deduct the periodic `WP` Upkeep cost.
        3.  Decrement `GameState.current_tu` (handling multiple ticks if necessary).
* **Interactions:**
    * **Interacts With:**
        * `Piloting Module`: Free Flight mode will call the function to add `TU`.
        * `Trading Module`: Actions like `Seek Rare Goods` will add `TU`.
        * `Character System`: To apply the `WP` Upkeep cost.
        * `EventBus`: To announce the `World Event Tick`.

### System 3: Character System
* **Code Reference:** `core/systems/character_system.gd`
* **Core Responsibility:** To track and manage the core narrative stats, skills, and social standing for all character agents by providing a stateless API to access `GameState.characters`.
* **Phase 1 Functionality:**
    * Must provide functions to get character data (e.g., `get_player_character()`).
    * Must provide functions to safely add or subtract `WP` and `FP` from a character's data in `GameState` (e.g., `add_wp(uid, amount)`, `get_fp(uid)`).
    * Must provide a function to retrieve skill values (e.g., `get_skill_level(uid, skill_name)`).
    * Must provide a function to handle the `Upkeep Cost` deduction (e.g., `apply_upkeep_cost(uid, cost)`) when called by the `Time System`.
* **Interactions:**
    * **Interacts With:**
        * `Trading Module`: To modify a character's `WP` total.
        * `Combat/Piloting Modules`: To retrieve skill values for `Module Modifiers`.
        * `Time System`: Receives the call to deduct `WP` for upkeep.
        * `GameStateManager`: Provides character data for saving and loading.

### System 4: Inventory System
* **Code Reference:** `core/systems/inventory_system.gd`
* **Core Responsibility:** To manage the contents of all character inventories within `GameState.inventories`. It is a stateless API.
* **Phase 1 Functionality:**
    * Must define the `InventoryType` enum (`SHIP`, `MODULE`, `COMMODITY`).
    * Must provide a function to create a new inventory record for a character: `create_inventory_for_character(uid)`.
    * Must provide generic functions to add/remove assets: `add_asset(uid, type, asset_id, quantity)` and `remove_asset(uid, type, asset_id, quantity)`.
    * Must provide a function to check quantity: `get_asset_count(uid, type, asset_id)`.
* **Interactions:**
    * **Interacts With:**
        * `Trading Module`: The Trade Interface will call this system's functions to modify inventories. `Cargo Capacity` checks must be performed by the *Trading Module* (by querying the `Asset System`) *before* calling `add_asset`.
        * `WorldGenerator`: Calls `create_inventory_for_character(uid)`.

### System 5: Asset System
* **Code Reference:** `core/systems/asset_system.gd`
* **Core Responsibility:** To provide a stateless API for accessing master asset instances (like ships) stored in `GameState.assets_ships`.
* **Phase 1 Functionality:**
    * Must provide a function to retrieve a specific ship instance: `get_ship(ship_uid)`.
    * Must provide a convenience function to get the player's active ship (by checking `GameState.characters`): `get_player_ship()`.
    * The returned `ShipTemplate` resource contains all relevant stats (e.g., `cargo_capacity`, `hull_integrity`, `ship_quirks`).
* **Interactions:**
    * **Interacts With:**
        * `Inventory System`: Provides `Cargo Capacity` via `get_player_ship().cargo_capacity`.
        * `Combat Module`: Provides stats like `hull_integrity` from the `ShipTemplate`.
        * `Piloting Module`: Provides stats like `max_move_speed` from the `ShipTemplate`.

*Note on Core Mechanics API: The foundational dice roll logic is located in the `autoload/CoreMechanicsAPI.gd` autoload, which provides the `perform_action_check()` function.*

--- Start of ./1.2-GDD-Core-Cellular-Automata.md ---

# GDTLancer - Cellular Automata Implementation

**Version:** 1.2
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 1.1-GDD-Core-Systems.md (v1.5), 6.1-GDD-Lore-Background.md (v1.5), 6.3-GDD-Narrative-Borders.md (v1.0)

## 1. Overview & Philosophy

This document outlines the implementation of Cellular Automata (CA) as a core technology for driving the "living world" and "emergent narrative" pillars of GDTLancer.

The core philosophy is that CA are not player-facing minigames, but background simulation engines. The player influences these simulations indirectly through their standard gameplay actions, and the results are presented back to them through intuitive, diegetic means such as changing maps, narrative descriptions, dialogue, and evolving gameplay opportunities. This approach ensures the player is aware of their impact on the world without breaking immersion with raw data or overly complex interfaces.

## 2. Phase 1 Implementation Approach

For the Phase 1 demo, all CA implementations will be lightweight "stubs" designed to hint at their future depth.
* They will primarily be advanced by the **`World Event Tick`**.
* They will be influenced by the outcomes of the player's **Narrative Actions**, which are resolved by the **`CoreMechanicsAPI`**.
* Their results will be exposed through existing or simple new UI elements, dialogue, and contextual gameplay changes.

## 3. Catalogue of CA Implementations

### World & Faction Simulation

#### 1. Strategic Map
* **Description:** A high-level CA where each cell represents a major location in the sector. The simulation models the ebb and flow of faction control, pirate activity, and economic stability over time.
* **Phase 1 Stub:** The simulation runs in the background, seeded by player actions (e.g., completing faction contracts, defeating pirates). It modifies a simple set of "World Stat" variables.
* **Player Access / Feedback:** A dedicated **"Sector Intel Map"** screen in the UI. This map displays locations with colored overlays representing the dominant faction's influence. After a `World Event Tick`, the player can see these colored borders subtly shift. A side panel displays the abstracted world stats as text, such as `Pirate Activity: Declining` or `Economic Outlook: Growing`.

#### 2. Supply & Demand Flow
* **Description:** A layer on the Strategic Map CA that models the propagation of resource needs and surpluses across the sector.
* **Phase 1 Stub:** Player trading actions (e.g., selling a large amount of cargo) change the state of a location's commodity (e.g., from `Normal` to `Surplus`). This state then spreads to neighboring locations over subsequent `World Event Ticks`.
* **Player Access / Feedback:** The **"Station Bulletin Board"** UI. The player does not see the raw data but instead reads narrative rumors generated by the simulation's state: *"Market chatter indicates a major surplus of Scrap Metal at Scrapyard Station."* This provides actionable intelligence that feels organic.

### Gameplay & Exploration Mechanics

#### 3. System Surveying (Anomaly Mapping)
* **Description:** A temporary, mini-CA that simulates the exploration and analysis of a volatile, uncharted cosmic anomaly, reflecting the dangers of exploring uncharted space.
* **Phase 1 Stub:** Unlocked by an "Explorer-class" ship. The `Chart Anomaly` Narrative Action triggers a fire-and-forget simulation that runs for a set amount of Time Units.
* **Player Access / Feedback:** A stylized **"Probe Data Report"** received as an in-game message. It displays a static, graphical snapshot of the anomaly's final state, accompanied by a narrative summary: *"Survey complete. The anomaly contains a high concentration of stable exotic particles. Data sold for +15 WP."*

#### 4. Salvage Analysis
* **Description:** A temporary mini-CA representing the complex process of sifting through salvaged wreckage for usable technology, reinforcing the setting's theme of iterative engineering.
* **Phase 1 Stub:** Triggered by an `Analyze Salvage` Narrative Action after combat. A background simulation runs to determine what can be successfully reverse-engineered.
* **Player Access / Feedback:** A narrative **"Workshop Analysis Report"** appears in the Hangar UI. It does not show the simulation, only the outcome: *"Analysis of the salvaged pirate vessel was successful. Our technicians have isolated a schematic for a more efficient engine manifold. **Progress made on 'Prospector Ship' Acquisition Project.**"*

### Social & Narrative Dynamics

#### 5. Influence Network
* **Description:** A non-spatial CA that models how information, rumors, and reputation propagate through the player's network of NPC Contacts.
* **Phase 1 Stub:** The state of "knowing" something (e.g., `Knows Player's Good Deed`) spreads from one Contact to their allies during `World Event Ticks`.
* **Player Access / Feedback:** Contextual dialogue. The player experiences this when a Contact references information they couldn't have known firsthand: *"I was talking to Officer Kai. He mentioned you handled that pirate situation quite well. I like that."* This makes the social world feel interconnected and alive.

#### 6. Ideological Alignment
* **Description:** A location-based CA where social cliques shift their ideological stance (e.g., Procedural vs. Pragmatic) based on world events and the player's actions.
* **Phase 1 Stub:** The player's `Risky` vs. `Cautious` action approaches push the alignment of relevant cliques.
* **Player Access / Feedback:** Environmental storytelling through the **type of contracts available**. A pragmatically-aligned station will offer more legally-gray but high-paying jobs, while a procedurally-aligned one will offer lawful but less lucrative contracts. The player feels their influence through the opportunities presented to them.

#### 7. Rivalry & Alliance Network
* **Description:** A CA modeling the evolving relationships *between* NPCs, creating a dynamic web of friends and rivals.
* **Phase 1 Stub:** Player actions, especially in "Contact Dilemma" events, can change the state of the link between two NPCs from `Neutral` to `Rivalry` or `Alliance`.
* **Player Access / Feedback:** Conflicting gameplay opportunities. When the player accepts a mission from Contact A, a competing mission from their rival, Contact B, may become unavailable, with a message explaining the conflict of interest. This makes social navigation a tangible, strategic choice.

#### 8. Trust & Deception Flow
* **Description:** A layer on the Influence Network where information is treated as an entity with a `Trustworthiness` score that can decay or be corrupted as it spreads.
* **Phase 1 Stub:** Rumors generated by the Supply & Demand CA are tagged with a trust level based on their source and how many "hops" they've made through the Influence Network.
* **Player Access / Feedback:** Simple UI tags on the **"Rumor Mill"**. Information is clearly marked as `[Verified Intel]`, `[Market Rumor]`, or `[Unconfirmed Hearsay]`. The player learns who to trust and can use a `Social Skill` check to `Verify Hearsay`, turning intel into a resource to be managed.

#### 9. Personal Goal Progression
* **Description:** A CA that tracks an individual NPC Contact's progress towards a personal ambition.
* **Phase 1 Stub:** The CA slowly ticks an NPC's `GoalProgress` variable. The player's actions can provide large boosts to this progress.
* **Player Access / Feedback:** The **"Contact Dossier" UI**. After discovering a goal, the player sees it listed with a simple progress bar. The completion of the goal is communicated via a direct, personal message from the NPC, which provides a clear narrative conclusion and a unique reward.

#### 10. Favor & Obligation Network
* **Description:** A CA that tracks a social currency of favors and debts between the player and NPCs.
* **Phase 1 Stub:** Player actions can create a positive (owed a favor) or negative (owe a favor) state on their link with a Contact.
* **Player Access / Feedback:** A contextual UI option. When making a difficult `Action Check`, a button may appear: **`[Call in Favor (Auto-Success)]`**. Conversely, a mission from a Contact the player owes may be flagged as: *"Declining this contract will significantly damage your standing with this contact."* This makes social currency a tangible, spendable resource.

--- Start of ./1-GDD-Core-Mechanics.md ---

# GDTLancer - Core Mechanics

**Version:** 1.6
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9)

## 1. Purpose

This document defines the game's core rules for resolving actions and managing key resources. These mechanics are used across all gameplay modules.

## 2. Action Check

Used for any action where the outcome is uncertain.

* **Core Mechanic:** `3d6 + Module Modifier`
* **Module Modifier:** `Relevant Skill + Asset Modifier +/- Situational Modifiers`
* **Thresholds:** The roll's total determines the quality of the outcome.
    * **Critical Success (14+):** The action succeeds exceptionally well, providing a bonus.
    * **Success (10-13):** The action succeeds as intended.
    * **Failure (<10):** The action fails, often with a complication.

## 3. Action Approach

A choice the player makes *before* rolling to influence the nature of the outcome.

* **Act Cautiously:** Prioritizes safety. A failure is less severe (e.g., lost time instead of damage), but a success offers no special bonus.
* **Act Risky:** Aims for a greater reward. A success is more effective or profitable, but a failure is more severe (e.g., critical damage instead of minor trouble).

## 4. Core Resources

These are the primary abstract resources players manage throughout the game.

### 4.1. Focus Points (FP)

* **What it is:** Represents an agent's mental energy, luck, or willpower.
* **How it works:** Spend FP *before* an Action Check to add a +1 bonus to the roll per point spent.
* **How to gain:** Earned by completing goals, roleplaying well, or through specific actions and outcomes.

### 4.2. Wealth Points (WP)

* **What it is:** An abstract resource representing significant economic power. It is not granular cash, but a measure of major purchasing power.
* **How it works:** Used to buy ships and modules, pay for major repairs, and cover the periodic Upkeep cost.
* **How to gain:** Earned from completing jobs, selling valuable assets (salvage, data), and achieving major goals.

### 4.3. Time Units (TU)

* **What it is:** An abstract measure of time. Most significant actions, like traveling, repairing, or undertaking a mission, cost TUs.
* **How it works:** Spending TU advances the **Time Clock**. When the clock fills, a **World Event Tick** occurs, advancing the world simulation.
* **Significance:** Time is a critical resource. The world changes and evolves independently of the player. Spending time on one opportunity means others may be lost.

--- Start of ./2.1-GDD-Development-Phase1-Scope.md ---

# GDTLancer - Phase 1 Scope & Goals

**Version:** 1.3
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 1.1-GDD-Core-Systems.md (v1.5), 4.3-GDD-Analogue-Phase1-Scope.md (v1.1), 5.1-GDD-Module-Piloting.md (v1.6), 5.2-GDD-Module-Combat.md (v1.4), 5.3-GDD-Module-Trading.md (v1.1)

## 1. Phase 1 Vision: "The First Contract" Demo

The singular goal of Phase 1 is to produce a playable, high-quality "vertical slice" of GDTLancer. This demo must establish the game's core identity by showcasing the unique blend of skill-based simulation and consequential, TTRPG-style narrative mechanics.

This initial build will focus on creating a complete and compelling, if small, player experience. It must prove that the core gameplay loops are engaging and that the foundation for the game's deeper, emergent narrative systems is sound. This version serves as the game's debut and must feel cohesive and purposeful.

## 2. Core Player Experience

In the Phase 1 demo, the player will:
* Start the game with a standard, pre-owned ship and a small amount of starting capital (WP).
* Engage with a small cast of named **Contacts** at stations to acquire contracts, building their **Relationship** score with them.
* Take on contracts from different **Factions**, which will affect their **Faction Standing**.
* Execute contracts by using the **Trading Module** to buy and sell a limited variety of commodities.
* Fly their ship in a `Free Flight` mode using the **Piloting Module**, spending **Time Units (TU)** and paying periodic `Upkeep` costs.
* Potentially face hostile NPCs in skill-based **Combat Challenges**, where victory or defeat has consequences.
* Resolve key moments—finalizing a trade, escaping a battle, docking at a station—by making **Narrative Actions** whose outcomes can grant rewards, affect their **Reputation**, or even add negative **Ship Quirks** to their vessel.
* Use their earned WP to invest in the **Asset Progression** system, working towards the tangible, long-term goal of acquiring a new, more capable ship that may unlock new gameplay opportunities.

## 3. Scope of Work: Included Components

### Modules
* **Piloting Module (v1.6):** The complete three-mode system for flight.
* **Combat Module (v1.4):** The core combat loop with hull-only targeting.
* **Trading Module (v1.1):** The core economic loop with static markets.

### Core Systems
* Event System
* Time System
* Character System
* Inventory System
* Asset System

*Note: The `Core Mechanics API` (`autoload/CoreMechanicsAPI.gd`) is a foundational utility for dice rolls but is not considered a "system" in the same architectural sense as the items listed above.*

### Narrative Stubs (Phase 1 Implementation)
* **Chronicle Stub ("Sector Stats"):** Tracks and displays the player's statistical impact on the game world.
* **Contact System:** Manages the player's relationships with a small cast of abstract NPCs.
* **Reputation Ledger:** A single stat tracking the player's professional standing.
* **Faction Standing:** A simple system tracking the player's standing with two distinct factions.
* **Ship Quirks:** A system for adding negative traits to a ship based on gameplay events.

## 4. Minimal Content Asset Checklist

* **Scenes:**
    * A functional **Main Menu** scene with "New Game" and "Quit" options.
    * A main **Game Scene** that hosts all managers, the player, the world, and the UI.
    * One playable **Zone Scene** containing at least two distinct station locations for trade.
* **Assets & Content:**
    * **Player Ships:** The starting ship and one additional, unlockable ship via the Asset Progression system.
    * **NPC Ship:** One hostile ship type for combat encounters.
    * **Commodities:** 3-5 unique commodity types.
    * **UI:** A functional Main HUD and menu-based interfaces for Trade, Contracts, Hangar/Asset Progression, and Contact/Faction info.
    * **Narrative:** 2-3 named Contacts and 2 named Factions for the player to interact with.

## 5. Phase 1 Development Milestones

### Milestone 1: Foundational Systems
* [**Done**] Implement the **Time System** to its required Phase 1 functionality.
* [**Done**] Implement the **Character, Asset, and Inventory Systems**.
* [ ] Implement the data structures for all narrative stubs (e.g., dictionaries for Reputation, Faction Standing; list for Ship Quirks).
* [**Done**] Ensure the **Core Mechanics API** (`autoload/CoreMechanicsAPI.gd`) is functional and accessible.

### Milestone 2: The Player in the World
* [**Done**] The player can be spawned into the Zone Scene in their starting ship.
* [**Done**] The **Piloting Module**'s `Free Flight` mode is fully functional.
* [**Done**] The Main HUD is implemented, displaying basic ship status.
* [**Done**] The **Time System** is connected to flight, consuming TU and triggering WP Upkeep.
* [ ] Implement basic UI screens to display narrative stub info (Reputation, Sector Stats, Contact Dossier, Faction Standing).

### Milestone 3: The Economic Loop
* [ ] The **Trading Module** is implemented, allowing the player to buy and sell commodities.
* [ ] The contract board is functional, allowing players to accept and complete simple delivery contracts.
* [ ] Trading narrative actions are implemented, correctly affecting the **Contact System** and **Faction Standing**.

### Milestone 4: The Combat Loop & Asset Progression
* [ ] The **Event System** can successfully trigger a combat encounter.
* [ ] The **Combat Module**'s `Combat Challenge` is functional (targeting, weapons, damage).
* [ ] Implement the trigger logic for adding **Ship Quirks** based on combat damage or failed pilot actions.
* [ ] Combat narrative actions are implemented, correctly affecting **Reputation** and **Faction Standing**.
* [ ] The **Asset Progression** "Hangar" UI is implemented, allowing players to invest WP toward acquiring the second ship.

### Milestone 5: Cohesion & "First Contract" Polish
* [ ] Create a simple, guided "first contract" that introduces the player to all core loops (Trade, Fly, Fight, Narrative Actions).
* [ ] Ensure a clean gameplay flow from the Main Menu to the end of the first contract.
* [ ] Perform a final balancing pass on WP rewards, upkeep costs, and Action Check difficulties.
* [ ] Final bug fixing to ensure a stable and playable demo experience.

--- Start of ./2-GDD-Development-Challenges.md ---

# GDTLancer - Development Challenges

**Version:** 1.4
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9)

## 1. Overview

This document lists key development challenges for GDTLancer to help with planning and risk management. Identifying these issues early allows for proactive problem-solving.

## 2. Core Design Challenges

### Challenge: Emergent Narrative Complexity
The goal of a 'living world' with emergent stories is difficult. The main challenge is making sure the stories are coherent and engaging, not random and repetitive.

* **Mitigation Strategies:**
    * **Phased Rollout:** Introduce agent complexity and simulation depth gradually over several development phases.
    * **Clear NPC Logic:** Give NPCs clear goal-selection rules (heuristics) to guide their behavior toward believable actions.
    * **Use the Chronicle:** The Chronicle system will log major events, allowing agents to react to them and create a more connected narrative.

### Challenge: Balancing Agency and Simulation
The game needs to let players feel impactful without allowing them to easily break or exploit the world simulation.

* **Mitigation Strategies:**
    * **Abstracted Resources:** Using abstract systems like Wealth Points (WP) and Time Units (TU) provides a layer of economic balancing.
    * **Soft Gates:** Guide players with narrative and economic challenges (e..g., needing a specific ship part for Asset Progression, high upkeep costs) rather than restrictive invisible walls.

## 3. Mechanical Challenges

### Challenge: Meaningful Risky/Cautious Outcomes
The `Act Risky` / `Act Cautiously` mechanic needs many unique and interesting outcomes to be effective. This is a large content creation task.

* **Mitigation Strategies:**
    * **Systemic Outcomes:** Focus on outcomes that affect game systems (e.g., damaging a component and adding a Ship Quirk, gaining a contact, alerting a faction) instead of just static text results.
    * **Templated Outcomes:** Create templates for outcomes that can be easily adapted to different situations.

## 4. Technical Challenges

### Challenge: Simulation Performance
Simulating many agents, each with individual goals and states, is CPU-intensive and must be carefully managed.

* **Mitigation Strategies:**
    * **AI Level of Detail (LOD):** Agents far from the player will use a simplified simulation loop, reducing computational load.
    * **Process in Ticks:** Process major, non-urgent simulation changes during 'World Event Ticks' rather than in real-time.

### Challenge: Transmedia Consistency
Keeping the PC, mobile, and tabletop versions consistent requires significant design discipline and maintenance effort.

* **Mitigation Strategies:**
    * **Single Source of Truth:** The GDDs will serve as the master design source for all versions of the game.
    * **Focus on the Core Experience:** Each version should capture the core gameplay loop and feel, even if specific features differ. The mobile version will naturally be the most simplified.

--- Start of ./3-GDD-Architecture-Coding.md ---

# GDTLancer - Coding Standards & Architecture Guide

**Version:** 1.8
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9)

## 1. Purpose

This document outlines the agreed-upon coding style conventions and core architectural patterns for the Godot Engine (v3.x) implementation of GDTLancer. Adhering to these principles aims to improve code readability, maintainability, modularity, and reusability across the project's different platforms and development phases.

## 2. Engine & Language

* **Engine:** Godot Engine v3.x.
* **GUT version:** 7.4.3
* **Renderer:** GLES2 backend (prioritizing performance and compatibility).
* **Language:** GDScript (using static typing hints where beneficial for clarity).

## 3. Core Philosophy

* **Keep It Simple (KISS):** Prefer simpler implementations where possible. Favor clarity over excessive abstraction if it doesn't provide significant benefit.
* **Modularity:** Structure the project and code logically around distinct responsibilities using the established framework:
    * **Gameplay Modules (Horizontal):** Self-contained activity loops (Piloting, Combat, etc.).
    * **Gameplay Layers (Vertical):** Functional implementations across modules (Simulation, Narrative, etc.).
    * **Gameplay Systems (Depth):** Cross-cutting rulesets managing specific domains (Events, Goals, Assets, etc.).
    * **Refactor for Clarity:** Proactively refactor large scripts that handle multiple responsibilities. Aim to split scripts when they significantly exceed approximately **300 lines** of code, breaking them down into smaller, focused components.
* **Simulation Foundation + Narrative Layer:** Build core gameplay around simulation within modules. Layer narrative mechanics (Action Checks, Focus, Events, Goals) on top to handle uncertainty, abstraction, and story progression.
* **Player Agency:** Empower players with choices regarding risk vs. reward, engagement level, and resource management.
* **Reusability:** Design core components to be reusable across different contexts. Leverage Godot's scene instancing and Resource system.
* **Decoupling:** Minimize hard dependencies between different systems and modules. Utilize the global `EventBus` for signaling events and state changes. Use `GlobalRefs` only for accessing essential, unique managers or nodes.
* **Adhering strictly to the project's established architecture.** This includes coding standards, modularity, data-logic separation (as seen in the project files), and using established patterns (e.g., Autoloads, Resources). Avoid creating redundant code or duplicating existing functionality.

## 4. Code Formatting Standards

* **Automatic Formatting:** Use **`gdformat`** consistently to ensure uniform code style.
* **Indentation:** Use **Tabs** for indentation.
* **Line Length:** A maximum line length of approximately **100 characters**.
* **Conditional Statements (`if`/`elif`/`else`): No Lumping.** As a manual standard, statements controlled by a conditional must always start on a new, properly indented line. The `gdformat` tool should be configured to enforce this, but the primary responsibility lies with the developer to write pristine, readable code.
* **Export Variables:** Only use `export var` for defining data in template files (e.g., `AgentTemplate`). Variables within standard node logic scripts should typically not be exported unless necessary for editor tweaking during development; prefer initialization via an `initialize()` method.
* **Naming Conventions:** Follow standard Godot GDScript conventions:
    * `snake_case` for variables and function names (e.g., `max_move_speed`, `_physics_process`). Use a leading underscore `_` for "private" methods or variables.
    * `PascalCase` for class names (if using `class_name`) and node names in the scene tree (e.g., `AgentContainer`).
    * `snake_case` for signals to maintain consistency with Godot's built-in signals and the project's `EventBus` (e.g., `agent_spawned`).
    * `ALL_CAPS_SNAKE_CASE` for constants (`const`).
* **Comments:** Use `#` for comments. Write comments to explain the *why* behind non-obvious code, not just *what* the code does.

## 5. Architectural Patterns & Practices

* **Autoload Singletons:** Utilize for truly global services and data:
    * `Constants`: Global constants (paths, names, tuning).
    * `GlobalRefs`: Holds references to unique, essential nodes/managers.
    * `EventBus`: Central signal dispatcher for decoupled communication.
    * `CoreMechanicsAPI`: Centralized functions for core rule resolution.
    * `GameStateManager`: Centralized save/load logic.
    * `GameState`: **Primary Source of Truth for all persistent data.** Holds all dynamic game state (characters, inventories, world time, etc.).
    * `TemplateDatabase`: Caches all loaded `.tres` templates on startup.
* **Component Pattern:** Use child Nodes with attached scripts to encapsulate distinct functionalities (e.g., `MovementSystem`, `NavigationSystem`).
* **Resource Templates (`.tres`):** Use custom `Resource` scripts (`extends Resource`, `class_name`) to define data structures (e.g., `AgentTemplate`). Initialize objects using these loaded Resource objects.
* **Scene Instancing:** Leverage Godot's scene instancing for creating Agents, loading Zones, and assembling UI.
* **Initialization:** Prefer initializing node properties via an `initialize(config)` method called *after* the node is added to the tree.

## 6. Physics Abstraction & Implementation

The game does not use a traditional rigid-body physics engine for ship movement. Instead, it "fakes physics" through a set of state-based rules and interpolation.

* **Core Method:** The primary method for all movement is `KinematicBody.move_and_slide()`. The velocity vector passed to this function is managed by the agent's component scripts.
* **Technical Components:**
    * **Linear Interpolation (`lerp`):** The `linear_interpolate()` function is used extensively for smooth acceleration, deceleration, and braking.
    * **PID Controllers:** A reusable `PIDController` class is employed for complex, goal-oriented behaviors that require smoothly reaching and maintaining a target state without overshoot, such as in navigation and camera control.

## 7. Unit Testing & Quality Assurance

To ensure the reliability of core systems and prevent regressions, a test-driven approach is encouraged for crucial, self-contained scripts.

* **Tooling:** The project uses the **Godot Unit Test (GUT) 7.4.3** framework for writing and running unit tests.
* **Testing Priorities (Crucial Scripts):** Unit tests are required for:
    * **Core Systems & APIs:** Any autoload singleton with internal logic (e.g., `CoreMechanicsAPI`, `GameStateManager`) and any core system (e.g., `TimeSystem`, `InventorySystem`) must have a corresponding test script.
    * **Complex Components:** Any component with significant, self-contained logic (e.g., `PIDController`, `MovementSystem`, `NavigationSystem`) must be tested.
    * **Utility Scripts:** Any general-purpose utility scripts must be tested to ensure reliability.
* **What Not to Test:**
    * **UI Scripts:** Scripts that primarily manage UI nodes and visual state are better suited for manual, integration testing.
    * **Simple "Glue" Scripts:** Scripts that primarily delegate commands or connect signals without complex internal logic do not require unit tests.
* **Best Practices:**
    * **Location:** Test scripts must be located in the `tests/` directory, mirroring the structure of the main project (e.g., the test for `core/systems/agent_system.gd` is located at `tests/core/systems/test_agent_spawner.gd`).
    * **Isolation:** Tests must be independent. Use GUT's `before_each()` and `after_each()` methods to set up and tear down the test environment for each test function, preventing side effects.
    * **Mocking:** When testing a script that depends on other complex nodes or systems, use mock objects (doubles) to isolate the unit under test.

## 8. System Implementation & Data Flow (Stateless Architecture)

This section defines the project's core data flow, which is based on **stateless systems** and a **centralized state object**.

### 8.1. General Principles

* **`GameState` is the Source of Truth:** The `GameState.gd` autoload singleton is the **single source of truth** for all dynamic, persistent game data. This includes `GameState.characters`, `GameState.inventories`, `GameState.current_tu`, etc.
* **Systems are Stateless APIs:** Core systems (e.g., `CharacterSystem`, `InventorySystem`, `TimeSystem`) are `Node` scripts located in `core/systems/` and parented under `WorldManager`. They are **stateless**. They do not hold their own data.
* **Systems Provide Logic:** A system's job is to provide a clean, logical API (a set of functions) that reads from and writes to the `GameState`.
    * **Example:** `CharacterSystem.add_wp(uid, amount)` is a function that retrieves the correct character from `GameState.characters`, modifies its `wealth_points` property, and (if it's the player) emits a signal on the `EventBus`. The `CharacterSystem` itself does not store the `wealth_points`.
* **Event-Driven Communication:** Systems should react to game events by listening to signals on the `EventBus` (e.g., `_on_world_event_tick`). They announce significant state changes by emitting signals on the `EventBus` (e.g., `player_wp_changed`).

### 8.2. System Script Checklist (Stateless)

When creating a new system (e.g., `new_system.gd`):

1.  **File Location & Node Setup:**
    * [ ] Place the script in `core/systems/`.
    * [ ] The script should `extend Node`.
    * [ ] The system should be added as a child of the `WorldManager` node in `main_game_scene.tscn`.

2.  **Initialization (`_ready()`):**
    * [ ] Register the system with `GlobalRefs` so other parts of the game can access its API (e.g., `GlobalRefs.set_new_system(self)`).
    * [ ] Connect to any necessary signals on the `EventBus` that this system needs to react to (e.g., `EventBus.connect("world_event_tick_triggered", self, "_on_world_event_tick")`).

3.  **State Management:**
    * [ ] **DO NOT** store persistent state variables in the system script. All persistent data must be read from and written to the `GameState` autoload.

4.  **Public API (Functions):**
    * [ ] **Action Methods:** Create functions that modify data within `GameState` (e.g., `add_wp(uid, amount)`). These are the only valid ways to change game state.
    * [ ] **Getter Methods:** Create functions that provide read-only access to data from `GameState` (e.g., `get_wp(uid)`).
    * [ ] **Data Protection:** If a getter returns a `Dictionary` or `Array` from `GameState`, it **must** return a copy by using `.duplicate(true)`. This prevents external scripts from getting a reference and modifying the data directly, bypassing the system's API.
        ```gdscript
        # GOOD: Returns a safe copy
        func get_player_data() -> Dictionary:
        	if GameState.characters.has(GameState.player_character_uid):
        		return GameState.characters[GameState.player_character_uid].duplicate(true)
        	return {}

        # BAD: Returns a direct reference, allowing external modification
        func get_player_data_bad() -> Dictionary:
        	return GameState.characters[GameState.player_character_uid]
        ```

### 8.3. Data Flow for Save & Load

The `GameStateManager.gd` autoload handles all save/load logic. It directly serializes and deserializes the `GameState` autoload.

**Saving Process:**

1.  `GameStateManager.save_game(slot_id)` is called.
2.  `GameStateManager` calls its internal `_serialize_game_state()` function.
3.  This function manually builds a `save_data` dictionary by pulling all necessary data *directly from `GameState`* (e.g., `save_data["current_tu"] = GameState.current_tu`).
4.  It uses helper functions like `_serialize_resource_dict()` to handle complex data like `GameState.characters`.
5.  `GameStateManager` writes the final, complete `save_data` dictionary to a file.

**Loading Process:**

1.  `GameStateManager.load_game(slot_id)` is called.
2.  `GameStateManager` reads the entire `save_data` dictionary from a file.
3.  It calls its internal `_deserialize_and_apply_game_state(save_data)`.
4.  This function clears the live `GameState` (e.g., `GameState.characters.clear()`) and repopulates it with the data from the `save_data` dictionary.
5.  After data is restored, `GameStateManager` emits `EventBus.emit_signal("game_state_loaded")`.
6.  Any UI elements or other nodes that need to refresh their display (like the `MainHUD`) listen for the `game_state_loaded` signal and then pull the new data from `GameState` using the (stateless) system APIs.

--- Start of ./4.1-GDD-Analogue-Setup.md ---

# GDTLancer Analogue Version Setup

**Version:** 1.4
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 1-GDD-Core-Mechanics.md (v1.6)

## 1. Overview & Philosophy

This document outlines the standard physical components and recommended setup for playing the Analogue (Tabletop RPG) version of GDTLancer. The goal is to deliver the core GDTLancer experience – balancing simulation abstraction with narrative mechanics, player agency, and emergent storytelling – using tabletop materials.

The Analogue version relies on narrative resolution mechanics (`Action Checks`, `Event System`) and abstract resource management (**Time Clock**, **WP**) rather than detailed simulation. Gameplay typically proceeds in turns or abstract time intervals.

## 2. Required Components

A typical solo or group session requires the following physical components per player or shared:

1.  **Dice:** At least three standard six-sided dice (3d6).
2.  **Character Sheet(s):** One per player character.
3.  **Map Sheet(s):** Represents the known space environment.
4.  **Asset/Module Sheet(s):** Representing key owned Assets (ships, major equipment).
5.  **Universal Mechanics Reference:** A concise rules summary sheet.
6.  **Module Event Booklet(s)/Reference(s):** Detailed outcome tables for specific Gameplay Modules.
7.  **Tokens/Trackers:** For managing variable values like Focus Points, Wealth Points, the Time Clock, Hull/Shield integrity, etc.

## 3. Component Details & Organization

* **3.1. Map Sheet(s):**
    * **Purpose:** Provides spatial context for navigation, exploration, and world state.
    * **Content:** Systems, points of interest, routes (with segment costs in **Time Units (TU)**, descriptors), hazards. Space for player annotations.
    * **Format:** Pre-generated maps, pointcrawls, or hex grids.

* **3.2. Character Sheet:**
    * **Purpose:** Tracks core Agent identity, capabilities, narrative state, and key meta-resources.
    * **Content:** Name, Description, Base Skills (for calculating Module Modifiers), Current/Max **Focus Points (FP)**, Current **Wealth Points (WP)**, **Time Clock** (e.g., 8 segments for tracking TU), XP/Progression track, Active Goals list, inventory/cargo summary, status effects.

* **3.3. Asset/Module Sheet(s):**
    * **Purpose:** Represents owned Assets and provides context for enabled Gameplay Modules.
    * **Format:** Double-sided sheet/card per major Asset or small booklet.
    * **Content:**
        * **Asset Side:** Asset Name, Description/Image, Key Stats (e.g., Hull Max, Shield Max, Cargo Capacity), `Asset Difficulty` scores, Enabled Modules list, Asset condition track.
        * **Module Side(s):** For each enabled Module: Module Name, Relevant Skill reference, Calculated **Module Modifier** space (`Skill + Asset Difficulty = ___`), **Integrated Outcome Table** (Summary + Event Ref Code for Risky/Cautious), Asset Variations, Module-Specific Resource Tracks (if any).

* **3.4. Universal Mechanics Reference:**
    * **Purpose:** Quick rules lookup.
    * **Content:** Action Check summary (3d6+Mod vs 10/14), Focus Point rules, Action Approach definitions (`Risky`/`Cautious`), basic Time Clock/World Event Tick overview, basic WP usage overview.

* **3.5. Module Event Booklet(s)/Reference(s):**
    * **Purpose:** Provides detailed outcomes for Event Reference Codes from Asset/Module sheets.
    * **Structure:** Organized by Module, indexed by Event Ref Code (e.g., `C-SWC-PILOT`).
    * **Content:** Descriptions, mechanical effects (stat changes, WP costs/rewards, **TU additions for delays**, new checks required, module switches, status effects), d6 sub-tables.

* **3.6. Tokens/Trackers:**
    * **Purpose:** Physical representation for fluctuating values.
    * **Examples:** Tokens/dice for Focus Points, Wealth Points, Hull/Shield points; a marker for the **Time Clock**; markers for Progress Tracks and map position.

## 4. Gameplay Flow Summary

1.  **Consult Map & Character Sheet:** Determine location, goals, resources (FP, WP), Time Clock status.
2.  **Choose Action & Engage Module:** Decide action (e.g., Travel). Select relevant **Asset/Module Sheet**. Note **Module Modifier**.
3.  **Declare Action & Approach:** State action (e.g., `Undertake Journey` segment) & declare `Act Risky` or `Act Cautiously`.
4.  **Make Action Check:** Roll 3d6 + Mod + FP bonus. Compare to Thresholds.
5.  **Find Outcome:** Use **Integrated Outcome Table** on **Asset/Module Sheet**. Note summary & **Event Reference Code**.
6.  **Resolve Outcome:** Look up Code in **Module Event Booklet**. Apply effects: update Character Sheet (**FP**, **WP**, Goals, status), **advance Time Clock (+TU)**, potentially trigger new checks or module transitions.
7.  **Check Time Clock:** If Time Clock fills, resolve **World Event Tick** (See Section 5).
8.  **Update State:** Mark map position, etc. Repeat from Step 1/2.

## 5. World Evolution ("World Event Tick")

* Simulates dynamic world changes in the Analogue Version. Triggered when the **Time Clock** on the Character Sheet fills.
* **Resolution:** Typically involves consulting Event System tables/procedures for background events AND requiring the player to pay an **Upkeep Cost in WP** representing abstract operational expenses (fuel, supplies, maintenance) accrued over that time period. Failure to pay Upkeep has consequences. The Time Clock then resets.

--- Start of ./4.2-GDD-Analogue-Setup-Formatting.md ---

# GDTLancer Analogue Version - Setup & Formatting Guide

**Version:** 1.3
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 1-GDD-Core-Mechanics.md (v1.6), 4.1-GDD-Analogue-Setup.md (v1.4)

## 1. Purpose

This document details the recommended physical layout, content organization, and formatting principles for the printed materials used in the Analogue (Tabletop RPG) version of GDTLancer. The aim is to ensure clarity, ease of use, and efficient information access during play, supporting the game's modular design.

## 2. General Formatting Principles

* **Paper Size:** Primarily target A4/Letter for main sheets (Character, Map) and A5/Half-Letter for reference cards/booklets where practical.
* **Layout:** Utilize clean, readable fonts (e.g., sans-serif 10-12pt for body text, larger for headings). Employ clear headings, logical information grouping (using boxes or sections), and sufficient white space.
* **Tracking Methods:** Standardized methods for tracking dynamic values:
    * **Linear Progress Tracks:** (e.g., Goal Progress, Time Clock) Use tracks printed along a reinforced edge of the relevant sheet, marked with **paperclip sliders**. Typically 8-10 segments.
    * **Point Pools:** (e.g., Focus Points, Wealth Points, Hull/Shields) Use marked boxes `[ ]` or dedicated areas for writing the current value with pencil or erasable marker. Small pools like Focus Points (FP) can use check-boxes `[ ] [ ] [ ]`.
    * **Notes & Dynamic Stats:** Use pencil or erasable markers for temporary notes, status effects, or calculated values like the Module Modifier.
* **Modularity:** Design sheets to function together. Information should be located where it's most relevant contextually. Minimize redundant information.

## 3. Component Layouts

* **3.1 Character Sheet Layout:** (Primary Sheet, e.g., A4/Letter)
    * **Section 1: Agent Identification:** Character Name, Pronouns, Concept/Background Summary, Player Name.
    * **Section 2: Core Skills/Stats:** List base Skill values (e.g., Piloting: `[+X]`, Tech: `[+Y]`, Social: `[+Z]`).
    * **Section 3: Meta-Resources & Condition:**
        * Focus Points (FP): Track (e.g., `FP: [ ] [ ] [ ]` Max 3).
        * Wealth Points (WP): Box for current value `WP: [ ___ ]`.
    * **Section 4: Time & World State:**
        * **Time Clock Track:** Linear track (e.g., 8 segments: `[ ][ ][ ][ ][ ][ ][ ][ ] TU`) along one reinforced edge for a paperclip slider.
    * **Section 5: Active Goals/Vows:**
        * Area to list 2-3 active Goals. For each: Goal Name/Objective, **Progress Track** (linear track, e.g., 10 segments `[ ][ ]...[ ]`) along a reinforced edge for a paperclip slider.
    * **Section 6: Status & Notes:** Area for temporary status effects, campaign notes, quick inventory reference, contacts.

* **3.2 Map Sheet(s) Layout:** (A4/Letter or larger, potentially foldable)
    * **Main Area:** Visual map (pointcrawl, hex, sector chart) showing locations, routes (with TU costs), known hazards, faction territories. Clear Key/Legend.
    * **Annotation Space:** Margins or dedicated areas for player notes, marking current location, drawing discovered routes.

* **3.3 Asset/Module Sheet Layout:** (A5/Half-Letter card/sheet, likely double-sided, one per major Asset)
    * **Side 1: Asset Details:**
        * Header: Asset Name & Type (e.g., Ship: Wayfarer Freighter).
        * Visual: Image/Icon (Optional).
        * Description: Brief flavor text.
        * Core Stats: Hull `[ ]/[Max]`, Shields `[ ]/[Max]`, Cargo Capacity `[X]`, etc. Relevant **`Asset Difficulty`** scores (e.g., Piloting: -3, Combat: -4).
        * Enabled Modules: List of Gameplay Modules this Asset grants access to.
        * Condition/Notes: Track damage, quirks, modifications specific to this Asset.
    * **Side 2: Enabled Module Details**:
        * Header: Module Name (e.g., Piloting & Travel).
        * **Modifier Calc:** `Uses Skill: [e.g., Piloting]` | `Asset Difficulty: [-3]` | `Current Skill: [+_]` | **`Module Modifier = [___]`** (Space for player to calculate & write).
        * **Action Outcome Summary:** The compact table referencing Risky/Cautious outcomes:
            ```
            | Result      | Cautious Outcome / Ref Code | Risky Outcome / Ref Code |
            |-------------|-----------------------------|--------------------------|
            | Crit (14+)  | Stable Success+ / C-CRIT-PILOT| Major Success++ / R-CRIT-PILOT|
            | Succ (10-13)| Success + Minor Cost / C-SWC-PILOT | Success + Notable Cost / R-SWC-PILOT|
            | Fail (<10)  | Fail + Minor Setback / C-FAIL-PILOT | Fail + Major Conseq. / R-FAIL-PILOT |
            ```
        * **Module Mechanics:** Brief summary of key module actions (e.g., `Undertake Journey`, `Fast Transit` TU costs).

* **3.4 Universal Mechanics Reference Layout:** (A5/Half-Letter card or separate A4 sheet)
    * **Action Check:** Flowchart or steps (Roll 3d6 + Mod + FP -> Compare vs 10/14).
    * **Focus Points:** Gain/Loss rules, Spending options.
    * **Action Approaches:** Definitions of `Act Risky` / `Act Cautiously`.
    * **Time Clock & World Event Tick:** Summary of how TU are tracked and what happens when the clock fills (Tick -> Event + WP Upkeep -> Reset).

* **3.5 Module Event Booklet(s)/Reference(s) Layout:** (Booklet, multi-page A5/Half-Letter, or cards)
    * **Organization:** Clearly titled by Module (e.g., "Piloting & Travel Events"). Entries organized and indexed by **Event Reference Code**.
    * **Content per Entry:** Reference Code, Brief Narrative Flavor, Specific Mechanical Effects (WP cost/gain, TU add, damage, status effects, etc.).

## 4. Information Flow Example

Player decides to `Undertake Journey`. They grab their **Ship Asset Sheet**, look at the Piloting section, calculate the `Module Modifier` using their **Character Sheet**'s Piloting Skill and the ship's `Asset Difficulty`. They declare `Act Cautiously`. They roll 3d6, potentially spend FP, and add the Module Modifier. They check the result and find the outcome summary and Ref Code on the **Asset/Module Sheet**'s table. They look up the Ref Code in the **Piloting Event Booklet**, apply the detailed effects, and mark TU on the **Character Sheet**'s Time Clock.

--- Start of ./4.3-GDD-Analogue-Phase1-Scope.md ---

# GDTLancer - Analogue Version: Phase 1 Scope & Goals

**Version:** 1.3
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 1-GDD-Core-Mechanics.md (v1.6), 1.1-GDD-Core-Systems.md (v1.5), 4.1-GDD-Analogue-Setup.md (v1.4), 4.2-GDD-Analogue-Setup-Formatting.md (v1.3)

## 1. Phase 1 Vision: "The First Contract" Quickstart PDF

The primary goal for the analogue version in Phase 1 is to produce a complete, playable, and publishable **"Quickstart"** or **"Starter Set"** in PDF format. This product will serve as a self-contained introduction to the GDTLancer tabletop experience for solo or group play.

This document will teach the core rules and allow players to experience the fundamental gameplay loop of taking contracts, traveling through space, resolving encounters, and managing resources. It will establish the core feeling of the game on paper and serve as the foundation for all future analogue expansions.

## 2. Core Player Experience (Analogue)

In a typical session of the Phase 1 Quickstart, the player(s) will:
* Start with a pre-generated **Character Sheet** and the starting **Ship Asset Sheet**.
* Consult the **Scenario Booklet** to choose a contract and identify their starting location on the Sector Map.
* Spend **Time Units (TU)** to travel between locations, marking their progress on the **Time Clock** track.
* Potentially roll on an **Encounter Table** during travel, which may lead to a combat scene or another narrative dilemma.
* Resolve all uncertain situations using the core **Action Check** mechanic.
* Interact with named **Contacts** described in the booklet, making choices that affect their **Relationship** score.
* Complete contracts for different **Factions**, altering their **Faction Standing**.
* See their **Reputation** change based on the outcomes and approaches of their Narrative Actions.
* Risk having negative **Ship Quirks** added to their ship sheet on a failed check.
* Track the changing state of the sector via the **Sector Stats** tracker.
* Manage their **Wealth Points (WP)**, balancing contract rewards against the periodic `Upkeep Cost` triggered by the Time Clock.

## 3. Scope of Work: Required PDF Components

The final PDF product must contain the following printable materials:

* **Quickstart Rulebook:** A short booklet explaining the core rules: Action Checks, Action Approaches, FP, WP, TU, the Time Clock, and the phased gameplay loop.
* **Printable Character Sheet:** A sheet with fields for skills, FP, WP, and tracks for the Time Clock, Reputation, and Faction Standing.
* **Printable Ship Asset Sheet:** A sheet for the starting ship, detailing its stats and providing a dedicated space to write in `Ship Quirks`.
* **Introductory Scenario Booklet:** The main content piece, containing:
    * A starter **Sector Map** with 2-3 locations.
    * A list of 3-5 introductory contracts.
    * A travel encounter table.
    * A list of 2-3 **Contacts** with space to track relationship scores.
    * A tracker for the **Sector Stats** (Chronicle Stub).
    * All necessary **Outcome Tables** for the Phase 1 Narrative Actions.
    * Stat blocks for 1-2 types of hostile NPC ships.
* **Universal Reference Sheet:** A one-page summary of rules and Action Check outcomes.

## 4. Minimal Content Requirements

* **Rules:** The final, concise text for all core mechanics.
* **Sheets:** One pre-generated character and one starting ship must be fully statted out.
* **Narrative Content:** All contracts, encounter table entries, location descriptions, Contact bios, and—most importantly—the detailed outcome text for all Narrative Actions must be written.

## 5. Analogue Development Milestones

### Milestone 1: Rules & Layout Finalization
* [ ] Write the final, edited rules text for the Quickstart Rulebook.
* [ ] Design the definitive visual layout and formatting for all printable sheets, ensuring they are clear and intuitive for tabletop play.

### Milestone 2: Core Content Creation
* [ ] Create the pre-generated starting player character and their backstory.
* [ ] Finalize the stats for the starting player ship and the hostile NPC ship(s).
* [ ] Design and draw the starter Sector Map.

### Milestone 3: Scenario & Outcome Writing
* [ ] Write the descriptions for the starter locations, Contacts, and available contracts.
* [ ] Write all entries for the Travel Encounter Table.
* [ ] **(Primary Task)** Write the detailed, narrative outcome descriptions for every possible result (Crit Success, Success, Failure) for both `Risky` and `Cautious` approaches for all Phase 1 Narrative Actions.

### Milestone 4: PDF Assembly & Finalization
* [ ] Assemble all designed sheets and written content into a single, cohesive PDF document.
* [ ] Write a "How to Play" introduction and a "Welcome to GDTLancer" preface for the booklet.
* [ ] Perform a final proofreading and editing pass on the entire document.
* [ ] Export the final, publishable Quickstart PDF.

--- Start of ./5.1-GDD-Module-Piloting.md ---

# 5.1 GDTLancer - Piloting Module

**Version:** 1.9
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `2.1-GDD-Development-Phase1-Scope.md` (v1.3), `3-GDD-Architecture-Coding.md` (v1.8), `5.2-GDD-Module-Combat.md` (v1.4), `7.2-GDD-Assets-Ship-Engines.md` (v1.3), `7.3-GDTLancer-Ship-Chassis.md` (v1.1)

---

## 1. Overview

This document defines the core mechanics of the Piloting Module. Its purpose is to govern all ship movement and its interaction with the core game loop. The module is divided into three distinct functional modes, designed to create a clear separation between low-stress travel, skill-based challenges, and narrative resolution.

---

## 2. Development Phase 1 Focus

This design is scoped specifically for **Phase 1 (Core Loop)**. The primary goal is to establish the fundamental flight model and the gameplay loop of transitioning between the three modes. Advanced features are planned for subsequent phases.

---

## 3. Mode 1: Free Flight

This is the default mode for intra-system travel, acting as the connective tissue between points of interest.

* **Purpose:** To allow players to move around a sector map in a low-stress, self-directed manner.
* **Mechanics:**
    * **Control Scheme:** Player has direct control over their ship using the core "boost and drift" flight model implemented via the `MovementSystem` and `NavigationSystem`.
    * **Resource Costs:**
        * This mode continuously advances the **Time Clock** at a standard rate, consuming **Time Units (TU)**.
        * It does not have a direct **Wealth Point (WP)** cost, but the time spent contributes to the periodic **Upkeep Cost** in `WP`.
    * **Event Triggering:** While in Free Flight, the **Event System** can trigger encounters (e.g., distress call, pirate ambush). A triggered event will seamlessly transition the player into a **Flight Challenge**.

---

## 4. Mode 2: Flight Challenge

This mode represents self-contained, objective-based scenarios that test the player's skill.

* **Purpose:** To provide a pure, skill-based test of the player's piloting (and potentially combat) abilities without interruption from abstract mechanics.
* **Mechanics:**
    * **Trigger:** Initiated by an event from Free Flight or by accepting a mission that requires a specific objective to be met.
    * **Objective-Based:** Each challenge has a clear, binary success condition. Examples for Phase 1 include:
        * `Neutralize all hostile targets.` (Handled by `Combat Module` rules)
        * `Survive for a specific duration.`
        * `Reach a specific coordinate.`
    * **Pure Skill:** Success or failure is determined entirely by the player's real-time performance. There are **no** `Action Checks` during a Flight Challenge.
    * **Ship Performance:** A ship's stats directly affect its handling, speed, and durability within the challenge. (See Section 6 for stat details).

---

## 5. Mode 3: Narrative Action

This mode is the TTRPG-style resolution step that occurs *after* a Flight Challenge is successfully completed.

* **Purpose:** To resolve the consequences, quality of success, and narrative fallout of the preceding skill-based challenge.
* **Mechanics:**
    * **Trigger:** Player-initiated command selected from a menu after the "CHALLENGE COMPLETE" condition is met.
    * **Core Mechanic:** Utilizes the standard `3d6 + Module Modifier` **Action Check** to determine the outcome.
    * **Consequences:** The result of the roll determines the strategic consequences. These outcomes can directly interact with narrative stub systems, such as adding a negative **"Ship Quirk"** to the player's vessel on a failure, or affecting their **"Reputation"** based on their chosen `Action Approach` (`Risky`/`Cautious`).
    * **Essential Phase 1 Actions:**
        * **Perform Evasive Departure:** Used after winning a combat encounter to determine if the getaway was clean. Failure could result in being tracked or damaging a component, potentially adding a "Ship Quirk".
        * **Execute Precision Arrival:** Used after reaching a destination coordinate to determine the quality of the docking/approach. Failure could result in minor ship damage and add a Quirk like "Jammed Landing Gear".

---

## 6. Required Phase 1 Systems & Stats

* **Required Agent Stats (from Character System):**
    * `Piloting Skill`: The base value used to calculate the `Module Modifier` for Narrative Actions.
* **Required Ship Stats (from Asset System):**
    * `Mass`: Affects inertia and drift. (Calculated from Hull Base Mass + component masses).
    * `Agility`: Affects turn rate and responsiveness. (Implemented via `max_turn_speed` in `AgentTemplate`).
    * `Thruster Power`: Affects acceleration and top speed. (Implemented via `acceleration` and `max_move_speed` in `AgentTemplate`).
* **Core System Integration:**
    * **Time System:** Must be advanced by Free Flight mode.
    * **Event System:** Required to trigger the transition from Free Flight to a Flight Challenge.
    * **Core Mechanics API:** The core function used to resolve all Narrative Actions.
    * **Asset System:** Provides the ship stats that influence flight performance.
    * **Character System:** Provides the skill stats for Narrative Action checks.

--- Start of ./5.2-GDD-Module-Combat.md ---

# 5.2 GDTLancer - Combat Module

**Version:** 1.7
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `5.1-GDD-Module-Piloting.md` (v1.9), `6.1-GDD-Lore-Background.md`, `6-GDD-Lore-Narrative-Borders.md`, `7.1-GDD-Assets-Ship-Design.md` (v2.2), `7.3-GDD-Assets-Ship-Chassis.md` (v1.1), `7.9-GDD-Assets-Utility-Tools.md` (v1.1)

---

## 1. Overview

This document defines the mechanics for ship-to-ship conflict, adhering to the **Preservation Convention**. Combat, as a module, prioritizes **disabling and capturing vessels** over outright destruction, reflecting the cultural and economic value placed on preserving assets. The module structures encounters into a distinct skill-based **Combat Challenge** followed by a narrative resolution via **Narrative Actions**.

**Key Design Constraint:** There are **no energy shields**. Combat focuses on overcoming hull integrity and disabling systems using specialized **Utility Tools**.

---

## 2. Development Phase 1 Focus

This design is scoped for **Phase 1 (Core Loop)**. The focus is on establishing the fundamental mechanics: targeting the main hull, applying damage using Phase 1 tools, and clear victory/disable conditions. Advanced features like specific sub-system targeting are planned for later phases.

---

## 3. Mode 1: Combat Challenge

This mode represents the direct, real-time engagement between vessels. It is a self-contained test of the player's combat and piloting skill.

* **Purpose:** To provide pure, skill-based ship-to-ship fighting focused on disabling tactics.
* **Mechanics:**
    * **Trigger:** Initiated by an event from Free Flight (e.g., ambush) or by accepting a mission that requires combat.
    * **Core Gameplay:** Players have direct control over their ship's movement and equipped **Utility Tools**. The core gameplay loop involves maneuvering, aiming, and using tools (like Ablative Lasers or Rotary Drills) to disable the enemy. This includes high-thrust industrial actions, such as using grapples to hold a target or drills to breach a hull, enabled by the **G-Stasis Cradle**.
    * **Targeting:** For Phase 1, targeting is limited to the enemy ship's main hull.
    * **Objective:** The challenge is successfully completed when all designated hostile targets are **neutralized** (Hull Integrity reaches 0 or another disable condition is met).
    * **Consequences of Damage:** Taking significant hull damage during the challenge, even if victorious, can result in a new "Ship Quirk" being added to the player's vessel.
    * **Pure Skill:** Success in this mode is determined solely by player performance. There are **no** `Action Checks` during the Combat Challenge.

---

## 4. Mode 2: Narrative Action

This is the resolution step that occurs after the Combat Challenge is successfully completed (i.e., the enemy is neutralized). It determines the consequences and potential rewards of the engagement.

* **Purpose:** To resolve the strategic and narrative fallout of a battle, emphasizing the **Preservation Convention's** goals.
* **Mechanics:**
    * **Trigger:** Player-initiated command selected from a menu after the last enemy ship is neutralized.
    * **Core Mechanic:** Utilizes the standard `3d6 + Module Modifier` **Action Check** to determine the outcome.
    * **Consequences:** Outcomes directly modify narrative stubs like "Reputation," "Faction Standing," and sector "World Stats". Successful disablement/capture should yield better rewards than simple destruction.
    * **Essential Phase 1 Actions:**
        * **Assess the Aftermath:** A general-purpose action to evaluate the battlefield context. Success might reveal faction affiliations or recoverable intel. Failure might mean misidentifying the wreck or attracting unwanted attention.
        * **Claim Wreckage:** A specific attempt to salvage components from a **disabled** ship. Success yields a valuable asset or adds to `WP`. A `Risky` approach might yield more `WP` but damage `Repation` ("Opportunist"). Failure could mean the wreckage is too unstable.

---

## 5. Required Phase 1 Systems & Stats

* **Required Agent Stats (from Character System):**
    * `Tactics Skill`: The base value used to calculate the `Module Modifier` for combat-related Narrative Actions.
* **Required Ship Stats (from Asset System):**
    * `Hull Integrity`: The ship's health points.
    * Equipped **`Utility Tools`**: These define the ship's offensive capabilities (damage output, range, special effects like grappling).
* **Core System Integration:**
    * **Event System:** To initiate combat encounters.
    * **Time System:** Combat Challenges and subsequent actions consume **Time Units (TU)**.
    * **Core Mechanics API:** To resolve Narrative Actions.
    * **Asset System:** Provides the ship's `Hull Integrity` and tracks equipped `Utility Tools`.
    * **Character System:** Provides the `Tactics Skill` for Narrative Action checks.

--- Start of ./5.3-GDD-Module-Trading.md ---

# 5.B GDTLancer - Trading Module

**Version:** 1.3
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 1.1-GDD-Core-Systems.md (v1.5)

## 1. Overview

This document defines the mechanics for all economic activities, including the buying and selling of commodities and the management of contracts. The primary function of this module is to provide the core loop for accumulating **Wealth Points (WP)**.

## 2. Development Phase 1 Focus

This design is scoped for **Phase 1 (Core Loop)**. The goal is to establish a minimal, functional economic loop. This includes basic commodities, static markets, and a simple interface for transactions. Dynamic economies, complex trade routes, and crafting are planned for later phases.

## 3. Core Mechanic: The Trade Interface

The primary interaction in the Trading Module is UI-based. This interface is the hub for all market and contract activity.

* **Purpose:** To allow players to manage their cargo, accept contracts, and execute transactions.
* **Mechanics:**
    * **Trigger:** Player docks at a location with a market and selects the "Market" or "Contracts" option.
    * **Market Gameplay:** A menu-driven interface displays the player's cargo, the station's inventory, and the current buy/sell prices for commodities. The player can execute buy and sell orders.
    * **Contract Gameplay:** A separate tab on the interface lists available contracts. For Phase 1, these are simple delivery contracts. Contracts will be flagged with a Faction owner.
    * **Economic Loop:** The goal is to buy commodities at a low price and sell them for a higher price, or to complete contracts, generating a net profit in `WP`.

## 4. Narrative Actions in Trading

These actions introduce skill, chance, and social interaction into trading, making it more than just a spreadsheet. They are the primary method for improving relationships with contacts and factions.

* **Purpose:** To provide opportunities for players to create their own advantages in the market through risk and social skill.
* **Mechanics:**
    * **Trigger:** Player-initiated special commands available within the Trade Interface.
    * **Core Mechanic:** Utilizes the standard `3d6 + Module Modifier` **Action Check** to resolve the outcome.
    * **Consequences:** Outcomes directly affect the player's relationships and standing. A successful negotiation might improve your relationship with a `Contact`, while failing a contract can damage your `Faction Standing` and `Reputation`.
    * **Essential Phase 1 Actions:**
        * **Negotiate Bulk Deal:** When buying or selling a large quantity of goods, perform this check to get a better price. This is framed as an interaction with a specific `Contact`. A success provides a `WP` bonus and may increase your `Relationship` with them. A failure can result in a worse price and a damaged relationship.
        * **Seek Rare Goods:** Perform this check to find unlisted opportunities. A success might reveal a rare commodity, offered as a "tip-off" from a friendly `Contact`. A failure consumes **Time Units (TU)** with no result.

## 5. Required Phase 1 Systems & Stats

* **Required Agent Stats (from Character System):**
    * `Trading Skill`: The base value used to calculate the `Module Modifier` for trading-related Narrative Actions.
* **Required Ship Stats (from Asset System):**
    * `Cargo Capacity`: Determines the maximum number of commodity units the ship can hold.
* **Required Commodity Stats:**
    * `Item ID`: A unique identifier.
    * `Name`: The display name of the commodity.
    * `Base Value`: The baseline price used for market calculations.
* **Core System Integration:**
    * **Character System:** Manages the player's `WP` total and `Trading Skill`. It is also the hub for `Reputation` and `Faction Standing` stubs.
    * **Inventory System:** Stores and manages player-owned commodities.
    * **Asset System:** Provides the ship's `Cargo Capacity`.
    * **Time System:** Actions like `Seek Rare Goods` consume `TU`.
    * **Core Mechanics API:** Resolves all Narrative Actions.
    * **Contact System:** The trading interface will be a primary point of interaction with Contacts.

--- Start of ./6.1-GDD-Lore-Background.md ---

# GDTLancer - Lore & Background

**Version:** 1.7
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 1-GDD-Core-Mechanics.md (v1.6)

## 1. Overview

This document outlines the foundational setting and background for the GDTLancer universe. This information informs game mechanics, dialogue, design, and technology.

## 2. The Premise: A Sector of Colonists

The game takes place in a hand-crafted sector of space populated by a human-centric society of early colonists and explorers. The specific history of *how* or *why* humanity arrived in this sector is left undefined. The narrative focus is on the current state of the sector and the player's actions within it.

## 3. Core Theme: Scarcity and Pragmatism

The primary driver of the setting is a considerable, but not punishing, scarcity of complex materials and skilled labor. This dynamic has forged a pragmatic, resilient, and resourceful culture.
* **Core Values:** The culture values efficiency, function-over-form ("Pragmatic Aesthetics"), and resourcefulness. "Waste not, want not" is a common adage.
* **Value of Assets:** Because of this scarcity, complex assets (like ships) and skilled personnel (like pilots) are highly valued and treated as quasi-irreplaceable.

## 4. The "Preservation Convention"

This cultural and economic reality has led to a widespread social norm known as the **Preservation Convention**.
* **Core Tenet:** This convention prioritizes the disablement, disarming, and capture of vessels over their outright destruction. Destroying a valuable ship and skilled pilot is seen as wasteful and unprofitable.
* **Conflict:** This creates a natural source of conflict, as fringe groups or sociopaths who *break* this convention are treated as a significant threat by the general society.
* **Industrial Tactics:** This convention favors the high-thrust application of industrial tools (grapples, reinforced prows, drills) in close-quarters engagements to disable, rather than annihilate, an opponent.

## 5. Technology & Aesthetics

* **Technological Baseline:** Technology is grounded and functional, iterating on known, reliable systems. The aesthetic is function-first, emphasizing reliability and modularity.
* **G-Stasis Cradle:** A key piece of in-lore technology standard in all high-performance ships. It is a bio-support system that allows a pilot to survive the extreme G-forces (e.g., up to 15G) generated by aggressive maneuvering or the use of high-thrust industrial tools in combat.
* **Travel:** Common Faster-Than-Light travel does not exist. Travel *within* a sector is done via in-system engines. Travel *between* sectors is a significant strategic undertaking, abstracted as a high cost in **Wealth Points (WP)** and **Time Units (TU)**.

## 6. Naming Conventions (Outline)

* **Cultural Synthesis:** Names reflect a blend of diverse Earth cultures.
* **Language:** A practical and direct creole lingua franca with heavy technical jargon.

## 7. Ambient Lore Implementation Goal

The player experiences this setting through its consequences on game mechanics (like the combat module), dialogue, and design, minimizing direct exposition in favor of "showing, not telling."

--- Start of ./6.2-GDD-Lore-Player-Onboarding.md ---

# GDTLancer - Player Onboarding

**Version:** 1.3
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 1-GDD-Core-Mechanics.md (v1.6), 6.1-GDD-Lore-Background.md (v1.7)

## 1. Purpose and Goals

This document outlines the player's first 30-60 minutes of gameplay. The goal is to introduce core systems smoothly without being overwhelming.

* **Teach Core Mechanics:** Introduce Action Checks, the `Risky`/`Cautious` system, and core resources (FP, WP, TU).
* **Show the Gameplay Loop:** Demonstrate how to accept a goal, travel, perform actions, and receive a reward.
* **Introduce the Setting:** Convey the pragmatic culture, resource scarcity, and the "Preservation Convention" mindset through action.
* **Provide a Clear Next Step:** End the tutorial with a clear, player-driven objective.

## 2. Onboarding Philosophy

* **Guided, Not Forced:** Give the player a clear starting goal within a small, controlled area, but allow for experimentation.
* **Learn by Doing:** Introduce mechanics as they are needed. Explain the Action Check when the player first needs to make one.
* **Contextual Introduction:** Frame the tutorial within a simple story that organically reveals aspects of the game's setting and culture.

## 3. Onboarding Scenario: "The First Contract"

This scenario introduces the player to the game's core loop and establishes their place in the world.

* **Setup:** The player is a new pilot with a basic, second-hand ship, docked at a small habitat. Their mentor, a senior, experienced engineer, guides them through their first official contract. This immediately grounds the player in the pragmatic, hands-on culture of the sector.

* **Step 1: The Mentor & The Goal**
    * The Mentor NPC gives the player a simple contract: a rival salvage crew has disabled a small cargo drone but failed to secure it. The drone is now adrift at a known coordinate. The player's contract is to fly to the drone and retrieve its secure data core.
    * **Introduces:** The Goal System, basic dialogue interaction, and the setting's focus on salvage.

* **Step 2: Travel & Time**
    * The mentor instructs the player to fly to the drone's coordinates. The flight is short and direct.
    * **Introduces:** Basic Piloting controls, the concept of spending Time Units (TU), and the Time Clock.

* **Step 3: The First Action Check**
    * Upon arriving, the player finds the drone, but its data port is damaged. The player must use their ship's tools to carefully access the core. This is their first **Action Check**.
    * **Introduces:** The Action Check mechanic, the `Risky`/`Cautious` choice, and how tools are used to solve problems.

* **Step 4: Controlled Conflict**
    * Just as the player secures the core, the rival salvage ship (a lone scavenger) that originally disabled the drone returns and demands the core. This is a controlled combat tutorial.
    * The mentor advises the player to disable the scavenger's ship (reduce its hull to zero) without completely destroying it, calling annihilation "wasteful" and "a good way to get a bad reputation."
    * **Introduces:** The Combat Module, targeting the enemy hull, and the core principle of the Preservation Convention (avoiding destruction to preserve assets).

* **Step 5: The Narrative Resolution (The Payoff)**
    * After the rival ship is neutralized (Hull Integrity at 0), the **Narrative Action** menu appears. The mentor explains this is where the "real work" is done.
    * The player is presented with options like **"Assess the Aftermath"** and **"Claim Wreckage"**.
    * The mentor guides them to **"Assess the Aftermath"**. The player makes an Action Check (using their `Tactics Skill`).
    * **Outcome (example):** On a Success, the mentor says, "Good. You scanned their ship data. They're small-time, no faction. As per convention, activate their distress beacon. We have what we came for."
    * **Introduces:** The core TTRPG loop: **Skill-based play followed by TTRPG-style narrative resolution.** It shows *how* you handle a disabled vessel (assess it and leave it for recovery, as per the Convention).

* **Step 6: The Reward & Next Steps**
    * The player returns the data core to the mentor. They receive their first **Wealth Point (WP)** as payment.
    * The mentor congratulates them and points them to the station's job board, explaining how to find new contracts.
    * **Introduces:** The Wealth (WP) resource and the systems for finding new, player-driven goals. The tutorial is now complete.

--- Start of ./6-GDD-Lore-Narrative-Borders.md ---

# GDTLancer - Narrative Borders of the Simulation

**Version:** 1.2
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 6.1-GDD-Lore-Background.md (v1.7)

## 1. Purpose & Philosophy

This document defines the high-level narrative and thematic constraints—the "borders"—within which the game's simulation must operate. The goal is to guide the emergent narrative so that it consistently reinforces the core themes of the GDTLancer universe.

Our design philosophy is that **the simulation serves the narrative, not the other way around.** We are not creating a scientifically accurate, open-ended universe simulation. We are creating a powerful, thematically-focused story generator. These borders ensure that the stories it generates are always grounded in the game's established lore and core pillars.

## 2. The Core Narrative Borders

These principles must be applied to the design of all game systems, from agent AI to event generation.

### Border 1: Preservation of Assets

* **Lore Justification:** The culture of the sector's colonists was forged by the scarcity of complex materials and skilled personnel. Every ship is a significant investment, and every skilled pilot is a nearly irreplaceable resource. This led to the creation of the **Preservation Convention**, which prizes neutralization and capture over outright destruction.
* **Mechanical Implementation:**
    * **High Cost of Destruction:** Systems must be designed so that the total destruction of a ship is the least profitable and most consequence-heavy outcome of combat. It should result in minimal WP gain, significant Reputation loss, and potential negative Faction Standing changes.
    * **Rewarding Disablement:** Conversely, disabling a ship to allow for salvage (`Claim Wreckage`) or compelling a surrender must always be the most mechanically and narratively rewarding path.
    * **NPC Behavior:** The logic for NPC agents must reflect this. Most NPCs will default to disabling tactics. Only specific, defined groups (e.g., fanatical outlaws, sociopaths) would ever favor wanton destruction, making them feel truly alien to the setting's culture.

### Border 2: Pragmatic Agent Behavior

* **Lore Justification:** The people of the sector are pragmatic, utilitarian, and focused on managing risk, time, and resources. Their actions are driven by logical needs and calculated goals, not chaos.
* **Mechanical Implementation:**
    * **Goal-Oriented AI:** The `Goal System` for NPCs must be built on heuristics, not pure randomness. A trading agent will seek to maximize profit. A pirate agent will seek to acquire wealth with the least possible risk.
    * **Systemic Pressures:** The core game loops and resource sinks (like the `Time System`'s `Upkeep Cost`) must apply to NPCs as well as the player, ensuring they operate under the same pragmatic pressures.

### Border 3: Contained Scale

* **Lore Justification:** Common Faster-Than-Light travel does not exist. The game's story is focused on the dense, personal, and political dynamics within a single star system or a small cluster of them (a "Sector").
* **Mechanical Implementation:**
    * **Sector-Based World:** The game world must be structured as a series of discrete, high-detail sectors, not a seamless galaxy.
    * **Relevant Events:** The `Event System` and `Chronicle` must prioritize generating and logging events that are local and relevant to the player. The "living world" should feel immediate and present, not like a distant, abstract simulation.

### Border 4: A Human-Centric Universe

* **Lore Justification:** The game's narrative is fundamentally about humanity—specifically, the early colonists and explorers of this sector—and how they've adapted.
* **Mechanical Implementation:**
    * **Agent Focus:** The simulation must be focused on the interactions between human agents and their factions. The vast majority of generated events should relate to trade, politics, piracy, personal relationships, and discovery.
    * **The Alien is Alien:** True alien life, cosmic horrors, or spatio-temporal anomalies must be treated as rare, significant, and narratively impactful. The simulation should not be populated with a menagerie of random sci-fi creatures and phenomena; this preserves their thematic weight.

--- Start of ./7.10-GDD-Assets-Energy-Storage.md ---

# 7.10 GDTLancer - Energy Storage

**Version:** 1.1
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `7.4-GDD-Assets-Power-Plants.md` (v1.1), `7.9 GDTLancer - Utility Tools` (v1.2)

---

## 1. Overview

This document defines the asset configurations for shipboard energy storage systems. These components work in conjunction with **Power Plants** to manage a ship's electrical supply, either by storing large reserves or enabling rapid discharge for high-draw systems.

This document follows the standard 3-part structure:
1.  **Lore & Visuals:** Descriptive text for in-game infocards.
2.  **Godot Implementation:** The `Resource` properties for the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore & Visuals (For Infocards)

| Asset Type | Visual & Lore Description |
| :--- | :--- |
| **"High-Capacity Battery Banks"** | Large, heavy banks of chemical batteries designed to store significant amounts of energy generated by the ship's power plant. They have a relatively slow discharge rate, making them suitable for providing sustained power or emergency backup, but not for peak loads. Visually, they are banks of simple, rugged containers. |
| **"Supercapacitors"** | Advanced energy storage using electrostatic fields rather than chemical reactions. They store less total energy than batteries but can discharge almost instantly, providing massive bursts of power for high-draw systems like Ablative Lasers or engine startups. Visually, they are more compact and complex modules. |

---

## 3. Part 2: Godot Implementation (Asset Stats)

Energy Storage units will be defined as `Resource` files (e.g., `SupercapacitorBank.tres`) and managed by the `Asset System`. The `Asset System` will track the `current_charge_mj` for each unit.

### Energy Storage `Resource` Properties

| Asset Type | `capacity_mj` (float) | `max_discharge_rate_mw` (float) | `charge_efficiency` (float) |
| :--- | :--- | :--- | :--- |
| **"Battery Bank"** | 1000.0 (High Capacity) | 2.0 (Low Discharge) | 0.9 |
| **"Supercapacitors"** | 100.0 (Low Capacity) | 50.0 (High Discharge) | 0.95 |

### Implementation Notes

* **`capacity_mj`:** The total amount of energy (in megajoules) the unit can store.
* **`max_discharge_rate_mw`:** The maximum power (in megawatts) the unit can output instantaneously. Supercapacitors excel here, enabling high-draw tools.
* **Power Management:** The `Asset System` manages the flow of energy. Power Plants charge these storage units. When ship power draw exceeds plant output, the storage units discharge (up to their `max_discharge_rate_mw`) to cover the deficit. If draw exceeds *both* plant output and storage discharge rate, systems shut down.
* **`charge_efficiency`:** Represents energy lost during the charging process.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

For the TTRPG, energy storage provides a buffer or enables peak power actions.

### Analogue Asset Stats

| Asset Type | Asset Difficulty (Tech) | `WP` Cost | Special Rule |
| :--- | :--- | :--- | :--- |
| **"Battery Bank"** | **0** (Standard) | Low | **Reserve Power:** Can spend **1 FP** to ignore the effects of a temporary power loss (e.g., failed Power Plant check) for 1 `TU`. |
| **"Supercapacitors"** | **+1** (Advanced) | Medium | **Peak Discharge:** Enables the use of assets requiring "Peak Power" (e.g., advanced lasers). Can spend **1 FP** to guarantee sufficient power for one activation of such an asset, even if Power Slots are currently insufficient. |

### Analogue Rules

* **Reserve Power:** Batteries provide a safety net against temporary power failures or insufficient generation.
* **Peak Discharge:** Supercapacitors are required for certain high-energy actions or assets, acting as an enabler and providing a way to push systems beyond normal limits using **Focus Points (FP)**.
* **Asset Difficulty (Tech):** Applies to `Action Checks` related to repairing or managing the energy storage system.

--- Start of ./7.11-GDD-Assets-Propellant-Storage.md ---

# 7.11 GDTLancer - Propellant Storage

**Version:** 1.1
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `7.2-GDD-Assets-Ship-Engines.md` (v1.4)

---

## 1. Overview

This document defines the asset configurations for propellant storage. This specifically covers storage for **liquid and cryogenic propellants** (like Liquid Oxygen (LOX) or liquid hydrogen for NTRs).

It does **not** cover solid propellant storage, as the "Rock-Eater" hybrid engine's solid fuel grain is considered an integral part of the engine casing itself.

This document follows the standard 3-part structure:
1.  **Lore & Visuals:** Descriptive text for in-game infocards.
2.  **Godot Implementation:** The `Resource` properties for the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore, Visuals, & Dimensions (For Infocards)

| Asset Type | Visual & Lore Description | Baseline Dimensions (Lore) |
| :--- | :--- | :--- |
| **"Insulated Dewar Tank"** | The baseline liquid storage tank. It is a passive, heavily insulated vessel. While reliable, it cannot perfectly prevent boil-off, causing a slow loss of cryogenic fuel over time. This limits a ship's maximum mission duration. Visually, it is a simple, reinforced cylinder. | **35m³ Baseline:**<br>~3m diameter<br>~5m long |
| **"Active Cryocooler Tank"** | A high-end cryogenic storage tank. It uses active cooling systems (powered by the ship's reactor) to completely eliminate fuel boil-off. Essential for long-haul vessels or ships using advanced propellants (like NTRs). Visually, it is bulkier, with external power couplings and small radiator fins. | **35m³ Baseline:**<br>~3.5m diameter (with machinery)<br>~5m long |

### Lore Note (Baseline Configuration)

The standard ship configuration seen in Phase 1 (e.g., a "Spinal" hull with a "Cruiser" engine) uses **two "Insulated Dewar Tanks"** to hold its `~80t` LOX supply.

---

## 3. Part 2: Godot Implementation (Asset Stats)

Propellant Tanks will be defined as `Resource` files (e.g., `InsulatedDewarTank.tres`) and managed by the `Asset System`. The `Asset System` will be responsible for tracking the `current_fuel_level` of each tank.

### Tank `Resource` Properties

| Asset Type | `capacity_m3` (float) | `boil_off_rate_per_tu` (float) | `power_draw_mw` (float) |
| :--- | :--- | :--- | :--- |
| **"Insulated Dewar"** | 35.0 | 0.01 (Example value) | 0.0 |
| **"Active Cryocooler"** | 35.0 | 0.0 | 0.5 (Example value) |

### Implementation Notes

* **`capacity_m3`:** The total volume of propellant the tank can hold.
* **`boil_off_rate_per_tu`:** This is the key mechanic. The `Time System`, upon advancing the `Time Clock`, will trigger a function in the `Asset System` to deduct this amount of fuel from all "Insulated Dewar Tanks."
* **`power_draw_mw`:** The "Active Cryocooler Tank" requires constant power from the ship's Power Plant (defined in `7.4-GDD-Assets-Power-Plants.md`). If power is lost, it reverts to behaving like a (less effective) Dewar tank.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

For the tabletop TTRPG, the mechanical difference is abstracted into a simple rule that interacts with the `Time Clock` and `WP` systems.

### Analogue Asset Stats

| Asset Type | Asset Difficulty | `WP` Cost (Est.) | Special Rule |
| :--- | :--- | :--- | :--- |
| **"Insulated Dewar"** | **0** (Standard) | (Baseline) | **Boil-Off:** If a `World Event Tick` occurs while you are not docked at a station, lose 1 `Endurance` segment from your ship's engine. |
| **"Active Cryocooler"** | **0** (Standard) | **High** (Upgrade) | **Active Cooling:** Immune to propellant **Boil-Off**. (May fail if the ship's Power Plant gains a negative `Ship Quirk`). |

### Analogue Rules

* **Boil-Off:** This rule links the `Time Clock` to the `Endurance` stat of the engine, creating a resource drain over time.
* **Active Cooling:** This asset negates the `Boil-Off` rule, but is dependent on the ship's power system.

--- Start of ./7.1-GDD-Assets-Ship-Design.md ---

# 7.1 GDTLancer - Ship Design Philosophy

**Version:** 2.3
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `6.1-GDD-Lore-Background.md` (v1.7), `6-GDD-Lore-Narrative-Borders.md` (v1.2), `7-GDD-Assets-Style.md` (v1.1), `7.2-GDD-Assets-Ship-Engines.md` (v1.3), `7.3-GDD-Assets-Ship-Chassis.md` (v1.1)

---

## 1. Overview

This document defines the foundational technology and design philosophy for all ship assets in the GDTLancer universe. It serves as a "palette" of available components, systems, and materials that inform the design of specific, player-facing assets (like engines and hulls). This philosophy is rooted in the lore of a colonial civilization defined by resource scarcity and pragmatic engineering.

---

## 2. Core Principles

* **Function over Form:** Design prioritizes a clear purpose over aesthetics. This aligns with the "Pragmatic Aesthetics" style.
* **Integrated Hull:** The ship's design is a complete, pre-designed spaceframe, not assembled from modular chassis parts.
* **Lived-In Aesthetic:** Ships show signs of maintenance and historical use (wear, patches, modifications), reflecting the "Waste not, want not" culture.

---

## 3. Propulsion Systems

### 3.1. Main Engines

* **"Rock-Eater" (Chemical - Baseline)**
    * **Propellant:** A solid fuel grain (powdered metals + binder) and a liquid oxidizer (LOX).
    * **Niche:** Common, reliable hybrid engine. This is the technology used by the Phase 1 "Cruiser," "Balanced," and "Brawler" engine configurations.
* **Nuclear Thermal Rocket (NTR)**
    * **Mechanism:** Fission reactor superheats a secondary liquid propellant (e.g., liquid hydrogen).
    * **Niche:** Top-tier, high-efficiency performance. Extremely expensive.

### 3.2. Emergency Propulsion

* **Microwave / Resistojet Thrusters**
    * **Mechanism:** Uses electricity to heat any available mass (e.g., waste gas) into plasma.
    * **Niche:** Very low thrust, high-efficiency "get-home" engine. Requires a significant power source.

---

## 4. Power Plants

* **Solar Panels**
    * **Niche:** Baseline power generation. Low output, ineffective far from a star.
* **Radioisotope Thermoelectric Generator (RTG)**
    * **Niche:** Low, constant power output for extreme durations. Ideal for emergency backup or low-power "dark running".
* **Fuel Cells**
    * **Niche:** Mid-grade power. Consumes propellant (e.g., hydrogen) to generate electricity. Better output than solar, but requires fuel.
* **Fission Reactor**
    * **Fuel:** Rare Uranium/Thorium ores from asteroids.
    * **Niche:** High-end, long-duration power source. Essential for deep space operations and high-draw modules, including NTR engines.

---

## 5. Cooling Systems

* **Standard Radiators**
    * **Niche:** Basic, durable heat dissipation. Bulky, often with exposed, vulnerable elements. Used on "Balanced" and "Brawler" engines.
* **Cryo-Coolers**
    * **Niche:** High-efficiency, active cooling for advanced systems. More compact, requires power, more fragile.

---

## 6. Life Support Systems

* **Open-Loop System**
    * **Niche:** Consumes stored consumables. Limits mission duration. Standard on short-range vessels.
* **Closed-Loop Recycler**
    * **Niche:** Recycles air and water using advanced technology. Extends mission endurance significantly.
* **G-Stasis Cradle**
    * **Function:** Mitigates extreme G-forces.
    * **Components:** Exo-Harness, Contour Bladders, Pressurized Breathing, Neuro-Biological Support.

---

## 7. Radiation Protection

* **Baseline Hull Shielding**
    * **Niche:** Standard hull materials offer minimal protection from cosmic radiation and solar flares. Sufficient only for short-duration, in-system travel.
* **Dense Core Laminate**
    * **Niche:** Heavy, layered armor with a dense material core. Offers significant radiation protection for deep space travel at the cost of increased mass.

---

## 8. Turbomachinery

* **Standard Mechanical Pumps**
    * **Niche:** Baseline pumps for propellant and coolant. Heavy, durable, and power-inefficient.
* **Single-Crystal Blisk Turbopumps**
    * **Niche:** Advanced, high-performance pumps. Fabricated from exotic single-crystal alloys for extreme efficiency, low mass, and high durability. Complex and costly.

---

## 9. External Hardpoints & Utility Tools

Tools often serve dual purposes for industry and combat, per the **Preservation Convention**.

### 9.1. Mining & Salvage Tools

* **Rotary Mining Drill:** Precision ore extraction. Doubles as a close-range tool for **breaching ship hulls** in a controlled manner.
* **Reinforced Prow:** A structural modification that adds a reinforced "hard place" to the ship's bow. It is designed for controlled, high-thrust interactions (like pushing large salvage objects) rather than high-speed impacts. Its combat application is for **breaching, pinning, or bulldozing** disabled targets.
* **High-Power Ablative Laser:** Skims trace elements from surfaces. Can strip ship armor or damage exposed external systems.
* **Seismic Charge Launcher:** Controlled demolition of asteroids via expensive consumables. Can target ship subsystems.

### 9.2. Capture & Control Tools

* **Harpoon & Winch Array:** Tethers asteroids or ships. Functions as a recoverable projectile.

### 9.3. Gas/Debris Collectors

* **Forward-Facing Debris Scoop:** Actively collects fragments from wreckage or fractured asteroids.

---

## 10. Energy Storage

* **High-Capacity Battery Banks**
    * **Niche:** High-storage, low-power-output. Stores large energy reserves from power plants but has a slow discharge rate.
* **Supercapacitors**
    * **Niche:** High-power-output, low-storage. Discharges almost instantly for high-draw systems (lasers, engine startup).

---

## 11. Size & Mass Characteristics

* **Size Range:** 20 to 40 meters in length.
* **Mass Range:** Dry mass from ~20 metric tons (light vessels) to over 100 metric tons (heavy freighters).
* **Core Design:** Built around a compact, single-pilot life support pod with an integrated **G-Stasis Cradle**.

---

## 12. Construction Materials

* **Welded Steel & Composites (Baseline)**
    * **Niche:** Heavy, cheap, easy to repair. Standard for industrial vessels.
* **Titanium-Alloy Frame (Mid-Grade)**
    * **Niche:** Lighter and stronger than steel. Improves agility and durability for a higher cost.
* **Graphene-Reinforced Ceramics (High-End)**
    * **Niche:** Extremely light, durable, high heat resistance. Rare and difficult to repair.

---

## 13. Liquid & Cryogenic Propellant Storage

* **Insulated Dewar Tank**
    * **Niche:** Baseline liquid storage (e.g., for LOX). Passive insulation results in inevitable fuel boil-off over time, limiting mission duration.
* **Active Cryocooler Tank**
    * **Niche:** High-end cryogenic storage. Uses power to actively cool the propellant, eliminating boil-off. Essential for long-haul cryogenic-fueled ships (e.g., LOX or NTR propellant).

--- Start of ./7.2-GDD-Assets-Ship-Engines.md ---

# 7.2 GDTLancer Ship Engines

**Version:** 1.4
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `2.1-GDD-Development-Phase1-Scope.md` (v1.3)

---

## 1. Overview

This document defines the player-facing engine configurations for GDTLancer. The initial entries ("Cruiser", "Balanced", "Brawler", "Interceptor") are scoped for Phase 1. Placeholders for future-phase technologies, such as Nuclear Thermal (NTR) and Microwave thrusters, are included for design completeness.

This document is broken into three sections to align with the project's transmedia goals:
1.  **Lore & Visuals:** Descriptive text for in-game infocards, aligning with the "Pragmatic Aesthetics".
2.  **Godot Implementation:** The `.tres` values that drive the "fake physics" model.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore, Visuals, & Dimensions (For Infocards)

The Phase 1 hybrid engines are all configurations of the baseline **"Rock-Eater" (Chemical - Baseline)** propulsion system. Future technologies will have distinct characteristics.

| Engine Config. | Visual & Exhaust Description | Estimated Dimensions (Lore) |
| :--- | :--- | :--- |
| **"Cruiser"** | A rugged, reliable single-cylinder hybrid engine. Its plain, armored casing emphasizes a **no-frills, function-first** design, with minimal external components save for a single, heavily shielded LOX feed line. It features a **simple conical nozzle**. The exhaust is a tight, stable, pale-blue or white flame. | **Baseline:**<br>Casing: ~8m long, ~2m diameter<br>Nozzle: ~2.5m wide<br>Total Length: ~9.5m |
| **"Balanced"** | A modified Cruiser chassis with visible performance upgrades. These include additional **heat shielding panels** and **small, passive radiator fins**. It uses a more pronounced **bell-shaped nozzle**. The exhaust is brighter, with visible **shock diamonds** (Mach diamonds). | **Variant of Cruiser:**<br>Casing: ~8m long, ~2.5m diameter (with fins)<br>Nozzle: ~3m wide<br>Total Length: ~10m |
| **"Brawler"** | Visibly aggressive, this engine's casing integrates prominent, **armored radiator panels**. The LOX feed lines are **thicker and more numerous**. It vents through a **single, very large, but relatively short and wide nozzle**. The exhaust is a violent, turbulent, orange-white plume. | **Variant of Cruiser:**<br>Casing: ~8m long, ~3.5-4m diameter (with radiators)<br>Nozzle: ~4m wide<br>Total Length: ~9m (short nozzle) |
| **"Interceptor"** | Not a traditional engine; it's a **rectangular or hexagonal armored block** that resembles a missile pod. Its surface has **visible seams** indicating where the entire cartridge cassette is loaded. The face is studded with the **many small, simple conical nozzles** of the individual cartridges. The "exhaust" is a massive, overwhelming, and short-lived **cloud of thick, dirty smoke and fire**. | **Module Block:**<br>~4m x 4m (face)<br>~2-3m (deep) |
| **Nuclear Thermal (NTR)** | *(Future Phase)* A complex, heavy engine built around a shielded fission reactor. The nozzle is large and advanced, designed to handle superheated propellant. Exhaust is a clean, intensely hot, and transparent or pale-colored plume. | TBD (Likely large/heavy) |
| **Microwave (Emergency)** | *(Future Phase)* A compact thruster block, often used as a backup. Features no large propellant casing, only power couplings and a small, complex nozzle array. Exhaust is a very faint, low-energy plasma glow. | TBD (Likely small module) |

### Lore Note (Propellant)

The note below applies to the Phase 1 "Rock-Eater" hybrid engines. Propellant for other technologies (NTR, etc.) will differ.

The "engine" casing (e.g., the `8m x 2m` cylinder of the Cruiser) contains the solid fuel. The baseline propellant load for a standard ship is assumed to be **~120 metric tons**. This is composed of:
* **~40t solid "Rock-Eater" fuel grain:** Housed within the engine casing itself. (The `8m x 2m` casing provides `~25.1m³` of volume, which fits 40t of high-density fuel composite).
* **~80t Liquid Oxygen (LOX):** Stored in **two external 35m³ cryotanks** (total `70m³` volume, matching the `~80t` mass of LOX), which are fed into the engine.

---

## 3. Part 2: Godot Implementation (For `asset_ship_template.gd`)

These are the *actual* gameplay parameters to be set in the `ShipTemplate` `.tres` resource files (which derive from `asset_ship_template.gd`).

### `asset_ship_template.gd` Values

| Engine Config. | `max_move_speed` | `acceleration` | `deceleration` | `max_turn_speed` |
| :--- | :--- | :--- | :--- | :--- |
| **"Cruiser"** | `500.0` | `0.3` | `0.3` | `0.6` |
| **"Balanced"** | `500.0` | `0.5` | `0.5` | `0.75` |
| **"Brawler"** | `500.0` | `0.8` | `0.8` | `1.1` |
| **Nuclear Thermal (NTR)** | `500.0` | `TBD` | `TBD` | `TBD` |
| **Microwave (Emergency)**| `100.0` | `0.1` | `0.1` | `0.3` |

### Implementation Notes

* These values are properties of the `ShipTemplate` `Resource`.
* The `AgentBody`'s `initialize` function reads these values from its associated `ShipTemplate` (provided by `AssetSystem`) and passes them to the `MovementSystem`'s `initialize_movement_params` function.
* `acceleration` (float) is the `lerp` factor. This value is the final gameplay implementation of the `Thruster Power` stat.
* `max_turn_speed` (float) is the `slerp` factor for rotation. This is the implementation of the `Agility` stat.
* **"Interceptor" (SRM):** This is **not** a `ShipTemplate` configuration. It will be implemented as a special *action* or *consumable asset* that, when activated, temporarily overrides the `MovementSystem.acceleration` with a massive value (e.g., `5.0` or higher) for a short, fixed duration.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

These stats are for the tabletop TTRPG, aligning with the core rules for `Action Checks` and the `Analogue Setup`.

### Analogue Asset Stats

| Engine Config. | Asset Difficulty (Piloting) | Endurance (Segments / ~TU) | `WP` / Resource Cost |
| :--- | :--- | :--- | :--- |
| **"Cruiser"** | **-1** (Easy/Stable) | **~10 Segments** | Low (Standard Refuel) |
| **"Balanced"** | **0** (Standard) | **~6 Segments** | Low (Standard Refuel) |
| **"Brawler"** | **+2** (Hard/Volatile) | **~3 Segments** | High (Fast Refuel) |
| **"Interceptor"** | **+3** (Burst/Risky) | **1-2 Bursts** | Costs `WP` to re-arm cartridges. |
| **Nuclear Thermal (NTR)** | **+3** (Complex) | **~20+ Segments** | **Very High** (Requires Fission Fuel) |
| **Microwave (Emergency)** | **0** (Reliable) | Unlimited (Low-Thrust) | N/A (Consumes Power) |

### Analogue Rules

* **Asset Difficulty:** This modifier is applied to the player's `3d6 + Module Modifier` `Action Check` when piloting. A `Brawler` (+2) is more difficult and risky to control.
* **Endurance (Segments / ~TU):** Defines how many "travel segments" the ship can cover before refueling is required. Each segment of travel costs `Time Units (TU)`, which advances the `Time Clock`.
* **`WP` Cost:** The `Brawler` and `Interceptor` engines are a `Wealth Point (WP)` sink, representing their inefficiency and specialized re-arming/refueling needs. This drives the economic loop by costing the player `WP` at stations.

--- Start of ./7.3-GDD-Assets-Ship-Chassis.md ---

# 7.3 GDTLancer Ship Chassis

**Version:** 1.2
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1.1-GDD-Core-Systems.md` (v1.5), `2.1-GDD-Development-Phase1-Scope.md` (v1.3), `6.1-GDD-Lore-Background.md` (v1.7), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `7.2-GDD-Assets-Ship-Engines.md` (v1.4), `4.1-GDD-Analogue-Setup.md` (v1.4)

---

## 1. Overview

This document defines the primary ship hull classes. A crucial design constraint is the **"Integrated Hull"** philosophy. Hulls are not modular chassis parts the player assembles; they are distinct, pre-designed spaceframes (ship classes) that the player acquires as a complete asset.

These integrated hulls are significant assets acquired through the **Asset Progression system**. Modularity is expressed by slotting components (like engines, tanks, and utility tools) into the pre-existing, specialized frames.

This document is broken into three sections:
1.  **Lore & Visuals:** Descriptive text for in-game infocards, based on the `Pragmatic Aesthetics`.
2.  **Godot Implementation:** The core stats (mass, cargo, slots) that each hull defines as a `Resource` within the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules and stats for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore & Hull Descriptions (For Infocards)

| Hull Class | Visual & Design Philosophy | Lore Role & GDD Justification |
| :--- | :--- | :--- |
| **"Spinal"** | The baseline, pragmatic, function-first design. Its linear layout aligns all core components along a central thrust axis, making it the most straightforward and efficient versatile vessel. | The ubiquitous **freighter, explorer, or multi-role vessel**. The reference model used for the "Cruiser" engine is a perfect example of this common, reliable design. |
| **"Catamaran"** | A dual-hull frame designed for a specific industrial purpose: mounting oversized modules that wouldn't fit on a standard spinal frame. Features dual-engine mounts for redundancy and stable thrust. | A dedicated **Industrial Hauler or Salvage Platform**. The wide central space is designed to mount specialized tools like a **Forward-Facing Debris Scoop** or oversized cargo pods. |
| **"Trident"** | A triple-engine mount frame, over-engineered to support extreme power generation or acceleration. It is designed to handle high-draw systems like **Fission Reactors** or **Microwave Thrusters**. | A **high-end industrial or combat vessel**. It may be a **Deep-Space Miner** powering a **High-Power Ablative Laser**, or a **fast attack vessel** using raw acceleration for high-thrust industrial takedowns, as per the **Preservation Convention**. |
| **"Tower"** | Not a "Broadside Battleship," but a **"Broadside Grappler"**. Its purpose is to present a massive "tool wall" for disabling and capturing enemy vessels, perfectly aligning with the **Preservation Convention's** focus on **preservation of assets** and close-quarters disabling actions. | A specialized **salvage and capture vessel**. Its tactical role is to "catch" a target with a volley of **Harpoon & Winch Arrays**, then use **Rotary Drills** (to breach) and **Ablative Lasers** to systematically disable and capture it. |

### Lore Note (Enabling Technology)

All exotic hull designs, especially the high-G "Trident" and the lateral-strafing "Tower," are only viable due to the **G-Stasis Cradle**. This system allows pilots to survive the extreme and unusual acceleration vectors these specialized ships produce.

---

## 3. Part 2: Godot Implementation (Asset Stats)

Ship Hulls will be defined as `Resource` files (e.g., `SpinalHull.tres`) and managed by the `Asset System`. These resources define the ship's core, non-performance stats and its component slots.

### Hull Base Stats & Slots

| Hull Class | Base Mass (t) | Base Cargo (units) | Engine Slots | Utility Slots (Est.) |
| :--- | :--- | :--- | :--- | :--- |
| **"Spinal"** | 60 | 50 | 1 | 2 |
| **"Catamaran"** | 120 | 150 | 2 | 4 (Oversized) |
| **"Trident"** | 90 | 40 | 3 | 3 (High-Power) |
| **"Tower"** | 150 | 100 | 1 (Standard) | 8+ (Broadside) |

### Implementation Notes
* **`Base Mass (t)`:** This is the hull's dry mass. The `Asset System` will be responsible for the final "wet mass" calculation (Base Mass + Engine Mass + Cargo Mass + Fuel Mass) that provides the `Mass` stat required by the Piloting Module.
* **`Base Cargo (units)`:** This is the `Cargo Capacity` stat used by the `Inventory System` and Trading Module.
* **Slots:** These define the number and type of components (like engines from `7.2-GDD-Assets-Ship-Engines.md` or tools from `7.9-GDD-Assets-Utility-Tools.md`) that can be slotted into the hull.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

For the tabletop TTRPG, the hull provides base stats (like Hull Integrity) and, like engines, an `Asset Difficulty` modifier that stacks.

### Analogue Asset Stats

| Hull Class | Asset Difficulty (Global) | Base Hull | Base Cargo | Special Rule |
| :--- | :--- | :--- | :--- | :--- |
| **"Spinal"** | **0** (Baseline) | 10 | 5 | Standard, versatile. |
| **"Catamaran"** | **+1** (Sluggish) | 15 | 15 | Can mount 'Industrial' tools. `+1` to salvage-related `Action Checks`. |
| **"Trident"** | **+1** (High-G) | 12 | 4 | Can mount 3 engines. `+1` to `Act Risky` Piloting checks for interception. |
| **"Tower"** | **+2** (Unwieldy) | 20 | 10 | Can mount 'Broadside' tools. `+1` to all `Action Checks` for grappling or disabling targets. |

### Analogue Rules

* **Asset Difficulty:** This modifier stacks with the engine's modifier. The *final* `Module Modifier` for an `Action Check` is `Skill + Engine_Difficulty + Hull_Difficulty`. A "Trident" hull (+1) with a "Brawler" engine (+2) would have a total `+3` difficulty, making it very hard to control, which fits the lore.
* **Base Hull / Cargo:** These are the starting values for the asset.
* **Special Rule:** These provide a narrative and mechanical benefit that reinforces the hull's specific role.

--- Start of ./7.4-GDD-Assets-Power-Plants.md ---

# 7.4 GDTLancer - Power Plants

**Version:** 1.1
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1.1-GDD-Core-Systems.md` (v1.5), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `7.2-GDD-Assets-Ship-Engines.md` (v1.4), `7.3-GDD-Assets-Ship-Chassis.md` (v1.2), `7.11-GDD-Assets-Propellant-Storage.md` (v1.0)

---

## 1. Overview

This document defines the asset configurations for shipboard power plants. These are a critical component, as they supply the necessary electricity for all other ship systems, from basic life support to high-draw modules like advanced engines, tools, and cooling systems.

The Phase 1 starting asset will be the basic "Solar Panels," with other plants available as goals via the **Asset Progression system**.

This document follows the standard 3-part structure:
1.  **Lore & Visuals:** Descriptive text for in-game infocards.
2.  **Godot Implementation:** The `Resource` properties for the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore & Visuals (For Infocards)

| Asset Type | Visual & Lore Description |
| :--- | :--- |
| **"Solar Panels"** | The baseline power source. Typically large, articulated "wings" of photovoltaic cells. Reliable and require no fuel, but suffer from low output and are ineffective in deep space or far from a star. |
| **"RTG"** | **(Radioisotope Thermoelectric Generator)**. A small, heavy, and extremely durable power source with no moving parts. Provides a low but constant power output for extreme durations. Ideal for emergency backup or "dark running". |
| **"Fuel Cells"** | A mid-grade power system that consumes propellant (e.g., hydrogen) to generate electricity. Offers better output than solar panels but requires a steady fuel supply, limiting its endurance. |
| **"Fission Reactor"** | The high-end, long-duration power source. A compact, heavily-shielded reactor that provides massive power output. It is essential for deep space operations and high-draw modules, such as those found on "Trident" hulls. |

---

## 3. Part 2: Godot Implementation (Asset Stats)

Power Plants will be defined as `Resource` files (e.g., `FissionReactor.tres`) and managed by the `Asset System`. The `Asset System` will track the ship's `current_power_output` vs. `current_power_draw`.

### Power Plant `Resource` Properties

| Asset Type | `power_output_mw` (float) | `fuel_type` (String) | `fuel_consumption_rate` (float) |
| :--- | :--- | :--- | :--- |
| **"Solar Panels"** | 1.0 (Baseline) | "None" | 0.0 |
| **"RTG"** | 0.5 | "None" | 0.0 |
| **"Fuel Cells"** | 5.0 | "Hydrogen" | 0.1 / TU |
| **"Fission Reactor"**| 20.0 | "Fission Fuel" | 0.01 / TU |

### Implementation Notes

* **`power_output_mw`:** The baseline power (in megawatts) the plant provides. The `Solar Panels`' output will be modified by a "solar_efficiency_factor" based on distance from the sector's star.
* **Power Management:** The `Asset System` must manage the ship's power budget. Modules like "Active Cryocooler Tanks", "Microwave Thrusters", and "Ablative Lasers" will add to the `current_power_draw`. If `draw > output`, systems will shut down, starting with non-essential modules.
* **`fuel_type` / `consumption_rate`:** The `Time System`, upon advancing the `Time Clock`, will trigger a function in the `Asset System` to consume fuel from the `Inventory System` for all fuel-consuming plants.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

For the TTRPG, power is abstracted into "Power Slots," which represent how many high-draw modules a ship can support.

### Analogue Asset Stats

| Asset Type | Asset Difficulty (Tech) | `WP` Cost | Power Slots | Special Rule |
| :--- | :--- | :--- | :--- | :--- |
| **"Solar Panels"** | **0** (Simple) | (Baseline) | **1** | **Solar Dependent:** In deep space, `Power Slots` are reduced to 0. |
| **"RTG"** | **0** (Simple) | Low | **0** | **Always On:** Provides 0 `Power Slots`, but keeps basic life support running in any condition. |
| **"Fuel Cells"** | **+1** (Managed) | Medium | **2** | **Consumes Fuel:** Costs `1 WP` per `World Event Tick` to represent refueling. |
| **"Fission Reactor"** | **+2** (Complex) | Very High | **4** | **Consumes Fuel:** Costs `5 WP` (or rare item) per `World Event Tick` to represent refueling. |

### Analogue Rules

* **Power Slots:** High-draw assets (like an "NTR Engine" or "Ablative Laser") require 1 or more `Power Slots` to be functional.
* **Asset Difficulty (Tech):** This modifier applies to any `Action Check` related to repairing the power plant or managing a power-related crisis.

--- Start of ./7.5-GDD-Assets-Cooling-Systems.md ---

# 7.5 GDTLancer - Cooling Systems

**Version:** 1.1
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `7.2-GDD-Assets-Ship-Engines.md` (v1.4), `7.4-GDD-Assets-Power-Plants.md` (v1.1)

---

## 1. Overview

This document defines the asset configurations for shipboard cooling systems. Heat management is a critical aspect of the pragmatic ship design philosophy, as high-performance components like engines and power plants generate significant waste heat that must be dissipated to prevent damage or reduced efficiency.

This document follows the standard 3-part structure:
1.  **Lore & Visuals:** Descriptive text for in-game infocards.
2.  **Godot Implementation:** The `Resource` properties for the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore & Visuals (For Infocards)

| Asset Type | Visual & Lore Description |
| :--- | :--- |
| **"Standard Radiators"** | The baseline heat dissipation system. Consists of large, often external, radiator panels. They are bulky and potentially vulnerable but are reliable and require no power. These are seen integrated into the casing of "Balanced" and "Brawler" engines. |
| **"Cryo-Coolers"** | An advanced, high-efficiency active cooling system. More compact than standard radiators, they use power to significantly enhance heat dissipation, making them essential for high-output systems like Fission Reactors or NTR engines. They are, however, more fragile and complex. |

---

## 3. Part 2: Godot Implementation (Asset Stats)

Cooling Systems will be defined as `Resource` files (e.g., `StandardRadiatorSet.tres`) and managed by the `Asset System`. The `Asset System` will track the ship's overall `current_heat_level` and `heat_dissipation_rate`.

### Cooling System `Resource` Properties

| Asset Type | `heat_dissipation_mw` (float) | `power_draw_mw` (float) | `fragility_modifier` (float) |
| :--- | :--- | :--- | :--- |
| **"Standard Radiators"** | 5.0 (Baseline) | 0.0 | 1.0 (Standard) |
| **"Cryo-Coolers"** | 20.0 | 2.0 | 1.5 (More fragile) |

### Implementation Notes

* **`heat_dissipation_mw`:** The amount of heat (in thermal megawatts) the system can dissipate per second.
* **Heat Management:** The `Asset System` must track the ship's `current_heat_level`. Components like Engines and Power Plants will *generate* heat based on their activity. The `Asset System` calculates the net heat change (`Heat Generated - Total Heat Dissipation`).
* **Overheating:** If `current_heat_level` exceeds a threshold, negative effects occur (e.g., reduced engine efficiency, component damage, potential for adding "Ship Quirks").
* **`power_draw_mw`:** Cryo-Coolers require power from a Power Plant. If power is insufficient, their dissipation rate drops significantly.
* **`fragility_modifier`:** A multiplier used by the `Combat Module` when determining the chance of this component being damaged or gaining a quirk. Cryo-Coolers are more susceptible to damage.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

For the TTRPG, cooling is abstracted. The primary effect is enabling high-performance modules and managing an abstract "Heat" track during stressful situations.

### Analogue Asset Stats

| Asset Type | Asset Difficulty (Tech) | `WP` Cost | Special Rule |
| :--- | :--- | :--- | :--- |
| **"Standard Radiators"** | **0** (Simple) | (Baseline) | Provides **1 Heat Capacity**. Sufficient for standard operations. |
| **"Cryo-Coolers"** | **+1** (Complex) | Medium | Requires **1 Power Slot**. Provides **3 Heat Capacity**. Enables use of "High Heat" assets (like NTR). |

### Analogue Rules

* **Heat Capacity:** Represents how much stress the ship's systems can take before overheating. Certain `Action Check` failures (especially `Risky` piloting or combat actions) or specific events may add **Heat Points**.
* **Overheating:** If `Heat Points >= Heat Capacity`, the ship suffers a consequence (e.g., gains a negative "Ship Quirk", must spend `TU` to vent heat).
* **Enabling Assets:** Certain high-performance assets (like an NTR engine) might explicitly require "Cryo-Coolers" (or equivalent Heat Capacity) to function.
* **Asset Difficulty (Tech):** Applies to `Action Checks` for repairing the cooling system.

--- Start of ./7.6-GDD-Assets-Life-Support.md ---

# 7.6 GDTLancer - Life Support Systems

**Version:** 1.1
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `6.1-GDD-Lore-Background.md` (v1.7), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `7.3-GDTLancer-Ship-Chassis.md` (v1.2)

---

## 1. Overview

This document defines the asset configurations for shipboard life support systems. These are essential for pilot survival and directly impact mission endurance by managing consumables or recycling vital resources. It also includes the critical **G-Stasis Cradle**, which enables high-performance maneuvering.

This document follows the standard 3-part structure:
1.  **Lore & Visuals:** Descriptive text for in-game infocards.
2.  **Godot Implementation:** The `Resource` properties for the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore & Visuals (For Infocards)

| Asset Type | Visual & Lore Description |
| :--- | :--- |
| **"Open-Loop System"** | The baseline life support system. Consumes stored consumables (oxygen, water, filters) to maintain a breathable atmosphere. Simple and reliable, but its limited supply restricts mission duration, making it standard only on short-range vessels. Visually represented by storage tanks and basic filtration units within the cockpit pod. |
| **"Closed-Loop Recycler"** | An advanced life support system utilizing advanced recycling technology. It actively recycles air and water, drastically reducing consumable usage and significantly extending mission endurance. Requires more power and maintenance. Visually, it includes more complex machinery, algae tanks, or chemical scrubbers. |
| **"G-Stasis Cradle"** | Not an environmental system, but a critical pilot support mechanism integrated into the ship's core design. It mitigates extreme G-forces during high-performance maneuvers. Includes an Exo-Harness, Active Contour Bladders, Pressurized Breathing apparatus, and Neuro-Biological Support systems. Enables the use of specialized hulls like the "Trident" and "Tower". |

---

## 3. Part 2: Godot Implementation (Asset Stats)

Life Support systems will be defined as `Resource` files (e.g., `ClosedLoopRecycler.tres`) and managed by the `Asset System`. The `Asset System` will track `current_life_support_reserves`.

### Life Support `Resource` Properties

| Asset Type | `consumable_rate_per_tu` (float) | `power_draw_mw` (float) | `max_g_tolerance` (float) |
| :--- | :--- | :--- | :--- |
| **"Open-Loop"** | 0.1 (Example) | 0.1 | 5.0 (Baseline) |
| **"Closed-Loop"** | 0.01 (Reduced) | 0.5 | 5.0 (Baseline) |
| **"G-Stasis Cradle"** | 0.0 | 1.0 (Active) | 15.0+ (Enhanced) |

### Implementation Notes

* **`consumable_rate_per_tu`:** The `Time System`, upon advancing the `Time Clock`, will trigger the `Asset System` to deduct this amount from `current_life_support_reserves` (tracked in the `Inventory System`). Running out of reserves leads to mission failure or severe penalties.
* **`power_draw_mw`:** Closed-loop systems and the G-Stasis Cradle require power. Loss of power disables their benefits.
* **`max_g_tolerance`:** This stat interacts with the `Piloting Module`. If the ship's acceleration exceeds this value (possible with high-thrust engines or extreme maneuvers), the pilot suffers negative effects (e.g., temporary control loss, increased chance of `Action Check` failure). The G-Stasis Cradle drastically increases this threshold.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

For the TTRPG, life support impacts mission endurance abstractly, while the G-Stasis Cradle enables specific maneuvers or ship types.

### Analogue Asset Stats

| Asset Type | Asset Difficulty (Tech) | `WP` Cost | Special Rule |
| :--- | :--- | :--- | :--- |
| **"Open-Loop"** | **0** (Standard) | (Baseline) | **Limited Duration:** After **10 TU** away from a station, gain the "Low Supplies" status (e.g., `-1` to all `Action Checks`). |
| **"Closed-Loop"** | **+1** (Complex) | Medium | **Extended Duration:** Extends the "Low Supplies" threshold to **30 TU**. Requires power. |
| **"G-Stasis Cradle"** | **+1** (Integrated) | (Included in Hull) | **High-G Maneuvers:** Required to pilot "Trident" or "Tower" hulls. Allows `Act Risky` Piloting checks involving extreme acceleration without automatic penalty. |

### Analogue Rules

* **Endurance:** The choice of life support system dictates how long a player can operate independently before needing to resupply, measured in **Time Units (TU)**. Running low imposes penalties.
* **G-Stasis Enablement:** The Cradle is a prerequisite for certain hulls and high-risk piloting actions, reinforcing the lore.
* **Asset Difficulty (Tech):** Applies to `Action Checks` related to repairing the life support system.

--- Start of ./7.7-GDD-Assets-Radiation-Protection.md ---

# 7.7 GDTLancer - Radiation Protection

**Version:** 1.1
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `6.1-GDD-Lore-Background.md` (v1.7), `7.1-GDD-Assets-Ship-Design.md` (v2.3)

---

## 1. Overview

This document defines the asset configurations for shipboard radiation protection. Shielding against cosmic radiation and solar flares is crucial for pilot safety, especially during deep space travel or operation near hazardous phenomena.

This document follows the standard 3-part structure:
1.  **Lore & Visuals:** Descriptive text for in-game infocards.
2.  **Godot Implementation:** The `Resource` properties for the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore & Visuals (For Infocards)

| Asset Type | Visual & Lore Description |
| :--- | :--- |
| **"Baseline Hull Shielding"** | This represents the minimal radiation protection offered by standard ship construction materials (like Welded Steel). It is sufficient only for short-duration travel within relatively safe, charted space near habitats or major celestial bodies. It is not a distinct component, but an inherent property of basic hulls. |
| **"Dense Core Laminate"** | A significant upgrade involving heavy, layered armor with a dense material core (e.g., lead or depleted uranium analogues) integrated into the hull structure. It offers substantial protection against cosmic radiation and solar flares, making deep space travel viable, but at the cost of significantly increased mass. Visually, ships with this upgrade may appear bulkier or have thicker hull plating. |

---

## 3. Part 2: Godot Implementation (Asset Stats)

Radiation Protection levels will likely be integrated as properties directly within the Hull `Resource` files (See `7.3-GDTLancer-Ship-Chassis.md`), rather than separate swappable components. The `Asset System` will expose this value.

### Hull Radiation Protection Property (Example within Hull Resource)

| Property Name | Data Type | Description | Baseline Value | Dense Core Value |
| :--- | :--- | :--- | :--- | :--- |
| `radiation_shielding_factor` | `float` | Multiplier representing effectiveness (0.0 = none, 1.0 = perfect). | 0.2 | 0.8 |

### Implementation Notes

* **Radiation Zones:** Environmental zones in the game world will have a `radiation_level` property.
* **Exposure Calculation:** The `Asset System` or a dedicated "Pilot Health System" (future phase) will calculate radiation exposure over time based on the zone's `radiation_level` mitigated by the ship's `radiation_shielding_factor`.
* **Consequences:** High radiation exposure could lead to temporary penalties (e.g., reduced `Focus Points`), add negative `Ship Quirks` related to sensor interference, or trigger dangerous events.
* **Mass Penalty:** Hulls with "Dense Core Laminate" will have a significantly higher `Base Mass (t)`, impacting piloting performance.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

In the TTRPG, radiation protection primarily acts as a gate for certain types of travel or exploration and mitigates specific hazards.

### Analogue Asset Stats (Integrated into Hull Sheet)

| Protection Level | `WP` Cost Modifier | Special Rule |
| :--- | :--- | :--- |
| **"Baseline Shielding"** | (Standard Hull Cost) | **Hazard Vulnerability:** When traveling through a "Radiation Hazard" zone, automatically gain 1 `Heat Point` per `TU` spent in the zone. |
| **"Dense Core Laminate"** | +High WP Cost (Hull Upgrade) | **Deep Space Capable:** Immune to the automatic `Heat Point` gain from "Radiation Hazard" zones. Required for travel segments marked "Deep Space Route". |

### Analogue Rules

* **Environmental Hazards:** Specific map locations or travel segments can be marked as "Radiation Hazards." Baseline shielding imposes a constant penalty (representing system strain and pilot stress) when in these areas.
* **Deep Space Gating:** Dense Core Laminate is a prerequisite for attempting certain long-range or exploratory journeys, representing a significant investment managed through the `Asset Progression` system.
* **Event Mitigation:** Specific event outcomes from the `Module Event Booklets` (e.g., solar flare encounter) might have reduced severity or be ignored entirely if the ship has Dense Core Laminate.

--- Start of ./7.8-GDD-Assets-Turbomachinery.md ---

# 7.8 GDTLancer - Turbomachinery

**Version:** 1.1
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `7.2-GDD-Assets-Ship-Engines.md` (v1.4), `7.11-GDD-Assets-Propellant-Storage.md` (v1.0)

---

## 1. Overview

This document defines the asset configurations for shipboard turbomachinery, specifically the pumps used for moving propellants and coolants. While often integrated directly into engines or other systems, their quality significantly impacts overall ship efficiency and reliability.

This document follows the standard 3-part structure:
1.  **Lore & Visuals:** Descriptive text for in-game infocards.
2.  **Godot Implementation:** The `Resource` properties for the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore & Visuals (For Infocards)

| Asset Type | Visual & Lore Description |
| :--- | :--- |
| **"Standard Mechanical Pumps"** | The baseline technology for fluid transfer. These are heavy, durable, but relatively power-inefficient mechanical pumps. Reliable workhorses found on most standard vessels. Visually represented as robust, blocky pump housings integrated near engines and tanks. |
| **"Single-Crystal Blisk Turbopumps"** | Advanced, high-performance turbopumps representing a significant technological step. Fabricated from exotic single-crystal alloys, these pumps combine the turbine and bladed disk into a single component ("blisk"), offering extreme efficiency, low mass, and high durability. Complex and costly, usually found on high-end engines or specialized industrial equipment. Visually smaller, more refined, possibly with diagnostic indicators. |

---

## 3. Part 2: Godot Implementation (Asset Stats)

Turbopumps might be implemented as integrated properties within the Engine `Resource` files or potentially as swappable sub-components influencing engine performance.

### Example Properties (If Integrated into Engine Resource)

| Property Name | Data Type | Description | Standard Value | Blisk Value |
| :--- | :--- | :--- | :--- | :--- |
| `pump_efficiency_modifier` | `float` | Multiplier affecting fuel consumption or thrust output. | 1.0 | 1.1 (Example) |
| `pump_power_draw_mw` | `float` | Base power draw for pump operation. | 0.2 | 0.1 (More efficient) |
| `pump_reliability_factor` | `float` | Base chance modifier for pump-related failures/quirks. | 1.0 | 0.8 (More reliable) |

### Implementation Notes

* **Performance Impact:** Higher `pump_efficiency_modifier` could slightly increase the effective `acceleration` or decrease fuel consumption calculated by the `Asset System`.
* **Power Draw:** Contributes to the ship's overall power budget. Blisk pumps are more power-efficient.
* **Reliability:** The `pump_reliability_factor` influences the chance of failure events or gaining related "Ship Quirks" during stressful situations (e.g., combat damage, critical failures on `Action Checks`).

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

In the TTRPG, pump quality is abstracted into reliability and efficiency modifiers.

### Analogue Asset Stats (Likely Integrated into Engine Sheet)

| Pump Type | Asset Difficulty (Tech) | `WP` Cost Modifier | Special Rule |
| :--- | :--- | :--- | :--- |
| **"Standard Mechanical"** | **0** (Standard) | (Baseline Engine Cost) | Standard performance and reliability. |
| **"Single-Crystal Blisk"** | **+1** (Advanced) | +Medium WP (Engine Upgrade) | **Enhanced Efficiency:** Gain `+1` Endurance segment. **Reliable:** Ignore the first pump-related "Ship Quirk" gained. |

### Analogue Rules

* **Efficiency Bonus:** Blisk pumps directly improve the engine's core **Endurance** stat, representing better fuel management.
* **Reliability Bonus:** They provide resilience against specific types of failures or negative traits acquired through gameplay, reducing downtime or repair costs (`WP`).
* **Asset Difficulty (Tech):** Applies to `Action Checks` related to repairing the pumps or engine systems. Advanced Blisk pumps might be harder to fix in the field.

--- Start of ./7.9-GDD-Assets-Utility-Tools.md ---

# 7.9 GDTLancer - Utility Tools

**Version:** 1.2
**Date:** October 31, 2025
**Related Documents:** `0.1-GDD-Main.md` (v1.9), `1-GDD-Core-Mechanics.md` (v1.6), `1.1-GDD-Core-Systems.md` (v1.5), `3-GDD-Architecture-Coding.md` (v1.8), `4.1-GDD-Analogue-Setup.md` (v1.4), `5.2-GDD-Module-Combat.md` (v1.7), `6.1-GDD-Lore-Background.md` (v1.7), `7.1-GDD-Assets-Ship-Design.md` (v2.3), `7.3-GDD-Assets-Ship-Chassis.md` (v1.2), `7.4-GDD-Assets-Power-Plants.md` (v1.1)

---

## 1. Overview

This document defines the asset configurations for external hardpoint-mounted utility tools. These tools often serve dual purposes for both industry (mining, salvage) and combat, which is a core tenet of the **Preservation Convention**.

The specific tools available are the primary distinguishing feature for specialized hull classes like the "Catamaran" and "Tower".

**Design Note on Combat:** Per `5.2-GDD-Module-Combat.md`, these tools are the primary means of offense. There are **no energy shields**; combat is a "hard sci-fi" affair focused on disabling systems and overcoming hull integrity. These tools enable that specific gameplay.

This document follows the standard 3-part structure:
1.  **Lore & Visuals:** Descriptive text for in-game infocards.
2.  **Godot Implementation:** The `Resource` properties for the `Asset System`.
3.  **Analogue Implementation:** The abstracted rules for the tabletop TTRPG asset sheets.

---

## 2. Part 1: Lore & Visuals (For Infocards)

| Asset Type | Visual & Lore Description |
| :--- | :--- |
| **"Rotary Mining Drill"** | A heavy-duty industrial drill designed for precision ore extraction from asteroids. Per the Preservation Convention, it doubles as a close-range tool for **breaching ship hulls** in a controlled manner. A key tool for "Tower" hulls. |
| **"Reinforced Prow"** | A structural modification that adds a reinforced "hard place" to the ship's bow. It is designed for controlled, high-thrust interactions (like pushing large salvage objects) rather than high-speed impacts. Its combat application is for **breaching, pinning, or bulldozing** disabled targets. |
| **"High-Power Ablative Laser"** | A high-draw energy tool. Its industrial use is to skim trace elements from asteroid surfaces. In combat, it is used to strip enemy armor or disable external systems without destroying the hull. Requires a **Fission Reactor**, common on "Trident" and "Tower" hulls. |
| **"Seismic Charge Launcher"** | A launcher that fires expensive, consumable charges for the controlled demolition of asteroids. In combat, these low-velocity charges can be used to target specific ship subsystems. |
| **"Harpoon & Winch Array"** | A recoverable projectile system. Industrially, it tethers asteroids for mining or towing. In combat, it is the primary tool for the "Broadside Grappler" tactic, allowing a "Tower" hull to tether and control a target. |
| **"Forward-Facing Debris Scoop"** | A massive, reinforced collector designed for actively scooping fragments from wreckage or fractured asteroids. It is an oversized module, requiring a specialized "Catamaran" hull to mount. |

---

## 3. Part 2: Godot Implementation (Asset Stats)

Utility Tools will be defined as `Resource` files (e.g., `RotaryDrill.tres`) and managed by the `Asset System`. These assets will be activated by the player and their logic handled by the relevant module (e.g., `Combat Module` or a future Mining module).

### Tool `Resource` Properties

| Asset Type | `power_draw_mw` (float) | `damage` (int) | `consumable_item_id` (String) | `slot_type` (String) |
| :--- | :--- | :--- | :--- | :--- |
| Rotary Drill | 1.0 | 50 (Breach) | "None" | "Broadside" |
| Reinforced Prow | 0.0 | 40 (Thrust/Impact)| "None" | "Structural" |
| Ablative Laser | 15.0 | 20 (Energy) | "None" | "High-Power" |
| Seismic Charge Launcher | 0.5 | 100 (Explosive) | "SeismicCharge" | "Standard" |
| Harpoon & Winch | 2.0 | 5 (Kinetic) | "None" | "Broadside" |
| Debris Scoop | 1.0 | 0 | "None" | "Oversized" |

### Implementation Notes

* **`power_draw_mw`:** The power required from the ship's Power Plant when the tool is active. The `Asset System` tracks this against the plant's output. The "Ablative Laser" has a very high draw, requiring a "Fission Reactor".
* **`damage`:** The base damage value used by the `Combat Module`. The "Harpoon" does minimal damage; its utility is in tethering.
* **`consumable_item_id`:** The item ID that is consumed from the `Inventory System` on use (e.g., for the Seismic Launcher).
* **`slot_type`:** Defines which hull hardpoints can mount this tool, aligning with the "Slots" defined in `7.3-GDD-Assets-Ship-Chassis.md`.

---

## 4. Part 3: Analogue TTRPG Implementation (For Asset Sheets)

For the TTRPG, tools grant new `Action Check` options or provide modifiers to existing ones.

### Analogue Asset Stats

| Asset Type | Asset Difficulty (Skill) | `WP` Cost (Est.) | Special Rule |
| :--- | :--- | :--- | :--- |
| Rotary Drill | **+2** (Tech/Pilot) | Medium | Grants the **"Breach Hull"** `Action Check` in close-quarters. On a `Success` (10+), deals direct Hull damage. |
| Reinforced Prow | **+1** (Piloting) | Low | Grants the **"Bulldoze / Pin"** `Act Risky` option. On a `Success` (10+), deals damage and pins the target; on a `Failure` (<10), you also take damage or lose position. |
| Ablative Laser | **+1** (Tech) | High | Requires 1 `Power Slot`. Can be used to `Act Cautiously` to add a **"Ship Quirk"** to a target instead of dealing damage. |
| Seismic Charge Launcher | **+1** (Tech) | Low (Consumable) | Firing consumes `1 WP` (or a "Seismic Charge" item). Has a high chance to add a **"Ship Quirk"**. |
| Harpoon & Winch | **+1** (Piloting) | Medium | Grants the **"Grapple Target"** `Action Check`. On a `Success` (10+), the target cannot flee. A key tool for "Tower" hulls. |
| Debris Scoop | **0** (Standard) | Medium | Requires a "Catamaran" hull. Grants a `+2` `Module Modifier` to all salvage-related `Action Checks` (e.g., "Claim Wreckage"). |

### Analogue Rules

* **Asset Difficulty:** This modifier applies to any `Action Check` made *using* that specific tool (e.g., a "Piloting" check to pin, a "Tech" check to operate the laser).
* **Special Rule:** Defines the tool's unique mechanical function within the TTRPG's abstract systems.

--- Start of ./7-GDD-Assets-Style.md ---

# GDTLancer - General Asset & Style Guide

**Version:** 1.1
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 6.1-GDD-Lore-Background.md (v1.7), 7.1-GDD-Assets-Ship-Design.md (v1.4)

## 1. Overview & Core Philosophy

This document defines the overarching artistic, audio, and user interface style for all assets in GDTLancer. The goal is to create a cohesive and distinct identity that reinforces the game's core themes of pragmatism, function-first design, and a unique "Neo-Retro" aesthetic.

* **Neo-Retro 3D:** The primary visual style is inspired by the limitations and aesthetics of early 3D graphics (mid-to-late 1990s), but executed with modern rendering techniques like dynamic lighting and shaders. This is not a pixel-perfect retro emulation, but an interpretation of that style.
* **Pragmatic Aesthetics:** Form always follows function. Every element in the game world, from a ship's hull to a UI button, should look like it was designed for a purpose, not for decoration. This reflects the utilitarian culture of the sector.

## 2. Visual Style

### 2.1. 3D Models & Texturing
* **Geometry:** Models must be medium-low-poly with clean, hard edges. Beveling should be used sparingly to catch light, but complex, smooth curves and subdivision surfaces are to be avoided. The silhouette should be clear and readable.
* **Texturing:** Photorealistic textures are forbidden. Surfaces should primarily use flat colors, simple gradients, or subtle, procedurally generated noise patterns. Textures should define material type (e.g., matte metal, rubberized composite) rather than intricate surface detail.
* **Wear and Tear:** Details like scratches, weld lines, and patch repairs should be added as simple decals or vertex color variations, not complex, high-resolution texture maps. The goal is to suggest a history of use, not to simulate realistic decay.

### 2.2. Environments
* **Space:** The void of space should be dark and minimalist. The sense of scale and movement is conveyed through simple, billboard-style star sprites and multi-layered dust particle effects.
* **Nebulae & Phenomena:** Large environmental features like nebulae should be stylized, using simple geometry with volumetric shaders or layered, transparent sprites rather than photorealistic clouds.
* **Structures:** Stations and habitats follow the same pragmatic design as ships: functional, modular, and often asymmetrical. Lighting is utilitarian, used for navigation, docking bays, and warning signals.

### 2.3. UI / UX
* **Philosophy:** The UI is a functional tool, not a decorative overlay. It must be clean, non-intrusive, and highly readable.
* **Layout:** Use a grid-based layout with clear information hierarchy. Group related elements logically.
* **Visuals:** Elements should be composed of simple, 2D vector-style lines and shapes. Buttons are functional rectangles or squares. Icons are simple and symbolic.
* **Typography:** Use a clean, sans-serif font (like Roboto Condensed) for all text to ensure maximum readability.
* **Color Palette:** The UI uses a mostly monochromatic palette (dark backgrounds, light grey or off-white text). Bright, saturated colors (cyan, yellow, red) are used exclusively for highlights, alerts, and critical information to draw the player's attention.

## 3. Audio Style

### 3.1. Sound Effects (SFX)
* **Philosophy:** Sounds are functional feedback. They should be clear, distinct, and immediately communicate what is happening.
* **Style:** SFX should have a slightly synthesized, "lo-fi" quality to match the neo-retro aesthetic. Avoid cinematic, high-fidelity explosions and impacts. Think more of the satisfying "thunks," "beeps," and "hums" of classic sci-fi. Thruster sounds should be a low, functional rumble, not a dramatic roar.

### 3.2. Music
* **Philosophy:** Music provides atmosphere, not overt emotional direction. It should support the feeling of isolation and pragmatic work in space.
* **Style:** The soundtrack should be minimalist and ambient. Expect long, evolving synthesizer pads, simple arpeggios, and a generally low-key, atmospheric tone. Music should swell subtly during moments of tension (like combat) but should not become an epic, orchestral score.

--- Start of ./AI-ACKNOWLEDGEMENT.md ---

## Acknowledgement of AI Assistance

This project utilizes generative AI technologies as a tool to enhance developer productivity during its development. The core functionality, architecture, and final decisions remain the product of human engineering and review.

**Scope of AI Use:**

* **Code Generation and Refinement:** AI assistance was used to generate, refactor, and optimize code snippets.
* **Documentation:** AI tools assisted in drafting, structuring, summarizing, and refining project documentation (such as README files, guides, code comments, and API documentation). While AI provided initial drafts or suggestions, the final documentation content has been reviewed and edited by the development team for accuracy and clarity.
* **Exclusion of Embedded Assets:** No AI-generated creative assets (e.g., images, audio, user-interface text intended for direct display *within* the application) are incorporated into the production version of this software.
* **Repository Artefacts:** Any other AI-generated assets potentially present in the repository were either:
    * Used as temporary placeholders during development and have since been removed or replaced, or
    * Created prior to the formalization of this acknowledgement and are not intended for production use or distribution.
* **Models and Data:** All AI models used were either publicly available or trained exclusively on permissively licensed data.

**Human Oversight:**

All AI-generated contributions, whether code or documentation, are subject to human review, modification, and approval before being integrated into the project. The ultimate responsibility for the software and its documentation lies with the human development team.

**Licensing:**

This project is licensed under the [GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.en.html).

**Note:** The use of the GPLv3 license predates the integration of AI development tools into this project's workflow.

--- Start of ./AI-PRIMING.md ---

# GDTLancer AI Collaboration Priming Prompt

**Version:** 1.3
**Date:** October 31, 2025
**Related Documents:** 0.1-GDD-Main.md (v1.9), 3-GDD-Architecture-Coding.md (v1.8)

## 1. Purpose

This document defines the standard priming prompt to be used when initiating a new chat session with an AI assistant for the development of GDTLancer. Its purpose is to clearly establish the project context, the expected collaborative paradigm, defined roles, and the iterative workflow, ensuring efficient and targeted AI assistance aligned with the project's goals and standards.

## 2. Standard Priming Prompt Text

*(Use the following text block as the initial prompt in a new AI chat session dedicated to GDTLancer development.)*

---

For Gemini,

This chat session is dedicated to the collaborative development of a game project, **GDTLancer**.

### 2.1. Project Overview

GDTLancer is a multi-platform space adventure RPG being built in Godot Engine 3. The core vision involves blending sandbox simulation with TTRPG-inspired emergent narrative mechanics to create a living, dynamic universe. My immediate focus is on developing a robust and well-structured game framework, which I can later fill with specific content and assets, similar to modding an existing game.

### 2.2. Provided Context & Source of Truth

Shortly, I will upload several text files containing the project's context. These will include:
* The combined Game Design Documents (`GDD-COMBINED-TEXT.md`).
* A text dump of the current project file/directory structure (`.PROJECT_DUMP_TEXT_ENHANCED_TREE.txt`).
* Text dumps of the existing GDScript code (`.PROJECT_DUMP_TEXT_GD.txt`), resource files (`.PROJECT_DUMP_TEXT_TRES.txt`), and scene structures (`.PROJECT_DUMP_TEXT_TSCN.txt`).

**Critical Note on Source of Truth:** The text dumps of the project files (`.PROJECT_DUMP_...`) are your **primary source of truth**. You must always prioritize them to understand the current state of the project.
* Refer to the GDDs *only when we need to implement new features or for high-level planning*.
* The GDDs may contain contradictions or outdated information; always default to the project files and prioritize sound project structure, logic, and data organization.
* You must **always** refer to and respect the `3-GDD-Architecture-Coding.md` file for all coding standards and architectural patterns.

### 2.3. Our Collaboration Paradigm & Roles

We will work together in a specific way:
* **My Role (User):** I will act as the project architect and director. I will focus on the high-level picture, define goals, provide guidance, validate your suggestions against the overall design, and make final decisions.
* **Your Role (Gemini):** You are my implementation assistant. Your primary responsibilities are:
    * Suggesting concrete implementation approaches and code structures.
    * Drafting initial versions of GDScript functions, classes, or entire system scripts based on my goals.
    * **Adhering strictly to the project's established architecture.** This includes coding standards, modularity, and especially the project's core data-logic separation pattern: **stateless systems** (nodes in `core/systems/`) that provide APIs to modify the central **`GameState` autoload**. Use established patterns (e.g., `EventBus`, `GlobalRefs`, Resources) and avoid creating redundant code or duplicating existing functionality.
    * Explaining drafted code and suggesting refinements.
    * Helping identify potential issues or inconsistencies.

### 2.4. Workflow & Key Constraints

Our workflow will be iterative:
1.  I will state a high-level goal (e.g., "Implement the basics of the Character System").
2.  You will analyze the existing project files and suggest an approach and/or draft the initial code.
3.  I will review, ask questions, and provide feedback.
4.  We will refine the code together.

**Key Architectural Constraints:**
* **File and Naming Conventions:** You must adhere to the existing folder structure, file naming conventions, and code formatting found in the project text dumps.
* **`EventBus` vs. `EventSystem`:** Do not alter `EventBus.gd` (in `autoload/`). It is for managing engine-level signals and is managed manually. For in-game events (e.g., ambush, world tick), we will use the `event_system.gd` script (in `core/systems/`), which acts as a narrative oracle.
* **No Canvas Feature:** Do not use the Canvas feature for our collaboration. All discussion and code drafting will occur in the main chat.

---

Please confirm you understand this collaborative approach and are ready to begin once I've uploaded the context files.

--- End of Priming Prompt Text ---

--- Start of ./README.md ---

# GDTLancer Game Design Documentation

![Banner](./Banner.png)

This repository contains the Game Design Documentation (GDD) for **GDTLancer: Generative Dynamic Transmedia Lancer**.

GDTLancer is envisioned as a multi-platform space adventure RPG blending sandbox simulation with TTRPG-inspired emergent narrative mechanics. It aims to create a living world shaped by the actions of both the player and AI agents, with a distinct neo-retro visual style and a focus on player agency in choosing their approach to risk and narrative engagement.

The main repository for the game project itself can be found at:
[https://github.com/roalyr/GDTLancer](https://github.com/roalyr/GDTLancer)

---

## Documentation Pages

This documentation is organized into several key areas:

### 0. Core Vision & Introduction

* [**0.0-GDD-Internal-Rules-Conventions.md**](./0.0-GDD-Internal-Rules-Conventions.md): Defines the structure, numeration, and standard page format for the GDD. (New: v1.0, 2025-10-26)
* [**0.1-GDD-Main.md**](./0.1-GDD-Main.md): The central Game Design Document outlining the overall vision, game pillars, development framework (Layers, Modules, Systems), phased plan, and summaries of core concepts. (Reviewed: v1.9, 2025-10-31)
* [**0.2-GDD-Main-Sayings.md**](./0.2-GDD-Main-Sayings.md): Lists key mottos for the game's branding and ethos, alongside in-game lore-wise sayings. (Reviewed: v1.5, 2025-10-31)

### 1. Core Systems & Mechanics

* [**1-GDD-Core-Mechanics.md**](./1-GDD-Core-Mechanics.md): Details the fundamental, universal mechanics: the **Action Check** (3d6+Mod resolution), **Focus Points (FP)**, and the **Action Approach** system (`Act Risky`/`Act Cautiously`). (Reviewed: v1.6, 2025-10-31)
* [**1.1-GDD-Core-Systems.md**](./1.1-GDD-Core-Systems.md): Defines the cross-cutting gameplay systems required for Phase 1, including the `Event System`, `Time System`, `Character System`, `Inventory System`, and `Asset System`, and their relation to `GameState.gd`. (Reviewed: v1.5, 2025-10-31)
* [**1.2-GDD-Core-Cellular-Automata.md**](./1.2-GDD-Core-Cellular-Automata.md): Outlines the philosophy and catalogue of Cellular Automata implementations used to drive the living world and emergent narrative systems. (Reviewed: v1.2, 2025-10-31)

### 2. Development Planning

* [**2-GDD-Development-Challenges.md**](./2-GDD-Development-Challenges.md): Identifies and acknowledges the primary challenges and inherent risks associated with the development of GDTLancer. (Reviewed: v1.4, 2025-10-31)
* [**2.1-GDD-Development-Phase1-Scope.md**](./2.1-GDD-Development-Phase1-Scope.md): The master document for the Phase 1 "First Contract" demo, defining the core player experience, included components, content requirements, and development milestones. (Reviewed: v1.3, 2025-10-31)

### 3. Development Architecture

* [**3-GDD-Architecture-Coding.md**](./3-GDD-Architecture-Coding.md): Outlines the coding style conventions, architectural patterns (including the stateless `GameState` model), and development philosophy for the Godot implementation. (Reviewed: v1.8, 2025-10-31)

### 4. Analogue Version

* [**4.1-GDD-Analogue-Setup.md**](./4.1-GDD-Analogue-Setup.md): Describes the recommended physical components and general organization for playing the tabletop RPG version. (Reviewed: v1.4, 2025-10-31)
* [**4.2-GDD-Analogue-Setup-Formatting.md**](./4.2-GDD-Analogue-Setup-Formatting.md): Specifies the detailed layout, content areas, and formatting for the physical sheets used in the analogue version. (Reviewed: v1.3, 2025-10-31)
* [**4.3-GDD-Analogue-Phase1-Scope.md**](./4.3-GDD-Analogue-Phase1-Scope.md): The master document for the Phase 1 Analogue "Quickstart PDF", defining its vision, required components, and development milestones. (Reviewed: v1.3, 2025-10-31)

### 5. Gameplay Modules

* [**5.1-GDD-Module-Piloting.md**](./5.1-GDD-Module-Piloting.md): Specific design details for the Piloting & Travel gameplay module, covering `Free Flight`, `Flight Challenges`, and `Narrative Actions`. (Reviewed: v1.9, 2025-10-31)
* [**5.2-GDD-Module-Combat.md**](./5.2-GDD-Module-Combat.md): Details the mechanics for ship-to-ship conflict, including `Combat Challenges` and post-battle `Narrative Actions`, adhering to the Preservation Convention. (Reviewed: v1.7, 2025-10-31)
* [**5.3-GDD-Module-Trading.md**](./5.3-GDD-Module-Trading.md): Details the mechanics for the economic loop, including the `Trade Interface` and trading-related `Narrative Actions`. (Reviewed: v1.3, 2025-10-31)

### 6. Lore & Player Experience

* [**6-GDD-Lore-Narrative-Borders.md**](./6-GDD-Lore-Narrative-Borders.md): Defines the thematic and narrative constraints that guide the game's simulation to ensure setting-adherence. (Reviewed: v1.2, 2025-10-31)
* [**6.1-GDD-Lore-Background.md**](./6.1-GDD-Lore-Background.md): Outlines the foundational setting premise (early colonists), pragmatic culture, Preservation Convention, and core technology. (Reviewed: v1.7, 2025-10-31)
* [**6.2-GDD-Lore-Player-Onboarding.md**](./6.2-GDD-Lore-Player-Onboarding.md): Details the "First Contract" tutorial scenario for introducing players to core mechanics and the setting. (Reviewed: v1.3, 2025-10-31)

### 7. Assets and Style

* [**7-GDD-Assets-Style.md**](./7-GDD-Assets-Style.md): Defines the core "Neo-Retro 3D" style for all game assets, including models, environments, UI, and audio. (Reviewed: v1.1, 2025-10-31)
* [**7.1-GDD-Assets-Ship-Design.md**](./7.1-GDD-Assets-Ship-Design.md): Defines the core design principles and technology palette for ships. (Reviewed: v2.3, 2025-10-31)
* [**7.2-GDD-Assets-Ship-Engines.md**](./7.2-GDD-Assets-Ship-Engines.md): Details the specific configurations, stats, and lore for ship engines. (Reviewed: v1.4, 2025-10-31)
* [**7.3-GDD-Assets-Ship-Chassis.md**](./7.3-GDD-Assets-Ship-Chassis.md): Details the specific configurations, stats, and lore for ship hulls/chassis. (Reviewed: v1.2, 2025-10-31)
* [**7.4-GDD-Assets-Power-Plants.md**](./7.4-GDD-Assets-Power-Plants.md): Details ship power generation assets. (Reviewed: v1.1, 2025-10-31)
* [**7.5-GDD-Assets-Cooling-Systems.md**](./7.5-GDD-Assets-Cooling-Systems.md): Details ship heat management assets. (Reviewed: v1.1, 2025-10-31)
* [**7.6-GDD-Assets-Life-Support.md**](./7.6-GDD-Assets-Life-Support.md): Details pilot life support and G-Stasis assets. (Reviewed: v1.1, 2025-10-31)
* [**7.7-GDD-Assets-Radiation-Protection.md**](./7.7-GDD-Assets-Radiation-Protection.md): Details hull radiation shielding levels. (Reviewed: v1.1, 2025-10-31)
* [**7.8-GDD-Assets-Turbomachinery.md**](./7.8-GDD-Assets-Turbomachinery.md): Details propellant and coolant pump assets. (Reviewed: v1.1, 2025-10-31)
* [**7.9-GDD-Assets-Utility-Tools.md**](./7.9-GDD-Assets-Utility-Tools.md): Details external hardpoint tools for industry and combat. (Reviewed: v1.2, 2025-10-31)
* [**7.10-GDD-Assets-Energy-Storage.md**](./7.10-GDD-Assets-Energy-Storage.md): Details battery and capacitor assets. (Reviewed: v1.1, 2025-10-31)
* [**7.11-GDD-Assets-Propellant-Storage.md**](./7.11-GDD-Assets-Propellant-Storage.md): Details liquid/cryogenic propellant tank assets. (Reviewed: v1.1, 2025-10-31)

### Meta & Legal

* [**LICENSE**](./LICENSE): Contains the licensing information for this documentation project.
* [**AI-ACKNOWLEDGEMENT.md**](./AI-ACKNOWLEDGEMENT.md): Details regarding the use of AI assistance during the generation and refinement of this documentation.
* [**AI-PRIMING.md**](./AI-PRIMING.md): Defines the standard priming prompt to be used when initiating a new chat session with an AI assistant. (Reviewed: v1.3, 2025-10-31)

## All pages in a single file

* [**GDD-COMBINED-TEXT.md**](./GDD-COMBINED-TEXT.md): Contains a consolidated version of all documentation pages.

---

This documentation is a living project and currently under active development.
