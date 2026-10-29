# Tests for Evolution: lives, fitness, the niche archive, and saving it all.

extends GutTest

const Genome = preload("res://src/core/evolution/genome.gd")

var _bodies: Array = []


class FakeBody extends Node:
	var evo_uid := ""
	var cargo := {}
	var hull_max := 50.0
	var hull := 50.0
	var bounty_paid := 0.0

	func clear_cargo() -> void:
		cargo = {}

	func remove_cargo(commodity_id: String, units: int) -> int:
		cargo[commodity_id] = int(cargo.get(commodity_id, 0)) - units
		if cargo[commodity_id] <= 0:
			cargo.erase(commodity_id)
		return units

	func repair_hull() -> float:
		var restored: float = hull_max - hull
		hull = hull_max
		return restored


var _saved_commodities: Dictionary = {}


func before_each():
	_empty_run()
	_saved_commodities = TemplateDatabase.assets_commodities
	var tech := CommodityTemplate.new()
	tech.template_id = "commodity_tech"
	tech.base_value = 60
	TemplateDatabase.assets_commodities = {"commodity_tech": tech}


# A new run without its seed designs (Constants EVO_SEEDS): the mechanics from an empty pool.
func _empty_run() -> void:
	Evolution.new_run()
	Evolution.genomes = {}
	for faction in Evolution.pools:
		Evolution.pools[faction] = {"cells": {}, "lives": 0}


func test_a_new_run_plants_the_seed_designs_each_in_its_niche():
	Evolution.new_run()
	for faction in Constants.EVO_SEEDS:
		assert_gt(Evolution.pools[faction].cells.size(), 0, faction)
	var prospectors := 0
	for niche in Evolution.pools.verdant.cells:
		if niche.find("|prospector|") >= 0:
			prospectors += 1
	assert_eq(prospectors, 2, "Two prospector seeds, light and medium")
	assert_eq(Evolution.plant_seeds(), 0, "Planted once")
	var life: Dictionary = Evolution.begin_life("xenohive", "frontier")
	assert_true(TemplateDatabase.get_template(life.ship_template_id) is ShipTemplate)
	assert_true(TemplateDatabase.get_template(life.ship_template_id).salvage_yield.has("commodity_biotech"), "Alien carcasses hold biotech")


func test_a_new_era_starts_every_record_over():
	Evolution.new_run()
	var genome_id: String = Evolution.pools.verdant.cells.values()[0]
	Evolution.genomes[genome_id].lives = 7
	Evolution.genomes[genome_id].fitness_sum = 3.0
	Evolution.new_era()
	assert_eq(int(Evolution.genomes[genome_id].lives), 0)
	assert_eq(float(Evolution.genomes[genome_id].fitness_sum), 0.0)


func after_each():
	Evolution.new_run()
	TemplateDatabase.assets_commodities = _saved_commodities
	TemplateDatabase.evolved = {}
	for body in _bodies:
		body.free()
	_bodies = []


func _body(uid: String) -> FakeBody:
	var body := FakeBody.new()
	body.evo_uid = uid
	_bodies.append(body)
	return body


func test_first_life_is_an_immigrant_with_a_buildable_ship():
	var life: Dictionary = Evolution.begin_life("verdant", "verdant_post")
	assert_eq(life.how, "immigrant")
	assert_true(TemplateDatabase.get_template(life.ship_template_id) is ShipTemplate)
	assert_true(Evolution.live.has(life.uid))
	assert_gt(float(life.cost), 0.0)


