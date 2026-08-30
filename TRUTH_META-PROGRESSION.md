<!--
PROJECT: GDTLancer
MODULE: TRUTH_META-PROGRESSION.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_EXPLORATION-PILLARS.md § 8
LOG_REF: 2026-08-30
-->

# GDTLancer — Meta-Progression (Between Runs)

**Version:** 1.0
**Date:** 2026-08-30
**Status:** Initial Draft (Post-M41 Scope)

---

## 1. Design Intent

When attrition ends a run (Mode A game-over from hull failure or resource depletion), the game does not reset to zero. A meta-progression layer ensures each new beginning builds on the past, rewarding deep exploration and meaningful choices across multiple playthroughs.

Meta-progression serves Exploration Pillar §8 (Mortality) and is constrained by:
- **No loot grinding or number scaling** (Prohibited Seams §6). Inheritance must not create power creep.
- **Lateral progression** (Exploration Pillar §3). Inherited assets expand options, not inflate numbers.
- **No ticking clock of doom** (Prohibited Seams §11). Run-ending is a consequence of material failure, not timer expiry.

> **Scope Note:** Meta-progression is explicitly deferred to post-M41. This document establishes the design boundaries so that M30–M41 milestones do not accidentally build infrastructure that conflicts with the eventual system.

---

## 2. Run-Ending Conditions

A run ends when the player's ship can no longer physically function in Mode A:
- **No minimum operational Module Cards** (all modules broken/junk, ship is a derelict hull).
- **Critical resource depletion.** **[TBD]** Specific resources that constitute terminal failure.

Run-ending is **never** caused by:
- Biological aging or a lifespan timer.
- A single failed board encounter (Mode B always returns to Ship Interior).
- Companion death alone (though it may cascade into material failure).

---

## 3. What Persists Between Runs

### Unlocked Starting Conditions
New runs can begin with expanded options based on prior achievements:
- **New ships:** Vessel types unlocked by reaching specific sectors or completing specific conditions.
- **New crew archetypes:** Companion personality types or starting bond configurations.
- **New starting locations:** Origin points deeper in the network (for experienced players who choose to skip early content).

### Inherited Assets
A limited selection of tangible items carries forward:
- **Legacy Cards:** Specific cards designated by the player before run-end (or automatically selected from the collection). These retain their condition state.
- **[TBD]** Exact number of inheritable cards and selection mechanism.
- **[TBD]** Whether Memorial Cards (from companion deaths) carry forward and serve a late-game function.

### What Does NOT Persist
- Numerical progress, stat inflation, or cumulative power bonuses.
- The full card collection. Only the designated Legacy Cards survive.
- Bond tracks. Companions from prior runs are gone unless re-encountered as new NPCs (not guaranteed).
- Ship Tableau configuration. New run starts with a new (or unlocked) ship.

---

## 4. Constraints on Inheritance

- Inherited assets must not grant a **decisive mechanical advantage** over a fresh start. They expand the verb space (lateral progression), not the power level.
- A player starting their fifth run should have **more options** but not be **stronger** than a first-run player in equivalent situations.
- **[TBD]** Whether inherited cards degrade faster in subsequent runs to prevent hoarding across generations.

---

## 5. Implementation Boundary

This system does **not** need to be implemented for M41 (Playable Vertical Slice). The vertical slice demonstrates a single complete run loop.

However, the following systems should be designed with meta-progression compatibility in mind:
- **GameStateManager** (save/load shape must accommodate run-boundary markers).
- **Card Collection** (must support tagging cards as "legacy-eligible").
- **Ship Tableau** (must support resetting to a new ship while preserving run history metadata).
