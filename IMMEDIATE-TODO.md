# IMMEDIATE-TODO.md
**Generated:** December 19, 2025  
**Target Sprint:** Sprint 11 - Ship Quirks System  
**Previous Sprint Status:** Sprint 10 (Full Game Loop Integration) COMPLETE — All manual tests passed

---

## 1. CONTEXT

We are implementing **Sprint 11: Ship Quirks System**, which completes the final Phase 1 Definition of Done item: "Ship quirks can be gained from failures." The existing infrastructure is partially in place:

- `ShipTemplate` has `ship_quirks: Array = []` field (in `/database/definitions/asset_ship_template.gd`)
- `NarrativeOutcomes` can return `"add_quirk"` effects
- `NarrativeActionSystem._apply_effects()` already appends quirks to ships

**What's missing:**
1. A **Ship Quirk Registry** defining available quirks and their mechanical effects
2. A **Quirk System** to manage quirks (add/remove API, apply mechanical penalties)
3. **Combat integration** to trigger quirks on hull damage thresholds
4. **UI display** of active quirks in the HUD or Hangar screen

This sprint delivers the complete ship quirks feature, enabling emergent narrative consequences from player actions.

---

## 2. ARCHITECTURE CHECK

Per `CONTENT-CREATION-MANUAL.md`, files are placed as follows:

| Content Type | Location |
|--------------|----------|
| **Quirk Template Definition** (Script) | `/database/definitions/quirk_template.gd` |
| **Quirk Instances** (Data) | `/database/registry/quirks/*.tres` |
| **Quirk System** (Logic) | `/src/core/systems/quirk_system.gd` |
| **Tests** | `/src/tests/core/systems/test_quirk_system.gd` |
| **UI Changes** | `/src/core/ui/` (existing files) |

---

## 3. FILE MANIFEST

### Files to CREATE:
| File | Purpose |
|------|---------|
| `/database/definitions/quirk_template.gd` | Resource class defining quirk properties |
| `/database/registry/quirks/quirk_scratched_hull.tres` | Phase 1 quirk instance |
| `/database/registry/quirks/quirk_jammed_landing_gear.tres` | Phase 1 quirk instance |
| `/database/registry/quirks/quirk_damaged_radiator.tres` | Phase 1 quirk instance |
| `/database/registry/quirks/quirk_reputation_tarnished.tres` | Phase 1 quirk (narrative) |
| `/src/core/systems/quirk_system.gd` | Stateless API for quirk management |
| `/src/tests/core/systems/test_quirk_system.gd` | GUT unit tests |

### Files to MODIFY:
| File | Change |
|------|--------|
| `/src/autoload/GlobalRefs.gd` | Add `quirk_system` reference and setter |
| `/src/autoload/EventBus.gd` | Add `quirk_added`, `quirk_removed` signals |
| `/src/autoload/TemplateDatabase.gd` | Load quirk templates on startup |
| `/src/core/systems/narrative_action_system.gd` | Use QuirkSystem API instead of direct append |
| `/src/core/systems/combat_system.gd` | Add quirk trigger on hull damage threshold |
| `/src/core/ui/main_hud/main_hud.gd` | Display active quirks (optional, simple label) |

### Files to READ for Context:
| File | Reason |
|------|--------|
| `/database/definitions/template.gd` | Base template class structure |
| `/src/autoload/GameState.gd` | State container patterns |
| `/src/core/systems/asset_system.gd` | Stateless system pattern reference |

---

## 4. ATOMIC TASKS

### Sprint 11 Checklist

- [ ] **TASK 1:** Create Quirk Template Definition & Registry
- [ ] **TASK 2:** Create Quirk System (Stateless API)
- [ ] **TASK 3:** Integrate Quirk System with NarrativeActionSystem
- [ ] **TASK 4:** Integrate Quirk System with CombatSystem
- [ ] **TASK 5:** Add Quirk Display to HUD
- [ ] **TASK 6:** Write GUT Unit Tests for QuirkSystem
- [ ] **TASK 7:** Manual Integration Verification

---

### TASK 1: Create Quirk Template Definition & Registry

**TARGET FILES:**
- `/database/definitions/quirk_template.gd`
- `/database/registry/quirks/quirk_scratched_hull.tres`
- `/database/registry/quirks/quirk_jammed_landing_gear.tres`
- `/database/registry/quirks/quirk_damaged_radiator.tres`
- `/database/registry/quirks/quirk_reputation_tarnished.tres`

**DEPENDENCIES:**
- Read `/database/definitions/template.gd` for base class pattern

**PSEUDO-CODE SIGNATURES:**
```gdscript
# File: /database/definitions/quirk_template.gd
extends Resource
class_name QuirkTemplate

export var quirk_id: String = ""
export var display_name: String = ""
export var description: String = ""
export var icon_path: String = ""

# Mechanical effects (modifiers applied when quirk is active)
export var piloting_modifier: int = 0      # Applied to piloting checks
export var trading_modifier: int = 0       # Applied to trading checks
export var combat_modifier: int = 0        # Applied to combat checks
export var reputation_modifier: int = 0    # Passive reputation drain

# Removal conditions
export var repair_wp_cost: int = 0         # WP to remove at station
export var auto_remove_on_repair: bool = true
export var is_permanent: bool = false      # Some quirks cannot be removed
```

**DATA INSTANCES (Example):**
```
# quirk_scratched_hull.tres
quirk_id: "scratched_hull"
display_name: "Scratched Hull"
description: "Cosmetic damage from a rough docking."
piloting_modifier: 0
trading_modifier: -1   # Less professional appearance
repair_wp_cost: 2

# quirk_jammed_landing_gear.tres
quirk_id: "jammed_landing_gear"
display_name: "Jammed Landing Gear"
description: "Landing gear sticks - docking is risky."
piloting_modifier: -1
repair_wp_cost: 5

# quirk_damaged_radiator.tres
quirk_id: "damaged_radiator"
display_name: "Damaged Radiator"
description: "Reduced cooling efficiency under stress."
combat_modifier: -1
repair_wp_cost: 8

# quirk_reputation_tarnished.tres
quirk_id: "reputation_tarnished"
display_name: "Tarnished Reputation"
description: "Word of your mishap has spread."
reputation_modifier: -1
repair_wp_cost: 0
auto_remove_on_repair: false
is_permanent: false
# (Removed over time or via narrative action)
```

