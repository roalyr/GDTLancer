## CURRENT GOAL: Implement Persistent Agent System & Contacts Panel

- TARGET_FILES:
  - `database/definitions/agent_template.gd` (extend with persistence flag)
  - `database/definitions/character_template.gd` (extend with personality properties)
  - `database/registry/agents/persistent_*.tres` (new - 2 Persistent Agents per faction)
  - `database/registry/characters/character_*.tres` (new - CharacterTemplates for all persistent agents)
  - `src/autoload/GameState.gd` (add persistent_agents tracking)
  - `src/autoload/EventBus.gd` (add contact_met signal)
  - `src/core/systems/agent_system.gd` (add persistent agent spawning/respawn logic)
  - `src/core/ui/contacts_panel/contacts_panel.gd` (new - UI for viewing known contacts)
  - `src/core/ui/contacts_panel/contacts_panel.tscn` (new)
  - `src/core/ui/main_hud/main_hud.gd` (wire toggle button)
  - `src/tests/core/systems/test_persistent_agents.gd` (new)

- TRUTH_RELIANCE:
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md` Section 1 Glossary: Agent, Persistent Agent, Temporary Agent, Contact, Home Base definitions
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md` Section 2.5: World Design Philosophy (Finite Resource Sandbox)
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md` Section 1.1 System 6: Agent System (Persistent Agent Management)
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md` Section 2.1 Phase 1 Scope: Persistent Agent System, Demo Character Roster
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md` Section 3 (Architecture): CharacterTemplate & AgentTemplate property definitions
  - `TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-30.md` Section 1.2: Personal Goal Progression CA uses "Contacts Panel" UI

- DESIGN_PHILOSOPHY (Finite Resource Sandbox — per GDD Section 2.5):
  - **Depth over Breadth**: Small, contained world with deep interactions between systems
  - **Dwarf Fortress / Mount & Blade Inspiration**: Few actors with full agency, emergent stories
  - **Demo Scope** (per GDD):
    - 3 Factions: Miners, Traders, Independents
    - 2-3 Bases per Faction (6-9 locations total)
    - 2 Persistent Agents per Faction (6 named NPCs total for demo)
    - All handcrafted with in-depth templates (personality, goals, relationships)
  - **Agent Categories** (per GDD Section 1.1 System 6):
    - **Persistent Agents**: Named characters with full agency, personality-driven decisions, respawn at home base when disabled, ARE the Contacts, finite in number
    - **Temporary Agents**: Generic encounters (drones, hostiles), resource-like, spawn/despawn, no personality
  - **Emergent Lore**: Minimal starting lore, world develops as player plays
  - **Controlled Expansion**: Procedural generation added sparingly

- TECHNICAL_CONSTRAINTS:
  - Godot 3.x, GLES2 - use `export var` NOT `@export`, use `onready` NOT `@onready`
  - No `await` syntax (Godot 3)
  - GameState is Source of Truth (per GDD Section 3 Architecture)
  - Contact = Persistent Agent (synonymous per GDD Glossary)
  - ContactTemplate is DEPRECATED — CharacterTemplate holds all contact data
  - Follow existing UI patterns from `narrative_status_panel.gd`
  - Use Theme from `assets/themes/main_theme.tres`

- ATOMIC_TASKS:
  - [x] TASK_1: Extend AgentTemplate with persistence properties
    - Location: `database/definitions/agent_template.gd`
    - Add: `export var is_persistent: bool = false`
    - Add: `export var home_location_id: String = ""` — base for respawn
    - Add: `export var character_template_id: String = ""` — links to CharacterTemplate
    - Add: `export var respawn_timeout_seconds: float = 300.0` — time before respawn after disable
    - Reference: GDD Section 3 Architecture (AgentTemplate Properties)

  - [x] TASK_2: Extend CharacterTemplate with personality properties
    - Location: `database/definitions/character_template.gd`
    - Add: `export var personality_traits: Dictionary = {}` — e.g., {"risk_tolerance": 0.7, "greed": 0.5, "loyalty": 0.6, "aggression": 0.3}
    - Add: `export var description: String = ""` — Lore/bio text
    - Add: `export var goals: Array = []` — Current goals (for future Goal System integration)
    - Reference: GDD Section 3 Architecture (CharacterTemplate Properties)

  - [x] TASK_3: Create CharacterTemplates for 6 named NPCs (per GDD Section 2.1 Demo Roster)
    - Location: `database/registry/characters/`
    - Miners Faction:
      - `character_kai.tres` — Veteran miner, pragmatic (risk_tolerance: 0.3, loyalty: 0.8)
      - `character_juno.tres` — Young prospector, ambitious (risk_tolerance: 0.8, greed: 0.7)
    - Traders Faction:
      - `character_vera.tres` — Merchant captain, cautious (risk_tolerance: 0.2, greed: 0.5)
      - `character_milo.tres` — Cargo hauler, opportunistic (greed: 0.7, aggression: 0.2)
    - Independents Faction:
      - `character_rex.tres` — Freelancer pilot, risky (risk_tolerance: 0.9, loyalty: 0.2)
      - `character_ada.tres` — Salvager, resourceful (risk_tolerance: 0.5, aggression: 0.1)

  - [x] TASK_4: Create Persistent Agent .tres files (6 total)
    - Location: `database/registry/agents/`
    - Files: `persistent_kai.tres`, `persistent_juno.tres`, `persistent_vera.tres`, `persistent_milo.tres`, `persistent_rex.tres`, `persistent_ada.tres`
    - Set `is_persistent = true`, link `home_location_id` and `character_template_id`
    - Reference: `npc_default.tres` pattern but with persistence enabled

  - [x] TASK_5: Update GameState for Persistent Agents
    - Location: `src/autoload/GameState.gd`
    - Add: `var persistent_agents: Dictionary = {}` — Key: agent_id, Value: state dict
    - State dict structure: `{ "character_uid": int, "current_location": String, "is_disabled": bool, "disabled_at_time": float, "relationship": int, "is_known": bool }`
    - Deprecate: `narrative_state.known_contacts` and `narrative_state.contact_relationships` (migrate to persistent_agents)
    - Keep `var contacts: Dictionary` temporarily for backward compatibility, mark deprecated

  - [x] TASK_6: Update AgentSystem for Persistent Agent lifecycle
    - Location: `src/core/systems/agent_system.gd`
    - Add: `func spawn_persistent_agents() -> void` — called on world init, spawns all 6 at home locations
    - Add: `func _handle_persistent_agent_disable(agent_uid: int) -> void` — marks disabled, records timestamp
    - Add: `func _check_persistent_agent_respawns() -> void` — called on world tick, respawns ready agents
    - Add: `func get_persistent_agent_state(agent_id: String) -> Dictionary` — returns state from GameState
    - Connect to EventBus `world_event_tick_triggered` for respawn checks
    - On disable: store timestamp in GameState.persistent_agents, remove body, agent respawns after timeout

  - [x] TASK_7: Add EventBus signal for contact discovery
    - Location: `src/autoload/EventBus.gd`
    - Add: `signal contact_met(agent_id)` — emitted when player first meets a Persistent Agent

  - [x] TASK_8: Create `contacts_panel.tscn` scene
    - Location: `src/core/ui/contacts_panel/contacts_panel.tscn`
    - Structure: Control (root) → Panel → VBoxContainer → [HeaderLabel, ScrollContainer → VBoxContainer (ContactList), ButtonClose]
    - Pattern: Mirror structure of `narrative_status_panel.tscn`
    - Required elements: Title "Known Contacts", scrollable list, close button

  - [x] TASK_9: Create `contacts_panel.gd` script
    - Location: `src/core/ui/contacts_panel/contacts_panel.gd`
    - Signature: `extends Control`, with UNIVERSAL HEADER (STATUS: Level 2 - Implementation)
    - Key functions:
      - `func open_screen() -> void` — shows panel and calls update_display()
      - `func update_display() -> void` — clears list, iterates persistent_agents where is_known=true
      - `func _build_contact_entry(agent_id: String) -> Control` — creates single contact row
      - `func _on_ButtonClose_pressed() -> void` — hides panel
    - Display per contact: Name, Faction (resolved display_name), Home Location, Relationship score, Status (Active/Disabled), Description
    - Connect to EventBus `contact_met` for reactive updates

  - [x] TASK_10: Wire Contacts Panel to MainHUD
    - Location: `src/core/ui/main_hud/main_hud.gd`
    - Add button or use existing character button to open Contacts Panel
    - Pattern: Follow how NarrativeStatusPanel is toggled (instantiate scene, connect button)
    - Instantiate `contacts_panel.tscn` as child of HUD CanvasLayer

  - [x] TASK_11: Add contact discovery on docking
    - Location: Docking handler (likely in piloting module or station menu)
    - Logic: When player docks at location, iterate GameState.persistent_agents
    - Check if any agent's `home_location_id` matches docked location AND `is_known == false`
    - If match: set `is_known = true`, emit `EventBus.contact_met(agent_id)`

  - [x] TASK_12: Deprecate ContactTemplate artifacts
    - Location: `database/definitions/contact_template.gd` — add deprecation comment at top
    - Location: `database/registry/contacts/` — keep files but add deprecation note (remove in future cleanup)
    - Location: `src/autoload/GameState.gd` — mark `var contacts: Dictionary` as deprecated
    - Location: `src/scenes/game_world/world_manager/world_generator.gd` — comment out contact loading, add migration note
    - Rationale: Contacts ARE Persistent Agents; CharacterTemplate now holds all contact data

  - [x] TASK_13: Create unit tests
    - Location: `src/tests/core/systems/test_persistent_agents.gd`
    - Test cases:
      - `test_persistent_agents_spawn_on_world_init` — Verify all 6 agents spawn at home locations
      - `test_persistent_agent_disable_records_state` — Disable agent, verify GameState updated
      - `test_persistent_agent_respawns_after_timeout` — Advance time past timeout, verify respawn
      - `test_persistent_agent_state_persists_across_save_load` — Save/load, verify state preserved
      - `test_contacts_panel_displays_known_agents_only` — Set is_known on some agents, verify UI
      - `test_contact_discovered_on_dock` — Simulate dock, verify is_known set and signal emitted

  - [x] VERIFICATION:
    - Run all GUT tests: `godot -s addons/gut/gut_cmdln.gd -gdir=res://src/tests` - ensure no regressions (target: 200+ tests pass)
    - RESULT: 213 passing tests, 575 asserts passed, 0 failures
