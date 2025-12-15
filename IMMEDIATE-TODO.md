# IMMEDIATE-TODO.md
**Generated:** December 15, 2025  
**Target Sprint:** Sprint 8 - Combat Module Integration  
**Previous Sprints Status:** Sprints 1-7 COMPLETE (verified in codebase + tests)

---

## 1. CONTEXT

We are implementing **Combat Module Integration** (Sprint 8), which wires the existing CombatSystem into actual gameplay—agents can fire weapons and take damage. CombatSystem already handles damage application, hull tracking, and victory conditions; what's missing is the **WeaponController component** (to fire weapons from agents) and **input/targeting integration** (so the player can actually shoot).

This sprint is a **critical prerequisite** for Sprint 9 (Enemy AI & Encounters), as enemies cannot fight back until weapon firing works.

---

## 2. FILE MANIFEST

### Files to CREATE:
| File | Purpose |
|------|---------|
| `core/agents/components/weapon_controller.gd` | Agent component: handles cooldowns, fires weapons via CombatSystem |
| `tests/core/agents/components/test_weapon_controller.gd` | GUT tests for WeaponController |

### Files to MODIFY:
| File | Change |
|------|--------|
| `core/agents/player_agent.tscn` | Add WeaponController node |
| `core/agents/npc_agent.tscn` | Add WeaponController node |
| `modules/piloting/scripts/player_controller_ship.gd` | Add fire input handling, call WeaponController |
| `project.godot` | Add `fire_weapon` input action |
| `core/ui/main_hud/main_hud.gd` | Display target's hull bar when in combat |

### Files to READ for Context (Dependencies):
| File | Reason |
|------|--------|
| `core/systems/combat_system.gd` | `fire_weapon()`, `register_combatant()`, `is_in_range()` API |
| `core/resource/utility_tool_template.gd` | Weapon data structure (damage, range, cooldown) |
| `core/resource/asset_ship_template.gd` | `equipped_tools` array, `hull_integrity` |
| `core/agents/agent.gd` | Agent structure, `character_uid`, signal patterns |
| `autoload/GlobalRefs.gd` | `combat_system` reference |
| `autoload/EventBus.gd` | `combat_started`, `damage_dealt`, `ship_disabled` signals |

---

## 3. ATOMIC TASKS

### Current Sprint Checklist

- [x] TASK 1: Add Fire Weapon Input Action
- [x] TASK 2: Create WeaponController Component
- [x] TASK 3: Integrate WeaponController into Agent Scenes
- [x] TASK 4: Add Fire Input to Player Controller
- [x] TASK 5: Add Combat HUD Elements (Target Hull Bar)
- [x] TASK 6: Write WeaponController Unit Tests
- [x] TASK 7: Integration Verification

---

### TASK 1: Add Fire Weapon Input Action

**TARGET FILE:** `project.godot`

**DEPENDENCIES:**
- None

**CHANGES:**
Add input action `fire_weapon` mapped to:
- Primary: Left Mouse Button (BUTTON_LEFT)
- Secondary: Space bar (KEY_SPACE)

**PSEUDO-CODE (INI format):**
```ini
[input]
fire_weapon={
"deadzone": 0.5,
"events": [ Object(InputEventMouseButton,"resource_local_to_scene":false,"button_index":1,"pressed":false,"doubleclick":false),
Object(InputEventKey,"resource_local_to_scene":false,"scancode":32,"pressed":false,"echo":false) ]
}
```

**SUCCESS CRITERIA:**
- `Input.is_action_just_pressed("fire_weapon")` returns true on left-click/space

---

### TASK 2: Create WeaponController Component

**TARGET FILE:** `core/agents/components/weapon_controller.gd`

**DEPENDENCIES:**
- Read `core/systems/combat_system.gd` (lines 70-150) for `fire_weapon()` API
- Read `core/resource/utility_tool_template.gd` for weapon data structure
- Read `core/resource/asset_ship_template.gd` for `equipped_tools` array