**SUCCESS CRITERIA:**
- `quirk_template.gd` defines all required export vars
- All 4 `.tres` files created and loadable in Godot Inspector
- No script errors on project reload

---

### TASK 2: Create Quirk System (Stateless API)

**TARGET FILE:** `/src/core/systems/quirk_system.gd`

**DEPENDENCIES:**
- `/src/autoload/GlobalRefs.gd` — Must add setter for quirk_system
- `/src/autoload/EventBus.gd` — Must add signals
- `/src/autoload/TemplateDatabase.gd` — Must load quirk templates
- `/src/core/systems/asset_system.gd` — Pattern reference

**PSEUDO-CODE SIGNATURES:**
```gdscript
# File: /src/core/systems/quirk_system.gd
extends Node

func _ready() -> void:
    """Register with GlobalRefs."""
    GlobalRefs.set_quirk_system(self)
    print("QuirkSystem Ready.")


# --- Public API ---


func add_quirk_to_ship(ship_uid: int, quirk_id: String) -> bool:
    """Add a quirk to a ship. Returns true if added, false if duplicate.
    
    Args:
        ship_uid: The UID of the ship in GameState.assets_ships.
        quirk_id: The quirk template ID (e.g., "scratched_hull").
    
    Behavior:
        - Validates ship exists.
        - Checks for duplicate quirk (no stacking by default).
        - Appends quirk_id to ship.ship_quirks array.
        - Emits EventBus.quirk_added(ship_uid, quirk_id).
    """
    pass


func remove_quirk_from_ship(ship_uid: int, quirk_id: String) -> bool:
    """Remove a quirk from a ship. Returns true if removed.
    
    Args:
        ship_uid: The UID of the ship.
        quirk_id: The quirk to remove.
    
    Behavior:
        - Validates ship exists and has quirk.
        - Removes quirk_id from ship.ship_quirks.
        - Emits EventBus.quirk_removed(ship_uid, quirk_id).
    """
    pass


func get_quirks_for_ship(ship_uid: int) -> Array:
    """Get all quirk IDs for a ship. Returns COPY of array."""
    pass


func get_quirk_template(quirk_id: String) -> QuirkTemplate:
    """Get QuirkTemplate resource by ID from TemplateDatabase."""
    pass


func get_total_modifier(ship_uid: int, modifier_type: String) -> int:
    """Calculate total modifier from all quirks on a ship.
    
    Args:
        ship_uid: The ship to check.
        modifier_type: "piloting", "trading", "combat", or "reputation".
    
    Returns:
        Sum of all quirk modifiers of that type.
    """
    pass


func repair_quirk(ship_uid: int, quirk_id: String, char_uid: int) -> Dictionary:
    """Attempt to repair/remove a quirk at a station.
    
    Args:
        ship_uid: Ship with the quirk.
        quirk_id: Quirk to repair.
        char_uid: Character paying for repair.
    
    Returns:
        {success: bool, wp_cost: int, reason: String}
    
    Behavior:
        - Checks quirk exists and is repairable.
        - Checks character has enough WP.
        - Deducts WP via CharacterSystem.
        - Removes quirk.
    """
    pass
```

**GlobalRefs.gd ADDITION:**
```gdscript
# Add variable:
var quirk_system: Node = null

# Add setter:
func set_quirk_system(system: Node) -> void:
    quirk_system = system
```

**EventBus.gd ADDITION:**
```gdscript
signal quirk_added(ship_uid, quirk_id)
signal quirk_removed(ship_uid, quirk_id)
```

**TemplateDatabase.gd ADDITION:**
```gdscript
# In _load_all_templates(), add:
_load_templates_from_directory("res://database/registry/quirks/")
```

**SUCCESS CRITERIA:**
- QuirkSystem registered in GlobalRefs
- `add_quirk_to_ship()` prevents duplicates
- `get_total_modifier()` correctly sums quirk penalties
- `repair_quirk()` deducts WP and removes quirk
- EventBus signals emitted on add/remove

---

### TASK 3: Integrate Quirk System with NarrativeActionSystem

**TARGET FILE:** `/src/core/systems/narrative_action_system.gd`

**DEPENDENCIES:**
- TASK 2 (QuirkSystem must exist)

**CHANGES:**
Replace direct array append with QuirkSystem API call in `_apply_effects()`:

**PSEUDO-CODE (Current → Updated):**
```gdscript
# BEFORE (current implementation around line 175):
if effects.has("add_quirk") and is_instance_valid(GlobalRefs.asset_system):
    var quirk_id: String = str(effects.get("add_quirk"))
    var ship = GlobalRefs.asset_system.get_ship_for_character(char_uid)
    if is_instance_valid(ship):
        ship.ship_quirks.append(quirk_id)
        applied["quirk_added"] = quirk_id

# AFTER (using QuirkSystem):
if effects.has("add_quirk"):
    var quirk_id: String = str(effects.get("add_quirk"))
    var character = GameState.characters.get(char_uid)
    if character and character.active_ship_uid != -1:
        if is_instance_valid(GlobalRefs.quirk_system):
            var added: bool = GlobalRefs.quirk_system.add_quirk_to_ship(
                character.active_ship_uid, quirk_id
            )
            if added:
                applied["quirk_added"] = quirk_id
```

**SUCCESS CRITERIA:**
- NarrativeActionSystem uses QuirkSystem.add_quirk_to_ship()
- No duplicate quirks added on repeated failures
- Applied effects dictionary still reports quirk_added correctly

---

### TASK 4: Integrate Quirk System with CombatSystem

**TARGET FILE:** `/src/core/systems/combat_system.gd`

**DEPENDENCIES:**
- TASK 2 (QuirkSystem must exist)
- Read `combat_system.gd` to understand damage flow

**CHANGES:**
Add quirk trigger when ship takes significant hull damage:

**PSEUDO-CODE SIGNATURES:**
```gdscript
# Add new private function:

func _check_damage_quirk_trigger(ship_uid: int, damage_dealt: int, current_hull: int, max_hull: int) -> void:
    """Potentially add a quirk when ship takes heavy damage.
    
    Trigger conditions (Phase 1 - simple):
        - Damage >= 25% of max_hull in single hit → 50% chance of quirk
        - Hull drops below 25% → guaranteed quirk
    
    Quirk selection:
        - Random from pool: ["damaged_radiator", "scratched_hull"]
    """
    if not is_instance_valid(GlobalRefs.quirk_system):
        return
    
    var trigger_quirk: bool = false
    var damage_ratio: float = float(damage_dealt) / float(max_hull)
    var hull_ratio: float = float(current_hull) / float(max_hull)
    
    # Heavy hit trigger
    if damage_ratio >= 0.25:
        trigger_quirk = randf() < 0.5  # 50% chance
    
    # Low hull trigger (guaranteed)
    if hull_ratio <= 0.25:
        trigger_quirk = true
    
    if trigger_quirk:
        var combat_quirks: Array = ["damaged_radiator", "scratched_hull"]
        var quirk_id: String = combat_quirks[randi() % combat_quirks.size()]
        GlobalRefs.quirk_system.add_quirk_to_ship(ship_uid, quirk_id)
```

**Integration point:**
Call `_check_damage_quirk_trigger()` inside the damage application function after hull is updated.

**SUCCESS CRITERIA:**
- Ships can gain quirks from combat damage
- Heavy hits have chance to add quirks
- Critical hull threshold guarantees quirk
- Player notified via quirk_added signal (UI will display)

---

### TASK 5: Add Quirk Display to HUD

**TARGET FILES:**
- `/src/core/ui/main_hud/main_hud.gd`
- `/src/core/ui/main_hud/main_hud.tscn`

**DEPENDENCIES:**
- TASK 2 (QuirkSystem must exist)
- EventBus signals: `quirk_added`, `quirk_removed`

**CHANGES:**
Add simple label/icon display for active quirks:

**PSEUDO-CODE SIGNATURES:**
```gdscript
# In main_hud.gd:

onready var quirk_container: HBoxContainer = $QuirkContainer  # Add to .tscn

func _ready() -> void:
    # ... existing code ...
    EventBus.connect("quirk_added", self, "_on_quirk_changed")
    EventBus.connect("quirk_removed", self, "_on_quirk_changed")
    EventBus.connect("game_state_loaded", self, "_refresh_quirk_display")

func _on_quirk_changed(_ship_uid: int, _quirk_id: String) -> void:
    """Refresh display when any quirk changes."""
    _refresh_quirk_display()

func _refresh_quirk_display() -> void:
    """Update quirk icons/labels for player ship."""
    # Clear existing children
    for child in quirk_container.get_children():
        child.queue_free()
    
    # Get player ship quirks
    if not is_instance_valid(GlobalRefs.asset_system):
        return
    var ship = GlobalRefs.asset_system.get_player_ship()
    if not is_instance_valid(ship):
        return
    
    # For each quirk, add a label (Phase 1: simple text)
    for quirk_id in ship.ship_quirks:
        var quirk_template = GlobalRefs.quirk_system.get_quirk_template(quirk_id)
        if quirk_template:
            var label = Label.new()
            label.text = "[" + quirk_template.display_name + "]"
            label.add_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red tint
            quirk_container.add_child(label)
```

**TSCN ADDITION:**
Add `QuirkContainer` (HBoxContainer) to main_hud.tscn, positioned near ship status area.

**SUCCESS CRITERIA:**
- Quirks displayed on HUD when gained
- Display updates on quirk add/remove
- Display refreshes on game load
- No errors if no quirks present

---

### TASK 6: Write GUT Unit Tests for QuirkSystem

**TARGET FILE:** `/src/tests/core/systems/test_quirk_system.gd`

**DEPENDENCIES:**
- TASK 1 (QuirkTemplate and instances)
- TASK 2 (QuirkSystem)

**PSEUDO-CODE TEST STRUCTURE:**
```gdscript
# File: /src/tests/core/systems/test_quirk_system.gd
extends GutTest

var _mock_ship_uid: int = 1001

func before_each() -> void:
    # Setup: Ensure GameState has a test ship
    var test_ship = ShipTemplate.new()
    test_ship.ship_quirks = []
    GameState.assets_ships[_mock_ship_uid] = test_ship

func after_each() -> void:
    # Cleanup
    GameState.assets_ships.erase(_mock_ship_uid)


# --- Test Cases ---

func test_add_quirk_success() -> void:
    """Adding a valid quirk returns true and appends to ship."""
    var result = GlobalRefs.quirk_system.add_quirk_to_ship(_mock_ship_uid, "scratched_hull")
    assert_true(result, "add_quirk_to_ship should return true")
    
    var quirks = GlobalRefs.quirk_system.get_quirks_for_ship(_mock_ship_uid)
    assert_has(quirks, "scratched_hull", "Ship should have scratched_hull quirk")

func test_add_duplicate_quirk_fails() -> void:
    """Adding the same quirk twice returns false (no stacking)."""
    GlobalRefs.quirk_system.add_quirk_to_ship(_mock_ship_uid, "scratched_hull")
    var result = GlobalRefs.quirk_system.add_quirk_to_ship(_mock_ship_uid, "scratched_hull")
    assert_false(result, "Duplicate quirk should return false")
    
    var quirks = GlobalRefs.quirk_system.get_quirks_for_ship(_mock_ship_uid)
    assert_eq(quirks.count("scratched_hull"), 1, "Should only have one instance")

func test_remove_quirk_success() -> void:
    """Removing an existing quirk returns true."""
    GlobalRefs.quirk_system.add_quirk_to_ship(_mock_ship_uid, "scratched_hull")
    var result = GlobalRefs.quirk_system.remove_quirk_from_ship(_mock_ship_uid, "scratched_hull")
    assert_true(result, "remove_quirk should return true")
    
    var quirks = GlobalRefs.quirk_system.get_quirks_for_ship(_mock_ship_uid)
    assert_does_not_have(quirks, "scratched_hull")

func test_get_total_modifier_sums_correctly() -> void:
    """Total modifier sums all quirk penalties."""
    GlobalRefs.quirk_system.add_quirk_to_ship(_mock_ship_uid, "jammed_landing_gear")  # piloting: -1
    GlobalRefs.quirk_system.add_quirk_to_ship(_mock_ship_uid, "scratched_hull")       # trading: -1
    
    var piloting_mod = GlobalRefs.quirk_system.get_total_modifier(_mock_ship_uid, "piloting")
    var trading_mod = GlobalRefs.quirk_system.get_total_modifier(_mock_ship_uid, "trading")
    
    assert_eq(piloting_mod, -1, "Piloting modifier should be -1")
    assert_eq(trading_mod, -1, "Trading modifier should be -1")

func test_repair_quirk_deducts_wp() -> void:
    """Repairing a quirk costs WP and removes the quirk."""
    # Setup character with WP
    var char_uid = GameState.player_character_uid
    GlobalRefs.character_system.add_wp(char_uid, 10)
    var initial_wp = GlobalRefs.character_system.get_wp(char_uid)
    
    GlobalRefs.quirk_system.add_quirk_to_ship(_mock_ship_uid, "scratched_hull")  # repair_wp_cost: 2
    
    var result = GlobalRefs.quirk_system.repair_quirk(_mock_ship_uid, "scratched_hull", char_uid)
    assert_true(result.success, "Repair should succeed")
    
    var final_wp = GlobalRefs.character_system.get_wp(char_uid)
    assert_eq(final_wp, initial_wp - 2, "WP should be deducted")
    
    var quirks = GlobalRefs.quirk_system.get_quirks_for_ship(_mock_ship_uid)
    assert_does_not_have(quirks, "scratched_hull", "Quirk should be removed")

func test_get_quirk_template_returns_resource() -> void:
    """get_quirk_template returns valid QuirkTemplate resource."""
    var template = GlobalRefs.quirk_system.get_quirk_template("scratched_hull")
    assert_not_null(template, "Template should not be null")
    assert_eq(template.quirk_id, "scratched_hull")
    assert_eq(template.display_name, "Scratched Hull")
```

