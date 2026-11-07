# TargetKinds: what an on-screen target is for the HUD's marks and colours (Constants
# COLOR_UI_*): a ship or a station by its side to the player (allied, neutral or hostile; not its
# faction's colour; the xenohive's always its own purple), anything else by its kind. Shared by the
# target brackets and the threat ring.

extends Reference

const Standing = preload("res://src/core/systems/standing.gd")


# "ship", "station", "beacon", "distress" (a mayday's beacon), "body", "rock", "wreck", "pickup",
# "jump" or "other".
static func kind_of(target) -> String:
	if not (is_instance_valid(target) and target is Node):
		return "other"
	if target.get("target_kind") == "jump_route" or target.is_in_group("jump_point"):
		return "jump"
	if target.get("is_wreck"):
		return "wreck"
	if target.has_method("get_faction_color"):
		return "ship"
	if target.is_in_group("dockable_station"):
		return "station"
	if target.is_in_group("beacon"):
		return "distress" if target.get("kind") == "distress" else "beacon"
	if target.is_in_group("ore_chunk") or target.is_in_group("loose_lance"):
		return "pickup"
	if target.is_in_group("celestial"):
		return "body"
	if target.is_in_group("asteroid"):
		return "rock"
	return "other"


# "hostile", "allied" or "neutral" to the player: a ship that would attack it is hostile, a station
# that would refuse it (or a territorial alien's) too; friendly standing makes either allied.
static func side_of(target, player) -> String:
	var faction = target.get("faction") if is_instance_valid(target) else null
	if target.has_method("is_enemy_of"):
		if is_instance_valid(player) and target.is_enemy_of(player):
			return "hostile"
	elif faction is String and (Standing.is_hostile(faction) or TemplateDatabase.factions.get(faction, {}).has("territory")):
		return "hostile"
	if faction is String and Standing.has_standing(faction) and Standing.of(faction) >= Constants.STANDING_FRIENDLY:
		return "allied"
	return "neutral"


static func side_color(side: String) -> Color:
	match side:
		"hostile":
			return graded(Constants.COLOR_UI_TARGET_HOSTILE)
		"allied":
			return graded(Constants.COLOR_UI_TARGET_ALLIED)
	return graded(Constants.COLOR_UI_TARGET_SIDE_NEUTRAL)


# `color` as the HUD's look (Settings "hud_preset") grades it: its saturation towards grey.
static func graded(color: Color) -> Color:
	var saturation: float = float(Constants.hud_preset(Settings.get_option("hud_preset")).saturation)
	if saturation >= 1.0:
		return color
	var grey: float = color.r * 0.3 + color.g * 0.59 + color.b * 0.11
	return Color(lerp(grey, color.r, saturation), lerp(grey, color.g, saturation), lerp(grey, color.b, saturation), color.a)


# True for the xenohive's ships and hives: purple whatever their side.
static func is_xenohive(target) -> bool:
	return is_instance_valid(target) and target.get("faction") == Constants.XENOHIVE_FACTION


# The colour of `target`'s mark and label (before dimming for awareness and faintness).
static func color_of(target, player) -> Color:
	var kind: String = kind_of(target)
	match kind:
		"ship", "station":
			return graded(Constants.COLOR_UI_XENOHIVE) if is_xenohive(target) else side_color(side_of(target, player))
		"wreck":
			return graded(Constants.COLOR_UI_WRECK)
		"beacon":
			return graded(Constants.COLOR_UI_BEACON)
		"distress":
			return graded(Constants.COLOR_UI_DISTRESS)
		"body":
			return graded(Constants.COLOR_UI_BODY)
		"rock":
			return graded(Constants.COLOR_UI_ROCK)
		"pickup":
			return graded(Constants.COLOR_UI_PICKUP)
	return graded(Constants.COLOR_UI_TARGET_NEUTRAL)
