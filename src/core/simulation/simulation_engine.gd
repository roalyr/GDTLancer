#
# PROJECT: GDTLancer
# MODULE: simulation_engine.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH-GDD-COMBINED-TEXT-MAJOR-CHANGE-frozen-2026.02.13.md Section 7 (Tick Sequence), Section 8 (Simulation Architecture)
# LOG_REF: 2026-02-13
#

extends Node

## SimulationEngine: Tick orchestrator for the four-layer simulation.
##
## Manages the full tick sequence (GDD Section 7):
##   Step 1: World Layer — static, no per-tick processing
##   Step 2: Grid Layer — CA-driven resource/dominion/market evolution
##   Step 3: Bridge Systems — cross-layer heat/entropy/knowledge
##   Step 4: Agent Layer — NPC goal evaluation and action execution
##   Step 5: Chronicle Layer — event capture and rumor generation
##   ASSERT: Conservation Axiom 1 — total matter unchanged
##
## This node is added to the scene tree under WorldManager. It listens to
## EventBus.world_event_tick_triggered to know when to process a tick.
## All layer processors are Reference objects (not Nodes) — no scene-tree coupling.


# =============================================================================
# === LAYER PROCESSOR REFERENCES ==============================================
# =============================================================================

var world_layer: Reference = null
var grid_layer: Reference = null
var agent_layer: Reference = null
var bridge_systems: Reference = null
var chronicle_layer: Reference = null
var ca_rules: Reference = null

## Whether the simulation has been initialized.
var _initialized: bool = false

## Config dictionary passed to all layer processors each tick.
## Built from Constants.gd values. Can be modified at runtime for tuning.
var _tick_config: Dictionary = {}


# =============================================================================
# === LIFECYCLE ===============================================================
# =============================================================================

func _ready() -> void:
	# Instantiate all layer processors
	var WorldLayerScript = load("res://src/core/simulation/world_layer.gd")
	var GridLayerScript = load("res://src/core/simulation/grid_layer.gd")
	var AgentLayerScript = load("res://src/core/simulation/agent_layer.gd")
	var BridgeSystemsScript = load("res://src/core/simulation/bridge_systems.gd")
	var ChronicleLayerScript = load("res://src/core/simulation/chronicle_layer.gd")
	var CARulesScript = load("res://src/core/simulation/ca_rules.gd")

	world_layer = WorldLayerScript.new()
	grid_layer = GridLayerScript.new()
	agent_layer = AgentLayerScript.new()
	bridge_systems = BridgeSystemsScript.new()
	chronicle_layer = ChronicleLayerScript.new()
	ca_rules = CARulesScript.new()

	# Inject ca_rules dependency into grid_layer
	grid_layer.ca_rules = ca_rules

	# Build tick config from Constants
	_build_tick_config()

	# Register in GlobalRefs
	GlobalRefs.simulation_engine = self

	# Connect to EventBus tick signal
	if not EventBus.is_connected("world_event_tick_triggered", self, "_on_world_event_tick_triggered"):
		EventBus.connect("world_event_tick_triggered", self, "_on_world_event_tick_triggered")

	print("SimulationEngine: Ready. Awaiting initialize_simulation() call.")


func _exit_tree() -> void:
	if EventBus.is_connected("world_event_tick_triggered", self, "_on_world_event_tick_triggered"):
		EventBus.disconnect("world_event_tick_triggered", self, "_on_world_event_tick_triggered")
	GlobalRefs.simulation_engine = null


# =============================================================================
# === INITIALIZATION ==========================================================
# =============================================================================

## Initializes the full simulation from a seed string.
## Must be called once before any ticks are processed.
##
## @param seed_string  String — deterministic world seed.
func initialize_simulation(seed_string: String) -> void:
	print("SimulationEngine: Initializing simulation with seed '%s'..." % seed_string)

	# Step 1: World Layer — build static topology, hazards, resource potential
	world_layer.initialize_world(seed_string)

	# Step 2: Grid Layer — seed dynamic state from world data + templates
	grid_layer.initialize_grid()

	# Step 3: Agent Layer — seed agents from templates
	agent_layer.initialize_agents()

	# Recalculate total matter across all layers for definitive Axiom 1 checksum
	world_layer.recalculate_total_matter()

	_initialized = true

	# Emit initialization signal
	EventBus.emit_signal("sim_initialized", seed_string)

	print("SimulationEngine: Initialization complete. Matter budget: %.2f, Tick: %d" % [
		GameState.world_total_matter,
		GameState.sim_tick_count
	])


