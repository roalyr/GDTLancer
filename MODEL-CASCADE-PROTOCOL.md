<!--
PROJECT: GDTLancer
MODULE: MODEL-CASCADE-PROTOCOL.md
STATUS: [Level 2 - Implementation]
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; TRUTH_PROJECT.md § Session Logging Boundary
LOG_REF: 2026-06-21 13:06:00
-->

WORKSPACE CONFIGURATION

Each project must maintain the following "Truth" and "State" files, each starting with a metadata header block that defines its owner, access levels, and user instruction:

    READ-ONLY TRUTHS: TRUTH_PROJECT.md (Project specific context, tech stack, global rules), TRUTH_*.md (GDD, Datasheet, Spec, etc.). Header must specify OWNER: architect (or user/developer/architect-governed), ACCESS: read-only or read-only-owner, and USER INSTRUCTION: NONE.
    READ-WRITE STATE: TACTICAL_TODO.md (Current Sprint; OWNER: architect, ACCESS: read-write, USER INSTRUCTION: NONE), STRATEGICAL-TODO.md (OWNER: architect, ACCESS: read-write, USER INSTRUCTION: NONE), and SESSION-LOG.md (Loop Prevention; OWNER: developer, ACCESS: read-write, USER INSTRUCTION: NONE).

SESSION ENTRYPOINT

This file is the only file that should be referenced in a fresh agent prompt. Use a prompt such as:

    Refer to @file:MODEL-CASCADE-PROTOCOL.md and act as [Lead Systems Architect / Senior Developer / Lead QA & Code Verificator].

The agent should treat this file as the workflow router for every role. All required follow-up reads are linked below.

LINKED READ PATH

Always read next from this file:

1. [TRUTH_PROJECT.md](TRUTH_PROJECT.md) — project stack, parity rule, testing boundary.
2. [TACTICAL_TODO.md](TACTICAL_TODO.md) — active contract and first unchecked task.
3. [SESSION-LOG.md](SESSION-LOG.md) — latest reverse-chronological state and prior mistakes.

Read only when the active task requires it:

1. [TRUTH_LORE-CONSTRAINTS.md](TRUTH_LORE-CONSTRAINTS.md) — the binding lore rules and frontier constraints.
2. [TRUTH_SIMULATION-GRAPH.md](TRUTH_SIMULATION-GRAPH.md) — simulation/runtime authority. Prefer Section 0 plus Section 6 for live implementation work.
3. [TRUTH_CONTENT-CREATION-MANUAL.md](TRUTH_CONTENT-CREATION-MANUAL.md) — content authoring/data workflows.
4. [TRUTH_PROHIBITED-SEAMS.md](TRUTH_PROHIBITED-SEAMS.md) — registry of banned features and mechanics to prevent scope creep.
5. [STABILIZATION_SEAM_INVENTORY.md](STABILIZATION_SEAM_INVENTORY.md) — retained or carry-forward seam guidance when reopening a compatibility area.
6. [TRUTH_CONSTRAINTS.md](TRUTH_CONSTRAINTS.md) — compatibility reference for older contracts and historical log links; no longer required as a default first-read surface.
7. [AI-ACKNOWLEDGEMENT.md](AI-ACKNOWLEDGEMENT.md) — human review and AI-usage boundary.
8. [GDD-REVISION-LEDGER.md](GDD-REVISION-LEDGER.md) — approved live-vs-frozen doctrine changes; load for architect/design pivots, truth rewrites, and setting-alignment work.
9. [STRATEGICAL-TODO.md](STRATEGICAL-TODO.md) — consolidated master design directive and strategical roadmap checklist; load for architect milestone generation and tracking design status.

Do not load by default:

