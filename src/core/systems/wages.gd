# Wages: pay for guarding, for everyone alike, the player included (Constants ESCORT_* and
# PATROL_WAGE_*).
# - Escorts: an armed ship keeping by a worker (a prospector or scavenger: is_worker) of a faction
#   that hires escorts is its escort (ShipControllerAI ward; the player's: PlayerControllerShip,
#   the INTERACT button). When the worker sells its hold, ESCORT_SHARE of the sale goes to its escorts
#   within ESCORT_PAY_RANGE, split between them.
# - Patrols: a faction that pays patrol wages pays an armed ship that docks at one of its havens for
#   the time it spent at its pickets since it last docked (BeaconNetwork counts it: on_patrol; up
#   to PATROL_WAGE_MAX_TIME), PATROL_WAGE_SHARE_PER_HOUR of its value an hour: its own ships, and
#   the player once its standing with the faction is friendly (its pickets are on the HUD, and
#   arriving at one says so).
# Paid into the bank (the player) or the life's takings (Evolution).

extends Reference

const Standing = preload("res://src/core/systems/standing.gd")


# Whether `ship` is a worker that can be escorted: a live NPC that mines or carries no weapons.
static func is_worker(ship) -> bool:
	if not (is_instance_valid(ship) and ship.is_inside_tree()) or ship.get("is_wreck") or ship.get("is_docked"):
		return false
	if ship.has_method("is_player") and ship.is_player():
		return false
	var ai = ship.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	if ai == null:
		return false
	return (ai.has_method("is_prospector") and ai.is_prospector()) or (ai.has_method("is_trader") and ai.is_trader()) or (ship.has_method("get_damage_per_second") and ship.get_damage_per_second() <= 0.0)


# Whether `escort` may escort `ward`: armed, the ward a worker of a faction that hires escorts, and
# its own faction's (the player: one whose standing with it is not hostile).
static func can_escort(escort, ward) -> bool:
	if not (is_instance_valid(escort) and is_worker(ward)) or escort == ward:
		return false
	var faction: String = str(ward.get("faction"))
	if not TemplateDatabase.factions.get(faction, {}).get("escorts", false):
		return false
	if not (escort.has_method("get_damage_per_second") and escort.get_damage_per_second() > 0.0):
		return false
	if escort.has_method("is_player") and escort.is_player():
		return not Standing.is_hostile(faction)
	return str(escort.get("faction")) == faction


# The ward sold its hold for `value`: its escorts in range take their share. Returns what they took.
static func pay_escorts(ward, value: int) -> int:
	var ai = ward.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME) if is_instance_valid(ward) else null
	if ai == null or not ai.has_method("get_escorts") or value <= 0:
		return 0
	var near: Array = []
	for escort in ai.get_escorts():
		if not escort.get("is_wreck") and escort.global_transform.origin.distance_to(ward.global_transform.origin) <= Constants.ESCORT_PAY_RANGE:
			near.append(escort)
	if near.empty():
		return 0
	var each: int = int(round(value * Constants.ESCORT_SHARE / near.size()))
	for escort in near:
		_pay(escort, each, "Escort pay from %s: %d WP" % [_name(ward), each])
	return each * near.size()


# `ship` was counted at `beacon` (BeaconNetwork, every `seconds`): at a picket of a faction that
# pays wages, armed, and its own or (the player) a friend of it, that is time on its patrol.
static func on_patrol(ship, beacon, seconds: float, arrived: bool) -> void:
	if beacon.kind != "patrol" or not TemplateDatabase.factions.get(beacon.faction, {}).get("patrol_wages", false):
		return
	if not (ship.has_method("get_damage_per_second") and ship.get_damage_per_second() > 0.0):
		return
	var is_player: bool = ship.has_method("is_player") and ship.is_player()
	if is_player:
		if not Standing.has_standing(beacon.faction) or Standing.of(beacon.faction) < Constants.STANDING_FRIENDLY:
			return
	elif str(ship.get("faction")) != beacon.faction:
		return
	var time: Dictionary = ship.get_meta("patrol_time") if ship.has_meta("patrol_time") else {}
	time[beacon.faction] = float(time.get(beacon.faction, 0.0)) + seconds
	ship.set_meta("patrol_time", time)
	if is_player and arrived:
		EventBus.emit_signal("announcement", "%s: on %s patrol, paid at its havens" % [beacon.get_display_name(), TemplateDatabase.factions[beacon.faction].get("name", beacon.faction)], "info")


