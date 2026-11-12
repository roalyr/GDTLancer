# Interactions: what the player may ask of the selected NPC ship, the INTERACT button's window
# (InteractionWindow). The player asks and the NPC says yes to whatever applies (no NPC decision
# making yet); each is the player's side of something NPCs already do with each other:
# - "escort": the player escorts a worker (Wages.can_escort): its share of the worker's sales.
# - "hire": an armed NPC of a faction that hires escorts (allied) escorts the player as it would a
#   worker of its own: guards it, and takes ESCORT_SHARE of the player's cargo sales within
#   ESCORT_PAY_RANGE (Wages.pay_player_escorts).
# - "wing": an armed NPC (allied) follows the player as its group's leader: keeps by it, guards it,
#   and joins the fights the player starts (ShipControllerAI._join_player_fight).
# - "caravan": the player travels in an allied trader's caravan (on its way, or mustering: the muster
#   is gathered at once); the trader keeps the player's pace (ShipControllerAI.get_caravan).
# Hostile ships offer nothing. An interaction holds until the player deselects it in the window, or
# the NPC lets go (too far, docked at the end of a caravan, killed: EventBus.player_interaction_ended).
# Ships in an interaction with the player are its partners (filled marks, arrows on the threat ring).

extends Reference

const Wages = preload("res://src/core/systems/wages.gd")
const Standing = preload("res://src/core/systems/standing.gd")

const KINDS = ["escort", "hire", "wing", "caravan"]
const LABELS = {"escort": "ESCORT IT", "hire": "HIRE AS ESCORT", "wing": "LEAD IT IN YOUR WING", "caravan": "JOIN ITS CARAVAN"}


static func controller_of(player):
	return player.get_node_or_null(Constants.PLAYER_INPUT_HANDLER_NAME) if is_instance_valid(player) else null


static func ai_of(ship):
	return ship.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME) if is_instance_valid(ship) and ship is Node else null


# Whether `ship` is an NPC ship the player can ask anything of at all: live, out in space, not a platform.
static func is_npc_ship(ship) -> bool:
	if not (is_instance_valid(ship) and ship is Node and ship.is_inside_tree()) or ship.get("is_wreck") or ship.get("is_docked") or ship.get("is_platform"):
		return false
	if ship.has_method("is_player") and ship.is_player():
		return false
	var ai = ai_of(ship)
	return ai != null and ai.has_method("player_role")


static func is_allied(faction) -> bool:
	return Standing.has_standing(faction) and Standing.of(faction) >= Constants.STANDING_FRIENDLY


static func _armed(ship) -> bool:
	return ship.has_method("get_damage_per_second") and ship.get_damage_per_second() > 0.0


# Whether the player has `kind` going with `ship` now.
static func is_active(player, ship, kind: String) -> bool:
	if not is_instance_valid(ship):
		return false
	match kind:
		"escort":
			var controller = controller_of(player)
			return controller != null and controller.get("escort_ward") == ship
		"hire", "wing":
			var ai = ai_of(ship)
			return ai != null and ai.has_method("player_role") and ai.player_role() == kind
		"caravan":
			var ai = ai_of(ship)
			return ai != null and ai.has_method("has_player_mate") and ai.has_player_mate()
	return false


# Why `kind` cannot be asked of `ship` now, "" if it can.
static func why_not(player, ship, kind: String) -> String:
	if not is_npc_ship(ship):
		return "Not a ship that can be asked"
	if ship.has_method("is_enemy_of") and ship.is_enemy_of(player):
		return "Hostile"
	var faction = ship.get("faction")
	var ai = ai_of(ship)
	match kind:
		"escort":
			if not _armed(player):
				return "You carry no weapons"
			return "" if Wages.can_escort(player, ship) else "Not a worker of a faction that takes escorts"
		"hire", "wing":
			if not is_allied(faction):
				return "Only allies follow you"
			if not _armed(ship) or Wages.is_worker(ship):
				return "Not a fighting ship"
			if kind == "hire" and not TemplateDatabase.factions.get(faction, {}).get("escorts", false):
				return "Its faction does not escort"
			if not is_active(player, ship, "hire") and not is_active(player, ship, "wing") and followers(player).size() >= Constants.PLAYER_FOLLOWERS_MAX:
				return "You have %d ships with you already" % Constants.PLAYER_FOLLOWERS_MAX
			return ""
		"caravan":
			if not is_allied(faction):
				return "Only allies take you in their caravan"
			if not (ai.has_method("is_trader") and ai.is_trader()):
				return "Not a trader"
			if ai.bound_for() == null and ai.mustering_at() == null:
				return "Not on its way anywhere"
			return ""
	return "Unknown"


