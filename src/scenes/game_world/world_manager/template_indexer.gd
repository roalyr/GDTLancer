# TemplateIndexer: scans database/registry/ and registers every .tres template into TemplateDatabase;
# then database/presets/ (evolved designs: tools/export_presets.gd), whose ships and parts go to
# TemplateDatabase.presets, for the home station's store only (AgentTemplates there are left out:
# nothing spawns from presets yet). A preset in several folders is the same design (ids follow the
# genes): the first is kept.

extends Node

# --- Public API ---

# Main entry point. Kicks off the recursive scan of the data directory.
func index_all_templates():
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("TemplateIndexer: Indexing all data templates...")
	_scan_directory_for_templates("res://database/registry/")
	_scan_presets(Constants.PRESETS_DIR)
	if Constants.VERBOSE_RUNTIME_LOGS:
		print("TemplateIndexer: Template indexing complete.")


# --- Private Logic ---

func _scan_presets(path: String) -> void:
	var dir = Directory.new()
	if dir.open(path) != OK:
		return
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	while file_name != "":
		var full_path: String = path.plus_file(file_name)
		if dir.current_is_dir():
			_scan_presets(full_path)
		elif file_name.ends_with(".tres") and not file_name.begins_with("agent_"):
			var template = load(full_path)
			if template is ShipTemplate or template is UtilityToolTemplate or template is ModuleTemplate:
				if not TemplateDatabase.presets.has(template.template_id) and TemplateDatabase.get_template(template.template_id) == null:
					TemplateDatabase.presets[template.template_id] = template
				if template is ShipTemplate and path.ends_with("min10"):
					TemplateDatabase.proven_presets[template.template_id] = true
		file_name = dir.get_next()


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
					for field in find_undeclared_fields(full_path, template):
						printerr("Template Error: ", full_path, " sets '", field, "', which ", template.get_script().resource_path, " does not declare; the value is ignored.")
					_register_template(template)
			file_name = dir.get_next()
	else:
		printerr("TemplateIndexer Error: Could not open directory for indexing: ", path)


# Fields written in a .tres file that its script does not declare. Godot drops them silently,
# so a renamed field, or a file saved by an editor still holding an old script, loses its values.
static func find_undeclared_fields(path: String, resource: Resource) -> Array:
	var declared := {}
	for property in resource.get_property_list():
		declared[property.name] = true
	var undeclared: Array = []
	var file := File.new()
	if file.open(path, File.READ) != OK:
		return undeclared
	var in_resource := false
	for line in file.get_as_text().split("\n"):
		if line.begins_with("["):
			in_resource = line.begins_with("[resource]")
		elif in_resource and " = " in line and not line.begins_with("\""):
			var field: String = line.split(" = ")[0]
			if not declared.has(field):
				undeclared.append(field)
	file.close()
	return undeclared


# Determines the type of a loaded template and adds it to the correct
# dictionary in the TemplateDatabase.
func _register_template(template: Template):
	if template.template_id == "":
		printerr("Template Error: Resource file has no template_id: ", template.resource_path)
		return
	var existing = TemplateDatabase.get_template(template.template_id)
	if existing is Resource and existing.resource_path != template.resource_path:
		printerr("Template Error: Duplicate template_id '", template.template_id, "' in ", template.resource_path, " (already used by ", existing.resource_path, ")")
		return

	if template is AgentTemplate:
		TemplateDatabase.agents[template.template_id] = template
	elif template is ShipTemplate:
		TemplateDatabase.assets_ships[template.template_id] = template
	elif template is ModuleTemplate:
		TemplateDatabase.assets_modules[template.template_id] = template
	elif template is CommodityTemplate:
		TemplateDatabase.assets_commodities[template.template_id] = template
	elif template is LocationTemplate:
		TemplateDatabase.locations[template.template_id] = template
	elif template is UtilityToolTemplate:
		TemplateDatabase.utility_tools[template.template_id] = template
	elif template is GameStartTemplate:
		TemplateDatabase.game_starts[template.template_id] = template
	else:
		print("TemplateIndexer Warning: Unknown template type for resource: ", template.resource_path)
