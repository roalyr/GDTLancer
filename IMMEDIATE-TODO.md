# IMMEDIATE-TODO.md
**Generated:** December 14, 2025  
**Target Sprint:** Sprint 7 - Narrative Actions Core  
**Previous Sprints Status:** Sprints 1-6 COMPLETE (verified in codebase)

---

## 1. CONTEXT

We are implementing the **Narrative Action System** (Sprint 7), which allows players to make Risky/Cautious decisions during key gameplay moments with dice-roll resolution. This is a **core differentiator** of GDTLancer's gameplay loop—every significant action (docking, trading, contract completion) triggers a narrative check that can result in bonuses, penalties, or ship quirks.

The foundation systems (Trading, Contracts, Docking, Station UI) are complete and tested. The next step integrates narrative outcomes into these existing flows.

---

## 2. FILE MANIFEST

### Files to CREATE:
| File | Purpose |
|------|---------|
| `core/systems/narrative_action_system.gd` | API for requesting/resolving narrative actions |
| `core/ui/action_check/action_check.tscn` | Modal UI for Risky/Cautious selection + result |
| `core/ui/action_check/action_check.gd` | UI logic, FP allocation, result display |
| `autoload/NarrativeOutcomes.gd` | Outcome tables (effects per action type + tier) |

### Files to MODIFY:
| File | Change |
|------|--------|
| `autoload/GlobalRefs.gd` | Add `narrative_action_system` reference + setter |
| `scenes/game_world/main_game_scene.tscn` | Add `NarrativeActionSystem` node under WorldManager |
| `core/ui/main_hud/main_hud.gd` | Instantiate `ActionCheckUI`, connect to `narrative_action_requested` |
| `scenes/ui/station_menu/station_menu.gd` | Trigger narrative action on contract completion |
| `core/systems/trading_system.gd` | Emit `narrative_action_requested` after large trades (optional Phase 1) |

### Files to READ for Context (Dependencies):
- `autoload/CoreMechanicsAPI.gd` — `perform_action_check()` signature
- `autoload/EventBus.gd` — Signal patterns, existing `narrative_action_*` signals
- `autoload/GameState.gd` — `narrative_state`, `session_stats` structure
- `core/systems/character_system.gd` — `get_skill_level()`, `subtract_fp()`, `add_fp()`
- `core/resource/asset_ship_template.gd` — `ship_quirks` array structure

---

## 3. ATOMIC TASKS

---

### TASK 1: Create NarrativeOutcomes Data Autoload

**TARGET FILE:** `autoload/NarrativeOutcomes.gd`

**DEPENDENCIES:**
- Read `autoload/Constants.gd` for tier names (CritSuccess, SwC, Failure)
- Read `GDD-COMBINED-TEXT-frozen-2025-10-31.md` sections on narrative outcomes (if available)

**PSEUDO-CODE SIGNATURES:**
```gdscript
extends Node

# Outcome structure per action_type + tier
# Returns: {description: String, effects: Dictionary}
# effects keys: "add_quirk", "wp_cost", "wp_gain", "fp_gain", "reputation_change"

const OUTCOMES: Dictionary = {
    "contract_complete": {
        "CritSuccess": {
            "description": "Flawless delivery - client impressed",
            "effects": {"wp_gain": 5, "reputation_change": 1}
        },
        "SwC": {
            "description": "Delivery complete with minor issues",
            "effects": {}
        },
        "Failure": {
            "description": "Cargo damaged in transit",
            "effects": {"wp_cost": 10, "add_quirk": "reputation_tarnished"}
        }
    },
    "dock_arrival": {
        "CritSuccess": {...},
        "SwC": {...},
        "Failure": {...}
    },
    "trade_finalize": {
        "CritSuccess": {...},
        "SwC": {...},
        "Failure": {...}
    }
}

func get_outcome(action_type: String, tier_name: String) -> Dictionary
func get_available_action_types() -> Array
```

**SUCCESS CRITERIA:**
- Can retrieve outcome data for all three action types
- Effects dictionary is well-structured for downstream application
- File loads without error as autoload

---

### TASK 2: Create NarrativeActionSystem

**TARGET FILE:** `core/systems/narrative_action_system.gd`

**DEPENDENCIES:**
- Read `autoload/CoreMechanicsAPI.gd` — lines 1-80, specifically `perform_action_check()`
- Read `autoload/EventBus.gd` — signals `narrative_action_requested`, `narrative_action_resolved`
- Read `core/systems/character_system.gd` — `get_skill_level()`, FP methods
- Read `autoload/NarrativeOutcomes.gd` (Task 1)

