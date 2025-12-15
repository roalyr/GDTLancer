# IMMEDIATE-TODO.md
**Generated:** December 15, 2025  
**Target Sprint:** Sprint 9 - Enemy AI & Combat Encounters  
**Previous Sprint Status:** Sprint 8 (Combat Module Integration) COMPLETE — 173 tests passing

---

## 1. CONTEXT

We are implementing **Sprint 9: Enemy AI & Combat Encounters**, which makes NPCs fight back and triggers combat encounters dynamically. The WeaponController component and CombatSystem are operational for the player; this sprint adds **AI combat states** to `ship_controller_ai.gd` and **encounter generation** to `event_system.gd`, completing the "combat loop" where enemies can spawn, attack, and be defeated.

This sprint is a **critical prerequisite** for Sprint 10 (Full Game Loop Integration), as the complete contract delivery → potential combat → arrival flow cannot be tested until NPCs can initiate combat.

---

## 2. FILE MANIFEST

### Files to CREATE:
| File | Purpose |
|------|---------|
| `tests/modules/piloting/test_ship_controller_ai.gd` | GUT tests for AI combat behavior |
| `tests/core/systems/test_event_system.gd` | GUT tests for encounter triggering |
| `assets/data/agents/npc_hostile_default.tres` | Hostile NPC agent template |

### Files to MODIFY:
| File | Change |
|------|--------|
| `modules/piloting/scripts/ship_controller_ai.gd` | Add state machine: IDLE, PATROL, COMBAT, FLEE; weapon firing logic |
| `core/systems/event_system.gd` | Implement encounter triggering on `world_event_tick_triggered` |
| `core/systems/combat_system.gd` | Add `end_combat()` cleanup + victory/defeat detection |
| `core/ui/main_hud/main_hud.gd` | Connect to combat signals for UI feedback |

### Files to READ for Context (Dependencies):
| File | Reason |
|------|--------|
| `core/agents/components/weapon_controller.gd` | `fire_at_target()` API for AI to use |
| `core/systems/combat_system.gd` | `register_combatant()`, `fire_weapon()`, `apply_damage()` |
| `core/systems/agent_system.gd` | `spawn_npc()` API for encounter spawning |
| `core/agents/agent.gd` | Agent state commands: `command_move_to()`, state machine |
| `autoload/EventBus.gd` | `combat_initiated`, `combat_ended`, `agent_disabled` signals |
| `autoload/GameState.gd` | `current_tu`, player reference |
| `core/systems/time_system.gd` | `world_event_tick_triggered` signal pattern |

---

## 3. ATOMIC TASKS

### Sprint 9 Checklist

- [x] **TASK 1:** Extend AI Controller with Combat State Machine
- [x] **TASK 2:** Implement AI Weapon Firing
- [x] **TASK 3:** Implement Event System Encounter Triggering
- [x] **TASK 4:** Add Combat End Detection to CombatSystem
- [x] **TASK 5:** Wire Combat Flow Signals to HUD
- [x] **TASK 6:** Create Hostile NPC Template
- [x] **TASK 7:** Write AI Combat Unit Tests
- [x] **TASK 8:** Write Event System Unit Tests
- [ ] **TASK 9:** Integration Verification

---

### TASK 1: Extend AI Controller with Combat State Machine

**TARGET FILE:** `modules/piloting/scripts/ship_controller_ai.gd`

**DEPENDENCIES:**
- Read `core/agents/agent.gd` (lines 1-150) — Agent command interface
- Read `core/systems/combat_system.gd` (lines 50-80) — `is_in_combat()`, `get_hull_percent()`
- Read `autoload/EventBus.gd` — `combat_initiated`, `agent_damaged`

**CHANGES:**
Replace the current passive "command once at init" controller with a state-driven AI:

**PSEUDO-CODE SIGNATURES:**
```gdscript
# File: modules/piloting/scripts/ship_controller_ai.gd
extends Node

enum AIState { IDLE, PATROL, COMBAT, FLEE, DISABLED }

# --- Configuration ---
export var aggro_range: float = 800.0          # Distance to detect player
export var weapon_range: float = 500.0         # Optimal firing distance
export var flee_hull_threshold: float = 0.2    # Flee when hull < 20%
export var patrol_radius: float = 200.0        # Random patrol area
export var is_hostile: bool = false            # Determines if NPC attacks player

# --- State ---
var _current_state: int = AIState.IDLE
var _target_agent: KinematicBody = null
var _home_position: Vector3 = Vector3.ZERO
var _weapon_controller: Node = null

# --- Initialization ---
func _ready() -> void:
    """Cache references, connect signals, set initial state."""
    # Get parent AgentBody, find WeaponController sibling
    # Connect to EventBus.agent_disabled for self-disable handling

func initialize(config: Dictionary) -> void:
    """Called by WorldManager. config may contain 'hostile': bool, 'patrol_center': Vector3."""
    # Store home_position from config.get("patrol_center", global_transform.origin)
    # Set is_hostile from config.get("hostile", false)
    # If hostile: immediately set state to PATROL to start scanning

# --- State Machine ---
func _physics_process(delta: float) -> void:
    """Run state logic each frame."""
    match _current_state:
        AIState.IDLE:
            _process_idle(delta)
        AIState.PATROL:
            _process_patrol(delta)
        AIState.COMBAT:
            _process_combat(delta)
        AIState.FLEE:
            _process_flee(delta)
        AIState.DISABLED:
            pass  # No processing

func _change_state(new_state: int) -> void:
    """Transition to new state, handle entry actions."""
    # On enter COMBAT: call agent_script.command_approach(_target_agent) if method exists
    # On enter FLEE: call agent_script.command_flee(_target_agent) if method exists
    # On enter DISABLED: stop all movement

# --- State Processors ---
func _process_idle(delta: float) -> void:
    """Check for targets within aggro_range, transition to COMBAT or PATROL."""
    # Find player via GlobalRefs.world_manager.player_agent
    # If player within aggro_range and self is hostile → _change_state(COMBAT)

func _process_patrol(delta: float) -> void:
    """Move randomly near home_position, scan for targets."""
    # If no current destination, pick random point near _home_position
    # Continue scanning for player

func _process_combat(delta: float) -> void:
    """Approach target, fire weapons when in range, flee if hull critical."""
    # 1. Check if target still valid + in range
    # 2. Check own hull: if < flee_hull_threshold → _change_state(FLEE)
    # 3. If distance > weapon_range: continue approach
    # 4. If in range: attempt to fire (see TASK 2)

func _process_flee(delta: float) -> void:
    """Move away from threat, despawn when safe."""
    # If distance to target > aggro_range * 2: despawn self via agent_script.despawn()
    # Keep fleeing otherwise

func _scan_for_target() -> KinematicBody:
    """Find valid target (player) within aggro range."""
    # Return player agent if hostile and within range, else null
```

**SUCCESS CRITERIA:**
- AI transitions from IDLE → COMBAT when player enters aggro_range
- AI transitions COMBAT → FLEE when hull < 20%
- AI approaches player during COMBAT state
- State changes emit no errors in console
- Non-hostile NPCs remain IDLE

---

### TASK 2: Implement AI Weapon Firing

**TARGET FILE:** `modules/piloting/scripts/ship_controller_ai.gd`

**DEPENDENCIES:**
- Read `core/agents/components/weapon_controller.gd` (lines 80-157) — `fire_at_target()` API
- Read `core/systems/combat_system.gd` (lines 82-130) — `fire_weapon()` return dict

**CHANGES:**
Add weapon firing logic within `_process_combat()`:

**PSEUDO-CODE SIGNATURES:**
```gdscript
# --- Weapon Firing (inside ship_controller_ai.gd) ---

var _fire_timer: float = 0.0
const AI_FIRE_INTERVAL: float = 1.5  # Seconds between fire attempts

func _try_fire_weapon() -> void:
    """Attempt to fire primary weapon at current target."""
    if not is_instance_valid(_weapon_controller):
        return
    if not is_instance_valid(_target_agent):
        return
    
    # Get target position
    var target_pos: Vector3 = _target_agent.global_transform.origin
    var target_uid: int = _target_agent.agent_uid if _target_agent.get("agent_uid") else -1
    
    # Fire weapon index 0 (primary)
    var result: Dictionary = _weapon_controller.fire_at_target(0, target_uid, target_pos)
    
    # React to result
    if result.get("success", false):
        _fire_timer = AI_FIRE_INTERVAL
    elif result.get("reason") == "Weapon on cooldown":
        _fire_timer = result.get("cooldown", 0.5)

func _is_in_weapon_range() -> bool:
    """Check if target is within weapon's effective range."""
    if not is_instance_valid(_target_agent) or not is_instance_valid(agent_script):
        return false
    var distance = agent_script.global_transform.origin.distance_to(
        _target_agent.global_transform.origin
    )
    return distance <= weapon_range

# Called in _process_combat:
func _process_combat(delta: float) -> void:
    # ... state checks ...
    _fire_timer = max(0.0, _fire_timer - delta)
    if _fire_timer <= 0 and _is_in_weapon_range():
        _try_fire_weapon()
    # ... hull checks ...
```

**SUCCESS CRITERIA:**
- AI fires at player when within weapon_range
- Player takes damage when AI hits (verify via `agent_damaged` signal)
- AI respects weapon cooldown (does not spam fire)
- AI respects its own fire interval timer

---

### TASK 3: Implement Event System Encounter Triggering

**TARGET FILE:** `core/systems/event_system.gd`

**DEPENDENCIES:**
- Read `core/systems/agent_system.gd` — `spawn_npc()` API
- Read `autoload/EventBus.gd` (line 52) — `world_event_tick_triggered` signal
- Read `autoload/GameState.gd` — Zone/location info, player state

**CHANGES:**
Implement encounter logic triggered by time passage:

**PSEUDO-CODE SIGNATURES:**
```gdscript
# File: core/systems/event_system.gd
extends Node

# --- Configuration ---
const ENCOUNTER_COOLDOWN_TU: int = 5           # Minimum TU between encounters
const BASE_ENCOUNTER_CHANCE: float = 0.3       # 30% base chance per tick
const SPAWN_DISTANCE_MIN: float = 600.0        # Min spawn distance from player
const SPAWN_DISTANCE_MAX: float = 1000.0       # Max spawn distance from player

# --- State ---
var _encounter_cooldown: int = 0
var _active_hostiles: Array = []

func _ready() -> void:
    GlobalRefs.set_event_system(self)
    EventBus.connect("world_event_tick_triggered", self, "_on_world_event_tick")
    EventBus.connect("agent_disabled", self, "_on_agent_disabled")
    EventBus.connect("agent_despawning", self, "_on_agent_despawning")
    print("EventSystem Ready.")

# --- Event Handlers ---
func _on_world_event_tick(tu_amount: int) -> void:
    """Called each world tick. Check for random encounter."""
    _encounter_cooldown = max(0, _encounter_cooldown - tu_amount)
    if _encounter_cooldown <= 0 and _active_hostiles.empty():
        _maybe_trigger_encounter()

func _on_agent_disabled(agent_body) -> void:
    """Remove from active hostiles when disabled."""
    _active_hostiles.erase(agent_body)
    _check_combat_end()

func _on_agent_despawning(agent_body) -> void:
    """Remove from active hostiles when despawning."""
    _active_hostiles.erase(agent_body)
    _check_combat_end()

# --- Encounter Logic ---
func _maybe_trigger_encounter() -> void:
    """Roll for encounter, spawn hostile if triggered."""
    var danger_level: float = _get_current_danger_level()
    var chance: float = BASE_ENCOUNTER_CHANCE * danger_level
    
    if randf() > chance:
        _encounter_cooldown = ENCOUNTER_COOLDOWN_TU
        return  # No encounter this tick
    
    _spawn_hostile_encounter()
    _encounter_cooldown = ENCOUNTER_COOLDOWN_TU * 2  # Longer cooldown after spawn

func _spawn_hostile_encounter() -> void:
    """Spawn 1-2 hostile NPCs near player."""
    var player = null
    if GlobalRefs.world_manager and GlobalRefs.world_manager.get("player_agent"):
        player = GlobalRefs.world_manager.player_agent
    if not is_instance_valid(player):
        return
    
    var player_pos: Vector3 = player.global_transform.origin
    var spawn_count: int = 1 + (randi() % 2)  # 1 or 2 enemies
    
    for i in range(spawn_count):
        var spawn_pos: Vector3 = _calculate_spawn_position(player_pos)
        var overrides: Dictionary = {
            "hostile": true,
            "patrol_center": spawn_pos,
            "initial_target": player_pos
        }
        
        # Spawn hostile NPC using agent_system
        var npc = null
        if GlobalRefs.agent_system and GlobalRefs.agent_system.has_method("spawn_npc"):
            npc = GlobalRefs.agent_system.spawn_npc(
                "npc_hostile_default",  # Template ID from assets/data/agents/
                spawn_pos,
                overrides
            )
        
        if is_instance_valid(npc):
            _active_hostiles.append(npc)
    
    # Emit combat initiated signal
    if not _active_hostiles.empty():
        EventBus.emit_signal("combat_initiated", player, _active_hostiles.duplicate())

func _calculate_spawn_position(player_pos: Vector3) -> Vector3:
    """Calculate random position at distance from player."""
    var angle: float = randf() * TAU  # Random angle in radians
    var distance: float = rand_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
    var offset: Vector3 = Vector3(cos(angle), 0, sin(angle)) * distance
    return player_pos + offset

func _get_current_danger_level() -> float:
    """Return danger multiplier for current zone. Phase 1: hardcoded."""
    # TODO: Read from LocationTemplate or zone metadata
    return 1.0

func _check_combat_end() -> void:
    """Check if all hostiles defeated, emit combat_ended."""
    if _active_hostiles.empty():
        EventBus.emit_signal("combat_ended", {"outcome": "victory", "hostiles_defeated": true})

# --- Public API ---
func get_active_hostiles() -> Array:
    """Return array of currently active hostile agents."""
    return _active_hostiles.duplicate()

func force_encounter() -> void:
    """Debug/testing: Force spawn encounter immediately."""
    _spawn_hostile_encounter()

func clear_hostiles() -> void:
    """Debug/testing: Clear hostile tracking."""
    _active_hostiles.clear()
```

**SUCCESS CRITERIA:**
- `world_event_tick_triggered` signal triggers encounter check
- Encounter spawns 1-2 hostile NPCs at correct distance from player
- `combat_initiated` signal emitted with correct parameters
- Encounter cooldown prevents immediate re-spawn
- Hostiles tracked in `_active_hostiles` array

---

### TASK 4: Add Combat End Detection to CombatSystem

**TARGET FILE:** `core/systems/combat_system.gd`

**DEPENDENCIES:**
- Read current `combat_system.gd` (lines 130-end) — Understand current damage flow
- Read `autoload/EventBus.gd` — `combat_ended`, `agent_disabled` signals

**CHANGES:**
Add proper combat lifecycle management:

**PSEUDO-CODE SIGNATURES:**
```gdscript
# Add to combat_system.gd

# --- Combat Lifecycle ---
func start_combat(attacker_uid: int, defender_uid: int) -> void:
    """Mark combat as active between two parties."""
    _combat_active = true
    emit_signal("combat_started", attacker_uid, defender_uid)

func end_combat(result: String) -> void:
    """Clean up combat state. result: 'victory', 'defeat', 'flee'"""
    _combat_active = false
    
    # Clear disabled combatants from tracking
    var to_remove: Array = []
    for uid in _active_combatants.keys():
        if _active_combatants[uid].get("is_disabled", false):
            to_remove.append(uid)
    for uid in to_remove:
        _active_combatants.erase(uid)
    
    emit_signal("combat_ended", {"outcome": result})

func is_combat_active() -> bool:
    """Return whether combat is currently ongoing."""
    return _combat_active

# --- Modify apply_damage to emit agent_disabled on EventBus ---
# In apply_damage(), after setting is_disabled = true, add:
#     EventBus.emit_signal("agent_disabled", _get_agent_body(target_uid))

func _get_agent_body(agent_uid: int):
    """Helper to find agent body by UID from WorldManager."""
    if GlobalRefs.world_manager and GlobalRefs.world_manager.has_method("get_agent_by_uid"):
        return GlobalRefs.world_manager.get_agent_by_uid(agent_uid)
    return null
```

**SUCCESS CRITERIA:**
- `agent_disabled` signal emitted on EventBus when hull reaches 0
- `end_combat()` cleans up `_active_combatants`
- `is_combat_active()` correctly reflects state

---

### TASK 5: Wire Combat Flow Signals to HUD

**TARGET FILE:** `core/ui/main_hud/main_hud.gd`

**DEPENDENCIES:**
- Read `autoload/EventBus.gd` — All combat-related signals
- Read `core/ui/main_hud/main_hud.gd` — Existing HUD structure

**CHANGES:**
Connect to combat events for UI feedback:

**PSEUDO-CODE:**
```gdscript
# In main_hud.gd — Add in _ready() or appropriate init:

func _ready():
    # ... existing code ...
    EventBus.connect("combat_initiated", self, "_on_combat_initiated")
    EventBus.connect("combat_ended", self, "_on_combat_ended")
    EventBus.connect("agent_damaged", self, "_on_agent_damaged")

func _on_combat_initiated(player_agent, enemy_agents: Array) -> void:
    """Show combat indicator."""
    # Option 1: Show a "COMBAT" label
    # Option 2: Flash the screen border red briefly
    # For now, just print debug
    print("[HUD] Combat initiated with ", enemy_agents.size(), " hostiles")

func _on_combat_ended(result_dict: Dictionary) -> void:
    """Show victory/defeat message."""
    var outcome = result_dict.get("outcome", "unknown")
    print("[HUD] Combat ended: ", outcome)
    # Could show a brief "VICTORY" or "DEFEAT" label
    # Could trigger narrative action "Assess the Aftermath" here

func _on_agent_damaged(agent_body, damage_amount: float, source_agent) -> void:
    """Flash damage indicator if player hit."""
    var player = null
    if GlobalRefs.world_manager:
        player = GlobalRefs.world_manager.get("player_agent")
    if agent_body == player:
        print("[HUD] Player took ", damage_amount, " damage!")
        # Flash screen red or show damage number
        # Could call a _flash_damage() method
```

**SUCCESS CRITERIA:**
- HUD prints/shows feedback on combat_initiated
- HUD prints/shows message on combat_ended
- Player damage shows debug output (visual flash optional for Phase 1)

---

### TASK 6: Create Hostile NPC Template

**TARGET FILE:** `assets/data/agents/npc_hostile_default.tres`

**DEPENDENCIES:**
- Read existing agent templates in `assets/data/agents/` for format
- Read `core/resource/agent_template.gd` for structure

**CHANGES:**
Create a hostile NPC template resource:

**RESOURCE CONTENT:**
```gdscript
[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://core/resource/agent_template.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
template_id = "npc_hostile_default"
template_name = "Hostile Raider"
agent_name = "Raider"
agent_faction = "pirates"
character_template_id = "character_hostile_default"
ship_template_id = "ship_default"  # Uses same ship as player for now
is_player = false

# AI Configuration (read by ship_controller_ai.gd)
# These may need to be added to agent_template.gd if not present:
# hostile = true
# aggro_range = 800.0
# weapon_range = 500.0
```

**SUCCESS CRITERIA:**
- Template loads via `TemplateDatabase.get_template("agents", "npc_hostile_default")`
- Template has valid references to character and ship templates
- AgentSystem can spawn NPC using this template ID

---

### TASK 7: Write AI Combat Unit Tests

**TARGET FILE:** `tests/modules/piloting/test_ship_controller_ai.gd`

**DEPENDENCIES:**
- Read `addons/gut/test.gd` — GUT test patterns
- Read existing tests in `tests/core/` for patterns

**PSEUDO-CODE:**
```gdscript
# File: tests/modules/piloting/test_ship_controller_ai.gd
extends "res://addons/gut/test.gd"

const ShipControllerAI = preload("res://modules/piloting/scripts/ship_controller_ai.gd")

var _ai_controller = null
var _mock_agent = null

func before_each():
    # Create minimal mock agent
    _mock_agent = KinematicBody.new()
    _mock_agent.agent_uid = 999
    add_child_autofree(_mock_agent)
    
    _ai_controller = ShipControllerAI.new()
    _mock_agent.add_child(_ai_controller)
    _ai_controller.agent_script = _mock_agent

func after_each():
    _ai_controller = null
    _mock_agent = null

# --- State Transition Tests ---
func test_initial_state_is_idle():
    assert_eq(_ai_controller._current_state, ShipControllerAI.AIState.IDLE)

func test_hostile_flag_enables_scanning():
    _ai_controller.is_hostile = true
    _ai_controller.initialize({"hostile": true})
    # Should transition to PATROL when hostile
    assert_eq(_ai_controller._current_state, ShipControllerAI.AIState.PATROL)

func test_remains_idle_when_not_hostile():
    _ai_controller.is_hostile = false
    _ai_controller._physics_process(0.1)
    assert_eq(_ai_controller._current_state, ShipControllerAI.AIState.IDLE)

func test_transitions_to_flee_when_hull_critical():
    # Setup: Simulate low hull
    _ai_controller._current_state = ShipControllerAI.AIState.COMBAT
    _ai_controller._check_hull_status(0.1)  # 10% hull
    assert_eq(_ai_controller._current_state, ShipControllerAI.AIState.FLEE)

# --- Weapon Firing Tests ---
func test_fire_timer_decrements():
    _ai_controller._fire_timer = 1.0
    _ai_controller._process_combat(0.5)
    assert_lt(_ai_controller._fire_timer, 1.0)

func test_respects_fire_interval():
    _ai_controller._fire_timer = 0.5
    # Should not fire while timer > 0
    var fired = _ai_controller._try_fire_weapon()
    assert_false(fired, "Should not fire during cooldown")
```

**SUCCESS CRITERIA:**
- Tests cover state transitions (IDLE→PATROL→COMBAT→FLEE)
- Tests verify fire timer logic
- All tests pass: `godot --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/modules/piloting/ -gexit`

---

### TASK 8: Write Event System Unit Tests

**TARGET FILE:** `tests/core/systems/test_event_system.gd`

**DEPENDENCIES:**
- Read existing system tests for patterns
- Read `core/systems/event_system.gd` after modifications

