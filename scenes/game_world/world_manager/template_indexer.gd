# File: scenes/game_world/world_manager/template_indexer.gd
# Purpose: Scans the project's data directories to find and register all
#          .tres template files into the TemplateDatabase autoload.
# Version: 1.4 - Added UtilityToolTemplate support.

extends Node

# --- Public API ---

# Main entry point. Kicks off the recursive scan of the data directory.
func index_all_templates():
	print("TemplateIndexer: Indexing all data templates...")
	_scan_directory_for_templates("res://assets/data/")
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
		TemplateDatabase.contracts[template.template_id] = template
	elif template is UtilityToolTemplate:
		TemplateDatabase.utility_tools[template.template_id] = template
	else:
		print("TemplateIndexer Warning: Unknown template type for resource: ", template.resource_path)
