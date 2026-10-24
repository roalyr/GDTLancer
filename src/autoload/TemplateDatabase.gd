# TemplateDatabase: data templates indexed from database/registry/, keyed by template_id.

extends Node

# Dictionaries to hold loaded templates, keyed by their template_id.
var agents: Dictionary = {}
var assets_ships: Dictionary = {}
var assets_modules: Dictionary = {}
var assets_commodities: Dictionary = {}  # Salvage cargo
var locations: Dictionary = {}
var utility_tools: Dictionary = {}  # Weapons and other utility tools
var game_starts: Dictionary = {}


# Generic getter that searches all template categories
func get_template(template_id: String) -> Resource:
	for category in [assets_ships, assets_modules, assets_commodities, locations, utility_tools, agents, game_starts]:
		if category.has(template_id):
			return category[template_id]
	return null


# --- Sector graph (static, read from LocationTemplates) ---
# Uses get() so plain Dictionary stand-ins (as in tests) work too.

func has_sector(sector_id: String) -> bool:
	return sector_id != "" and locations.has(sector_id)


func get_sector_connections(sector_id: String) -> Array:
	var connections: Array = []
	var template = locations.get(sector_id)
	if template == null or template.get("connections") == null:
		return connections
	for target_sector_id in template.get("connections"):
		connections.append(str(target_sector_id))
	return connections


func get_sector_type(sector_id: String, fallback: String = "system") -> String:
	var template = locations.get(sector_id)
	if template != null and template.get("sector_type") != null and str(template.get("sector_type")) != "":
		return str(template.get("sector_type"))
	return fallback
