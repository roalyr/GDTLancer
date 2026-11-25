# Optimization Draft

Potential performance-killing or unnecessarily active routines identified in the codebase, with minimal guard-based diff examples.

---

## 1. `Evolution` still runs in play mode (`frozen == true`)

`GameStateManager.set_mode("play")` sets `Evolution.frozen = true`, yet `Evolution` still runs `_physics_process()` (including `print_report()` every `EVO_REPORT_INTERVAL`), processes `EventBus` combat/death signals (`_on_agent_damaged`, `_on_agent_disabled`, `_end_life`), and runs `on_position()` -> `territory_at()` (`get_nodes_in_group("faction_station")`) from `BeaconNetwork._update()`.

**File:** `src/autoload/Evolution.gd`

```diff
 func _physics_process(delta: float) -> void:
 	if not active or live.empty():
 		return
 	game_time += delta
+	if frozen:
+		return
 	real_time += delta / max(Engine.time_scale, 0.001)
 	if game_time >= _report_due:
 		_report_due = game_time + Constants.EVO_REPORT_INTERVAL
 		print_report()
```

```diff
 func _on_agent_damaged(body, amount, source) -> void:
+	if frozen:
+		return
 	var victim_uid: String = str(body.get("evo_uid")) if is_instance_valid(body) and body.get("evo_uid") != null else ""
```

```diff
 func _on_agent_disabled(body) -> void:
 	if not is_instance_valid(body) or body.get("evo_uid") == null:
 		return
 	var uid: String = str(body.evo_uid)
 	if not live.has(uid):
 		return
+	if frozen:
+		live.erase(uid)
+		_bodies.erase(uid)
+		return
 	var killer: String = str(live[uid].get("last_hit_by", ""))
```

```diff
 func on_position(body: Node) -> void:
+	if frozen:
+		return
 	var uid: String = str(body.get("evo_uid"))
```

*(Also guard `_end_life()` with `if frozen: live.erase(uid); _bodies.erase(uid); return` if `retire`/`on_docked` reaches it in play mode.)*

---

## 2. `FrameProfiler` runs continuously while debug overlay is hidden

`MainHUD._ready()` unconditionally creates `FrameProfiler`, which sets the `"frame_profiler"` tree meta and hooks `physics_frame` and `idle_frame`. Every `FrameProfiler.begin()`/`end()` across `agent.gd`, `navigation_system.gd`, `tool_controller.gd`, `projectile.gd`, `view_detail.gd`, `engine_exhaust_set.gd`, `sound_effects.gd`, `offscreen.gd`, `ship_controller_ai.gd`, and `main_hud.gd` executes `OS.get_ticks_usec()` and dictionary updates every frame even when `debug_overlay` is hidden.

**File:** `src/core/ui/main_hud/main_hud.gd`

```diff
 func _ready():
-	_frame_profiler = FrameProfiler.new()
-	_frame_profiler.name = "FrameProfiler"
-	add_child(_frame_profiler)
 	_frame_governor = FrameGovernor.new()
```

```diff
 func _on_ButtonDebug_pressed() -> void:
 	if not is_instance_valid(debug_overlay):
 		return
 	debug_overlay.visible = not debug_overlay.visible
+	if debug_overlay.visible and not is_instance_valid(_frame_profiler):
+		_frame_profiler = FrameProfiler.new()
+		_frame_profiler.name = "FrameProfiler"
+		add_child(_frame_profiler)
+	elif not debug_overlay.visible and is_instance_valid(_frame_profiler):
+		_frame_profiler.queue_free()
+		_frame_profiler = null
 	if is_instance_valid(awareness_zone):
```

---

## 3. Visual effects and ship components active while docked, wrecked, or offscreen

`Offscreen._set_flown()` disables `_physics_process` on offscreen ships, but not `_process` on visual effects (`EngineExhaustSet`, `HullSmoulderEffect`, `DamageTrailEffect`, `FuelLeakEffect`). Meanwhile `Agent.dock_at()` and `Agent.become_wreck()` leave `_physics_process` active on `Agent` and `ToolController`.

**Files:** `src/core/agents/effects/engine_exhaust_set.gd`, `hull_smoulder_effect.gd`, `damage_trail_effect.gd`, `fuel_leak_effect.gd`

```diff
 # engine_exhaust_set.gd
 func _process(_delta: float) -> void:
+	if not is_visible_in_tree():
+		return
 	var tree: SceneTree = get_tree()
```

```diff
 # hull_smoulder_effect.gd
 func _process(delta: float) -> void:
+	if not is_visible_in_tree():
+		_age += delta
+		return
 	_age += delta
```

