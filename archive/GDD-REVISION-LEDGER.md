<!--
PROJECT: GDTLancer
MODULE: GDD-REVISION-LEDGER.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: STRATEGICAL-TODO.md
LOG_REF: 2026-06-20 20:31:00
-->

# GDD Revision Ledger - GDTLancer

Purpose: This file is the architect-owned staging surface for approved live-vs-frozen doctrine changes. It does not replace `TACTICAL_TODO.md`, and it does not retroactively rewrite frozen truth docs in place. Each approved entry exists to keep future milestones aligned with the live codebase and the intended setting direction until a later truth or GDD rewrite formalizes it.

## Ledger Rules

- **Only Unimplemented Revisions:** The active root-level ledger (`GDD-REVISION-LEDGER.md`) must only contain revisions that are not yet implemented in code.
- **Archival Policy:** Once a milestone implements a set of revisions, those revisions are moved to an archived ledger file under `/archive/` (e.g. [archive/GDD-REVISION-LEDGER-1.md](archive/GDD-REVISION-LEDGER-1.md)), and are removed from this active ledger to avoid duplication and bloat.
- **First 8 Revisions:** Revisions `REV_001` through `REV_008` are already implemented in the baseline GDD. These are preserved only in the archived ledger and must not be duplicated in the active ledger.

## Entry Schema

For each revision entry, use the same fields:

- `Domain`
- `Live Reality`
- `Frozen / Legacy Tension`
- `Approved Direction`
- `Status`
- `Blocked By`
- `Evidence`

## Approved Revisions

> [!NOTE]
> **Active Ledger Only:** This file contains only revisions that are not yet implemented in code (starting from `REV_010`). Previously implemented revisions (`REV_001` through `REV_009` and `REV_011`-`REV_013`) have been moved to the archived ledger: [archive/GDD-REVISION-LEDGER-1.md](archive/GDD-REVISION-LEDGER-1.md).


### REV_015: Solo TTRPG & Emergent Narrative Pivot

- Domain: Core Gameplay Loop & UI
- Live Reality: Previous designs assumed "contracts" as mechanical tasks picked from a board, and morale as a numerical modifier/lockout.
- Frozen / Legacy Tension: The project risks feeling like a mechanical spreadsheet rather than a living world if tasks are just picked from a menu.
- Approved Direction: Shift fully to a Solo TTRPG experience. The environment applies pressure (via GridLayer tags), and the player defines their goals. Remove the "Contract Board" concept entirely; tasks and opportunities emerge organically from interacting with actors or reacting to environmental events. Morale drops trigger narrative consequences and story beats (e.g., mutiny standoffs) rather than flat mathematical grinding. No linear hand-crafted missions.
- Status: Approved direction
- Blocked By: None
- Evidence: MVP_CORE_IMPLEMENTATION_PROPOSAL.md


## Usage Notes

- This file is an architect and design staging surface, not the active implementation queue.
- `TACTICAL_TODO.md` remains the only active sprint contract.
- When a later milestone formalizes one of these entries, move the ledger entry to the archived ledger.
