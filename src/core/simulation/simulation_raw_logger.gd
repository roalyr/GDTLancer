# PROJECT: GDTLancer
# MODULE: simulation_raw_logger.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

#
# PROJECT: GDTLancer
# MODULE: simulation_raw_logger.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6.5; TACTICAL_TODO.md TASK_1
# LOG_REF: 2026-05-28 14:01:46
#

extends Reference

const SCHEMA_ID := "gdtlancer.sim_snapshot.v1"
const RECORD_RUN_STARTED := "run_started"
const RECORD_TICK_SNAPSHOT := "tick_snapshot"
const RECORD_RUN_FINISHED := "run_finished"
const STREAM_MODE_BOUNDED := "bounded"
const STREAM_MODE_CONTINUOUS := "continuous"

var _active_run_id: String = ""
var _active_tick_start: int = 0
var _active_ticks_processed: int = 0
var _active_record_count: int = 0
var _active_request: Dictionary = {}
var _active_stream_mode: String = ""


func run_and_log(engine, tick_count: int, log_request: Dictionary = {}) -> Dictionary:
	var requested_tick_count: int = max(1, tick_count)
	_begin_run(engine, requested_tick_count, log_request, STREAM_MODE_BOUNDED)
	for _tick_index in range(requested_tick_count):
		engine.process_tick()
		_emit_active_tick_record(engine)
	return _finish_run(engine)


func begin_continuous_run(engine, log_request: Dictionary = {}) -> Dictionary:
	if _active_run_id != "":
		return active_run_summary()
	return _begin_run(engine, null, log_request, STREAM_MODE_CONTINUOUS)


func log_continuous_tick(engine) -> Dictionary:
	return _emit_active_tick_record(engine)


func finish_continuous_run(engine) -> Dictionary:
	return _finish_run(engine)


func active_run_summary() -> Dictionary:
	return {
		"schema_id": SCHEMA_ID,
		"run_id": _active_run_id,
		"tick_start": _active_tick_start,
		"tick_end": GameState.sim_tick_count,
		"ticks_processed": _active_ticks_processed,
		"record_count": _active_record_count,
		"stream_mode": _active_stream_mode,
		"active": _active_run_id != "",
	}


func _begin_run(engine, tick_count_requested, log_request: Dictionary, stream_mode: String) -> Dictionary:
	_active_tick_start = GameState.sim_tick_count
	_active_ticks_processed = 0
	_active_record_count = 1
	_active_stream_mode = stream_mode
	_active_run_id = _build_run_id(_active_tick_start, tick_count_requested, stream_mode)
	_active_request = _normalize_request(log_request, tick_count_requested, stream_mode)
	_emit_record(_build_run_started_record(engine, _active_run_id, tick_count_requested, _active_tick_start, _active_request, stream_mode))
	return active_run_summary()


func _emit_active_tick_record(engine) -> Dictionary:
	if _active_run_id == "":
		return {}
	_active_ticks_processed += 1
	_active_record_count += 1
	var record: Dictionary = _build_tick_snapshot_record(engine, _active_run_id, _active_ticks_processed, _active_stream_mode)
	_emit_record(record)
	return record


func _finish_run(engine) -> Dictionary:
	if _active_run_id == "":
		return {
			"schema_id": SCHEMA_ID,
			"run_id": "",
			"tick_start": GameState.sim_tick_count,
			"tick_end": GameState.sim_tick_count,
			"ticks_processed": 0,
			"record_count": 0,
			"stream_mode": "",
			"active": false,
		}
	_active_record_count += 1
	_emit_record(_build_run_finished_record(engine, _active_run_id, _active_tick_start, _active_ticks_processed, _active_request, _active_stream_mode))
	var summary: Dictionary = active_run_summary()
	summary["active"] = false
	_clear_active_run()
	return summary


func _clear_active_run() -> void:
	_active_run_id = ""
	_active_tick_start = 0
	_active_ticks_processed = 0
	_active_record_count = 0
	_active_request = {}
	_active_stream_mode = ""