func test_each_family_gets_its_share_of_lives_whatever_its_fitness():
	Evolution.new_run()
	var cells: Dictionary = Evolution.pools.verdant.cells
	var families := {}
	for niche in cells:
		var entry: Dictionary = Evolution.genomes[cells[niche]]
		entry.lives = 50
		entry.fitness_sum = 50.0 * (2.0 if Genome.family(niche) != "prospector" else -2.0)  # Prospectors far behind
		families[Genome.family(niche)] = 0
	assert_true(families.has("prospector") and families.size() > 1)
	for i in range(400):
		var pick: Dictionary = Evolution._pick_genome("verdant")
		var entry: Dictionary = Evolution.genomes[pick.genome_id]
		var source: Dictionary = Evolution.genomes[entry.parent] if pick.how == "mutant" else entry
		families[Genome.family(Genome.niche(source.genome))] += 1
	var share: float = float(families.prospector) / 400.0
	assert_almost_eq(share, 1.0 / families.size(), 0.08, "Prospectors fly their family's share though far less fit")
	assert_eq(Genome.family("s+0.0|lance-cannon-raider|-"), "lance")
	assert_eq(Genome.family("s+0.0|missile-cannon-raider|-"), "raider")
	assert_eq(Genome.family("s+0.0|cannon-fighter|mid"), "fighter")
	assert_eq(Genome.family("s+0.0|scavenger|-"), "scavenger")
	assert_eq(Genome.family("s+0.0|driller|-"), "driller", "A role a new rule adds is its own family")


func test_fitness_is_return_on_cost_less_a_lost_ship():
	var record := {"earned": 300, "bounty": 200.0, "spent": 0.0, "cost": 1000.0}
	assert_almost_eq(Evolution.fitness_of(record, false, 0.0), 0.5, 0.0001)
	assert_almost_eq(Evolution.fitness_of(record, true, 0.0), -0.5, 0.0001)
	var upkeep: float = Constants.EVO_UPKEEP_PER_HOUR
	assert_almost_eq(Evolution.fitness_of(record, false, 3600.0), 0.5 - upkeep, 0.0001, "Upkeep: a share of the cost per hour")
	record.destroyed = 1500.0
	assert_almost_eq(Evolution.fitness_of(record, true, 0.0), -0.5, 0.0001, "Enemy value destroyed counts only in combat niches")
	record.combat = true
	assert_almost_eq(Evolution.fitness_of(record, true, 0.0), -0.5 + 1.5 * Constants.EVO_COMBAT_EXCHANGE_WEIGHT, 0.0001, "A fighter that took 1.5 ships' worth for its own: ahead")
	assert_true(Genome.is_combat_role("s+0.0|missile-raider|-"))
	assert_true(Genome.is_combat_role("s+0.0|lancer|-"))
	assert_true(Genome.is_combat_role("s+0.0|lance-cannon-fighter|mid"))
	assert_false(Genome.is_combat_role("s+0.0|scavenger|-"))
	assert_false(Genome.is_combat_role("s+0.0|prospector|mid"))


func test_run_and_chase_events_are_counted_per_life():
	var life: Dictionary = Evolution.begin_life("verdant", "verdant_post")
	Evolution.note(life.uid, "fled")
	Evolution.note(life.uid, "fled")
	Evolution.note(life.uid, "let_go")
	Evolution.note("nobody", "fled")
	assert_eq_deep(Evolution.live[life.uid].events, {"fled": 2, "let_go": 1})


func test_a_kill_pays_a_bounty_and_ends_the_victims_life_in_the_archive():
	var hunter: Dictionary = Evolution.begin_life("verdant", "verdant_post")
	var prey: Dictionary = Evolution.begin_life("violet", "violet_post")
	Evolution._on_agent_damaged(_body(prey.uid), 10.0, _body(hunter.uid))
	var wreck := _body(prey.uid)
	wreck.bounty_paid = 123.0  # What Bounty.on_kill paid the killer
	Evolution._on_agent_disabled(wreck)
	assert_false(Evolution.live.has(prey.uid))
	assert_eq(int(Evolution.live[hunter.uid].kills), 1)
	assert_almost_eq(float(Evolution.live[hunter.uid].bounty), 123.0, 0.01)
	assert_eq(int(Evolution.totals.deaths), 1)
	assert_eq(Evolution.pools.violet.cells.size(), 1, "Its genome takes an empty niche")