# =============================================================================
# === TICK PROCESSING =========================================================
# =============================================================================

## Signal handler: called when TimeSystem emits world_event_tick_triggered.
func _on_world_event_tick_triggered(_seconds_amount) -> void:
	if not _initialized:
		push_warning("SimulationEngine: Tick triggered but simulation not initialized.")
		return
	process_tick()


## Processes one full simulation tick through all layers.
func process_tick() -> void:
	# Increment tick counter
	GameState.sim_tick_count += 1

	var tick: int = GameState.sim_tick_count

	# --- Step 1: World Layer (static — no processing) ---
	# World data is read-only after initialization.

	# --- Step 2: Grid Layer ---
	grid_layer.process_tick(_tick_config)

	# --- Step 3: Bridge Systems ---
	bridge_systems.process_tick(_tick_config)

	# --- Step 4: Agent Layer ---
	agent_layer.process_tick(_tick_config)

	# --- Step 5: Chronicle Layer ---
	chronicle_layer.process_tick()

	# --- ASSERT: Conservation Axiom 1 ---
	var is_conserved: bool = verify_matter_conservation()
	if not is_conserved:
		push_error("SimulationEngine: AXIOM 1 VIOLATION at tick %d!" % tick)

	# Emit tick-completed signal
	EventBus.emit_signal("sim_tick_completed", tick)


# =============================================================================
# === CONSERVATION AXIOM 1 ===================================================
# =============================================================================

## Verifies that total matter in the universe equals the initial checksum.
## Returns true if conservation holds, false if there is a violation.
func verify_matter_conservation() -> bool:
	var expected: float = GameState.world_total_matter
	var actual: float = _calculate_total_matter()
	var tolerance: float = _tick_config.get("axiom1_tolerance", 0.01)
	var drift: float = abs(actual - expected)

	if drift > tolerance:
		# Detailed breakdown for debugging
		var breakdown: Dictionary = _matter_breakdown()
		push_warning(
			"AXIOM 1 DRIFT: %.4f (expected: %.2f, actual: %.2f)\n" % [drift, expected, actual] +
			"  Resource potential: %.2f\n" % breakdown["resource_potential"] +
			"  Grid stockpiles: %.2f\n" % breakdown["grid_stockpiles"] +
			"  Wrecks: %.2f\n" % breakdown["wrecks"] +
			"  Agent inventories: %.2f" % breakdown["agent_inventories"]
		)
		return false

	return true


## Calculates current total matter across all layers.
func _calculate_total_matter() -> float:
	var total: float = 0.0

	# Layer 1: Resource potential (finite deposits)
	for sector_id in GameState.world_resource_potential:
		var potential: Dictionary = GameState.world_resource_potential[sector_id]
		total += potential.get("mineral_density", 0.0)
		total += potential.get("propellant_sources", 0.0)

	# Layer 2: Grid stockpiles
	for sector_id in GameState.grid_stockpiles:
		var stockpile: Dictionary = GameState.grid_stockpiles[sector_id]
		var commodities: Dictionary = stockpile.get("commodity_stockpiles", {})
		for commodity_id in commodities:
			total += float(commodities[commodity_id])

	# Layer 2: Wrecks
	for wreck_uid in GameState.grid_wrecks:
		var wreck: Dictionary = GameState.grid_wrecks[wreck_uid]
		var inventory: Dictionary = wreck.get("wreck_inventory", {})
		for item_id in inventory:
			total += float(inventory[item_id])
		total += 1.0  # Base hull mass

	# Layer 3: Agent inventories
	for char_uid in GameState.inventories:
		var inv: Dictionary = GameState.inventories[char_uid]
		if inv.has(2):  # InventoryType.COMMODITY
			var commodities: Dictionary = inv[2]
			for commodity_id in commodities:
				total += float(commodities[commodity_id])

	return total


