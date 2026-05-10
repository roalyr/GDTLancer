## CURRENT GOAL: HUD-Projected Jump Route Targeting
- TARGET_FILES:
  - src/core/ui/main_hud/main_hud.gd
  - scenes/ui/hud/main_hud.tscn
  - src/modules/piloting/player_controller_ship.gd
  - src/core/targeting/route_target.gd
  - src/core/targeting/route_target_provider.gd
  - src/scenes/game_world/world_manager.gd
  - src/core/systems/agent_system.gd
  - src/core/systems/sector_loader.gd
- TRUTH_RELIANCE: TRUTH_PROJECT.md, TRUTH_CONSTRAINTS.md §1, TRUTH_SIMULATION-GRAPH.md §2.1 and §3.3, TRUTH_CONTENT-CREATION-MANUAL.md §3.4 and §6
- TECHNICAL_CONSTRAINTS:
  - Platform (primary): Godot3 (3.6 stable)
  - Graphics: GLES2 (CanvasItem/Control-safe HUD projection only)
  - Interaction rule: jump selection must remain on the existing Interact action path
  - Compatibility rule: keep current station/ship world targeting working while route targets migrate to HUD projection
- ATOMIC_TASKS:
  - [x] TASK_1: Store route-based arrival metadata and spawn the player from the inbound vector instead of reverse JumpPoint lookup.
    - Required signatures: preserve `WorldManager.travel_to_sector(target_sector_id)`, `GameState.current_sector_id`, `EventBus.player_jump_requested`, and `AgentSystem.spawn_player()`.
    - Store `GameState.player_arrival_direction` from topology-derived sector positions and spawn at `Constants.SECTOR_JUMP_ARRIVAL_RADIUS`.
    - Do not require a destination JumpPoint node to compute arrival placement.

  - [x] TASK_2: Add logical jump-route targets plus HUD-projected route brackets that feed the existing target-selection and interact flow.
    - Required signatures: preserve `EventBus.player_target_selected`, `EventBus.player_target_deselected`, `EventBus.jump_available`, and `EventBus.player_jump_requested` semantics.
    - `MainHUD` owns projected route brackets and emits `player_target_selection_requested(route_target)`.
    - `PlayerControllerShip` accepts logical route targets, highlights them, and emits `jump_available` without a distance gate.

  - [ ] TASK_3: Retire player-facing physical JumpPoint dependency from sector loading and focused tests.
    - Required files: `src/core/systems/sector_loader.gd`, `src/tests/core/systems/test_sector_loader.gd`, and any jump-point-specific fixtures that still assume `station_beta` or scene-local JumpPoint anchors.
    - Player travel must no longer depend on scene-instanced JumpPoint nodes for prompting, selection, or arrival.
    - Physical route markers may remain only as non-interactive decoration if they no longer control gameplay.

  - [ ] TASK_4: Finalize HUD-target precedence so projected route brackets own route selection instead of world-raycast clicks.
    - Required files: `src/modules/piloting/player_input_states/state_default.gd`, `src/core/ui/main_hud/main_hud.gd`, and any follow-on targeting surfaces that still assume `Spatial`-only selection.
    - HUD route brackets must stay clickable without world-space raycast interference.
    - Keep existing ship/station selection behavior intact until those target classes migrate to the projected-target system.

  - [ ] VERIFICATION: Confirm the HUD-projected jump slice with focused checks and one manual travel pass.
    - [x] Run `test_route_target_provider.gd` and expect the logical route-target block to pass.
    - [x] Run `test_docking_logic.gd` and confirm the route-target selection/interact block passes, even if unrelated fixture drift still fails elsewhere in the widened suite.
    - [ ] Run the narrow sector-loader/jump migration slice after TASK_3 and expect no player-facing JumpPoint dependency.
    - [ ] Manual Godot check: from any point in local space, select a HUD route bracket, press Interact, and arrive in the destination sector 100 km from center on the inbound vector.
