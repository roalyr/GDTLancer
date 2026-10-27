# Evolution: the arena NPCs' gene pools, their lives, and the record of every life (see Constants
# ARENA AND EVOLUTION). Each faction has its own pool: an archive of niches (Genome.niche), each
# holding the best genome found for it. A spawn (begin_life) picks a niche softly by fitness and
# flies its genome again or a mutant; the life's end (death or retirement) scores the genome and
# may make it its niche's best. In proving mode (Constants EVO_PROVING) it mostly re-flies the leading
# genomes of each archetype until they have enough lives to be presets (_unproven).
# Saved with the game (serialize / deserialize).
# Console: lines start with "EVO " (Constants EVO_LOG_LEVEL), a report every EVO_REPORT_INTERVAL.
# File: every finished life in full, one JSON line each, under Constants EVO_LOG_DIR.

extends Node

const Genome = preload("res://src/core/evolution/genome.gd")
const PresetExporter = preload("res://src/core/evolution/preset_exporter.gd")
const Market = preload("res://src/core/systems/market.gd")
const SAVE_VERSION = 1

var run_id: String = ""  # Names the log file; a new game starts a new run
var game_time: float = 0.0  # s of simulated time with the arenas running
var real_time: float = 0.0  # s of wall-clock time with the arenas running
var totals: Dictionary = {}  # "births", "deaths", "retired"
var pools: Dictionary = {}  # Faction -> {"cells": {niche: genome id}, "lives": lives ended}
var genomes: Dictionary = {}  # Genome id -> {"genome", "faction", "parent", "born", "lives", "fitness_sum", "kills", "deaths", "earned"}
var live: Dictionary = {}  # NPC uid -> life record (see begin_life)
var resume: Array = []  # Life records of NPCs saved or left behind with the sector: they fly again first
var _next_uid: int = 0
var _next_genome: int = 0
var _bodies: Dictionary = {}  # NPC uid -> its AgentBody
var _report_due: float = 0.0
var active: bool = false  # Arenas populated (AgentSystem); time only counts then


func _ready():
	pause_mode = Node.PAUSE_MODE_STOP
	new_run()
	EventBus.connect("agent_damaged", self, "_on_agent_damaged")
	EventBus.connect("agent_disabled", self, "_on_agent_disabled")
	EventBus.connect("agent_despawning", self, "_on_agent_despawning")


func _physics_process(delta: float) -> void:
	if not active or live.empty():
		return
	game_time += delta
	real_time += delta / max(Engine.time_scale, 0.001)
	if game_time >= _report_due:
		_report_due = game_time + Constants.EVO_REPORT_INTERVAL
		print_report()


# --- Runs ---

func new_run() -> void:
	var now: Dictionary = OS.get_datetime()
	run_id = "%04d%02d%02d_%02d%02d%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]
	game_time = 0.0
	real_time = 0.0
	totals = {"births": 0, "deaths": 0, "retired": 0}
	pools = {}
	for faction in Constants.ARENA_FACTIONS:
		pools[faction] = {"cells": {}, "lives": 0}
	genomes = {}
	live = {}
	resume = []
	_bodies = {}
	_next_uid = 0
	_next_genome = 0
	_report_due = Constants.EVO_REPORT_INTERVAL
	plant_seeds()


# Puts each starting design (Constants EVO_SEEDS) into its pool, where its niche is still empty.
# Returns how many were planted.
func plant_seeds() -> int:
	var planted := 0
	for faction in Constants.EVO_SEEDS:
		if not pools.has(faction):
			pools[faction] = {"cells": {}, "lives": 0}
		for spec in Constants.EVO_SEEDS[faction]:
			var genome: Dictionary = Genome.seed_genome(spec)
			var niche: String = Genome.niche(genome)
			if not pools[faction].cells.has(niche):
				pools[faction].cells[niche] = _add_genome(genome, faction, "")
				planted += 1
	return planted


# A new era of rules: every genome's record starts over (lives, fitness, kills), so what is measured
# from now on is not mixed with fitness earned under the old rules. The genomes and niches stay.
func new_era() -> void:
	for genome_id in genomes:
		var entry: Dictionary = genomes[genome_id]
		for key in ["lives", "kills", "deaths", "earned"]:
			entry[key] = 0
		entry.fitness_sum = 0.0
	_log(1, "EVO NEW ERA: %d genomes start over, %d seeds planted" % [genomes.size(), plant_seeds()])