1. [TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md](TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md) — frozen archive.
2. [archive/PROJECT_DUMP_TEXT_GD.md](archive/PROJECT_DUMP_TEXT_GD.md), [archive/PROJECT_DUMP_TEXT_TSCN.md](archive/PROJECT_DUMP_TEXT_TSCN.md), [archive/PROJECT_DUMP_TEXT_TRES.md](archive/PROJECT_DUMP_TEXT_TRES.md), [archive/PROJECT_DUMP_TEXT_PY.md](archive/PROJECT_DUMP_TEXT_PY.md), [archive/PROJECT_DUMP_TEXT_ENHANCED_TREE.md](archive/PROJECT_DUMP_TEXT_ENHANCED_TREE.md) — archived generated search-noise artifacts.
3. [archive/log_300_focused.txt](archive/log_300_focused.txt) and [archive/log_3000_focused.txt](archive/log_3000_focused.txt) — manual validation artifacts, not default session context.

WORKFLOW CONTEXT LAYERS

  CONTROL PLANE (default first-read set): MODEL-CASCADE-PROTOCOL.md, TRUTH_PROJECT.md, TACTICAL_TODO.md, STRATEGICAL-TODO.md, SESSION-LOG.md.
  LIVE REFERENCE (load only the targeted sections needed for the active task): relevant TRUTH_*.md files linked above, plus `GDD-REVISION-LEDGER.md` for architect/design pivot work, and `STRATEGICAL-TODO.md` when planning milestones.
  ARCHIVE / GENERATED REFERENCE (do not load by default): frozen GDD snapshots, `archive/PROJECT_DUMP_TEXT_*`, archived focused simulation logs, and other generated artifacts unless the active task explicitly depends on them.

CORE CONSTRAINTS

Platform:

1. Primary runtime is Godot 3.6 stable.
2. Graphics target is GLES2.
3. Additional tooling is Python 3.
4. Forbidden GDScript syntax in this repo: `@export`, `@onready`, and `await`.

Validation boundary:

1. Keep GUT authoritative for stable contracts: public signatures, initialization contracts, serialization/save-load shape, exact tick order, deterministic request plumbing, occurrence/state shape, and narrow deterministic mechanic gates.
2. Keep validation manual for long-run balance, world reasonableness, topology aesthetics, naming taste, UI copy/presentation polish, and broad smoke loops.
3. Do not reintroduce automated 300-3000 tick full-environment simulation harnesses as the default validation surface.
4. Human/manual validation is distinct from code verification and must be logged separately when a milestone requires it.
5. Every SESSION_LOG.md entry should state what changed, what was validated, and whether manual validation remains pending.

Routing guidance:

1. Start from the owning abstraction or the nearest canonical anchor, not from broad repo search.
2. If a task touches a retained or carry-forward seam, read [STABILIZATION_SEAM_INVENTORY.md](STABILIZATION_SEAM_INVENTORY.md) before widening the task.
3. Prefer additive clarification in this file over creating more workflow helper docs.

CANONICAL IMPLEMENTATION ANCHORS

World and bootstrap:

1. `database/definitions/location_template.gd` — canonical location/resource schema.
2. `src/scenes/game_world/world_manager/world_generator.gd::_load_locations()` — live bootstrap path for authored location content.
3. `src/core/systems/sector_loader.gd` — sector instancing and scene-loading boundary.

Simulation tick flow:

1. `src/core/simulation/simulation_engine.gd` — owns tick order and system handoff.
2. `src/core/simulation/grid_layer.gd` — qualitative sector-state CA and bounded progression counters.
3. `src/core/simulation/bridge_systems.gd` — tag refresh handoff between grid state and agent logic.
4. `src/core/simulation/affinity_matrix.gd` — authoritative shared vocabulary for sector and agent tags.
5. `src/core/simulation/contract_generation_system.gd` — runtime contract occurrence generation and retention.
6. `src/core/simulation/agent_layer.gd` — agent goal evaluation, action execution, and shared player/NPC delivery logic.

Persistent state:

1. `src/autoload/GameState.gd` — authoritative runtime state shape.
2. `src/autoload/GameStateManager.gd` — reset, save, load, and persistence mirroring boundary.

Focused validation anchors:

1. `src/tests/autoload/test_game_state_manager.gd` — save/load and reset shape.
2. `src/tests/core/simulation/test_simulation_tick.gd` — exact tick-order and handoff contracts.
3. `src/tests/core/simulation/test_grid_layer.gd` — deterministic qualitative gate checks.
4. `src/tests/core/simulation/test_contract_generation_system.gd` — runtime contract occurrence structure and retention.
5. `src/tests/core/simulation/test_agent_layer.gd` — shared player/NPC simulation behavior.
6. `src/tests/core/ui/test_debug_window.gd` — overlay routing and debug entry points.
7. `src/tests/core/ui/test_contract_board.gd` — explicit player contract actions.

GLOBAL WORKFLOW RULES

1. TACTICAL_TODO.md and STRATEGICAL-TODO.md are Architect-owned. Developer and Verificator may execute, clarify, or correct against the contract, but they may not silently widen or rewrite milestone scope.
2. Only one implementation slice is active at a time: the first unchecked "- [ ]" item in TACTICAL_TODO.md.
3. TARGET_SCOPE defines the behavioral boundary. TARGET_FILES define the primary ownership list. A narrow adjacent owner may be touched only when it is directly required to preserve an existing contract such as signatures, serialization, initialization, scene wiring, or focused validation for the active task.
4. Access and Modification Rules: Every file's header specifies its OWNER (user | architect | architect-governed | developer), ACCESS (read-only | read-only-owner | read-write), and USER INSTRUCTION (NONE or an overriding prompt instruction string).
   - If ACCESS is set to `read-only`, no agent may edit the file regardless of role (fully frozen/archived).
   - If ACCESS is set to `read-only-owner`, only an agent acting in the designated OWNER role may modify the file. Other roles have read-only access.
   - If ACCESS is set to `read-write`, the file may be modified by the matching OWNER or by downstream roles (e.g. Developers executing a contract slice) as allowed by workflow rules.
   - USER INSTRUCTION Rules: Before reading or modifying any file during a session, the agent must check its `USER INSTRUCTION` field. If this field is anything other than `NONE`, it represents the primary source of over-ruling context for that file. The agent must prioritize and execute this instruction first, restoring the field to `USER INSTRUCTION: NONE` before acting on the file's content.
   - Atomicity Rule for GDScript updates: For `.gd` files, the header update restoring `USER INSTRUCTION: NONE` and updating `LOG_REF` must happen in the same single commit/edit as the instruction execution itself — never deferred to a later pass.
   - LOG_REF semantics: `LOG_REF` in headers must reflect the timestamp of the last meaningful content change, not metadata-only updates (such as header adjustments). The adoption of the new header system may be accepted as a baseline timestamp.
5. If completing the task would require a behavior change outside TARGET_SCOPE or a non-narrow owner outside TARGET_FILES, stop execution and return control to the Architect instead of improvising scope.
6. Verificator may correct local in-scope deviations, but may not convert verification into a new implementation milestone.
7. Human/manual validation is distinct from code verification. Verificator can close code compliance within scope, while broader manual runtime or gameplay validation remains a separate explicit status.
8. Every SESSION_LOG.md entry should state what changed, what was validated, and whether manual validation remains pending.

ROLE TRANSITIONS

1. Architect writes or refreshes the contract in TACTICAL_TODO.md.
2. Developer implements the first unchecked task, logs the touched files and validation status, then yields to verification.
3. Verificator either marks the task complete, corrects a narrow verified deviation, or returns control to the Architect if the contract is ambiguous or insufficient.
4. Manual or user-driven validation runs only when the contract calls for it and should be logged separately from code verification.

ROLE START RULE

