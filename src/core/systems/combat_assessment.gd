# CombatAssessment: how a fight between two ships looks, shared by NPCs (as numbers) and the player
# (as words on the HUD), so both judge by the same rule.
#   advantage = (own time to die) / (time to kill the target), from hulls and laser damage per second.
#   desire = advantage * gain factor (what the kill is worth); NPCs fight on desire, players judge worth themselves.
# Fights are judged side against side (team_advantage): a ship with its friends near it (side_of)
# against the target with its own, so a lone ship thinks twice about a pair and a pair gangs up.

extends Reference


static func compute_advantage(own_hull: float, own_dps: float, target_hull: float, target_dps: float) -> float:
	if own_dps <= 0.0:
		return 0.0
	var time_to_kill: float = target_hull / own_dps
	var time_to_die: float = own_hull / max(target_dps, 0.001)
	return min(time_to_die / max(time_to_kill, 0.001), 100.0)


static func compute_desire(own_hull: float, own_dps: float, target_hull: float, target_dps: float, gain: float) -> float:
	var gain_factor: float = clamp(gain / Constants.AI_GAIN_REFERENCE, Constants.AI_GAIN_FACTOR_MIN, Constants.AI_GAIN_FACTOR_MAX)
	return compute_advantage(own_hull, own_dps, target_hull, target_dps) * gain_factor


static func advantage_between(own, target) -> float:
	return compute_advantage(own.hull, own.get_damage_per_second(), target.hull, target.get_damage_per_second())


# `own`'s side against `target`'s (side_of each): the advantage NPCs fight on and the HUD shows.
static func team_advantage(own, target) -> float:
	var ours: Dictionary = side_of(own)
	var theirs: Dictionary = side_of(target)
	return compute_advantage(ours.hull, ours.dps, theirs.hull, theirs.dps)


# A ship and its friends as one side: {"hull", "dps", "ships"} summed over `body` and the live,
# undocked ships of its faction within Constants.AI_TEAM_RADIUS of it (the player flies alone).
static func side_of(body) -> Dictionary:
	var side := {"hull": float(body.hull), "dps": float(body.get_damage_per_second()), "ships": 1}
	var faction = body.get("faction")
	if not (faction is String) or faction == "" or faction == "player" or not body.is_inside_tree():
		return side
	var here: Vector3 = body.global_transform.origin
	for other in body.get_tree().get_nodes_in_group("agent_body"):
		if other == body or other.get("faction") != faction or other.get("is_wreck") != false or other.get("is_docked"):
			continue
		if other.global_transform.origin.distance_to(here) > Constants.AI_TEAM_RADIUS:
			continue
		side.hull += float(other.hull)
		side.dps += float(other.get_damage_per_second())
		side.ships += 1
	return side


# The player's at-a-glance read of a target.
static func difficulty_label(advantage: float) -> String:
	if advantage >= Constants.DIFFICULTY_EASY_ADVANTAGE:
		return "EASY"
	if advantage >= Constants.DIFFICULTY_EVEN_ADVANTAGE:
		return "EVEN"
	if advantage >= Constants.DIFFICULTY_HARD_ADVANTAGE:
		return "HARD"
	return "DEADLY"