**PSEUDO-CODE SIGNATURES:**
```gdscript
extends Node

signal action_ui_requested(action_data)  # Internal: tells UI to show
signal action_resolved(result_data)       # Internal: tells UI result is ready

var _pending_action: Dictionary = {}  # Stores context while waiting for player input

func _ready():
    GlobalRefs.set_narrative_action_system(self)

# Called by game systems (ContractSystem, TradingSystem) to initiate
# Emits EventBus.narrative_action_requested to trigger UI display
# context: {char_uid, action_type, description, related_ids...}
func request_action(action_type: String, context: Dictionary) -> void:
    _pending_action = {
        "action_type": action_type,
        "context": context,
        "char_uid": context.get("char_uid", GameState.player_character_uid)
    }
    # Determine which skill/attribute applies
    var skill_info = _get_skill_for_action(action_type)
    _pending_action.merge(skill_info)
    EventBus.emit_signal("narrative_action_requested", _pending_action)

# Called by ActionCheckUI when player confirms selection
# approach: Constants.ActionApproach (RISKY or CAUTIOUS)
# fp_spent: int (0-3 typically)
func resolve_action(approach: int, fp_spent: int) -> Dictionary:
    var char_uid = _pending_action.char_uid
    var attr = GlobalRefs.character_system.get_attribute(char_uid, _pending_action.attribute_name)
    var skill = GlobalRefs.character_system.get_skill_level(char_uid, _pending_action.skill_name)
    
    # Perform the roll via CoreMechanicsAPI
    var roll_result = CoreMechanicsAPI.perform_action_check(attr, skill, fp_spent, approach)
    
    # Get narrative outcome from tier
    var tier_name = roll_result.tier_name
    var outcome = NarrativeOutcomes.get_outcome(_pending_action.action_type, tier_name)
    
    # Apply effects
    var applied = _apply_effects(char_uid, outcome.effects)
    
    # Deduct FP spent
    if fp_spent > 0:
        GlobalRefs.character_system.subtract_fp(char_uid, fp_spent)
    
    # Handle FP gain/loss from result
    if roll_result.focus_gain > 0:
        GlobalRefs.character_system.add_fp(char_uid, roll_result.focus_gain)
    if roll_result.focus_loss_reset:
        # Reset FP to base (implementation detail)
        pass
    
    var result = {
        "roll_result": roll_result,
        "outcome": outcome,
        "effects_applied": applied,
        "action_type": _pending_action.action_type
    }
    
    EventBus.emit_signal("narrative_action_resolved", result)
    _pending_action = {}
    return result

# Internal: maps action_type to skill/attribute used
func _get_skill_for_action(action_type: String) -> Dictionary:
    match action_type:
        "contract_complete":
            return {"attribute_name": "cunning", "skill_name": "negotiation"}
        "dock_arrival":
            return {"attribute_name": "reflex", "skill_name": "piloting"}
        "trade_finalize":
            return {"attribute_name": "cunning", "skill_name": "trading"}
        _:
            return {"attribute_name": "cunning", "skill_name": "general"}

# Internal: applies effects from outcome
func _apply_effects(char_uid: int, effects: Dictionary) -> Dictionary:
    var applied = {}
    if effects.has("add_quirk"):
        var ship = GlobalRefs.asset_system.get_player_ship()
        if ship:
            ship.ship_quirks.append(effects.add_quirk)
            applied["quirk_added"] = effects.add_quirk
    if effects.has("wp_cost"):
        GlobalRefs.character_system.subtract_wp(char_uid, effects.wp_cost)
        applied["wp_lost"] = effects.wp_cost
    if effects.has("wp_gain"):
        GlobalRefs.character_system.add_wp(char_uid, effects.wp_gain)
        applied["wp_gained"] = effects.wp_gain
    if effects.has("reputation_change"):
        GameState.narrative_state.reputation += effects.reputation_change
        applied["reputation_changed"] = effects.reputation_change
    return applied
```

**SUCCESS CRITERIA:**
- `request_action()` emits `narrative_action_requested` with complete data
- `resolve_action()` returns valid roll result + outcome data
- Effects correctly modify GameState (quirks, WP, reputation)
- FP spending and gain/loss handled correctly

---

### TASK 3: Create ActionCheckUI Scene

**TARGET FILE:** `core/ui/action_check/action_check.tscn`

**DEPENDENCIES:**
- Read `scenes/ui/station_menu/StationMenu.tscn` — for UI structure patterns
- Read `core/ui/main_hud/main_hud.tscn` — for theming/layout reference