**PSEUDO-CODE:**
```gdscript
# File: tests/core/systems/test_event_system.gd
extends "res://addons/gut/test.gd"

var _event_system = null
var _combat_initiated_count: int = 0
var _combat_ended_count: int = 0

func before_each():
    _event_system = preload("res://core/systems/event_system.gd").new()
    add_child_autofree(_event_system)
    _combat_initiated_count = 0
    _combat_ended_count = 0
    EventBus.connect("combat_initiated", self, "_on_combat_initiated")
    EventBus.connect("combat_ended", self, "_on_combat_ended")

func after_each():
    if EventBus.is_connected("combat_initiated", self, "_on_combat_initiated"):
        EventBus.disconnect("combat_initiated", self, "_on_combat_initiated")
    if EventBus.is_connected("combat_ended", self, "_on_combat_ended"):
        EventBus.disconnect("combat_ended", self, "_on_combat_ended")

func _on_combat_initiated(_a, _b):
    _combat_initiated_count += 1

func _on_combat_ended(_d):
    _combat_ended_count += 1

# --- Encounter Tests ---
func test_encounter_respects_cooldown():
    _event_system._encounter_cooldown = 10
    _event_system._on_world_event_tick(1)
    assert_eq(_combat_initiated_count, 0, "Should not trigger during cooldown")

func test_encounter_decrements_cooldown():
    _event_system._encounter_cooldown = 5
    _event_system._on_world_event_tick(2)
    assert_eq(_event_system._encounter_cooldown, 3)

func test_cooldown_does_not_go_negative():
    _event_system._encounter_cooldown = 2
    _event_system._on_world_event_tick(10)
    assert_eq(_event_system._encounter_cooldown, 0)

# --- Combat End Tests ---
func test_emits_combat_ended_when_hostiles_cleared():
    var mock_hostile = Node.new()
    add_child_autofree(mock_hostile)
    _event_system._active_hostiles = [mock_hostile]
    _event_system._on_agent_disabled(mock_hostile)
    assert_eq(_combat_ended_count, 1)

func test_tracks_multiple_hostiles():
    var hostile1 = Node.new()
    var hostile2 = Node.new()
    add_child_autofree(hostile1)
    add_child_autofree(hostile2)
    _event_system._active_hostiles = [hostile1, hostile2]
    _event_system._on_agent_disabled(hostile1)
    assert_eq(_combat_ended_count, 0, "Should not end with hostiles remaining")
    _event_system._on_agent_disabled(hostile2)
    assert_eq(_combat_ended_count, 1, "Should end when all hostiles gone")

func test_get_active_hostiles_returns_copy():
    var hostile = Node.new()
    add_child_autofree(hostile)
    _event_system._active_hostiles = [hostile]
    var result = _event_system.get_active_hostiles()
    result.clear()
    assert_eq(_event_system._active_hostiles.size(), 1, "Original array should be unchanged")
```

**SUCCESS CRITERIA:**
- Tests cover cooldown logic
- Tests verify hostile tracking
- Tests verify combat_ended emission
- All tests pass

---

### TASK 9: Integration Verification

**TARGET FILE:** N/A (Manual + Automated testing)

**DEPENDENCIES:**
- All previous tasks complete
- GUT test suite

**VERIFICATION STEPS:**

1. **Run Full GUT Suite:**
   ```bash
   godot --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
   ```
   - Expected: All tests pass (185+ tests)

2. **Manual Combat Flow Test:**
   - [ ] Start game in flight zone
   - [ ] Wait for time to pass OR call `GlobalRefs.event_system.force_encounter()` in debugger
   - [ ] Verify hostile NPC spawns at appropriate distance (600-1000 units)
   - [ ] Verify hostile NPC approaches player (state: COMBAT)
   - [ ] Verify hostile NPC fires weapons (player takes damage)
   - [ ] Fire back at hostile → verify damage applied
   - [ ] Destroy hostile → verify `combat_ended` signal fires
   - [ ] Verify hostile marked as disabled (stops moving)
   - [ ] Verify HUD shows combat feedback (debug prints at minimum)

3. **Edge Case Tests:**
   - [ ] Spawn multiple hostiles → defeat all → verify single `combat_ended`
   - [ ] AI hull critical → verify AI enters FLEE state and moves away
   - [ ] AI flees beyond range → verify AI despawns
   - [ ] No player in scene → encounter spawn fails gracefully (no crash)

