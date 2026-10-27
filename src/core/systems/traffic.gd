# Traffic: persistent NPCs that travel the sector graph (Constants TRAFFIC_*), the population of the
# world outside the arenas. Each traveller is a record in GameState.travelers:
#   {"id", "faction", "role", "genome", "sector", "status" ("dwell" or "transit"), "until" (world
#    time), "from" (the sector it came from), "next" (the one it leaves for), "fuel" (units), "bank"
#    (WP), "cargo" {commodity: units}, "hull" (share, 1 = whole)}
# Off-screen it keeps a timetable: it stays in a sector until "until", then jumps to "next", burning a
# jump's fuel (ceil(mass / FUEL_MASS_PER_UNIT), as everyone), and arrives TRAFFIC_TRANSIT_TIME later.
# Without fuel for a jump it stays put. In Elace it sells its cargo (base value) into its bank, buys
# fuel and is repaired. In the player's sector it is a ship (its genome, built as an arena NPC's is):
# its AI mines, raids or patrols round its work point (prospectors: the nearest minable thing), and
# when its time is up, or its hold full, it flies out toward "next" and jumps. A traveller that dies is
# gone; another takes its place in Elace TRAFFIC_REPLACE_TIME later, from the best design of its kind.
# A child of AgentSystem, ticked by its population timer.

extends Node

const Genome = preload("res://src/core/evolution/genome.gd")

var _bodies: Dictionary = {}  # Traveller id -> its ship in the current sector
var _unloading: bool = false  # The sector is going: its ships leave with it, not through a jump point


func _ready() -> void:
	EventBus.connect("zone_unloading", self, "_on_zone_unloading")
	EventBus.connect("zone_loaded", self, "_on_zone_loaded")
	EventBus.connect("agent_disabled", self, "_on_agent_disabled")
	EventBus.connect("agent_despawning", self, "_on_agent_despawning")


# --- Roster ---

# Fills the roster (Constants TRAFFIC_ROSTER) with new travellers in Elace: on a new game, and as
# replacements fall due (a lost traveller's place stays empty until then).
func fill_roster() -> void:
	var pending: Array = []
	for at in GameState.traffic_replacements:
		if float(at) > GameState.world_time:
			pending.append(at)
	GameState.traffic_replacements = pending
	var room: int = _roster_size() - GameState.travelers.size() - pending.size()
	for entry in Constants.TRAFFIC_ROSTER:
		var have := 0
		for record in GameState.travelers:
			if record.faction == entry.faction and record.role == entry.role:
				have += 1
		while have < int(entry.count) and room > 0:
			GameState.travelers.append(_new_traveler(entry.faction, entry.role))
			have += 1
			room -= 1


static func _roster_size() -> int:
	var total := 0
	for entry in Constants.TRAFFIC_ROSTER:
		total += int(entry.count)
	return total


func _new_traveler(faction: String, role: String) -> Dictionary:
	var genome: Dictionary = best_genome(faction, role)
	var record := {
		"id": "T%d" % GameState.traffic_next_id, "faction": faction, "role": role, "genome": genome,
		"sector": Constants.INITIAL_SECTOR_ID, "status": "dwell", "from": "", "next": "",
		"until": GameState.world_time + rand_range(Constants.TRAFFIC_DWELL_TIME[0], Constants.TRAFFIC_DWELL_TIME[1]),
		"fuel": 0, "bank": Constants.TRAFFIC_START_BANK, "cargo": {}, "hull": 1.0,
	}
	GameState.traffic_next_id += 1
	_restock(record)
	record.next = _pick_next(record)
	return record


# The fittest design of its kind in Evolution's pools (role: a niche's role, "" for any), or its
# faction's first seed design.
static func best_genome(faction: String, role: String) -> Dictionary:
	var best: Dictionary = {}
	var best_fitness: float = -INF
	var marker: String = "|%s|" % role
	for niche in Evolution.pools.get(faction, {}).get("cells", {}):
		var genome_id: String = Evolution.pools[faction].cells[niche]
		if not Evolution.genomes.has(genome_id) or (role != "" and niche.find(marker) < 0):
			continue
		var fitness: float = Evolution.shrunk_fitness(genome_id)
		if fitness > best_fitness:
			best_fitness = fitness
			best = Evolution.genomes[genome_id].genome
	if best.empty():
		var seeds: Array = Constants.EVO_SEEDS.get(faction, Constants.EVO_FACTION_SEEDS)
		return Genome.seed_genome(seeds[0])
	return best.duplicate(true)


# --- Timetable ---

