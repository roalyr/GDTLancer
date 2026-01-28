## PREREQUISITE: Project-Wide Naming Standardization

Per GDD Section 7 (Platform Mechanics Divergence), the Digital version uses specific terminology that differs from Analogue. The codebase currently mixes terms. This must be resolved before new features.

### NAMING AUDIT FINDINGS:

| Category | GDD Digital Term | Current Code Term | Status |
|----------|------------------|-------------------|--------|
| Currency | `credits` | `wealth_points`, `wp`, `WP` | RENAME |
| Currency signals | `player_credits_changed` | `player_wp_changed` | RENAME |
| Time | `game_time` (real seconds) | `tu`, `TU`, `current_tu` | RENAME |
| Equipment folder | `tools/` | `weapons/` | RENAME |
| Equipment files | `tool_*.tres` | `weapon_*.tres` | RENAME |
| Equipment component | `tool_controller.gd` | `weapon_controller.gd` | RENAME |
| Focus Points | (stub/remove for Digital) | `focus_points`, `fp` | KEEP (Analogue compat) |

### NAMING STANDARDIZATION TASKS:

- [x] NAMING_1: Rename currency from WP to Credits (Section 7 Platform Mechanics Divergence)
  - Files: `database/definitions/character_template.gd`
    - `wealth_points` → `credits`
  - Files: `database/definitions/contract_template.gd`
    - `reward_wp` → `reward_credits`
  - Files: `src/core/systems/character_system.gd`
    - `add_wp()` → `add_credits()`
    - `subtract_wp()` → `subtract_credits()`
    - `get_wp()` → `get_credits()`
  - Files: `src/autoload/EventBus.gd`
    - `player_wp_changed` → `player_credits_changed`
  - Files: All UI scripts referencing WP signals/labels
  - Files: `src/autoload/GameState.gd`
    - `total_wp_earned` → `total_credits_earned`
    - `total_wp_spent` → `total_credits_spent`

- [x] NAMING_2: Rename time units from TU to game_time (seconds)
  - Files: `src/autoload/GameState.gd`
    - `current_tu` → `game_time_seconds`
  - Files: `src/autoload/Constants.gd`
    - `TIME_CLOCK_MAX_TU` → `WORLD_TICK_INTERVAL_SECONDS`
  - Files: `database/definitions/contract_template.gd`
    - `time_limit_tu` → `time_limit_seconds`
    - `accepted_at_tu` → `accepted_at_seconds`
  - Files: `src/autoload/EventBus.gd`
    - `time_units_added` → `game_time_advanced`
  - Files: `src/core/systems/time_system.gd` - update all TU references

- [x] NAMING_3: Rename weapons folder/files to tools
  - Folder: `database/registry/weapons/` → `database/registry/tools/`
  - Files: `weapon_ablative_laser.tres` → `tool_ablative_laser.tres`
  - Files: `weapon_harpoon.tres` → `tool_harpoon.tres`
  - Files: `weapon_rotary_drill.tres` → `tool_rotary_drill.tres`
  - Files: `src/core/agents/components/weapon_controller.gd` → `tool_controller.gd`
  - Update all scene references to WeaponController → ToolController
  - Update TemplateDatabase scan paths

- [x] NAMING_4: Update UI display strings
  - Files: `src/core/ui/narrative_status/narrative_status_panel.gd`
    - "Total WP Earned" → "Total Credits Earned"
  - Files: `scenes/ui/screens/*.tscn` - label text updates
    - "Current WP:" → "Credits:"
    - "Current FP:" → (keep for Analogue, or hide in Digital)

- [x] NAMING_5: Update TRUTH_CONTENT-CREATION-MANUAL.md
  - Update all references to match new naming conventions
  - Update directory structure references

- [x] NAMING_VERIFICATION:
  - Run `grep -r "wealth_points\|_wp\|WP" src/` - should return 0 hits (except FP)
  - Run `grep -r "current_tu\|_tu\b" src/` - should return 0 hits
  - Run `grep -r "weapon_" database/registry/` - should return 0 hits
  - Run all GUT tests to ensure no regressions
  - Manual test: Launch game, check UI labels show "Credits" not "WP"

---

## CURRENT GOAL: Implement Contact & Faction Data Layer