**SUCCESS CRITERIA:**
- All 6+ test cases pass
- Tests run in isolation (no side effects)
- Tests complete in < 2 seconds

---

### TASK 7: Manual Integration Verification

**TARGET:** Full playthrough validation with quirks

**NO CODE CHANGES** — Manual testing checklist

---

## MANUAL PLAYTEST CHECKLIST (Sprint 11)

### TEST A: Quirk from Narrative Action

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| A.1 | Start New Game, accept contract | Docked at Station Alpha | |
| A.2 | Undock, fly to Station Beta | In flight | |
| A.3 | Dock at Station Beta | Docking triggers dock_arrival Narrative Action | |
| A.4 | Select "Act Risky" with 0 FP | Roll performed | |
| A.5 | If Failure/SwC: check HUD | Quirk label appears (e.g., "[Jammed Landing Gear]") | |
| A.6 | Open Station Menu → Hangar/Repair | Quirk listed with repair cost | |

### TEST B: Quirk from Combat Damage

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| B.1 | Undock and trigger combat | Combat encounter starts | |
| B.2 | Let enemy deal heavy damage (>25% hull in one hit) | Potential quirk trigger | |
| B.3 | Continue until hull < 25% | Guaranteed quirk trigger | |
| B.4 | Check HUD | New quirk label visible | |
| B.5 | Win combat, dock at station | Can repair quirks | |

### TEST C: Quirk Mechanical Effect

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| C.1 | Have "jammed_landing_gear" quirk | Piloting modifier: -1 | |
| C.2 | Perform dock_arrival Narrative Action | Roll result shows penalty applied | |
| C.3 | Repair the quirk at station | WP deducted, quirk removed | |
| C.4 | Perform another dock_arrival | No penalty (quirk gone) | |

### TEST D: Save/Load Persistence

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| D.1 | Gain a quirk, save game | Save completes | |
| D.2 | Gain another quirk, note total quirks | 2 quirks on ship | |
| D.3 | Load saved game | Restores to 1 quirk state | |
| D.4 | Check HUD | Only original quirk displayed | |

---

## 5. CONSTRAINTS

1. **Stateless System Pattern:** QuirkSystem must NOT store state. All quirk data lives in `ship.ship_quirks` (accessed via `GameState.assets_ships`).

2. **Use EventBus Signals:** All quirk changes must emit signals:
   - `EventBus.quirk_added(ship_uid: int, quirk_id: String)`
   - `EventBus.quirk_removed(ship_uid: int, quirk_id: String)`

3. **No Quirk Stacking:** A ship cannot have multiple instances of the same quirk ID.

4. **Strict Typing:** All functions must use static type hints per project coding standards.

5. **Template Loading via TemplateDatabase:** Quirk templates must be loaded via the existing `TemplateDatabase` pattern, not direct `load()` calls in the system.

6. **GDScript 3.x Syntax:** NO `@export`, `@onready`, `await`, `super()`. Use `export var`, `onready var`, `yield`.

7. **Signal Registration:** Add required signals to `EventBus.gd`:
   ```gdscript
   signal quirk_added(ship_uid, quirk_id)
   signal quirk_removed(ship_uid, quirk_id)
   ```

---

## 6. DEFINITION OF DONE UPDATE

After Sprint 11, the Phase 1 Definition of Done checklist should read:

- [PASS] Player can start new game and spawn at station
- [PASS] Player can view and accept contracts
- [PASS] Player can buy/sell commodities at stations
- [PASS] Player can fly between two stations
- [PASS] Player can complete delivery contracts and receive rewards
- [PASS] Combat encounters can trigger during flight
- [PASS] Player can fight and disable enemy ships
- [PASS] Narrative Actions resolve with visible outcomes
- [PASS] Time system triggers upkeep costs
- [**PASS**] Ship quirks can be gained from failures  ← **This Sprint**
- [PASS] Game state can be saved and loaded
- [PASS] No critical bugs or crashes during 15-minute play session
- [PASS] All unit tests pass (target: 190+ tests)

---
---

# SPRINT 12: Global Agent Persistency

**Target:** Proof of concept for "Nothing appears and disappears without a reason"

---

## 1. CONTEXT (Sprint 12)

We are implementing **Sprint 12: Global Agent Persistency**, which creates a fully persistent albeit minimalistic world. This is the foundation for the "Living World" pillar.

**Core Philosophy:** "Nothing appears and nothing disappears without a reason."

**Goals:**
1. All NPCs spawn on New Game in different parts of space (zone size: ~300,000 units)
2. Fixed NPC population count (~100 agents, with slight randomization)
3. All agents neutral by default, patrol/orbit around virtual anchor points
4. Combat behavior when attacked (pursue/attack, flee when low hull, return to anchor when disengaged)
5. Subtle HUD indicators showing all NPC positions (faint bracket markers)
6. Full serialization of ALL agent properties (position, rotation, equipment, cargo, quirks, etc.)

**This replaces the current "encounter spawning" model** where NPCs appear temporarily for combat and despawn.

---

## 2. ARCHITECTURE CHECK (Sprint 12)