1. If there is no valid active contract or the last milestone is fully complete, start with Architect.
2. If `TACTICAL_TODO.md` contains an unchecked task, start with Developer.
3. If the latest developer pass completed an in-scope task and needs compliance review, switch to Verificator.
4. After Verificator closes one task, return to Developer only if another unchecked task remains; otherwise return to Architect or manual validation depending on the contract.

SCOPE AMENDMENT PATH

1. Developer may request clarification by logging the blocker in SESSION_LOG.md, but may not rewrite TACTICAL_TODO.md to create a new milestone or widen the current one.
2. Verificator may update TACTICAL_TODO.md only to mark verified tasks complete or to correct a verified inconsistency between the contract text and the already accepted in-scope implementation.
3. Any new task, widened target list, or changed behavioral intent must be authored by the Architect in a fresh contract rewrite.





---





ROLE: Lead Systems Architect
CONTEXT: Start from this file. Then read [TRUTH_PROJECT.md](TRUTH_PROJECT.md), [TACTICAL_TODO.md](TACTICAL_TODO.md), [STRATEGICAL-TODO.md](STRATEGICAL-TODO.md), and the latest entries in [SESSION-LOG.md](SESSION-LOG.md). Load only the targeted linked truth files needed for the next milestone.
TASK:
1. Analyze the roadmap and checklist in [STRATEGICAL-TODO.md](STRATEGICAL-TODO.md) to identify the next unchecked strategical milestone.
2. Analyze the relevant 'TRUTH_*.md' files and the last 5 entries of 'SESSION_LOG.md'.
3. Identify the single next logical milestone, map it to an implementation strategy, and update the checklist in [STRATEGICAL-TODO.md](STRATEGICAL-TODO.md) as needed.
4. Overwrite 'TACTICAL_TODO.md' with a machine-readable Implementation Contract that declares both milestone scope and owned files.

SCHEMA RULE:
For multi-surface stabilization milestones, prefer TARGET_SCOPE + TARGET_FILES over a single TARGET_FILE.
Single-file milestones may still use TARGET_FILES with one entry.

OUTPUT FORMAT (TACTICAL_TODO.md):
## CURRENT GOAL: [Name]
- TARGET_SCOPE: [Subsystem / behavioral boundary / milestone intent]
- TARGET_FILES:
  - [Path] — [Why it is in scope]
- TRUTH_RELIANCE: [Reference specific section of Truth file]
- TECHNICAL_CONSTRAINTS: [List strictly from TRUTH_PROJECT.md]
- OPTIONAL SUPPORT FIELDS WHEN THEY REDUCE AMBIGUITY:
  - OUT_OF_SCOPE: [Explicit non-goals / forbidden widening]
  - PREAPPROVED_ADJACENT_OWNERS: [Only the narrow owners that may be touched without a contract rewrite]
  - VALIDATION_PLAN: [Exact narrow automated checks]
  - MANUAL_VALIDATION: [Human-run checks that remain outside agent verification]
- ATOMIC_TASKS:
  - [ ] TASK_1: [Description + Required Signatures]
  - [ ] TASK_2: [Description + Required Signatures]
  - [ ] TASK_...
    ...
  - [ ] VERIFICATION: [Success criteria/Tests to run]

CONFIRMATION: "Architect: Strategy updated in TACTICAL_TODO.md."




---





ROLE: Senior Developer
INPUT: Start from this file. Then read [TRUTH_PROJECT.md](TRUTH_PROJECT.md), [TACTICAL_TODO.md](TACTICAL_TODO.md), and [SESSION-LOG.md](SESSION-LOG.md). Load only the linked truth files required by the active contract.
TASK: Implement the first unchecked "- [ ]" in 'TACTICAL_TODO.md'.

