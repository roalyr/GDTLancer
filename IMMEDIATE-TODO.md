# IMMEDIATE-TODO.md
**Generated:** December 15, 2025  
**Target Sprint:** Sprint 10 - Full Game Loop Integration  
**Previous Sprint Status:** Sprint 9 (Enemy AI & Combat Encounters) COMPLETE — Tests passing

---

## 1. CONTEXT

We are implementing **Sprint 10: Full Game Loop Integration**, which connects all existing systems (Trading, Contracts, Combat, Narrative Actions, Docking) into a playable vertical slice. Sprint 9 delivered functional AI combat and encounter spawning; this sprint validates the **complete player journey**: start docked → accept contract → trade for cargo → undock → travel (potential combat) → dock at destination → complete contract with narrative action → receive reward.

This sprint is the **final integration milestone** before Definition of Done for Phase 1. It does not add new systems—it ensures existing systems work together seamlessly and the Main Menu properly initializes a new game.

---

## 2. FILE MANIFEST

### Files to CREATE:
| File | Purpose |
|------|---------|
| `tests/scenes/test_full_game_loop.gd` | GUT integration tests for complete player journey |

### Files to MODIFY:
| File | Change |
|------|--------|
| `core/ui/main_menu/main_menu.gd` | Implement New Game / Load Game / Exit button logic |
| `scenes/game_world/world_manager.gd` | Wire main menu signals, start player docked at station |
| `scenes/game_world/world_manager/world_generator.gd` | Ensure player spawns docked, initial WP=50, contracts available |
| `autoload/GameStateManager.gd` | Verify save/load covers all new state fields (narrative, contracts, quirks) |

### Files to READ for Context (Dependencies):
| File | Reason |
|------|--------|
| `core/ui/main_menu/main_menu.tscn` | Understand existing button structure |
| `scenes/ui/station_menu/station_menu.gd` | Docked state UI flow |
| `core/systems/contract_system.gd` | `accept_contract()`, `complete_contract()` API |
| `core/systems/trading_system.gd` | `execute_buy()`, `execute_sell()` API |
| `autoload/GameState.gd` | All state containers |
| `autoload/EventBus.gd` | Required signals for flow |
| `core/systems/time_system.gd` | Upkeep mechanics |

---

## 3. ATOMIC TASKS

### Sprint 10 Checklist

- [x] **TASK 1:** Implement Main Menu Button Logic
- [x] **TASK 2:** Implement Player Spawn Docked Flow
- [x] **TASK 3:** Verify Save/Load Serialization Completeness
- [x] **TASK 4:** Implement Game Over / Win Conditions UI
- [x] **TASK 5:** Write Full Game Loop Integration Tests
- [x] **TASK 6:** Manual Integration Verification (PARTIAL - Combat damage issues remain)

---

### TASK 1: Implement Main Menu Button Logic

**TARGET FILE:** `core/ui/main_menu/main_menu.gd`

**DEPENDENCIES:**
- Read `core/ui/main_menu/main_menu.tscn` (lines 1-100) — Button node paths
- Read `scenes/game_world/world_manager.gd` (lines 40-70) — `_setup_new_game()` flow
- Read `autoload/GameStateManager.gd` — `save_game()`, `load_game()` API

**CHANGES:**
Implement button handlers for New Game, Load Game, Save Game, and Exit:

