# FittingWindow: the home station's store and refitting, mouse-only. Covers the screen for as
# long as the player is docked at home (the docked ship is out of the world); UNDOCK leaves. Slots (click to unfit), storage (fit or sell) and the store, which
# sells every ship (the one flown is traded in), part and commodity (bought into the hold, sold
# back from it). The frame is the scene; rows are rebuilt after every change.

extends Control

const Fitting = preload("res://src/core/systems/fitting.gd")
const ShipFit = preload("res://src/core/systems/ship_fit.gd")

onready var _title: Label = $Panel/Layout/Header/Title
onready var _stats: Label = $Panel/Layout/Body/Content/Stats
onready var _slots: VBoxContainer = $Panel/Layout/Body/Content/Columns/Slots/List
onready var _storage: VBoxContainer = $Panel/Layout/Body/Content/Columns/Storage/Scroll/List
onready var _store: VBoxContainer = $Panel/Layout/Body/Content/Columns/Store/Scroll/List
onready var _status: Label = $Panel/Layout/Body/Content/Status


func _ready() -> void:
	$Panel/Layout/Header/ButtonUndock.connect("pressed", EventBus, "emit_signal", ["player_undocked"])
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")


func open() -> void:
	if not Fitting.is_available():
		return
	_status.text = ""
	visible = true
	refresh()


func close() -> void:
	visible = false


# Deferred: the player controller sets GameState.player_docked_at in its own handler.
func _on_player_docked(_location_id: String) -> void:
	call_deferred("open")


func _on_player_undocked() -> void:
	close()


func refresh() -> void:
	var ship_body = GlobalRefs.player_agent_body
	if not is_instance_valid(ship_body) or ship_body.get("fit") == null:
		close()
		return
	_title.text = "DOCKED AT %s  -  BANK %d WP" % [_station_name(GameState.player_docked_at).to_upper(), GameState.player_bank]
	_stats.text = describe_stats(ship_body)
	_rebuild_slots(ship_body)
	_rebuild_storage(ship_body)
	_rebuild_store(ship_body)


func _station_name(location_id: String) -> String:
	for station in get_tree().get_nodes_in_group("dockable_station"):
		if station.get("location_id") == location_id:
			return station.station_name
	return location_id


static func describe_stats(ship_body) -> String:
	var stats: Dictionary = ship_body.fit_stats
	var top_speed: float = stats.linear_thrust / max(ship_body.mass * Constants.LINEAR_DRAG, 0.001)
	return "HULL %d   POWER %d (+%d/s)   CARGO %d   THRUST %d kN   MASS %.1f t   TOP SPEED %d m/s   SIGNATURE %.1f km   SENSORS x%.1f" % [
		stats.hull, stats.power_capacity, stats.power_regen, stats.cargo_capacity,
		stats.linear_thrust / 1000.0, ship_body.mass / 1000.0, top_speed, stats.signature / 1000.0, stats.sensor_strength
	]


const STAT_LABELS = {
	"hull": ["%+d hull", 1.0],
	"power_capacity": ["%+d power", 1.0],
	"power_regen": ["%+d power/s", 1.0],
	"cargo_capacity": ["%+d cargo", 1.0],
	"linear_thrust": ["%+d kN thrust", 0.001],
	"angular_thrust": ["%+d kNm turn", 0.001],
	"signature": ["%+d m signature", 1.0],
	"sensor_strength": ["%+.1f sensors", 1.0],
	"decoy_charges": ["%d decoys", 1.0],
	"afterburner_thrust": ["%+d kN thrust lit", 0.001],
}


# What a part does, compactly: effect or role, then mass.
static func describe_part(part_id: String) -> String:
	var part = TemplateDatabase.get_template(part_id)
	if part is UtilityToolTemplate:
		var note: String = "" if part.tool_type in ["laser", "harpoon", "missile", "cannon"] else "  (no use yet)"
		return "%s  %s, %d m, %.1f t%s" % [part.tool_name, part.mount_size, part.optimal_range, part.mass / 1000.0, note]
	if part is ModuleTemplate:
		var effects: Array = []
		for stat in part.stat_modifiers:
			if stat == "damper_mass":  # Its share depends on the hull: the reference hull's
				effects.append("-%d%% signature on a Phoenix Light" % int(round(100.0 * ShipFit.damper_share(part.stat_modifiers[stat], Constants.LAW_SHIP_REF_MASS))))
				continue
			var label: Array = STAT_LABELS.get(stat, ["%+d " + stat, 1.0])
			effects.append(label[0] % (part.stat_modifiers[stat] * label[1]))
		return "%s  %s, %.1f t" % [part.module_name, PoolStringArray(effects).join(", "), part.mass / 1000.0]
	return part_id


func _rebuild_slots(ship_body) -> void:
	_clear(_slots)
	var sizes: Array = ShipFit.tool_slot_sizes(ship_body.ship_template)
	for i in range(ship_body.fit.tools.size()):
		var part_id: String = ship_body.fit.tools[i]
		_add_button(_slots, "%s tool: %s" % [sizes[i].capitalize(), Fitting.part_name(part_id) if part_id != "" else "empty"], part_id == "", "_on_unfit", ["tools", i])
	for i in range(ship_body.fit.modules.size()):
		var part_id: String = ship_body.fit.modules[i]
		_add_button(_slots, "Module: %s" % (Fitting.part_name(part_id) if part_id != "" else "empty"), part_id == "", "_on_unfit", ["modules", i])


