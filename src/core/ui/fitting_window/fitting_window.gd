# FittingWindow: the home station's store and refitting, mouse-only. Covers the screen for as
# long as the player is docked (the docked ship is out of the world); UNDOCK leaves; MENU opens the main menu (the HUD's menu button is under it). Away from home
# it shows the cargo tab only: the hold is sold here, by the player, never on docking (Fitting). At
# home, two views: FITTING, the ship (its stats, its hull turning, its slots: tap to unfit) beside
# storage (fit or sell); MARKET, storage beside the store, which
# sells every ship (the one flown is traded in; preset designs come fitted), part and commodity
# (bought into the hold, sold back from it). The store shows one tab at a time (STORE_TABS), its
# goods under headings (weight class, part kind), each a two-line row: name over what it is, its
# price on the button beside it. The frame is the scene, and so is each piece of the lists
# (scenes/ui/menus/fitting/: row, heading, note, buttons); the lists are rebuilt after every change.

extends Control

const Fitting = preload("res://src/core/systems/fitting.gd")
const ShipFit = preload("res://src/core/systems/ship_fit.gd")
const PresetClassifier = preload("res://src/core/evolution/preset_classifier.gd")
const Market = preload("res://src/core/systems/market.gd")
const ShipStats = preload("res://src/core/ui/helpers/ship_stats.gd")

onready var _title: Label = $Panel/Overflow/Layout/Header/Title
onready var _stats: VBoxContainer = $Panel/Overflow/Layout/Body/Content/Columns/Ship/Stats  # The ship flown: its numbers (Ship), where the power goes (Power)
onready var _ship_preview: Control = $Panel/Overflow/Layout/Body/Content/Columns/Ship/ShipPreview  # The ship flown, turning
onready var _slots: VBoxContainer = $Panel/Overflow/Layout/Body/Content/Columns/Ship/List
onready var _storage: VBoxContainer = $Panel/Overflow/Layout/Body/Content/Columns/Storage/Scroll/List
onready var _store: VBoxContainer = $Panel/Overflow/Layout/Body/Content/Columns/Store/Scroll/List
onready var _store_scroll: ScrollContainer = $Panel/Overflow/Layout/Body/Content/Columns/Store/Scroll
onready var _tabs: HBoxContainer = $Panel/Overflow/Layout/Body/Content/Columns/Store/Tabs
onready var _status: Label = $Panel/Overflow/Layout/Body/Content/Status
onready var _preview: Control = $Panel/Overflow/Layout/Body/Content/Columns/Store/HullPreview

const STORE_TABS = ["ships", "weapons", "equipment", "modules", "cargo"]
const WEAPON_TYPES = ["laser", "missile", "cannon"]
const RowScene = preload("res://scenes/ui/menus/fitting/fitting_row.tscn")
const RowButtonScene = preload("res://scenes/ui/menus/fitting/fitting_row_button.tscn")
const ButtonScene = preload("res://scenes/ui/menus/fitting/fitting_button.tscn")
const GroupHeadingScene = preload("res://scenes/ui/menus/fitting/fitting_group_heading.tscn")
const HeadingScene = preload("res://scenes/ui/menus/fitting/fitting_heading.tscn")
const NoteScene = preload("res://scenes/ui/menus/fitting/fitting_note.tscn")
const STORE_STAT_COLUMNS = 4  # A store hull's numbers (ShipStats, brief: eight) in two rows
const GROUP_OPEN_MAX = 12  # A part heading over more rows than this starts folded (tap it to unfold)

const FITTING = "fitting"  # The view: the ship (stats, its hull turning, its slots) and storage
const MARKET = "market"  # storage and the store

var view: String = FITTING
var _tab: String = "ships"
var _folded: Dictionary = {}  # Tab/heading -> folded, once tapped
var _ship_rows: Dictionary = {}  # Ships tab: ship id -> its row (tapping one shows it in the preview)
const SELECTED_SHADE = Color(1, 1, 1, 0.16)  # The previewed ship's row


