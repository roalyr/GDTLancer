# Fitting: the home station's store and refitting. It sells, at the station's prices (Market), the
# part catalogue (PartCatalog: three of every kind, light, medium, heavy; bought into the home
# storage, fitted from there, sold back for half), the archetypes' hulls (the current one is traded
# in for half its price) and every commodity
# (into the hold, sold back at the station's cargo price). Every refit is applied to the ship at once
# (stats, mass, tools) and repairs it.
# Cargo is the one trade at every station (can_sell_cargo): docking never sells the hold, the
# player does, a unit or all at once, at the station's price for it (Market.commodity_sale_price:
# what it buys, its markup and the player's standing with its faction), salvage included.
# Returns "" on success or a message saying why not.

extends Reference

const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const HomePort = preload("res://src/core/systems/home_port.gd")
const Market = preload("res://src/core/systems/market.gd")
const PartCatalog = preload("res://src/core/systems/part_catalog.gd")


static func is_available() -> bool:
	return HomePort.is_home(GameState.player_docked_at)


# Docked anywhere: the hold can be sold.
static func can_sell_cargo() -> bool:
	return GameState.player_docked_at != ""


# The faction of the station docked at ("" for none).
static func docked_faction() -> String:
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		for station in tree.get_nodes_in_group("dockable_station"):
			if station.get("location_id") == GameState.player_docked_at:
				return str(station.get("faction")) if station.get("faction") != null else ""
	return ""


# Parts the home station sells: the catalogue, nothing else.
static func catalog() -> Array:
	var ids: Array = []
	for part_id in PartCatalog.ids():
		if TemplateDatabase.get_template(part_id) != null:
			ids.append(part_id)
	ids.sort()
	return ids


# Ships the home station sells: the archetypes' hulls, three of every family (bare: its price is the
# hull's; the parts are in catalog()). Drafts are evolution's, not for sale.
static func ship_catalog() -> Array:
	var ids: Array = []
	for preset_id in TemplateDatabase.presets:
		if TemplateDatabase.presets[preset_id] is ShipTemplate and str(preset_id).begins_with("preset_ship_archetype_"):
			ids.append(preset_id)
	ids.sort()
	return ids


# Commodities the home station trades: every one.
static func cargo_catalog() -> Array:
	var ids: Array = TemplateDatabase.assets_commodities.keys()
	ids.sort()
	return ids


# What the home station charges.
static func price(part_id: String) -> int:
	return Market.price(_value(part_id), GameState.home_location_id)


# What it pays for a part or a traded-in hull.
static func sale_price(part_id: String) -> int:
	return Market.part_sale_price(_value(part_id), GameState.home_location_id)


# What the station docked at pays for a unit of cargo (0: it does not buy it).
static func cargo_sale_price(commodity_id: String) -> int:
	return Market.commodity_sale_price(commodity_id, GameState.player_docked_at, docked_faction())


static func _value(part_id: String) -> float:
	var part = TemplateDatabase.get_template(part_id)
	return float(part.base_value) if part != null and "base_value" in part else 0.0


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
# own default fit (a preset's bare), repaired and docked here (and, as on any docking at home, its
# hold is banked).
static func buy_ship(ship_id: String) -> String:
	if not is_available():
		return "Dock at the home station to change ships"
	if not (TemplateDatabase.get_template(ship_id) is ShipTemplate and ship_id in ship_catalog()):
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
	var hull = TemplateDatabase.get_template(ship_id)
	GameState.player_fit = ShipFit.empty_fit(hull) if TemplateDatabase.presets.has(ship_id) else {}  # Bare, or the hull's default fit
	GameState.player_hull = -1.0  # Full
	GameState.player_hull_scars = []  # A new hull is unmarked
	spawner.replace_player()
	return ""


# One unit of a commodity into the hold, at the station's price.
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


# `units` of a commodity from the hold (-1: all of it), at the station's cargo price.
static func sell_cargo(ship_body: Node, commodity_id: String, units: int = 1) -> String:
	if not can_sell_cargo():
		return "Dock to sell cargo"
	var price: int = cargo_sale_price(commodity_id)
	if price <= 0:
		return "This station does not buy it"
	var held: int = int(ship_body.cargo.get(commodity_id, 0))
	var taken: int = ship_body.remove_cargo(commodity_id, held if units < 0 else int(min(units, held))) if held > 0 else 0
	if taken <= 0:
		return "None in the hold"
	GameState.player_bank += taken * price
	return ""


# The whole hold but the fuel, as the station buys it (Market.sell_hold). Returns {"banked", "units"}.
static func sell_hold(ship_body: Node) -> Dictionary:
	if not can_sell_cargo():
		return {"banked": 0, "units": 0}
	return Market.sell_hold(ship_body, GameState.player_docked_at, docked_faction())


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