func serialize() -> Dictionary:
	var lives: Array = resume.duplicate(true)
	for uid in live:
		lives.append(live[uid].duplicate(true))
	return {
		"version": SAVE_VERSION, "run_id": run_id, "game_time": game_time, "real_time": real_time,
		"totals": totals.duplicate(), "pools": pools.duplicate(true), "genomes": genomes.duplicate(true),
		"lives": lives, "next_uid": _next_uid, "next_genome": _next_genome,
	}


func deserialize(data: Dictionary) -> bool:
	new_run()
	if int(data.get("version", 0)) != SAVE_VERSION:
		return false
	run_id = str(data.get("run_id", run_id))
	game_time = float(data.get("game_time", 0.0))
	real_time = float(data.get("real_time", 0.0))
	totals = data.get("totals", totals)
	pools = data.get("pools", pools)
	for faction in Constants.ARENA_FACTIONS:
		if not pools.has(faction):
			pools[faction] = {"cells": {}, "lives": 0}
	genomes = data.get("genomes", {})
	resume = data.get("lives", [])
	var zones: Array = []
	for zone in Constants.ARENA_ZONES:
		zones.append(zone.id)
	for record in resume:
		if not record.get("zone") in zones:
			record.zone = zones.back()  # Its zone is gone (3v3 became 4v4): it flies in the biggest
	_next_uid = int(data.get("next_uid", 0))
	_next_genome = int(data.get("next_genome", genomes.size()))
	plant_seeds()
	_report_due = game_time + Constants.EVO_REPORT_INTERVAL
	_log(1, "EVO RESUMED run %s at t=%.0fs: %d lives ended, %d genomes, %d ships to fly again" % [run_id, game_time, lives_ended(), genomes.size(), resume.size()])
	return true


# Lives ended so far (the evolution's cycles).
func lives_ended() -> int:
	return int(totals.get("deaths", 0)) + int(totals.get("retired", 0))


# For the save summary.
func summary() -> Dictionary:
	var niches := 0
	for faction in pools:
		niches += pools[faction].cells.size()
	return {"game_time": game_time, "real_time": real_time, "lives": lives_ended(), "births": int(totals.get("births", 0)), "niches": niches, "genomes": genomes.size()}


# Live records move to `resume` (their ships left with the sector); they fly again on its return.
func suspend_all() -> void:
	for uid in live:
		resume.append(live[uid])
	live = {}
	_bodies = {}


# --- Lives ---

# A new life for an arena slot: a saved one for this faction and zone if there is one, otherwise a
# genome from the pool. Returns the life record ("uid", "genome_id", "ship_template_id", "fit",
# "behavior", "skill", ...) or {} if none.
func begin_life(faction: String, zone_id: String) -> Dictionary:
	for i in range(resume.size()):
		var saved: Dictionary = resume[i]
		if saved.get("faction") == faction and saved.get("zone") == zone_id and genomes.has(saved.get("genome_id", "")):
			resume.remove(i)
			_start(saved)
			_log(2, "EVO BACK %s %s zone=%s age=%.0fs" % [saved.uid, saved.genome_id, zone_id, game_time - float(saved.born)])
			return saved
	var pick: Dictionary = _pick_genome(faction, _preferred_role(faction, zone_id))
	var genome_id: String = pick.genome_id
	var entry: Dictionary = genomes[genome_id]
	var prefix: String = Constants.FACTIONS.get(faction, {}).get("name", faction).substr(0, 2).to_upper()
	var record := {
		"uid": "%s-%05d" % [prefix, _next_uid], "faction": faction, "zone": zone_id, "genome_id": genome_id,
		"parent": entry.parent, "how": pick.how, "born": game_time, "skill": rand_range(0.3, 0.8),
		"cost": Genome.cost(entry.genome), "hull_value": Genome.hull_value(entry.genome), "kills": 0, "victims": [], "earned": 0, "bounty": 0.0, "spent": 0.0,
		"damage_dealt": 0.0, "damage_taken": 0.0, "docks": 0,
	}
	_next_uid += 1
	totals.births = int(totals.get("births", 0)) + 1
	_start(record)
	_log(2, "EVO BIRTH %s %s (%s from %s) zone=%s niche=%s cost=%.0f skill=%.2f %s" % [
		record.uid, genome_id, pick.how, entry.parent if entry.parent != "" else "-", zone_id,
		Genome.niche(entry.genome), record.cost, record.skill, Genome.describe(entry.genome)])
	return record