## Returns a breakdown of matter by category for debugging.
func _matter_breakdown() -> Dictionary:
	var resource_potential: float = 0.0
	for sector_id in GameState.world_resource_potential:
		var potential: Dictionary = GameState.world_resource_potential[sector_id]
		resource_potential += potential.get("mineral_density", 0.0)
		resource_potential += potential.get("propellant_sources", 0.0)

	var grid_stockpiles: float = 0.0
	for sector_id in GameState.grid_stockpiles:
		var stockpile: Dictionary = GameState.grid_stockpiles[sector_id]
		var commodities: Dictionary = stockpile.get("commodity_stockpiles", {})
		for commodity_id in commodities:
			grid_stockpiles += float(commodities[commodity_id])

	var wrecks: float = 0.0
	for wreck_uid in GameState.grid_wrecks:
		var wreck: Dictionary = GameState.grid_wrecks[wreck_uid]
		var inventory: Dictionary = wreck.get("wreck_inventory", {})
		for item_id in inventory:
			wrecks += float(inventory[item_id])
		wrecks += 1.0

	var agent_inventories: float = 0.0
	for char_uid in GameState.inventories:
		var inv: Dictionary = GameState.inventories[char_uid]
		if inv.has(2):
			var commodities: Dictionary = inv[2]
			for commodity_id in commodities:
				agent_inventories += float(commodities[commodity_id])

	return {
		"resource_potential": resource_potential,
		"grid_stockpiles": grid_stockpiles,
		"wrecks": wrecks,
		"agent_inventories": agent_inventories
	}


# =============================================================================
# === TICK CONFIG =============================================================
# =============================================================================

## Builds the config dictionary from Constants.gd values.
## This is passed to all layer processors each tick.
func _build_tick_config() -> void:
	_tick_config = {
		# --- Grid CA Parameters ---
		"influence_propagation_rate": Constants.CA_INFLUENCE_PROPAGATION_RATE,
		"pirate_activity_decay": Constants.CA_PIRATE_ACTIVITY_DECAY,
		"pirate_activity_growth": Constants.CA_PIRATE_ACTIVITY_GROWTH,
		"stockpile_diffusion_rate": Constants.CA_STOCKPILE_DIFFUSION_RATE,
		"extraction_rate_default": Constants.CA_EXTRACTION_RATE_DEFAULT,
		"price_sensitivity": Constants.CA_PRICE_SENSITIVITY,
		"demand_base": Constants.CA_DEMAND_BASE,

		# --- Wreck / Entropy ---
		"wreck_degradation_per_tick": Constants.WRECK_DEGRADATION_PER_TICK,
		"wreck_debris_return_fraction": Constants.WRECK_DEBRIS_RETURN_FRACTION,
		"entropy_radiation_multiplier": Constants.ENTROPY_RADIATION_MULTIPLIER,
		"entropy_base_rate": Constants.ENTROPY_BASE_RATE,

		# --- Power ---
		"power_draw_per_agent": Constants.POWER_DRAW_PER_AGENT,
		"power_draw_per_service": Constants.POWER_DRAW_PER_SERVICE,

		# --- Bridge Systems ---
		"heat_generation_in_space": Constants.HEAT_GENERATION_IN_SPACE,
		"heat_dissipation_base": Constants.HEAT_DISSIPATION_DOCKED,
		"heat_overheat_threshold": Constants.HEAT_OVERHEAT_THRESHOLD,
		"entropy_hull_multiplier": Constants.ENTROPY_HULL_MULTIPLIER,
		"fleet_entropy_reduction": Constants.ENTROPY_FLEET_RATE_FRACTION,
		"propellant_drain_per_tick": Constants.PROPELLANT_DRAIN_PER_TICK,
		"energy_drain_per_tick": Constants.ENERGY_DRAIN_PER_TICK,
		"knowledge_noise_factor": Constants.AGENT_KNOWLEDGE_NOISE_FACTOR,

		# --- Agent Layer ---
		"npc_cash_low_threshold": Constants.NPC_CASH_LOW_THRESHOLD,
		"npc_hull_repair_threshold": Constants.NPC_HULL_REPAIR_THRESHOLD,
		"commodity_base_price": Constants.COMMODITY_BASE_PRICE,
		"world_tick_interval_seconds": float(Constants.WORLD_TICK_INTERVAL_SECONDS),
		"respawn_timeout_seconds": Constants.RESPAWN_TIMEOUT_SECONDS,
		"hostile_growth_rate": Constants.HOSTILE_GROWTH_RATE,

		# --- Axiom 1 ---
		"axiom1_tolerance": Constants.AXIOM1_TOLERANCE
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


## Allows runtime config overrides for tuning/debugging.
func set_config(key: String, value) -> void:
	_tick_config[key] = value


## Returns the current tick config for inspection.
func get_config() -> Dictionary:
	return _tick_config
