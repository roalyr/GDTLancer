<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary
LOG_REF: 2026-06-06 01:10:00
-->

## CURRENT GOAL: Truth Alignment: Commodity Classification and Market Dynamics

- TARGET_SCOPE: Integrate the finalized Commodity Classification architecture (Phases 1-3) into the content creation manual, reflecting the new dynamic tag-aware restock baselines and dynamic pricing elasticity, and update the GDD revision ledger's milestone status.
- TARGET_FILES:
  - TRUTH_CONTENT-CREATION-MANUAL.md — Update Section 4.3 with the new Phase 3 market restock and dynamic pricing rules.
  - GDD-REVISION-LEDGER.md — Update the Follow-on Milestone Order to reflect that the Commodity Classification milestones are completed.
- TRUTH_RELIANCE: ["commodity_classification_architecture.md", "SESSION-LOG.md"]
- TECHNICAL_CONSTRAINTS: ["Strictly align documentation with the already-implemented Phase 3 features.", "Do not propose new gameplay features."]
- OUT_OF_SCOPE: Any code changes or implementation of Phase 4.
- PREAPPROVED_ADJACENT_OWNERS:
  - SESSION-LOG.md
- VALIDATION_PLAN: Review the text of the touched markdown files to ensure accuracy.
- MANUAL_VALIDATION: None required.
- ATOMIC_TASKS:
  - [x] TASK_1: Update `TRUTH_CONTENT-CREATION-MANUAL.md` Section 4.3 (Economy Balance). Remove mentions of `MARKET_RESTOCK_MAX_QUANTITY`. Document that restocking pulls toward a tag-aware baseline, and document the new dynamic price elasticity modifier based on current stock versus baseline.
  - [x] TASK_2: Update `GDD-REVISION-LEDGER.md` Follow-on Milestone Order. Mark "Commodity Classification Registry & Tag-Governed Market Seeding" as (Completed). Keep the subsequent milestones (like "Lawful / Unlawful Market Simulation") as the next steps.
  - [x] VERIFICATION: Review both markdown files for clarity, correct constants, and proper milestone status.