**SCENE STRUCTURE:**
```
ActionCheckUI (Control, anchors full rect)
├── Overlay (ColorRect, semi-transparent black, full rect)
├── Panel (PanelContainer, centered)
│   └── VBoxContainer
│       ├── LabelTitle (Label) — "Resolve Action"
│       ├── LabelDescription (Label, autowrap) — Context text
│       ├── HSeparator
│       ├── HBoxApproach (HBoxContainer)
│       │   ├── BtnCautious (Button) — "Act Cautiously"
│       │   └── BtnRisky (Button) — "Act Risky"
│       ├── HBoxFP (HBoxContainer)
│       │   ├── LabelFP (Label) — "Focus Points:"
│       │   └── SpinBoxFP (SpinBox, min=0, max=3, step=1)
│       ├── LabelCurrentFP (Label) — "Available: X FP"
│       ├── BtnConfirm (Button) — "Confirm"
│       ├── HSeparator
│       └── VBoxResult (VBoxContainer, initially hidden)
│           ├── LabelRollResult (Label) — "Roll: 14 → Success with Cost"
│           ├── LabelOutcomeDesc (RichTextLabel) — Narrative description
│           ├── LabelEffects (Label) — "Effects: -10 WP, Quirk Added"
│           └── BtnContinue (Button) — "Continue"
```

**SUCCESS CRITERIA:**
- Scene loads without errors
- All node paths in script match scene structure
- Centered modal over game view
- Result section starts hidden

---

### TASK 4: Create ActionCheckUI Script

**TARGET FILE:** `core/ui/action_check/action_check.gd`

**DEPENDENCIES:**
- Read `core/systems/narrative_action_system.gd` (Task 2)
- Read `autoload/Constants.gd` — `ActionApproach` enum
- Read `scenes/ui/station_menu/station_menu.gd` — UI pattern reference

**PSEUDO-CODE SIGNATURES:**
```gdscript
extends Control

onready var label_title = $Panel/VBoxContainer/LabelTitle
onready var label_description = $Panel/VBoxContainer/LabelDescription
onready var btn_cautious = $Panel/VBoxContainer/HBoxApproach/BtnCautious
onready var btn_risky = $Panel/VBoxContainer/HBoxApproach/BtnRisky
onready var spinbox_fp = $Panel/VBoxContainer/HBoxFP/SpinBoxFP
onready var label_current_fp = $Panel/VBoxContainer/LabelCurrentFP
onready var btn_confirm = $Panel/VBoxContainer/BtnConfirm
onready var vbox_result = $Panel/VBoxContainer/VBoxResult
onready var label_roll_result = $Panel/VBoxContainer/VBoxResult/LabelRollResult
onready var label_outcome_desc = $Panel/VBoxContainer/VBoxResult/LabelOutcomeDesc
onready var label_effects = $Panel/VBoxContainer/VBoxResult/LabelEffects
onready var btn_continue = $Panel/VBoxContainer/VBoxResult/BtnContinue

var _selected_approach: int = Constants.ActionApproach.CAUTIOUS
var _action_data: Dictionary = {}

func _ready():
    visible = false
    vbox_result.visible = false
    btn_cautious.connect("pressed", self, "_on_cautious_pressed")
    btn_risky.connect("pressed", self, "_on_risky_pressed")
    btn_confirm.connect("pressed", self, "_on_confirm_pressed")
    btn_continue.connect("pressed", self, "_on_continue_pressed")
    EventBus.connect("narrative_action_requested", self, "_on_action_requested")

func _on_action_requested(action_data: Dictionary):
    _action_data = action_data
    _show_selection_ui()

func _show_selection_ui():
    visible = true
    vbox_result.visible = false
    btn_confirm.visible = true
    
    label_title.text = _get_action_title(_action_data.action_type)
    label_description.text = _action_data.context.get("description", "Resolve this action.")
    
    var current_fp = GlobalRefs.character_system.get_fp(_action_data.char_uid)
    label_current_fp.text = "Available: %d FP" % current_fp
    spinbox_fp.max_value = min(3, current_fp)
    spinbox_fp.value = 0
    
    _select_approach(Constants.ActionApproach.CAUTIOUS)

func _select_approach(approach: int):
    _selected_approach = approach
    btn_cautious.pressed = (approach == Constants.ActionApproach.CAUTIOUS)
    btn_risky.pressed = (approach == Constants.ActionApproach.RISKY)

func _on_cautious_pressed():
    _select_approach(Constants.ActionApproach.CAUTIOUS)

func _on_risky_pressed():
    _select_approach(Constants.ActionApproach.RISKY)

func _on_confirm_pressed():
    var fp_spent = int(spinbox_fp.value)
    var result = GlobalRefs.narrative_action_system.resolve_action(_selected_approach, fp_spent)
    _show_result(result)

func _show_result(result: Dictionary):
    btn_confirm.visible = false
    vbox_result.visible = true
    
    var roll = result.roll_result
    label_roll_result.text = "Roll: %d → %s" % [roll.roll_total, roll.tier_name]
    label_outcome_desc.bbcode_text = "[i]%s[/i]" % result.outcome.description
    
    var effects_text = _format_effects(result.effects_applied)
    label_effects.text = effects_text if effects_text != "" else "No additional effects."

func _format_effects(effects: Dictionary) -> String:
    var parts = []
    if effects.has("wp_lost"):
        parts.append("-%d WP" % effects.wp_lost)
    if effects.has("wp_gained"):
        parts.append("+%d WP" % effects.wp_gained)
    if effects.has("quirk_added"):
        parts.append("Quirk: %s" % effects.quirk_added)
    if effects.has("reputation_changed"):
        var rep = effects.reputation_changed
        parts.append("%+d Reputation" % rep)
    return PoolStringArray(parts).join(", ")

func _on_continue_pressed():
    visible = false
    _action_data = {}

func _get_action_title(action_type: String) -> String:
    match action_type:
        "contract_complete": return "Finalize Delivery"
        "dock_arrival": return "Execute Approach"
        "trade_finalize": return "Seal the Deal"
        _: return "Resolve Action"
```