Per `CONTENT-CREATION-MANUAL.md`:

| Content Type | Location |
|--------------|----------|
| **World Population System** (Logic) | `/src/core/systems/world_population_system.gd` |
| **Anchor Point Data** (Data) | `/database/registry/anchors/*.tres` (or generated) |
| **NPC State Storage** | `GameState.world_agents` (new Dictionary) |
| **HUD Agent Markers** (UI Logic) | `/src/core/ui/main_hud/agent_marker_overlay.gd` |
| **Tests** | `/src/tests/core/systems/test_world_population_system.gd` |

---

## 3. FILE MANIFEST (Sprint 12)

### Files to CREATE:
| File | Purpose |
|------|---------|
| `/src/core/systems/world_population_system.gd` | Manages persistent NPC population lifecycle |
| `/src/core/ui/main_hud/agent_marker_overlay.gd` | Renders HUD markers for all agents |
| `/database/definitions/anchor_template.gd` | Resource class for patrol anchor points |
| `/src/tests/core/systems/test_world_population_system.gd` | GUT unit tests |

### Files to MODIFY:
| File | Change |
|------|--------|
| `/src/autoload/GameState.gd` | Add `world_agents: Dictionary` for NPC persistent state |
| `/src/autoload/GameStateManager.gd` | Serialize/deserialize `world_agents` with full properties |
| `/src/autoload/GlobalRefs.gd` | Add `world_population_system` reference |
| `/src/autoload/EventBus.gd` | Add `npc_population_initialized`, `agent_state_changed` signals |
| `/src/core/systems/agent_system.gd` | Integrate with WorldPopulationSystem for spawning |
| `/src/core/agents/agent.gd` | Add patrol/orbit behavior state, anchor_point reference |
| `/src/modules/piloting/ship_controller_ai.gd` | Add `STATE_PATROL` mode with orbit behavior |
| `/src/core/ui/main_hud/main_hud.gd` | Instantiate AgentMarkerOverlay |
| `/src/core/ui/main_hud/main_hud.tscn` | Add CanvasLayer for markers |
| `/scenes/game_world/world_manager/world_generator.gd` | Call WorldPopulationSystem on new game |

---

## 4. ATOMIC TASKS (Sprint 12)

### Sprint 12 Checklist

- [ ] **TASK 12.1:** Add GameState.world_agents & Anchor Template
- [ ] **TASK 12.2:** Create World Population System
- [ ] **TASK 12.3:** Implement NPC Patrol/Orbit Behavior
- [ ] **TASK 12.4:** Integrate NPC Spawning with WorldPopulationSystem
- [ ] **TASK 12.5:** Create Agent Marker HUD Overlay
- [ ] **TASK 12.6:** Implement Full Agent Serialization
- [ ] **TASK 12.7:** Write GUT Unit Tests
- [ ] **TASK 12.8:** Manual Integration Verification

---

### TASK 12.1: Add GameState.world_agents & Anchor Template

**TARGET FILES:**
- `/src/autoload/GameState.gd`
- `/database/definitions/anchor_template.gd`

**DEPENDENCIES:** None

**PSEUDO-CODE SIGNATURES:**

```gdscript
# File: /src/autoload/GameState.gd
# ADD new Dictionary for persistent NPC state:

# Key: agent_uid (int), Value: Dictionary with full agent state
var world_agents: Dictionary = {}

# Structure of each world_agents entry:
# {
#   "agent_uid": int,
#   "character_uid": int,
#   "template_id": String,
#   "position": Vector3,
#   "rotation": Vector3,
#   "anchor_point": Vector3,      # Patrol center
#   "orbit_radius": float,        # Distance from anchor
#   "orbit_speed": float,         # Angular velocity
#   "current_state": String,      # "patrol", "hostile", "fleeing", "disabled"
#   "hull_current": int,
#   "is_hostile": bool,
#   "cargo": Array,               # Item IDs in hold
#   "equipped_weapons": Array,
#   "ship_quirks": Array,
#   "spawned_body_ref": NodePath  # Empty if not currently spawned
# }
```

```gdscript
# File: /database/definitions/anchor_template.gd
extends Resource
class_name AnchorTemplate

export var anchor_id: String = ""
export var display_name: String = ""
export var position: Vector3 = Vector3.ZERO
export var anchor_type: String = "generic"  # "station", "asteroid_field", "nav_beacon", "generic"
export var typical_traffic: int = 5         # How many NPCs typically orbit here
```

**SUCCESS CRITERIA:**
- `GameState.world_agents` exists and is empty on init
- `anchor_template.gd` compiles without errors
- Both added to `reset_to_defaults()` in GameStateManager

---

### TASK 12.2: Create World Population System

**TARGET FILE:** `/src/core/systems/world_population_system.gd`

**DEPENDENCIES:**
- TASK 12.1 (GameState.world_agents)
- `/src/core/systems/agent_system.gd` — Pattern reference

**PSEUDO-CODE SIGNATURES:**

```gdscript
# File: /src/core/systems/world_population_system.gd
extends Node

const ZONE_SIZE: float = 300000.0
const BASE_POPULATION: int = 100
const POPULATION_VARIANCE: int = 20  # +/- randomization

var _anchor_points: Array = []  # Generated virtual anchors


func _ready() -> void:
    GlobalRefs.set_world_population_system(self)
    print("WorldPopulationSystem Ready.")


func initialize_world_population(seed_value: String) -> void:
    """Generate initial NPC population on New Game.
    
    Args:
        seed_value: World seed for deterministic generation.
    
    Behavior:
        1. Generate anchor points across zone.
        2. Create population_count NPC entries in GameState.world_agents.
        3. Assign each NPC to an anchor with random orbit params.
        4. Emit npc_population_initialized signal.
    """
    pass


func _generate_anchor_points(count: int, rng: RandomNumberGenerator) -> Array:
    """Generate virtual patrol anchors distributed across zone.
    
    Returns:
        Array of Vector3 positions.
    """
    pass


func _create_npc_agent_data(agent_uid: int, anchor_pos: Vector3, rng: RandomNumberGenerator) -> Dictionary:
    """Create persistent data Dictionary for a single NPC.
    
    Returns:
        Full agent state dictionary for GameState.world_agents.
    """
    pass


func get_all_agent_data() -> Array:
    """Returns array of all world_agents data (copies)."""
    pass


func get_agent_data(agent_uid: int) -> Dictionary:
    """Get specific agent's persistent data."""
    pass


func update_agent_state(agent_uid: int, updates: Dictionary) -> void:
    """Update an agent's persistent state (position, hull, state, etc.).
    
    Called by agents during gameplay to persist their current state.
    """
    pass


func get_agents_near_position(position: Vector3, radius: float) -> Array:
    """Get all agent UIDs within radius of position.
    
    Used for spawning visible agents and HUD markers.
    """
    pass


func mark_agent_disabled(agent_uid: int) -> void:
    """Mark an agent as disabled (hull=0). Does NOT despawn."""
    pass


func respawn_disabled_agent(agent_uid: int, repair_cost_wp: int) -> bool:
    """Allow disabled agents to be 'recovered' at stations (future feature)."""
    pass
```