```diff
 # damage_trail_effect.gd
 func _process(delta: float) -> void:
+	if not is_visible_in_tree():
+		return
 	_check_timer -= delta
```

```diff
 # fuel_leak_effect.gd
 func _process(delta: float) -> void:
 	_age += delta
+	if _age >= Constants.FUEL_LEAK_DURATION + _jet.lifetime:
+		queue_free()
+		return
+	if not is_visible_in_tree():
+		return
 	var pressure: float = get_pressure()
```

**File:** `src/core/agents/agent.gd`

```diff
 func dock_at(station: Spatial) -> void:
 	if not is_docked:
 		_undocked_collision = [collision_layer, collision_mask]
 	is_docked = true
 	visible = false
+	set_physics_process(false)
+	if is_instance_valid(tool_controller):
+		tool_controller.set_physics_process(false)
```

```diff
 func undock() -> void:
 	if is_docked and _undocked_collision.size() == 2:
 		collision_layer = _undocked_collision[0]
 		collision_mask = _undocked_collision[1]
 	if is_docked:
 		mode = MODE_RIGID
 		sleeping = false
 	is_docked = false
 	visible = true
+	set_physics_process(true)
+	if is_instance_valid(tool_controller):
+		tool_controller.set_physics_process(true)
```

```diff
 func become_wreck() -> void:
 	if is_wreck:
 		return
 	is_wreck = true
+	set_physics_process(false)
+	if is_instance_valid(tool_controller):
+		tool_controller.deactivate_all("wrecked")
+		tool_controller.set_physics_process(false)
```

*(Also in `src/core/agents/components/lance_controller.gd`: `if not is_instance_valid(_agent) or _agent.is_wreck or _agent.is_docked: return` at the top of `_physics_process()`.)*

---

## 4. `ThreatRing` redrawing every frame and `ThreatWatch` scanning while docked

`ThreatRing._process()` calls `update()` every frame even when `_threats` and `partners` are empty or the player is docked. `ThreatWatch._process()` calls `get_tree().get_nodes_in_group("agent_body")` before checking if the player is docked or wrecked.

**File:** `src/core/ui/main_hud/threat_ring.gd`

```diff
 func _process(delta: float) -> void:
+	var player = GlobalRefs.player_agent_body
+	if not is_instance_valid(player) or player.get("is_docked") or player.get("is_wreck"):
+		if not _threats.empty():
+			_threats = []
+			update()
+		return
 	_refresh_left -= delta
 	if _refresh_left <= 0.0:
 		_refresh_left = Constants.THREAT_REFRESH_INTERVAL
 		_threats = []
-		for ship in threats(GlobalRefs.player_agent_body, get_tree().get_nodes_in_group("agent_body")):
+		for ship in threats(player, get_tree().get_nodes_in_group("agent_body")):
 			_threats.append(weakref(ship))
-	update()
+	var has_partners: bool = is_instance_valid(GlobalRefs.main_hud) and GlobalRefs.main_hud.has_method("get_partners") and not GlobalRefs.main_hud.get_partners().empty()
+	if not _threats.empty() or has_partners:
+		update()
```

**File:** `src/core/systems/threat_watch.gd`

```diff
 func _process(delta: float) -> void:
 	_left -= delta
 	if _left > 0.0:
 		return
 	_left = Constants.THREAT_WATCH_INTERVAL
-	check(GlobalRefs.player_agent_body, get_tree().get_nodes_in_group("agent_body"))
+	var player = GlobalRefs.player_agent_body
+	var active: bool = is_instance_valid(player) and not player.get("is_docked") and not player.get("is_wreck")
+	check(player, get_tree().get_nodes_in_group("agent_body") if active else [])
```

---

## 5. `AmbientMusic._process()` updating volume every frame when steady or muted

Once tracks finish fading (or when music volume is `0.0`), `AmbientMusic._process()` still loops over `_players`, computes `clamp`, `lerp`, `sqrt`, and writes `volume_db` every frame.

**File:** `src/scenes/game_world/ambient_music.gd`

