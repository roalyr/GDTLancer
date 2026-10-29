# Beacon: a point of a sector's map the AI goes by (Constants SECTOR_LAYOUTS; BeaconNetwork keeps
# their numbers). Kinds: "haven" (a station's), "patrol" (a faction's picket), "field" (a rock
# field), "landmark" (a point to route through: planets, moons, passes). It remembers heat (hull lost
# to fire near it, fading), traffic (ships passing, fading), when each faction's ships were last
# there and how many are there now, and a field the ore left in it. Seen from anywhere, like a
# star; the player reads its numbers as words (target info).

extends StaticBody

export var kind: String = "landmark"
export var faction: String = ""  # Its faction, "" for none
export var beacon_name: String = ""
export var radius: float = Constants.BEACON_TRAFFIC_RADIUS  # m it covers (a field: its rocks)
var heat: float = 0.0
var traffic: float = 0.0
var value: float = 0.0  # A field's ore left (units)
var last_visit: Dictionary = {}  # Faction -> BeaconNetwork time a ship of it was last here
var presence: Dictionary = {}  # Faction -> its ships here at the last count
var haven: Node = null  # A haven's station


func _ready() -> void:
	add_to_group("beacon")
	collision_layer = 0
	collision_mask = 0


func get_signature() -> float:
	return INF


func get_apparent_radius() -> float:
	return 20.0


func get_display_name() -> String:
	return beacon_name if beacon_name != "" else name


# What the player reads off it: its kind and faction, how hot and how busy it is, and a field's ore.
func get_beacon_cues() -> Array:
	var cues: Array = []
	var owner_name: String = Constants.FACTIONS.get(faction, {}).get("name", "")
	cues.append(("%s %s" % [owner_name, kind]).strip_edges().to_upper())
	cues.append(_word(heat, Constants.BEACON_HEAT_WORDS))
	cues.append(_word(traffic, Constants.BEACON_TRAFFIC_WORDS))
	if kind == "field":
		cues.append("ORE %d" % int(value))
	return cues


static func _word(amount: float, words: Array) -> String:
	for word in words:
		if amount < float(word[0]):
			return str(word[1])
	return str(words.back()[1])
