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


### REV_010: Hardened Narrative Content Delivery

- Domain: Content Pipeline and Chronicle
- Live Reality: There is no narrative content delivery system. NPC interaction surfaces a trade panel with raw data. No hand-authored narrative templates exist.
- Frozen / Legacy Tension: The frozen GDD describes a Chronicle layer (Layer 4) for event capture and narrative, but the implementation model is unspecified.
- Approved Direction: Narrative prose is not procedurally generated. The local sector's Grid layer tags are combined into a deterministic key string that queries a static, hand-authored directory of `.tres` resource templates. Content is authored in the sector's practical jargon creole. This enforces authored quality and prevents LLM or procedural text generation from entering the player-facing narrative layer.
- Status: Approved direction
- Blocked By: REV_009
- Evidence: STRATEGICAL-TODO.md §2.2

### REV_014: Prohibited Seams Registry

- Domain: Scope Control
- Live Reality: There is no formal registry of explicitly banned feature categories. Scope control relies on `TACTICAL_TODO.md` contract boundaries and architect judgment.
- Frozen / Legacy Tension: The frozen GDD includes various feature descriptions (ship modules, detailed market UIs, equipment crafting) that are now out of scope but not formally prohibited.
- Approved Direction: Establish a permanent, truth-level prohibited seams list. Initial entries: (1) No speculative market displays — player-facing trade uses Wealth Track increments and Contract Value Classes, never raw credit integers; (2) No 3D on-foot navigation — all station-side interaction is 2D grid-aligned Chronicle View menus. Future prohibited seams are added to this registry by architect directive only.
- Status: Approved direction
- Blocked By: None
- Evidence: STRATEGICAL-TODO.md §5


## Usage Notes

- This file is an architect and design staging surface, not the active implementation queue.
- `TACTICAL_TODO.md` remains the only active sprint contract.
- When a later milestone formalizes one of these entries, move the ledger entry to the archived ledger.
