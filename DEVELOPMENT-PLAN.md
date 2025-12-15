# GDTLancer Development Plan - Phase 1 Implementation

**Version:** 1.0  
**Date:** December 14, 2025  
**Status:** Active Development  
**Scope:** Phase 1 - "The First Contract" Demo

---

## 0. Guiding Principles

1. **GDD is frozen** - No design changes, only implementation of existing specifications
2. **Code robustness first** - Every feature must be testable and have clear failure states
3. **Incremental delivery** - Each sprint produces a playable, testable build
4. **Placeholder-driven** - Use primitives for assets/UI, replace with art later
5. **Test early, test often** - Manual test checklists after each sprint

---

## 1. Current State Assessment

### ✅ IMPLEMENTED & WORKING
- **Autoloads:** Constants, EventBus, GlobalRefs, GameState, CoreMechanicsAPI, TemplateDatabase, GameStateManager
- **Core Systems:** TimeSystem, CharacterSystem, AssetSystem, InventorySystem (all stateless, API-based)
- **Agent Architecture:** KinematicBody agents with MovementSystem + NavigationSystem components
- **Piloting (Free Flight):** Ship movement, targeting, orbital mechanics, approach/flee/stop commands
- **World Management:** Zone loading, agent spawning, template indexing, world generation
- **Main HUD:** Target indicator, WP/FP display, flight control buttons, zoom/speed sliders
- **Unit Tests:** TimeSystem, CharacterSystem, AssetSystem, InventorySystem

### ❌ NOT IMPLEMENTED (Required for Phase 1)
- **Trading Module:** Buy/sell commodities, cargo capacity checks
- **Combat Module:** Weapon firing, damage application, hull destruction
- **Event System:** Encounter triggering, combat initiation
- **Narrative Actions:** Action Check UI, Risky/Cautious selection, outcome resolution
- **Contract System:** Contract data, acceptance, completion, rewards
- **Ship Stats Integration:** Agent movement not reading from ShipTemplate
- **UI Screens:** Trade interface, Contract board, Character screen, Hangar/Progression

---

## 2. Sprint Structure

Each sprint is **1-2 weeks** and follows this pattern:
1. **Implement** - Write code, create placeholders
2. **Unit Test** - Write/run GUT tests for new systems
3. **Integration Test** - Manual testing checklist
4. **Polish** - Bug fixes only, no scope expansion

---

## 3. Sprint Schedule

### SPRINT 1: Foundation Fixes (Critical Path) ✅ COMPLETE
**Goal:** Wire existing systems together properly before adding new features.

#### 1.1 Ship Stats Integration
**Problem:** Agent movement uses hardcoded values instead of ShipTemplate stats.

**Tasks:**
- [x] Modify `agent.gd` `initialize()` to pull `move_params` from the agent's linked `ShipTemplate`
- [x] Add a helper in `AssetSystem` to get ship by character UID: `get_ship_for_character(char_uid)`
- [x] Ensure `WorldGenerator` correctly links character → ship UID
- [x] Update `AgentSystem.spawn_player()` to pass `character_uid` in overrides

**Files modified:**
- `core/agents/agent.gd` - Added `character_uid`, `_get_movement_params_from_ship()`
- `core/systems/asset_system.gd` - Added `get_ship_for_character()`, `get_ships_for_character()`
- `core/systems/agent_system.gd` - Added `character_uid` to spawn overrides, added `spawn_npc()`

**Test Checklist (Sprint 1.1):**
- [ ] Spawn player agent → verify movement speed matches `ship_default.tres` values (300.0)
- [ ] Change `ship_default.tres` max_speed → verify in-game speed changes
- [ ] Spawn NPC with different ship template → verify different handling

---

#### 1.2 EventBus Signal Audit
**Problem:** Some signals declared but unused; some missing for new features.

**Tasks:**
- [x] Audit all EventBus signals - document which are connected
- [x] Add missing signals for Phase 1:
  - `game_state_loaded` - After GameStateManager restores state
  - `combat_initiated`, `combat_ended` - Combat lifecycle
  - `agent_damaged`, `agent_disabled` - Combat damage events
  - `contract_accepted`, `contract_completed`, `contract_abandoned`, `contract_failed` - Contract lifecycle
  - `trade_transaction_completed` - Trading events
  - `dock_available`, `dock_unavailable`, `player_docked`, `player_undocked` - Docking events
  - `narrative_action_requested`, `narrative_action_resolved` - Narrative action events