func _ready() -> void:
	$Panel/Overflow/Layout/Header/ButtonUndock.connect("pressed", EventBus, "emit_signal", ["player_undocked"])
	$Panel/Overflow/Layout/Header/ButtonMenu.connect("pressed", EventBus, "emit_signal", ["main_menu_requested"])  # The HUD's menu button is under the store
	$Panel/Overflow/Layout/Header/TabFitting.connect("pressed", self, "show_view", [FITTING])
	$Panel/Overflow/Layout/Header/TabMarket.connect("pressed", self, "show_view", [MARKET])
	EventBus.connect("player_docked", self, "_on_player_docked")
	EventBus.connect("player_undocked", self, "_on_player_undocked")


func open() -> void:
	if not Fitting.can_sell_cargo():
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
	_title.text = Strings.t("fit.title", [_station_name(GameState.player_docked_at).to_upper(), GameState.player_bank])
	ShipStats.fill(_stats.get_node("Ship"), ShipStats.entries(ship_body.fit_stats, ship_body.mass, ship_body.get("ship_template")))
	var flow: Dictionary = power_numbers(ship_body)
	ShipStats.fill(_stats.get_node("Power"), ShipStats.power_entries(flow.regen, flow.damper, flow.tools_draw, flow.power_max, flow.afterburner))
	var home: bool = Fitting.is_available()
	var header: Node = $Panel/Overflow/Layout/Header
	header.get_node("TabFitting").visible = home  # Away from home: the cargo market alone
	header.get_node("TabMarket").visible = home
	header.get_node("TabFitting").text = ("[%s]" if view == FITTING else "%s") % Strings.t("fit.tab.fitting")
	header.get_node("TabMarket").text = ("[%s]" if view == MARKET else "%s") % Strings.t("fit.tab.market")
	_slots.get_parent().visible = home and view == FITTING
	_storage.get_parent().get_parent().visible = home
	_store.get_parent().get_parent().visible = not home or view == MARKET
	if not home:
		_tab = "cargo"
	if _ship_preview.ship_id != GameState.player_ship_template_id:
		_ship_preview.show_ship(GameState.player_ship_template_id)
	_rebuild_slots(ship_body)
	_rebuild_storage(ship_body)
	_rebuild_store(ship_body)


func _station_name(location_id: String) -> String:
	for station in get_tree().get_nodes_in_group("dockable_station"):
		if station.get("location_id") == location_id:
			return station.station_name
	return location_id


# Where the power goes, from the fit: the reactor's charge (less what sensor dampers run off it),
# the draw of every tool working at once (harpoons draw per launch, not counted), the afterburner's
# at full thrust, and the net with the tools on: what a long fight costs or leaves. One entry per
# line of the HUD's ship info; the docking view runs them together.
static func power_flow(ship_body) -> Array:
	var flow: Dictionary = power_numbers(ship_body)
	var reactor: String = Strings.t("power.reactor", [flow.regen + flow.damper])
	if flow.damper > 0.0:
		reactor += "  " + Strings.t("power.damper", [flow.damper])
	var lines: Array = [reactor]
	if flow.tools_draw > 0.0:
		var net: float = flow.regen - flow.tools_draw
		lines.append(Strings.t("power.tools_on", [flow.tools_draw, "+" if net >= 0.0 else "-", abs(net),
			"" if net >= 0.0 else "  " + Strings.t("power.full_to_empty", [int(flow.power_max / -net)])]))
	if flow.afterburner > 0.0:
		lines.append(Strings.t("power.afterburner", [flow.afterburner]))
	return lines


# power_flow's numbers: {regen (the reactor's, less the damper's), damper, tools_draw (all on),
# power_max, afterburner (at full thrust)}, per second.
static func power_numbers(ship_body) -> Dictionary:
	var stats: Dictionary = ship_body.get("fit_stats") if ship_body.get("fit_stats") != null else {}
	var tools_draw := 0.0
	var tools = ship_body.get_node_or_null("ToolController")
	if is_instance_valid(tools):
		for index in range(tools.get_tool_count()):
			var tool_template = tools.get_tool(index)
			if tool_template != null and tool_template.tool_type != "harpoon" and tool_template.cycle_time > 0.0:
				tools_draw += tool_template.power_per_cycle / tool_template.cycle_time
	return {"regen": float(ship_body.power_regen), "damper": Constants.LAW_DAMPER_POWER_PER_KG * float(stats.get("damper_mass", 0.0)),
		"tools_draw": tools_draw, "power_max": float(ship_body.power_max),
		"afterburner": float(stats.get("afterburner_thrust", 0.0)) / 1000.0 * Constants.LAW_AFTERBURNER_POWER_PER_KN}