func _start(record: Dictionary) -> void:
	var entry: Dictionary = genomes[record.genome_id]
	var built: Dictionary = Genome.build(entry.genome, record.genome_id, record.faction)
	record.ship_template_id = built.ship_template_id
	record.fit = built.fit
	record.behavior = entry.genome.get("behavior", Genome.default_behavior())
	live[record.uid] = record


func attach_body(uid: String, body: Node) -> void:
	_bodies[uid] = body


# Extra drones a xenohive has grown from what its drones brought home (Constants XENOHIVE_*).
func grown_drones(faction: String) -> int:
	if not Constants.FACTIONS.get(faction, {}).has("territory"):
		return 0
	var delivered: float = float(pools.get(faction, {}).get("delivered", 0.0))
	return int(min(Constants.XENOHIVE_DRONES_MAX, floor(delivered / Constants.XENOHIVE_MASS_PER_DRONE)))


func get_record(uid: String) -> Dictionary:
	return live.get(uid, {})


# Docked at one of its stations: sells the hold, repairs. Returns true if the ship retires here
# (Constants ARENA_MAX_LIFETIME): its life ends, and the caller removes it.
func on_docked(body: Node, location_id: String = "") -> bool:
	var uid: String = str(body.get("evo_uid"))
	if not live.has(uid):
		return false
	var record: Dictionary = live[uid]
	var sale: Dictionary = Market.hold_value(body, location_id)  # At the station's cargo price, as the player
	var value: int = int(sale.value)
	var units: int = int(sale.units)
	var delivered: float = float(sale.mass)
	body.clear_cargo()
	var pool: Dictionary = pools.get(record.faction, {})
	pool["delivered"] = float(pool.get("delivered", 0.0)) + delivered
	var hull_max: float = max(float(body.hull_max), 1.0)
	var repaired: float = body.repair_hull()
	var repair_cost: float = Constants.EVO_REPAIR_COST_SHARE * float(record.get("hull_value", record.cost)) * repaired / hull_max
	var lance = body.get_lance() if body.has_method("get_lance") else null
	if lance != null:
		var lances: int = lance.restock()
		repair_cost += lances * float(lance.lance.nail_value)  # Lances used are bought anew
		if lances > 0:
			note(uid, "rearmed")
	var tools = body.get_node_or_null("ToolController")
	if tools != null and tools.has_method("restock_ammo"):
		var added: Dictionary = tools.restock_ammo()
		for index in added:
			repair_cost += int(added[index]) * float(tools.get_tool(index).round_value)  # Rounds fired are bought anew
		if not added.empty():
			note(uid, "reloaded")
	if body.has_method("restock_decoys"):
		repair_cost += body.restock_decoys() * Constants.LAW_DECOY_VALUE
	record.earned = int(record.earned) + value
	record.spent = float(record.get("spent", 0.0)) + repair_cost
	record.docks = int(record.docks) + 1
	_log(2, "EVO DOCK %s sold %d units for %d WP (life total %d), repaired %.0f hull for %.0f WP, age %.0fs" % [uid, units, value, record.earned, repaired, repair_cost, game_time - float(record.born)])
	if game_time - float(record.born) >= lifetime_of(uid):
		_end_life(uid, false, "")
		return true
	return false


# A run-and-chase event in a life, counted in its record and log: "fled" (broke off or ran),
# "held_fire" (ran without shooting back), "escaped" (docked while running), "let_go" (let a
# runner go), "spared" (was let go).
func note(uid: String, event: String) -> void:
	if not live.has(uid):
		return
	var record: Dictionary = live[uid]
	var events: Dictionary = record.get("events", {})
	events[event] = int(events.get(event, 0)) + 1
	record.events = events
	_log(2, "EVO %s %s" % [event.to_upper().replace("_", " "), uid])


