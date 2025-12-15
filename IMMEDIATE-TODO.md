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
- [ ] **TASK 6:** Manual Integration Verification

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
**Instructions:** Complete each step in order. Report PASS/FAIL + any console errors or unexpected behavior.

---

#### FLOW 1: New Game Initialization

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1.1 | Launch game from editor (F5) or exported build | Main Menu appears with title "GDTLancer" | [ ] |
| 1.2 | Observe "Load" button state | "Load" button should be DISABLED (grayed out) if no save file exists | [ ] |
| 1.3 | Click "New" button | Main Menu hides; Station Menu opens automatically | [ ] |
| 1.4 | Observe Station Menu header | Should display "Station Alpha - Mining Hub" (or similar) | [ ] |
| 1.5 | Look at HUD top-left WP display | Should show "Current WP: 50" | [ ] |
| 1.6 | Look at HUD top-left FP display | Should show "Current FP: 3" | [ ] |
| 1.7 | Check console output | Should see "WorldGenerator: Player starting docked at station_alpha" or similar, NO red errors | [ ] |

---

#### FLOW 2: Contract Acceptance

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 2.1 | In Station Menu, click "Contracts" button | Contract Interface panel opens | [ ] |
| 2.2 | Observe contract list | At least 1-2 delivery contracts listed (e.g., "Deliver Ore to Station Beta") | [ ] |
| 2.3 | Click on a delivery contract in the list | Contract details appear: destination, required cargo type & quantity, reward WP | [ ] |
| 2.4 | Click "Accept" button | Contract moves to "Active" section; Accept button disables or list refreshes | [ ] |
| 2.5 | Check console output | Should see "contract_accepted" signal or similar log, NO errors | [ ] |
| 2.6 | Click "Close" to return to Station Menu | Contract Interface closes; Station Menu visible again | [ ] |

---

#### FLOW 3: Trading (Buy Cargo)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 3.1 | In Station Menu, click "Trade" button | Trade Interface opens showing Station inventory and Player cargo | [ ] |
| 3.2 | Observe Station inventory list | Should show commodities: Ore, Food, Tech, Fuel with prices and quantities | [ ] |
| 3.3 | Observe Player cargo section | Should be EMPTY (0 items) at game start | [ ] |
| 3.4 | Select "Ore" (or required contract cargo) in Station list | Item highlights; Buy button enables | [ ] |
| 3.5 | Set quantity to 10 (or contract requirement) | Quantity field shows 10; total cost displays (e.g., "Cost: 80 WP") | [ ] |
| 3.6 | Click "Buy" button | Transaction executes | [ ] |
| 3.7 | Observe WP display in HUD | WP should decrease (e.g., 50 → 42 if ore costs 8/unit) | [ ] |
| 3.8 | Observe Player cargo in Trade Interface | Should now show "Ore: 10" (or purchased quantity) | [ ] |
| 3.9 | Check console output | Should see "trade_transaction_completed" signal, NO errors | [ ] |
| 3.10 | Click "Close" to return to Station Menu | Trade Interface closes | [ ] |

---

#### FLOW 4: Undock and Flight

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 4.1 | In Station Menu, click "Undock" button | Station Menu closes; player ship visible in 3D space | [ ] |
| 4.2 | Observe console output | Should see "player_undocked" signal emitted | [ ] |
| 4.3 | Try moving ship (WASD or click "Manual Flight") | Ship responds to input; can rotate and thrust | [ ] |
| 4.4 | Look for Station Beta in the zone | Should see another station marker/model in distance | [ ] |
| 4.5 | Fly toward Station Beta (use Approach or manual) | Ship moves toward destination | [ ] |
| 4.6 | Observe time passing (clock in HUD if present) | Time ticks should increment as you fly | [ ] |
| 4.7 | (Optional) Wait for random encounter | Hostile NPC may spawn; combat_initiated signal in console | [ ] |
| 4.8 | Approach Station Beta until "Dock Available" prompt | HUD shows docking prompt near station | [ ] |

---

#### FLOW 5: Docking at Destination

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 5.1 | When "Dock Available" shows, press Interact/Dock key | Player docks; Station Menu opens for Station Beta | [ ] |
| 5.2 | Observe Station Menu header | Should display "Station Beta" (or destination name) | [ ] |
| 5.3 | Observe "Complete Contract" button | Should be VISIBLE if you have the required cargo and active contract for this destination | [ ] |
| 5.4 | Check console output | Should see "player_docked" signal with "station_beta" | [ ] |

---