func _build_run_started_record(engine, run_id: String, tick_count_requested, tick_start: int, normalized_request: Dictionary, stream_mode: String = STREAM_MODE_BOUNDED) -> Dictionary:
	var schema_contract: Dictionary = {
		"stream_encoding": "jsonl",
		"stream_mode": stream_mode,
		"tick_record_type": RECORD_TICK_SNAPSHOT,
		"completion_record_type": RECORD_RUN_FINISHED,
		"completion_record_guarantee": "always" if stream_mode == STREAM_MODE_BOUNDED else "best_effort_on_graceful_shutdown",
		"game_state_source": "GameState.get_script().get_script_property_list()",
		"dictionary_keys": "stringified",
		"special_variant_marker": "__type",
	}
	var record: Dictionary = {
		"schema_id": SCHEMA_ID,
		"record_type": RECORD_RUN_STARTED,
		"run_id": run_id,
		"stream_mode": stream_mode,
		"world_seed": GameState.world_seed,
		"tick_start": tick_start,
		"request": normalized_request,
		"tick_config": _normalize_variant(_engine_config(engine)),
		"game_state_fields": _game_state_property_names(),
		"schema_contract": schema_contract,
	}
	record["tick_count_requested"] = int(tick_count_requested) if tick_count_requested != null else null
	return record


func _build_tick_snapshot_record(engine, run_id: String, tick_index: int, stream_mode: String = STREAM_MODE_BOUNDED) -> Dictionary:
	return {
		"schema_id": SCHEMA_ID,
		"record_type": RECORD_TICK_SNAPSHOT,
		"run_id": run_id,
		"stream_mode": stream_mode,
		"tick_index": tick_index,
		"sim_tick": GameState.sim_tick_count,
		"world_seed": GameState.world_seed,
		"tick_config": _normalize_variant(_engine_config(engine)),
		"game_state": _snapshot_game_state(),
	}


func _build_run_finished_record(engine, run_id: String, tick_start: int, tick_count: int, normalized_request: Dictionary, stream_mode: String = STREAM_MODE_BOUNDED) -> Dictionary:
	var record: Dictionary = {
		"schema_id": SCHEMA_ID,
		"record_type": RECORD_RUN_FINISHED,
		"run_id": run_id,
		"stream_mode": stream_mode,
		"world_seed": GameState.world_seed,
		"tick_start": tick_start,
		"tick_end": GameState.sim_tick_count,
		"ticks_processed": tick_count,
		"record_count": tick_count + 2,
		"request": normalized_request,
		"tick_config": _normalize_variant(_engine_config(engine)),
	}
	if stream_mode == STREAM_MODE_CONTINUOUS:
		record["completion_reason"] = "graceful_shutdown"
	return record


func _emit_record(record: Dictionary) -> void:
	print(to_json(record))


func _engine_config(engine) -> Dictionary:
	if engine != null and engine.has_method("get_config"):
		return engine.get_config()
	return {}


func _normalize_request(log_request: Dictionary, tick_count_requested = null, stream_mode: String = STREAM_MODE_BOUNDED) -> Dictionary:
	var normalized_request: Dictionary = log_request.duplicate(true)
	normalized_request["stream_mode"] = stream_mode
	if tick_count_requested != null:
		normalized_request["tick_count_requested"] = int(tick_count_requested)
	if not normalized_request.has("requested_by"):
		normalized_request["requested_by"] = "unknown"
	return _normalize_variant(normalized_request)


func _snapshot_game_state() -> Dictionary:
	var snapshot: Dictionary = {}
	for property_name in _game_state_property_names():
		snapshot[property_name] = _normalize_variant(GameState.get(property_name))
	return snapshot


func _game_state_property_names() -> Array:
	var property_names: Array = []
	if GameState == null or GameState.get_script() == null:
		return property_names
	for prop in GameState.get_script().get_script_property_list():
		var property_name: String = str(prop.get("name", ""))
		if property_name == "" or property_name == "script" or property_name.begins_with("_"):
			continue
		property_names.append(property_name)
	property_names.sort()
	return property_names


func _build_run_id(tick_start: int, tick_count_requested = null, stream_mode: String = STREAM_MODE_BOUNDED) -> String:
	if stream_mode == STREAM_MODE_CONTINUOUS or tick_count_requested == null:
		return "%s:%d:continuous" % [GameState.world_seed, tick_start]
	return "%s:%d:%d" % [GameState.world_seed, tick_start, int(tick_count_requested)]


