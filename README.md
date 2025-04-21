## Draft README for Main Game Repository (`roalyr/GDTLancer`)

# GDTLancer: Generative Dynamic Transmedia Lancer

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**GDTLancer** is a multi-platform space adventure RPG combining sandbox simulation with TTRPG-inspired emergent narrative mechanics. Explore a living, dynamic universe where your actions, and those of AI agents, shape the course of history.

This project aims to create a unique experience blending the freedom of classic space sims with the deep, player-driven stories found in tabletop roleplaying games, all presented in a distinct neo-retro 3D visual style.

**Current Status:** Undergoing refactoring.

### Core Concepts & Features (Based on Design):

* **Living Universe:** A persistent world simulated dynamically, where NPC agents pursue their own goals using the same core mechanics as the player, influencing factions, economies, and discoveries.
* **Emergent Narrative:** Stories evolve organically from the interplay of game systems, agent actions, and generated events, rather than following rigid plots.
* **Hybrid Gameplay:** Engage in direct simulation gameplay (piloting, combat, trading) within distinct **Gameplay Modules**. High-stakes actions are resolved via an **Action Check** (3d6+Modifier), influenced by **Focus Points (FP)**.
* **Player Agency:** Choose your level of engagement – focus on simulation modules or narrative systems. Manage risk by declaring an **Action Approach** (`Act Risky` or `Act Cautiously`) for key actions, influencing potential outcomes. Set long-term goals via the Goal System.
* **Transmedia Vision:** Planned versions include:
    * Primary PC/Mobile build (Godot Engine 3).
    * Simplified J2ME version (turn-based, wireframe).
    * Analogue Tabletop RPG ruleset.
* **Neo-Retro Aesthetics:** Distinctive visual style using minimalist 3D, hard edges, solid colors, and stylized lighting.
* **Chronicle System:** Uncover the generated history of the world through an in-game interface logging significant player and NPC actions.

### Design Documentation

The detailed design principles, mechanics, and development plan for GDTLancer reside in its dedicated documentation repository:
**[GDTLancer Game Design Documentation](https://github.com/roalyr/GDTLancer-game-design)**

### Technology

* Primary Engine: **Godot Engine 3**

### License

This project (the Godot 3 implementation source code and associated assets within this repository) is intended to be licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**. Please see the LICENSE file in the repository root for the full license text once added.

* The J2ME version will also use GPLv3.
* The Analogue TTRPG version materials, developed in a separate repository, are intended to be licensed under Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0).

### Contributions

* Currently solo development.
