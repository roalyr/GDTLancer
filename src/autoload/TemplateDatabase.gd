# PROJECT: GDTLancer
# MODULE: TemplateDatabase.gd
# STATUS: [Level 2 - Implementation]
# OWNER: architect-governed
# ACCESS: read-write
# USER INSTRUCTION: NONE
# TRUTH_LINK: None
# LOG_REF: 2026-06-20 18:41:40

# File: autoload/TemplateDatabase.gd
# Autoload Singleton: Scanned templates from /data/ are indexed and stored here
# Version: 1.3 - Added utility_tools dictionary and get_template method

extends Node

# Dictionaries to hold loaded templates, keyed by their template_id.
var actions: Dictionary = {}
var agents: Dictionary = {}
var characters: Dictionary = {}
var assets_ships: Dictionary = {}
var assets_modules: Dictionary = {}
var assets_commodities: Dictionary = {}
var locations: Dictionary = {}
var contracts: Dictionary = {}
var utility_tools: Dictionary = {}  # Weapons and other utility tools
var factions: Dictionary = {}
var contacts: Dictionary = {}
var narratives: Dictionary = {}
var game_starts: Dictionary = {}


# Generic getter that searches all template categories
func get_template(template_id: String) -> Resource:
	if characters.has(template_id):
		return characters[template_id]
	if narratives.has(template_id):
		return narratives[template_id]
	if factions.has(template_id):
		return factions[template_id]
	if contacts.has(template_id):

		return contacts[template_id]
	if assets_ships.has(template_id):
		return assets_ships[template_id]
	if assets_modules.has(template_id):
		return assets_modules[template_id]
	if assets_commodities.has(template_id):
		return assets_commodities[template_id]
	if locations.has(template_id):
		return locations[template_id]
	if contracts.has(template_id):
		return contracts[template_id]
	if utility_tools.has(template_id):
		return utility_tools[template_id]
	if agents.has(template_id):
		return agents[template_id]
	if actions.has(template_id):
		return actions[template_id]
	if game_starts.has(template_id):
		return game_starts[template_id]
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


func get_sector_type(sector_id: String, fallback: String = "star") -> String:
	var template = locations.get(sector_id)
	if template != null and template.get("sector_type") != null and str(template.get("sector_type")) != "":
		return str(template.get("sector_type"))
	return fallback
