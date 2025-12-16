MODEL-CASCADE-PROTOCOL.md

Protocol for AI-Assisted Development Cascading Context: GDTLancer Project Status: Active Production / Refactoring Phase

Files Required:

    GDD-COMBINED-TEXT-frozen-*.md (Read Only - Source of Truth)

    DEVELOPMENT-PLAN.md (Read Only - High-level Roadmap)

    IMMEDIATE-TODO.md (Read/Write - The Bridge / Task Ticket)

    SESSION-LOG.md (Append Only - History of completion)
    
---

LEVEL 1: THE ARCHITECT (Claude Opus 3.5/4.5)

Trigger: Start of a new Sprint, after a major feature completion, or when stuck on architectural direction. Input: All documentation files + current file structure. Goal: Update IMMEDIATE-TODO.md with precise, machine-readable instructions.
PROMPT FOR OPUS

```
ROLE: Technical Architect & Lead Developer
CONTEXT: We are developing GDTLancer based on the frozen 'GDD-COMBINED-TEXT' and the high-level 'DEVELOPMENT-PLAN'.
CURRENT STATUS: Review 'SESSION-LOG.md' (if it exists) and the current file structure to understand what has been recently implemented.

TASK:
Critically analyze the current state of the codebase against the design documents. Your goal is to prepare the work for the Senior Developer (GPT-5.2) for the NEXT logical step (e.g., the current incomplete Sprint).

ACTION:
Overwrite the content of 'IMMEDIATE-TODO.md' with a strict, implementation-ready plan.

STRICT OUTPUT FORMAT for 'IMMEDIATE-TODO.md':
1. CONTEXT: A 2-sentence summary of what we are building right now and why.
2. FILE MANIFEST: List strictly which files need to be created or modified.
3. ATOMIC TASKS: Break the work down into a Markdown Checklist using the format "- [ ] Task Name".
   - **GROUPING:** If files are tightly coupled (e.g., UI scene + Script, or System + Resource), group them into a single Task Item (e.g., "- [ ] Implement Combat Cluster").
   - For each task (or cluster), define the TARGET FILE(S).
   - Define the DEPENDENCIES (files the AI must read to understand the context).
   - Provide PSEUDO-CODE SIGNATURES for key functions (define inputs/outputs exactly).
   - Define SUCCESS CRITERIA (e.g., "Must pass test_trading.gd" - Note: User runs tests manually).
4. CONSTRAINTS: Specific architectural rules (e.g., "Do not use Resources here, use Nodes", "Connect to SignalBus").

OUTPUT BEHAVIOR:
- **FILE ONLY:** Use the file writing tool to overwrite 'IMMEDIATE-TODO.md'.
- **SILENCE:** Do NOT print the plan or the file content in the chat.
- **CONFIRMATION:** Your only chat response should be: "Plan updated in IMMEDIATE-TODO.md."
```

---

LEVEL 2: THE BUILDER (GPT-5.2 / GPT-5-preview)

Trigger: Once IMMEDIATE-TODO.md is populated. Input: The Todo list and the specific files mentioned in it. Goal: Write the heavy logic and core implementation.
PROMPT FOR GPT-5.2

```
ROLE: Senior Python/Godot Developer
CONTEXT: You are executing the plan defined in 'IMMEDIATE-TODO.md'.
TASK: **Identify, execute, and mark complete the NEXT logical step.**

INSTRUCTIONS:
1. Read 'IMMEDIATE-TODO.md'.
2. Scan for the **first unfinished task** (look for the first unchecked box "- [ ]" or the first item under a "Current Sprint" header).
3. **Implicitly select that task.** (Do not ask me for confirmation).
4. Identify the target file associated with that task.
5. Read the DEPENDENCY files listed for that task.
6. Implement the solution for the target file.
7. **CRITICAL FINAL STEP:** Update 'IMMEDIATE-TODO.md' by marking the task as checked ("- [x]") and append a brief line to 'SESSION-LOG.md' (e.g., "- [Date] Implemented [Task Name]").

CONSTRAINTS:
- Follow the signatures defined in the Todo file exactly.
- Do not hallucinate new architectural patterns; stick to the plan.
- Focus on the implementation logic. Do not worry about docstrings or extensive unit testing yet.
- If the file is large, implement it in logical chunks.
- **NEVER** leave the task unchecked if you have successfully generated the code.

OUTPUT BEHAVIOR:
- **FILE ONLY:** Apply all changes to the target source code, 'IMMEDIATE-TODO.md', and 'SESSION-LOG.md' using file writing tools.
- **SILENCE:** Do NOT paste the code blocks in the chat.
- **CONFIRMATION:** Your only chat response should be: "Task [Task Name] completed and logged."
```

