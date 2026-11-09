# StepCache: a scene group's members fetched once per physics step and shared by every caller in
# that step (get_nodes_in_group builds a new array on each call: with every round in flight and
# every weapon looking each step, that was a crowded fight's waste). Only within a physics step
# of the game world (WorldManager turns it on as a zone loads; unit tests, which GUT runs inside
# physics steps and change things between looks, see everything fresh); anywhere else the group
# is fetched fresh. Agent.get_signature and ToolController._hold go by active() too. A member freed during the step is still listed: callers check is_instance_valid.
# One spawned during the step is seen from the next.

extends Reference

const _CACHE := {}  # Group name -> [physics frame, Array]
const _STATE := {"on": false}


static func set_active(on: bool) -> void:
	_STATE.on = on
	_CACHE.clear()


# Within a physics step of the game world: per-step caching applies.
static func active() -> bool:
	return _STATE.on and Engine.is_in_physics_frame()


static func group(tree: SceneTree, name: String) -> Array:
	if not active():
		return tree.get_nodes_in_group(name)
	var frame: int = Engine.get_physics_frames()
	var entry = _CACHE.get(name)
	if entry == null or entry[0] != frame:
		entry = [frame, tree.get_nodes_in_group(name)]
		_CACHE[name] = entry
	return entry[1]