func is_old(uid: String) -> bool:
	return live.has(uid) and game_time - float(live[uid].born) >= lifetime_of(uid)


# --- Rank: renown within a group (a faction's ships in one arena zone; Constants RENOWN_*) ---

static func renown_of(record: Dictionary) -> float:
	return Constants.RENOWN_PER_KILL * int(record.get("kills", 0)) \
		+ Constants.RENOWN_PER_ASSIST * int(record.get("events", {}).get("assisted", 0)) \
		+ Constants.RENOWN_PER_DAMAGE * float(record.get("damage_dealt", 0.0))


# How long it flies before it retires: longer the more renown it has won.
func lifetime_of(uid: String) -> float:
	var renown: float = renown_of(live.get(uid, {}))
	return Constants.ARENA_MAX_LIFETIME * min(Constants.ARENA_LIFETIME_MAX_FACTOR, 1.0 + renown * Constants.ARENA_LIFETIME_PER_RENOWN)


# The group's lives, most renowned first (the older first on a tie).
func group_of(faction: String, zone_id: String) -> Array:
	var group: Array = []
	for uid in live:
		if live[uid].faction == faction and live[uid].zone == zone_id:
			group.append(uid)
	group.sort_custom(self, "_ranks_above")
	return group


func _ranks_above(a: String, b: String) -> bool:
	var renown_a: float = renown_of(live[a])
	var renown_b: float = renown_of(live[b])
	if renown_a != renown_b:
		return renown_a > renown_b
	return float(live[a].born) < float(live[b].born)


# 1 for the first in its group; 0 if not a live arena NPC.
func rank_of(uid: String) -> int:
	if not live.has(uid):
		return 0
	return group_of(live[uid].faction, live[uid].zone).find(uid) + 1


# The group's leader, if it has one out flying: the first, with RENOWN_LEADER_MIN renown and someone
# to lead.
func leader_of(faction: String, zone_id: String) -> Node:
	var group: Array = group_of(faction, zone_id)
	if group.size() < 2 or renown_of(live[group[0]]) < Constants.RENOWN_LEADER_MIN:
		return null
	var body = _bodies.get(group[0])
	if not is_instance_valid(body) or body.get("is_docked") or body.get("is_wreck"):
		return null
	return body


func _on_agent_damaged(body, amount, source) -> void:
	var victim_uid: String = str(body.get("evo_uid")) if is_instance_valid(body) and body.get("evo_uid") != null else ""
	var source_uid: String = ""
	if is_instance_valid(source):
		source_uid = str(source.get("evo_uid")) if source.get("evo_uid") != null and str(source.get("evo_uid")) != "" else ("player" if source.has_method("is_player") and source.is_player() else "")
	if live.has(source_uid):
		live[source_uid].damage_dealt = float(live[source_uid].damage_dealt) + float(amount)
	if live.has(victim_uid):
		live[victim_uid].damage_taken = float(live[victim_uid].damage_taken) + float(amount)
		live[victim_uid].last_hit_by = source_uid


func _on_agent_disabled(body) -> void:
	if not is_instance_valid(body) or body.get("evo_uid") == null:
		return
	var uid: String = str(body.evo_uid)
	if not live.has(uid):
		return
	var killer: String = str(live[uid].get("last_hit_by", ""))
	if live.has(killer):
		var bounty: float = float(body.get("bounty_paid")) if body.get("bounty_paid") != null else 0.0  # Bounty.on_kill
		live[killer].kills = int(live[killer].kills) + 1
		live[killer].victims.append(uid)
		live[killer].bounty = float(live[killer].bounty) + bounty
		_log(2, "EVO KILL %s killed %s (zone %s), bounty %.0f WP" % [killer, uid, live[uid].zone, bounty])
	_end_life(uid, true, killer)


# A ship that leaves without dying (sector unloaded, game reset): it flies again later.
func _on_agent_despawning(body) -> void:
	if not is_instance_valid(body) or body.get("evo_uid") == null:
		return
	var uid: String = str(body.evo_uid)
	if live.has(uid):
		resume.append(live[uid])
		live.erase(uid)
		_bodies.erase(uid)