**PSEUDO-CODE SIGNATURES:**
```gdscript
# File: core/ui/main_menu/main_menu.gd
extends Control

onready var btn_new_game = $ScreenControls/MainButtonsHBoxContainer/ButtonStartNewGame
onready var btn_load_game = $ScreenControls/MainButtonsHBoxContainer/ButtonLoadGame
onready var btn_save_game = $ScreenControls/MainButtonsHBoxContainer/ButtonSaveGame
onready var btn_exit_game = $ScreenControls/MainButtonsHBoxContainer/ButtonExitGame

func _ready() -> void:
    """Connect button signals, check for existing save file to enable/disable load."""
    btn_new_game.connect("pressed", self, "_on_new_game_pressed")
    btn_load_game.connect("pressed", self, "_on_load_game_pressed")
    btn_save_game.connect("pressed", self, "_on_save_game_pressed")
    btn_exit_game.connect("pressed", self, "_on_exit_game_pressed")
    
    # Connect to EventBus for menu toggling
    EventBus.connect("main_menu_requested", self, "_show_menu")
    
    # Disable Load if no save exists
    _update_load_button_state()

func _on_new_game_pressed() -> void:
    """Emit signal to WorldManager to reset and initialize fresh game state."""
    # Hide menu
    visible = false
    # Emit signal for WorldManager to handle
    EventBus.emit_signal("new_game_requested")

func _on_load_game_pressed() -> void:
    """Load saved game state via GameStateManager."""
    if GameStateManager.has_save_file():
        visible = false
        GameStateManager.load_game()
        EventBus.emit_signal("game_state_loaded")

func _on_save_game_pressed() -> void:
    """Save current game state via GameStateManager."""
    GameStateManager.save_game()
    # Show brief confirmation (optional popup or toast)

func _on_exit_game_pressed() -> void:
    """Quit the application."""
    get_tree().quit()

func _update_load_button_state() -> void:
    """Enable/disable load button based on save file existence."""
    btn_load_game.disabled = not GameStateManager.has_save_file()

func _show_menu() -> void:
    """Show the main menu (called when ESC pressed in-game)."""
    visible = true
    _update_load_button_state()
```

**SUCCESS CRITERIA:**
- New Game button hides menu and emits `new_game_requested` signal
- Load button disabled if no save file exists
- Save button calls `GameStateManager.save_game()` without errors
- Exit button quits application
- ESC key shows menu during gameplay

---

### TASK 2: Implement Player Spawn Docked Flow

**TARGET FILE(S):** 
- `scenes/game_world/world_manager.gd`
- `scenes/game_world/world_manager/world_generator.gd`

**DEPENDENCIES:**
- Read `autoload/GameState.gd` — `player_docked_at` field
- Read `autoload/EventBus.gd` — `player_docked`, `new_game_requested` signals
- Read `scenes/ui/station_menu/station_menu.gd` — Expects `player_docked` signal

**CHANGES:**
Modify world initialization to start player docked at Station Alpha:

**PSEUDO-CODE SIGNATURES (world_manager.gd):**
```gdscript
func _ready() -> void:
    # ... existing code ...
    EventBus.connect("new_game_requested", self, "_on_new_game_requested")

func _on_new_game_requested() -> void:
    """Reset GameState and start fresh game with player docked."""
    # Clear existing agents
    _cleanup_all_agents()
    # Reset GameState to defaults
    GameStateManager.reset_to_defaults()
    # Re-run world generator
    _setup_new_game()
    # Load the initial zone
    load_zone(Constants.INITIAL_ZONE_SCENE_PATH)

func _cleanup_all_agents() -> void:
    """Remove all spawned agent bodies."""
    for agent in _spawned_agent_bodies:
        if is_instance_valid(agent):
            agent.queue_free()
    _spawned_agent_bodies.clear()
```

**PSEUDO-CODE SIGNATURES (world_generator.gd):**
```gdscript
func generate_new_world() -> void:
    # ... existing character/ship/inventory creation ...
    
    # Set player starting state
    GameState.player_docked_at = "station_alpha"
    
    # Ensure player starts with 50 WP (per GDD)
    var player_char = GameState.characters.get(GameState.player_character_uid)
    if player_char:
        player_char.wealth_points = 50
        player_char.focus_points = 3
    
    # Emit docked signal AFTER zone loads (use call_deferred)
    call_deferred("_emit_initial_dock_signal")

func _emit_initial_dock_signal() -> void:
    """Emit player_docked after zone is ready so StationMenu opens."""
    yield(get_tree(), "idle_frame")
    if GameState.player_docked_at != "":
        EventBus.emit_signal("player_docked", GameState.player_docked_at)
```

**SUCCESS CRITERIA:**
- On New Game: Player spawns at Station Alpha position
- On New Game: `player_docked` signal emits → Station Menu opens automatically
- On New Game: Player has 50 WP and 3 FP
- On New Game: Trade and Contract interfaces accessible immediately
- Player movement disabled while docked (existing logic in player_controller_ship.gd)

