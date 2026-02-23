#
# PROJECT: GDTLancer
# MODULE: simulation_engine.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_11
# LOG_REF: 2026-02-21 (TASK_11)
#

extends Node

## SimulationEngine: Qualitative tick orchestrator for the tag-based simulation.
##
## Manages the full tick sequence:
##   Step 0: Advance World-Age (PROSPERITY → DISRUPTION → RECOVERY cycle)
##   Step 1: World Layer — static topology, no per-tick processing
##   Step 2: Grid Layer — qualitative CA tag transitions
##   Step 3: Bridge Systems — cross-layer tag refresh (affinity-derived)
##   Step 4: Agent Layer — NPC goal evaluation and action execution
##   Step 5: Chronicle Layer — event capture and rumor generation
##
## Python reference: python_sandbox/core/simulation/simulation_engine.py


# =============================================================================
# === LAYER PROCESSOR REFERENCES ==============================================
# =============================================================================

var world_layer: Reference = null
var grid_layer: Reference = null
var agent_layer: Reference = null
var bridge_systems: Reference = null
var chronicle_layer: Reference = null
var affinity_matrix: Reference = null

## Whether the simulation has been initialized.
var _initialized: bool = false

## Config dictionary passed to all layer processors each tick.
var _tick_config: Dictionary = {}


# =============================================================================
# === LIFECYCLE ===============================================================
# =============================================================================

func _ready() -> void:
	# Load scripts
	var AffinityMatrixScript = load("res://src/core/simulation/affinity_matrix.gd")
	var WorldLayerScript = load("res://src/core/simulation/world_layer.gd")
	var GridLayerScript = load("res://src/core/simulation/grid_layer.gd")
	var AgentLayerScript = load("res://src/core/simulation/agent_layer.gd")
	var BridgeSystemsScript = load("res://src/core/simulation/bridge_systems.gd")
	var ChronicleLayerScript = load("res://src/core/simulation/chronicle_layer.gd")

	# Instantiate processors
	affinity_matrix = AffinityMatrixScript.new()
	world_layer = WorldLayerScript.new()
	grid_layer = GridLayerScript.new()
	agent_layer = AgentLayerScript.new()
	bridge_systems = BridgeSystemsScript.new()
	chronicle_layer = ChronicleLayerScript.new()

	# Wire shared dependencies
	agent_layer.affinity_matrix = affinity_matrix
	agent_layer.set_chronicle(chronicle_layer)
	bridge_systems.affinity_matrix = affinity_matrix

	# Build tick config
	_build_tick_config()

	# Register in GlobalRefs
	GlobalRefs.simulation_engine = self

	# Simulation ticks are event-driven (dock, undock, sector travel, debug).
	# Connect to gameplay events that trigger a tick.
	if not EventBus.is_connected("player_docked", self, "_on_player_docked"):
		EventBus.connect("player_docked", self, "_on_player_docked")
	if not EventBus.is_connected("player_undocked", self, "_on_player_undocked"):
		EventBus.connect("player_undocked", self, "_on_player_undocked")

	print("SimulationEngine: Ready. Awaiting initialize_simulation() call.")


func _exit_tree() -> void:
	if EventBus.is_connected("player_docked", self, "_on_player_docked"):
		EventBus.disconnect("player_docked", self, "_on_player_docked")
	if EventBus.is_connected("player_undocked", self, "_on_player_undocked"):
		EventBus.disconnect("player_undocked", self, "_on_player_undocked")
	GlobalRefs.simulation_engine = null


# =============================================================================
# === INITIALIZATION ==========================================================
# =============================================================================

## Initializes the full simulation from a seed string.
## Must be called once before any ticks are processed.
func initialize_simulation(seed_string: String) -> void:
	print("SimulationEngine: Initializing simulation with seed '%s'..." % seed_string)

	# Step 1: World Layer — build static topology and hazards from templates
	world_layer.initialize_world(seed_string)

	# Step 2: Grid Layer — seed dynamic tag-state from world data
	grid_layer.initialize_grid()

	# Step 3: Agent Layer — seed agents from templates
	agent_layer.initialize_agents()

	# Initialize world-age cycle
	GameState.world_age = Constants.WORLD_AGE_CYCLE[0]
	GameState.world_age_timer = Constants.WORLD_AGE_DURATIONS[GameState.world_age]
	GameState.world_age_cycle_count = 0
	_apply_age_config()

	_initialized = true

	# Emit initialization signal
	EventBus.emit_signal("sim_initialized", seed_string)

	print("SimulationEngine: Initialization complete. World-age: %s, Tick: %d" % [
		GameState.world_age,
		GameState.sim_tick_count
	])


# =============================================================================
# === TICK PROCESSING =========================================================
# =============================================================================

## Signal handler: called when player docks at a station.
func _on_player_docked(_location_id) -> void:
	request_tick()


## Signal handler: called when player undocks from a station.
func _on_player_undocked() -> void:
	request_tick()


## Public API: Requests one simulation tick. Called by gameplay events
## (dock, undock, sector travel, debug button) rather than a timer.
func request_tick() -> void:
	if not _initialized:
		push_warning("SimulationEngine: Tick requested but simulation not initialized.")
		return
	process_tick()