# Fitness: return on cost, (earned + bounties - repairs - upkeep) / cost, less 1 if the ship was lost.
static func fitness_of(record: Dictionary, died: bool, age: float) -> float:
	return net_of(record, age) / max(float(record.cost), 1.0) - (1.0 if died else 0.0)


# A life's takings so far (WP): earned + bounties - repairs - upkeep.
static func net_of(record: Dictionary, age: float) -> float:
	var upkeep: float = Constants.EVO_UPKEEP_PER_HOUR * max(float(record.cost), 1.0) * age / 3600.0
	return float(record.earned) + float(record.bounty) - float(record.get("spent", 0.0)) - upkeep


# What a live arena pilot has (WP): its stake (Constants EVO_PILOT_STAKE_SHARE) plus its takings.
func wallet_of(uid: String) -> float:
	if not live.has(uid):
		return 0.0
	var record: Dictionary = live[uid]
	return Constants.EVO_PILOT_STAKE_SHARE * float(record.cost) + net_of(record, game_time - float(record.born))


func _end_life(uid: String, died: bool, killer: String) -> void:
	var record: Dictionary = live[uid]
	live.erase(uid)
	_bodies.erase(uid)
	var age: float = game_time - float(record.born)
	var fitness: float = fitness_of(record, died, age)
	var entry: Dictionary = genomes.get(record.genome_id, {})
	totals[("deaths" if died else "retired")] = int(totals.get("deaths" if died else "retired", 0)) + 1
	var verdict: String = ""
	if not entry.empty():
		entry.lives = int(entry.lives) + 1
		entry.fitness_sum = float(entry.fitness_sum) + fitness
		entry.kills = int(entry.kills) + int(record.kills)
		entry.deaths = int(entry.deaths) + (1 if died else 0)
		entry.earned = int(entry.earned) + int(record.earned)
		verdict = _place_in_archive(record.genome_id)
	var pool: Dictionary = pools[record.faction]
	pool.lives = int(pool.lives) + 1
	_log(1, "EVO %s %s %s zone=%s age=%.0fs kills=%d earned=%d bounty=%.0f spent=%.0f dealt=%.0f taken=%.0f docks=%d %s renown=%.0f cost=%.0f fitness=%+.2f genome_mean=%+.2f (n=%d) %s%s" % [
		"DEATH" if died else "RETIRE", uid, record.genome_id, record.zone, age, record.kills, record.earned, record.bounty,
		record.get("spent", 0.0), record.damage_dealt, record.damage_taken, record.docks, to_json(record.get("events", {})), renown_of(record), record.cost, fitness, shrunk_fitness(record.genome_id),
		int(entry.get("lives", 0)), verdict, (" killer=" + killer) if killer != "" else ""])
	_write_life(record, died, killer, fitness, age)
	_prune_genomes()


# Fitness mean, shrunk toward 0 by Constants EVO_PRIOR_LIVES (one lucky life proves little).
func shrunk_fitness(genome_id: String) -> float:
	var entry: Dictionary = genomes.get(genome_id, {})
	if entry.empty():
		return 0.0
	return float(entry.fitness_sum) / (float(entry.lives) + Constants.EVO_PRIOR_LIVES)


# Takes the genome's niche if it is empty or the genome now beats its best. Returns a note.
func _place_in_archive(genome_id: String) -> String:
	var entry: Dictionary = genomes[genome_id]
	var cells: Dictionary = pools[entry.faction].cells
	var niche: String = Genome.niche(entry.genome)
	var best: String = str(cells.get(niche, ""))
	if best == genome_id:
		return "holds " + niche
	if best == "" or not genomes.has(best):
		cells[niche] = genome_id
		return "NEW NICHE " + niche
	if shrunk_fitness(genome_id) > shrunk_fitness(best):
		cells[niche] = genome_id
		return "TAKES " + niche + " from " + best
	return "below best of " + niche


# A zone can favour a role (Constants ARENA_ZONES prefer_role, prefer_share): this spawn picks among
# that role's niches only, if the pool has any. Returns the role, or "".
func _preferred_role(faction: String, zone_id: String) -> String:
	for zone in Constants.ARENA_ZONES:
		if zone.id == zone_id and zone.has("prefer_role") and randf() < float(zone.get("prefer_share", 0.0)):
			var role: String = "|%s|" % zone.prefer_role
			for niche in pools.get(faction, {}).get("cells", {}):
				if niche.find(role) >= 0:
					return role
	return ""