# What the window offers for `ship`: [{"kind", "label", "active", "note"}], the kinds that apply now
# and those going (to deselect), in KINDS order.
static func options(player, ship) -> Array:
	var found: Array = []
	for kind in KINDS:
		var active: bool = is_active(player, ship, kind)
		if active or why_not(player, ship, kind) == "":
			found.append({"kind": kind, "label": LABELS[kind], "active": active, "note": describe(ship, kind)})
	return found


# One line on what `kind` means with `ship`.
static func describe(ship, kind: String) -> String:
	var share: int = int(Constants.ESCORT_SHARE * 100)
	var km: float = Constants.ESCORT_PAY_RANGE / 1000.0
	match kind:
		"escort":
			return "Keep by it and guard it: %d%% of its sales while within %.0f km of it" % [share, km]
		"hire":
			return "It keeps by you and guards you, for %d%% of your cargo sales while within %.0f km" % [share, km]
		"wing":
			return "It keeps by you, guards you and joins the fights you start"
		"caravan":
			var ai = ai_of(ship)
			var station = ai.bound_for() if ai != null and ai.has_method("bound_for") else null
			var where: String = str(station.get("station_name")) if is_instance_valid(station) and station.get("station_name") != null else ""
			return "Travel with it%s: it keeps your pace" % ((" to " + where) if where != "" else "")
	return ""


# Starts `kind` with `ship`, or ends it if it is going. Returns a line for the player.
static func toggle(player, ship, kind: String) -> String:
	var controller = controller_of(player)
	var ai = ai_of(ship)
	if controller == null:
		return ""
	if is_active(player, ship, kind):
		match kind:
			"escort":
				controller.set_escort_ward(null)
			"hire", "wing":
				ai.release_player()
			"caravan":
				ai.dismiss_player()
		EventBus.emit_signal("player_interactions_changed")
		return "%s: %s ended" % [name_of(ship), LABELS[kind].capitalize()]
	var why: String = why_not(player, ship, kind)
	if why != "":
		return why
	match kind:
		"escort":
			controller.set_escort_ward(ship)
		"hire", "wing":
			ai.follow_player(player, kind == "wing")
		"caravan":
			for other in partners(player):  # One caravan at a time
				if other != ship and is_active(player, other, "caravan"):
					ai_of(other).dismiss_player()
			ai.admit_player(player)
	EventBus.emit_signal("player_interactions_changed")
	return "%s: %s" % [name_of(ship), describe(ship, kind)]


# The NPC ships the player is in an interaction with now, either way.
static func partners(player) -> Array:
	var found: Array = []
	if not (is_instance_valid(player) and player.is_inside_tree()):
		return found
	var controller = controller_of(player)
	var ward = controller.get("escort_ward") if controller != null else null
	if is_instance_valid(ward):
		found.append(ward)
	for ship in player.get_tree().get_nodes_in_group("agent_body"):
		if ship == player or ship in found or not is_instance_valid(ship) or ship.get("is_wreck"):
			continue
		var ai = ai_of(ship)
		if ai != null and ai.has_method("player_role") and (ai.player_role() != "" or ai.has_player_mate()):
			found.append(ship)
	return found


# The NPCs keeping by the player: hired or in its wing.
static func followers(player) -> Array:
	var found: Array = []
	for ship in partners(player):
		var ai = ai_of(ship)
		if ai != null and ai.has_method("player_role") and ai.player_role() != "":
			found.append(ship)
	return found


static func name_of(ship) -> String:
	var template = ship.get("ship_template") if is_instance_valid(ship) else null
	var model: String = template.ship_model_name if is_instance_valid(template) else str(ship.name)
	var faction: String = ship.get_faction_name() if ship.has_method("get_faction_name") else ""
	return ("%s %s" % [faction, model]).strip_edges()