## Processes one full simulation tick through all layers.
func process_tick() -> void:
	GameState.sim_tick_count += 1

	# --- Step 0: World-Age Advance ---
	_advance_world_age()

	# --- Step 1: World Layer (static — no per-tick processing) ---

	# --- Step 2: Grid Layer ---
	grid_layer.process_tick(_tick_config)

	# --- Step 3: Bridge Systems ---
	bridge_systems.process_tick(_tick_config)

	# --- Step 4: Agent Layer ---
	agent_layer.process_tick(_tick_config)

	# --- Step 5: Chronicle Layer ---
	chronicle_layer.process_tick()

	# Emit tick-completed signal
	EventBus.emit_signal("sim_tick_completed", GameState.sim_tick_count)


## Advances the simulation by the given number of sub-ticks.
## Sub-ticks accumulate in GameState.sub_tick_accumulator. When the
## accumulator reaches SUB_TICKS_PER_TICK, one full tick fires.
## Returns the number of full ticks that were processed.
func advance_sub_ticks(cost: int) -> int:
	if not _initialized:
		push_warning("SimulationEngine: advance_sub_ticks() called but not initialized.")
		return 0

	GameState.sub_tick_accumulator += cost
	var ticks_fired: int = 0
	var threshold: int = Constants.SUB_TICKS_PER_TICK

	while GameState.sub_tick_accumulator >= threshold:
		GameState.sub_tick_accumulator -= threshold
		process_tick()
		ticks_fired += 1

	return ticks_fired


# =============================================================================
# === WORLD-AGE CYCLE =========================================================
# =============================================================================

## Advances the world-age timer and transitions to the next age when due.
func _advance_world_age() -> void:
	GameState.world_age_timer -= 1
	if GameState.world_age_timer > 0:
		return

	var cycle: Array = Constants.WORLD_AGE_CYCLE
	var index: int = cycle.find(GameState.world_age)
	var next_index: int = (index + 1) % cycle.size()

	if next_index == 0:
		GameState.world_age_cycle_count += 1

	GameState.world_age = cycle[next_index]
	GameState.world_age_timer = Constants.WORLD_AGE_DURATIONS[GameState.world_age]
	_apply_age_config()

	# Log the transition
	chronicle_layer.log_event({
		"tick": GameState.sim_tick_count,
		"actor_id": "world",
		"action": "age_change",
		"sector_id": "",
		"metadata": {"new_age": GameState.world_age},
	})

	EventBus.emit_signal("world_age_changed", GameState.world_age)


## Applies any age-specific config overrides on top of the base config.
func _apply_age_config() -> void:
	_build_tick_config()
	var age_overrides: Dictionary = Constants.WORLD_AGE_CONFIGS.get(GameState.world_age, {})
	for key in age_overrides:
		_tick_config[key] = age_overrides[key]


# =============================================================================
# === TICK CONFIG =============================================================
# =============================================================================

## Builds the config dictionary from Constants.gd values.
func _build_tick_config() -> void:
	_tick_config = {
		"colony_upgrade_ticks_required": Constants.COLONY_UPGRADE_TICKS_REQUIRED,
		"colony_downgrade_ticks_required": Constants.COLONY_DOWNGRADE_TICKS_REQUIRED,
		"respawn_cooldown_ticks": Constants.RESPAWN_COOLDOWN_TICKS,
		"catastrophe_chance_per_tick": Constants.CATASTROPHE_CHANCE_PER_TICK,
		"catastrophe_disable_duration": Constants.CATASTROPHE_DISABLE_DURATION,
		"mortal_global_cap": Constants.MORTAL_GLOBAL_CAP,
		"mortal_spawn_required_security": Array(Constants.MORTAL_SPAWN_REQUIRED_SECURITY),
		"mortal_spawn_blocked_sector_tags": Array(Constants.MORTAL_SPAWN_BLOCKED_SECTOR_TAGS),
	}


# =============================================================================
# === PUBLIC UTILITY ==========================================================
# =============================================================================

## Returns the chronicle_layer reference so other systems can call log_event().
func get_chronicle() -> Reference:
	return chronicle_layer


## Returns whether the simulation has been initialized.
func is_initialized() -> bool:
	return _initialized


## Runs `tick_count` ticks and returns a chronicle-style narrative report.
## Events are grouped into epochs of `epoch_size` ticks (default 1 for small
## runs, increase for large runs like 300/3000).
func run_batch_and_report(tick_count: int, epoch_size: int = 1) -> String:
	if not _initialized:
		push_warning("SimulationEngine: run_batch_and_report() called but not initialized.")
		return "(simulation not initialized)"
	var ReportScript = load("res://src/core/simulation/simulation_report.gd")
	var report: Reference = ReportScript.new()
	return report.run_and_report(self, tick_count, epoch_size)


## Allows runtime config overrides for tuning/debugging.
func set_config(key: String, value) -> void:
	_tick_config[key] = value


## Returns the current tick config for inspection.
func get_config() -> Dictionary:
	return _tick_config