---

### TASK 3: Verify Save/Load Serialization Completeness

**TARGET FILE:** `autoload/GameStateManager.gd`

**DEPENDENCIES:**
- Read `autoload/GameState.gd` — All Dictionary fields that need persistence
- Read `core/systems/contract_system.gd` — `active_contracts` structure
- Read `core/resource/asset_ship_template.gd` — `ship_quirks` array

**CHANGES:**
Audit and ensure all Phase 1 state is serialized:

**REQUIRED STATE FIELDS:**
```gdscript
# GameState fields that MUST persist:
- characters: Dictionary          # Character stats, WP, FP
- inventories: Dictionary         # Player cargo
- assets_ships: Dictionary        # Ship data including ship_quirks
- contracts: Dictionary           # Available contracts
- active_contracts: Dictionary    # Player's accepted contracts
- locations: Dictionary           # Market inventory state (quantities change)
- narrative_state: Dictionary     # Reputation, faction standings
- current_tu: int                 # Time progress
- player_character_uid: int
- player_docked_at: String
- session_stats: Dictionary
```

**PSEUDO-CODE (verification test):**
```gdscript
# In test_game_state_manager.gd or manual verification:
func test_save_load_preserves_all_state() -> void:
    # Setup: Create known state
    GameState.contracts["test_contract"] = {...}
    GameState.active_contracts["test_contract"] = {...}
    GameState.locations["station_alpha"].market_inventory["commodity_ore"].quantity = 50
    GameState.assets_ships["ship_001"].ship_quirks = ["scratched_hull"]
    GameState.narrative_state["reputation"] = "Dependable"
    GameState.player_docked_at = "station_beta"
    
    # Act: Save then reset then load
    GameStateManager.save_game()
    GameStateManager.reset_to_defaults()
    GameStateManager.load_game()
    
    # Assert: All state restored
    assert_eq(GameState.contracts.has("test_contract"), true)
    assert_eq(GameState.active_contracts.has("test_contract"), true)
    assert_eq(GameState.locations["station_alpha"].market_inventory["commodity_ore"].quantity, 50)
    assert_eq(GameState.assets_ships["ship_001"].ship_quirks, ["scratched_hull"])
    assert_eq(GameState.narrative_state["reputation"], "Dependable")
    assert_eq(GameState.player_docked_at, "station_beta")
```

**SUCCESS CRITERIA:**
- Save file includes ALL required fields
- Load restores exact state
- Market inventory changes persist (if player bought items, quantities reduced)
- Ship quirks array persists
- Active contracts persist with progress data

---

### TASK 4: Implement Game Over / Win Conditions UI

**TARGET FILE(S):**
- `core/ui/main_hud/main_hud.gd` (or new `game_over_popup.gd`)
- `core/ui/main_hud/main_hud.tscn` (add popup node)

**DEPENDENCIES:**
- Read `autoload/EventBus.gd` — `agent_disabled` signal
- Read `core/systems/combat_system.gd` — Player hull tracking
- Read `autoload/GlobalRefs.gd` — `player_agent_body` reference

**CHANGES:**
Detect player ship destruction and show Game Over popup:

**PSEUDO-CODE SIGNATURES:**
```gdscript
# In main_hud.gd (or separate game_over handler)

func _ready() -> void:
    # ... existing ...
    EventBus.connect("agent_disabled", self, "_on_agent_disabled")

func _on_agent_disabled(agent_body: Node) -> void:
    """Check if disabled agent is player; show Game Over if so."""
    if not is_instance_valid(agent_body):
        return
    if agent_body == GlobalRefs.player_agent_body:
        _show_game_over_popup()

func _show_game_over_popup() -> void:
    """Display Game Over screen with Return to Menu button."""
    # Pause game tree (optional)
    get_tree().paused = true
    
    # Show popup (either existing node or dynamically created)
    var popup = $GameOverPopup  # Add this node to main_hud.tscn
    popup.visible = true

func _on_return_to_menu_pressed() -> void:
    """Return to main menu from Game Over state."""
    get_tree().paused = false
    # Hide game over popup
    $GameOverPopup.visible = false
    # Show main menu
    EventBus.emit_signal("main_menu_requested")
```