func _rebuild_storage(_ship_body) -> void:
	_clear(_storage)
	var ids: Array = GameState.player_storage.keys()
	ids.sort()
	if ids.empty():
		var empty := Label.new()
		empty.text = "Nothing stored"
		_storage.add_child(empty)
	for part_id in ids:
		var row := HBoxContainer.new()
		_storage.add_child(row)
		var fit_button: Button = _add_button(row, "Fit %s  x%d" % [Fitting.part_name(part_id), GameState.player_storage[part_id]], false, "_on_fit", [part_id])
		fit_button.size_flags_horizontal = SIZE_EXPAND_FILL
		fit_button.clip_text = true
		_add_button(row, "Sell %d" % Fitting.sale_price(part_id), false, "_on_sell", [part_id])


func _rebuild_store(ship_body) -> void:
	_clear(_store)
	_add_heading(_store, "SHIPS - yours is traded in for half")
	for ship_id in Fitting.ship_catalog():
		var flying: bool = ship_id == GameState.player_ship_template_id
		var cost: int = Fitting.ship_cost(ship_id)
		var label: String = "FLYING" if flying else ("%d WP" % cost if cost >= 0 else "+%d WP" % -cost)
		var button: Button = _add_button(_store, "%s  %s" % [label, describe_ship(ship_id)], flying or GameState.player_bank < cost, "_on_buy_ship", [ship_id])
		button.clip_text = true
	_add_heading(_store, "PARTS - into storage")
	for part_id in Fitting.catalog():
		var cost: int = Fitting.price(part_id)
		var button: Button = _add_button(_store, "%d WP  %s" % [cost, describe_part(part_id)], GameState.player_bank < cost, "_on_buy", [part_id])
		button.clip_text = true
	_add_heading(_store, "CARGO - hold %d / %d" % [ship_body.get_cargo_units(), ship_body.cargo_capacity])
	for commodity_id in Fitting.cargo_catalog():
		var cost: int = Fitting.price(commodity_id)
		var held: int = int(ship_body.cargo.get(commodity_id, 0))
		var row := HBoxContainer.new()
		_store.add_child(row)
		var buy: Button = _add_button(row, "%d WP  %s  x%d" % [cost, Fitting.part_name(commodity_id), held], GameState.player_bank < cost or ship_body.get_free_cargo() <= 0, "_on_buy_cargo", [commodity_id])
		buy.size_flags_horizontal = SIZE_EXPAND_FILL
		buy.clip_text = true
		_add_button(row, "Sell", held <= 0, "_on_sell_cargo", [commodity_id])


# A hull, compactly: hull points, tool slots by size, module slots, mass.
static func describe_ship(ship_id: String) -> String:
	var ship = TemplateDatabase.get_template(ship_id)
	if not ship is ShipTemplate:
		return ship_id
	var tools: Array = []
	for size in [["small", ship.tool_slots_small], ["medium", ship.tool_slots_medium], ["large", ship.tool_slots_large]]:
		if size[1] > 0:
			tools.append("%d %s" % [size[1], size[0]])
	return "%s  hull %d, tools %s, %d modules, %.1f t" % [ship.ship_model_name, ship.hull_integrity, PoolStringArray(tools).join(" + "), ship.module_slots, ship.mass / 1000.0]


func _add_heading(container: Node, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	container.add_child(heading)


func _add_button(container: Node, text: String, disabled: bool, method: String, binds: Array) -> Button:
	var button := Button.new()
	button.text = text.to_upper()  # Like the HUD buttons
	button.disabled = disabled
	button.align = Button.ALIGN_LEFT
	button.rect_min_size = Vector2(0, 40)
	button.connect("pressed", self, method, binds)
	container.add_child(button)
	return button


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _report(error: String, success: String) -> void:
	_status.text = error if error != "" else success
	refresh()


func _on_buy(part_id: String) -> void:
	_report(Fitting.buy(part_id), "Bought %s" % Fitting.part_name(part_id))


func _on_buy_ship(ship_id: String) -> void:
	_report(Fitting.buy_ship(ship_id), "Now flying %s; the old fit is in storage" % Fitting.part_name(ship_id))


func _on_buy_cargo(commodity_id: String) -> void:
	_report(Fitting.buy_cargo(GlobalRefs.player_agent_body, commodity_id), "Bought 1 %s" % Fitting.part_name(commodity_id))


func _on_sell_cargo(commodity_id: String) -> void:
	_report(Fitting.sell_cargo(GlobalRefs.player_agent_body, commodity_id), "Sold 1 %s for %d WP" % [Fitting.part_name(commodity_id), Fitting.price(commodity_id)])


func _on_sell(part_id: String) -> void:
	_report(Fitting.sell(part_id), "Sold %s for %d WP" % [Fitting.part_name(part_id), Fitting.sale_price(part_id)])


func _on_fit(part_id: String) -> void:
	_report(Fitting.fit_part(GlobalRefs.player_agent_body, part_id), "Fitted %s" % Fitting.part_name(part_id))


func _on_unfit(kind: String, slot: int) -> void:
	var part_id: String = GlobalRefs.player_agent_body.fit[kind][slot]
	_report(Fitting.unfit(GlobalRefs.player_agent_body, kind, slot), "Unfitted %s" % Fitting.part_name(part_id))