static func describe_stats(ship_body) -> String:
	return ShipStats.text(ShipStats.entries(ship_body.fit_stats, ship_body.mass)) + "\n" + Strings.t("power.flow") + "   " + PoolStringArray(power_flow(ship_body)).join("   ")


const STAT_LABELS = {
	"hull": ["part.stat.hull", 1.0],  # Strings keys, a number in each
	"power_capacity": ["part.stat.power_capacity", 1.0],
	"power_regen": ["part.stat.power_regen", 1.0],
	"cargo_capacity": ["part.stat.cargo_capacity", 1.0],
	"linear_thrust": ["part.stat.linear_thrust", 0.001],
	"angular_thrust": ["part.stat.angular_thrust", 0.001],
	"signature": ["part.stat.signature", 1.0],
	"sensor_strength": ["part.stat.sensor_strength", 1.0],
	"decoy_charges": ["part.stat.decoy_charges", 1.0],
	"afterburner_thrust": ["part.stat.afterburner_thrust", 0.001],
	"shell_load": ["part.stat.shell_load", 1.0],
	"missile_load": ["part.stat.missile_load", 1.0],
}


# What a part does, compactly: its name, effect or role, then mass.
static func describe_part(part_id: String) -> String:
	var part = TemplateDatabase.get_template(part_id)
	if part is UtilityToolTemplate or part is ModuleTemplate:
		return "%s  %s" % [Fitting.part_name(part_id), part_detail(part_id)]
	return part_id


# What a part does, without its name.
static func part_detail(part_id: String) -> String:
	var part = TemplateDatabase.get_template(part_id)
	if part is UtilityToolTemplate:
		var note: String = "" if part.tool_type in ["laser", "harpoon", "missile", "cannon"] else "  " + Strings.t("part.no_use_yet")
		return Strings.t("part.tool_detail", [Strings.t("size." + str(part.mount_size)), part.optimal_range, part.mass / 1000.0]) + note
	if part is ModuleTemplate:
		var effects: Array = []
		for stat in part.stat_modifiers:
			if stat == "damper_mass":  # Its share depends on the hull: the reference hull's
				effects.append(Strings.t("part.stat.damper", [
					int(round(100.0 * ShipFit.damper_share(part.stat_modifiers[stat], Constants.LAW_SHIP_REF_MASS))), Constants.LAW_DAMPER_POWER_PER_KG * part.stat_modifiers[stat]]))
				continue
			var label: Array = STAT_LABELS.get(stat, ["", 1.0])
			effects.append(Strings.t(label[0], [part.stat_modifiers[stat] * label[1]]) if label[0] != "" else "%+d %s" % [part.stat_modifiers[stat], stat])
		return Strings.t("part.module_detail", [Strings.t("size." + str(ShipFit.module_mount_size(part))), PoolStringArray(effects).join(", "), part.mass / 1000.0])
	return ""


func _rebuild_slots(ship_body) -> void:
	_clear(_slots)
	var sizes: Array = ShipFit.tool_slot_sizes(ship_body.ship_template)
	for i in range(ship_body.fit.tools.size()):
		var part_id: String = ship_body.fit.tools[i]
		_add_button(_slots, Strings.t("fit.slot.tool", [Strings.t("size." + str(sizes[i])), Fitting.part_name(part_id) if part_id != "" else Strings.t("fit.slot.empty")]), part_id == "", "_on_unfit", ["tools", i])
	for i in range(ship_body.fit.modules.size()):
		var part_id: String = ship_body.fit.modules[i]
		_add_button(_slots, Strings.t("fit.slot.module", [Strings.t("size." + str(ShipFit.module_slot_size(ship_body.ship_template))), Fitting.part_name(part_id) if part_id != "" else Strings.t("fit.slot.empty")]), part_id == "", "_on_unfit", ["modules", i])


