#
# PROJECT: GDTLancer
# MODULE: sector_info_panel.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT §7 Assets & Style Guide (UI: functional, monochromatic)
# LOG_REF: 2026-03-21
#

extends Control

## SectorInfoPanel: Compact BBCode strip displaying current sector status.
## Shows sector name, economy/security/environment tags, colony level,
## and world age with tick counter. Refreshes on sim_tick_completed via MainHUD.

# --- Color Constants (hex for BBCode) ---
const COLOR_GREEN := "55ff55"
const COLOR_YELLOW := "ffff55"
const COLOR_RED := "ff5555"
const COLOR_CYAN := "55ffff"
const COLOR_WHITE := "ffffff"

# --- Node References ---
onready var info_label: RichTextLabel = $PanelBg/InfoLabel


func _ready() -> void:
	info_label.bbcode_text = "Awaiting sensor data..."


func refresh(contact_manager) -> void:
	var info: Dictionary = contact_manager.get_current_sector_info()
	if info.empty() or info.get("sector_id", "") == "":
		info_label.bbcode_text = "Awaiting sensor data..."
		return

	var line1 := "[b]%s[/b]  Econ: %s  Sec: %s  Env: %s" % [
		info.get("name", "Unknown"),
		_format_economy_tags(info.get("economy_tags", [])),
		_color_security(info.get("security_tag", "UNKNOWN")),
		_color_environment(info.get("environment_tag", "UNKNOWN")),
	]

	var line2 := "Colony: %s  Age: %s (tick %d)" % [
		_color_colony(info.get("colony_level", "frontier")),
		_color_world_age(info.get("world_age", "")),
		info.get("sim_tick_count", 0),
	]

	info_label.bbcode_text = line1 + "\n" + line2


func _format_economy_tags(tags: Array) -> String:
	if tags.empty():
		return "[color=#%s]none[/color]" % COLOR_WHITE
	var parts := []
	for tag in tags:
		parts.append("[color=#%s]%s[/color]" % [_economy_color(tag), tag])
	return " ".join(parts)


func _economy_color(tag: String) -> String:
	if tag.ends_with("_RICH"):
		return COLOR_GREEN
	elif tag.ends_with("_ADEQUATE"):
		return COLOR_YELLOW
	elif tag.ends_with("_POOR"):
		return COLOR_RED
	return COLOR_WHITE


func _color_security(tag: String) -> String:
	var color: String
	match tag:
		"SECURE":
			color = COLOR_GREEN
		"CONTESTED":
			color = COLOR_YELLOW
		"LAWLESS":
			color = COLOR_RED
		_:
			color = COLOR_WHITE
	return "[color=#%s]%s[/color]" % [color, tag]


func _color_environment(tag: String) -> String:
	var color: String
	match tag:
		"MILD":
			color = COLOR_GREEN
		"HARSH":
			color = COLOR_YELLOW
		"EXTREME":
			color = COLOR_RED
		_:
			color = COLOR_WHITE
	return "[color=#%s]%s[/color]" % [color, tag]


func _color_colony(level: String) -> String:
	var color: String
	match level:
		"hub":
			color = COLOR_CYAN
		"colony":
			color = COLOR_GREEN
		"outpost":
			color = COLOR_YELLOW
		_:
			color = COLOR_WHITE
	return "[color=#%s]%s[/color]" % [color, level]


func _color_world_age(age: String) -> String:
	var color: String
	match age:
		"PROSPERITY":
			color = COLOR_GREEN
		"DISRUPTION":
			color = COLOR_RED
		"RECOVERY":
			color = COLOR_YELLOW
		_:
			color = COLOR_WHITE
	return "[color=#%s]%s[/color]" % [color, age]