**Files modified:**
- `autoload/EventBus.gd` - Added all new signals

---

#### 1.3 GameState Extensions
**Problem:** GameState lacks containers for contracts, locations, narrative state.

**Tasks:**
- [x] Add to `GameState.gd`:
  - `locations: Dictionary` - Zone/station data
  - `contracts: Dictionary` - Available contracts
  - `active_contracts: Dictionary` - Player's accepted contracts  
  - `narrative_state: Dictionary` - Reputation, faction standings
  - `session_stats: Dictionary` - Session tracking

**Files modified:**
- `autoload/GameState.gd`

**Test Checklist (Sprint 1.2-1.3):**
- [ ] Print EventBus signal list → verify all new signals exist
- [ ] Print GameState.contracts → verify empty dict exists
- [ ] Save/Load game → verify new fields persist (may need GameStateManager update)

---

### SPRINT 2: Trading Module Core ✅ COMPLETE
**Goal:** Implement buy/sell mechanics without UI.

#### 2.1 Location Data Structure
**Tasks:**
- [x] Create `LocationTemplate` resource (`core/resource/location_template.gd`):
  ```gdscript
  extends Template
  class_name LocationTemplate
  
  export var location_name: String = "Unknown Station"
  export var location_type: String = "station"  # station, outpost, debris_field
  export var position_in_zone: Vector3 = Vector3.ZERO
  export var market_inventory: Dictionary = {}  # template_id -> {price, quantity}
  export var available_services: Array = ["trade", "repair", "contracts"]
  ```
- [x] Create placeholder location data file: `assets/data/locations/station_alpha.tres`
- [x] Extend `WorldGenerator` to load locations into `GameState.locations`

**Files to create:**
- `core/resource/location_template.gd`
- `assets/data/locations/station_alpha.tres` (placeholder)
- `assets/data/locations/station_beta.tres` (placeholder)

---

#### 2.2 Trading System
**Tasks:**
- [x] Create `core/systems/trading_system.gd`:
  ```gdscript
  extends Node
  
  func can_buy(char_uid, location_id, commodity_id, quantity) -> Dictionary
  func execute_buy(char_uid, location_id, commodity_id, quantity) -> Dictionary
  func can_sell(char_uid, location_id, commodity_id, quantity) -> Dictionary
  func execute_sell(char_uid, location_id, commodity_id, quantity) -> Dictionary
  func get_market_prices(location_id) -> Dictionary
  ```