**SUCCESS CRITERIA:**
- Player hull reaching 0 triggers `agent_disabled` signal
- Game Over popup appears immediately
- Game pauses while popup visible
- "Return to Menu" button shows Main Menu
- No crash on player death

---

### TASK 5: Write Full Game Loop Integration Tests

**TARGET FILE:** `tests/scenes/test_full_game_loop.gd`

**DEPENDENCIES:**
- Read all system files for API signatures
- Read `tests/helpers/` for test utilities

**CHANGES:**
Create comprehensive integration test covering complete player journey:

**PSEUDO-CODE TEST STRUCTURE:**
```gdscript
# File: tests/scenes/test_full_game_loop.gd
extends GutTest

var _player_uid: int = -1

func before_each() -> void:
    # Initialize minimal game state for testing
    GameStateManager.reset_to_defaults()
    _setup_test_world()

func after_each() -> void:
    # Cleanup
    pass

func _setup_test_world() -> void:
    """Create minimal world state for integration testing."""
    # Create player character with 50 WP
    # Create test ship
    # Create test locations with market inventory
    # Create test contracts

# --- Test Cases ---

func test_accept_contract_flow() -> void:
    """Player can accept a delivery contract."""
    var contracts = GlobalRefs.contract_system.get_available_contracts("station_alpha")
    assert_gt(contracts.size(), 0, "Contracts should be available")
    
    var result = GlobalRefs.contract_system.accept_contract(_player_uid, contracts[0].template_id)
    assert_true(result.success, "Contract acceptance should succeed")

func test_buy_cargo_for_contract() -> void:
    """Player can buy required cargo for contract."""
    # Accept contract that requires commodity_ore
    # Execute buy for required quantity
    # Verify WP deducted, inventory updated

func test_complete_contract_at_destination() -> void:
    """Player can complete contract when at destination with cargo."""
    # Setup: Player at destination with required cargo
    GameState.player_docked_at = "station_beta"  # Contract destination
    # Add cargo to inventory
    GlobalRefs.inventory_system.add_asset(_player_uid, InventoryType.COMMODITY, "commodity_ore", 10)
    
    # Accept contract
    var result = GlobalRefs.contract_system.accept_contract(_player_uid, "delivery_01")
    
    # Check completion
    var check = GlobalRefs.contract_system.check_contract_completion(_player_uid, "delivery_01")
    assert_true(check.can_complete, "Contract should be completable")
    
    # Complete
    var complete_result = GlobalRefs.contract_system.complete_contract(_player_uid, "delivery_01")
    assert_true(complete_result.success, "Contract completion should succeed")

func test_upkeep_deduction_on_time_tick() -> void:
    """Time clock overflow triggers WP upkeep deduction."""
    var initial_wp = GlobalRefs.character_system.get_wp(_player_uid)
    
    # Advance time to trigger tick
    GlobalRefs.time_system.add_time_units(Constants.TIME_CLOCK_MAX_TU)
    
    var final_wp = GlobalRefs.character_system.get_wp(_player_uid)
    assert_lt(final_wp, initial_wp, "WP should decrease after upkeep")

func test_full_contract_journey() -> void:
    """Complete journey: accept → buy cargo → travel → deliver → reward."""
    # 1. Start at Station Alpha, docked
    GameState.player_docked_at = "station_alpha"
    var initial_wp = GlobalRefs.character_system.get_wp(_player_uid)
    
    # 2. Accept delivery contract (destination: station_beta, cargo: ore x10)
    GlobalRefs.contract_system.accept_contract(_player_uid, "delivery_01")
    
    # 3. Buy required cargo
    GlobalRefs.trading_system.execute_buy(_player_uid, "station_alpha", "commodity_ore", 10)
    var wp_after_buy = GlobalRefs.character_system.get_wp(_player_uid)
    assert_lt(wp_after_buy, initial_wp, "WP should decrease after purchase")
    
    # 4. Simulate arrival at destination
    GameState.player_docked_at = "station_beta"
    
    # 5. Complete contract
    var result = GlobalRefs.contract_system.complete_contract(_player_uid, "delivery_01")
    assert_true(result.success, "Contract should complete successfully")
    
    # 6. Verify reward
    var final_wp = GlobalRefs.character_system.get_wp(_player_uid)
    assert_gt(final_wp, wp_after_buy, "WP should increase after contract reward")
```