```diff
 func _process(delta: float) -> void:
 	if not _started:
 		return
 	if not _pending.empty() and _silent():
 		_set_tracks(_pending)  # The old sector's tracks are out: the new ones come in
 		_pending = {}
 	var current: String = track_for(level) if float(Settings.get_option("music")) > 0.0 and _pending.empty() else ""  # Off, or changing sectors: all fade out
 	var step: float = delta / max(_fade_time, 0.01)
 	for key in _players:
 		var player: AudioStreamPlayer = _players[key]
 		if player.stream == null:
 			continue
-		_gain[key] = clamp(_gain[key] + (step if key == current else -step), 0.0, 1.0)
-		player.volume_db = lerp(Constants.MUSIC_SILENT_DB, Constants.MUSIC_AMBIENT_VOLUME_DB, sqrt(_gain[key]))
+		var next_gain: float = clamp(_gain[key] + (step if key == current else -step), 0.0, 1.0)
+		if next_gain == _gain[key]:
+			continue
+		_gain[key] = next_gain
+		player.volume_db = lerp(Constants.MUSIC_SILENT_DB, Constants.MUSIC_AMBIENT_VOLUME_DB, sqrt(next_gain))
 		if _gain[key] > 0.0 and not player.playing:
 			player.play()
 		elif _gain[key] <= 0.0 and player.playing:
 			player.stop()
```

---

## 6. Uncached `get_nodes_in_group()` calls in physics-step paths

`StepCache.group(tree, name)` avoids allocating a new Array on every `get_nodes_in_group()` call during physics steps, but several physics-step callers still bypass it (including `Agent.in_territory`, `Hazard._physics_process`, `BeaconNetwork._update`, `PlatformController`, and `ShipControllerAI`).

**File:** `src/core/agents/agent.gd`

```diff
 func in_territory(other) -> bool:
 	var territory: float = float(TemplateDatabase.factions.get(faction, {}).get("territory", 0.0))
 	if territory <= 0.0 or other.get("faction") == faction or not is_inside_tree():
 		return false
-	for station in get_tree().get_nodes_in_group("faction_station"):
+	for station in StepCache.group(get_tree(), "faction_station"):
+		if not is_instance_valid(station):
+			continue
 		if station.get("faction") == faction and other.global_transform.origin.distance_to(station.global_transform.origin) <= territory:
 			return true
 	return false
```

**Files:** `src/scenes/game_world/sector_layout/hazard.gd`, `beacon_network.gd`, `src/modules/piloting/platform_controller.gd`, `src/modules/piloting/ship_controller_ai.gd`

```diff
 # Example (repeat for each physics-step caller; preload StepCache if not already present)
+const StepCache = preload("res://src/core/utils/step_cache.gd")
 ...
-	for body in get_tree().get_nodes_in_group("agent_body"):
+	for body in StepCache.group(get_tree(), "agent_body"):
+		if not is_instance_valid(body):
+			continue
```

Affected locations:
- `src/scenes/game_world/sector_layout/hazard.gd:53` (`_physics_process`)
- `src/scenes/game_world/sector_layout/beacon_network.gd:109` (`_update`)
- `src/modules/piloting/platform_controller.gd:115, 150` (`clear_shot`, `_pick_target`)
- `src/modules/piloting/ship_controller_ai.gd:275, 442, 491, 504, 1578, 1741, 1791, 1807` (`agent_body`) and `:1761` (`loose_lance`)

---

## 7. `ViewDetail` judging hidden (docked or offscreen) hosts

`ViewDetail._check_all()` iterates `_ALL.list` and computes `ViewBand.screen_share()` and `band_changed` for every host in the tree—including docked and offscreen ships whose `visible` is `false`.

**File:** `src/core/agents/components/view_detail.gd`

```diff
 	for detail in _ALL.list.duplicate():  # A band change may take a host out of the tree
 		if not is_instance_valid(detail) or (detail._due > clock and not zoomed):
 			continue
-		if not detail.is_inside_tree() or not is_instance_valid(detail._host):
+		if not detail.is_inside_tree() or not is_instance_valid(detail._host) or not detail._host.visible:
 			continue
 		var camera: Camera = detail._viewport.get_camera()
```

---

## 8. `MainHUD` projecting brackets and updating flight controls while docked

When the player is docked, the world is not paused (`MainHUD._process()` still runs), so `_update_hud()` continues projecting all route/world brackets and refreshing tool/lance/afterburner/safety buttons behind the station UI.

**File:** `src/core/ui/main_hud/main_hud.gd`