**SUCCESS CRITERIA:**
- System registered in GlobalRefs
- `initialize_world_population()` creates ~100 entries in `GameState.world_agents`
- Anchor points distributed across 300,000 unit zone
- Each NPC has valid orbit parameters
- EventBus.npc_population_initialized emitted

---

### TASK 12.3: Implement NPC Patrol/Orbit Behavior

**TARGET FILES:**
- `/src/modules/piloting/ship_controller_ai.gd`
- `/src/core/agents/agent.gd`

**DEPENDENCIES:**
- TASK 12.1 (agent state structure)
- Existing AI state machine

**PSEUDO-CODE SIGNATURES:**

```gdscript
# File: /src/modules/piloting/ship_controller_ai.gd
# ADD new state constant:
const STATE_PATROL = "patrol"

# ADD new state variables:
var anchor_point: Vector3 = Vector3.ZERO
var orbit_radius: float = 500.0
var orbit_speed: float = 0.05  # Radians per second
var orbit_angle: float = 0.0   # Current angle around anchor

func _process_state_patrol(delta: float) -> void:
    """Orbit around anchor_point at orbit_radius.
    
    Behavior:
        - Incrementally move along circular path
        - Face movement direction (tangent to orbit)
        - If attacked → transition to STATE_PURSUING
    """
    orbit_angle += orbit_speed * delta
    var target_pos = anchor_point + Vector3(
        cos(orbit_angle) * orbit_radius,
        0,
        sin(orbit_angle) * orbit_radius
    )
    _set_navigation_target(target_pos)


func set_patrol_anchor(anchor_pos: Vector3, radius: float, speed: float) -> void:
    """Configure patrol behavior."""
    anchor_point = anchor_pos
    orbit_radius = radius
    orbit_speed = speed
    orbit_angle = randf() * TAU  # Random start position
    _change_state(STATE_PATROL)


func _on_attacked() -> void:
    """React to being attacked - become hostile, pursue attacker."""
    if _current_state == STATE_PATROL:
        _change_state(STATE_PURSUING)
        # Set attacker as target


func _on_target_lost() -> void:
    """When target escapes or is destroyed, return to patrol."""
    if anchor_point != Vector3.ZERO:
        _change_state(STATE_PATROL)
```

```gdscript
# File: /src/core/agents/agent.gd
# ADD persistent state sync:

var persistent_uid: int = -1  # Links to GameState.world_agents key

func sync_to_persistent_state() -> void:
    """Update GameState.world_agents with current live state."""
    if persistent_uid < 0:
        return
    if not is_instance_valid(GlobalRefs.world_population_system):
        return
    
    GlobalRefs.world_population_system.update_agent_state(persistent_uid, {
        "position": global_transform.origin,
        "rotation": rotation_degrees,
        "hull_current": _get_current_hull(),
        "current_state": _get_ai_state()
    })


func load_from_persistent_state(data: Dictionary) -> void:
    """Initialize agent from saved world_agents data."""
    global_transform.origin = data.get("position", Vector3.ZERO)
    rotation_degrees = data.get("rotation", Vector3.ZERO)
    # Configure AI controller with patrol data
    var ai_controller = get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
    if ai_controller and ai_controller.has_method("set_patrol_anchor"):
        ai_controller.set_patrol_anchor(
            data.get("anchor_point", Vector3.ZERO),
            data.get("orbit_radius", 500.0),
            data.get("orbit_speed", 0.05)
        )
```

**SUCCESS CRITERIA:**
- NPCs orbit their anchor points smoothly
- NPCs face their movement direction
- NPCs become hostile when attacked
- NPCs return to patrol when target is lost/out of range
- Position syncs to GameState.world_agents periodically

---

### TASK 12.4: Integrate NPC Spawning with WorldPopulationSystem

**TARGET FILES:**
- `/src/core/systems/agent_system.gd`
- `/scenes/game_world/world_manager/world_generator.gd`

**DEPENDENCIES:**
- TASK 12.2 (WorldPopulationSystem)
- TASK 12.3 (Patrol behavior)

**PSEUDO-CODE SIGNATURES:**

```gdscript
# File: /src/core/systems/agent_system.gd
# MODIFY to support persistent agent spawning:

func spawn_persistent_npc(agent_uid: int) -> KinematicBody:
    """Spawn an NPC from its persistent data in GameState.world_agents.
    
    Args:
        agent_uid: Key in GameState.world_agents
        
    Returns:
        Spawned KinematicBody or null
    """
    if not GameState.world_agents.has(agent_uid):
        printerr("AgentSpawner: No world_agent with uid: ", agent_uid)
        return null
    
    var agent_data = GameState.world_agents[agent_uid]
    var position = agent_data.get("position", Vector3.ZERO)
    
    # Load appropriate template based on agent_data.template_id
    var template_path = _get_template_path_for_agent(agent_data)
    var npc_body = spawn_npc_from_template(template_path, position, {
        "agent_type": "npc",
        "template_id": agent_data.get("template_id", "npc_default"),
        "character_uid": agent_data.get("character_uid", -1),
        "hostile": agent_data.get("is_hostile", false)
    })
    
    if is_instance_valid(npc_body):
        npc_body.persistent_uid = agent_uid
        npc_body.load_from_persistent_state(agent_data)
    
    return npc_body


func spawn_all_world_agents() -> void:
    """Spawn all persistent NPCs in GameState.world_agents.
    
    Called on zone load after new game or load game.
    """
    for agent_uid in GameState.world_agents.keys():
        var data = GameState.world_agents[agent_uid]
        if data.get("current_state") != "disabled":
            spawn_persistent_npc(agent_uid)
```