func _normalize_variant(value):
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_REAL, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return {"__type": "Vector2", "x": value.x, "y": value.y}
		TYPE_RECT2:
			return {
				"__type": "Rect2",
				"position": _normalize_variant(value.position),
				"size": _normalize_variant(value.size),
			}
		TYPE_VECTOR3:
			return {"__type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
		TYPE_TRANSFORM2D:
			return {
				"__type": "Transform2D",
				"x": _normalize_variant(value.x),
				"y": _normalize_variant(value.y),
				"origin": _normalize_variant(value.origin),
			}
		TYPE_PLANE:
			return {"__type": "Plane", "normal": _normalize_variant(value.normal), "d": value.d}
		TYPE_QUAT:
			return {"__type": "Quat", "x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_AABB:
			return {
				"__type": "AABB",
				"position": _normalize_variant(value.position),
				"size": _normalize_variant(value.size),
			}
		TYPE_BASIS:
			return {
				"__type": "Basis",
				"x": _normalize_variant(value.x),
				"y": _normalize_variant(value.y),
				"z": _normalize_variant(value.z),
			}
		TYPE_TRANSFORM:
			return {
				"__type": "Transform",
				"basis": _normalize_variant(value.basis),
				"origin": _normalize_variant(value.origin),
			}
		TYPE_COLOR:
			return {"__type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_NODE_PATH:
			return {"__type": "NodePath", "path": str(value)}
		TYPE_RID:
			return {"__type": "RID", "id": str(value)}
		TYPE_OBJECT:
			return _normalize_object(value)
		TYPE_DICTIONARY:
			return _normalize_dictionary(value)
		TYPE_ARRAY:
			return _normalize_array(value)
		TYPE_RAW_ARRAY:
			return {"__type": "PoolByteArray", "items": _normalize_array(Array(value))}
		TYPE_INT_ARRAY:
			return {"__type": "PoolIntArray", "items": _normalize_array(Array(value))}
		TYPE_REAL_ARRAY:
			return {"__type": "PoolRealArray", "items": _normalize_array(Array(value))}
		TYPE_STRING_ARRAY:
			return {"__type": "PoolStringArray", "items": _normalize_array(Array(value))}
		TYPE_VECTOR2_ARRAY:
			return {"__type": "PoolVector2Array", "items": _normalize_array(Array(value))}
		TYPE_VECTOR3_ARRAY:
			return {"__type": "PoolVector3Array", "items": _normalize_array(Array(value))}
		TYPE_COLOR_ARRAY:
			return {"__type": "PoolColorArray", "items": _normalize_array(Array(value))}
		_:
			return {"__type": "VariantFallback", "variant_type": typeof(value), "string": str(value)}


func _normalize_dictionary(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	var keys: Array = []
	for key in value.keys():
		keys.append(key)
	keys.sort_custom(self, "_sort_variants_by_string")
	for key in keys:
		normalized[str(key)] = _normalize_variant(value[key])
	return normalized


func _normalize_array(value: Array) -> Array:
	var normalized: Array = []
	for item in value:
		normalized.append(_normalize_variant(item))
	return normalized


func _normalize_object(value):
	if value == null or not is_instance_valid(value):
		return null
	if value is Resource:
		return _normalize_resource(value)
	if value is Node:
		var node_data: Dictionary = {
			"__type": "Node",
			"class": value.get_class(),
			"instance_id": value.get_instance_id(),
			"name": str(value.name),
			"path": str(value.get_path()) if value.is_inside_tree() else "",
		}
		var node_script_path: String = _script_path(value)
		if node_script_path != "":
			node_data["script"] = node_script_path
		return node_data
	var object_data: Dictionary = {
		"__type": "Object",
		"class": value.get_class(),
		"instance_id": value.get_instance_id(),
	}
	var object_script_path: String = _script_path(value)
	if object_script_path != "":
		object_data["script"] = object_script_path
	return object_data


func _normalize_resource(value: Resource) -> Dictionary:
	var resource_data: Dictionary = {
		"__type": "Resource",
		"class": value.get_class(),
		"resource_path": str(value.resource_path),
		"properties": {},
	}
	var script_path: String = _script_path(value)
	if script_path != "":
		resource_data["script"] = script_path
	for property_name in _script_property_names_for_object(value):
		resource_data["properties"][property_name] = _normalize_variant(value.get(property_name))
	return resource_data


func _script_property_names_for_object(value) -> Array:
	var property_names: Array = []
	if value == null or not is_instance_valid(value):
		return property_names
	var script = value.get_script()
	if script == null:
		return property_names
	for prop in script.get_script_property_list():
		var property_name: String = str(prop.get("name", ""))
		if property_name == "" or property_name == "script" or property_name.begins_with("_"):
			continue
		property_names.append(property_name)
	property_names.sort()
	return property_names


func _script_path(value) -> String:
	if value == null or not is_instance_valid(value):
		return ""
	var script = value.get_script()
	if script == null:
		return ""
	return str(script.resource_path)


func _sort_variants_by_string(a, b) -> bool:
	return str(a) < str(b)