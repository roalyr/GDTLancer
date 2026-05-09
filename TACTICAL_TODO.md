## CURRENT GOAL: Debug Map Panel Interaction + Spatial Annotation Upgrade
- TARGET_FILE: src/core/ui/debug_map_panel/debug_map_panel.gd
- TRUTH_RELIANCE: TRUTH_PROJECT.md (Godot3 3.6 stable, GLES2), TRUTH_CONSTRAINTS.md §1, TRUTH_CONTENT-CREATION-MANUAL.md §2 and §6, TRUTH_SIMULATION-GRAPH.md §2.1
- TECHNICAL_CONSTRAINTS:
  - Godot3 (3.6 stable)
  - GLES2 (for performance and compatibility)
  - Python3 sandbox remains out of scope for this milestone
- ATOMIC_TASKS:
  - [x] TASK_1: Add smooth mouse orbit and wheel zoom to the existing map camera without replacing the current button-driven camera helpers.
    - Required signatures: preserve `_orbit_rotate(dyaw: float, dpitch: float)`, `_zoom(factor: float)`, `_pan(direction: Vector3)`, `_reset_camera()` as the only camera mutation helpers.
    - Add viewport-local mouse input handling in `debug_map_panel.gd` so drag motion feeds `_orbit_rotate(...)` continuously and mouse wheel feeds `_zoom(...)` continuously.
    - Consume map mouse input only while the panel is visible and the pointer is over the map viewport.
    - Do not remove existing header buttons. Pan buttons must keep their current behavior.

  - [x] TASK_2: Add a reference-axis overlay inside the map viewport using the same line-rendering approach as sector connection lines.
    - Required signatures: add `_create_reference_axes()` and call it from `_populate_map()` after sector markers and connection lines are created.
    - Use `ImmediateGeometry` plus an unshaded `SpatialMaterial`, matching the connection-line rendering pattern.
    - Draw positive X, Y, Z arrows from the galactic origin using standard colors: X red, Y green, Z blue.
    - Add axis labels `X`, `Y`, `Z` and scale notch labels `1e5`, `2e5`, `3e5`, `4e5`, `5e5` aligned to the corresponding axes.

  - [x] TASK_3: Add a coordinate-visibility toggle that controls whether sector labels include XYZ values.
    - Required scene change: add `BtnCoords` to `src/core/ui/debug_map_panel/debug_map_panel.tscn` in the header row.
    - Required script state/signatures: add `_show_sector_coordinates: bool` and `_on_toggle_coords()` in `debug_map_panel.gd`.
    - When coordinates are visible, each sector label must include the sector name plus `[x, y, z]` in the same label. When hidden, labels must show the sector name only.
    - Toggling coordinates must refresh existing labels without rebuilding unrelated map geometry.

  - [x] TASK_4: Increase label readability without changing topology or marker semantics.
    - Apply a dedicated sector-label font using the same Roboto Condensed font asset already referenced by the scene.
    - Increase sector label font size by exactly `1.5x` relative to the current map label size.
    - Enable wrapping for long labels and constrain them to a fixed maximum width so long station names and coordinate suffixes do not run off-screen.
    - Keep current-sector highlight behavior intact.
    - Preferred label format when coordinates are shown: sector name on the first line, coordinate suffix `[x, y, z]` on the second line.

  - [x] TASK_5: Extend the debug map test slice for the new interaction and annotation behavior.
    - Required file: `src/tests/core/ui/test_debug_map_panel.gd`.
    - Add coverage for smooth-input entry points, coordinate toggle state, reference-axis geometry creation, and sector label text formatting.
    - Preserve the existing TemplateDatabase and topology seeding helpers.

  - [x] VERIFICATION: Confirm the contract with focused checks only.
    - [x] `get_errors()` reports zero new errors in the touched files.
    - [x] Run the narrow GUT slice for `src/tests/core/ui/test_debug_map_panel.gd` and expect pass.
    - [x] Manual Godot check: F4 opens the map, mouse drag rotates smoothly, mouse wheel zooms smoothly, pan buttons still work, axes/notches/axis labels render, and the coordinates button toggles `[x, y, z]` suffixes on wrapped labels.