func test_docking_sells_the_hold_and_charges_repairs():
	var life: Dictionary = Evolution.begin_life("verdant", "verdant_post")
	var body := _body(life.uid)
	body.cargo = {"commodity_tech": 2}
	body.hull = 25.0
	GameState.station_markups = {"s": 0.25}  # Cargo price: (1 + 0.25) * PRICE_CARGO_SELL_SHARE of value
	assert_false(Evolution.on_docked(body, "s"), "A young ship does not retire")
	assert_eq(int(Evolution.live[life.uid].earned), 2 * int(round(60 * 1.25 * Constants.PRICE_CARGO_SELL_SHARE)), "At the station's cargo price")
	assert_almost_eq(float(Evolution.live[life.uid].spent), Constants.EVO_REPAIR_COST_SHARE * float(life.hull_value) * 0.5, 0.01)
	assert_true(body.cargo.empty())


func test_old_ships_retire_at_the_dock():
	var life: Dictionary = Evolution.begin_life("verdant", "verdant_haven")
	Evolution.game_time += Constants.NPC_MAX_LIFETIME + 1.0
	assert_true(Evolution.on_docked(_body(life.uid)))
	assert_eq(int(Evolution.totals.retired), 1)


func test_a_fitter_genome_takes_its_niche():
	var genome_id: String = Evolution._add_genome(Evolution.Genome.random_genome(), "verdant", "")
	Evolution._place_in_archive(genome_id)
	var rival_id: String = Evolution._add_genome(Evolution.genomes[genome_id].genome.duplicate(true), "verdant", genome_id)
	Evolution.genomes[rival_id].lives = 3
	Evolution.genomes[rival_id].fitness_sum = 3.0
	assert_true(Evolution._place_in_archive(rival_id).begins_with("TAKES"))
	var niche: String = Evolution.Genome.niche(Evolution.genomes[rival_id].genome)
	assert_eq(Evolution.pools.verdant.cells[niche], rival_id)


func test_saved_lives_fly_again_after_loading():
	var life: Dictionary = Evolution.begin_life("violet", "violet_post")
	Evolution.live[life.uid].kills = 2
	var data: Dictionary = Evolution.serialize()
	Evolution.new_run()
	assert_true(Evolution.deserialize(data))
	var again: Dictionary = Evolution.begin_life("violet", "violet_post")
	assert_eq(again.uid, life.uid, "The same ship, not a new one")
	assert_eq(int(again.kills), 2)


func test_suspended_lives_resume_by_zone_and_faction():
	var life: Dictionary = Evolution.begin_life("verdant", "verdant_post")
	Evolution.suspend_all()
	assert_true(Evolution.live.empty())
	var other: Dictionary = Evolution.begin_life("verdant", "verdant_haven")
	assert_ne(other.uid, life.uid, "Another zone's slot gets a new life")
	assert_eq(Evolution.begin_life("verdant", "verdant_post").uid, life.uid)


func test_presets_export_the_fittest_of_each_archetype_whatever_the_faction():
	var Exporter = load("res://src/core/evolution/preset_exporter.gd")
	var genome: Dictionary = Evolution.Genome.random_genome()
	genome.tools = [{"kind": "harpoon", "type": 1, "genes": {}}, {"kind": "harpoon", "type": 1, "genes": {}},
		{"kind": "missile", "type": 2, "genes": Constants.PART_TYPE_SEEDS.missile[2].duplicate()}]
	var genome_id: String = Evolution._add_genome(genome, "violet", "")
	Evolution.genomes[genome_id].lives = 3
	Evolution.genomes[genome_id].fitness_sum = 1.5
	Evolution._place_in_archive(genome_id)
	var untried: String = Evolution._add_genome(Evolution.Genome.random_genome(), "verdant", "")
	Evolution._place_in_archive(untried)
	var folder := "user://test_presets/"
	var lines: Array = Exporter.export_all(Evolution.serialize(), 5, 3, folder)
	var agent = load(folder + "agent_preset_%s.tres" % genome_id.to_lower())
	assert_true(agent is AgentTemplate, str(lines))
	if agent is AgentTemplate:
		assert_eq(agent.faction, "", "No faction: an archetype")
		var ship = load(folder + "%s.tres" % agent.ship_template_id)
		assert_true(ship is ShipTemplate)
		assert_eq(ship.equipped_tools.count(Constants.HARPOON_TEMPLATE_ID), 1, "One harpoon: the spare is junk")
		for part_id in ship.equipped_tools + ship.equipped_modules:
			if part_id != Constants.HARPOON_TEMPLATE_ID:
				var part = load(folder + "%s.tres" % part_id)
				assert_not_null(part, part_id)
				if part_id.begins_with("preset_missile"):
					assert_true(part is UtilityToolTemplate, "A missile rack is a tool, not a module")
	assert_false(Directory.new().file_exists(folder + "agent_preset_%s.tres" % untried.to_lower()), "Too few lives to trust")
	_remove_tree(folder)