**SUCCESS CRITERIA:**
- UI shows when `narrative_action_requested` emitted
- Player can select Risky/Cautious approach
- Player can allocate FP (capped by available FP)
- Confirm triggers `resolve_action()` and shows result
- Continue closes UI

---

### TASK 5: Integrate ActionCheckUI into MainHUD

**TARGET FILE:** `core/ui/main_hud/main_hud.gd`

**DEPENDENCIES:**
- Read current `core/ui/main_hud/main_hud.gd` — lines 1-50
- Task 3 + Task 4 complete

**CHANGES:**
```gdscript
# Add near line 15 (after StationMenuScene):
const ActionCheckScene = preload("res://core/ui/action_check/action_check.tscn")
var action_check_instance = null

# Add in _ready() after station_menu_instance setup:
action_check_instance = ActionCheckScene.instance()
add_child(action_check_instance)
# ActionCheckUI handles its own visibility via EventBus
```

**SUCCESS CRITERIA:**
- ActionCheckUI instance exists in HUD hierarchy
- UI appears when `narrative_action_requested` signal fires

---

### TASK 6: Integrate Narrative Action into Contract Completion

**TARGET FILE:** `scenes/ui/station_menu/station_menu.gd`

**DEPENDENCIES:**
- Read current file — `_on_complete_contract_pressed()` method
- Task 2 complete (NarrativeActionSystem exists)

**CHANGES:**
Modify `_on_complete_contract_pressed()` to:
1. Instead of calling `complete_contract()` directly, call `request_action()`
2. Listen for `narrative_action_resolved` to then call `complete_contract()` with modifiers

**PSEUDO-CODE:**
```gdscript
# Add to _ready():
EventBus.connect("narrative_action_resolved", self, "_on_narrative_resolved")

var _pending_contract_completion: String = ""

func _on_complete_contract_pressed():
    if completable_contract_id == "":
        return
    
    _pending_contract_completion = completable_contract_id
    
    # Request narrative action instead of completing directly
    if GlobalRefs.narrative_action_system:
        GlobalRefs.narrative_action_system.request_action("contract_complete", {
            "char_uid": GameState.player_character_uid,
            "contract_id": completable_contract_id,
            "description": "Finalize delivery of '%s'. How do you approach the handoff?" % completable_contract_title
        })
    else:
        # Fallback: complete without narrative check
        _finalize_contract_completion()

func _on_narrative_resolved(result: Dictionary):
    if result.action_type == "contract_complete" and _pending_contract_completion != "":
        _finalize_contract_completion()
        _pending_contract_completion = ""

func _finalize_contract_completion():
    if GlobalRefs.contract_system:
        var result = GlobalRefs.contract_system.complete_contract(
            GameState.player_character_uid, 
            completable_contract_id
        )
        # ... existing reward popup logic ...
```

