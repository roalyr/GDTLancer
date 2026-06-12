<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; MODEL-CASCADE-PROTOCOL.md § Role: Lead Systems Architect; GDD-REVISION-LEDGER.md REV_009
LOG_REF: 2026-06-12 01:10:00
-->

## CURRENT GOAL: Generic Interaction Window for In-Scene Objects

- TARGET_SCOPE: Implement a generic `InteractionWindow` Control scene that opens when the player interacts with any in-scene object (NPC agents or celestial bodies). For NPC targets, the window shows a "Trade" button; pressing it opens the existing `NpcTradePanel` if the NPC is tradeable, or shows a verbose feedback message if trade is not possible. For celestial bodies, the window shows a placeholder "No interactions available yet" message. The window is owned and instanced by `main_hud.gd` alongside existing sub-screens. The existing `player_npc_interact_requested` EventBus signal is repurposed as the trigger to open this window (replacing the current direct-open-NpcTradePanel flow in `npc_trade_panel.gd`). The `NpcTradePanel` is now opened exclusively from within the `InteractionWindow`, not directly from the EventBus signal.

- TARGET_FILES:
  - `scenes/ui/menus/interaction_window/InteractionWindow.tscn` — New scene: generic interaction window control node.
  - `src/core/ui/interaction_window/interaction_window.gd` — New script: drives context-aware button population and delegates to NpcTradePanel for trade.
  - `scenes/ui/menus/npc_trade_panel/NpcTradePanel.tscn` — Existing: no structural changes; its trigger pathway changes (see TASK_3).
  - `src/core/ui/npc_trade_panel/npc_trade_panel.gd` — Existing: disconnect EventBus `player_npc_interact_requested`; add a public `open_for_agent(agent_id, target_node)` method callable by InteractionWindow.
  - `src/core/ui/main_hud/main_hud.gd` — Existing: instance `InteractionWindow`, connect `player_npc_interact_requested` to open the InteractionWindow (not NpcTradePanel directly).

- TRUTH_RELIANCE: TRUTH_PROJECT.md § Agent Parity Principle; GDD-REVISION-LEDGER.md REV_009; player_npc_interaction_architecture.md § Interaction UI.

- TECHNICAL_CONSTRAINTS: "Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"

- OUT_OF_SCOPE: Celestial body interaction logic (buttons beyond a placeholder label), distance gating for interact, new EventBus signals, changes to station menu or dock flow, visual/style polish.

- PREAPPROVED_ADJACENT_OWNERS:
  - `src/modules/piloting/player_controller_ship.gd` — Bug fix: incorrect agent_id type (int vs string) used for GameState.agents lookup; required to make interact signal carry correct key.

- VALIDATION_PLAN:
  - All 404 existing GUT tests must continue to pass.

- MANUAL_VALIDATION: Open game in Godot editor, fly to an NPC, press Interact — InteractionWindow must appear showing NPC name/role and a Trade button. Pressing Trade opens NpcTradePanel. Close and re-target a celestial — InteractionWindow opens showing a "No interactions available" label.

- ATOMIC_TASKS:
  - [x] TASK_1: Create `src/core/ui/interaction_window/interaction_window.gd`.
  - [x] TASK_2: Create `scenes/ui/menus/interaction_window/InteractionWindow.tscn`.
  - [x] TASK_3: Modify `src/core/ui/npc_trade_panel/npc_trade_panel.gd` — remove EventBus self-trigger; add `open_for_agent()`; fix `character_uid` resolution from `persistent_agents`; fix `tags` → `dynamic_tags` bug.
  - [x] TASK_4: Modify `src/core/ui/main_hud/main_hud.gd` — instance InteractionWindow, wire signal, add handler.
  - [x] BUGFIX: Fix `player_controller_ship.gd` — use `template_id` (string) instead of `agent_uid` (int) for `GameState.agents` lookup. Use `_resolve_agent_id()` helper. Emit `player_npc_interact_requested` for all agent_body and celestial targets (InteractionWindow gates internally).
  - [x] VERIFICATION: Debugged target-selection and group checks. NPC target now supports both "Agents" and "agent_body" groups, and celestials are properly identified via group/naming fallbacks. Non-RigidBody selections (like StaticBody stars/planets/moons) are now directly supported for interaction.