# The worker `ship` escorts now, within ESCORT_PAY_RANGE: an NPC's ward, or the player's
# (PlayerControllerShip escort_ward); null if none.
static func escorted_ward(ship):
	var ward = null
	var ai = ship.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	if ai != null and ai.has_method("get_ward"):
		ward = ai.get_ward()
	elif ship.has_method("is_player") and ship.is_player():
		var controller = ship.get_node_or_null("PlayerInputHandler")  # PlayerControllerShip (player_agent.tscn)
		ward = controller.get("escort_ward") if controller != null else null
	if not (is_instance_valid(ward) and ward.is_inside_tree()) or ward.get("is_wreck"):
		return null
	if ward.global_transform.origin.distance_to(ship.global_transform.origin) > Constants.ESCORT_PAY_RANGE:
		return null
	return ward


# `seconds` more escorting: counted with the ship's patrol time for the ward's faction (if it pays
# patrol wages), so the faction pays it at its havens by the hour and by the ship's value, as a patrol:
# a big escort earns as much for its cost as a small one (its share of the ward's sales comes besides).
static func on_escort(ship, seconds: float) -> void:
	var ward = escorted_ward(ship)
	if ward == null:
		return
	var faction: String = str(ward.get("faction"))
	if not TemplateDatabase.factions.get(faction, {}).get("patrol_wages", false):
		return
	var time: Dictionary = ship.get_meta("patrol_time") if ship.has_meta("patrol_time") else {}
	time[faction] = float(time.get(faction, 0.0)) + seconds
	ship.set_meta("patrol_time", time)


# The time `ship` has patrolled for `faction` since it last took it, and starts the count over.
static func take_patrol_time(ship, faction: String) -> float:
	if not (is_instance_valid(ship) and ship.has_meta("patrol_time")):
		return 0.0
	var time: Dictionary = ship.get_meta("patrol_time")
	var seconds: float = float(time.get(faction, 0.0))
	time.erase(faction)
	return seconds


# What `faction` pays a ship of `value` for `seconds` on patrol (0 if it pays no wages).
static func patrol_wage(faction: String, value: float, seconds: float) -> int:
	if not TemplateDatabase.factions.get(faction, {}).get("patrol_wages", false):
		return 0
	return int(round(value * Constants.PATROL_WAGE_SHARE_PER_HOUR * clamp(seconds, 0.0, Constants.PATROL_WAGE_MAX_TIME) / 3600.0))


# The player docked at `faction`'s station after `seconds` at its pickets: its patrol wage, if the
# faction thinks well enough of it and its ship is armed. Returns what was paid.
static func pay_player_patrol(ship, faction: String, seconds: float) -> int:
	if not Standing.has_standing(faction) or Standing.of(faction) < Constants.STANDING_FRIENDLY:
		return 0
	if not (is_instance_valid(ship) and ship.has_method("get_damage_per_second") and ship.get_damage_per_second() > 0.0):
		return 0
	var wage: int = patrol_wage(faction, ship.get_value(), seconds)
	if wage > 0:
		GameState.player_bank += wage
	return wage


static func _name(ship) -> String:
	var template = ship.get("ship_template")
	return template.ship_model_name if is_instance_valid(template) else str(ship.name)


static func _pay(ship, amount: int, message: String) -> void:
	if amount <= 0:
		return
	if ship.has_method("is_player") and ship.is_player():
		GameState.player_bank += amount
		EventBus.emit_signal("announcement", message, "info")
	else:
		Evolution.pay(str(ship.get("evo_uid")), amount, "escort_paid")