**PSEUDO-CODE SIGNATURES:**
```gdscript
# File: core/agents/components/weapon_controller.gd
# Purpose: Manages weapon firing and cooldowns for an agent.
# Attaches as child of AgentBody (KinematicBody).
extends Node

signal weapon_fired(weapon_index: int, target_position: Vector3)
signal weapon_cooldown_started(weapon_index: int, duration: float)
signal weapon_ready(weapon_index: int)

# --- References (set in _ready) ---
var _agent_body: KinematicBody = null  # Parent AgentBody
var _ship_template = null               # Linked ShipTemplate (via AssetSystem)
var _weapons: Array = []                # Loaded UtilityToolTemplate instances
var _cooldowns: Dictionary = {}         # weapon_index -> remaining_time

# --- Initialization ---
func _ready() -> void:
    """Get parent AgentBody, load weapons from ship template."""
    _agent_body = get_parent()
    if not _agent_body is KinematicBody:
        printerr("WeaponController: Parent must be KinematicBody")
        return
    _load_weapons_from_ship()

func _load_weapons_from_ship() -> void:
    """Load equipped_tools from the agent's ShipTemplate."""
    # Get character_uid from agent, then ship from AssetSystem
    var char_uid: int = _agent_body.get("character_uid") if _agent_body.get("character_uid") != null else -1
    if char_uid < 0:
        return  # No character linked, no weapons
    
    _ship_template = GlobalRefs.asset_system.get_ship_for_character(char_uid)
    if not _ship_template:
        return
    
    # Load each equipped tool template
    for tool_id in _ship_template.equipped_tools:
        var tool_template = TemplateDatabase.get_template("tools", tool_id)
        if tool_template and tool_template.tool_type == "weapon":
            _weapons.append(tool_template)
            _cooldowns[_weapons.size() - 1] = 0.0

func _physics_process(delta: float) -> void:
    """Update cooldown timers."""
    for idx in _cooldowns.keys():
        if _cooldowns[idx] > 0:
            _cooldowns[idx] -= delta
            if _cooldowns[idx] <= 0:
                _cooldowns[idx] = 0
                emit_signal("weapon_ready", idx)

# --- Public API ---

func get_weapon_count() -> int:
    """Return number of equipped weapons."""
    return _weapons.size()

func get_weapon(index: int) -> Resource:
    """Return weapon template at index, or null."""
    if index >= 0 and index < _weapons.size():
        return _weapons[index]
    return null

func is_weapon_ready(index: int) -> bool:
    """Return true if weapon cooldown is complete."""
    return _cooldowns.get(index, 0.0) <= 0.0

func get_cooldown_remaining(index: int) -> float:
    """Return remaining cooldown time for weapon."""
    return _cooldowns.get(index, 0.0)

func fire_at_target(weapon_index: int, target_uid: int, target_position: Vector3) -> Dictionary:
    """Attempt to fire weapon at target. Returns result dict from CombatSystem.
    
    Args:
        weapon_index: Index into equipped weapons array
        target_uid: Target agent's UID for combat system
        target_position: Target's global position
        
    Returns:
        {success: bool, reason: String, damage: float, hit: bool, ...}
    """
    if weapon_index < 0 or weapon_index >= _weapons.size():
        return {"success": false, "reason": "Invalid weapon index"}
    
    if not is_weapon_ready(weapon_index):
        return {"success": false, "reason": "Weapon on cooldown", "cooldown": _cooldowns[weapon_index]}
    
    var weapon = _weapons[weapon_index]
    var shooter_uid = _agent_body.agent_uid
    var shooter_pos = _agent_body.global_transform.origin
    
    # Ensure both combatants registered
    _ensure_combatant_registered(shooter_uid)
    _ensure_combatant_registered(target_uid)
    
    # Fire via CombatSystem
    var result = GlobalRefs.combat_system.fire_weapon(
        shooter_uid, target_uid, weapon, shooter_pos, target_position
    )
    
    if result.success:
        # Start cooldown
        _cooldowns[weapon_index] = weapon.cooldown_seconds
        emit_signal("weapon_cooldown_started", weapon_index, weapon.cooldown_seconds)
        emit_signal("weapon_fired", weapon_index, target_position)
    
    return result

func _ensure_combatant_registered(uid: int) -> void:
    """Register combatant if not already in CombatSystem."""
    if GlobalRefs.combat_system.is_in_combat(uid):
        return
    # Need ship template for registration
    var ship = GlobalRefs.asset_system.get_ship_by_uid(uid)  # or by character
    if ship:
        GlobalRefs.combat_system.register_combatant(uid, ship)
```

