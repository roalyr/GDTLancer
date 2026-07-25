# PROJECT: GDTLancer
# MODULE: hook_generator.gd
# STATUS: [Level 2 - Implementation]
# OWNER: developer
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: TRUTH_GAME-LOOP-VISION.md §2
# LOG_REF: 2026-07-26 02:15:00

extends Node
class_name HookGenerator

signal hook_generated(sector_id, hook_dict)

func generate_hooks_for_sector(sector_id: String) -> Array:
	var hooks: Array = []
	var tracks: Dictionary = GameState.get_sector_tracks(sector_id)
	var tags: Array = GameState.get_sector_tags(sector_id)

	var stability = tracks.get("stability", 5)
	var resources = tracks.get("resources", 5)
	var security = tracks.get("security", 5)

	# Low track hooks
	if stability <= 3:
		var hook = {
			"hook_id": "hook_unrest_" + sector_id,
			"sector_id": sector_id,
			"type": "COMMUNITY_UNREST",
			"description": "Rising tensions among residents due to crumbling infrastructure.",
			"required_tag": "community_aid",
			"severity": "HIGH"
		}
		hooks.append(hook)
		emit_signal("hook_generated", sector_id, hook)

	if resources <= 3:
		var hook = {
			"hook_id": "hook_famine_" + sector_id,
			"sector_id": sector_id,
			"type": "RESOURCE_SHORTAGE",
			"description": "Urgent request for emergency grain and fuel shipments.",
			"required_tag": "supplies_delivery",
			"severity": "CRITICAL"
		}
		hooks.append(hook)
		emit_signal("hook_generated", sector_id, hook)

	if security <= 3:
		var hook = {
			"hook_id": "hook_raiders_" + sector_id,
			"sector_id": sector_id,
			"type": "OUTLAW_THREAT",
			"description": "Patrol vessels requested to secure trade corridors.",
			"required_tag": "escort_duty",
			"severity": "MEDIUM"
		}
		hooks.append(hook)
		emit_signal("hook_generated", sector_id, hook)

	# High track hooks (Opportunities)
	if resources >= 8:
		var hook = {
			"hook_id": "hook_surplus_" + sector_id,
			"sector_id": sector_id,
			"type": "RESOURCE_SURPLUS",
			"description": "Bountiful harvest available for low-cost trade.",
			"required_tag": "trade_permit",
			"severity": "OPPORTUNITY"
		}
		hooks.append(hook)
		emit_signal("hook_generated", sector_id, hook)

	# Tag-driven hooks
	for tag in tags:
		if tag == "anomalous_unrest":
			var hook = {
				"hook_id": "hook_anomaly_" + sector_id,
				"sector_id": sector_id,
				"type": "ANOMALY_INVESTIGATION",
				"description": "Unexplained spatial distortions reported near station perimeter.",
				"required_tag": "scientific_scanner",
				"severity": "HIGH"
			}
			hooks.append(hook)
			emit_signal("hook_generated", sector_id, hook)

	return hooks

func scan_all_sectors() -> Dictionary:
	var results: Dictionary = {}
	for sector_id in GameState.sector_tracks.keys():
		results[sector_id] = generate_hooks_for_sector(sector_id)
	return results
