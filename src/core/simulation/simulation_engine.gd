# PROJECT: GDTLancer
# MODULE: simulation_engine.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: gameplay_milestone_audit.md
# LOG_REF: 2026-06-12 23:00:00

extends Node

## SimulationEngine: Qualitative tick orchestrator for the tag-based simulation.
##
## Manages the full tick sequence:
##   Step 0: Advance World-Age (PROSPERITY → DISRUPTION → RECOVERY cycle)
##   Step 1: World Layer — static topology, no per-tick processing
##   Step 2: Grid Layer — qualitative CA tag transitions
##   Step 3: Bridge Systems — cross-layer tag refresh (affinity-derived)
##   Step 4: Contract Generation — runtime qualitative occurrence refresh
##   Step 5: Agent Layer — NPC goal evaluation and action execution
##   Step 6: Chronicle Layer — event capture and rumor generation
##
## Python reference: python_sandbox/core/simulation/simulation_engine.py


# =============================================================================
# === LAYER PROCESSOR REFERENCES ==============================================
# =============================================================================

var world_layer: Reference = null
var grid_layer: Reference = null
var agent_layer: Reference = null
var bridge_systems: Reference = null
var contract_generation_system: Reference = null
var chronicle_layer: Reference = null
var affinity_matrix: Reference = null

## Whether the simulation has been initialized.
var _initialized: bool = false

## Config dictionary passed to all layer processors each tick.
var _tick_config: Dictionary = {}

const CONTINUOUS_RAW_STREAM_TICKS_PER_FRAME := 1

var _silent_raw_stream_active: bool = false
var _silent_raw_stream_logger: Reference = null


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
	var ContractGenerationSystemScript = load("res://src/core/simulation/contract_generation_system.gd")
	var ChronicleLayerScript = load("res://src/core/simulation/chronicle_layer.gd")

	# Instantiate processors
	affinity_matrix = AffinityMatrixScript.new()
	world_layer = WorldLayerScript.new()
	grid_layer = GridLayerScript.new()
	agent_layer = AgentLayerScript.new()
	bridge_systems = BridgeSystemsScript.new()
	contract_generation_system = ContractGenerationSystemScript.new()
	chronicle_layer = ChronicleLayerScript.new()

	# Wire shared dependencies
	agent_layer.affinity_matrix = affinity_matrix
	agent_layer.set_chronicle(chronicle_layer)
	bridge_systems.affinity_matrix = affinity_matrix

	# Build tick config
	_build_tick_config()
	set_process(false)

	# Register in GlobalRefs
	GlobalRefs.simulation_engine = self

	# NOTE: GDD REVISION - Dock/undock event connections. In the upcoming revision,
	# dock/undock will no longer produce simulation ticks. Instead, a unified delay-based
	# ticking mechanism (e.g., every 10 minutes of game time) is planned.
	if not EventBus.is_connected("player_docked", self, "_on_player_docked"):
		EventBus.connect("player_docked", self, "_on_player_docked")
	if not EventBus.is_connected("player_undocked", self, "_on_player_undocked"):
		EventBus.connect("player_undocked", self, "_on_player_undocked")

	if Constants.VERBOSE_RUNTIME_LOGS:
		print("SimulationEngine: Ready. Awaiting initialize_simulation() call.")


func _exit_tree() -> void:
	_stop_silent_raw_stream()
	if EventBus.is_connected("player_docked", self, "_on_player_docked"):
		EventBus.disconnect("player_docked", self, "_on_player_docked")
	if EventBus.is_connected("player_undocked", self, "_on_player_undocked"):
		EventBus.disconnect("player_undocked", self, "_on_player_undocked")
	GlobalRefs.simulation_engine = null


func _process(_delta: float) -> void:
	if not _silent_raw_stream_active or _silent_raw_stream_logger == null:
		return
	for _tick_index in range(CONTINUOUS_RAW_STREAM_TICKS_PER_FRAME):
		process_tick()
		_silent_raw_stream_logger.log_continuous_tick(self)


# =============================================================================
# === INITIALIZATION ==========================================================
# =============================================================================

