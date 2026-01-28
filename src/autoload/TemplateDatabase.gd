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


# Generic getter that searches all template categories
func get_template(template_id: String) -> Resource:
	if characters.has(template_id):
		return characters[template_id]
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
	return null