**SUCCESS CRITERIA:**
- WeaponController loads weapons from ShipTemplate
- `fire_at_target()` calls CombatSystem and manages cooldowns
- Cooldowns decrement each frame and emit `weapon_ready` when done

---

### TASK 3: Integrate WeaponController into Agent Scenes

**TARGET FILES:**
- `core/agents/player_agent.tscn`
- `core/agents/npc_agent.tscn`

**DEPENDENCIES:**
- Task 2 complete

**CHANGES:**
Add `WeaponController` node as child of root `AgentBody`:
```
AgentBody (KinematicBody)
├── NavigationSystem
├── MovementSystem
├── WeaponController  <-- NEW
└── ...
```

**SCENE EDIT (for both scenes):**
```
[node name="WeaponController" type="Node" parent="."]
script = ExtResource( "res://core/agents/components/weapon_controller.gd" )
```

**SUCCESS CRITERIA:**
- Both agent scenes load without error
- WeaponController `_ready()` finds parent AgentBody

---

### TASK 4: Add Fire Input to Player Controller

**TARGET FILE:** `modules/piloting/scripts/player_controller_ship.gd`

**DEPENDENCIES:**
- Read current file structure (input handling pattern)
- Task 1 (input action exists)
- Task 3 (WeaponController exists on agent)

**CHANGES:**
Add in `_physics_process()` or `_unhandled_input()`:
```gdscript
# --- Combat Input ---
var _weapon_controller: Node = null  # Cached reference

func _ready():
    # ... existing code ...
    _weapon_controller = get_node_or_null("WeaponController")

func _physics_process(delta):
    # ... existing movement code ...
    _handle_combat_input()

func _handle_combat_input() -> void:
    """Handle weapon firing input."""
    if not _weapon_controller:
        return
    if not Input.is_action_just_pressed("fire_weapon"):
        return
    
    # Get current target from targeting system
    var target_body = _get_current_target()
    if not target_body:
        return  # No target selected
    
    # Fire primary weapon (index 0)
    var target_uid = target_body.agent_uid if target_body.has("agent_uid") else -1
    var target_pos = target_body.global_transform.origin
    
    var result = _weapon_controller.fire_at_target(0, target_uid, target_pos)
    if not result.success:
        print("Fire failed: ", result.reason)
    else:
        print("Hit! Damage: ", result.get("damage", 0))

func _get_current_target() -> KinematicBody:
    """Return currently targeted agent body, or null."""
    # Check if there's a targeting system or use GlobalRefs
    if GlobalRefs.player and GlobalRefs.player.has_method("get_target"):
        return GlobalRefs.player.get_target()
    return null
```

**SUCCESS CRITERIA:**
- Press fire key with target selected → weapon fires
- Press fire key without target → nothing happens
- Press fire during cooldown → "Weapon on cooldown" feedback

---

### TASK 5: Add Combat HUD Elements (Target Hull Bar)

**TARGET FILE:** `core/ui/main_hud/main_hud.gd` (and `.tscn`)

**DEPENDENCIES:**
- Read current HUD structure
- CombatSystem `get_hull_percent()` API

**CHANGES:**
1. Add UI elements (scene):
```
TargetInfoPanel (PanelContainer) - positioned top-center or near target indicator
├── VBoxContainer
│   ├── LabelTargetName (Label)
│   └── TargetHullBar (ProgressBar)
```