## Initializes the full simulation from a seed string.
## Must be called once before any ticks are processed.
func initialize_simulation(seed_string: String) -> void:
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("SimulationEngine: Initializing simulation with seed '%s'..." % seed_string)

	# Step 1: World Layer — build static topology and hazards from templates
	world_layer.initialize_world(seed_string)

	# Step 2: Grid Layer — seed dynamic tag-state from world data
	grid_layer.initialize_grid()

	# Step 3: Agent Layer — seed agents from templates
	agent_layer.initialize_agents()
	GameState.runtime_contract_occurrences.clear()
	GameState.runtime_contract_occurrences_by_target_sector.clear()
	GameState.runtime_contract_occurrences_by_source_sector.clear()

	# Initialize world-age cycle
	GameState.world_age = Constants.WORLD_AGE_CYCLE[0]
	GameState.world_age_timer = Constants.WORLD_AGE_DURATIONS[GameState.world_age]
	GameState.world_age_cycle_count = 0
	_apply_age_config()
	_seed_initial_runtime_contract_occurrences()

	_initialized = true

	# Emit initialization signal
	EventBus.emit_signal("sim_initialized", seed_string)

	if Constants.VERBOSE_RUNTIME_LOGS:
		print("SimulationEngine: Initialization complete. World-age: %s, Tick: %d" % [
			GameState.world_age,
			GameState.sim_tick_count
		])


func _seed_initial_runtime_contract_occurrences() -> void:
	if grid_layer != null and is_instance_valid(grid_layer) and grid_layer.has_method("seed_initial_contract_demand"):
		grid_layer.call("seed_initial_contract_demand")
	if contract_generation_system != null and is_instance_valid(contract_generation_system):
		contract_generation_system.process_tick(_tick_config)


# =============================================================================
# === TICK PROCESSING =========================================================
# =============================================================================

## Signal handler: called when player docks at a station.
## NOTE: GDD REVISION - This event-driven trigger is deprecated. Ticks will transition
## to a delay-based timer (e.g., 10-minute game time intervals).
func _on_player_docked(_location_id) -> void:
	request_tick()


## Signal handler: called when player undocks from a station.
## NOTE: GDD REVISION - This event-driven trigger is deprecated. Ticks will transition
## to a delay-based timer (e.g., 10-minute game time intervals).
func _on_player_undocked() -> void:
	request_tick()


## Public API: Requests one simulation tick. Called by gameplay events
## (dock, undock, sector travel, debug button) rather than a timer.
func request_tick() -> void:
	if not _initialized:
		push_warning("SimulationEngine: Tick requested but simulation not initialized.")
		return
	process_tick()


func player_accept_runtime_contract(occurrence_id: String) -> bool:
	if agent_layer == null or not is_instance_valid(agent_layer):
		return false
	if not agent_layer.has_method("player_accept_runtime_contract"):
		return false
	return bool(agent_layer.call("player_accept_runtime_contract", occurrence_id))


func player_pick_up_runtime_contract(occurrence_id: String) -> bool:
	if agent_layer == null or not is_instance_valid(agent_layer):
		return false
	if not agent_layer.has_method("player_pick_up_runtime_contract"):
		return false
	return bool(agent_layer.call("player_pick_up_runtime_contract", occurrence_id))


func player_complete_runtime_contract(occurrence_id: String) -> bool:
	if agent_layer == null or not is_instance_valid(agent_layer):
		return false
	if not agent_layer.has_method("player_complete_runtime_contract"):
		return false
	return bool(agent_layer.call("player_complete_runtime_contract", occurrence_id))


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

	# --- Step 4: Contract Generation ---
	contract_generation_system.process_tick(_tick_config)

	# --- Step 5: Agent Layer ---
	agent_layer.process_tick(_tick_config)
	if agent_layer.has_method("_tick_market_restock"):
		agent_layer._tick_market_restock()

	# --- Step 6: Chronicle Layer ---
	_call_process_tick(chronicle_layer, _tick_config)

	# Emit tick-completed signal
	EventBus.emit_signal("sim_tick_completed", GameState.sim_tick_count)


func _call_process_tick(layer: Object, config: Dictionary) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	if _process_tick_argument_count(layer) > 0:
		layer.call("process_tick", config)
		return
	layer.call("process_tick")


