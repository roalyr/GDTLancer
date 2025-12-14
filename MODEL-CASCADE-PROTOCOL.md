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
@workspace
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
3. ATOMIC TASKS: Break the work down into numbered steps (Task 1, Task 2, etc.).
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
@workspace
ROLE: Senior Python/Godot Developer
CONTEXT: You are executing the plan defined in 'IMMEDIATE-TODO.md'.
TASK: We are tackling [INSERT TASK NUMBER/NAME HERE] from the immediate todo list.

INSTRUCTIONS:
1. Read 'IMMEDIATE-TODO.md' to understand the specific requirements, signatures, and constraints for this task.
2. Read the DEPENDENCY files listed in the task to understand the existing APIs you must connect to.
3. Implement the solution for the TARGET FILE. 

CONSTRAINTS:
- Follow the signatures defined in the Todo file exactly.
- Do not hallucinate new architectural patterns; stick to the plan.
- Focus on the implementation logic. Do not worry about docstrings or extensive unit testing yet (the Junior Dev will handle that).
- If the file is large, implement it in logical chunks (e.g., "Properties and Init", then "Core Methods").

Output the code for: [INSERT TARGET FILE NAME]

```

---

##LEVEL 3: THE INTERN (GPT-4.1 / GPT-4o)
**Trigger:** After GPT-5.2 outputs code.
**Input:** The newly created/modified file.
**Goal:** Cleanup, Documentation, Unit Tests, and Logging.

### PROMPT FOR GPT-4.1
```
@workspace
ROLE: QA Engineer & Junior Developer
CONTEXT: The Senior Dev has just implemented code in [INSERT FILE NAME].
TASK: Polish, Test, and Log.

ACTION 1: CODE POLISH
- Review the new code. Add Pythonic/GDScript docstrings to all functions explaining arguments and returns.
- Check for obvious syntax errors or unused imports.
- Fix minor formatting issues (indentation, naming conventions).

ACTION 2: UNIT TESTS
- Create or update the corresponding test file (e.g., 'tests/unit/test_[filename].gd').
- Write comprehensive tests covering success paths, edge cases, and failure states based on the logic you see.
- Ensure all tests use the 'autofree' utility to prevent memory leaks.

ACTION 3: LOGGING
- Append a brief summary of what was completed to 'SESSION-LOG.md'. Format it as:
  "- [Date] [Sprint X] Implemented [Feature]. Passed [N] tests."

Output the polished code and the new test file.

```

---

## RECOVERY LOOP (If things break)
**Trigger:** If GPT-5.2 gets stuck or the code fails to run.
**Model:** GPT-5.2 (Deep Reasoning)

### PROMPT FOR RECOVERY
```
@workspace
ROLE: Senior Developer (Debug Mode)
CONTEXT: We attempted to implement Task [X] from 'IMMEDIATE-TODO.md', but encountered issues.
ERROR/ISSUE: [PASTE ERROR LOG OR DESCRIBE UNEXPECTED BEHAVIOR]

TASK:
1. Analyze the 'IMMEDIATE-TODO.md' again to ensure we didn't miss a constraint.
2. Analyze the current code in [FILE NAME].
3. Identify the logical flaw or syntax error.
4. Rewrite the specific function or section causing the issue. DO NOT refactor the whole file if not necessary.

```