2. Add script logic:
```gdscript
onready var target_info_panel = $TargetInfoPanel
onready var label_target_name = $TargetInfoPanel/VBoxContainer/LabelTargetName
onready var target_hull_bar = $TargetInfoPanel/VBoxContainer/TargetHullBar

var _current_target_uid: int = -1

func _ready():
    # ... existing code ...
    target_info_panel.visible = false
    EventBus.connect("target_changed", self, "_on_target_changed")
    EventBus.connect("damage_dealt", self, "_on_damage_dealt")

func _on_target_changed(new_target):
    if new_target and new_target.has("agent_uid"):
        _current_target_uid = new_target.agent_uid
        _update_target_display(new_target)
        target_info_panel.visible = true
    else:
        _current_target_uid = -1
        target_info_panel.visible = false

func _update_target_display(target):
    label_target_name.text = target.agent_name if target.has("agent_name") else "Unknown"
    var hull_pct = GlobalRefs.combat_system.get_hull_percent(_current_target_uid)
    target_hull_bar.value = hull_pct * 100

func _on_damage_dealt(target_uid, amount, source_uid):
    if target_uid == _current_target_uid:
        var hull_pct = GlobalRefs.combat_system.get_hull_percent(target_uid)
        target_hull_bar.value = hull_pct * 100
```

**SUCCESS CRITERIA:**
- Target hull bar shows when target selected
- Hull bar updates when damage dealt
- Hull bar hides when no target

---

### TASK 6: Write WeaponController Unit Tests

**TARGET FILE:** `tests/core/agents/components/test_weapon_controller.gd`

**DEPENDENCIES:**
- Task 2 complete
- Reference existing tests: `tests/core/agents/components/test_movement_system.gd`

**PSEUDO-CODE TEST CASES:**
```gdscript
extends GutTest

const WeaponController = preload("res://core/agents/components/weapon_controller.gd")

var weapon_controller = null
var mock_agent_body = null
var mock_ship = null

func before_each():
    # Setup mock agent body with agent_uid and character_uid
    # Setup mock ship with equipped_tools
    # Instance WeaponController as child of mock agent
    pass

func after_each():
    # Cleanup
    pass

# --- Test Cases ---

func test_loads_weapons_from_ship_template():
    """WeaponController should load equipped weapons from ship."""
    assert_eq(weapon_controller.get_weapon_count(), 1, "Should have 1 weapon")
    assert_not_null(weapon_controller.get_weapon(0), "Weapon 0 should exist")

func test_fire_weapon_success():
    """Fire weapon at valid target should succeed."""
    var result = weapon_controller.fire_at_target(0, TARGET_UID, Vector3.ZERO)
    assert_true(result.success, "Fire should succeed")
    assert_signal_emitted(weapon_controller, "weapon_fired")

func test_fire_weapon_starts_cooldown():
    """Firing weapon should start cooldown."""
    weapon_controller.fire_at_target(0, TARGET_UID, Vector3.ZERO)
    assert_false(weapon_controller.is_weapon_ready(0), "Weapon should be on cooldown")

func test_fire_weapon_during_cooldown_fails():
    """Firing during cooldown should fail."""
    weapon_controller.fire_at_target(0, TARGET_UID, Vector3.ZERO)
    var result = weapon_controller.fire_at_target(0, TARGET_UID, Vector3.ZERO)
    assert_false(result.success, "Second fire should fail")
    assert_eq(result.reason, "Weapon on cooldown")

func test_cooldown_decrements_over_time():
    """Cooldown should decrement each physics frame."""
    weapon_controller.fire_at_target(0, TARGET_UID, Vector3.ZERO)
    var initial_cd = weapon_controller.get_cooldown_remaining(0)
    weapon_controller._physics_process(0.5)
    var new_cd = weapon_controller.get_cooldown_remaining(0)
    assert_lt(new_cd, initial_cd, "Cooldown should decrease")

func test_weapon_ready_signal_emitted():
    """weapon_ready signal should emit when cooldown ends."""
    weapon_controller.fire_at_target(0, TARGET_UID, Vector3.ZERO)
    # Simulate time passing equal to cooldown
    weapon_controller._physics_process(5.0)  # Assume 1s cooldown
    assert_signal_emitted(weapon_controller, "weapon_ready")

func test_invalid_weapon_index_returns_error():
    """Invalid weapon index should return error dict."""
    var result = weapon_controller.fire_at_target(99, TARGET_UID, Vector3.ZERO)
    assert_false(result.success)
    assert_eq(result.reason, "Invalid weapon index")
```