```diff
 	var now: int = OS.get_ticks_usec()
 	var dt: float = clamp((now - _hud_last_usec) / 1000000.0, 0.0, 1.0) if _hud_last_usec > 0 else 0.0
 	_hud_last_usec = now
-	# Every frame: what moves with the view (positions) and button highlights (a tap answers at once).
-	_update_route_target_overlay()
-	_update_world_target_overlay(false)
-	_refresh_toggle_button_states()
-	# On their cadences (Constants UPDATE CADENCES), out of step with the bracket slices and each other.
-	_controls_left -= dt
-	if _controls_left <= 0.0:
-		_controls_left = Constants.HUD_CONTROLS_INTERVAL
-		_update_tool_buttons()
-		_update_lance_button()
-		_update_afterburner_button()
-		_update_safety_button()
-		_layout_tool_rows()
-		_update_dock_button_label()
-		_partners_left -= Constants.HUD_CONTROLS_INTERVAL
-		if _partners_left <= 0.0:
-			refresh_partners()
-		_update_interact_button_label()
-		_update_approach_button_label()
+	var player = GlobalRefs.player_agent_body
+	var docked: bool = is_instance_valid(player) and bool(player.get("is_docked"))
+	if not docked:
+		# Every frame: what moves with the view (positions) and button highlights (a tap answers at once).
+		_update_route_target_overlay()
+		_update_world_target_overlay(false)
+		_refresh_toggle_button_states()
+		# On their cadences (Constants UPDATE CADENCES), out of step with the bracket slices and each other.
+		_controls_left -= dt
+		if _controls_left <= 0.0:
+			_controls_left = Constants.HUD_CONTROLS_INTERVAL
+			_update_tool_buttons()
+			_update_lance_button()
+			_update_afterburner_button()
+			_update_safety_button()
+			_layout_tool_rows()
+			_update_dock_button_label()
+			_partners_left -= Constants.HUD_CONTROLS_INTERVAL
+			if _partners_left <= 0.0:
+				refresh_partners()
+			_update_interact_button_label()
+			_update_approach_button_label()
 	_debug_left -= dt
```

---

## 9. `OrbitCamera` polling `Settings` every physics step

`OrbitCamera` already connects to `Settings.changed` (`_on_settings_changed`), yet `_physics_process()` still calls `Settings.get_option("dynamic_camera")` on every physics step.

**File:** `src/scenes/camera/orbit_camera.gd`

```diff
 func _physics_process(delta):
 	if is_instance_valid(_position_controller):
-		var dynamic: bool = bool(Settings.get_option("dynamic_camera"))
-		if dynamic != _position_controller.dynamic:
-			_rotation_controller.set_loose(dynamic)
-		_position_controller.dynamic = dynamic
 		_position_controller.physics_step(delta)
 	if not Interp.enabled():
 		_follow(delta)
```

*(Ensure `_position_controller.dynamic` and `_rotation_controller.set_loose()` are initialized once in `_ready()` from `Settings.get_option("dynamic_camera")`, after which `_on_settings_changed` keeps them in sync.)*

---

## Test Impact

Checked the related GUT suites under `src/tests/` against all 9 changes:

- **No existing tests break:**
  - `test_evolution.gd`: frozen-world tests (`test_a_frozen_world_flies_its_factions_archetypes_on_their_hulls`, `test_a_free_port_ships_life_ends_on_record_though_evolution_has_no_pool_for_it`) already flip `Evolution.frozen = false` before calling `_end_life()`; `test_a_play_save_holds_no_evolution_and_reloads_archetypes_from_their_presets` only calls `begin_life()`, `serialize()`, and `deserialize()`.
  - `test_hardpoints.gd`: instances `EngineExhaustSet` under an in-tree visible `FakeShip`, so `is_visible_in_tree()` is `true`.
  - `test_tool_controller.gd`: calls `become_wreck()` and expects tools to stop firing (`deactivate_all("wrecked")` + `set_physics_process(false)` matches this).
  - `test_threat_ring.gd` & `test_threat_watch.gd`: test static helpers or call `check()` directly with `_process` disabled.
  - `test_ambient_music.gd`: all assertions test `_gain` transitions (`0 -> 1 -> 0`) or initial `0.0` state, which still behave identically.
  - `test_step_cache.gd` & physics-step callers: `StepCache.active()` is `false` in unit tests, so `StepCache.group()` falls back to `tree.get_nodes_in_group()` fresh on every call.
  - `test_main_hud_projected_targeting.gd`: calls `hud._update_world_target_overlay()` directly with an undocked player.
  - `test_view_band.gd`, `test_mesh_lod.gd`, `test_hull_scars.gd`: attach `ViewDetail` to visible in-tree `Spatial` hosts.
- **Adjustments / notes when applying:**
  - **Case 9 (`OrbitCamera`)**: initialize `_position_controller.dynamic` and `_rotation_controller.set_loose()` in `_ready()` from `Settings.get_option("dynamic_camera")` when removing the `_physics_process()` poll.
  - **Case 7 (`ViewDetail`)**: if a ship becomes `visible = true` again (undocking or returning from offscreen), reset `detail._due = -1.0` so its LOD band updates immediately instead of waiting up to `VIEW_CHECK_INTERVAL`.
  - **New tests worth adding**: unit tests verifying `Evolution` skips `_on_agent_damaged` / `_on_agent_disabled` when `frozen == true`, and `ViewDetail._check_all()` skips hidden hosts.