**SUCCESS CRITERIA:**
- All integration tests pass
- Tests cover: contract accept, trading, contract completion, time/upkeep, full journey
- Tests run in isolation without requiring full scene tree
- Tests complete in < 5 seconds total

---

### TASK 6: Manual Integration Verification

**TARGET:** Full playthrough validation

**NO CODE CHANGES** — Manual testing checklist

---

## COMPREHENSIVE PLAYTEST CHECKLIST

Complete each test section in order. After each step, provide feedback:
- ✅ **PASS** — Works as expected
- ⚠️ **ISSUE** — Works but with problems (describe)
- ❌ **FAIL** — Does not work (describe error/behavior)

---

### TEST 1: Game Launch & Main Menu

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 1.1 | Launch the game | Main Menu appears with title "GDTLancer" visible | PASS |
| 1.2 | Observe Main Menu buttons | "New", "Load", "Save", "Settings", "Exit" buttons visible | PASS |
| 1.3 | Check "Load" button state | Load button should be DISABLED (greyed out) if no save file exists | PASS |
| 1.4 | Click "Exit" button | Game closes cleanly, no errors in console | PASS |

---

### TEST 2: New Game Initialization

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 2.1 | Launch game, click "New Game" | Main Menu hides | PASS |
| 2.2 | Observe screen after New Game | Station Menu appears (you are docked at "Station Alpha - Mining Hub") | PASS |
| 2.3 | Check station name label | Shows "Station Alpha - Mining Hub" or similar | PASS |
| 2.4 | Check HUD WP display | Shows "Current WP: 50" (top-left area) | PASS |
| 2.5 | Check HUD FP display | Shows "Current FP: 3" (top-left area) | PASS |
| 2.6 | Observe available buttons | Station Menu shows: "Trade", "Contracts", "Undock" buttons | PASS |

---

### TEST 3: Contract Board

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 3.1 | Click "Contracts" button | Contract Interface opens (modal/popup) | PASS |
| 3.2 | Observe contract list | At least 1-2 delivery contracts visible (e.g., "Deliver Ore") | PASS |
| 3.3 | Click on a contract in the list | Contract details panel shows: Title, Type, Destination, Required Cargo, Reward WP | PASS |
| 3.4 | Note contract details | Record: destination station, required commodity, quantity, reward amount | PASS |
| 3.5 | Click "Accept" button | Contract moves to "Active Contracts" section (or list updates) | PASS |
| 3.6 | Try to accept same contract again | Should NOT allow duplicate acceptance (button disabled or error) | PASS |
| 3.7 | Close Contract Interface | Contract Interface closes, Station Menu still visible | PASS |

---

### TEST 4: Trading System

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 4.1 | Click "Trade" button | Trade Interface opens | PASS |
| 4.2 | Observe station inventory | Left panel shows commodities station sells (e.g., Ore, Food, Tech, Fuel) with prices and quantities | PASS |
| 4.3 | Observe player cargo | Right panel shows "Your Cargo" — should be EMPTY at game start | PASS |
| 4.4 | Select a commodity to buy | Commodity row highlights or becomes selected | PASS |
| 4.5 | Set quantity (e.g., 10) | Quantity selector accepts input | PASS |
| 4.6 | Note WP before purchase | Record current WP value | PASS |
| 4.7 | Click "Buy" button | Transaction executes | PASS |
| 4.8 | Check WP after purchase | WP decreased by (quantity × buy_price) | PASS |
| 4.9 | Check player cargo | Purchased commodity now appears in player cargo with correct quantity | PASS |
| 4.10 | Check station inventory | Station's quantity of that commodity decreased | PASS |
| 4.11 | Buy cargo needed for contract | Purchase the commodity + quantity required by your accepted contract | PASS |
| 4.12 | Close Trade Interface | Trade Interface closes | PASS |

---