**SUCCESS CRITERIA:**
- All 7 tests pass
- Uses `autofree()` for cleanup
- Properly mocks agent body and ship template

---

### TASK 7: Integration Verification

**TARGET:** Manual testing checklist

**DEPENDENCIES:**
- Tasks 1-6 complete

**TEST CHECKLIST:**
- [ ] Spawn player with `ship_default.tres` (has `ablative_laser` equipped)
- [ ] Spawn NPC target agent
- [ ] Select NPC as target
- [ ] Press fire key → damage appears in console, NPC hull decreases
- [ ] Press fire again immediately → "Weapon on cooldown" message
- [ ] Wait for cooldown → fire again successfully
- [ ] Reduce NPC hull to 0 → `ship_disabled` signal emitted
- [ ] Target hull bar updates in real-time
- [ ] No target selected → fire does nothing

---

## 4. CONSTRAINTS

### Architectural Rules:
1. **WeaponController is a Node COMPONENT** — Attaches to AgentBody, not a singleton/system
2. **CombatSystem remains stateless logic** — WeaponController handles per-agent state (cooldowns)
3. **Use GlobalRefs for system access** — `GlobalRefs.combat_system`, `GlobalRefs.asset_system`
4. **EventBus for cross-system signals** — `damage_dealt`, `ship_disabled` already exist
5. **TemplateDatabase for resource loading** — `TemplateDatabase.get_template("tools", id)`

### Signal Flow:
```
Player presses fire_weapon
    → PlayerControllerShip._handle_combat_input()
        → WeaponController.fire_at_target(0, target_uid, target_pos)
            → CombatSystem.fire_weapon(...)
                → CombatSystem.apply_damage(...)
                    → EventBus.emit("damage_dealt", ...)
                        → MainHUD._on_damage_dealt() updates hull bar
            → WeaponController emits "weapon_fired"
            → WeaponController starts cooldown timer
```

### DO NOT:
- Add weapon cooldown tracking to CombatSystem (it's per-agent, belongs in WeaponController)
- Create a new autoload for weapons
- Modify `combat_system.gd` public API (it's already complete)
- Add visual effects yet (defer to Sprint 11 polish)

### Phase 1 Simplifications:
- **Hitscan only** — No projectiles, instant hit if in range
- **Primary weapon only** — Fire index 0, no weapon switching UI
- **No accuracy roll** — 100% hit rate within range (accuracy added in Phase 2)

---

## 5. VERIFICATION CHECKLIST

After implementation, verify:

- [ ] `Input.is_action_just_pressed("fire_weapon")` works in-game
- [ ] WeaponController loads 1 weapon from `ship_default.tres`
- [ ] `fire_at_target()` returns `{success: true}` with valid target
- [ ] Cooldown prevents immediate re-fire
- [ ] Cooldown timer decrements correctly
- [ ] `weapon_ready` signal emits after cooldown ends
- [ ] Target hull bar appears when target selected
- [ ] Target hull bar updates on `damage_dealt` signal
- [ ] Target hull bar hides when target deselected
- [ ] NPC hull reaches 0 → `ship_disabled` signal fires
- [ ] All GUT tests pass (existing + new)

---

## 6. ESTIMATED COMPLEXITY

| Task | Difficulty | Lines of Code | Dependencies |
|------|------------|---------------|--------------|
| Task 1 | Low | ~5 (config) | None |
| Task 2 | Medium | ~120 | CombatSystem, AssetSystem |
| Task 3 | Low | Scene edit | Task 2 |
| Task 4 | Medium | ~50 | Task 1, Task 3 |
| Task 5 | Medium | ~60 | CombatSystem |
| Task 6 | Medium | ~100 | Task 2 |
| Task 7 | N/A | Manual test | All |

**Total estimated new code:** ~330 lines  
**Recommended order:** 1 → 2 → 6 → 3 → 4 → 5 → 7