func tick() -> void:
	if GameState.current_sector_id == "":
		return
	fill_roster()
	var now: float = GameState.world_time
	for record in GameState.travelers.duplicate():
		var body = _bodies.get(record.id)
		if is_instance_valid(body):
			_sync(record, body)
			if now >= float(record.until):
				_send_off(record, body)
			continue
		if record.status == "transit" and now >= float(record.until):
			_arrive(record)
		elif record.status == "dwell" and now >= float(record.until) and record.sector != GameState.current_sector_id:
			_depart(record)
		if record.status == "dwell" and record.sector == GameState.current_sector_id and not _unloading and is_instance_valid(GlobalRefs.agent_container):
			_spawn(record)


# Leaves for `next`, burning a jump's fuel, or stays a while longer without the fuel.
func _depart(record: Dictionary) -> void:
	if record.next == "" or record.next == record.sector:
		record.next = _pick_next(record)
	var cost: int = jump_cost(record)
	if int(record.fuel) < cost:
		if record.sector == Constants.INITIAL_SECTOR_ID:
			_restock(record)
		record.until = GameState.world_time + Constants.TRAFFIC_DWELL_TIME[0]
		if int(record.fuel) < cost:
			return
	record.fuel = int(record.fuel) - cost
	record.from = record.sector
	record.sector = record.next
	record.status = "transit"
	record.until = GameState.world_time + Constants.TRAFFIC_TRANSIT_TIME


func _arrive(record: Dictionary) -> void:
	record.status = "dwell"
	record["arriving"] = true  # Shows up at the jump shell, not at its work
	record.until = GameState.world_time + rand_range(Constants.TRAFFIC_DWELL_TIME[0], Constants.TRAFFIC_DWELL_TIME[1])
	if record.sector == Constants.INITIAL_SECTOR_ID:
		_restock(record)
	record.next = _pick_next(record)


# In Elace: sells the hold, buys fuel to TRAFFIC_FUEL_JUMPS jumps' worth, and is repaired.
func _restock(record: Dictionary) -> void:
	for commodity_id in record.cargo:
		var commodity = TemplateDatabase.get_template(commodity_id)
		if commodity is CommodityTemplate:
			record.bank = float(record.bank) + int(record.cargo[commodity_id]) * commodity.base_value
	record.cargo = {}
	var fuel = TemplateDatabase.get_template(Constants.FUEL_COMMODITY)
	var price: float = float(fuel.base_value) if fuel is CommodityTemplate else 25.0
	var want: int = jump_cost(record) * Constants.TRAFFIC_FUEL_JUMPS - int(record.fuel)
	var bought: int = int(clamp(want, 0, floor(max(0.0, float(record.bank)) / price)))
	record.fuel = int(record.fuel) + bought
	record.bank = float(record.bank) - bought * price
	record.hull = 1.0


# A neighbour to go to: back toward Elace when short of fuel for two more jumps, anywhere otherwise.
func _pick_next(record: Dictionary) -> String:
	var neighbours: Array = neighbours_of(record.sector)
	if neighbours.empty():
		return record.sector
	if Constants.INITIAL_SECTOR_ID in neighbours and int(record.fuel) < 2 * jump_cost(record):
		return Constants.INITIAL_SECTOR_ID
	return neighbours[randi() % neighbours.size()]


static func neighbours_of(sector_id: String) -> Array:
	var found: Array = []
	for id in TemplateDatabase.locations:
		var location = TemplateDatabase.locations[id]
		if location.get("connections") == null:
			continue
		if id == sector_id:
			for other in location.connections:
				if not other in found:
					found.append(other)
		elif sector_id in location.connections and not id in found:
			found.append(id)
	return found


static func jump_cost(record: Dictionary) -> int:
	var ShipLaws = load("res://src/core/systems/ship_laws.gd")
	var mass: float = float(ShipLaws.ship_stats(record.genome.ship).get("mass", Constants.FUEL_MASS_PER_UNIT))
	return int(max(1.0, ceil(mass / Constants.FUEL_MASS_PER_UNIT)))


# --- In the player's sector ---

