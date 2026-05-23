##
## PROJECT: GDTLancer
## MODULE: template_indexer.gd
## STATUS: [Level 2 - Implementation]
## TRUTH_LINK: TRUTH_CONTENT-CREATION-MANUAL.md §2, §3.4, §6; TRUTH_SIMULATION-GRAPH.md §2.1
## LOG_REF: 2026-05-23 17:10:12
##

# File: src/scenes/game_world/world_manager/template_indexer.gd
# Purpose: Scans the project's data directories to find and register all
#          .tres template files into the TemplateDatabase autoload.
# Version: 1.4 - Added UtilityToolTemplate support.

extends Node

var _pending_contract_templates: Array = []

# --- Public API ---

# Main entry point. Kicks off the recursive scan of the data directory.
func index_all_templates():
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("TemplateIndexer: Indexing all data templates...")
	_pending_contract_templates.clear()
	_scan_directory_for_templates("res://database/registry/")
	_register_pending_contract_templates()
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("TemplateIndexer: Template indexing complete.")


# --- Private Logic ---

# Recursively scans a directory path for .tres files.
func _scan_directory_for_templates(path: String):
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# --- FIX: Skip '.' and '..' to prevent infinite recursion ---
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue # Move to the next item immediately
			# --- END FIX ---

			var full_path = path.plus_file(file_name)
			if dir.current_is_dir():
				# If it's a directory, scan it recursively.
				_scan_directory_for_templates(full_path + "/")
			elif file_name.ends_with(".tres"):
				# If it's a .tres file, load it and register it.
				var template = load(full_path)
				if is_instance_valid(template) and template is Template:
					_register_template(template)
			file_name = dir.get_next()
	else:
		printerr("TemplateIndexer Error: Could not open directory for indexing: ", path)


# Determines the type of a loaded template and adds it to the correct
# dictionary in the TemplateDatabase.
func _register_template(template: Template):
	if template.template_id == "":
		printerr("Template Error: Resource file has no template_id: ", template.resource_path)
		return

	if template is ActionTemplate:
		TemplateDatabase.actions[template.template_id] = template
	elif template is AgentTemplate:
		TemplateDatabase.agents[template.template_id] = template
	elif template is CharacterTemplate:
		TemplateDatabase.characters[template.template_id] = template
	elif template is ShipTemplate:
		TemplateDatabase.assets_ships[template.template_id] = template
	elif template is ModuleTemplate:
		TemplateDatabase.assets_modules[template.template_id] = template
	elif template is CommodityTemplate:
		TemplateDatabase.assets_commodities[template.template_id] = template
	elif template is LocationTemplate:
		TemplateDatabase.locations[template.template_id] = template
	elif template is ContractTemplate:
		_pending_contract_templates.append(template)
	elif template is UtilityToolTemplate:
		TemplateDatabase.utility_tools[template.template_id] = template
	elif template is FactionTemplate:
		TemplateDatabase.factions[template.template_id] = template
	else:
		print("TemplateIndexer Warning: Unknown template type for resource: ", template.resource_path)


func _register_pending_contract_templates() -> void:
	for template in _pending_contract_templates:
		if _contract_locations_are_valid(template):
			TemplateDatabase.contracts[template.template_id] = template
	_pending_contract_templates.clear()


func _contract_locations_are_valid(template: ContractTemplate) -> bool:
	var invalid_fields: Array = []
	var origin_location_id: String = template.get("origin_location_id") if template.get("origin_location_id") != null else ""
	var destination_location_id: String = template.get("destination_location_id") if template.get("destination_location_id") != null else ""

	if not TemplateDatabase.locations.has(origin_location_id):
		invalid_fields.append("origin_location_id=%s" % _format_location_id(origin_location_id))
	if not TemplateDatabase.locations.has(destination_location_id):
		invalid_fields.append("destination_location_id=%s" % _format_location_id(destination_location_id))

	if invalid_fields.empty():
		return true

	printerr(
		"TemplateIndexer: Skipping contract '%s' with invalid locations: %s." % [
			template.template_id,
			", ".join(invalid_fields),
		]
	)
	return false


func _format_location_id(location_id: String) -> String:
	if location_id == "":
		return "<empty>"
	return location_id
