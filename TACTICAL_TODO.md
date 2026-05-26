<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Automated Testing Boundary; TRUTH_SIMULATION-GRAPH.md §0, §6.1, §6.3, §6.4; TRUTH_CONTENT-CREATION-MANUAL.md §6; TRUTH_CONSTRAINTS.md §1; MODEL-CASCADE-PROTOCOL.md ROLE: Lead Systems Architect
LOG_REF: 2026-05-26 14:02:14
-->

## CURRENT GOAL: Automated Test Boundary Governance And GUT Simulation Pruning
- TARGET_SCOPE: Codify a project-level rule for what belongs in automated GUT coverage versus manual chronicle/in-game validation, then prune or rewrite the current simulation-side test surfaces so GUT keeps deterministic mechanics, ordering, serialization, and API regressions while dropping balance-coupled, long-run, and broad smoke checks that now churn with rebalance work. Scope covers truth-level testing policy plus the highest-friction simulation tests that currently blur stable mechanics with manual balance validation. It does not retune live simulation behavior, alter the manual focused/composite chronicle workflow, widen GUT into new long-run harnesses, or cull stable scene/resource/serialization tests outside the declared owners.
- TARGET_FILES:
  - TRUTH_PROJECT.md — authoritative project-level boundary for what automated tests must cover versus what stays manual.
  - src/tests/core/simulation/test_grid_layer.gd — current highest-friction simulation test surface for balance-coupled threshold and pacing assertions.
  - src/tests/core/simulation/test_simulation_integration.gd — broad end-to-end simulation smoke coverage that must be narrowed to stable contracts or removed.
  - src/tests/core/simulation/test_simulation_report.gd — report-side tests that should remain structural/API-focused rather than becoming manual balance surrogates.
  - src/tests/core/simulation/test_simulation_tick.gd — deterministic tick-order and world-age contract surface that should remain in GUT and help define the keep boundary.
  - src/tests/core/simulation/test_contract_generation_system.gd — deterministic runtime-demand contract generation guards that should be explicitly reviewed against the new keep/cull rules.
- TRUTH_RELIANCE: ["TRUTH_PROJECT.md § Project Stack And Context", "TRUTH_PROJECT.md § Automated Testing Boundary", "TRUTH_SIMULATION-GRAPH.md §0 Implementation Reality", "TRUTH_SIMULATION-GRAPH.md §6.1", "TRUTH_SIMULATION-GRAPH.md §6.3", "TRUTH_SIMULATION-GRAPH.md §6.4", "TRUTH_CONTENT-CREATION-MANUAL.md §6", "TRUTH_CONSTRAINTS.md §1"]
- TECHNICAL_CONSTRAINTS: ["Platform (primary): Godot3 (3.6 stable)", "Graphics: GLES2 (for performance and compatibility)", "Additional: Python3 (for sandbox)"]
- ATOMIC_TASKS:
  - [x] TASK_1: Add an explicit automated-testing policy to `TRUTH_PROJECT.md` that defines the keep/cull boundary between deterministic GUT regression guards and manual balance validation. Required signatures: preserve the current Godot3/GLES2/Python3 project context in `TRUTH_PROJECT.md`, preserve the manual focused/composite chronicle workflow as the authority for long-run balance validation, and do not redefine live runtime ownership.
  - [x] TASK_2: Review the declared simulation-side GUT files and cull or rewrite tests that primarily encode rebalanceable thresholds, long-run world-shape expectations, or broad smoke loops instead of stable contracts. Required signatures: preserve production-code public interfaces, keep deterministic tick/order/report/contract-generation guards that still express stable mechanics, and do not reintroduce automated 300-3000 tick full-environment harnesses.
  - [x] TASK_3: Tighten any kept simulation tests so they assert stable invariants, gating rules, or effective live-code thresholds rather than stale balance numbers or registry-coupled incidental behavior. Required signatures: preserve the existing test-file ownership boundary, prefer local fixture/helper updates over runtime code changes, and keep GUT invocation narrow (exact-file or narrow-folder).
  - [ ] VERIFICATION: Success criteria/tests to run: `TRUTH_PROJECT.md` contains an explicit automated-testing boundary that separates deterministic GUT coverage from manual balance validation; the declared simulation test files no longer contain broad smoke checks or balance assertions that should live in chronicle/manual review; deterministic mechanics/order/report/contract-generation guards that still represent stable contracts remain present; no automated long-run 300-3000 tick harness is added or restored; touched-file diagnostics stay clean; headless `godot --path "$PWD" --no-window --quit` stays clean apart from the known GLES2 sharpening warning; any GUT follow-up is run as exact-file or narrow-folder slices rather than as a new broad suite mandate.
