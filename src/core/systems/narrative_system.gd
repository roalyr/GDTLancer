# PROJECT: GDTLancer
# MODULE: narrative_system.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: GDD-MASTER-DESIGN-DIRECTIVE.md §2.2, §7.4; TRUTH_GAME-LOOP-VISION.md §5.2
# LOG_REF: 2026-06-22 01:10:00

extends Reference
class_name NarrativeSystem

## NarrativeSystem: Resolves hand-authored narrative templates (.tres) from local sector tags.
##
## This replaces procedural/LLM-generated text with deterministic, grid-driven lookup.

const BASE_PATH = "res://database/registry/narrative_templates"

## Resolves a template based on a sector ID and event type, query-lookup compatible.
func resolve_narrative_template(sector_id: String, event_type: String) -> Resource:
	var sector_type = "star"
	if GameState.world_topology.has(sector_id):
		var topo = GameState.world_topology[sector_id]
		if topo.has("sector_type"):
			sector_type = topo["sector_type"]
			
	var economy_tag = "default"
	if GameState.sector_tags.has(sector_id):
		for tag in GameState.sector_tags[sector_id]:
			if tag.begins_with("RAW_") or tag.begins_with("MANUFACTURED_") or tag.begins_with("CURRENCY_"):
				economy_tag = tag
				break
				
	var security_tag = "default"
	if GameState.sector_tags.has(sector_id):
		for tag in ["SECURE", "CONTESTED", "LAWLESS"]:
			if tag in GameState.sector_tags[sector_id]:
				security_tag = tag
				break
				
	return query_template(sector_type, economy_tag, security_tag, event_type)


## Queries templates using explicit tags, resolving with hierarchical fallbacks.
func query_template(sector_type: String, economy_tag: String, security_tag: String, event_type: String) -> Resource:
	# Try 1: Full path
	var path1 = "%s/%s/%s/%s/%s.tres" % [BASE_PATH, sector_type, economy_tag, security_tag, event_type]
	var res = _safe_load_narrative(path1)
	if res != null:
		return res
		
	# Try 2: Replace event_type with "default"
	var path2 = "%s/%s/%s/%s/default.tres" % [BASE_PATH, sector_type, economy_tag, security_tag]
	res = _safe_load_narrative(path2)
	if res != null:
		return res
		
	# Try 3: Replace security_tag with "default"
	var path3 = "%s/%s/%s/default/default.tres" % [BASE_PATH, sector_type, economy_tag]
	res = _safe_load_narrative(path3)
	if res != null:
		return res
		
	# Try 4: Coarser sector default
	var path4 = "%s/%s/default.tres" % [BASE_PATH, sector_type]
	res = _safe_load_narrative(path4)
	if res != null:
		return res
		
	# Try 5: Global default
	var path5 = "%s/default.tres" % BASE_PATH
	res = _safe_load_narrative(path5)
	if res != null:
		return res
		
	# Fallback code-driven resource
	var fallback_res = load("res://database/definitions/narrative_template.gd").new()
	fallback_res.title = "Local Transmission"
	fallback_res.body_text = "Static interference on the local frequency. The sector is quiet."
	fallback_res.creole_dialect = "Standard"
	return fallback_res


func _safe_load_narrative(path: String) -> Resource:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Resource:
			return res
	return null
