# Radio: NPCs on a common frequency, saying what they do and mean to (Constants RADIO_*). A line
# goes out as EventBus radio_message; whoever listens keeps the ones said within RADIO_RANGE of it.
# A ship speaks at most every RADIO_SPEAKER_COOLDOWN s, unless `urgent` (a mayday). Silent factions
# (FACTIONS "silent": the xenohive) say nothing.

extends Reference


static func say(speaker: Node, text: String, urgent: bool = false) -> bool:
	if not (is_instance_valid(speaker) and speaker.is_inside_tree()):
		return false
	var faction = speaker.get("faction")
	if faction == null or Constants.FACTIONS.get(faction, {}).get("silent", false):
		return false
	var now: float = Evolution.game_time
	if not urgent and speaker.has_meta("radio_next") and now < float(speaker.get_meta("radio_next")):
		return false
	speaker.set_meta("radio_next", now + Constants.RADIO_SPEAKER_COOLDOWN)
	EventBus.emit_signal("radio_message", speaker, text)
	return true


# How the speaker is named on the air: its faction and its life's id ("Verdant VE-1234"), or a
# number for a ship without one (a traveller).
static func call_sign(speaker: Node) -> String:
	var faction_name: String = speaker.get_faction_name() if speaker.has_method("get_faction_name") else ""
	var uid: String = str(speaker.get("evo_uid")) if speaker.get("evo_uid") != null else ""
	if uid == "":
		uid = "#%04d" % (speaker.get_instance_id() % 10000)
	return (faction_name + " " + uid).strip_edges()


# What `body` is called in a line: "you" (the player: only the player reads the radio), a ship by
# its call sign, or a station's or beacon's name.
static func name_of(body: Node) -> String:
	if not is_instance_valid(body):
		return "someone"
	if body.has_method("is_player") and body.is_player():
		return "you"
	if body.has_method("get_faction_name") and body.get_faction_name() != "":
		return call_sign(body)
	for property in ["station_name", "beacon_name"]:
		if body.get(property) != null and str(body.get(property)) != "":
			return str(body.get(property))
	return str(body.name)