func _pick_genome(faction: String, role: String = "") -> Dictionary:
	var pool: Dictionary = pools[faction]
	var cells: Array = []
	for niche in pool.cells:
		if genomes.has(pool.cells[niche]) and (role == "" or niche.find(role) >= 0):
			cells.append(pool.cells[niche])
	if Constants.EVO_PROVING and role == "" and not cells.empty() and randf() < Constants.EVO_PROVE_REFLY_CHANCE:
		var unproven: Array = _unproven(faction)
		if not unproven.empty():
			return {"genome_id": unproven[randi() % unproven.size()], "how": "refly"}
	var immigrant_chance: float = 0.0 if Constants.EVO_PROVING or role != "" else Constants.EVO_IMMIGRANT_CHANCE
	if cells.empty() or randf() < immigrant_chance:
		return {"genome_id": _add_genome(Genome.random_genome(), faction, ""), "how": "immigrant"}
	var weights: Array = []
	var total := 0.0
	for genome_id in cells:
		var weight: float = exp(clamp(shrunk_fitness(genome_id) / Constants.EVO_SELECTION_TEMPERATURE, -30.0, 30.0))
		weights.append(weight)
		total += weight
	var roll: float = randf() * total
	var parent: String = cells.back()
	for i in range(cells.size()):
		roll -= weights[i]
		if roll <= 0.0:
			parent = cells[i]
			break
	if randf() < Constants.EVO_REFLY_CHANCE:
		return {"genome_id": parent, "how": "refly"}
	var behavior_on: bool = int(pool.lives) >= Constants.EVO_BEHAVIOR_START_LIVES
	return {"genome_id": _add_genome(Genome.mutate(genomes[parent].genome, behavior_on), faction, parent), "how": "mutant"}


# Proving mode: this faction's niche bests that rank among the fittest EVO_PROVE_PER_ARCHETYPE of their
# archetype (both factions' pools as one, as the presets are picked) and have fewer than EVO_PROVE_LIVES lives.
func _unproven(faction: String) -> Array:
	var ranked: Dictionary = {}  # Archetype -> [[fitness, genome id]]
	for pool_faction in pools:
		var cells: Dictionary = pools[pool_faction].cells
		for niche in cells:
			if genomes.has(cells[niche]) and niche.find("|drifter|") < 0:
				var kind: String = PresetExporter.archetype(niche)
				if not ranked.has(kind):
					ranked[kind] = []
				ranked[kind].append([shrunk_fitness(cells[niche]), cells[niche]])
	var unproven: Array = []
	for kind in ranked:
		var picks: Array = ranked[kind]
		picks.sort_custom(self, "_fitter_first")
		for i in range(min(Constants.EVO_PROVE_PER_ARCHETYPE, picks.size())):
			var entry: Dictionary = genomes[picks[i][1]]
			if entry.faction == faction and int(entry.lives) < Constants.EVO_PROVE_LIVES:
				unproven.append(picks[i][1])
	return unproven


func _add_genome(genome: Dictionary, faction: String, parent: String) -> String:
	var genome_id: String = "%s%d" % [faction.substr(0, 1).to_upper(), _next_genome]
	_next_genome += 1
	genomes[genome_id] = {"genome": genome, "faction": faction, "parent": parent, "born": game_time, "lives": 0, "fitness_sum": 0.0, "kills": 0, "deaths": 0, "earned": 0}
	return genome_id


# Past Constants EVO_GENOME_MEMORY, forgets the oldest genomes that are no niche's best and not flying.
func _prune_genomes() -> void:
	if genomes.size() <= Constants.EVO_GENOME_MEMORY:
		return
	var keep := {}
	for faction in pools:
		for niche in pools[faction].cells:
			keep[pools[faction].cells[niche]] = true
	for record in live.values() + resume:
		keep[record.genome_id] = true
	var ids: Array = genomes.keys()
	var excess: int = genomes.size() - Constants.EVO_GENOME_MEMORY
	for genome_id in ids:  # Insertion order: oldest first
		if excess <= 0:
			break
		if not keep.has(genome_id):
			genomes.erase(genome_id)
			excess -= 1