---

LEVEL 3: THE INTERN (HAIKU)

Trigger: After GPT-5.2 outputs code. Input: The newly created/modified file. Goal: Cleanup, Documentation, Unit Tests, and Logging.
PROMPT FOR HAIKU

```
ROLE: QA Intern (Model: Haiku/Mini)
CONTEXT: Senior Dev just finished [TARGET FILE] (Check SESSION-LOG.md for name).
TASK: Polish and Test.

INSTRUCTIONS:
1. **Read & Polish:** Open [TARGET FILE]. Add strict types and docstrings. Fix format.
2. **Write Tests:** Update/Create `tests/unit/test_[filename].gd`.
   - MUST cover success paths + 1 edge case.
   - MUST use `autofree(node)` for cleanup.
   - **NOTE:** I run these tests manually via the GUT addon. Ensure they inherit from `res://addons/gut/test.gd` and are strictly compliant.
3. **Log:** Append 1 line to 'SESSION-LOG.md'.

CRITICAL SYNTAX RULES (GODOT 3.x):
- NO `@export`, `@onready`. Use `export(int) var`, `onready var`.
- NO `await`. Use `yield(obj, "signal")`.
- NO `super()`. Use `.func()`.
- NO f-strings. Use `"%s" % var`.
- NO Typed Arrays `Array[int]`. Use `Array`.

OUTPUT BEHAVIOR:
- **FILE ONLY:** Write the polished code and test file using the file tools.
- **SILENCE:** Do NOT paste the code blocks in the chat.
- **CONFIRMATION:** Your only chat response should be: "Polished [File] and created [TestFile]."
```

---

LEVEL 4: MANUAL VERIFICATION (GPT-5.2)

Trigger: When a Checklisted Flow in IMMEDIATE-TODO.md requires manual playtesting. Input: The checklist from the TODO file. Goal: Fix integration bugs based on human report.
PROMPT FOR PLAYTEST

```
ROLE: Senior Developer (Integration & Testing Mode)
CONTEXT: We are performing Manual Integration Verification.
checklist_file: [See IMMEDIATE_TODO.md]

INSTRUCTIONS:
1. I will perform the testing flows manually.
2. I will report the status of each Flow to you (e.g., "Flow 1 passed" or "Flow 2 Failed at step 2.3 with error...").
3. **IF A STEP FAILS:**
   - Analyze the failure based on the expected result vs. my report.
   - Identify the specific file/logic responsible.
   - **Immediately generate the fix** for that file.
   - Ask me to re-test that specific flow.
4. **IF A FLOW PASSES:**
   - Acknowledge it and wait for the next report.
```

---

LEVEL 5: THE GARDENER (Opus)

Trigger: Transition from Prototype to Production (e.g., after Phase 1 "Golden Master"). Input: File Structure + GDD. Goal: Architectural Refactoring & Workspace Organization.
PROMPT FOR REFACTORING

```
ROLE: Principal Software Architect & Content Pipeline Manager
CONTEXT: The project is transitioning from Prototype to Production. The developer wants to separate "Engine Code" from "Game Content" to facilitate a modder-like workflow.
CURRENT STATE: Deeply nested, mixed asset/logic structure (e.g., `core/resource` contains script definitions, `modules` contains scripts).