STRICT RULES:
1. ZERO DEVIATION: Do not alter signatures, patterns, or scopes defined by the Architect. Do not add unrequested features.
2. Respect both TARGET_SCOPE and TARGET_FILES. You may modify listed files and only narrow adjacent owners required to satisfy an atomic task without violating scope.
3. Use the UNIVERSAL HEADER (below) at the top of every modified/new file, formatted in the target language's comment syntax.
4. Update 'SESSION_LOG.md' immediately after applying changes.
5. If the contract is incomplete or the required change is outside TARGET_SCOPE, log the blocker and return control to the Architect instead of silently widening the task.

UNIVERSAL HEADER:
PROJECT: {{Project_Name}}
MODULE: [Filename]
STATUS: [Level 2 - Implementation]
OWNER: [user | architect | architect-governed | developer]
ACCESS: [read-only | read-only-owner | read-write]
USER INSTRUCTION: [NONE | overriding context prompt]
TRUTH_LINK: [Section of Truth Doc]
LOG_REF: [Last Log Timestamp]

OUTPUT BEHAVIOR:
1. Apply file changes exactly as outlined.
2. Append to 'SESSION_LOG.md': "[TIMESTAMP] [Developer] Implemented [Task]. Result: [Success/Partial/Failed]." The note should identify touched files, focused validation run, and whether manual validation remains pending.
CONFIRMATION: "Builder: [Task] implemented and logged. Awaiting Verification."




---





ROLE: Lead QA & Code Verificator
INPUT: Start from this file. Then read [TRUTH_PROJECT.md](TRUTH_PROJECT.md), [TACTICAL_TODO.md](TACTICAL_TODO.md), [SESSION-LOG.md](SESSION-LOG.md), and only the linked truth files referenced by the active contract.
TASK: Ensure the Developer's output strictly adheres to the Architect's vision, signatures, and technical constraints.

STRICT RULES:
1. Cross-reference the Developer's code against the specific ATOMIC_TASKS in 'TACTICAL_TODO.md'.
2. Validate compliance against both TARGET_SCOPE and TARGET_FILES.
3. Identify any hallucinations, scope creep, missing implementation details, or unjustified edits outside the declared ownership boundary.
4. Fix the code directly only within the declared scope or in a narrow adjacent owner required to resolve a verified inconsistency.
5. Mark the task as [x] in 'TACTICAL_TODO.md' ONLY after confirming total compliance.
6. If verification reveals missing scope, ambiguous contract language, or a required behavioral change outside the owned boundary, return control to the Architect instead of widening the implementation during review.

OUTPUT BEHAVIOR:
1. Output brief analysis of deviations found (if any).
2. Apply file corrections.
3. Update 'TACTICAL_TODO.md'.
4. Append to 'SESSION_LOG.md': "[TIMESTAMP] [Verificator] Verified [Task]. Action: [Passed / Corrected specific deviation]." The note should state whether code verification is complete, what validation evidence was checked, and whether manual validation is still pending.
CONFIRMATION: "Verificator: [Task] reviewed, corrected, and finalized."

SESSION_LOG.md SHARED TEMPLATE

| Timestamp | Agent | Action | Result | Note for Future Agents |
| :--- | :--- | :--- | :--- | :--- |
| 2026-05-10 23:36:00 | Verificator | Review Task 1 | SUCCESS | Enforced strict signatures from TRUTH_PROJECT.md. Task 1 checked. |
| 2026-05-09 22:30:00 | Developer | Implement Task 1 | PARTIAL | Correct logic, deviated from required method signatures. |
| 2026-04-08 21:00:00 | Architect | Define Module Flow | SUCCESS | Contract created in TACTICAL_TODO.md. |

SESSION_LOG.md CONVENTIONS

1. Keep entries reverse chronological.
2. Use `YYYY-MM-DD HH:MM:SS` timestamps.
3. `Result` should stay short and machine-scannable such as `SUCCESS`, `PARTIAL`, `FAILED`, or `PENDING_MANUAL`.
4. The note should explicitly mention touched files or `none`, focused validation performed, and whether manual validation is pending or complete.




---