func _rebuild_storage(_ship_body) -> void:
	_clear(_storage)
	var ids: Array = GameState.player_storage.keys()
	ids.sort()
	if ids.empty():
		_add_note(_storage, Strings.t("fit.storage.empty"))
	for i in range(ids.size()):
		var part_id: String = ids[i]
		_add_row(_storage, i, "%s  x%d" % [Fitting.part_name(part_id), GameState.player_storage[part_id]], part_detail(part_id),
			[[Strings.t("fit.button.fit"), false, "_on_fit", [part_id]], [Strings.t("fit.button.sell", [Fitting.sale_price(part_id)]), false, "_on_sell", [part_id]]], true)


func _rebuild_tabs() -> void:
	_clear(_tabs)
	for tab in STORE_TABS if Fitting.is_available() else ["cargo"]:
		var button: Button = _add_button(_tabs, ("[%s]" if tab == _tab else "%s") % Strings.t("fit.store." + tab), false, "_on_tab", [tab])
		button.align = Button.ALIGN_CENTER
		button.theme_type_variation = "TabButton"
		button.size_flags_horizontal = SIZE_EXPAND_FILL


func _rebuild_store(ship_body) -> void:
	_rebuild_tabs()
	_clear(_store)
	_ship_rows = {}
	_preview.visible = _tab == "ships"
	match _tab:
		"ships":
			_add_note(_store, Strings.t("fit.store.ships.note"))
			_store_ships()
			preview_ship(_preview.ship_id if _ship_rows.has(_preview.ship_id) else GameState.player_ship_template_id)
		"weapons":
			_store_parts(store_groups(true))
		"equipment":
			_store_parts(store_groups(false, true))
		"modules":
			_store_parts(store_groups(false))
		"cargo":
			_store_cargo(ship_body)


# Ships by weight class, proven designs first, then by price.
func _store_ships() -> void:
	var groups := {}
	for ship_id in Fitting.ship_catalog():
		var weight: String = PresetClassifier.ship_weight(TemplateDatabase.get_template(ship_id))
		if not groups.has(weight):
			groups[weight] = []
		groups[weight].append(ship_id)
	for weight in Constants.PRESET_WEIGHT_CLASSES:
		var ids: Array = groups.get(weight[0], [])
		if ids.empty():
			continue
		ids.sort_custom(self, "_ships_first")
		if not _add_group_heading(Strings.t("fit.hulls." + str(weight[0])), ids.size()):
			continue
		for i in range(ids.size()):
			var ship_id: String = ids[i]
			var flying: bool = ship_id == GameState.player_ship_template_id
			var cost: int = Fitting.ship_cost(ship_id)
			var label: String = Strings.t("fit.button.flying") if flying else (Strings.t("fit.button.buy", [cost]) if cost >= 0 else Strings.t("fit.button.buy_get", [-cost]))
			var title: String = Fitting.part_name(ship_id) + ("  " + Strings.t("fit.proven") if TemplateDatabase.proven_presets.has(ship_id) else "")
			var row: Control = _add_row(_store, i, title, describe_ship(ship_id), [[label, flying or GameState.player_bank < cost, "_on_buy_ship", [ship_id]]])
			_add_ship_stats(row, ship_id)
			row.connect("gui_input", self, "_on_ship_row_input", [ship_id])
			_ship_rows[ship_id] = row


# [heading, [part ids]] pairs for a tab (weapons; equipment: other tools; else modules), each
# kind's parts by mount size then price.
func store_groups(weapons: bool, equipment: bool = false) -> Array:
	var kinds := {}
	for part_id in Fitting.catalog():
		var part = TemplateDatabase.get_template(part_id)
		var kind: String = part_kind(part)
		if part is UtilityToolTemplate:
			if (part.tool_type in WEAPON_TYPES) != weapons or not (weapons or equipment):
				continue
		elif weapons or equipment:
			continue
		if not kinds.has(kind):
			kinds[kind] = []
		kinds[kind].append(part_id)
	var names: Array = kinds.keys()
	names.sort()
	var groups: Array = []
	for kind in names:
		kinds[kind].sort_custom(self, "_parts_first")
		groups.append([kind, kinds[kind]])
	return groups