```gdscript
# File: /scenes/game_world/world_manager/world_generator.gd
# MODIFY generate_new_world():

func generate_new_world() -> void:
    # ... existing character/ship/inventory creation ...
    
    # Initialize world NPC population
    if is_instance_valid(GlobalRefs.world_population_system):
        GlobalRefs.world_population_system.initialize_world_population(GameState.world_seed)
```

**SUCCESS CRITERIA:**
- New Game creates ~100 NPCs in GameState.world_agents
- Zone load spawns all persistent NPCs
- NPCs spawn at their saved positions
- NPCs resume patrol at their anchors

---

### TASK 12.5: Create Agent Marker HUD Overlay

**TARGET FILES:**
- `/src/core/ui/main_hud/agent_marker_overlay.gd`
- `/src/core/ui/main_hud/main_hud.tscn`
- `/src/core/ui/main_hud/main_hud.gd`

**DEPENDENCIES:**
- TASK 12.2 (WorldPopulationSystem for agent positions)

**PSEUDO-CODE SIGNATURES:**

```gdscript
# File: /src/core/ui/main_hud/agent_marker_overlay.gd
extends Control

const MARKER_SIZE: float = 8.0
const MARKER_COLOR_NEUTRAL: Color = Color(0.5, 0.5, 0.5, 0.3)  # Faint gray
const MARKER_COLOR_HOSTILE: Color = Color(1.0, 0.3, 0.3, 0.5)   # Red
const MARKER_COLOR_DISABLED: Color = Color(0.3, 0.3, 0.3, 0.2)  # Dim

var _camera: Camera = null
var _marker_data: Array = []  # [{uid, screen_pos, color, visible}]


func _ready() -> void:
    set_process(true)


func _process(_delta: float) -> void:
    _update_marker_positions()
    update()  # Trigger _draw()


func _update_marker_positions() -> void:
    """Project all world agent positions to screen space."""
    _marker_data.clear()
    _camera = get_viewport().get_camera()
    if not is_instance_valid(_camera):
        return
    
    for agent_uid in GameState.world_agents.keys():
        var data = GameState.world_agents[agent_uid]
        var world_pos = data.get("position", Vector3.ZERO)
        
        # Check if in front of camera
        var cam_transform = _camera.global_transform
        var to_agent = world_pos - cam_transform.origin
        if to_agent.dot(-cam_transform.basis.z) < 0:
            continue  # Behind camera
        
        var screen_pos = _camera.unproject_position(world_pos)
        var color = _get_marker_color(data)
        
        _marker_data.append({
            "uid": agent_uid,
            "screen_pos": screen_pos,
            "color": color
        })


func _get_marker_color(agent_data: Dictionary) -> Color:
    """Determine marker color based on agent state."""
    if agent_data.get("current_state") == "disabled":
        return MARKER_COLOR_DISABLED
    if agent_data.get("is_hostile", false):
        return MARKER_COLOR_HOSTILE
    return MARKER_COLOR_NEUTRAL


func _draw() -> void:
    """Render bracket markers for all visible agents."""
    for marker in _marker_data:
        _draw_bracket_marker(marker.screen_pos, marker.color)


func _draw_bracket_marker(pos: Vector2, color: Color) -> void:
    """Draw a small X bracket at screen position."""
    var s = MARKER_SIZE
    # Draw X shape
    draw_line(pos + Vector2(-s, -s), pos + Vector2(s, s), color, 1.0)
    draw_line(pos + Vector2(s, -s), pos + Vector2(-s, s), color, 1.0)
```

**TSCN CHANGES:**
Add `AgentMarkerOverlay` (Control node) to main_hud.tscn, set to fill screen.

**SUCCESS CRITERIA:**
- Faint X markers visible for all NPCs
- Markers follow NPC world positions
- Hostile NPCs show red markers
- Disabled NPCs show dim markers
- No performance issues with 100 markers

---

### TASK 12.6: Implement Full Agent Serialization

**TARGET FILE:** `/src/autoload/GameStateManager.gd`

**DEPENDENCIES:**
- TASK 12.1 (GameState.world_agents structure)

**PSEUDO-CODE SIGNATURES:**

```gdscript
# File: /src/autoload/GameStateManager.gd

# ADD to _serialize_game_state():
state_dict["world_agents"] = _serialize_world_agents()

func _serialize_world_agents() -> Dictionary:
    """Serialize all persistent NPC data."""
    var serialized = {}
    for agent_uid in GameState.world_agents.keys():
        var data = GameState.world_agents[agent_uid].duplicate(true)
        # Convert Vector3 to serializable format
        data["position"] = _serialize_vector3(data.get("position", Vector3.ZERO))
        data["rotation"] = _serialize_vector3(data.get("rotation", Vector3.ZERO))
        data["anchor_point"] = _serialize_vector3(data.get("anchor_point", Vector3.ZERO))
        serialized[agent_uid] = data
    return serialized


# ADD to _deserialize_and_apply_game_state():
GameState.world_agents = _deserialize_world_agents(save_data.get("world_agents", {}))

func _deserialize_world_agents(serialized: Dictionary) -> Dictionary:
    """Deserialize NPC data back to world_agents format."""
    var world_agents = {}
    for agent_uid_str in serialized.keys():
        var agent_uid = int(agent_uid_str)
        var data = serialized[agent_uid_str].duplicate(true)
        # Convert serialized vectors back to Vector3
        data["position"] = _deserialize_vector3(data.get("position", {}))
        data["rotation"] = _deserialize_vector3(data.get("rotation", {}))
        data["anchor_point"] = _deserialize_vector3(data.get("anchor_point", {}))
        world_agents[agent_uid] = data
    return world_agents


# ADD to reset_to_defaults():
GameState.world_agents.clear()
```

**SUCCESS CRITERIA:**
- All 100 NPCs save correctly
- Positions and rotations serialize as Vector3
- Load restores exact NPC states
- Disabled NPCs remain disabled after load
- No data loss on save/load cycle

---

### TASK 12.7: Write GUT Unit Tests

**TARGET FILE:** `/src/tests/core/systems/test_world_population_system.gd`

**PSEUDO-CODE TEST STRUCTURE:**

