<!--
PROJECT: GDTLancer
MODULE: TRUTH_PROJECT.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Automated Testing Boundary
LOG_REF: 2026-05-26 13:53:58
-->

## Project Stack And Context

- Project: GDTLancer
- Platform (primary): Godot3 (3.6 stable)
- Graphics: GLES2 (for performance and compatibility)
- Additional: Python3 (for sandbox)

## Automated Testing Boundary

### Must Stay In GUT

- Public signatures, initialization contracts, serialization/save-load shape, scene/resource/template loading guarantees, and other stable API or data-shape invariants.
- Exact tick order, system handoff contracts, report/request plumbing, and deterministic event-packet or occurrence-dictionary structure.
- Locally seeded mechanic gates whose intent is stable even when balance changes, such as "must require a gate", "must preserve uniqueness", "must retain one security tag", or "must respect a blocking condition".
- Narrow deterministic unit or integration checks whose fixtures are locally owned and do not depend on long-run emergent world metrics or broad registry state.

### Must Stay Manual

- Live balance, long-run world reasonableness, narrative texture, discovery volume, sector mix, topology aesthetics, naming taste/readability, and other emergent qualities tuned through focused/composite chronicle review.
- Broad smoke tests whose primary claim is only that "the live simulation ran for N ticks" without protecting a specific contract.
- Automated 300-3000 tick full-environment harnesses for simulation balance. Manual chronicle review is the authoritative validation surface for that class of behavior.

### Authoring Rules

- If a mechanic is deterministic but its exact threshold or pacing is an active rebalance seam, GUT should assert the gate or direction of change, or derive the effective threshold from the live code path, instead of pinning stale tuned numbers unless that number is itself a truth-level contract.
- Prefer exact-file or narrow-folder GUT runs over broad suite execution while iterating on rebalance-heavy systems, and keep fixtures locally seeded so unrelated registry/template refactors do not create false failures.
- When a test fails because the project intentionally rebalanced a live tuning seam, rewrite or remove the balance-coupled assertion rather than forcing the runtime back to an obsolete metric.