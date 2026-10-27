# Bounty: prices on ships, for everyone alike, the player included. Two kinds:
# - War: every faction pays BOUNTY_WAR_SHARE of a ship's value (Agent.get_value) for killing a ship of
#   a faction it is at war with.
# - Posted: a faction whose ship is killed posts BOUNTY_POST_SHARE of the victim's value on the killer
#   (Agent.bounties, the player's in GameState.player_bounties), and it adds up kill by kill; an ace
#   is worth hunting.
# A kill pays the killer what the victim carried that the killer can claim (claims: its own faction's
# postings and those of factions not at war with it; for the player, those of factions whose standing
# is not hostile), the war bounty once, and the victim's postings lapse. Paid on the kill: into the
# bank (the player), the life's takings (Evolution) or the wallet. Ships hunt a ship carrying a claim
# worth BOUNTY_HUNT_SHARE of their own value (Agent.is_enemy_of). The player's postings lapse when
# the ship is lost.

extends Reference

const Standing = preload("res://src/core/systems/standing.gd")


static func postings(ship) -> Dictionary:
	if not is_instance_valid(ship):
		return {}
	if ship.has_method("is_player") and ship.is_player():
		return GameState.player_bounties
	var own = ship.get("bounties")
	return own if own is Dictionary else {}


# Whether `faction` pays `ship` (a bounty it posted, or its war bounty).
static func pays(faction, ship) -> bool:
	if not (Standing.has_standing(faction) and is_instance_valid(ship)):
		return false
	if ship.has_method("is_player") and ship.is_player():
		return not Standing.is_hostile(faction)
	var own = ship.get("faction")
	if own == faction:
		return true
	return not (own in Constants.FACTIONS[faction].get("enemies", [])) and not (faction in Constants.FACTIONS.get(own, {}).get("enemies", []))


# What `hunter` would be paid for killing `ship`: the postings it can claim plus the war bounty.
static func claimable(hunter, ship) -> float:
	if not (is_instance_valid(hunter) and is_instance_valid(ship)) or hunter == ship:
		return 0.0
	var total := 0.0
	var posted: Dictionary = postings(ship)
	for faction in posted:
		if pays(faction, hunter):
			total += float(posted[faction])
	return total + war_bounty(hunter, ship)


static func war_bounty(hunter, ship) -> float:
	var victim_faction = ship.get("faction")
	for faction in Constants.FACTIONS:
		if victim_faction in Constants.FACTIONS[faction].get("enemies", []) and pays(faction, hunter):
			return Constants.BOUNTY_WAR_SHARE * _value(ship)
	return 0.0


# `killer` killed `victim`: pays the killer, posts the victim's faction's bounty on it and clears the
# victim's postings. Returns what was paid.
static func on_kill(killer, victim) -> float:
	if not (is_instance_valid(killer) and is_instance_valid(victim)) or killer == victim:
		return 0.0
	var paid: float = claimable(killer, victim)
	var victim_faction = victim.get("faction")
	if Standing.has_standing(victim_faction) and killer.get("faction") != victim_faction:
		var posted: Dictionary = postings(killer)
		var amount: float = Constants.BOUNTY_POST_SHARE * _value(victim)
		posted[victim_faction] = float(posted.get(victim_faction, 0.0)) + amount
		if killer.has_method("is_player") and killer.is_player():
			EventBus.emit_signal("announcement", "%s posts a bounty on you: %d WP" % [Constants.FACTIONS[victim_faction].get("name", victim_faction), int(posted[victim_faction])], "warning")
	postings(victim).clear()
	if paid <= 0.0:
		return 0.0
	if killer.has_method("is_player") and killer.is_player():
		GameState.player_bank += int(round(paid))
		EventBus.emit_signal("announcement", "Bounty: %d WP" % int(round(paid)), "info")
	elif str(killer.get("evo_uid")) == "" and killer.get("wallet") != null:
		killer.wallet += paid  # Arena pilots are paid through Evolution (agent_disabled)
	return paid


# Whether `hunter` goes after `ship` for its price.
static func is_worth_hunting(hunter, ship) -> bool:
	if not is_instance_valid(ship) or ship.get("is_wreck"):
		return false
	var posted := 0.0
	var on_ship: Dictionary = postings(ship)
	for faction in on_ship:
		if pays(faction, hunter):
			posted += float(on_ship[faction])
	return posted > 0.0 and posted >= Constants.BOUNTY_HUNT_SHARE * _value(hunter)


static func _value(ship) -> float:
	return float(ship.get_value()) if ship.has_method("get_value") else 0.0
