<!--
PROJECT: GDTLancer
MODULE: TRUTH-ORACLES.md
STATUS: [Level 1 - Core Truth] DRAFT
OWNER: architect
ACCESS: read-only-owner
USER INSTRUCTION: NONE
TRUTH_LINK: TRUTH_RULEBOOK.md; TRUTH_LORE-CONSTRAINTS.md
LOG_REF: 2026-07-07
-->

# GDTLancer — Oracle Tables

**Version:** 0.1 (Draft)
**Date:** 2026-07-07
**Status:** Draft — Expandable during play

---

## 0. How Oracles Work

**Oracles are a free action.** They do not consume a game action, do not advance the World Clock, and do not cost resources. They are a creative aid — available whenever the player or GM needs inspiration.

**When to use:**
- Declaring a goal (§2.3) — roll Action + Theme for a goal seed.
- Generating NPC concerns — roll Focus + Theme.
- When the player asks "what happens next?" — roll any combination.
- When the GM needs to populate a community or sector — roll Focus.

**How to roll:** Roll 2d6. First die = row, second die = column. Read the result from the table. Roll on multiple tables and combine keywords to build a cue.

**Interpretation is always the player's job.** The oracle gives raw words. The player decides what they mean in context.

---

## 1. Action Oracle (What is happening)

|   | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| **1** | Secure | Deliver | Repair | Search | Protect | Negotiate |
| **2** | Abandon | Salvage | Investigate | Shelter | Warn | Share |
| **3** | Withhold | Return | Prepare | Endure | Confront | Escape |
| **4** | Restore | Gather | Conceal | Support | Challenge | Observe |
| **5** | Mend | Provide | Request | Defy | Commit | Sacrifice |
| **6** | Navigate | Anchor | Harvest | Ration | Settle | Depart |

---

## 2. Theme Oracle (Why it matters)

|   | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| **1** | Scarcity | Trust | Obligation | Survival | Isolation | Kinship |
| **2** | Debt | Legacy | Pride | Loss | Hope | Betrayal |
| **3** | Exhaustion | Renewal | Rivalry | Community | Sacrifice | Authority |
| **4** | Fear | Gratitude | Ambition | Loyalty | Decay | Discovery |
| **5** | Burden | Freedom | Tradition | Change | Belonging | Exile |
| **6** | Desperation | Resilience | Secrecy | Honor | Grief | Opportunity |

---

## 3. Focus Oracle (What is involved)

|   | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| **1** | Vessel | Community | Bond | Resource | Route | Equipment |
| **2** | Crew | Cargo | Station | Sector | Stranger | Elder |
| **3** | Family | Signal | Wreck | Claim | Water | Fuel |
| **4** | Parts | Shelter | Path | Reputation | Secret | Promise |
| **5** | Disease | Storm | Child | Pilot | Debt | Tool |
| **6** | Dock | Tunnel | Relay | Seal | Hull | Anchor |

---

## 4. Usage Examples

**Goal creation:** Roll Action + Theme → "Restore" + "Belonging" → *"Restore Elace's sense of belonging among the outer settlements."*

**NPC concern:** Roll Focus + Theme → "Water" + "Scarcity" → *Water rationing is the concern on everyone's mind.*

**Event seed:** Roll Action + Focus → "Confront" + "Stranger" → *An unknown person has arrived and there is tension.*

**Combination:** Roll all three → "Salvage" + "Legacy" + "Wreck" → *An old wreck has been found. Someone's family history is tied to it.*

---

## 5. NPC Disposition Oracle (What is their mood)

Simple 1d6 roll. Use when interacting with an NPC and you need to establish their current state.

| Roll | Disposition |
|---|---|
| 1 | Worried |
| 2 | Hopeful |
| 3 | Frustrated |
| 4 | Calm |
| 5 | Eager |
| 6 | Distant |

---

## 6. Conversation Seed Oracle (What do they want to discuss)

Use when you need a prompt for what an NPC conversation is about. Roll d6×d6.

|   | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| **1** | A plan | A worry | A favor | A memory | A rumor | A warning |
| **2** | A debt | A promise | A question | A regret | A hope | A grudge |
| **3** | A change | A loss | A secret | A proposal | A complaint | An offer |
| **4** | A child | A route | A shortage | A stranger | A departure | A return |
| **5** | A vessel | A skill | A mistake | A tradition | A conflict | A celebration |
| **6** | The future | The past | A place | A name | A price | A silence |

---

## Appendix: Expansion Notes

This file is designed to grow. Future tables may include:

- **Sector Feature** — what makes a location distinct
- **Complication** — what goes wrong
- **Opportunity** — what opens up

Tables must stay within lore constraints (TRUTH_LORE-CONSTRAINTS.md). No institutions, no military ranks, no power-fantasy vocabulary.

> `[FEEDBACK]` Did the oracle tables produce useful cues? Were any entries too vague or too specific? Which new tables would be most useful?
>
> `[IMPL NOTE]` Maps to: Oracle button in Mode B UI, random keyword generator, goal creation assistant.
