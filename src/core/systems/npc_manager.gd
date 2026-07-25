# PROJECT: GDTLancer
# MODULE: npc_manager.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md
# LOG_REF: 2026-07-26 02:10:00

extends Node
class_name NPCManager

const BOND_NONE = "NONE"
const BOND_FRAGILE = "FRAGILE"
const BOND_STABLE = "STABLE"
const BOND_DEEP = "DEEP"

signal npc_registered(npc_id, data)
signal npc_bond_changed(npc_id, new_bond, modifier)
signal npc_tags_changed(npc_id, tags)
signal npc_status_changed(npc_id, flag, active)

func register_npc(npc_id: String, display_name: String, initial_bond: String = BOND_FRAGILE, tags: Array = [], status_flags: Array = [], sector_id: String = "") -> Dictionary:
	var record: Dictionary = {
		"npc_id": npc_id,
		"display_name": display_name,
		"bond_strength": initial_bond,
		"tags": tags.duplicate(),
		"status_flags": status_flags.duplicate(),
		"sector_id": sector_id
	}
	GameState.npc_data[npc_id] = record
	emit_signal("npc_registered", npc_id, record)
	return record

func get_npc(npc_id: String) -> Dictionary:
	return GameState.npc_data.get(npc_id, {})

func set_bond_strength(npc_id: String, bond_strength: String) -> void:
	if GameState.npc_data.has(npc_id):
		GameState.npc_data[npc_id]["bond_strength"] = bond_strength
		var mod = get_bond_modifier(npc_id)
		emit_signal("npc_bond_changed", npc_id, bond_strength, mod)

func get_bond_strength(npc_id: String) -> String:
	var npc = get_npc(npc_id)
	return npc.get("bond_strength", BOND_NONE)

func get_bond_modifier(npc_id: String) -> int:
	var bond = get_bond_strength(npc_id)
	match bond:
		BOND_FRAGILE:
			return 1
		BOND_STABLE:
			return 2
		BOND_DEEP:
			return 3
		_:
			return 0

func add_npc_tag(npc_id: String, tag: String) -> void:
	if GameState.npc_data.has(npc_id):
		var tags: Array = GameState.npc_data[npc_id].get("tags", [])
		if not tag in tags:
			tags.append(tag)
			GameState.npc_data[npc_id]["tags"] = tags
			emit_signal("npc_tags_changed", npc_id, tags)

func remove_npc_tag(npc_id: String, tag: String) -> void:
	if GameState.npc_data.has(npc_id):
		var tags: Array = GameState.npc_data[npc_id].get("tags", [])
		if tag in tags:
			tags.erase(tag)
			GameState.npc_data[npc_id]["tags"] = tags
			emit_signal("npc_tags_changed", npc_id, tags)

func get_npc_tags(npc_id: String) -> Array:
	var npc = get_npc(npc_id)
	return npc.get("tags", [])

func has_npc_tag(npc_id: String, tag: String) -> bool:
	return tag in get_npc_tags(npc_id)

func set_status_flag(npc_id: String, flag: String, active: bool = true) -> void:
	if GameState.npc_data.has(npc_id):
		var flags: Array = GameState.npc_data[npc_id].get("status_flags", [])
		if active and not flag in flags:
			flags.append(flag)
			GameState.npc_data[npc_id]["status_flags"] = flags
			emit_signal("npc_status_changed", npc_id, flag, true)
		elif not active and flag in flags:
			flags.erase(flag)
			GameState.npc_data[npc_id]["status_flags"] = flags
			emit_signal("npc_status_changed", npc_id, flag, false)

func has_status_flag(npc_id: String, flag: String) -> bool:
	var npc = get_npc(npc_id)
	var flags: Array = npc.get("status_flags", [])
	return flag in flags

func get_npcs_in_sector(sector_id: String) -> Array:
	var list: Array = []
	for npc_id in GameState.npc_data.keys():
		var npc = GameState.npc_data[npc_id]
		if npc.get("sector_id", "") == sector_id or sector_id == "":
			list.append(npc)
	return list