func _remove_tree(path: String) -> void:
	var dir := Directory.new()
	if dir.open(path) != OK:
		return
	dir.list_dir_begin(true, true)
	var name: String = dir.get_next()
	while name != "":
		if dir.current_is_dir():
			_remove_tree(path.plus_file(name))
		else:
			dir.remove(name)
		name = dir.get_next()
	Directory.new().remove(path)


func test_groups_rank_by_renown_and_the_first_leads():
	var first: Dictionary = Evolution.begin_life("verdant", "verdant_haven")
	var second: Dictionary = Evolution.begin_life("verdant", "verdant_haven")
	Evolution.begin_life("violet", "violet_haven")
	assert_eq(Evolution.rank_of(first.uid), 1, "No renown yet: the older first")
	Evolution.live[second.uid].kills = 1
	assert_eq(Evolution.rank_of(second.uid), 1, "A kill puts it first")
	assert_eq(Evolution.group_of("verdant", "verdant_haven").size(), 2, "Only its faction in its zone")
	var body := _body(second.uid)
	body.set("is_docked", false)
	Evolution.attach_body(second.uid, body)
	assert_eq(Evolution.leader_of("verdant", "verdant_haven"), body, "and makes it the leader")
	assert_null(Evolution.leader_of("violet", "violet_haven"), "No one to lead, no leader")


func test_renown_puts_off_retiring():
	var life: Dictionary = Evolution.begin_life("verdant", "verdant_haven")
	Evolution.live[life.uid].kills = 2
	var longer: float = min(2.0, Constants.NPC_LIFETIME_MAX_FACTOR)
	assert_almost_eq(Evolution.lifetime_of(life.uid), Constants.NPC_MAX_LIFETIME * longer, 0.01, "Two kills: twice as long (if on)")
	Evolution.game_time += Constants.NPC_MAX_LIFETIME * longer - 1.0
	assert_false(Evolution.on_docked(_body(life.uid)), "Not old yet")
	Evolution.live[life.uid].kills = 100
	assert_almost_eq(Evolution.lifetime_of(life.uid), Constants.NPC_MAX_LIFETIME * Constants.NPC_LIFETIME_MAX_FACTOR, 0.01, "At most this long")


func test_presets_come_in_three_weights_per_role():
	var Exporter = load("res://src/core/evolution/preset_exporter.gd")
	assert_eq(Exporter.archetype("s-1.5|missile-raider|-"), "missile-raider light")
	assert_eq(Exporter.archetype("s+0.5|missile-raider|-"), "missile-raider medium")
	assert_eq(Exporter.archetype("s+2.5|missile-raider|-"), "missile-raider heavy")


func test_proving_reflies_the_leading_unproven_of_each_archetype():
	var ids: Array = []
	var niches: Array = ["s+1.5|raider|long", "s+1.5|raider|mid", "s+2.0|raider|short", "s+2.5|raider|-", "s+1.5|drifter|-"]
	for i in range(niches.size()):
		var faction: String = "violet" if i == 1 else "verdant"
		var genome_id: String = Evolution._add_genome(Evolution.Genome.random_genome(), faction, "")
		Evolution.genomes[genome_id].lives = 10 if i == 0 else 3
		Evolution.genomes[genome_id].fitness_sum = 5.0 - i
		Evolution.pools[faction].cells[niches[i]] = genome_id
		ids.append(genome_id)
	var unproven: Array = Evolution._unproven("verdant")
	assert_eq(unproven, [ids[2]], "The top three raider heavies but the proven one and the other faction's; not the fourth, nor a drifter")
	assert_eq(Evolution._unproven("violet"), [ids[1]])