func _store_parts(groups: Array) -> void:
	if groups.empty():
		_add_note(_store, Strings.t("fit.store.nothing"))
	for group in groups:
		var kind_key: String = "kind." + str(group[0])
		if not _add_group_heading(Strings.t(kind_key) if Strings.has(kind_key) else group[0].replace("_", " ").to_upper(), group[1].size()):
			continue
		for i in range(group[1].size()):
			var part_id: String = group[1][i]
			var cost: int = Fitting.price(part_id)
			_add_row(_store, i, Fitting.part_name(part_id), part_detail(part_id), [[Strings.t("fit.button.buy", [cost]), GameState.player_bank < cost, "_on_buy", [part_id]]])


# The hold, sold here a unit or all at once at this station's price (salvage too), and what the
# station makes, bought at its price (Fitting.cargo_stock): any station, as NPC traders trade.
func _store_cargo(ship_body) -> void:
	_add_heading(_store, Strings.t("fit.cargo.heading", [ship_body.get_cargo_units(), ship_body.cargo_capacity]))
	var worth: int = Market.hold_value(ship_body, GameState.player_docked_at).units
	_add_button(_store, Strings.t("fit.button.sell_hold"), worth <= 0, "_on_sell_hold", [])
	var stock: Array = Fitting.cargo_stock()
	var ids: Array = stock.duplicate()
	for commodity_id in ship_body.cargo:
		if not commodity_id in ids:
			ids.append(commodity_id)
	if ids.empty():
		_add_note(_store, Strings.t("fit.cargo.empty"))
	for i in range(ids.size()):
		var commodity_id: String = ids[i]
		var held: int = int(ship_body.cargo.get(commodity_id, 0))
		var sale: int = Fitting.cargo_sale_price(commodity_id)
		var buttons: Array = []
		if commodity_id in stock:
			var cost: int = Fitting.cargo_price(commodity_id)
			buttons.append([Strings.t("fit.button.buy", [cost]), GameState.player_bank < cost or ship_body.get_free_cargo() <= 0, "_on_buy_cargo", [commodity_id]])
		if sale <= 0:
			buttons.append([Strings.t("fit.button.not_bought"), true, "_on_sell_cargo", [commodity_id, 1]])
		else:
			buttons.append([Strings.t("fit.button.sell", [sale]), held <= 0, "_on_sell_cargo", [commodity_id, 1]])
			buttons.append([Strings.t("fit.button.sell_all", [sale * held]), held <= 1, "_on_sell_cargo", [commodity_id, -1]])
		_add_row(_store, i, Fitting.part_name(commodity_id), Strings.t("fit.cargo.held", [held]), buttons)


static func part_kind(part) -> String:
	if part is UtilityToolTemplate:
		return part.tool_type
	if part is ModuleTemplate:
		if part.module_kind != "":
			return part.module_kind
		return "lance" if not part.lance.empty() else "other"
	return "other"


# A hull's role (and its evolved pilot's temperament), then its fit; its numbers are ShipStats' (_add_ship_stats).
static func describe_ship(ship_id: String) -> String:
	var ship = TemplateDatabase.get_template(ship_id)
	if not ship is ShipTemplate:
		return ship_id
	var fitted: Array = []
	for part_id in ship.equipped_tools + ship.equipped_modules:
		if str(part_id) != "":
			fitted.append(Fitting.part_name(str(part_id)))
	var agent = TemplateDatabase.preset_agents.get(ship_id)
	var role: String = agent.role if agent != null and agent.role != "" else PresetClassifier.ship_role(ship, agent.behavior if agent != null else {})
	if agent != null and agent.temperament != "":
		role = Strings.t("role." + role) if Strings.has("role." + role) else role
		role += ", " + (Strings.t("temper." + agent.temperament) if Strings.has("temper." + agent.temperament) else agent.temperament)  # How its evolved pilot flies it (NPCs; a hint to the player)
	elif Strings.has("role." + role):
		role = Strings.t("role." + role)
	var fit_note: String = Strings.t("fit.evolved_with") if TemplateDatabase.presets.has(ship_id) else Strings.t("fit.comes_with")
	return "%s\n%s" % [role.to_upper(), (fit_note + " " + PoolStringArray(fitted).join(", ")) if not fitted.empty() else Strings.t("fit.bare_hull")]


