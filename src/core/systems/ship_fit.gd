# ShipFit: what is fitted in a ship's slots, and the stats that follow from it.
# A fit is {"tools": [id or "" per tool slot], "modules": [id or "" per module slot]}.
# Tool slots are listed small, then medium, then large; a tool fits a slot of its size or larger.
# Stats are the hull's own plus every module's stat_modifiers; every part adds its mass.

extends Reference

const SIZES = ["small", "medium", "large"]
const STATS = ["hull", "power_capacity", "power_regen", "cargo_capacity", "linear_thrust", "angular_thrust", "signature", "sensor_strength"]


static func tool_slot_sizes(ship) -> Array:
	var sizes: Array = []
	for i in range(ship.tool_slots_small):
		sizes.append("small")
	for i in range(ship.tool_slots_medium):
		sizes.append("medium")
	for i in range(ship.tool_slots_large):
		sizes.append("large")
	return sizes


static func tool_fits_slot(tool_template, slot_size: String) -> bool:
	return SIZES.find(tool_template.mount_size) <= SIZES.find(slot_size)


# The hull's default fit: equipped tools into the first slots that take them, then its modules.
static func default_fit(ship) -> Dictionary:
	var fit: Dictionary = empty_fit(ship)
	for tool_id in ship.equipped_tools:
		var slot: int = free_tool_slot(ship, fit, tool_id)
		if slot >= 0:
			fit.tools[slot] = tool_id
	for i in range(min(ship.equipped_modules.size(), fit.modules.size())):
		fit.modules[i] = ship.equipped_modules[i]
	return fit


# A random fit for an NPC: a laser in its first tool slot (so it can fight), any working tool in
# the others (lasers, harpoon; not the drill, which has no use yet), and a random module or none in
# each module slot.
static func random_fit(ship) -> Dictionary:
	var fit: Dictionary = empty_fit(ship)
	var sizes: Array = tool_slot_sizes(ship)
	var lasers: Array = []
	var usable: Array = []
	for tool_id in TemplateDatabase.utility_tools:
		var tool_template = TemplateDatabase.utility_tools[tool_id]
		if not tool_template is UtilityToolTemplate:
			continue
		if tool_template.tool_type == "laser":
			lasers.append(tool_id)
		if tool_template.tool_type in ["laser", "harpoon"]:
			usable.append(tool_id)
	for i in range(sizes.size()):
		var choices: Array = []
		for tool_id in (lasers if i == 0 else usable):
			if tool_fits_slot(TemplateDatabase.utility_tools[tool_id], sizes[i]):
				choices.append(tool_id)
		if not choices.empty():
			fit.tools[i] = choices[randi() % choices.size()]
	var modules: Array = TemplateDatabase.assets_modules.keys()
	for i in range(fit.modules.size()):
		var pick: int = randi() % (modules.size() + 1)  # One chance in (modules + 1) of an empty slot
		if pick < modules.size():
			fit.modules[i] = modules[pick]
	return fit


static func empty_fit(ship) -> Dictionary:
	var tools: Array = []
	tools.resize(tool_slot_sizes(ship).size())
	var modules: Array = []
	modules.resize(ship.module_slots)
	for i in range(tools.size()):
		tools[i] = ""
	for i in range(modules.size()):
		modules[i] = ""
	return {"tools": tools, "modules": modules}


# A stored fit made to match this hull's slots (extra parts dropped, missing slots empty).
static func normalized(ship, fit: Dictionary) -> Dictionary:
	var result: Dictionary = empty_fit(ship)
	var sizes: Array = tool_slot_sizes(ship)
	var tools: Array = fit.get("tools", [])
	for i in range(min(tools.size(), result.tools.size())):
		var tool_template = TemplateDatabase.get_template(str(tools[i]))
		if tool_template is UtilityToolTemplate and tool_fits_slot(tool_template, sizes[i]):
			result.tools[i] = str(tools[i])
	var modules: Array = fit.get("modules", [])
	for i in range(min(modules.size(), result.modules.size())):
		if TemplateDatabase.get_template(str(modules[i])) is ModuleTemplate:
			result.modules[i] = str(modules[i])
	return result


# Smallest empty tool slot that takes this tool, or -1.
static func free_tool_slot(ship, fit: Dictionary, tool_id: String) -> int:
	var tool_template = TemplateDatabase.get_template(tool_id)
	if not tool_template is UtilityToolTemplate:
		return -1
	var sizes: Array = tool_slot_sizes(ship)
	var best := -1
	for i in range(sizes.size()):
		if fit.tools[i] == "" and tool_fits_slot(tool_template, sizes[i]):
			if best < 0 or SIZES.find(sizes[i]) < SIZES.find(sizes[best]):
				best = i
	return best


static func free_module_slot(fit: Dictionary) -> int:
	return fit.modules.find("")


static func fitted_tool_ids(fit: Dictionary) -> Array:
	var ids: Array = []
	for tool_id in fit.get("tools", []):
		if tool_id != "":
			ids.append(tool_id)
	return ids


static func compute_stats(ship, fit: Dictionary) -> Dictionary:
	var stats := {
		"hull": float(ship.hull_integrity),
		"power_capacity": float(ship.power_capacity),
		"power_regen": float(ship.power_regen),
		"cargo_capacity": float(ship.cargo_capacity),
		"linear_thrust": float(ship.linear_thrust),
		"angular_thrust": float(ship.angular_thrust),
		"signature": float(ship.signature),
		"sensor_strength": float(ship.sensor_strength),
		"mass": float(ship.mass),
	}
	for tool_id in fit.get("tools", []):
		var tool_template = TemplateDatabase.get_template(str(tool_id))
		if tool_template is UtilityToolTemplate:
			stats.mass += tool_template.mass
	for module_id in fit.get("modules", []):
		var module = TemplateDatabase.get_template(str(module_id))
		if module is ModuleTemplate:
			stats.mass += module.mass
			for stat in module.stat_modifiers:
				if stats.has(stat):
					stats[stat] += float(module.stat_modifiers[stat])
	return stats