func _process_tick_argument_count(layer: Object) -> int:
	for method_info in layer.get_method_list():
		if str(method_info.get("name", "")) != "process_tick":
			continue
		return Array(method_info.get("args", [])).size()
	return 0


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
		"contract_occurrence_global_cap": Constants.CONTRACT_OCCURRENCE_GLOBAL_CAP,
		"contract_occurrence_per_sector_cap": Constants.CONTRACT_OCCURRENCE_PER_SECTOR_CAP,
		"contract_source_search_max_hops": Constants.CONTRACT_SOURCE_SEARCH_MAX_HOPS,
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
func run_batch_and_report(tick_count: int, epoch_size: int = 1, report_request: Dictionary = {}) -> String:
	if not _initialized:
		push_warning("SimulationEngine: run_batch_and_report() called but not initialized.")
		return "(simulation not initialized)"
	var ReportScript = load("res://src/core/simulation/simulation_report.gd")
	var report: Reference = ReportScript.new()
	return report.run_and_report(self, tick_count, epoch_size, report_request)


## Runs one cumulative research pass and emits bundled chronicle sections for
## each requested milestone (for example 30, 300, and 3000 ticks).
func run_composite_research_report(tick_counts: Array, composite_request: Dictionary = {}) -> String:
	if not _initialized:
		push_warning("SimulationEngine: run_composite_research_report() called but not initialized.")
		return "(simulation not initialized)"
	var ReportScript = load("res://src/core/simulation/simulation_report.gd")
	var report: Reference = ReportScript.new()
	return report.run_composite_report(self, tick_counts, composite_request)


## Runs `tick_count` ticks and emits a full JSON-lines snapshot stream to the
## console without taking over the Sim Debug Panel report view.
func run_silent_simulation_log(tick_count: int, log_request: Dictionary = {}) -> Dictionary:
	if not _initialized:
		push_warning("SimulationEngine: run_silent_simulation_log() called but not initialized.")
		return {
			"schema_id": "gdtlancer.sim_snapshot.v1",
			"run_id": "",
			"tick_start": GameState.sim_tick_count,
			"tick_end": GameState.sim_tick_count,
			"ticks_processed": 0,
			"record_count": 0,
		}
	var RawLoggerScript = load("res://src/core/simulation/simulation_raw_logger.gd")
	var raw_logger: Reference = RawLoggerScript.new()
	return raw_logger.run_and_log(self, tick_count, log_request)


## Starts an unbounded raw JSON-lines stream that advances the simulation
## continuously until the process exits or the engine is torn down.
func start_silent_raw_stream(log_request: Dictionary = {}) -> Dictionary:
	if not _initialized:
		push_warning("SimulationEngine: start_silent_raw_stream() called but not initialized.")
		return {
			"schema_id": "gdtlancer.sim_snapshot.v1",
			"run_id": "",
			"tick_start": GameState.sim_tick_count,
			"tick_end": GameState.sim_tick_count,
			"ticks_processed": 0,
			"record_count": 0,
			"stream_mode": "continuous",
			"active": false,
		}
	if _silent_raw_stream_active and _silent_raw_stream_logger != null:
		return _silent_raw_stream_logger.active_run_summary()
	var RawLoggerScript = load("res://src/core/simulation/simulation_raw_logger.gd")
	_silent_raw_stream_logger = RawLoggerScript.new()
	_silent_raw_stream_active = true
	set_process(true)
	return _silent_raw_stream_logger.begin_continuous_run(self, log_request)


func is_silent_raw_stream_active() -> bool:
	return _silent_raw_stream_active


func _stop_silent_raw_stream() -> Dictionary:
	if not _silent_raw_stream_active or _silent_raw_stream_logger == null:
		return {}
	_silent_raw_stream_active = false
	set_process(false)
	var summary: Dictionary = _silent_raw_stream_logger.finish_continuous_run(self)
	_silent_raw_stream_logger = null
	return summary


## Allows runtime config overrides for tuning/debugging.
func set_config(key: String, value) -> void:
	_tick_config[key] = value


## Returns the current tick config for inspection.
func get_config() -> Dictionary:
	return _tick_config