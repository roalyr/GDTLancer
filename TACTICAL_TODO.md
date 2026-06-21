## CURRENT GOAL: Milestone 11 (Hardened Narrative Content Pipeline)
- TARGET_SCOPE: Implement the narrative content delivery system (REV_010). Narrative prose is not procedurally generated; instead, the local sector's tags are used to query a static, hand-authored directory of `.tres` resource templates. Establish the sub-folder directory structure for template lookup (`templates/{sector_type}/{economy_tag}/{security_tag}/{event_type}.tres`).
- TARGET_FILES:
  - `src/core/systems/narrative_system.gd` (or similar new system script) — to handle the querying and delivery of narrative templates based on sector tags.
  - `database/registry/narrative_templates/` — define the sub-folder structure and create initial `.tres` stubs for testing the pipeline.
  - `src/core/ui/chronicle_view.gd` (or similar UI script) — integrate the narrative system to display the text in the Chronicle View.
- TRUTH_RELIANCE:
  - `STRATEGICAL-TODO.md` § REV_010 & Design Question Log 3
  - `TRUTH_CONTENT-CREATION-MANUAL.md` (for the narrative jargon guidelines)
- TECHNICAL_CONSTRAINTS:
  - Godot 3.6 stable compatibility.
  - Forbidden GDScript syntax: `@export`, `@onready`, and `await`.
  - Content lookup must be deterministic and grid-driven.
- ATOMIC_TASKS:
  - [x] TASK_1: **Architecture & Data Schema.** Define the `NarrativeTemplate` resource script (`.gd`) with fields for title, body text, and any required gating parameters. Establish the exact directory structure pattern.
  - [x] TASK_2: **Implement Narrative Query Engine.** Build the system that takes current sector tags (sector_type, economy_tag, security_tag) and the specific event_type to resolve the correct `.tres` file path. Handle fallbacks gracefully.
  - [x] TASK_3: **Authored Stubs.** Create at least 3 distinct narrative template `.tres` files in the new directory structure using the Lore Lexicon to verify the lookup engine.
  - [x] TASK_4: **Chronicle View Integration.** Wire the query engine into the UI so that interaction events or sector entries request and display the correct narrative prose.
  - [x] VERIFICATION: Write headless GUT tests verifying the path resolution logic and fallback behavior of the narrative query engine. Ensure all tests pass.