### TEST 5: Undocking

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 5.1 | Click "Undock" button | Station Menu closes | PASS |
| 5.2 | Observe game view | 3D flight view visible, ship can be controlled | PASS |
| 5.3 | Test ship movement | WASD/Arrow keys or flight controls move the ship | PASS |
| 5.4 | Observe surroundings | Station Alpha visible nearby; other objects (Station Beta) in distance | PASS |

---

### TEST 6: Flight & Navigation

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 6.1 | Locate Station Beta | Another station visible in the zone (may need to fly/look around) | PASS |
| 6.2 | Click on Station Beta to target | Target indicator appears on Station Beta | PASS |
| 6.3 | Use "Approach" button | Ship automatically flies toward Station Beta | PASS |
| 6.4 | Monitor flight progress | Ship moves toward target; distance decreases | PASS |
| 6.5 | Observe time passage | Time Clock in HUD advances as you fly | PASS |

---

### TEST 7: Combat Encounter (if triggered)

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 7.1 | Continue flying until encounter | Hostile NPC may spawn (red ship) — depends on danger level and RNG | PASS |
| 7.2 | If hostile spawns: observe behavior | Enemy approaches player and attempts to fire | PASS (no recieved attack indication for now implemented)|
| 7.3 | Target the enemy | Click enemy ship to select as target | PASS |
| 7.4 | Fire weapon (LMB or fire key) | Weapon fires at target (if in range) | PASS |
| 7.5 | Observe damage dealt | Target's hull decreases (visible in Target Info panel) | FAIL |
| 7.6 | Continue combat until victory or flee | Either destroy enemy (hull = 0) or use Flee button | ISSUE (enemy doesn't die) |
| 7.7 | Combat end | "Combat ended" state; you can continue flying | ??? |
| 7.8 | (If skipped) Note if no encounter | Combat encounters are probabilistic; may not trigger every flight | PASS |

---

### TEST 8: Docking at Destination

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 8.1 | Approach Station Beta | Fly close to Station Beta | PASS |
| 8.2 | Enter docking range | "Dock Available" prompt appears on HUD | PASS |
| 8.3 | Press dock key (F or interact) | Player docks at Station Beta | PASS |
| 8.4 | Observe Station Menu | Station Menu opens showing "Station Beta" name | PASS |

---

### TEST 9: Contract Completion

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 9.1 | Check Station Menu buttons | "✓ Complete: [Contract Name]" button visible (if you have cargo + at destination) | PASS (Will rework UI further on my own, placeholders are satisfactory) |
| 9.2 | Note WP before completion | Record current WP | PASS |
| 9.3 | Click "Complete Contract" button | Narrative Action UI appears (Action Check popup) | PASS |
| 9.4 | Observe Action Check UI | Shows action description, Cautious/Risky buttons, FP selector | PASS |
| 9.5 | Select approach (Cautious or Risky) | Button highlights/selects | PASS |
| 9.6 | Set FP to spend (0-3) | FP selector accepts value | PASS |
| 9.7 | Click "Confirm" | Roll resolves; outcome displayed | PASS |
| 9.8 | Observe outcome | Result tier shown (CritSuccess/SwC/Failure/etc.) with description | PASS |
| 9.9 | Acknowledge result | UI closes (click OK or auto-close) | PASS |
| 9.10 | Check WP after completion | WP increased by contract reward amount | PASS |
| 9.11 | Check cargo | Delivered commodity removed from player cargo | PASS |
| 9.12 | Check active contracts | Completed contract no longer in active list | PASS |

---

### TEST 10: Save Game

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 10.1 | Press ESC key | Main Menu appears (overlay on game) | PASS |
| 10.2 | Click "Save" button | Game saves (no error popup or console error) | PASS |
| 10.3 | Note current state | Record: current WP, FP, location, active contracts, cargo | PASS |
| 10.4 | Click anywhere or press ESC | Menu closes (if applicable) or stays open | PASS (Will rework on my own) |

---

### TEST 11: Load Game

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 11.1 | Continue playing: spend some WP | Make a purchase or change state somehow | PASS |
| 11.2 | Press ESC → Main Menu | Menu appears | PASS |
| 11.3 | Check "Load" button | Load button should now be ENABLED | PASS |
| 11.4 | Click "Load" button | Game loads saved state | PASS |
| 11.5 | Verify WP restored | WP matches what you recorded in TEST 10.3 | PASS |
| 11.6 | Verify location restored | Docked at same station as when saved | PASS |
| 11.7 | Verify cargo restored | Cargo matches saved state | PASS |
| 11.8 | Verify active contracts | Same contracts active as when saved | PASS |

---

### TEST 12: Game Over

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 12.1 | Undock and find/trigger combat | Get into combat with a hostile | PASS |
| 12.2 | Let enemy damage you | Stop fighting back; let enemy shoot you | FAIL - enemy does not attack or does not deal damage or player agent does not receive damage (should be a notification for that) |
| 12.3 | Observe hull decreasing | Player hull drops toward 0 | FAIL - not impemented? |
| 12.4 | Hull reaches 0 | "GAME OVER" overlay appears | FAIL - never triggered |
| 12.5 | Observe Game Over UI | Shows "GAME OVER" text and "Return to Menu" button | FAIL - never triggered |
| 12.6 | Game is paused | Background gameplay frozen while overlay visible | |
| 12.7 | Click "Return to Menu" | Main Menu appears; Game Over overlay closes | |
| 12.8 | Start New Game from menu | Can start fresh game after Game Over | |

---

### TEST 13: Edge Cases & Stability

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 13.1 | Try to buy with insufficient WP | Error message or transaction blocked | PASS |
| 13.2 | Try to complete contract without cargo | "Complete Contract" button not visible or disabled | PASS |
| 13.3 | Try to dock while already docked | No crash; action ignored or not available | PASS |
| 13.4 | Rapid button clicking | No crash; UI handles gracefully | PASS |
| 13.5 | Play for 5+ minutes continuously | No crashes, memory leaks, or performance degradation | PASS |
| 13.6 | Check console for errors | Note any red error messages during session | PASS |

---

## SUMMARY TEMPLATE

After completing all tests, fill in:

```
PLAYTEST SUMMARY — 2025-12-15

Tests Passed: 45/50
Tests with Issues: 2
Tests Failed: 3

BLOCKERS (must fix):
- TEST 7.5-7.6: Enemy hull doesn't decrease when hit / enemy doesn't die
- TEST 12.2-12.4: Player doesn't receive damage from enemy attacks
- TEST 12.4-12.7: Game Over never triggers (depends on above)

ISSUES (should fix):
- TEST 7.2: No received attack indication for player (HUD feedback)

OBSERVATIONS (nice to fix):
- Dock/Attack buttons now separated and functional
- Save/Load position and rotation working
- Hostile NPCs spawn and orbit player correctly

OVERALL VERDICT: [ ] READY FOR PHASE 1 DOD / [x] NEEDS FIXES
```

1. **No New Systems:** Sprint 10 integrates existing systems only. Do not create new gameplay systems.

2. **Preserve Existing APIs:** Do not change function signatures in TradingSystem, ContractSystem, CombatSystem, etc. Add only connecting logic.

3. **Signal-Driven Flow:** All major state transitions (dock, undock, contract complete, game over) must emit EventBus signals. UI components react to signals, not direct function calls.

4. **Pause Mode:** Game Over state should use `get_tree().paused = true`. Ensure Main Menu and popups have `pause_mode = PAUSE_MODE_PROCESS`.

5. **Starting State:**
   - Player starts DOCKED at Station Alpha
   - Starting WP: 50 (per GDD)
   - Starting FP: 3 (per GDD)
   - 3+ delivery contracts available at Station Alpha
   - Player cargo: Empty

6. **Save File Location:** Use `user://savegame.json` or similar. Do not hardcode absolute paths.

7. **Test Independence:** Integration tests must not depend on full scene tree. Mock or stub missing systems as needed.

---

## 5. DEFINITION OF DONE CHECKLIST (Phase 1)

After Sprint 10, verify all Phase 1 requirements:

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
- [ ] All unit tests pass (target: 180+ tests)

---

**END OF IMMEDIATE-TODO.md**
