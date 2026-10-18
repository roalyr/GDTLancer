# Fitting: refitting the player's ship at the home port. Parts are bought with banked WP into the
# home storage, fitted from storage into slots, unfitted back to storage, and sold for half price.
# Every change is applied to the ship at once (stats, mass, tools) and the ship is repaired.
# Returns "" on success or a message saying why not.

extends Reference

const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const HomePort = preload("res://src/core/systems/home_port.gd")


static func is_available() -> bool:
	return HomePort.is_home(GameState.player_docked_at)


# Parts the home station sells: tools that work and every module.
static func catalog() -> Array:
	var ids: Array = []
	for tool_id in TemplateDatabase.utility_tools:
		if TemplateDatabase.utility_tools[tool_id].tool_type in ["laser", "harpoon"]:
			ids.append(tool_id)
	for module_id in TemplateDatabase.assets_modules:
		ids.append(module_id)
	ids.sort()
	return ids


static func price(part_id: String) -> int:
	var part = TemplateDatabase.get_template(part_id)
	return int(part.base_value) if part != null and "base_value" in part else 0


static func sale_price(part_id: String) -> int:
	return price(part_id) / 2


static func part_name(part_id: String) -> String:
	var part = TemplateDatabase.get_template(part_id)
	if part is UtilityToolTemplate:
		return part.tool_name
	if part is ModuleTemplate:
		return part.module_name
	return part_id


static func buy(part_id: String) -> String:
	if not is_available():
		return "Dock at the home station to buy parts"
	var cost: int = price(part_id)
	if cost <= 0 or not part_id in catalog():
		return "Not for sale"
	if GameState.player_bank < cost:
		return "Not enough banked WP (%d needed)" % cost
	GameState.player_bank -= cost
	_add_to_storage(part_id, 1)
	return ""


static func sell(part_id: String) -> String:
	if not is_available():
		return "Dock at the home station to sell parts"
	if int(GameState.player_storage.get(part_id, 0)) <= 0:
		return "Not in storage"
	_add_to_storage(part_id, -1)
	GameState.player_bank += sale_price(part_id)
	return ""


# Fits a stored part into the first free slot that takes it.
static func fit_part(ship_body: Node, part_id: String) -> String:
	if not is_available():
		return "Dock at the home station to refit"
	if int(GameState.player_storage.get(part_id, 0)) <= 0:
		return "Not in storage"
	var ship = ship_body.ship_template
	var fit: Dictionary = ship_body.fit.duplicate(true)
	var part = TemplateDatabase.get_template(part_id)
	if part is UtilityToolTemplate:
		var slot: int = ShipFit.free_tool_slot(ship, fit, part_id)
		if slot < 0:
			return "No free %s or larger tool slot" % part.mount_size
		fit.tools[slot] = part_id
	elif part is ModuleTemplate:
		var slot: int = ShipFit.free_module_slot(fit)
		if slot < 0:
			return "No free module slot"
		fit.modules[slot] = part_id
	else:
		return "Unknown part"
	_add_to_storage(part_id, -1)
	_apply(ship_body, fit)
	return ""


# kind is "tools" or "modules".
static func unfit(ship_body: Node, kind: String, slot: int) -> String:
	if not is_available():
		return "Dock at the home station to refit"
	var fit: Dictionary = ship_body.fit.duplicate(true)
	if slot < 0 or slot >= fit[kind].size() or fit[kind][slot] == "":
		return "Slot is empty"
	_add_to_storage(fit[kind][slot], 1)
	fit[kind][slot] = ""
	_apply(ship_body, fit)
	return ""


static func _apply(ship_body: Node, fit: Dictionary) -> void:
	ship_body.apply_fit(fit)
	ship_body.repair_hull()


static func _add_to_storage(part_id: String, units: int) -> void:
	var count: int = int(GameState.player_storage.get(part_id, 0)) + units
	if count > 0:
		GameState.player_storage[part_id] = count
	else:
		GameState.player_storage.erase(part_id)