#### FLOW 6: Contract Completion

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 6.1 | Click "Complete Contract" button (or "✓ Complete: [title]") | Narrative Action UI appears OR contract completes directly | [ ] |
| 6.2 | If Narrative Action UI appears: select approach (Cautious/Balanced/Risky) | Options visible with FP cost | [ ] |
| 6.3 | Click "Confirm" on Narrative Action | Action resolves; outcome popup shows success/complication | [ ] |
| 6.4 | Observe WP display after completion | WP should INCREASE by contract reward (e.g., +100 WP) | [ ] |
| 6.5 | Observe cargo after completion | Delivered cargo should be REMOVED from inventory | [ ] |
| 6.6 | Check "Contracts" → Active list | Completed contract should be GONE from active contracts | [ ] |
| 6.7 | Check console output | Should see "contract_completed" signal, session_stats.contracts_completed incremented | [ ] |

---

#### FLOW 7: Save Game

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 7.1 | Press ESC key (or click Menu button) | Main Menu appears over game | [ ] |
| 7.2 | Click "Save" button | Save executes; brief confirmation or no visible error | [ ] |
| 7.3 | Check console output | Should see "Game saved to slot 0" or similar, NO errors | [ ] |
| 7.4 | Note current state: WP value, location, active contracts | Write down for comparison after load | [ ] |
| 7.5 | Click "Exit" button | Game closes cleanly | [ ] |

---

#### FLOW 8: Load Game

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 8.1 | Relaunch game | Main Menu appears | [ ] |
| 8.2 | Observe "Load" button state | Should now be ENABLED (not grayed out) | [ ] |
| 8.3 | Click "Load" button | Game loads; Main Menu hides | [ ] |
| 8.4 | Observe current location | Should be at the station where you saved (Station Beta or wherever) | [ ] |
| 8.5 | Check WP display | Should match the WP value when you saved | [ ] |
| 8.6 | Open "Contracts" → check active list | Should show same active contracts (or none if completed) | [ ] |
| 8.7 | Open "Trade" → check player cargo | Should match cargo when you saved | [ ] |
| 8.8 | Check console output | Should see "Game loaded from slot 0", NO errors | [ ] |

---

#### FLOW 9: Game Over (Player Death)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 9.1 | Undock and find/trigger a hostile encounter | Combat initiates; enemy NPC attacks | [ ] |
| 9.2 | Let enemy destroy your ship (don't fight back or flee) | Player hull reaches 0 | [ ] |
| 9.3 | Observe screen when hull = 0 | "GAME OVER" overlay appears; game PAUSES | [ ] |
| 9.4 | Observe "Return to Menu" button | Button should be visible and clickable | [ ] |
| 9.5 | Click "Return to Menu" | Overlay hides; Main Menu appears; game UNPAUSES | [ ] |
| 9.6 | Check console output | Should see "agent_disabled" for player, then "main_menu_requested" | [ ] |

---

#### FLOW 10: Edge Cases (Optional)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 10.1 | Try to buy more cargo than you can afford | Buy should FAIL; error message or disabled button | [ ] |
| 10.2 | Try to complete contract without required cargo | Complete button should be HIDDEN or disabled | [ ] |
| 10.3 | Accept 3 contracts, then try to accept a 4th | Should FAIL with "Maximum active contracts reached" | [ ] |
| 10.4 | Save game, modify WP via console, then Load | WP should restore to saved value, not modified value | [ ] |

---

**SUMMARY CHECKLIST:**

| Flow | Description | Result |
|------|-------------|--------|
| 1 | New Game Initialization | [ ] PASS / [ ] FAIL |
| 2 | Contract Acceptance | [ ] PASS / [ ] FAIL |
| 3 | Trading (Buy Cargo) | [ ] PASS / [ ] FAIL |
| 4 | Undock and Flight | [ ] PASS / [ ] FAIL |
| 5 | Docking at Destination | [ ] PASS / [ ] FAIL |
| 6 | Contract Completion | [ ] PASS / [ ] FAIL |
| 7 | Save Game | [ ] PASS / [ ] FAIL |
| 8 | Load Game | [ ] PASS / [ ] FAIL |
| 9 | Game Over (Player Death) | [ ] PASS / [ ] FAIL |
| 10 | Edge Cases (Optional) | [ ] PASS / [ ] FAIL |

**SUCCESS CRITERIA:**
- Flows 1-9 all PASS
- No red errors in console during entire playtest
- Save/Load preserves all player state correctly
- Game Over → Return to Menu works without crash

---

## 4. CONSTRAINTS

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
