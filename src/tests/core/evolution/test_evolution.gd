# Tests for Evolution: lives, fitness, the niche archive, and saving it all.

extends GutTest

var _bodies: Array = []


class FakeBody extends Node:
	var evo_uid := ""
	var cargo := {}
	var hull_max := 50.0
	var hull := 50.0

	func clear_cargo() -> void:
		cargo = {}

	func repair_hull() -> float:
		var restored: float = hull_max - hull
		hull = hull_max
		return restored


var _saved_commodities: Dictionary = {}


func before_each():
	Evolution.new_run()
	_saved_commodities = TemplateDatabase.assets_commodities
	var tech := CommodityTemplate.new()
	tech.template_id = "commodity_tech"
	tech.base_value = 60
	TemplateDatabase.assets_commodities = {"commodity_tech": tech}


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
	var life: Dictionary = Evolution.begin_life("verdant", "1v1")
	assert_eq(life.how, "immigrant")
	assert_true(TemplateDatabase.get_template(life.ship_template_id) is ShipTemplate)
	assert_true(Evolution.live.has(life.uid))
	assert_gt(float(life.cost), 0.0)


func test_fitness_is_return_on_cost_less_a_lost_ship():
	var record := {"earned": 300, "bounty": 200.0, "spent": 0.0, "cost": 1000.0}
	assert_almost_eq(Evolution.fitness_of(record, false, 0.0), 0.5, 0.0001)
	assert_almost_eq(Evolution.fitness_of(record, true, 0.0), -0.5, 0.0001)
	var upkeep: float = Constants.EVO_UPKEEP_PER_HOUR
	assert_almost_eq(Evolution.fitness_of(record, false, 3600.0), 0.5 - upkeep, 0.0001, "Upkeep: a share of the cost per hour")


func test_a_kill_pays_a_bounty_and_ends_the_victims_life_in_the_archive():
	var hunter: Dictionary = Evolution.begin_life("verdant", "1v1")
	var prey: Dictionary = Evolution.begin_life("violet", "1v1")
	Evolution._on_agent_damaged(_body(prey.uid), 10.0, _body(hunter.uid))
	Evolution._on_agent_disabled(_body(prey.uid))
	assert_false(Evolution.live.has(prey.uid))
	assert_eq(int(Evolution.live[hunter.uid].kills), 1)
	assert_almost_eq(float(Evolution.live[hunter.uid].bounty), Constants.EVO_KILL_BOUNTY_SHARE * float(prey.cost), 0.01)
	assert_eq(int(Evolution.totals.deaths), 1)
	assert_eq(Evolution.pools.violet.cells.size(), 1, "Its genome takes an empty niche")


func test_docking_sells_the_hold_and_charges_repairs():
	var life: Dictionary = Evolution.begin_life("verdant", "2v2")
	var body := _body(life.uid)
	body.cargo = {"commodity_tech": 2}
	body.hull = 25.0
	assert_false(Evolution.on_docked(body), "A young ship does not retire")
	assert_eq(int(Evolution.live[life.uid].earned), 2 * 60)
	assert_almost_eq(float(Evolution.live[life.uid].spent), Constants.EVO_REPAIR_COST_SHARE * float(life.hull_value) * 0.5, 0.01)
	assert_true(body.cargo.empty())


func test_old_ships_retire_at_the_dock():
	var life: Dictionary = Evolution.begin_life("verdant", "3v3")
	Evolution.game_time += Constants.ARENA_MAX_LIFETIME + 1.0
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
	var life: Dictionary = Evolution.begin_life("violet", "2v2")
	Evolution.live[life.uid].kills = 2
	var data: Dictionary = Evolution.serialize()
	Evolution.new_run()
	assert_true(Evolution.deserialize(data))
	var again: Dictionary = Evolution.begin_life("violet", "2v2")
	assert_eq(again.uid, life.uid, "The same ship, not a new one")
	assert_eq(int(again.kills), 2)


func test_suspended_lives_resume_by_zone_and_faction():
	var life: Dictionary = Evolution.begin_life("verdant", "1v1")
	Evolution.suspend_all()
	assert_true(Evolution.live.empty())
	var other: Dictionary = Evolution.begin_life("verdant", "3v3")
	assert_ne(other.uid, life.uid, "Another zone's slot gets a new life")
	assert_eq(Evolution.begin_life("verdant", "1v1").uid, life.uid)


func test_presets_export_the_fittest_tried_genomes():
	var Exporter = load("res://src/core/evolution/preset_exporter.gd")
	var genome_id: String = Evolution._add_genome(Evolution.Genome.random_genome(), "verdant", "")
	Evolution.genomes[genome_id].lives = 3
	Evolution.genomes[genome_id].fitness_sum = 1.5
	Evolution._place_in_archive(genome_id)
	var untried: String = Evolution._add_genome(Evolution.Genome.random_genome(), "violet", "")
	Evolution._place_in_archive(untried)
	var folder := "user://test_presets/"
	var lines: Array = Exporter.export_all(Evolution.serialize(), 5, 3, folder)
	var agent = load(folder + "verdant/agent_preset_verdant_%s.tres" % genome_id.to_lower())
	assert_true(agent is AgentTemplate, str(lines))
	if agent is AgentTemplate:
		var ship = load(folder + "verdant/%s.tres" % agent.ship_template_id)
		assert_true(ship is ShipTemplate)
		assert_eq(agent.faction, "verdant")
		for part_id in ship.equipped_tools + ship.equipped_modules:
			if part_id != Constants.HARPOON_TEMPLATE_ID:
				assert_true(File.new().file_exists(folder + "verdant/%s.tres" % part_id), part_id)
	assert_false(Directory.new().file_exists(folder + "violet/agent_preset_violet_%s.tres" % untried.to_lower()), "Too few lives to trust")
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