```gdscript
# File: /src/tests/core/systems/test_world_population_system.gd
extends GutTest

func before_each() -> void:
    GameState.world_agents.clear()

func after_each() -> void:
    GameState.world_agents.clear()


func test_initialize_creates_population() -> void:
    """initialize_world_population creates ~100 agents."""
    GlobalRefs.world_population_system.initialize_world_population("test_seed")
    var count = GameState.world_agents.size()
    assert_gte(count, 80, "Should have at least 80 agents")
    assert_lte(count, 120, "Should have at most 120 agents")


func test_agents_have_valid_positions() -> void:
    """All agents have positions within zone bounds."""
    GlobalRefs.world_population_system.initialize_world_population("test_seed")
    for uid in GameState.world_agents.keys():
        var pos = GameState.world_agents[uid].get("position")
        assert_true(pos is Vector3, "Position should be Vector3")
        assert_lte(pos.length(), 300000, "Position within zone bounds")


func test_agents_have_anchor_points() -> void:
    """All agents have valid anchor points."""
    GlobalRefs.world_population_system.initialize_world_population("test_seed")
    for uid in GameState.world_agents.keys():
        var anchor = GameState.world_agents[uid].get("anchor_point")
        assert_true(anchor is Vector3, "Anchor should be Vector3")


func test_update_agent_state() -> void:
    """update_agent_state modifies agent data."""
    GlobalRefs.world_population_system.initialize_world_population("test_seed")
    var first_uid = GameState.world_agents.keys()[0]
    var new_pos = Vector3(100, 0, 100)
    
    GlobalRefs.world_population_system.update_agent_state(first_uid, {
        "position": new_pos,
        "is_hostile": true
    })
    
    var updated = GameState.world_agents[first_uid]
    assert_eq(updated.position, new_pos)
    assert_true(updated.is_hostile)


func test_mark_agent_disabled() -> void:
    """mark_agent_disabled sets agent state."""
    GlobalRefs.world_population_system.initialize_world_population("test_seed")
    var first_uid = GameState.world_agents.keys()[0]
    
    GlobalRefs.world_population_system.mark_agent_disabled(first_uid)
    
    var data = GameState.world_agents[first_uid]
    assert_eq(data.get("current_state"), "disabled")


func test_serialization_roundtrip() -> void:
    """Save/load preserves all agent data."""
    GlobalRefs.world_population_system.initialize_world_population("test_seed")
    var original_count = GameState.world_agents.size()
    var first_uid = GameState.world_agents.keys()[0]
    var original_pos = GameState.world_agents[first_uid].get("position")
    
    GameStateManager.save_game(99)  # Test slot
    GameState.world_agents.clear()
    GameStateManager.load_game(99)
    
    assert_eq(GameState.world_agents.size(), original_count)
    assert_eq(GameState.world_agents[first_uid].get("position"), original_pos)
```

**SUCCESS CRITERIA:**
- All 6+ tests pass
- Tests verify population count, positions, anchors
- Serialization roundtrip preserves all data
- Tests complete in < 3 seconds

---

### TASK 12.8: Manual Integration Verification

**NO CODE CHANGES** — Manual testing checklist

---

## MANUAL PLAYTEST CHECKLIST (Sprint 12)

### TEST A: New Game Population

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| A.1 | Start New Game | Game loads | |
| A.2 | Check console output | "WorldPopulationSystem: Created X agents" message | |
| A.3 | Look around in space | Faint X markers visible in various directions | |
| A.4 | Count visible markers | Should see markers for ~100 NPCs | |

### TEST B: NPC Patrol Behavior

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| B.1 | Fly toward a distant marker | Marker gets larger/closer | |
| B.2 | Approach until NPC is visible | NPC ship visible, orbiting a point | |
| B.3 | Observe NPC movement | NPC moves in circular pattern around anchor | |
| B.4 | NPC does not attack unprovoked | NPC ignores player unless attacked | |

### TEST C: Combat & Return to Patrol

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| C.1 | Attack a neutral NPC | NPC marker turns red, NPC pursues player | |
| C.2 | Flee far from NPC (~5000+ units) | NPC eventually breaks off pursuit | |
| C.3 | Observe NPC after disengaging | NPC returns toward its anchor point | |
| C.4 | NPC resumes patrol | NPC orbits anchor again | |

### TEST D: Persistence - Save/Load

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| D.1 | Fly to specific NPC, note its position | Record position | |
| D.2 | Attack and damage NPC (don't destroy) | NPC hull reduced | |
| D.3 | Save game | Save completes | |
| D.4 | Destroy the NPC | NPC disabled | |
| D.5 | Load game | Game loads | |
| D.6 | Check NPC at saved position | NPC exists, hull restored to saved value | |

### TEST E: Disabled Agent Persistence

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| E.1 | Disable an NPC (hull to 0) | NPC stops moving, shows as disabled | |
| E.2 | Check HUD marker | Marker becomes dim/gray | |
| E.3 | Save game | Save completes | |
| E.4 | Reload game | Game loads | |
| E.5 | Check disabled NPC | Still disabled at same position | |

---

## 5. CONSTRAINTS (Sprint 12)

1. **Zone Size:** Playable area is 300,000 units. NPCs distributed across this space.

2. **Population Count:** Base ~100 agents, ±20 variance based on seed.

3. **Default Neutral:** All NPCs spawn neutral. Only become hostile when attacked.

4. **Patrol State:** Default AI state is `STATE_PATROL` (orbit anchor).

5. **Full Serialization:** ALL agent properties must serialize:
   - Position, Rotation (Vector3)
   - anchor_point, orbit_radius, orbit_speed
   - hull_current, is_hostile, current_state
   - cargo, equipped_weapons, ship_quirks

6. **HUD Markers:** Faint, non-intrusive. X bracket shape. Color-coded by state.

7. **No Despawning:** Disabled agents remain in world_agents (can be salvaged later).

8. **Sync Frequency:** Agents sync state to GameState.world_agents every 1-2 seconds.

9. **GDScript 3.x Syntax:** NO `@export`, `@onready`, `await`, `super()`.

---

## 6. DEFINITION OF DONE UPDATE (Post-Sprint 12)

After Sprint 12, add to Definition of Done:

- [**PASS**] World contains persistent NPC population (~100 agents)
- [**PASS**] NPCs patrol/orbit anchor points when neutral
- [**PASS**] NPCs become hostile when attacked, return to patrol when disengaged
- [**PASS**] All NPC positions visible on HUD as markers
- [**PASS**] Full agent state serializes in save files
- [**PASS**] Disabled agents persist (not despawned)

---

**END OF IMMEDIATE-TODO.md**
