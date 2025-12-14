#MODEL-CASCADE-PROTOCOL.md**Protocol for AI-Assisted Development Cascading**
**Context:** GDTLancer Project
**Files Required:**

1. `GDD-COMBINED-TEXT-frozen-*.md` (Read Only - Source of Truth)
2. `DEVELOPMENT-PLAN.md` (Read Only - High-level Roadmap)
3. `IMMEDIATE-TODO.md` (Read/Write - The Bridge / Task Ticket)
4. `SESSION-LOG.md` (Append Only - History of completion)

---

##LEVEL 1: THE ARCHITECT (Claude Opus 3.5/4.5)
**Trigger:** Start of a new Sprint, after a major feature completion, or when stuck on architectural direction.
**Input:** All documentation files + current file structure.
**Goal:** Update `IMMEDIATE-TODO.md` with precise, machine-readable instructions.

### PROMPT FOR OPUS
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
   - For each task, define the TARGET FILE.
   - Define the DEPENDENCIES (files the AI must read to understand the context).
   - Provide PSEUDO-CODE SIGNATURES for key functions (define inputs/outputs exactly).
   - Define SUCCESS CRITERIA (e.g., "Must pass test_trading.gd").
4. CONSTRAINTS: Specific architectural rules (e.g., "Do not use Resources here, use Nodes", "Connect to SignalBus").

DO NOT write the full implementation code. Write the "Ticket" that ensures the Senior Dev cannot misunderstand the architecture.

```

---

##LEVEL 2: THE BUILDER (GPT-5.2 / GPT-5-preview)
**Trigger:** Once `IMMEDIATE-TODO.md` is populated.
**Input:** The Todo list and the specific files mentioned in it.
**Goal:** Write the heavy logic and core implementation.

### PROMPT FOR GPT-5.2
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

Rewrite the code for the target file AND update markdown files.

```

---

##LEVEL 3: THE INTERN (GPT-4.1 / GPT-4o)
**Trigger:** After GPT-5.2 outputs code.
**Input:** The newly created/modified file.
**Goal:** Cleanup, Documentation, Unit Tests, and Logging.

### PROMPT FOR HAIKU
```
ROLE: QA Intern (Model: Haiku/Mini)
CONTEXT: Senior Dev just finished [TARGET FILE] (Check SESSION-LOG.md for name).
TASK: Polish and Test.

INSTRUCTIONS:
1. **Read & Polish:** Open [TARGET FILE]. Add strict types and docstrings. Fix format.
2. **Write Tests:** Update/Create `tests/unit/test_[filename].gd`.
   - MUST cover success paths + 1 edge case.
   - MUST use `autofree(node)` for cleanup.
3. **Log:** Append 1 line to 'SESSION-LOG.md'.

CRITICAL SYNTAX RULES (GODOT 3.x):
- NO `@export`, `@onready`. Use `export(int) var`, `onready var`.
- NO `await`. Use `yield(obj, "sig")`.
- NO `super()`. Use `.func()`.
- NO f-strings. Use `"%s" % var`.
- NO Typed Arrays `Array[int]`. Use `Array`.

Output the POLISHED CODE and the TEST FILE.

```

---

## RECOVERY LOOP (If things break)
**Trigger:** If GPT-5.2 gets stuck or the code fails to run.
**Model:** GPT-5.2 (Deep Reasoning)

### PROMPT FOR RECOVERY
```
ROLE: Senior Developer (Debug & Recovery Mode)
CONTEXT: We attempted to execute a task from 'IMMEDIATE-TODO.md', but encountered a critical failure.
ERROR/ISSUE: [PASTE ERROR LOG OR DESCRIBE UNEXPECTED BEHAVIOR]

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

Write the fixed code and update markdown files.

```
