<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack and Context; TRUTH_SIMULATION-GRAPH.md §5, §6.4; MODEL-CASCADE-PROTOCOL.md ROLE: Lead Systems Architect
LOG_REF: 2026-05-23 23:55:43
-->

## CURRENT GOAL: Scoped Chronicle Analysis And Sim Debug Reporting
- TARGET_SCOPE: Improve simulation observability without materially changing the current live world snapshot panel. Scope covers verbose chronicle batch reporting, sector/agent-focused report generation and sorting, and sim-debug controls for selecting analysis focus while keeping the existing world-layer snapshot useful as-is.
- TARGET_FILES:
  - src/core/simulation/chronicle_layer.gd — raw event capture and rumor/event distribution; must expose enough detail for focused sector and agent analysis without breaking the existing event packet shape.
  - src/core/simulation/simulation_report.gd — owns chronicle batch report generation and must grow beyond the current world-wide narrative summary into verbose, sortable, focus-aware reports.
  - src/core/simulation/simulation_engine.gd — panel-facing batch report entry point and request plumbing for scoped report generation.
  - src/core/ui/sim_debug_panel/sim_debug_panel.gd — keeps the current live world snapshot intact while adding controls for scoped chronicle analysis runs.
  - scenes/ui/hud/sim_debug_panel.tscn — sim debug panel controls for selecting report focus, sort mode, and detail level.
  - src/tests/core/simulation/test_simulation_report.gd — report-mode, focus, and sorting coverage.
  - src/tests/core/simulation/test_chronicle_layer.gd — chronicle event-shape and enrichment/filtering coverage.
  - src/tests/core/ui/test_sim_debug_panel.gd — focused panel-control and scoped-report request coverage.
- TRUTH_RELIANCE: ["SESSION-LOG.md 2026-05-23 23:24:49 verification closeout", "TRUTH_PROJECT.md § Project Stack and Context", "TRUTH_SIMULATION-GRAPH.md §0 Implementation Reality", "TRUTH_SIMULATION-GRAPH.md §5", "TRUTH_SIMULATION-GRAPH.md §6.4"]
- TECHNICAL_CONSTRAINTS: ["Platform (primary): Godot3 (3.6 stable)", "Graphics: GLES2 (for performance and compatibility)", "Additional: Python3 (for sandbox)"]
- ATOMIC_TASKS:
  - [ ] TASK_1: Extend chronicle/report generation so the same batch run can emit both integral summaries and detailed event logs, with focus controls for `world`, `sector`, or `agent` analysis and deterministic sort controls for `chronological`, `sector`, or `agent` ordering. Required signatures: preserve `ChronicleLayer.log_event(event_packet: Dictionary)` and `ChronicleLayer.process_tick()`; preserve the event packet shape `{tick, actor_id, action, sector_id, metadata}`; extend `SimulationReport.run_and_report(engine, tick_count: int, epoch_size: int = 1, report_request: Dictionary = {}) -> String` without breaking the default world-wide chronicle call.
  - [ ] TASK_2: Update the batch-report entry point and sim debug panel so the default live world snapshot remains the primary F3 view, while batch runs can request world-wide, sector-focused, or agent-focused chronicle reports with selectable detail level and focus id from current simulation entities. Required signatures: preserve `SimulationEngine.run_batch_and_report(tick_count: int, epoch_size: int = 1, report_request: Dictionary = {}) -> String`; keep the existing Run 30 / Run 300 / Run 3000 affordances available rather than replacing them with a different flow.
  - [ ] TASK_3: Add focused automated coverage for scoped chronicle analysis. Required signatures: preserve the existing simulation-report smoke assertions, extend `test_chronicle_layer.gd` without changing the public ChronicleLayer API, and add a narrow sim-debug-panel test rather than widening unrelated UI suites.
  - [ ] VERIFICATION: Success criteria/tests to run: the current live world snapshot still renders World/Grid/Agent/Chronicle overview without collapsing into report mode by default; default batch report still produces a readable world-wide chronicle; sector-focused reports include only relevant sector state changes and events plus an integral summary for that sector; agent-focused reports include the tracked agent's movement/combat/trade/contract/discovery lifecycle in order; sort modes are deterministic and readable; 30/300/3000 tick report generation remains stable without dumping full reports by default in tests; touched-file diagnostics stay clean; defer full GUT/manual runtime execution to the user's final pass.
