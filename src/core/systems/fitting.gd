# Fitting: the home station's store and refitting. It sells everything there is: every tool and
# module (bought into the home storage, fitted from there, sold back for half), every ship hull
# (the current one is traded in for half its price) and every commodity (into the hold, sold back
# at the same price). Every refit is applied to the ship at once (stats, mass, tools) and repairs it.
# Returns "" on success or a message saying why not.

extends Reference

const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const HomePort = preload("res://src/core/systems/home_port.gd")


static func is_available() -> bool:
	return HomePort.is_home(GameState.player_docked_at)


# Parts the home station sells: every tool and module.
static func catalog() -> Array:
	var ids: Array = []
	for tool_id in TemplateDatabase.utility_tools:
		ids.append(tool_id)
	for module_id in TemplateDatabase.assets_modules:
		ids.append(module_id)
	ids.sort()
	return ids


# Ships the home station sells: every hull.
static func ship_catalog() -> Array:
	var ids: Array = TemplateDatabase.assets_ships.keys()
	ids.sort()
	return ids


# Commodities the home station trades: every one.
static func cargo_catalog() -> Array:
	var ids: Array = TemplateDatabase.assets_commodities.keys()
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
	if part is ShipTemplate:
		return part.ship_model_name
	if part is CommodityTemplate:
		return part.commodity_name if "commodity_name" in part else part_id
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


# What a new hull costs here: its price less half the current hull's (negative: a refund).
static func ship_cost(ship_id: String) -> int:
	return price(ship_id) - sale_price(GameState.player_ship_template_id)


# Swaps the player's hull for another. The fitted parts go to storage, the new hull comes with its
# own default fit, repaired and docked here (and, as on any docking at home, its hold is banked).
static func buy_ship(ship_id: String) -> String:
	if not is_available():
		return "Dock at the home station to change ships"
	if not TemplateDatabase.assets_ships.get(ship_id) is ShipTemplate:
		return "Not for sale"
	if ship_id == GameState.player_ship_template_id:
		return "Already flying it"
	var cost: int = ship_cost(ship_id)
	if GameState.player_bank < cost:
		return "Not enough banked WP (%d needed)" % cost
	var spawner = GlobalRefs.agent_spawner
	if not is_instance_valid(spawner) or not spawner.has_method("replace_player"):
		return "Cannot change ships here"
	GameState.player_bank -= cost
	for kind in ["tools", "modules"]:
		for part_id in GameState.player_fit.get(kind, []):
			if str(part_id) != "":
				_add_to_storage(str(part_id), 1)
	GameState.player_ship_template_id = ship_id
	GameState.player_fit = {}  # The new hull's default fit
	GameState.player_hull = -1.0  # Full
	GameState.player_hull_scars = []  # A new hull is unmarked
	spawner.replace_player()
	return ""


# One unit of a commodity into the hold, at its base value.
static func buy_cargo(ship_body: Node, commodity_id: String) -> String:
	if not is_available():
		return "Dock at the home station to trade"
	var cost: int = price(commodity_id)
	if cost <= 0 or not commodity_id in cargo_catalog():
		return "Not for sale"
	if GameState.player_bank < cost:
		return "Not enough banked WP (%d needed)" % cost
	if ship_body.add_cargo(commodity_id, 1) <= 0:
		return "Hold full"
	GameState.player_bank -= cost
	return ""


# One unit of a commodity from the hold, at its base value.
static func sell_cargo(ship_body: Node, commodity_id: String) -> String:
	if not is_available():
		return "Dock at the home station to trade"
	if ship_body.remove_cargo(commodity_id, 1) <= 0:
		return "None in the hold"
	GameState.player_bank += price(commodity_id)
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