- [x] Implement cargo capacity checks (query AssetSystem for ship's cargo_capacity)
- [x] Implement WP transactions via CharacterSystem
- [x] Emit `trade_transaction_completed` signal on success

**Files to create:**
- `core/systems/trading_system.gd`

**Files to modify:**
- `scenes/game_world/main_game_scene.tscn` - Add TradingSystem node under WorldManager

---

#### 2.3 Trading System Tests
**Tasks:**
- [x] Create `tests/core/systems/test_trading_system.gd`:
  - Test: Buy commodity within budget → success, WP decreases, inventory increases
  - Test: Buy commodity over budget → failure, no state change
  - Test: Buy commodity exceeds cargo → failure, no state change
  - Test: Sell commodity player owns → success, WP increases, inventory decreases
  - Test: Sell commodity player doesn't own → failure

**Files to create:**
- `tests/core/systems/test_trading_system.gd`

**Test Checklist (Sprint 2):**
- [ ] Run GUT tests → all trading tests pass
- [ ] In debugger: call `TradingSystem.execute_buy()` → verify GameState changes
- [ ] In debugger: call `TradingSystem.execute_sell()` → verify GameState changes
- [ ] Buy until cargo full → verify further buys fail
- [ ] Spend all WP → verify further buys fail

---

### SPRINT 3: Contract System Core ✅ COMPLETE
**Goal:** Create contract data structures and completion logic.

#### 3.1 Contract Data Structure
**Tasks:**
- [x] Create `ContractTemplate` resource (`core/resource/contract_template.gd`):
  ```gdscript
  extends Template
  class_name ContractTemplate
  
  export var contract_type: String = "delivery"  # delivery, combat, exploration
  export var title: String = "Unnamed Contract"
  export var description: String = ""
  export var issuer_id: String = ""              # Contact ID
  export var faction_id: String = ""
  export var origin_location_id: String = ""
  export var destination_location_id: String = ""
  export var required_commodity_id: String = ""
  export var required_quantity: int = 0
  export var reward_wp: int = 0
  export var reward_reputation: int = 0
  export var time_limit_tu: int = -1             # -1 = no limit
  export var difficulty: int = 1                 # For matching/filtering
  ```
- [x] Create 3 placeholder contracts in `assets/data/contracts/`

**Files to create:**
- `core/resource/contract_template.gd`
- `assets/data/contracts/delivery_01.tres`
- `assets/data/contracts/delivery_02.tres`
- `assets/data/contracts/delivery_03.tres`

---

#### 3.2 Contract System
**Tasks:**
- [x] Create `core/systems/contract_system.gd`:
  ```gdscript
  extends Node
  
  func get_available_contracts(location_id) -> Array
  func accept_contract(char_uid, contract_id) -> bool
  func check_contract_completion(char_uid, contract_id) -> Dictionary
  func complete_contract(char_uid, contract_id) -> Dictionary
  func abandon_contract(char_uid, contract_id) -> bool
  func get_active_contracts(char_uid) -> Array
  ```
- [ ] Completion logic for "delivery" type:
  - Check player is at destination location
  - Check player has required commodity quantity
  - Remove commodity from inventory
  - Add WP reward via CharacterSystem
  - Update reputation in GameState.narrative_state
  - Emit `contract_completed` signal

**Files to create:**
- `core/systems/contract_system.gd`

---

#### 3.3 Contract System Tests
**Tasks:**
- [x] Create `tests/core/systems/test_contract_system.gd`:
  - Test: Accept contract → added to active_contracts
  - Test: Accept already-active contract → failure
  - Test: Check completion when not at destination → incomplete
  - Test: Check completion when missing cargo → incomplete
  - Test: Complete valid contract → rewards applied, contract removed
  - Test: Abandon contract → removed from active, no penalty (Phase 1)

**Files to create:**
- `tests/core/systems/test_contract_system.gd`

**Test Checklist (Sprint 3):**
- [ ] Run GUT tests → all contract tests pass
- [ ] In debugger: accept contract → verify active_contracts populated
- [ ] In debugger: complete contract → verify WP reward applied
- [ ] Accept 3 contracts → verify all tracked correctly
- [ ] Complete contract → verify removed from active list

---

### SPRINT 4: Docking & Location Interaction ✅ COMPLETE
**Goal:** Player can dock at stations and access services.

#### 4.1 Dockable Zone Objects
**Tasks:**
- [x] Create `DockableStation` scene (`scenes/zones/objects/dockable_station.tscn`):
  - Area node for dock trigger detection
  - Collision shape (sphere, radius = interaction_radius from location template)
  - Visual: Placeholder mesh (cube or sphere with distinct color)
  - Script that emits `station_dock_available` when player enters area
- [x] Modify `basic_flight_zone.tscn` to include 2 station instances
- [x] Add `location_id` export var to link station to LocationTemplate

**Files to create:**
- `scenes/zones/objects/dockable_station.tscn`
- `scenes/zones/objects/dockable_station.gd`

**Files to modify:**
- `scenes/zones/basic_flight_zone.tscn` - Add station instances

**Placeholder Asset Needed:**
- **Station visual:** Use a scaled `CubeMesh` or `SphereMesh` with a bright color (e.g., green for Station Alpha, blue for Station Beta). I will create the actual station models later.

---

#### 4.2 Docking State Machine
**Tasks:**
- [x] Add to EventBus:
  ```gdscript
  signal dock_available(location_id)
  signal dock_unavailable
  signal player_docked(location_id)
  signal player_undocked
  ```
- [x] Add docking state to player agent or create `DockingController` component:
  - Track `is_docked: bool` and `current_location_id: String`
  - When docked: disable movement, show station UI
  - When undocked: enable movement, hide station UI
- [x] Add dock/undock input actions to `project.godot`

**Files to modify:**
- `autoload/EventBus.gd`
- `modules/piloting/scripts/player_controller_ship.gd` (or new component)
- `project.godot` - Add `action_dock` input

---

#### 4.3 Station Menu UI (Placeholder)
**Tasks:**
- [x] Create `StationMenuUI` scene (`core/ui/station_menu/station_menu.tscn`):
  - Panel container with buttons: [Trade] [Contracts] [Undock]
  - Label showing station name
  - Initially hidden, shown when `player_docked` signal received
- [x] Connect buttons to emit navigation signals (actual screens built in later sprints)

**Files to create:**
- `core/ui/station_menu/station_menu.tscn`
- `core/ui/station_menu/station_menu.gd`

**UI Reference:** Follow `main_hud.tscn` structure. Use `Button` nodes with simple text labels. Panel background can be a `ColorRect` with semi-transparent dark color.

**Test Checklist (Sprint 4):**
- [ ] Fly to station → "Dock Available" indicator appears
- [ ] Press dock key → ship stops, station menu appears
- [ ] Press undock → menu closes, ship can move again
- [ ] Fly away from station → dock indicator disappears
- [ ] Dock at Station Alpha → verify correct station name displayed
- [ ] Dock at Station Beta → verify correct station name displayed

---

### SPRINT 5: Trade UI & Integration ✅ COMPLETE
**Goal:** Functional trade interface using TradingSystem.

#### 5.1 Trade Screen UI (Placeholder)
**Tasks:**
- [x] Create `TradeScreenUI` scene (`core/ui/trade_screen/trade_screen.tscn`):
  - Left panel: Station inventory (ItemList or VBoxContainer with commodity rows)
  - Right panel: Player cargo (ItemList or VBoxContainer)
  - Center: Transaction controls (Buy/Sell buttons, quantity selector)
  - Top: Current WP display, Cargo space display
  - Bottom: [Confirm] [Cancel] buttons
- [ ] Each commodity row shows: Name, Price, Quantity
- [ ] Connect to TradingSystem API

**Files to create:**
- `core/ui/trade_screen/trade_screen.tscn`
- `core/ui/trade_screen/trade_screen.gd`

**UI Reference:** Use `VBoxContainer` for lists, `HBoxContainer` for rows. `Label` for text, `SpinBox` for quantity. Colors: dark background, light text.

---

#### 5.2 Trade Screen Logic
**Tasks:**
- [x] Implement in `trade_screen.gd`:
  - `_on_open(location_id)`: Populate station inventory from `TradingSystem.get_market_prices()`
  - `_on_buy_pressed()`: Call `TradingSystem.execute_buy()`, refresh displays
  - `_on_sell_pressed()`: Call `TradingSystem.execute_sell()`, refresh displays
  - Update WP and cargo displays after each transaction
  - Handle errors (show message if transaction fails)

**Test Checklist (Sprint 5):**
- [ ] Open trade screen → station inventory displays correctly
- [ ] Open trade screen → player cargo displays correctly
- [ ] Buy 1 commodity → WP decreases, cargo increases, lists update
- [ ] Sell 1 commodity → WP increases, cargo decreases, lists update
- [ ] Try to buy with insufficient WP → error message, no change
- [ ] Try to buy with full cargo → error message, no change
- [ ] Buy all of a commodity type → quantity shows 0 or item removed from station list
- [ ] Close and reopen trade screen → state persists correctly

---

### SPRINT 6: Contract UI & Integration ✅ COMPLETE
**Goal:** Functional contract board and active contracts display.

#### 6.1 Contract Board UI (Placeholder)
**Tasks:**
- [x] Create `ContractBoardUI` scene (`core/ui/contract_board/contract_board.tscn`):
  - List of available contracts at current location
  - Each row: Title, Type, Reward, Destination
  - [Accept] button per contract or for selected contract
  - [Close] button
- [ ] Filter contracts by current location via `ContractSystem.get_available_contracts()`

**Files to create:**
- `core/ui/contract_board/contract_board.tscn`
- `core/ui/contract_board/contract_board.gd`

---

#### 6.2 Active Contracts Panel
**Tasks:**
- [x] Add to Main HUD or create separate panel:
  - List of player's active contracts (max 3 for Phase 1)
  - Each entry: Title, Objective summary, Destination
  - Visual indicator when at correct destination with required cargo
- [ ] Update panel when `contract_accepted` or `contract_completed` signals fire

**Files to modify:**
- `core/ui/main_hud/main_hud.tscn` - Add contracts panel
- `core/ui/main_hud/main_hud.gd` - Add contract display logic

---

#### 6.3 Contract Completion Flow
**Tasks:**
- [x] When player docks at destination:
  - Check active contracts for completability via `ContractSystem.check_contract_completion()`
  - If completable, show [Complete Contract] button in station menu
  - On press: call `ContractSystem.complete_contract()`, show reward popup
- [x] Create simple reward popup (Label with WP gain, auto-hide after 2s)

**Test Checklist (Sprint 6):**
- [ ] Open contract board at station → shows available contracts
- [ ] Accept contract → appears in active contracts panel
- [ ] Accept contract → removed from available list
- [ ] Fly to destination without cargo → completion not available
- [ ] Fly to destination with cargo → [Complete Contract] button visible
- [ ] Complete contract → WP increases, contract removed from active list
- [ ] Complete contract → reward popup displays correct amount
- [ ] Accept 3 contracts → all display in active panel
- [ ] Try to accept 4th contract → blocked (if limit implemented) or allowed

---

### SPRINT 7: Narrative Actions - Core ✅ COMPLETE
**Goal:** Implement Action Check resolution with Risky/Cautious choice.

#### 7.1 Narrative Action System
**Tasks:**
- [x] Create `core/systems/narrative_action_system.gd`:
  ```gdscript
  extends Node
  
  # Called to initiate a narrative action (shows UI, waits for player choice)
  func request_action(action_type: String, context: Dictionary) -> void
  
  # Called when player confirms approach selection
  func resolve_action(action_type: String, approach: int, context: Dictionary) -> Dictionary
  ```
- [ ] Action types for Phase 1:
  - `"trade_finalize"` - After completing a trade transaction
  - `"contract_complete"` - After delivering contract cargo
  - `"dock_arrival"` - After docking (optional, can add quirks)
- [ ] Resolution uses `CoreMechanicsAPI.perform_action_check()` with character skills

**Files to create:**
- `core/systems/narrative_action_system.gd`

---

#### 7.2 Action Check UI (Placeholder)
**Tasks:**
- [x] Create `ActionCheckUI` scene (`core/ui/action_check/action_check.tscn`):
  - Title: Action being resolved (e.g., "Execute Precision Arrival")
  - Description: Context text
  - Two large buttons: [Act Cautiously] [Act Risky]
  - FP Selector: SpinBox or buttons to allocate FP (0 to current FP)
  - [Confirm] button
  - Result display area (shows after roll)
- [ ] Flow:
  1. UI appears with action context
  2. Player selects approach and FP
  3. Player presses Confirm
  4. Roll happens, result displayed
  5. Outcome applied, UI closes after acknowledgment

**Files to create:**
- `core/ui/action_check/action_check.tscn`
- `core/ui/action_check/action_check.gd`

**UI Reference:** Modal popup over game. Dark semi-transparent background overlay. Centered panel.

---

#### 7.3 Outcome Application
**Tasks:**
- [x] Define outcome tables in `Constants.gd` or separate data file:
  ```gdscript
  const NARRATIVE_OUTCOMES = {
      "dock_arrival": {
          "CritSuccess": {"description": "Perfect approach", "effects": {}},
          "SwC": {"description": "Minor scrape", "effects": {"add_quirk": "scratched_hull"}},
          "Failure": {"description": "Rough landing", "effects": {"add_quirk": "jammed_landing_gear", "wp_cost": 2}}
      },
      # ... more action types
  }
  ```
- [x] Implement effect application:
  - `add_quirk`: Add string to ship's `ship_quirks` array
  - `wp_cost`: Subtract WP via CharacterSystem
  - `reputation_change`: Modify `GameState.narrative_state.reputation`

**Test Checklist (Sprint 7):**
- [ ] Trigger narrative action → UI appears
- [ ] Select Cautious + 0 FP + Confirm → roll happens, result shown
- [ ] Select Risky + 2 FP + Confirm → roll happens, higher bonus visible
- [ ] Critical Success → no negative effects applied
- [ ] Failure → quirk added to ship (check GameState.assets_ships)
- [ ] Failure with WP cost → WP decreases
- [ ] Close result → UI dismissed, game continues
- [ ] Check FP after spending → correctly reduced

---

### SPRINT 8: Combat Module - Core ✅ COMPLETE
**Goal:** Basic ship-to-ship combat with hull damage.

#### 8.1 Weapon/Tool Data
**Tasks:**
- [x] Create `UtilityToolTemplate` resource (`core/resource/utility_tool_template.gd`):
  ```gdscript
  extends Template
  class_name UtilityToolTemplate
  
  export var tool_name: String = "Default Tool"
  export var tool_type: String = "weapon"  # weapon, grapple, drill
  export var damage: int = 10
  export var range_meters: float = 500.0
  export var cooldown_seconds: float = 1.0
  export var projectile_speed: float = 1000.0  # 0 = hitscan
  ```
- [x] Create placeholder weapon: `assets/data/tools/ablative_laser.tres`
- [x] Add `equipped_tools: Array` to `ShipTemplate` (list of tool template IDs)

**Files to create:**
- `core/resource/utility_tool_template.gd`
- `assets/data/tools/ablative_laser.tres`

**Files to modify:**
- `core/resource/asset_ship_template.gd` - Add `equipped_tools`

---

#### 8.2 Combat System
**Tasks:**
- [x] Create `core/systems/combat_system.gd`:
  ```gdscript
  extends Node
  
  var active_combat: bool = false
  var combat_participants: Array = []
  
  func initiate_combat(player_agent, enemy_agents: Array)
  func end_combat(result: String)  # "victory", "defeat", "flee"
  func apply_damage(target_agent, damage: int, source_agent)
  func check_destruction(agent) -> bool
  func get_combat_state() -> Dictionary
  ```
- [ ] Damage applies to `hull_integrity` on target's ShipTemplate instance
- [ ] When hull <= 0, agent is "disabled" (emit signal, stop AI, mark as wreck)

**Files to create:**
- `core/systems/combat_system.gd`

---

#### 8.3 Weapon Firing Component
**Tasks:**
- [x] Create `WeaponController` component (`core/agents/components/weapon_controller.gd`):
  - Handles cooldowns per equipped tool
  - `fire_weapon(tool_index, target)` - Check range, apply damage
  - For Phase 1: Hitscan only (instant hit if in range and aimed)
- [ ] Add to player agent scene, connect to input

**Files to create:**
- `core/agents/components/weapon_controller.gd`

**Files to modify:**
- `core/agents/player_agent.tscn` - Add WeaponController node

---

#### 8.4 Combat Input & Targeting
**Tasks:**
- [x] Add input action `fire_weapon` to `project.godot` (left mouse button or key)
- [x] Modify player input handler:
  - When fire pressed and target selected: call WeaponController.fire_weapon()
  - Visual/audio feedback (placeholder: print statement or simple particle)

**Files to modify:**
- `project.godot`
- `modules/piloting/scripts/player_controller_ship.gd`

**Placeholder Asset Needed:**
- **Weapon fire visual:** For now, use `ImmediateGeometry` to draw a line from player to target, or skip visual entirely and just print damage. I will add proper effects later.

**Test Checklist (Sprint 8):**
- [ ] Equip ship with weapon → weapon data loads correctly
- [ ] Target enemy → fire weapon → damage applied to enemy hull
- [ ] Fire at target out of range → no damage (or miss message)
- [ ] Fire during cooldown → no effect
- [ ] Reduce enemy hull to 0 → enemy marked as disabled
- [ ] Disabled enemy stops moving/attacking
- [ ] Combat system tracks active combat state correctly

---

### SPRINT 9: Enemy AI & Combat Encounters ✅ COMPLETE
**Goal:** NPCs that fight back, encounters triggered by Event System.

#### 9.1 Enemy AI Combat Behavior
**Tasks:**
- [x] Extend `ship_controller_ai.gd` with combat states:
  - `STATE_IDLE`, `STATE_PATROL`, `STATE_COMBAT`, `STATE_FLEE`
  - In COMBAT: Approach player, fire weapons when in range
  - Switch to FLEE if hull below threshold (e.g., 20%)
- [x] AI weapon firing with cooldowns
- [x] AI target selection (for Phase 1: always target player if hostile)

**Files to modify:**
- `modules/piloting/scripts/ship_controller_ai.gd`

---

#### 9.2 Event System - Combat Encounters
**Tasks:**
- [x] Implement `event_system.gd` with basic functionality:
  ```gdscript
  extends Node
  
  var _encounter_cooldown: int = 0
  
  func _on_world_event_tick(tu_amount):
      _encounter_cooldown -= tu_amount
      if _encounter_cooldown <= 0:
          _maybe_trigger_encounter()
  
  func _maybe_trigger_encounter():
      # Roll chance based on location danger level
      # If triggered, spawn hostile NPC and emit combat_initiated
  ```
- [x] Connect to `world_event_tick_triggered` signal
- [x] Spawn hostile agent at distance from player, initiate combat

**Files to modify:**
- `core/systems/event_system.gd`

---

#### 9.3 Combat Flow Integration
**Tasks:**
- [x] When combat ends (all enemies disabled or player flees):
  - Call `CombatSystem.end_combat(result)`
  - Trigger Narrative Action for aftermath (e.g., "Assess the Aftermath")
  - Apply outcomes (WP from salvage, reputation changes)
- [x] If player ship destroyed: Game Over state (simple for Phase 1)

**Placeholder Asset Needed:**
- **Enemy ship visual:** Use the same ship mesh as player but with different color material (red/orange). I will create distinct enemy models later.

**Test Checklist (Sprint 9):**
- [ ] Wait for time to pass → combat encounter triggers
- [ ] Enemy spawns at appropriate distance
- [ ] Enemy approaches player and fires
- [ ] Player takes damage when hit
- [ ] Destroy enemy → combat ends, narrative action triggers
- [ ] Player hull reaches 0 → game over state
- [ ] Enemy flees when low health
- [ ] Multiple enemies in one encounter work correctly

---

### SPRINT 10: Full Game Loop Integration ✅ COMPLETE
**Goal:** Connect all systems into playable demo flow.

#### 10.1 New Game Flow
**Tasks:**
- [x] Create proper main menu (`core/ui/main_menu/main_menu.tscn`):
  - [New Game] - Initialize fresh GameState, load zone
  - [Quit] - Exit application
- [x] New game initialization:
  - Player starts docked at Station Alpha
  - Starting WP: 50
  - Starting cargo: Empty
  - 2-3 contracts available at station

**Files to modify:**
- `core/ui/main_menu/` - Implement menu functionality

---

#### 10.2 Game Session Flow
**Tasks:**
- [x] Verify complete loop works:
  1. Start at station → Open contracts → Accept delivery contract
  2. Open trade → Buy required commodity
  3. Undock → Fly to destination (maybe encounter combat)
  4. Dock at destination → Complete contract (narrative action)
  5. Receive reward → Repeat
- [x] Time passes during flight → Upkeep costs deducted
- [x] Track session with debug logging

---

#### 10.3 Win/Lose Conditions
**Tasks:**
- [x] Lose condition: Player hull <= 0
  - Show "Ship Destroyed" screen
  - [Return to Menu] button
- [x] "Soft lose": WP drops below 0
  - For Phase 1: Just show warning, allow continued play
  - (Full game would have debt mechanics)
- [x] No explicit "win" for Phase 1 (sandbox demo)

**Test Checklist (Sprint 10):**
- [ ] New Game → player spawns docked at station
- [ ] Complete full contract cycle (accept → travel → deliver)
- [ ] WP updates correctly through full cycle
- [ ] Combat encounter during travel → survive → continue to destination
- [ ] Combat encounter → die → game over screen → return to menu
- [ ] Time Clock fills → upkeep deducted
- [ ] Upkeep with insufficient WP → warning displayed
- [ ] Multiple contract completions → verify stacking rewards

---

### SPRINT 11: Polish & Edge Cases
**Goal:** Stability, edge case handling, save/load verification.

#### 11.1 Save/Load Verification
**Tasks:**
- [ ] Verify `GameStateManager` serializes all new data:
  - `contracts`, `active_contracts`
  - `locations` (market state changes)
  - `narrative_state`
  - Ship `ship_quirks` array
- [ ] Test save during various states:
  - Mid-flight
  - Docked at station
  - With active contracts
  - After combat (with quirks)
- [ ] Test load restores exact state

---

#### 11.2 Error Handling
**Tasks:**
- [ ] Add null checks to all system API functions
- [ ] Add fallback behaviors:
  - Missing template → use default
  - Invalid location_id → log error, no crash
  - Combat with no enemies → auto-end
- [ ] Ensure no orphan nodes (use `add_child_autofree` in tests)

---

#### 11.3 Performance Check
**Tasks:**
- [ ] Profile with 10+ NPC agents in zone
- [ ] Check for memory leaks after zone transitions
- [ ] Verify no physics errors in console during extended play

**Test Checklist (Sprint 11):**
- [ ] Play for 10 minutes continuously → no crashes
- [ ] Save mid-mission → load → continue exactly where left off
- [ ] Trigger every error condition intentionally → graceful handling
- [ ] Zone transition → no orphan nodes or errors
- [ ] Complete 5 contracts in one session → stable performance

---

## 4. Asset Placeholder List

These primitives should be replaced with final art after Phase 1 gameplay is solid:

| Placeholder | Location | Replace With |
|-------------|----------|--------------|
| Player ship mesh | `assets/models/ships/` | Detailed ship model |
| Enemy ship mesh | `assets/models/ships/` | Hostile ship model |
| Station mesh | `scenes/zones/objects/` | Station model |
| Weapon fire effect | (none currently) | Laser/projectile VFX |
| Explosion effect | (none currently) | Destruction VFX |
| UI panel backgrounds | `core/ui/*/` | Themed panel textures |
| Commodity icons | (none currently) | Item icon sprites |
| Character portraits | (none currently) | Portrait images |

---

## 5. Testing Protocol

After each sprint, perform this testing sequence:

### Automated Tests
```bash
# Run from Godot editor or command line
godot --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```

### Manual Test Sessions
1. **Fresh Start Test:** New game, play for 5 minutes, verify core loop
2. **Persistence Test:** Save, quit, load, verify state
3. **Stress Test:** Rapid actions, edge cases, try to break it
4. **Flow Test:** Complete intended player journey start-to-finish

### Bug Tracking
- Log issues in a simple text file: `KNOWN-ISSUES.md`
- Format: `[Sprint X] [System] Brief description - Status`
- Prioritize: Blocker > Major > Minor > Polish

---

## 6. Definition of Done - Phase 1

Phase 1 is complete when:

- [ ] Player can start new game and spawn at station
- [ ] Player can view and accept contracts
- [ ] Player can buy/sell commodities at stations
- [ ] Player can fly between two stations
- [ ] Player can complete delivery contracts and receive rewards
- [ ] Combat encounters can trigger during flight
- [ ] Player can fight and disable enemy ships
- [ ] Narrative Actions resolve with visible outcomes
- [ ] Time system triggers upkeep costs
- [ ] Ship quirks can be gained from failures
- [ ] Game state can be saved and loaded
- [ ] No critical bugs or crashes during 15-minute play session
- [ ] All unit tests pass

---

## 7. Post-Phase 1

After Phase 1 is validated and stable:

1. **Art Pass:** Replace all placeholders with final assets
2. **Audio Pass:** Add sound effects and music
3. **Balance Pass:** Tune WP rewards, prices, upkeep costs, combat damage
4. **UX Pass:** Improve UI flow, add tooltips, polish animations
5. **Content Pass:** Add more contracts, locations, ship types

Then proceed to Phase 2 (Mining/Industrial module, deeper narrative systems).

---

## Appendix A: File Structure (New Files)

```
core/
  resource/
    location_template.gd        [Sprint 2]
    contract_template.gd        [Sprint 3]
    utility_tool_template.gd    [Sprint 8]
  systems/
    trading_system.gd           [Sprint 2]
    contract_system.gd          [Sprint 3]
    narrative_action_system.gd  [Sprint 7]
    combat_system.gd            [Sprint 8]
  agents/
    components/
      weapon_controller.gd      [Sprint 8]
  ui/
    station_menu/
      station_menu.tscn         [Sprint 4]
      station_menu.gd           [Sprint 4]
    trade_screen/
      trade_screen.tscn         [Sprint 5]
      trade_screen.gd           [Sprint 5]
    contract_board/
      contract_board.tscn       [Sprint 6]
      contract_board.gd         [Sprint 6]
    action_check/
      action_check.tscn         [Sprint 7]
      action_check.gd           [Sprint 7]

scenes/
  zones/
    objects/
      dockable_station.tscn     [Sprint 4]
      dockable_station.gd       [Sprint 4]

assets/
  data/
    locations/
      station_alpha.tres        [Sprint 2]
      station_beta.tres         [Sprint 2]
    contracts/
      delivery_01.tres          [Sprint 3]
      delivery_02.tres          [Sprint 3]
      delivery_03.tres          [Sprint 3]
    tools/
      ablative_laser.tres       [Sprint 8]

tests/
  core/
    systems/
      test_trading_system.gd    [Sprint 2]
      test_contract_system.gd   [Sprint 3]
```

---

## Appendix B: Quick Reference - Key APIs

### CharacterSystem
- `get_player_character() -> CharacterTemplate`
- `add_wp(uid, amount)` / `subtract_wp(uid, amount)`
- `add_fp(uid, amount)` / `subtract_fp(uid, amount)`
- `get_skill_level(uid, skill_name) -> int`

### InventorySystem
- `add_asset(char_uid, type, asset_id, quantity)`
- `remove_asset(char_uid, type, asset_id, quantity) -> bool`
- `get_asset_count(char_uid, type, asset_id) -> int`

### AssetSystem
- `get_ship(ship_uid) -> ShipTemplate`
- `get_player_ship() -> ShipTemplate`

### CoreMechanicsAPI
- `perform_action_check(attr, skill, fp_spent, approach) -> Dictionary`
  - Returns: `{roll_total, result_tier, tier_name, focus_gain, focus_loss_reset, ...}`

### TimeSystem
- `add_time_units(tu_to_add)`
- `get_current_tu() -> int`
