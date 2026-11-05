# HavenTemplate: a station NPCs live from (database/sectors/<sector>/havens/<id>.tres), listed by
# its sector's SectorLayoutTemplate. Built by SectorLayout (unless `station` names one already in the
# sector scene), a beacon too; NPCs dock where they are welcome (Havens.welcome): their own
# faction's havens, and neutral ones unless they are raiders or the xenohive. Read as a Dictionary
# (to_spec; Havens.spec).

extends Template
class_name HavenTemplate

export var display_name: String = ""
export var faction: String = ""  # Its owner's FactionTemplate id; "" neutral
export var station: String = ""  # A station already in the sector scene (by node name); "" builds one here
export var form: String = ""  # Its placeholder look (Constants STATION_FORMS: haven, post, refinery, den); "" the cargo ship
export var position: Vector3 = Vector3.ZERO  # m from the sector's middle (a built station)
export var ships: Dictionary = {}  # Faction id -> ships living from it (each haven's are a group, with ranks and a leader)
export var prefer_role: String = ""  # A family its ships are more often (Evolution), prefer_share of the time
export var prefer_share: float = 0.0
export var repair: bool = false  # Services: repairs hulls
export var rearm: bool = false  # refills lances, rounds and decoys
export var buys: Dictionary = {}  # Commodity id (or "*" for any) -> price factor on its cargo price; it buys nothing else


func to_spec() -> Dictionary:
	var spec := {
		"id": template_id, "name": display_name, "faction": faction, "at": position, "ships": ships.duplicate(),
		"services": {"repair": repair, "rearm": rearm, "buys": buys.duplicate()},
	}
	if station != "":
		spec["station"] = station
	if form != "":
		spec["form"] = form
	if prefer_role != "":
		spec["prefer_role"] = prefer_role
		spec["prefer_share"] = prefer_share
	return spec
