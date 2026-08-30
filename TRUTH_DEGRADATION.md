<!--
PROJECT: GDTLancer
MODULE: TRUTH_DEGRADATION.md
STATUS: [Level 2 - Design]
OWNER: architect
ACCESS: read-write
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_PROJECT.md § Project Stack And Context; TRUTH_GAME-LOOP-VISION.md § 2
LOG_REF: 2026-08-30
-->

# GDTLancer — Degradation & Repair Mechanics

**Version:** 1.0
**Date:** 2026-08-30
**Status:** Initial Draft

---

## 1. Design Intent

Degradation is the primary source of **material entropy** in GDTLancer. It transforms the ship and its equipment from abstract inventory into a living, decaying system that demands constant care. Degradation serves the Mortality pillar (Exploration Pillar §8) and the failure cascade (Mode B failures degrade Mode A capabilities), while respecting the prohibition against ticking clocks of doom (Prohibited Seams §11).

Degradation is **action-driven, not time-driven.** Cards do not decay passively. They degrade as a consequence of player choices — using a card in a high-risk context, pushing deeper into dangerous territory, or neglecting maintenance during downtime.

---

## 2. Card Degradation Lifecycle

Every card with a persistent lifespan (Module, Field, Possession) has a **condition state** that follows a strict lifecycle:

```
Fresh → Degraded → Broken → Junk
```

| State | Effect | Reversible? |
|---|---|---|
| **Fresh** | Full effectiveness. No visual indicators. | N/A |
| **Degraded** | Reduced effectiveness. Visual wear indicator on card. Card remains usable but at diminished capability. | Yes — via Repair action. |
| **Broken** | Non-functional. Cannot be used for its intended purpose. Remains in collection as dead weight. | Yes — via Repair action (costlier than repairing Degraded). |
| **Junk** | Fully destroyed as its original form. Becomes a generic Junk card. Loses original tags and identity. | No — the original card is permanently lost. The resulting Junk card is a new entity. |

### Consumables Exception
Consumables are **single-use** and skip the degradation lifecycle entirely. They are expended on use and removed from the collection.

---

## 3. Stress Triggers

Cards degrade when subjected to **stress** — specific contextual conditions during board play:

- **High-risk board actions:** Using a Field Card on a board node tagged as dangerous or deep in an Exploration Board path.
- **Environmental hazards:** Events or board states that apply stress to equipped Module Cards.
- **Overuse:** **[TBD]** Whether repeated use in a single board session causes additional wear, or if stress is purely contextual.

### Stress Resolution
When a card is subjected to stress:
1. If **Fresh**, it becomes **Degraded**.
2. If **Degraded**, it becomes **Broken**.
3. If **Broken**, it becomes **Junk** (the original card is destroyed).

Stress is **binary per exposure** — a single stress event causes exactly one step of degradation. Multiple stress events in one board session can cause multiple steps.

---

## 4. Degradation Effects

### On Field Cards and Possessions
- **Degraded:** Any quantitative modifiers on the card are halved (round down, minimum 0). Tag-based effects still function but may be visually marked as unreliable.
- **Broken:** Card cannot be played on boards. Remains in collection but is functionally dead weight until repaired.

### On Module Cards (Ship Tableau)
- **Degraded:** The ship capability provided by this module operates at reduced effectiveness. The specific reduction depends on the module type. The Ship Tableau slot is visually marked.
- **Broken:** The ship capability is **removed entirely**. The slot shows as non-functional. If the ship drops below minimum operational modules, it is treated as a derelict hull (no Mode A capabilities).

Module Card degradation is the primary vector for the **failure cascade** (Mode B → Mode A).

---

## 5. Repair Mechanics

Repair is an explicit player action performed in the **Ship Interior** during downtime.

### Repair Cost
- **Degraded → Fresh:** Requires **1 Junk card** (consumed).
- **Broken → Fresh:** Requires **2 Junk cards** or **1 specific Possession card** with a matching repair tag (consumed).

### Repair Constraints
- Repair consumes **Per-Board-Session Clock ticks** (time cost).
- Repair is only available in the Ship Interior, not during external Contextual Boards.
- **[TBD]** Whether companions with specific tags can reduce repair costs or time.

---

## 6. Legacy Markers

Ship Tableau slots accumulate **Legacy Markers** over time, reflecting the cumulative repair history of that slot.

- Each time a Module Card in a slot is repaired from **Broken** state, the slot gains one Legacy Marker.
- Legacy Markers are **permanent** and tied to the slot, not the card.
- Legacy Markers are **visible** on the Ship Tableau as a visual history of the ship's wear.

### Marker Effects
- Legacy Markers have **no direct mechanical penalty.** They are a narrative record — a visual scar showing the ship's history.
- **[TBD]** Whether late-game content or anomalous events interact with Legacy Marker counts.

---

## 7. Relationship to Crafting

The degradation lifecycle feeds directly into the crafting economy:

- **Junk cards** (the terminal state of degradation) are the **universal crafting fuel.** They are never truly worthless.
- Deliberately breaking unwanted cards into Junk is a valid player strategy for fueling crafting and repair.
- The tag-pairing crafting system uses Junk as the base cost component. Failed crafting attempts also produce Junk.

This creates a closed loop: **Use → Degrade → Break → Junk → Craft/Repair → Use**.

---

## 8. Relationship to Failure Cascade

The degradation mechanic is the mechanical bridge between Mode B consequences and Mode A capabilities:

1. Player uses cards on boards (Mode B) → cards take stress → cards degrade.
2. Module Cards degrade in the Ship Tableau → ship capabilities diminish.
3. Ship drops below minimum operational modules → Mode A game-over (derelict hull).

**There is no Mode B hard game-over.** Failed boards always return the player to the Ship Interior in a degraded state. The only terminal state is Mode A hull failure.
