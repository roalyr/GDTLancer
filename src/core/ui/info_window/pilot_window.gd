# PilotWindow (scenes/ui/menus/pilot_window.tscn): the HUD's PILOT button. The player, read only:
# bank, home, ship and storage, play time; standing with each faction (a bar and its word, what it
# means for you, whom the faction is at war with); the bounties posted on you; and work: whom you
# escort and the patrol time each faction owes you, paid when you dock at one of its havens.

extends "res://src/core/ui/info_window/info_window.gd"

const Fitting = preload("res://src/core/systems/fitting.gd")
const Standing = preload("res://src/core/systems/standing.gd")
const Wages = preload("res://src/core/systems/wages.gd")
const TargetKinds = preload("res://src/core/ui/main_hud/target_kinds.gd")

const BAR_SIZE = Vector2(240, 10)
const BAR_BACK = Color(1, 1, 1, 0.12)
const STANDING_SIDES = {"HOSTILE": "hostile", "FRIENDLY": "allied", "NEUTRAL": "neutral"}  # Its colour, as the HUD's sides


func fill() -> void:
	_title.text = "PILOT  -  BANK %d WP" % GameState.player_bank
	var stored: int = 0
	for part_id in GameState.player_storage:
		stored += int(GameState.player_storage[part_id])
	_summary.text = "HOME %s   FLYING %s   STORAGE %d PARTS   PLAYED %s" % [
		station_name(GameState.home_location_id).to_upper(), Fitting.part_name(GameState.player_ship_template_id).to_upper(),
		stored, duration_text(GameState.play_time).to_upper()]
	_fill_standing()
	_fill_bounties()
	_fill_work()


func _fill_standing() -> void:
	add_heading("Standing")
	var ids: Array = TemplateDatabase.factions.keys()
	ids.sort()
	for faction in ids:
		var spec: Dictionary = TemplateDatabase.factions[faction]
		var name: String = str(spec.get("name", faction))
		var war: Array = []
		for enemy in spec.get("enemies", []):
			war.append(str(TemplateDatabase.factions.get(enemy, {}).get("name", enemy)))
		var war_line: String = ("At war with " + PoolStringArray(war).join(", ") + ".") if not war.empty() else "At war with no one."
		if not Standing.has_standing(faction):
			add_row(name, "Keeps no standing: answers what you do there and then. " + war_line)
			continue
		var word: String = Standing.label(faction)
		var row: Control = add_row("%s  %s" % [name, word], standing_meaning(faction, word) + " " + war_line)
		row.get_node("Row/Text/Name").add_color_override("font_color", TargetKinds.side_color(STANDING_SIDES[word]))
		row.get_node("Row").add_child(_standing_bar(Standing.of(faction), TargetKinds.side_color(STANDING_SIDES[word])))


# What a standing means for the player, in a line.
static func standing_meaning(faction: String, word: String) -> String:
	var spec: Dictionary = TemplateDatabase.factions.get(faction, {})
	match word:
		"HOSTILE":
			return "Its ships attack you on sight; its stations refuse you."
		"FRIENDLY":
			return "Its best prices." + (" Pays you for time at its pickets." if spec.get("patrol_wages", false) else "")
	return "Fair prices; it trades and docks you." + (" Friendly, it would pay for patrols." if spec.get("patrol_wages", false) else "")


# A bar from hated (left) to trusted (right), filled from its middle to the standing.
func _standing_bar(value: float, color: Color) -> Control:
	var holder := CenterContainer.new()
	var bar := ColorRect.new()
	bar.rect_min_size = BAR_SIZE
	bar.color = BAR_BACK
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(bar)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = color
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	var share: float = 0.5 + 0.5 * clamp(value, -1.0, 1.0)
	fill.anchor_left = min(0.5, share)
	fill.anchor_right = max(0.5, share)
	fill.anchor_bottom = 1.0
	bar.add_child(fill)
	var middle := ColorRect.new()
	middle.color = Color(1, 1, 1, 0.5)
	middle.mouse_filter = MOUSE_FILTER_IGNORE
	middle.anchor_left = 0.5
	middle.anchor_right = 0.5
	middle.anchor_bottom = 1.0
	middle.margin_left = -1.0
	middle.margin_right = 1.0
	bar.add_child(middle)
	return holder


func _fill_bounties() -> void:
	add_heading("Bounties on you")
	var total: int = 0
	for faction in GameState.player_bounties:
		var amount: int = int(GameState.player_bounties[faction])
		if amount <= 0:
			continue
		total += amount
		add_row("%s  %d WP" % [TemplateDatabase.factions.get(faction, {}).get("name", faction), amount], "")
	if total <= 0:
		add_note("None.")
	else:
		add_note("Hunters claim them by killing you; they lapse when your ship is lost.")


func _fill_work() -> void:
	add_heading("Work")
	var ship = GlobalRefs.player_agent_body
	var any: bool = false
	var controller = ship.get_node_or_null("PlayerInputHandler") if is_instance_valid(ship) else null
	var ward = controller.get("escort_ward") if controller != null else null
	if is_instance_valid(ward):
		any = true
		add_row("Escorting %s" % str(ward.ship_template.ship_model_name if is_instance_valid(ward.get("ship_template")) else ward.name),
			"A share of its cargo sales is yours while you keep by it; its faction may pay the time as patrol.")
	var time: Dictionary = ship.get_meta("patrol_time") if is_instance_valid(ship) and ship.has_meta("patrol_time") else {}
	for faction in time:
		var seconds: float = float(time[faction])
		if seconds < 1.0:
			continue
		any = true
		var spec: Dictionary = TemplateDatabase.factions.get(faction, {})
		var wage: int = Wages.patrol_wage(faction, ship.get_value(), seconds)
		add_row("%s patrol  %s" % [spec.get("name", faction), duration_text(seconds)],
			"About %d WP, paid when you dock at one of its havens%s." % [wage, "" if Standing.of(faction) >= Constants.STANDING_FRIENDLY else ", if it still thinks you a friend"])
	if not any:
		add_note("Nothing under way. Armed, friendly factions pay for time at their pickets; INTERACT a worker to escort it.")
