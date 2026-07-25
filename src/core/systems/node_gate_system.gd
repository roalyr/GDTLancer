# PROJECT: GDTLancer
# MODULE: node_gate_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_EXPLORATION-PILLARS.md §4
# LOG_REF: 2026-07-26 02:15:00

extends Node
class_name NodeGateSystem

# Key: node_id (String), Value: Dictionary {required_asset_tag, required_sector_tag, description}
var gates: Dictionary = {}

func _ready() -> void:
	# Default outer-margin node gate registration (Dangling Carrot)
	register_gate("node_outer_margin_alpha", "outer_margin_pass", "", "Requires Outer Margin Nav-Pass Asset Card")
	register_gate("node_outer_margin_beta", "quantum_anchor", "", "Requires Quantum Anchor Asset Card")

func register_gate(node_id: String, required_asset_tag: String = "", required_sector_tag: String = "", description: String = "Locked Node") -> void:
	gates[node_id] = {
		"node_id": node_id,
		"required_asset_tag": required_asset_tag,
		"required_sector_tag": required_sector_tag,
		"description": description
	}

func is_node_locked(node_id: String, player_inventory: Array = []) -> bool:
	if not gates.has(node_id):
		return false

	var gate: Dictionary = gates[node_id]
	var req_card_tag: String = gate.get("required_asset_tag", "")
	var req_sector_tag: String = gate.get("required_sector_tag", "")

	# Check asset tag requirement
	if not req_card_tag.empty():
		var has_card = false
		for item in player_inventory:
			if item != null and item.has_method("has_tag") and item.has_tag(req_card_tag):
				has_card = true
				break
			elif item is Dictionary and item.get("tags", []).has(req_card_tag):
				has_card = true
				break
		if not has_card:
			return true

	# Check sector tag requirement
	if not req_sector_tag.empty():
		var tags = GameState.get_sector_tags(node_id)
		if not req_sector_tag in tags:
			return true

	return false

func get_lock_reason(node_id: String, player_inventory: Array = []) -> String:
	if not is_node_locked(node_id, player_inventory):
		return ""
	var gate: Dictionary = gates.get(node_id, {})
	return gate.get("description", "Node mechanically locked.")
