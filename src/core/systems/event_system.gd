## EventSystem: Combat tracking and encounter management (DISABLED — random spawns removed).
##
## Random encounter spawning is disabled. All NPCs come from the simulation.
## This system still tracks active hostiles and emits combat_initiated / combat_ended
## signals. The force_encounter() debug API remains available for testing.
extends Node

# --- Configuration (kept for future simulation-driven encounters) ---
const SPAWN_DISTANCE_MIN: float = 600.0
const SPAWN_DISTANCE_MAX: float = 1000.0

# --- State ---
var _active_hostiles: Array = []


## Initializes EventSystem and connects to EventBus signals.
func _ready() -> void:
	GlobalRefs.set_event_system(self)

	if EventBus:
		EventBus.connect("agent_disabled", self, "_on_agent_disabled")
		EventBus.connect("agent_despawning", self, "_on_agent_despawning")

	print("EventSystem Ready.")


## Handles agent disabled signal; removes from active hostiles and checks for combat end.
func _on_agent_disabled(agent_body: Node) -> void:
	if _active_hostiles.has(agent_body):
		_active_hostiles.erase(agent_body)
	_check_combat_end()


## Handles agent despawning signal; removes from active hostiles and checks for combat end.
func _on_agent_despawning(agent_body: Node) -> void:
	if _active_hostiles.has(agent_body):
		_active_hostiles.erase(agent_body)
	_check_combat_end()



## NOTE: Random encounter spawning is disabled. These methods are kept for
## future simulation-driven encounters where the simulation decides when/where
## hostiles appear, and this system handles the physical spawning.

## Spawns hostile NPCs at calculated positions and emits combat_initiated signal.
## Currently only callable via force_encounter() for debug.
func _spawn_hostile_encounter() -> void:
	var player: Node = GlobalRefs.player_agent_body
	if not is_instance_valid(player):
		return

	var spawner: Node = GlobalRefs.agent_spawner
	if not is_instance_valid(spawner) or not spawner.has_method("spawn_npc_from_template"):
		printerr("EventSystem: AgentSpawner missing spawn_npc_from_template().")
		return

	var player_pos: Vector3 = player.global_transform.origin
	var spawn_count: int = 1 + (randi() % 2)

	for _i in range(spawn_count):
		var spawn_pos: Vector3 = _calculate_spawn_position(player_pos)
		var overrides: Dictionary = {
			"agent_type": "npc",
			"template_id": "npc_hostile_default",
			"character_uid": -1,
			"hostile": true,
			"patrol_center": spawn_pos,
		}

		var npc: Node = spawner.spawn_npc_from_template(Constants.NPC_HOSTILE_TEMPLATE_PATH, spawn_pos, overrides)
		if is_instance_valid(npc):
			_active_hostiles.append(npc)

	_prune_invalid_hostiles()
	if not _active_hostiles.empty() and EventBus:
		EventBus.emit_signal("combat_initiated", player, _active_hostiles.duplicate())


## Calculates a random spawn position around the player within configured distance.
## Returns: Vector3 spawn position
func _calculate_spawn_position(player_pos: Vector3) -> Vector3:
	var angle: float = randf() * TAU
	var distance: float = rand_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
	var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * distance
	return player_pos + offset


## Checks if all hostiles are defeated and emits combat_ended signal if so.
func _check_combat_end() -> void:
	_prune_invalid_hostiles()
	if _active_hostiles.empty() and EventBus:
		EventBus.emit_signal("combat_ended", {"outcome": "victory", "hostiles_defeated": true})


## Removes invalid (freed) nodes from active hostiles array.
func _prune_invalid_hostiles() -> void:
	if _active_hostiles.empty():
		return
	var still_valid: Array = []
	for hostile in _active_hostiles:
		if is_instance_valid(hostile):
			still_valid.append(hostile)
	_active_hostiles = still_valid


# --- Public API ---

## Returns a copy of the current active hostiles array.
## Returns: Array of active hostile nodes
func get_active_hostiles() -> Array:
	_prune_invalid_hostiles()
	return _active_hostiles.duplicate()


## Immediately forces an encounter to spawn (for testing/debugging).
func force_encounter() -> void:
	_spawn_hostile_encounter()


## Clears all tracked hostiles from active list.
func clear_hostiles() -> void:
	_active_hostiles.clear()


## Cleanup on node deletion; disconnects signals and clears references.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if GlobalRefs and GlobalRefs.event_system == self:
			GlobalRefs.event_system = null
		if EventBus:
			if EventBus.is_connected("agent_disabled", self, "_on_agent_disabled"):
				EventBus.disconnect("agent_disabled", self, "_on_agent_disabled")
			if EventBus.is_connected("agent_despawning", self, "_on_agent_despawning"):
				EventBus.disconnect("agent_despawning", self, "_on_agent_despawning")