func _spawn(record: Dictionary) -> void:
	var spawner = get_parent()
	if not (is_instance_valid(spawner) and spawner.has_method("spawn_npc_from_template")):
		return
	var built: Dictionary = Genome.build(record.genome, "traffic_" + record.id, record.faction)
	var entry: Vector3 = _entry_point()
	var arriving: bool = bool(record.get("arriving", false))
	record.erase("arriving")
	var position: Vector3 = _jump_shell_point(entry, record.from) if arriving else _work_point(record, entry) + _scatter(Constants.TRAFFIC_WORK_RADIUS)
	var body = spawner.spawn_npc_from_template(Constants.NPC_BASE_TEMPLATE_PATH, position, {
		"faction": record.faction,
		"ship_template_id": built.ship_template_id,
		"fit": built.fit,
		"skill": 0.6,
		"behavior": record.genome.get("behavior", Genome.default_behavior()),
		"patrol_center": _work_point(record, entry),
		"home_point": _jump_shell_point(entry, record.next),
		"wallet": float(record.bank),
	})
	if not is_instance_valid(body):
		return
	body.set_meta("traveler", record.id)
	body.hull = body.hull_max * clamp(float(record.hull), 0.05, 1.0)
	for commodity_id in record.cargo:
		body.add_cargo(commodity_id, int(record.cargo[commodity_id]))
	_bodies[record.id] = body


# Its time is up: it flies out toward its next sector (ShipControllerAI DEPART) and jumps there.
func _send_off(record: Dictionary, body: Node) -> void:
	if int(record.fuel) < jump_cost(record):  # It cannot jump: it stays a while longer
		record.until = GameState.world_time + Constants.TRAFFIC_DWELL_TIME[0]
		return
	var ai = body.get_node_or_null(Constants.AI_CONTROLLER_NODE_NAME)
	if ai != null and ai.has_method("leave_toward") and not ai.is_leaving():
		ai.leave_toward(_jump_shell_point(_entry_point(), record.next))


func _sync(record: Dictionary, body: Node) -> void:
	record.cargo = body.cargo.duplicate()
	record.hull = float(body.hull) / max(float(body.hull_max), 1.0)


func _on_agent_despawning(body) -> void:
	if not (is_instance_valid(body) and body.has_meta("traveler")):
		return
	var id: String = str(body.get_meta("traveler"))
	_bodies.erase(id)
	if _unloading:
		return
	var record: Dictionary = _record(id)
	if not record.empty():  # Flew out through the jump point (DEPART): it jumps
		_sync(record, body)
		_depart(record)


func _on_agent_disabled(body) -> void:
	if not (is_instance_valid(body) and body.has_meta("traveler")):
		return
	var id: String = str(body.get_meta("traveler"))
	_bodies.erase(id)
	var record: Dictionary = _record(id)
	if not record.empty():
		GameState.travelers.erase(record)
		GameState.traffic_replacements.append(GameState.world_time + Constants.TRAFFIC_REPLACE_TIME)


func _on_zone_unloading(_zone) -> void:
	_unloading = true
	for id in _bodies:
		var record: Dictionary = _record(id)
		if not record.empty() and is_instance_valid(_bodies[id]):
			_sync(record, _bodies[id])
	_bodies.clear()


func _on_zone_loaded(_zone, _path, _container) -> void:
	_unloading = false


func _record(id: String) -> Dictionary:
	for record in GameState.travelers:
		if record.id == id:
			return record
	return {}


func _entry_point() -> Vector3:
	if is_instance_valid(GlobalRefs.current_zone):
		var entry = GlobalRefs.current_zone.find_node("EntryPoint", true, false)
		if entry is Spatial:
			return entry.global_transform.origin
	return Vector3.ZERO


# Where ships come in from, or go out toward, `sector_id` (the jump shell on its side).
func _jump_shell_point(entry: Vector3, sector_id: String) -> Vector3:
	var here = TemplateDatabase.locations.get(GameState.current_sector_id)
	var there = TemplateDatabase.locations.get(sector_id)
	var distance: float = float(here.jump_in_distance) if here != null and here.get("jump_in_distance") != null else 20000.0
	var direction: Vector3 = (there.global_position - here.global_position).normalized() if here != null and there != null else _scatter(1.0).normalized()
	return entry + direction * distance * 0.9


# Prospectors work the nearest minable thing to the entry point; the rest keep near it.
func _work_point(record: Dictionary, entry: Vector3) -> Vector3:
	if record.role == "prospector":
		var best: Spatial = null
		var best_distance: float = Constants.TRAFFIC_WORK_SEARCH
		for rock in get_tree().get_nodes_in_group("mineable"):
			var distance: float = rock.global_transform.origin.distance_to(entry)
			if distance < best_distance:
				best = rock
				best_distance = distance
		if best != null:
			return best.global_transform.origin
	return entry


static func _scatter(radius: float) -> Vector3:
	return Vector3(rand_range(-1, 1), rand_range(-0.3, 0.3), rand_range(-1, 1)).normalized() * radius * randf()
