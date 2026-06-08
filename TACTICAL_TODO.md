<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; MODEL-CASCADE-PROTOCOL.md § Role: Lead Systems Architect
LOG_REF: 2026-06-08 02:20:00
-->

## CURRENT GOAL: Simplify Jump Transition Camera Sequence

- TARGET_SCOPE: Simplify the jump transition camera logic in `WorldManager` and `JumpTransitionRig`. Replace the complex multi-constant sequence (aiming duration, fov ease power, speed ramps, braking distance, target fov calculations, and multi-envelope overlay states) with a direct, 4-step sequence:
  1. Ship orienting and accelerating (gameplay physics continues to run for a set duration), camera is locked, HUD is hidden, camera zoom and FoV are recorded.
  2. Fade-in to black begins.
  3. When fully faded to black, gameplay is paused, source scene unloads, transition camera is enabled (inheriting the recorded orbit camera's FoV, which remains constant during transition), transition movement begins, and fade lifts.
  4. Movement continues for `JUMP_TRAVEL_DURATION` seconds. At `JUMP_TRAVEL_DURATION - JUMP_FADE_DURATION`, fade-in begins. When fully black, the destination scene is loaded, camera zoom and FoV are restored, gameplay is unpaused, fade gradually lifts, and HUD is restored.
- TARGET_FILES:
  - src/autoload/Constants.gd — Add simplified constants: `JUMP_ACCEL_DURATION`, `JUMP_FADE_DURATION`, `JUMP_TRAVEL_DURATION`. Remove/simplify obsolete configuration properties.
  - src/scenes/game_world/world_manager.gd — Refactor `_run_jump_transition_sequence` and add overlay fade coroutines.
  - src/scenes/game_world/jump_transition/jump_transition_rig.gd — Simplify rig state, remove envelope/velocity calculations, and implement simple travel progress interpolation.
  - src/tests/scenes/jump_transition/test_jump_transition_regressions.gd — Rewrite transition tests to match the simplified sequence and assert new behavior.
- TRUTH_RELIANCE: ["MODEL-CASCADE-PROTOCOL.md", "TRUTH_PROJECT.md"]
- TECHNICAL_CONSTRAINTS: ["Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"]
- OUT_OF_SCOPE: "Changing sector structures, modifying player controller input layout, altering player physics equations."
- VALIDATION_PLAN: "Run Gut tests in test_jump_transition_regressions.gd to assert correct simplified sequence, locked/unlocked state, and HUD visibility."
- ATOMIC_TASKS:
  - [x] TASK_1: Update `Constants.gd` to define simplified parameters: `JUMP_ACCEL_DURATION`, `JUMP_FADE_DURATION`, and `JUMP_TRAVEL_DURATION` while simplifying obsolete keys.
  - [x] TASK_2: Refactor `world_manager.gd` to orchestrate the simplified 4-step sequence using direct overlay alpha fades.
  - [x] TASK_3: Simplify `jump_transition_rig.gd` to perform linear interpolation of camera position over travel progress, removing obsolete envelope/velocity physics.
  - [x] TASK_4: Update `test_jump_transition_regressions.gd` to align with the simplified sequence and ensure all tests pass.
  - [x] VERIFICATION: Run the full test suite and verify all tests pass cleanly.