**SUCCESS CRITERIA:**
- Clicking "Complete Contract" opens ActionCheckUI
- After resolving action, contract actually completes
- Narrative effects (quirks, WP changes) apply before contract reward

---

### TASK 7: Add GlobalRefs Entry for NarrativeActionSystem

**TARGET FILE:** `autoload/GlobalRefs.gd`

**DEPENDENCIES:**
- Read current `autoload/GlobalRefs.gd` structure

**CHANGES:**
```gdscript
# Add variable:
var narrative_action_system: Node = null

# Add setter:
func set_narrative_action_system(system: Node):
    narrative_action_system = system
```

**SUCCESS CRITERIA:**
- `GlobalRefs.narrative_action_system` accessible from any script
- Setter follows existing pattern (e.g., `set_trading_system`)

---

### TASK 8: Register NarrativeActionSystem in Scene Tree

**TARGET FILE:** `scenes/game_world/main_game_scene.tscn`

**DEPENDENCIES:**
- Examine current scene structure for node placement pattern

**CHANGES:**
- Add `NarrativeActionSystem` node under `WorldManager` (or similar parent)
- Attach `core/systems/narrative_action_system.gd` script

**SUCCESS CRITERIA:**
- System initializes when game scene loads
- `GlobalRefs.narrative_action_system` populated in `_ready()`

---

## 4. CONSTRAINTS

### Architectural Rules:
1. **NarrativeActionSystem MUST be a Node** — Not a Resource. It needs `_ready()` lifecycle and signal connections.
2. **All state changes go through existing systems** — Use `CharacterSystem.add_wp()`, not direct `GameState` mutation.
3. **EventBus for cross-system communication** — `narrative_action_requested` and `narrative_action_resolved` signals.
4. **UI is modal and blocking** — Player cannot interact with game while ActionCheckUI is visible.
5. **NarrativeOutcomes is data-only** — Pure data lookup, no game logic. Keep outcome tables easily editable.

### Signal Flow:
```
ContractSystem._on_complete_contract_pressed()
    → NarrativeActionSystem.request_action()
        → EventBus.emit("narrative_action_requested")
            → ActionCheckUI._on_action_requested()
                [Player makes selection]
            → NarrativeActionSystem.resolve_action()
                → CoreMechanicsAPI.perform_action_check()
                → _apply_effects()
                → EventBus.emit("narrative_action_resolved")
                    → StationMenu._on_narrative_resolved()
                        → ContractSystem.complete_contract()
```

### DO NOT:
- Create new autoloads without updating `project.godot`
- Modify `CoreMechanicsAPI.perform_action_check()` signature
- Add UI elements to scenes outside MainHUD hierarchy
- Store persistent state in NarrativeActionSystem (it's stateless between actions)

### Testing Notes:
- Manual test: Accept contract → travel → dock at destination → click Complete → verify ActionCheckUI appears
- Manual test: Select Risky + 2 FP → Confirm → verify roll result shows → Continue → verify contract completes
- Manual test: Trigger Failure outcome → verify quirk added to ship in GameState

---

## 5. VERIFICATION CHECKLIST

After implementation, verify:

- [ ] `NarrativeOutcomes.get_outcome("contract_complete", "CritSuccess")` returns valid data
- [ ] `GlobalRefs.narrative_action_system` is not null after scene load
- [ ] Pressing Complete Contract at destination station opens ActionCheckUI
- [ ] Selecting approach visually highlights correct button
- [ ] FP spinbox max is capped at player's available FP
- [ ] Confirm button triggers roll and shows result panel
- [ ] Continue button closes UI and completes contract
- [ ] WP changes from effects reflected in HUD
- [ ] Ship quirks added on Failure visible in `GameState.assets_ships[uid].ship_quirks`
- [ ] System works when `narrative_action_system` is null (graceful fallback)

---

## 6. ESTIMATED COMPLEXITY

| Task | Difficulty | Lines of Code | Dependencies |
|------|------------|---------------|--------------|
| Task 1 | Low | ~80 | None |
| Task 2 | Medium | ~150 | Task 1, CoreMechanicsAPI |
| Task 3 | Low | Scene only | Theme reference |
| Task 4 | Medium | ~120 | Task 2, Task 3 |
| Task 5 | Low | ~10 | Task 3, Task 4 |
| Task 6 | Medium | ~40 | Task 2 |
| Task 7 | Low | ~5 | None |
| Task 8 | Low | Scene edit | Task 2 |

**Total estimated new code:** ~400 lines  
**Recommended order:** 7 → 1 → 2 → 8 → 3 → 4 → 5 → 6