**SUCCESS CRITERIA:**
- Zero test failures
- Complete combat loop playable: Encounter spawn → AI attacks → Player defeats AI → Victory
- No console errors during combat
- SESSION-LOG.md updated with "SPRINT 9 COMPLETE"

---

## 4. CONSTRAINTS

### Architectural Rules

1. **State Machine Pattern:** AI must use explicit state enum (`AIState`), not boolean flags. Use `match` statement for state processing.

2. **Signal-Driven Communication:** 
   - AI Controller → WeaponController: Direct method calls (same agent hierarchy)
   - EventSystem → Global: Use EventBus signals only
   - Combat state changes → EventBus: Always emit for UI/logging

3. **No Direct Player Reference Storage:** AI must query `GlobalRefs.world_manager.player_agent` each frame or cache with validity checks using `is_instance_valid()`. Player reference can become invalid.

4. **Stateless Systems:** EventSystem must not rely on scene tree state for core logic. Track hostiles by reference but verify validity before use.

5. **Combat Registration:** All agents entering combat MUST call `CombatSystem.register_combatant()` before firing. WeaponController handles this for player; AI Controller must ensure NPC is registered.

6. **Template-Driven Spawning:** Hostile NPCs must spawn via `AgentSystem.spawn_npc()` using template IDs, not hardcoded instantiation.

### Testing Rules

1. **Autofree Pattern:** All test-created nodes must use `add_child_autofree()` to prevent orphans.

2. **Signal Cleanup:** Tests connecting to EventBus MUST disconnect in `after_each()`.

3. **Null Safety:** All GlobalRefs access must check validity before use.

### DO NOT

- Do NOT implement player death/game-over (Sprint 10)
- Do NOT add new weapon types (use existing `ablative_laser.tres`)
- Do NOT modify agent.gd's command interface (stable API)
- Do NOT add complex UI for enemy indicators (debug prints sufficient for Phase 1)
- Do NOT implement flee despawn animation (instant despawn is acceptable)
- Do NOT add loot/salvage system (Sprint 10)

---

## 5. DEPENDENCY GRAPH

```
TASK 6 (Hostile Template) ←── needed for spawning
    ↓
TASK 1 (AI State Machine) ←── core AI behavior
    ↓
TASK 2 (AI Firing) ←── depends on TASK 1
    ↓
TASK 3 (Event System) ←── depends on TASK 6 for spawn
    ↓
TASK 4 (Combat End) ←── integrates with TASK 3
    ↓
TASK 5 (HUD Wiring) ←── depends on TASK 3, 4 signals
    ↓
TASK 7 (AI Tests) ←── depends on TASK 1, 2
    ↓
TASK 8 (Event Tests) ←── depends on TASK 3, 4
    ↓
TASK 9 (Integration) ←── depends on ALL
```

**Recommended Execution Order:**
1. TASK 6 (template first - blocks spawning)
2. TASK 1 (AI state machine)
3. TASK 2 (AI firing)
4. TASK 3 (Event System)
5. TASK 4 (Combat End)
6. TASK 5 (HUD)
7. TASK 7 + TASK 8 (tests - can parallel)
8. TASK 9 (integration)

---

## 6. OPEN QUESTIONS FOR FUTURE SPRINTS

1. **Danger Levels:** Zone-based danger levels not implemented. Hardcode `1.0` for now; revisit in Sprint 10 with LocationTemplate integration.

2. **Loot/Salvage:** Combat victory should eventually trigger salvage narrative action. Defer to Sprint 10.

3. **Multiple Enemy Types:** Phase 1 uses single hostile type. Template system supports multiple; defer to post-Phase 1.

4. **Visual Combat Feedback:** Screen flash on damage, combat music trigger, etc. Defer to Sprint 11 (Polish).

5. **AI Weapon Selection:** Currently fires weapon index 0. Multi-weapon AI logic deferred to Phase 2.