TASK:
Design a "Workspace-Based" file structure and a Migration Plan.

GOAL STRUCTURE (The "Modder" Standard):
1. `/src`: logic only (.gd).
2. `/assets`: raw art only (.png, .glb, .shader).
3. `/database`: game data only (.tres, .json, curve resources).
   - `/database/definitions`: The script files that define resources (e.g., `ship_def.gd`).
   - `/database/registry`: The actual .tres files (e.g., `phoenix_ship.tres`).
   - `/database/config`: Tuning values (PID values, Constants).
4. `/scenes`: composed scenes (.tscn).
   - `/scenes/prefabs`: Reusable objects (Ships, Stations).
   - `/scenes/ui`: UI layouts.
   - `/scenes/levels`: World chunks.

ACTION 1: THE MIGRATION MANIFEST
Create a file `MIGRATION-PLAN.md`.
- List every folder in the current project and where it must move.
- Identify "Split Targets" (e.g., if `core/agents` has both `.gd` and `.tscn`, specify splitting them into `/src/agents` and `/scenes/prefabs/agents`).
- **CRITICAL:** Flag any `load("res://...")` hardcoded paths that will break and need string replacement.

ACTION 2: THE CONTENT MANUAL (The "API")
Create a file `CONTENT-CREATION-MANUAL.md`.
- This is for the "Designer/Artist" persona.
- Create a section "How to Add a New Item":
  1. ART: Place mesh in `/assets/models/...`
  2. DEFS: Duplicate template in `/database/registry/...`
  3. PREFAB: Inherit `base_item.tscn` in `/scenes/prefabs/...`
- Create a section "Tuning & Balance":
  - List where the global PID controllers and Constants live.

OUTPUT BEHAVIOR:
- **FILE ONLY:** Write `MIGRATION-PLAN.md` and `CONTENT-CREATION-MANUAL.md`.
- **SILENCE:** Do not output the files in chat.
- **CONFIRMATION:** "Migration Plan and Designer Manual generated. Please review `MIGRATION-PLAN.md` before we start moving files."
```

---

RECOVERY LOOP (If things break)

Trigger: If GPT-5.2 gets stuck or the code fails to run during Level 2 or 4. Model: GPT-5.2 (Deep Reasoning)
PROMPT FOR RECOVERY

```
ROLE: Senior Developer (Debug & Recovery Mode)
CONTEXT: We attempted to execute a task from 'IMMEDIATE-TODO.md', but encountered a critical failure.
ERROR/ISSUE: [PASTE GUT ERROR LOG OR DESCRIBE UNEXPECTED BEHAVIOR]

TASK: **Analyze, Fix, and Re-align.**

INSTRUCTIONS:
1. **Analyze:** specific error against the code in [TARGET FILE] and the plan in 'IMMEDIATE-TODO.md'.
2. **Diagnose:** Determine if this is a simple syntax/logic error OR a fundamental flaw in the plan (e.g., impossible dependency).
3. **Fix:** Rewrite the specific section of code causing the issue.
   - *Condition A:* If it's a code error, fix it directly.
   - *Condition B:* If the PLAN was wrong, **update 'IMMEDIATE-TODO.md'** to reflect the necessary change in strategy.
4. **Log:** Append a line to 'SESSION-LOG.md' describing the fix (e.g., "  - [FIX] Resolved circular dependency in [File].").

CONSTRAINTS:
- Do NOT refactor unrelated parts of the file.
- If the task is now actually complete and working, ensure 'IMMEDIATE-TODO.md' is marked with "- [x]".
- If the task is blocked by this error, mark it as "- [ ]" and add a "**BLOCKED:**" note next to it in the Todo file.

OUTPUT BEHAVIOR:
- **FILE ONLY:** Apply fixes directly to files.
- **SILENCE:** Do not explain the bug in depth.
- **CONFIRMATION:** Your only chat response should be: "Fix applied to [File]."
```