# --- Logging ---

func _log(level: int, line: String) -> void:
	if Constants.EVO_LOG_LEVEL >= level:
		print("[%s] %s" % [_clock(), line])


func _clock() -> String:
	var h: int = int(game_time) / 3600
	var m: int = (int(game_time) % 3600) / 60
	var s: int = int(game_time) % 60
	return "%d:%02d:%02d" % [h, m, s]


func _write_life(record: Dictionary, died: bool, killer: String, fitness: float, age: float) -> void:
	var dir := Directory.new()
	if not dir.dir_exists(Constants.EVO_LOG_DIR):
		dir.make_dir_recursive(Constants.EVO_LOG_DIR)
	var path: String = Constants.EVO_LOG_DIR + "run_%s.jsonl" % run_id
	var file := File.new()
	var err: int = file.open(path, File.READ_WRITE) if file.file_exists(path) else file.open(path, File.WRITE)
	if err != OK:
		return
	file.seek_end()
	var entry: Dictionary = genomes.get(record.genome_id, {})
	var line := {
		"t": game_time, "uid": record.uid, "faction": record.faction, "zone": record.zone, "genome_id": record.genome_id,
		"parent": record.parent, "how": record.get("how", ""), "died": died, "killer": killer, "age": age,
		"kills": record.kills, "victims": record.victims, "earned": record.earned, "bounty": record.bounty, "spent": record.get("spent", 0.0),
		"damage_dealt": record.damage_dealt, "damage_taken": record.damage_taken, "docks": record.docks, "events": record.get("events", {}),
		"cost": record.cost, "skill": record.skill, "fitness": fitness,
		"niche": Genome.niche(entry.genome) if not entry.empty() else "", "genome": entry.get("genome", {}),
	}
	file.store_line(to_json(line))
	file.close()


# The state of both pools: their best niches, part and size spread. Printed every report interval.
func print_report() -> void:
	print("[%s] EVO REPORT ===== run %s  sim %.2f h  wall %.2f h  births %d  deaths %d  retired %d  flying %d  genomes %d =====" % [
		_clock(), run_id, game_time / 3600.0, real_time / 3600.0, int(totals.births), int(totals.deaths), int(totals.retired), live.size(), genomes.size()])
	for faction in pools:
		var pool: Dictionary = pools[faction]
		var ranked: Array = []
		for niche in pool.cells:
			var genome_id: String = pool.cells[niche]
			if genomes.has(genome_id):
				ranked.append([shrunk_fitness(genome_id), niche, genome_id])
		ranked.sort_custom(self, "_fitter_first")
		print("[%s] EVO REPORT %s: %d niches, %d lives ended, behaviour %s" % [_clock(), faction, ranked.size(), int(pool.lives),
			"evolving" if int(pool.lives) >= Constants.EVO_BEHAVIOR_START_LIVES else "fixed until %d lives" % Constants.EVO_BEHAVIOR_START_LIVES])
		var roles := {}
		var parts := {}
		for i in range(ranked.size()):
			var entry: Dictionary = genomes[ranked[i][2]]
			var role: String = ranked[i][1].split("|")[1]
			roles[role] = int(roles.get(role, 0)) + 1
			for part in entry.genome.tools + entry.genome.modules:
				if not part.empty():
					var key: String = "%s %s" % [part.kind, Constants.PART_TYPE_NAMES.get(int(part.type), "")]
					parts[key] = int(parts.get(key, 0)) + 1
			if i < 8:
				print("[%s] EVO REPORT   #%d %-22s %s fit %+.2f n=%d kills=%d deaths=%d earned=%d  %s" % [_clock(), i + 1, ranked[i][1], ranked[i][2],
					ranked[i][0], int(entry.lives), int(entry.kills), int(entry.deaths), int(entry.earned), Genome.describe(entry.genome)])
		print("[%s] EVO REPORT   roles %s  parts %s" % [_clock(), to_json(roles), to_json(parts)])


func _fitter_first(a: Array, b: Array) -> bool:
	return a[0] > b[0]
