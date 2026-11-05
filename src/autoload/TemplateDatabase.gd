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
var evolved: Dictionary = {}  # Ships and parts built from genes at runtime (Evolution); not sold at stations
var presets: Dictionary = {}  # Evolved designs exported to database/presets/ (ships, tools, modules): sold at the home station only
var preset_agents: Dictionary = {}  # Preset ship id -> its AgentTemplate (behaviour, classification); nothing spawns from these yet
var factions: Dictionary setget _set_factions, _get_factions  # Faction id -> FactionTemplate.to_spec(), from Constants.FACTIONS_DIR (loaded on first use)
var _factions: Dictionary = {}
var sector_layouts: Dictionary setget _set_sector_layouts, _get_sector_layouts  # Sector id -> SectorLayoutTemplate.to_spec(), from Constants.SECTORS_DIR (loaded on first use)
var _sector_layouts: Dictionary = {}
var proven_presets: Dictionary = {}  # Preset ship ids from a *_min10 folder: designs that flew 10 lives or more


func _get_factions() -> Dictionary:
	if _factions.empty():
		var dir := Directory.new()
		if dir.open(Constants.FACTIONS_DIR) == OK:
			dir.list_dir_begin(true, true)
			var file_name: String = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres"):
					var faction = load(Constants.FACTIONS_DIR.plus_file(file_name))
					if faction is FactionTemplate and faction.template_id != "":
						_factions[faction.template_id] = faction.to_spec()
				file_name = dir.get_next()
	return _factions


func _set_factions(_value) -> void:
	pass  # Read from the faction files only


func _get_sector_layouts() -> Dictionary:
	if _sector_layouts.empty():
		var dir := Directory.new()
		if dir.open(Constants.SECTORS_DIR) == OK:
			dir.list_dir_begin(true, true)
			var file_name: String = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres"):
					var layout = load(Constants.SECTORS_DIR.plus_file(file_name))
					if layout is SectorLayoutTemplate and layout.template_id != "":
						_sector_layouts[layout.template_id] = layout.to_spec()
				file_name = dir.get_next()
	return _sector_layouts


func _set_sector_layouts(_value) -> void:
	pass  # Read from the sector files only


func register_evolved(template: Resource) -> void:
	evolved[template.template_id] = template


# Generic getter that searches all template categories
func get_template(template_id: String) -> Resource:
	for category in [assets_ships, assets_modules, assets_commodities, locations, utility_tools, agents, game_starts, evolved, presets]:
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
