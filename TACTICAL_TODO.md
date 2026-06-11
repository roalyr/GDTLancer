<!--
PROJECT: GDTLancer
MODULE: TACTICAL_TODO.md
STATUS: [Level 2 - Implementation]
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_PROJECT.md § Workflow And Scope Boundary; TRUTH_PROJECT.md § Agent Parity Principle; MODEL-CASCADE-PROTOCOL.md § Role: Lead Systems Architect; GDD-REVISION-LEDGER.md REV_007; GDD-REVISION-LEDGER.md REV_008
LOG_REF: 2026-06-11 20:05:00
-->

## COMPLETED: Clamp credit mutations to prevent negative credits and enforce strict non-negativity
- [x] TASK_1: Update `subtract_credits` in `character_system.gd` to set the character's credits to `max(0, GameState.characters[character_uid].credits - amount)`.
- [x] TASK_2: Add a unit test `test_credits_clamping` in `test_character_system.gd` that starts a character with 100 credits, subtracts 150, and asserts that the remaining balance is `0` rather than `-50`.
- [x] VERIFICATION: Full test suite passed — 391/391 tests passed successfully.

---

## CURRENT GOAL: Trust-Gated Credit vs Specie Transaction Routing
- TARGET_SCOPE: Introduce affinity-based payment routing into agent-to-agent and agent-to-station transactions so that credit payments are only accepted when faction trust is sufficient. Below the trust threshold, transactions must route through `commodity_specie` instead. Factionless agents (no faction tag on either side) always route through specie unconditionally. This is Layer 1 of the approved dual-economy growth path (GDD-REVISION-LEDGER.md REV_008).
- TARGET_FILES:
  - `src/autoload/Constants.gd` — Add `CREDIT_TRUST_THRESHOLD` constant (float, range 0.0–1.0, represents the minimum affinity score for credit acceptance).
  - `src/core/simulation/agent_layer.gd` — Add `_resolve_payment_instrument(payer_tags, payee_tags) -> String` helper returning `"credits"` or `"specie"` based on affinity and faction tag presence. Wire into `_bilateral_trade`, `_attempt_npc_market_buy`, and `_attempt_npc_market_sell` at the payment step.
  - `src/tests/core/simulation/test_agent_layer.gd` — Add focused unit tests: same-faction pair routes through credits; cross-faction pair below threshold routes through specie; factionless agent always routes through specie regardless of affinity.
- TRUTH_RELIANCE: GDD-REVISION-LEDGER.md REV_007 § Approved Direction; GDD-REVISION-LEDGER.md REV_008 § Approved Direction; TRUTH_SIMULATION-GRAPH.md §2.2.1; TRUTH_SIMULATION-GRAPH.md §8.1; TRUTH_PROJECT.md § Agent Parity Principle
- TECHNICAL_CONSTRAINTS: "Forbidden GDScript syntax: @export, @onready, await", "Graphics target GLES2", "Godot 3.6 stable compatibility"
- OUT_OF_SCOPE: Multiple credit ledgers per faction, exchange rate mechanics, credit supply ceilings, specie surcharge amounts, player UI credit display changes, faction treasury tags, contract reward currency selection (Layer 2/3 concerns).
- PREAPPROVED_ADJACENT_OWNERS:
  - `src/core/simulation/affinity_matrix.gd` — read-only: use existing `compute_affinity()` signature; do not extend tags or scoring without a contract rewrite.
- VALIDATION_PLAN:
  - `_resolve_payment_instrument` unit tests cover: allied pair → credits, hostile pair → specie, factionless sender → specie, factionless receiver → specie.
  - Existing `_bilateral_trade` and dock-market tests must continue passing without regression.
- MANUAL_VALIDATION: Chronicle output from a multi-tick session should show NPC trade events routing through specie when cross-faction pairs interact. No automated coverage required.
- ATOMIC_TASKS:
  - [ ] TASK_1: Add `CREDIT_TRUST_THRESHOLD = 0.3` constant to `Constants.gd`. Value is tunable; 0.3 means any affinity score at or above 0.3 accepts credits.
  - [ ] TASK_2: Add `_resolve_payment_instrument(payer_tags: Array, payee_tags: Array) -> String` to `agent_layer.gd`. Returns `"credits"` if both sides have at least one faction tag AND `affinity_matrix.compute_affinity(payer_tags, payee_tags) >= Constants.CREDIT_TRUST_THRESHOLD`; returns `"specie"` otherwise.
  - [ ] TASK_3: Wire `_resolve_payment_instrument` into `_bilateral_trade` and both `_attempt_npc_market_buy` / `_attempt_npc_market_sell` so the payment leg uses the resolved instrument. When instrument is `"specie"`, deduct from payer's `commodity_specie` inventory and add to payee's `commodity_specie` inventory instead of mutating `credits`.
  - [ ] TASK_4: Add focused unit tests in `test_agent_layer.gd` covering: same-faction above threshold → credits, cross-faction below threshold → specie, factionless payer → specie, factionless payee → specie.
  - [ ] VERIFICATION: Run the full test suite using GUT; ensure all tests pass with zero failures.
