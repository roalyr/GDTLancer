<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; MODEL-CASCADE-PROTOCOL.md § Role: Lead Systems Architect
LOG_REF: 2026-06-09 20:56:00
-->

## CURRENT GOAL: UI Overlay Simplification and Manual Flight Passthrough
- TARGET_SCOPE: Simplify jump route projected targeting labels by using a distinct color (defined in Constants.gd) instead of the redundant "Jump Route" text. Re-map the HUD overlay buttons: `ButtonOverlayJump` toggles star jump routes, `ButtonOverlayStellar` toggles all other jump routes (planets/moons) alongside intra-sector stellar targets, and `ButtonOverlayStructures` remains as-is. Finally, ensure the projected target brackets do not consume passive mouse drag motion during manual flight mode (mouse filter or drag forwarding).
- TARGET_FILES:
  - src/autoload/Constants.gd — Add a UI color constant for jump routes.
  - src/core/ui/main_hud/main_hud.gd — Update `_get_projected_target_overlay_kind()` to differentiate jump routes based on the destination sector type (`star` vs others).
  - src/core/ui/main_hud/projected_target_bracket.gd — Apply the custom color for jump targets, remove the "Jump Route" string, and correctly forward or ignore mouse motion during manual flight to avoid steering lock.
  - src/tests/core/ui/test_main_hud_projected_targeting.gd — Update assertions for the label text, color, and overlay routing to match the new behavior.
- TRUTH_RELIANCE: MODEL-CASCADE-PROTOCOL.md
- TECHNICAL_CONSTRAINTS: "Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"
- ATOMIC_TASKS:
  - [x] TASK_1: Update `Constants.gd` to include `COLOR_UI_JUMP_ROUTE`.
  - [x] TASK_2: In `main_hud.gd`, update `_get_projected_target_overlay_kind()` to check the destination sector type for route targets. If `sector_type` is `"star"`, return `OVERLAY_KIND_JUMP`. Otherwise (e.g. `"planet"`, `"moon"`), return `OVERLAY_KIND_STELLAR`. Leave intra-sector stellar bodies as `OVERLAY_KIND_STELLAR`.
  - [x] TASK_3: In `projected_target_bracket.gd`, update `_resolve_secondary_label()` to return `""` instead of `"Jump Route"`. Update `_sync_label()` to apply `Constants.COLOR_UI_JUMP_ROUTE` to `_info_label.add_color_override("font_color", ...)` if `_is_route_target(target_ref)` or it's a jump point; otherwise clear the color override.
  - [ ] TASK_4: In `projected_target_bracket.gd`, update `_input()` to ensure `InputEventMouseMotion` is forwarded to `_unhandled_input` of the ship controller (or not consumed) if the pointer is not dragging, not pressed, and `is_free_flight_active()` is true.
  - [ ] VERIFICATION: Update and run `test_main_hud_projected_targeting.gd` to verify the label color, text removal, and the new `OVERLAY_KIND` logic for jump targets.