- TARGET_FILES:
  - `database/definitions/faction_template.gd`
  - `database/definitions/contact_template.gd`
  - `database/registry/factions/faction_miners.tres`
  - `database/registry/factions/faction_traders.tres`
  - `database/registry/factions/faction_independents.tres`
  - `database/registry/contacts/contact_kai.tres`
  - `database/registry/contacts/contact_vera.tres`
  - `src/autoload/GameState.gd`
  - `src/core/systems/world_generator.gd` (or equivalent initialization)
  - `src/core/ui/narrative_status/narrative_status_panel.gd`

- TRUTH_RELIANCE:
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md` Section 0.1 Glossary (Contact, Faction definitions)
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md` Section 2.1 Phase 1 Scope: "Interact with named Contacts... building Relationship score"
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md` Section 2.1 Phase 1 Scope: "Take on contracts from different Factions, affecting Faction Standing"
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md` Section 2.1 Milestone 2: "Implement basic UI screens to display narrative stub info (Contact Dossier, Faction Standing)"
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md` Section 3 (Architecture): Stateless system pattern, Resource templates

- TECHNICAL_CONSTRAINTS:
  - Godot 3.x, GLES2 - use `export var` NOT `@export`
  - All templates must extend `Template` base class (see `database/definitions/template.gd`)
  - Faction IDs must match existing references: `faction_miners`, `faction_traders`, `faction_independents`
  - GameState is Source of Truth; systems are stateless APIs
  - Follow established naming: `snake_case` for variables, `PascalCase` for class_name
  - No `@onready` or `await` syntax (Godot 3)

- ATOMIC_TASKS:
  - [x] TASK_1: Create `faction_template.gd` definition
    - Location: `database/definitions/faction_template.gd`
    - Signature: `extends Template`, `class_name FactionTemplate`
    - Properties: `export var faction_id: String`, `export var display_name: String`, `export var description: String`, `export var faction_color: Color`

  - [x] TASK_2: Create `contact_template.gd` definition
    - Location: `database/definitions/contact_template.gd`
    - Signature: `extends Template`, `class_name ContactTemplate`
    - Properties: `export var contact_id: String`, `export var display_name: String`, `export var description: String`, `export var faction_id: String`, `export var location_id: String`
    - Reference: GDD Glossary - "Contact: An abstract NPC the player interacts with via menus"

  - [x] TASK_3: Create faction .tres registry files
    - Location: `database/registry/factions/`
    - Files: `faction_miners.tres`, `faction_traders.tres`, `faction_independents.tres`
    - Must match existing `faction_id` references in contracts and locations

  - [x] TASK_4: Create starter Contact .tres files
    - Location: `database/registry/contacts/`
    - Files: `contact_kai.tres` (faction_miners), `contact_vera.tres` (faction_traders)
    - Minimum 2 contacts per GDD Section 2.1 ("2-3 named Contacts")

  - [x] TASK_5: Add `factions` and `contacts` dictionaries to GameState.gd
    - Signature: `var factions: Dictionary = {}` (Key: faction_id, Value: FactionTemplate)
    - Signature: `var contacts: Dictionary = {}` (Key: contact_id, Value: ContactTemplate)
    - Initialize `narrative_state.faction_standings` with known faction_ids on game start

  - [x] TASK_6: Update world initialization to seed faction standings
    - Location: World generator or GameStateManager initialization flow
    - Logic: On new game, iterate registered factions and set `narrative_state.faction_standings[faction_id] = 0`
    - Ensure `known_contacts` is populated when player visits a location with a Contact

  - [x] TASK_7: Update NarrativeStatusPanel to display faction data properly
    - Location: `src/core/ui/narrative_status/narrative_status_panel.gd`
    - Update `_update_factions()` to lookup FactionTemplate for display_name
    - Format: "Miners Guild: +5" instead of "faction_miners: 5"

  - [x] TASK_8: Register factions/contacts in TemplateDatabase
    - Ensure TemplateDatabase scans `database/registry/factions/` and `database/registry/contacts/`
    - Or add manual loading to existing initialization

  - [x] VERIFICATION:
    - Launch game, open Narrative Status Panel (Tab or HUD button)
    - Confirm Faction Standing section shows all 3 factions with display names
    - Confirm no "No known factions" message when factions are registered
    - Run existing tests: `res://tests/` - ensure no regressions
    - Manual test: Complete a contract, verify faction_standings updates for contract's faction_id
