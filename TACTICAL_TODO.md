<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; MODEL-CASCADE-PROTOCOL.md § Role: Lead Systems Architect
LOG_REF: 2026-06-10 23:13:00
-->

## CURRENT GOAL: NPC Persistent Instantiation and Character State Linking
- TARGET_SCOPE: Resolve the pending TODO in `agent_system.gd` to ensure all spawned NPCs are properly backed by a `CharacterTemplate` in `GameState.characters` and an inventory via `InventorySystem`. If an NPC is spawned without a valid `character_uid`, generate a character sheet from the `character_template_id` specified in the `AgentTemplate`, link it, and initialize its credits and assets.
- TARGET_FILES:
  - src/core/systems/agent_system.gd — Add logic to create and link characters and inventories during NPC spawn.
  - src/core/systems/character_system.gd — Expose a helper to generate a default character sheet.
  - src/tests/core/systems/test_persistent_agents.gd — Add assertions to verify that spawned NPCs have valid character and inventory data.
- TRUTH_RELIANCE: TRUTH_SIMULATION-GRAPH.md §2.3; TRUTH_CONTENT-CREATION-MANUAL.md §3.6
- TECHNICAL_CONSTRAINTS: "Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"
- ATOMIC_TASKS:
  - [x] TASK_1: In `character_system.gd`, add a `create_character(template_id: String) -> int` helper that reads the template from `TemplateDatabase.characters`, generates a new `CharacterTemplate` instance, assigns it a unique UID, populates initial credits and focus points based on the template, stores it in `GameState.characters`, and returns the UID.
  - [x] TASK_2: In `agent_system.gd`, update `spawn_agent` and `spawn_npc_from_template` so that if `character_uid` is -1 or missing, it calls `GlobalRefs.character_system.create_character(agent_template.character_template_id)` to generate one. Assign this UID to the NPC overrides and link it to the agent instance.
  - [x] TASK_3: In `agent_system.gd` after creating the character, call `GlobalRefs.inventory_system.create_inventory_for_character(character_uid)` to ensure the NPC has a valid container for assets and cargo.
  - [x] VERIFICATION: Run tests in `test_persistent_agents.gd` and `test_agent_spawner.gd` (if it exists) to ensure NPCs successfully generate with linked characters and inventories without crashing.