# A store hull's numbers as it comes fitted (ShipStats, brief: as the ship flown's header shows
# them), between its name and its role.
func _add_ship_stats(row: Control, ship_id: String) -> void:
	var ship = TemplateDatabase.get_template(ship_id)
	if not ship is ShipTemplate:
		return
	var stats: Dictionary = ShipFit.compute_stats(ship, {"tools": ship.equipped_tools, "modules": ship.equipped_modules})
	var strip: GridContainer = ShipStats.new_grid(STORE_STAT_COLUMNS)
	row.get_node("Row/Text").add_child_below_node(row.get_node("Row/Text/Name"), strip)
	ShipStats.fill(strip, ShipStats.entries(stats, float(stats.get("mass", ship.mass)), ship, true))


func _ships_first(a: String, b: String) -> bool:
	var proven_a: bool = TemplateDatabase.proven_presets.has(a)
	if proven_a != TemplateDatabase.proven_presets.has(b):
		return proven_a
	return Fitting.price(a) < Fitting.price(b)


func _parts_first(a: String, b: String) -> bool:
	var size_a: int = ShipFit.SIZES.find(str(TemplateDatabase.get_template(a).get("mount_size")))
	var size_b: int = ShipFit.SIZES.find(str(TemplateDatabase.get_template(b).get("mount_size")))
	if size_a != size_b:
		return size_a < size_b
	return Fitting.price(a) < Fitting.price(b)


func _add_heading(container: Node, text: String) -> void:
	if container.get_child_count() > 0:
		_add_gap(container, 10)
	var heading: Label = HeadingScene.instance()
	heading.text = text
	container.add_child(heading)


# A store heading that folds its group away when tapped; returns whether the group shows.
func _add_group_heading(title: String, count: int) -> bool:
	var key: String = _tab + "/" + title
	var folded: bool = _folded.get(key, _tab != "ships" and count > GROUP_OPEN_MAX)
	if _store.get_child_count() > 0:
		_add_gap(_store, 6)
	_add_button(_store, "%s  (%d)  %s" % [title, count, "+" if folded else "-"], false, "_on_fold", [key, not folded], GroupHeadingScene)
	return not folded


func _add_gap(container: Node, height: float) -> void:
	var gap := Control.new()
	gap.rect_min_size = Vector2(0, height)
	container.add_child(gap)


func _add_note(container: Node, text: String) -> void:
	var note: Label = NoteScene.instance()
	note.text = text
	container.add_child(note)


# A row: `title` over `detail` (dimmer, wrapping), and its buttons ([text, disabled, method, binds])
# beside them. Every other row is shaded, so rows read apart.
# `stacked`: the buttons one over another and a long name wrapped, not cut (the narrow storage
# column: beside two buttons its names were cut to a dozen letters).
func _add_row(container: Node, index: int, title: String, detail: String, buttons: Array, stacked: bool = false) -> Control:
	var panel: PanelContainer = RowScene.instance()
	if index % 2 != 0:
		panel.self_modulate = Color(1, 1, 1, 0)  # Unshaded: the panel's own look only, not its contents
	container.add_child(panel)
	var name_label: Label = panel.get_node("Row/Text/Name")
	name_label.text = title.to_upper()
	var detail_label: Label = panel.get_node("Row/Text/Detail")
	detail_label.text = detail
	detail_label.visible = detail != ""
	var holder: Node = panel.get_node("Row")
	if stacked:
		name_label.clip_text = false
		name_label.autowrap = true
		holder = VBoxContainer.new()
		holder.alignment = BoxContainer.ALIGN_CENTER
		panel.get_node("Row").add_child(holder)
	for spec in buttons:
		_add_button(holder, spec[0], spec[1], spec[2], spec[3], RowButtonScene)
	return panel


# Shows `ship_id`'s hull in the preview and marks its row.
func preview_ship(ship_id: String) -> void:
	for other_id in _ship_rows:  # Every other row back to its own look (the scene's style, its line's shade)
		var other = _ship_rows[other_id]
		if other_id != ship_id and is_instance_valid(other) and other.has_meta("look"):
			var look: Array = other.get_meta("look")
			other.add_stylebox_override("panel", look[0])
			other.self_modulate = look[1]
			other.remove_meta("look")
	_preview.show_ship(ship_id)
	var row = _ship_rows.get(ship_id)
	if is_instance_valid(row) and not row.has_meta("look"):
		var own: StyleBox = row.get_stylebox("panel")
		row.set_meta("look", [own, row.self_modulate])
		var style: StyleBoxFlat = own.duplicate()
		style.bg_color = SELECTED_SHADE
		row.add_stylebox_override("panel", style)
		row.self_modulate = Color(1, 1, 1, 1)  # Shaded even on an unshaded line


func _on_ship_row_input(event: InputEvent, ship_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		preview_ship(ship_id)


func _add_button(container: Node, text: String, disabled: bool, method: String, binds: Array, scene: PackedScene = ButtonScene) -> Button:
	var button: Button = scene.instance()
	button.text = text.to_upper()  # Like the HUD buttons
	button.disabled = disabled
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


func _on_fold(key: String, folded: bool) -> void:
	_folded[key] = folded
	refresh()


# FITTING: the ship beside storage; MARKET: storage beside the store.
func show_view(which: String) -> void:
	view = which
	refresh()


func _on_tab(tab: String) -> void:
	_tab = tab
	refresh()
	_store_scroll.scroll_vertical = 0


func _on_buy(part_id: String) -> void:
	_report(Fitting.buy(part_id), Strings.t("fit.done.bought", [Fitting.part_name(part_id)]))


func _on_buy_ship(ship_id: String) -> void:
	_report(Fitting.buy_ship(ship_id), Strings.t("fit.done.new_ship", [Fitting.part_name(ship_id)]))


func _on_buy_cargo(commodity_id: String) -> void:
	_report(Fitting.buy_cargo(GlobalRefs.player_agent_body, commodity_id), Strings.t("fit.done.bought_one", [Fitting.part_name(commodity_id)]))


func _on_sell_cargo(commodity_id: String, units: int) -> void:
	var body = GlobalRefs.player_agent_body
	var count: int = int(body.cargo.get(commodity_id, 0)) if units < 0 else units
	var price: int = Fitting.cargo_sale_price(commodity_id)
	_report(Fitting.sell_cargo(body, commodity_id, units), Strings.t("fit.done.sold_cargo", [count, Fitting.part_name(commodity_id), count * price]))


func _on_sell_hold() -> void:
	var sold: Dictionary = Fitting.sell_hold(GlobalRefs.player_agent_body)
	_report("" if sold.units > 0 else Strings.t("fit.err.nothing_buys"), Strings.t("fit.done.sold_hold", [sold.units, sold.banked]))


func _on_sell(part_id: String) -> void:
	_report(Fitting.sell(part_id), Strings.t("fit.done.sold", [Fitting.part_name(part_id), Fitting.sale_price(part_id)]))


func _on_fit(part_id: String) -> void:
	_report(Fitting.fit_part(GlobalRefs.player_agent_body, part_id), Strings.t("fit.done.fitted", [Fitting.part_name(part_id)]))


func _on_unfit(kind: String, slot: int) -> void:
	var part_id: String = GlobalRefs.player_agent_body.fit[kind][slot]
	_report(Fitting.unfit(GlobalRefs.player_agent_body, kind, slot), Strings.t("fit.done.unfitted", [Fitting.part_name(part_id)]))
